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
    this.stopCore,
    this.killProcess,
    this.awaitExit,
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

  /// Stands in for `helperClient.stopCore(...)`.
  ///
  /// P9-S06 — without this, the ownership gate could only be tested by talking
  /// to a real helper.
  final Future<bool> Function()? stopCore;

  /// Stands in for `Process.kill(...)`. `force` is the sigkill escalation.
  final Future<void> Function(Process process, bool force)? killProcess;

  /// Stands in for `process.exitCode` — must **throw** `TimeoutException` when
  /// the process has not exited, never return a sentinel value.
  final Future<int> Function(Process process)? awaitExit;

  /// Stands in for `Process.start(...)` **and** the two stdio listeners after it.
  final Future<void> Function(
    String corePath,
    String arg,
    Map<String, String> environment,
  )?
  launchCore;
}

/// Where the core image for this start comes from.
///
/// SEC-P0-01 — the helper runs as LocalSystem and now refuses any core outside
/// its own (protected) directory, so the two launch modes need two different
/// paths:
///
/// * **helper** — `%ProgramFiles%\Fluxora\Service\FluxoraCore.exe`, the copy the
///   install step verified against the build anchor.
/// * **direct** — the bundle copy beside the app, run under the user's own
///   token. That one is user-writable by design and grants nothing extra.
class CoreLaunchPlan {
  const CoreLaunchPlan._(this.helper, this.path);

  const CoreLaunchPlan.helper(String path) : this._(true, path);

  const CoreLaunchPlan.direct(String path) : this._(false, path);

  /// True when the image is started by the LocalSystem helper.
  final bool helper;
  final String path;

  @override
  String toString() => 'CoreLaunchPlan(helper=$helper, path="$path")';
}

/// Pure decision for [CoreLaunchPlan], so the rule can be tested without a
/// socket, a helper, or a Windows host.
///
/// The helper is only used when a protected core path can actually be resolved.
/// Sending it the bundle path instead would be a guaranteed rejection, and
/// "ask the helper, get refused, fall back" is a worse outcome than "do not ask"
/// — it also means the app never *tries* to have SYSTEM run a user-writable
/// image.
CoreLaunchPlan planCoreLaunch({
  required bool isWindows,
  required bool serviceOk,
  required String? protectedCorePath,
  required String bundleCorePath,
}) {
  if (!isWindows || !serviceOk) return CoreLaunchPlan.direct(bundleCorePath);
  if (protectedCorePath == null || protectedCorePath.isEmpty) {
    return CoreLaunchPlan.direct(bundleCorePath);
  }
  return CoreLaunchPlan.helper(protectedCorePath);
}

class ClashService extends ClashHandlerInterface {
  static ClashService? _instance;

  Completer<ServerSocket> serverCompleter = Completer();

  Completer<Socket> socketCompleter = Completer();

  bool isStarting = false;

  /// The error from the most recent failed core start, or `null` after a
  /// successful one.
  ///
  /// P9-S04 — `preload()` deliberately reports **transport readiness only**, so
  /// this is the only way a caller (or the UI) learns that the core itself never
  /// came up. Set by [reStart], cleared when a start succeeds.
  Object? lastStartFailure;

  /// P9-S06 — did **this instance** get its core started through the helper?
  ///
  /// Only that grants the right to send `core.stop`: the helper owns a single
  /// global core (`services/helper/src/ops.rs`), so an instance that spawned its
  /// own process must never stop someone else's.
  ///
  /// This is a client-side claim, not server-side session ownership. It cannot
  /// fix two old-version instances racing over the helper's one core — see
  /// `PHASE_09_P9_S06_CORE_OWNERSHIP_FIX_REPORT.md`.
  bool _coreStartedViaHelper = false;

  @visibleForTesting
  bool get coreStartedViaHelperForTest => _coreStartedViaHelper;

  @visibleForTesting
  set coreStartedViaHelperForTest(bool value) => _coreStartedViaHelper = value;

  /// Test entry point for the failed-start cleanup.
  @visibleForTesting
  Future<bool> abortFailedStartForTest({required bool viaHelper}) =>
      _abortFailedStart(viaHelper: viaHelper);
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

  /// Whether this instance actually talks to the core over AF_UNIX.
  ///
  /// Windows is excluded even if a transport value says otherwise: `afunix.sys`
  /// bugchecks when a Unix-domain socket handle is torn down at process exit
  /// (`0xD1` in `AfUnixTlConnectEndpointDisconnect`). `getRecommendedTransport()`
  /// already refuses it there — this keeps a future regression from reaching the
  /// bind, and keeps the core argument in step with the listener we really bind.
  bool get _useUnixSocket =>
      _transportType == TransportType.unixSocket && !Platform.isWindows;

