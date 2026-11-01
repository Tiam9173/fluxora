import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/helper/helper.dart';
import 'package:fluxora/models/core.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/utils/frame_codec.dart';
import 'package:fluxora/utils/platform_check.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Test-only stand-ins for the three collaborators [_doRestart] reaches outside
/// the socket: the Windows service probe, the helper client, and the core
/// launcher.
///
/// None of the three can be intercepted from a test — the helper client and the
/// `windows` probe are library globals, and `Process.start` cannot be overridden
/// through `IOOverrides`. Production leaves [ClashService.startHooksForTest]
/// `null`, so every branch below takes exactly the path it takes today.
@visibleForTesting
class ClashServiceStartHooks {
  const ClashServiceStartHooks({
    this.registerService,
    this.startCore,
    this.launchCore,
  });

  /// Stands in for `windows?.registerService()`.
  final Future<bool> Function()? registerService;

  /// Stands in for `helperClient.startCore(...)`.
  final Future<bool> Function({
    required String corePath,
    required String arg,
    required String homeDir,
  })?
  startCore;

  /// Stands in for `Process.start(...)` **and** the two stdio listeners after it.
  final Future<void> Function(
    String corePath,
    String arg,
    Map<String, String> environment,
  )?
  launchCore;
}

class ClashService extends ClashHandlerInterface {
  static ClashService? _instance;

  Completer<ServerSocket> serverCompleter = Completer();

  Completer<Socket> socketCompleter = Completer();

  bool isStarting = false;
  bool _isDestroying = false;

  /// Set once [destroy] has run and **never cleared**.
  ///
  /// `_isDestroying` cannot serve this purpose: [_doRestart] resets it to
  /// `false` on every restart (a restart means "we are coming back"), so a bind
  /// that lands after a destroy would look like a fresh start and leak its
  /// listener. This flag is the terminal state.
  bool _teardownRequested = false;

  Process? process;

  @override
  bool get hasLiveProcess => process != null;

  Completer<void>? _restartCompleter;

  TransportType _transportType = TransportType.unixSocket;
  String? _socketPath;
  int? _tcpPort;

  /// The listener this instance bound, or `null` before a successful bind.
  ///
  /// It doubles as the **ownership token**: only a non-null value means this
  /// process owns the file at [_socketPath] and may unlink it.
  ServerSocket? _server;

  /// Whether this instance created the file at [_socketPath].
  ///
  /// Set **after** a successful bind only, so a failed bind can never delete a
  /// path that belongs to another instance.
  bool _ownsSocketFile = false;

  /// Per-process sequence, so two binds inside the same microsecond still get
  /// different names.
  static int _socketSeq = 0;

  /// Set by [_releaseOwnedSocket] and cleared by a successful [_bindListener].
  ///
  /// [_doRestart] uses it to tell "the listener was released by a shutdown, bind
  /// a new one" apart from "the first bind is still in flight, leave it alone"
  /// and from "the first bind failed, do not silently retry".
  bool _listenerReleased = false;

  factory ClashService() {
    _instance ??= ClashService._internal();
    return _instance!;
  }

  ClashService._internal() {
    _initTransport();
  }

  /// Test-only escape hatch: set this **before** the `clashService` singleton is
  /// first read and [_initTransport] returns immediately — no socket is bound
  /// and no core process is spawned.
  ///
  /// Without it, any test that reaches `clashCore` constructs a real
  /// `ClashService` (`core.dart:68`), which binds `%TEMP%\Fluxora_<n>.sock` and
  /// never unlinks it, because nothing under `test/` calls `destroy()`.
  /// See `PHASE_06_8_R7_6_SOCKET_LIFECYCLE_AUDIT_REPORT.md`.
  static bool skipTransportForTest = false;

  /// Test-only: bind the socket for real but stop before spawning the core.
  ///
  /// `Process.start` cannot be faked, so a lifecycle test that wants to observe
  /// a real bind (`_server` / socket file ownership) has no other way to avoid
  /// launching a core binary. Production never sets it.
  static bool skipCoreSpawnForTest = false;

  /// Test-only: stand-ins for the helper probe and the core launcher, so the
  /// helper → fallback branch can be exercised without a Windows service, a
  /// helper, or a real core binary. See [ClashServiceStartHooks].
  ///
  /// Production never sets it; `null` means "use the real collaborators".
  @visibleForTesting
  static ClashServiceStartHooks? startHooksForTest;

  /// Test-only: drop the singleton so the next `ClashService()` binds again.
  ///
  /// The class is a singleton, so without this a test file could only ever
  /// observe one bind. Callers must release the previous instance first
  /// (`shutdown()` / `destroy()`), otherwise its socket file is orphaned.
  static void resetForTest() {
    _instance = null;
  }

  Future<void> _initTransport() async {
    if (skipTransportForTest) return;

    _transportType = await PlatformChecker.getRecommendedTransport();

    if (_transportType == TransportType.unixSocket) {
      final tempDir = Directory.systemTemp.path;
      _socketPath = p.join(tempDir, socketFileName());
      commonPrint.log('Using Unix Domain Socket: $_socketPath');
    }

    // `_initServer` reports a bind failure through `serverCompleter` so
    // `preload()` fails fast; the `catchError` here only keeps a rejected future
    // from surfacing as an unhandled async error.
    unawaited(
      _initServer().catchError((Object e, StackTrace st) {
        commonPrint.log('Socket bind failed: $e');
      }),
    );
    // `reStart()` throws when the bind failed. That same error already reaches
    // every `serverCompleter` waiter (`preload()`, `_doRestart()`), so it is
    // consumed here only to keep it from surfacing as an unhandled async error.
    unawaited(
      reStart().catchError((Object e, StackTrace st) {
        commonPrint.log('Core start aborted: $e');
      }),
    );
  }

  /// A socket file name that two live processes cannot produce twice.
  ///
  /// `pid` is unique among live processes, the microsecond clock separates
  /// successive runs of the same pid, and [_socketSeq] separates two binds that
  /// land in the same microsecond.
  ///
  /// **Path length is a hard constraint, not a style choice.** AF_UNIX paths are
  /// capped at 108 bytes on Linux and **104 bytes on macOS** (`sun_path` is
  /// `char[104]` there). This format is at most 41 bytes, and
  /// `Directory.systemTemp` adds 4 bytes on Linux and up to 48 on macOS — about
  /// 90 bytes in total, which leaves only ~14 bytes of headroom on macOS.
  ///
  /// **Recompute the whole path before changing this format.** Replacing the
  /// microsecond stamp with a UUID, or lengthening the instance id, would cross
  /// the macOS limit; the bind would then fail and the app would come up with no
  /// core at all.
  static String socketFileName() =>
      'Fluxora_${pid}_${DateTime.now().microsecondsSinceEpoch}_${_socketSeq++}.sock';

  /// Binds a fresh listener for the current transport and takes ownership of it.
  ///
  /// Re-entrant by design: [_initTransport] calls it once, and [_doRestart]
  /// calls it again after a [shutdown] released the previous listener.
  /// Ownership is granted **only after** the bind succeeds, so a failed bind
  /// never grants the right to unlink someone else's path.
  Future<ServerSocket> _bindListener() async {
    final ServerSocket server;
    if (_transportType == TransportType.unixSocket) {
      final address = InternetAddress(
        _socketPath!,
        type: InternetAddressType.unix,
      );
      // No unlink before the bind on purpose. The name is instance-unique, so a
      // bind can only fail for a reason worth reporting - deleting the path
      // first would hide that failure and could take another instance's socket
      // away. Exclusive bind (no `shared:`) because this path is ours alone.
      server = await ServerSocket.bind(address, 0);
    } else {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _tcpPort = server.port;
      commonPrint.log('TCP Server bound to port: $_tcpPort');
    }

    _server = server;
    _ownsSocketFile = _transportType == TransportType.unixSocket;
    _listenerReleased = false;
    return server;
  }

  /// Binds the listener and starts accepting on it.
  ///
  /// Re-entrant: [shutdown] releases the listener and the next [_doRestart]
  /// calls this again. A **fresh** [serverCompleter] is created on every call,
  /// so a completed - or failed - completer is never reused.
  Future<void> _initServer() async {
    // A *completed* completer belongs to a listener that has already been
    // released (a re-bind after shutdown), so it must be replaced. The field
    // initializer, by contrast, is still pending on the first call — keeping it
    // is what lets a `preload()` that ran before `_initTransport` reached the
    // bind await the very same future instead of one that is never completed.
    if (serverCompleter.isCompleted) {
      serverCompleter = Completer<ServerSocket>();
    }

    final ServerSocket server;
    try {
      server = await _bindListener();
    } catch (e, stack) {
      // Hand the original error to every waiter before it can be logged and
      // swallowed: `preload()` and `_doRestart()` must fail fast.
      if (!serverCompleter.isCompleted) {
        serverCompleter.completeError(e, stack);
      }
      if (!_isDestroying && !globalState.isExiting) {
        commonPrint.log(e.toString());
        if (e is SocketException) globalState.showNotifier(e.toString());
      }
      return;
    }

    if (_teardownRequested) {
      // `destroy()` ran while the bind was in flight. Release the socket here
      // rather than leaking it, and fail the waiters instead of handing them a
      // listener nobody will ever read.
      await _releaseOwnedSocket();
      if (!serverCompleter.isCompleted) {
        serverCompleter.completeError(
          StateError('ClashService destroyed while binding'),
        );
      }
      return;
    }

    if (!serverCompleter.isCompleted) {
      serverCompleter.complete(server);
    }
    _acceptLoop(server);
  }