  Future<void> _initTransport() async {
    if (skipTransportForTest) return;

    _transportType = await PlatformChecker.getRecommendedTransport();

    if (_useUnixSocket) {
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
        // P9-S04 — `preload()` only waits for the socket to bind, so this is the
        // first moment the app can tell the user the core itself never came up.
        // Mirrors the bind-failure path just above.
        if (!_isDestroying && !globalState.isExiting) {
          try {
            globalState.showNotifier(e.toString());
          } catch (_) {
            // No binding (unit tests, headless contexts). The log above already
            // carries the failure, and a notification must never turn a start
            // failure into an unhandled async error.
          }
        }
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
    if (_useUnixSocket) {
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
    _ownsSocketFile = _useUnixSocket;
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
      lastStartFailure = null;
    } catch (e) {
      // P9-S04 — the single funnel for every start path, so the failure is
      // recorded here rather than at one call site. `preload()` only reports
      // transport readiness, so without this a dead core is invisible to the
      // UI and to tests.
      lastStartFailure = e;
      rethrow;
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
    // P9-S07 — a helper-owned core has no `Process` handle, so the kill below
    // cannot reach it. Stop it through the helper *before* dropping the claim;
    // a failed stop keeps the claim so `shutdown()` can retry instead of
    // silently leaking the process.
    if (system.isWindows && _coreStartedViaHelper) {
      final stopped = await _stopHelperCore();
      if (!stopped) {
        // P9-S08 — starting now would leave two cores alive with only one of
        // them tracked, and the untracked one could never be stopped. Refuse,
        // keep the claim so a later attempt can retry the stop.
        isStarting = false;
        throw StateError(
          'Previous helper core not confirmed stopped; refusing to start another',
        );
      }
      _coreStartedViaHelper = false;
    } else {
      // Every other start begins with no claim; only the helper branch grants
      // one, so a direct `Process.start` never inherits the previous start's.
      _coreStartedViaHelper = false;
    }

    await _destroySocket();

    // P9-S09 — the previous direct core is reaped through the same confirmed
    // path as a failed start. The old code used `onTimeout: () => -1` and then
    // dropped the handle, so "still running" was recorded as "exited".
    final previous = process;
    if (previous != null) {
      if (await _reapDirectCore(previous)) {
        process = null;
      } else {
        isStarting = false;
        throw StateError(
          'Previous core process not confirmed exited; refusing to start another',
        );
      }
    }

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
    if (_useUnixSocket) {
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

      final plan = planCoreLaunch(
        isWindows: true,
        serviceOk: serviceOk,
        protectedCorePath: appPath.protectedCorePath,
        bundleCorePath: appPath.corePath,
      );

      if (plan.helper) {
        final startViaHelper = hooks?.startCore;
        final started = startViaHelper != null
            ? await startViaHelper(
                corePath: plan.path,
                arg: arg,
                homeDir: homeDirPath,
              )
            : await helperClient.startCore(
                corePath: plan.path,
                arg: arg,
                homeDir: homeDirPath,
              );
        if (started) {
          // P9-S06 — ownership is granted here and only here: the helper
          // accepted `core.start` for this instance.
          _coreStartedViaHelper = true;
          try {
            await _ensureCoreReadyOrThrow();
          } catch (_) {
            // The helper launched a core that never connected — tell it to stop
            // or the process outlives the failed start. The claim is dropped
            // only if that stop is confirmed.
            final stopped = await _abortFailedStart(viaHelper: true);
            if (stopped) {
              _coreStartedViaHelper = false;
            }
            rethrow;
          }
          isStarting = false;
          if (system.isWindows &&
              globalState.config.appSetting.enableHighPriority) {
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
        // The helper refused the start. The claim is **not** granted: the
        // fallback below runs the core under the user's own token, and nothing
        // in this process may believe a SYSTEM-owned core is running.
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
    try {
      await _ensureCoreReadyOrThrow();
    } catch (_) {
      // We started this process; a core that never connects must not linger.
      await _abortFailedStart(viaHelper: false);
      rethrow;
    }
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

  /// How long a freshly launched core gets to connect back.
  ///
  /// Test-only knob: the production budget is 5 s, which no test should wait
  /// for. Shrinking it is the only way to exercise the timeout branch without a
  /// real core binary.
  @visibleForTesting
  static Duration coreReadyTimeout = const Duration(seconds: 5);

  /// P9B-D2 — a core that never connects is a **failure**, not a log line.
  ///
  /// This used to swallow the timeout and return normally, so `_doRestart()`
  /// reported a successful start while `socketCompleter` was still pending. The
  /// fault then surfaced 5–30 s later as an unrelated IPC timeout. It now
  /// returns `false` and the caller turns that into a thrown error.
  Future<bool> _waitForCoreReady() async {
    try {
      await socketCompleter.future.timeout(coreReadyTimeout);
      return true;
    } catch (_) {
      commonPrint.log(
        'Core ready timeout after ${coreReadyTimeout.inMilliseconds} ms',
      );
      return false;
    }
  }

  /// Fails the start when the core never becomes ready, and resets
  /// [isStarting] on the way out so the next attempt is not blocked.
  Future<void> _ensureCoreReadyOrThrow() async {
    if (await _waitForCoreReady()) return;
    isStarting = false;
    throw StateError(
      'Core did not become ready within '
      '${coreReadyTimeout.inMilliseconds} ms',
    );
  }

  /// Test seam: drives the real readiness gate without spawning a core.
  @visibleForTesting
  Future<void> ensureCoreReadyOrThrowForTest() => _ensureCoreReadyOrThrow();

  /// P9-S04 — a failed start must not leave a core behind.
  ///
  /// The helper branch has no `Process` handle (the helper owns the child), so
  /// the only way to reap it is `core.stop`. The direct branch owns the handle
  /// and kills it here.
  /// Sends `core.stop` through the test hook when one is installed.
  ///
  /// P9-S07 — returns `true` **only** when the stop was confirmed. The caller
  /// uses that to decide whether the ownership claim may be dropped: a failed
  /// stop must never be recorded as cleaned up, or the orphan core can never be
  /// retried.
  Future<bool> _stopHelperCore() async {
    final hooks = startHooksForTest;
    if (hooks != null) {
      final hook = hooks.stopCore;
      if (hook == null) {
        // P9-S08 — a test installed hooks but no `stopCore`. Falling back to the
        // real client would reach this machine's helper pipe, so fail closed
        // instead. Production never has hooks, so it always takes the path below.
        commonPrint.log(
          'stopCore hook missing; refusing to touch the real helper',
        );
        return false;
      }
      try {
        return await hook();
      } catch (e) {
        commonPrint.log('core.stop failed: $e');
        return false;
      }
    }

    try {
      return await helperClient.stopCore();
    } catch (e) {
      commonPrint.log('core.stop failed: $e');
      return false;
    }
  }

  Future<bool> _abortFailedStart({required bool viaHelper}) async {
    if (viaHelper) {
      return _stopHelperCore();
    }

    final launched = process;
    if (launched == null) return true;
    // P9-S09 — drop the handle only when the exit is confirmed. Keeping it lets
    // `shutdown()` retry instead of losing the only way to reach the process.
    final reaped = await _reapDirectCore(launched);
    if (reaped) process = null;
    return reaped;
  }

  /// Kills [launched] and **confirms** it exited.
  ///
  /// P9-S08 — a timeout is not confirmation. The sigkill escalation gets its own
  /// budget, and if that also produces no exit code the answer is `false`, so the
  /// caller never records an unconfirmed cleanup as done.
  Future<bool> _reapDirectCore(Process launched) async {
    final hooks = startHooksForTest;

    Future<void> kill(bool force) async {
      final hook = hooks?.killProcess;
      if (hook != null) {
        await hook(launched, force);
        return;
      }
      launched.kill(force ? ProcessSignal.sigkill : ProcessSignal.sigterm);
    }

    Future<int> awaitExit() async {
      final hook = hooks?.awaitExit;
      if (hook != null) return hook(launched);
      return launched.exitCode.timeout(const Duration(seconds: 2));
    }

    try {
      await kill(false);
      await awaitExit();
      return true;
    } on TimeoutException {
      // Still running — escalate below.
    } catch (e) {
      commonPrint.log('Failed to reap the core after a failed start: $e');
      return false;
    }

    try {
      await kill(true);
      await awaitExit();
      return true;
    } catch (e) {
      commonPrint.log('Core still not reaped after sigkill: $e');
      return false;
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
    if (system.isWindows && _coreStartedViaHelper) {
      // P9-S06 — only the instance that got its core started *through* the
      // helper may stop it. The helper owns one global core, so a direct
      // `Process.start` instance that sent `core.stop` would kill someone
      // else's.
      await _stopHelperCore();
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