  /// Reads frames from [server] until it is closed.
  ///
  /// Runs in its own guarded zone: a decode error is logged without tearing down
  /// the caller, and once [_releaseOwnedSocket] closes the listener the
  /// `await for` simply ends.
  void _acceptLoop(ServerSocket server) {
    runZonedGuarded(
      () async {
        await for (final socket in server) {
          await _destroySocket();
          socketCompleter.complete(socket);

          socket
              .transform(FrameDecoderTransformer())
              .listen(
                (data) {
                  handleResult(ActionResult.fromJson(json.decode(data)));
                },
                onError: (error) {
                  if (_isDestroying || globalState.isExiting) return;
                  commonPrint.log('Frame decode error: $error');
                },
                onDone: () {
                  commonPrint.log('Socket connection closed');
                },
              );
        }
      },
      (error, stack) {
        if (_isDestroying || globalState.isExiting) return;
        commonPrint.log(error.toString());
      },
    );
  }

  @override
  Future<void> reStart() async {
    final completer = Completer<void>();
    final previous = _restartCompleter;
    _restartCompleter = completer;

    if (previous != null) {
      await previous.future;
    }

    try {
      // Perform a real restart so every caller is guaranteed to see a fresh
      // core after this call returns. Queued calls will run sequentially.
      await _doRestart();
    } finally {
      // `_doRestart` clears this on every path that *returns*, but a thrown
      // bind / service-probe / helper / `Process.start` error skips all of
      // them. Leaving the flag set made `checkCoreHealth()` report "still
      // starting" forever, with no way back short of a new instance. This is
      // the only caller of `_doRestart`, so the finally covers every exit —
      // and it does not catch, so the original error and its stack still
      // propagate.
      isStarting = false;
      if (_restartCompleter == completer) {
        _restartCompleter = null;
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> _doRestart() async {
    isStarting = true;
    _isDestroying = false;

    await _destroySocket();

    process?.kill();
    if (process != null) {
      await process!.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          process?.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
    process = null;

    socketCompleter = Completer();

    // A previous `shutdown()` released the listener. Handing the core a path
    // whose file is gone and whose listener is closed would make its
    // `net.Dial` fail and the process exit, so bind a new one first.
    // The flag (rather than `_server == null`) keeps this from firing while the
    // very first bind is still in flight, or after a bind that already failed.
    if (_listenerReleased) {
      if (_teardownRequested) {
        // A destroyed instance must never come back to life.
        isStarting = false;
        throw StateError('ClashService was destroyed');
      }
      await _initServer();
    }

    // Throws when the bind failed, so the caller (`reStart()`) sees the original
    // error instead of waiting on a completer that never completes.
    final serverSocket = await serverCompleter.future;

    if (skipCoreSpawnForTest) {
      // Test seam: the socket really was bound, but no core process is started.
      isStarting = false;
      return;
    }

    final String arg;
    if (_transportType == TransportType.unixSocket) {
      arg = _socketPath!;
    } else {
      arg = '${serverSocket.port}';
    }

    final homeDirPath = await appPath.homeDirPath;
    final environment = Map<String, String>.from(Platform.environment);
    environment['SAFE_PATHS'] = homeDirPath;

    final hooks = startHooksForTest;

    if (system.isWindows) {
      final probeService = hooks?.registerService;
      final serviceOk = probeService != null
          ? await probeService()
          : (await windows?.registerService() ?? false);
      if (serviceOk) {
        final startViaHelper = hooks?.startCore;
        final started = startViaHelper != null
            ? await startViaHelper(
                corePath: appPath.corePath,
                arg: arg,
                homeDir: homeDirPath,
              )
            : await helperClient.startCore(
                corePath: appPath.corePath,
                arg: arg,
                homeDir: homeDirPath,
              );
        if (started) {
          await _waitForCoreReady();
          isStarting = false;
          if (system.isWindows && globalState.config.appSetting.enableHighPriority) {
            unawaited(
              helperClient
                  .setProcessPriority(
                    '${AppIdentity.coreExecutableName}.exe',
                    true,
                  )
                  .catchError((e) {
                    commonPrint.log('Failed to set core process priority: $e');
                    return false;
                  }),
            );
          }
          return;
        }
        commonPrint.log(
          'Helper start core failed, falling back to normal mode',
        );
      }
    }

    final launchCore = hooks?.launchCore;
    if (launchCore != null) {
      await launchCore(appPath.corePath, arg, environment);
    } else {
      process = await Process.start(appPath.corePath, [
        arg,
      ], environment: environment);
      process?.stdout.listen((_) {});
      process?.stderr.listen((e) {
        final error = utf8.decode(e);
        if (error.isNotEmpty) commonPrint.log(error);
      });
    }
    await _waitForCoreReady();
    isStarting = false;
    if (system.isWindows && globalState.config.appSetting.enableHighPriority) {
      unawaited(
        helperClient
            .setProcessPriority('${AppIdentity.coreExecutableName}.exe', true)
            .catchError((e) {
              commonPrint.log('Failed to set core process priority: $e');
              return false;
            }),
      );
    }
  }

  Future<void> _waitForCoreReady() async {
    try {
      await socketCompleter.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      commonPrint.log('Core ready timeout after 5s');
    }
  }

  @override
  destroy() async {
    _isDestroying = true;
    _teardownRequested = true;
    // Acts on the ownership token, not on `serverCompleter`: awaiting a bind
    // that never completes used to hang destroy() forever, and awaiting one
    // that failed would rethrow the bind error out of a teardown path.
    await _releaseOwnedSocket();
    return true;
  }

  @override
  sendMessage(String message) async {
    if (_isDestroying || globalState.isExiting) {
      return;
    }
    final socket = await socketCompleter.future;
    try {
      final frame = FrameCodec.encode(message);
      socket.add(frame);
    } on SocketException catch (e) {
      if (_isDestroying || globalState.isExiting || isStarting) {
        commonPrint.log(
          'Ignored message send on closed socket during transition: $e',
        );
        return;
      }
      rethrow;
    } on StateError catch (e) {
      if (_isDestroying || globalState.isExiting || isStarting) {
        commonPrint.log(
          'Ignored message send on closed socket during transition: $e',
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> _deleteSocketFile() async {
    // Ownership gate: the file is unlinked only when *this* instance created
    // it. A failed bind, or a destroy() that raced a bind, therefore cannot
    // remove a path that belongs to another instance.
    if (!_ownsSocketFile) return;
    _ownsSocketFile = false;
    final path = _socketPath;
    if (_transportType != TransportType.unixSocket || path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Cleanup must never mask the error that led here.
      commonPrint.log('Failed to unlink socket file: $e');
    }
  }

  /// Closes the listener this instance owns and unlinks its socket file.
  ///
  /// It acts on [_server] / [_ownsSocketFile] — never on `serverCompleter` — so
  /// it cannot hang on a bind that never completes, and cannot rethrow the bind
  /// error out of a teardown path. Safe to call repeatedly.
  Future<void> _releaseOwnedSocket() async {
    final server = _server;
    _server = null;
    _listenerReleased = true;
    if (server != null) {
      try {
        await server.close();
      } catch (e) {
        commonPrint.log('Failed to close socket listener: $e');
      }
    }
    await _deleteSocketFile();
  }

  Future<void> _destroySocket() async {
    if (socketCompleter.isCompleted) {
      final lastSocket = await socketCompleter.future;
      await lastSocket.close();
      socketCompleter = Completer();
    }
  }

  @override
  shutdown() async {
    _isDestroying = true;
    if (system.isWindows) {
      await helperClient.stopCore();
    }
    await _destroySocket();
    process?.kill();
    process = null;
    // Closing the listener is what makes the socket file removable: on Windows
    // `ServerSocket.close()` does not unlink it. Only the listener this
    // instance actually bound is closed and unlinked.
    await _releaseOwnedSocket();
    return true;
  }

  Future<bool> checkCoreHealth({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_isDestroying || globalState.isExiting || isStarting) return false;
    if (!socketCompleter.isCompleted) return false;
    try {
      final result = await invoke<bool>(
        method: ActionMethod.getIsInit,
        timeout: timeout,
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> preload() async {
    await serverCompleter.future;
    return true;
  }
}

final clashService = system.isDesktop ? ClashService() : null;
