import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/external_control.dart';
import 'package:fluxora/utils/platform_check.dart';
// Test-only: both are transitive dependencies of `path_provider`. `AppPath`
// resolves its temp/download dirs through it, and the platform interface throws
// before any channel mock can answer in a VM test.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// R7-15.5 — `ExternalControl` socket ownership.
///
/// The control channel lives at a **fixed** path (`<dataDir>/Fluxora.control.sock`)
/// because other processes have to find it. That path used to be unlinked
/// unconditionally before the bind, and again in `stop()`, with no ownership
/// check at all — so a second instance sharing a data directory always cut the
/// first one's channel (a 100% collision, unlike the core socket's 1-in-10000).
///
/// The fix is a sidecar lock file plus an OS-level exclusive lock. Ownership is
/// taken **before** anything is deleted or bound, and the files are unlinked
/// **while the lock is still held**.
///
/// The multi-instance tests spawn a real second OS process
/// (`test/common/support/control_lock_holder.dart`). Two Dart objects in one VM
/// would not be evidence: POSIX `fcntl` locks are per-process, so an in-process
/// "second instance" can succeed where a real process cannot.
void main() {
  // `AppPath`'s constructor kicks off `getTemporaryDirectory()` for its temp
  // dir, which needs a platform channel; without a binding that surfaces as an
  // unhandled async error in whichever test touches `appPath` first.
  TestWidgetsFlutterBinding.ensureInitialized();

  late String lockPath;
  late String socketPath;
  late String portPath;
  late bool udsSupported;

  final holders = <_LockHolder>[];

  late Directory pathProviderSandbox;

  setUpAll(() async {
    // Must precede the first `appPath` read: `AppPath._internal()` calls
    // `getTemporaryDirectory()` / `getDownloadsDirectory()` eagerly, and the
    // latter throws "only available on macOS" on any other platform.
    pathProviderSandbox = Directory.systemTemp.createTempSync(
      'fluxora_r7155_path_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      pathProviderSandbox,
    );
    udsSupported = await PlatformChecker.checkUnixSocketSupport();
  });

  tearDownAll(() async {
    try {
      await pathProviderSandbox.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    System.platformOverride = 'linux';
    lockPath = await appPath.controlLockFilePath;
    socketPath = await appPath.controlSocketPath;
    portPath = await appPath.controlPortFilePath;

    // Never delete the lock file: a fresh inode would defeat the whole scheme.
    for (final path in [socketPath, portPath]) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
  });

  tearDown(() async {
    // P7-B3-A: hand the lock back through the protocol, not by killing the
    // shell. A surviving grandchild would keep `Fluxora.control.lock` open and
    // make the sandbox undeletable at `tearDownAll`.
    for (final holder in holders) {
      try {
        await holder.release();
      } catch (_) {
        try {
          holder.process.kill();
        } catch (_) {}
      }
    }
    holders.clear();
    try {
      await ExternalControl.stop();
    } catch (_) {}
    System.platformOverride = null;
    IOOverrides.global = null;
  });

  /// Spawns the helper in a separate process and waits until it holds the lock.
  ///
  /// P7-B3-A: the helper now releases on an explicit `RELEASE` line instead of
  /// sleeping for a fixed time. [watchdog] is only a crash backstop — the normal
  /// path never waits for it.
  Future<_LockHolder> holdLockInAnotherProcess({
    Duration watchdog = const Duration(minutes: 2),
  }) async {
    final script = File(
      'test/common/support/control_lock_holder.dart',
    ).absolute.path;
    final process = await Process.start('dart', [
      script,
      lockPath,
      '${watchdog.inMilliseconds}',
    ], runInShell: true);

    // The helper prints `LOCKED` when it got the lock, `BUSY` when someone else
    // holds it. Reporting the actual token turns "the lock was leaked" into a
    // readable assertion instead of a 20 s timeout.
    final settled = Completer<String>();
    final released = Completer<void>();
    process.stdout
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final token = line.trim();
          if ((token == 'LOCKED' || token == 'BUSY') && !settled.isCompleted) {
            settled.complete(token);
          }
          // Printed by the **real** child, not the shell: receiving it is what
          // proves the process that held the lock actually ran to completion.
          if (token == 'RELEASED' && !released.isCompleted) {
            released.complete();
          }
        });
    final result = await settled.future.timeout(const Duration(seconds: 20));
    expect(
      result,
      'LOCKED',
      reason: 'a second process must be able to take the control lock',
    );

    final holder = _LockHolder(process, released.future);
    holders.add(holder);
    return holder;
  }

  group('single instance', () {
    test('start() takes the lock and binds; stop() releases but keeps the lock '
        'file', () async {
      await ExternalControl.start();

      expect(
        File(lockPath).existsSync(),
        isTrue,
        reason: 'the ownership token must exist while the channel is up',
      );
      if (udsSupported) {
        expect(
          FileSystemEntity.typeSync(socketPath),
          isNot(FileSystemEntityType.notFound),
          reason: 'the control socket should be listening',
        );
      }

      await ExternalControl.stop();

      expect(
        File(lockPath).existsSync(),
        isTrue,
        reason:
            'the lock file must survive stop() - a new inode would let two '
            'processes lock different files and both think they own the channel',
      );
      if (udsSupported) {
        expect(
          FileSystemEntity.typeSync(socketPath),
          FileSystemEntityType.notFound,
          reason: 'the owner removes its own socket',
        );
      }
    });

    test('repeated start/stop cycles keep working', () async {
      for (var i = 0; i < 3; i++) {
        await ExternalControl.start();
        if (udsSupported) {
          expect(
            FileSystemEntity.typeSync(socketPath),
            isNot(FileSystemEntityType.notFound),
            reason: 'cycle $i: bound',
          );
        }
        await ExternalControl.stop();
        if (udsSupported) {
          expect(
            FileSystemEntity.typeSync(socketPath),
            FileSystemEntityType.notFound,
            reason: 'cycle $i: released',
          );
        }
      }
    });

    test('a stale socket from a crash is cleared by the new owner', () async {
      if (!udsSupported) return;

      // A leftover file with nothing listening behind it — exactly what a killed
      // process leaves.
      File(socketPath).writeAsStringSync('stale');

      await ExternalControl.start();

      expect(
        FileSystemEntity.typeSync(socketPath),
        isNot(FileSystemEntityType.notFound),
        reason: 'the new owner replaces the stale file with a live socket',
      );
    });

    test('a failed bind releases the lock again', () async {
      IOOverrides.global = _FailingBind();

      await expectLater(
        ExternalControl.start(),
        throwsA(isA<SocketException>()),
        reason: 'both transports failed, so start() must surface the error',
      );

      // If the lock had leaked, this second start would silently decline.
      IOOverrides.global = null;
      await ExternalControl.start();

      expect(
        File(lockPath).existsSync(),
        isTrue,
        reason: 'ownership was re-acquired after the failure',
      );
      if (udsSupported) {
        expect(
          FileSystemEntity.typeSync(socketPath),
          isNot(FileSystemEntityType.notFound),
        );
      }
    });

    test('an exception after taking the lock frees it for another process',
        () async {
      // `start()` throws after the lock was already taken. If the release were
      // skipped, the lock would stay held for the rest of this process's life
      // and no later instance - in this process or another one - could ever take
      // the control channel.
      IOOverrides.global = _FailingBind();
      await expectLater(
        ExternalControl.start(),
        throwsA(isA<SocketException>()),
      );
      IOOverrides.global = null;

      // A **real second OS process** must be able to take it.
      final holder = await holdLockInAnotherProcess();
      expect(
        holders.contains(holder),
        isTrue,
        reason: 'the holder really ran as a separate process',
      );
      expect(holder.process.pid, greaterThan(0));
      await holder.release();
    });

    test('transport selection happens inside the ownership try', () {
      // `getRecommendedTransport()` is not side-effect free (it probes AF_UNIX by
      // binding a throwaway socket on Windows) and it cannot be made to throw
      // from a test, so the ordering is guarded structurally: if the call ever
      // moves back above the `try`, the lock leaks on that path again.
      final source = File(
        'lib/common/external_control.dart',
      ).readAsStringSync();

      final acquired = source.indexOf('await _acquireOwnership()');
      final transport = source.indexOf(
        'PlatformChecker.getRecommendedTransport()',
      );
      final released = source.indexOf('await _releaseOwnership();', transport);

      expect(acquired, greaterThan(-1));
      expect(
        transport,
        greaterThan(acquired),
        reason: 'ownership must be taken before the transport is selected',
      );
      expect(
        released,
        greaterThan(transport),
        reason:
            'the release must come after transport selection, i.e. the call has '
            'to sit inside the try',
      );
    });

    test('a failure after the bind closes the listener and frees the lock',
        () async {
      // The bind "succeeds" but the listener cannot be consumed, which is what a
      // half-initialised channel looks like. Without the unwind, `_server` would
      // stay set — so every later `start()` returns immediately at the
      // `_server != null` guard — and the listener would stay open.
      final bind = _HalfBoundBind();
      IOOverrides.global = bind;

      await expectLater(
        ExternalControl.start(),
        throwsA(isA<StateError>()),
        reason: 'the listener could not be consumed, so start() must fail',
      );

      IOOverrides.global = null;

      expect(bind.created, isNotEmpty);
      for (final server in bind.created) {
        expect(
          server.closed,
          isTrue,
          reason:
              'every listener bound during the failed attempt must be closed, '
              'including the one the TCP fallback replaced',
        );
      }

      // `_server` was reset and the lock handed back, so a fresh start works.
      await ExternalControl.start();
      expect(File(lockPath).existsSync(), isTrue);
      if (udsSupported) {
        expect(
          FileSystemEntity.typeSync(socketPath),
          isNot(FileSystemEntityType.notFound),
          reason: 'the retry must end up with a live channel',
        );
      }
    });

    test('a REAL uds bound then failed to listen is unlinked and closed',
        () async {
      // P7-B1 / A4': the test above hands out a *fake* `ServerSocket`, so it
      // proves the listener is closed but never touches a real file. This one
      // binds a real AF_UNIX socket through the OS, faults only `listen()`, and
      // then checks the actual file and the actual listener.
      expect(
        udsSupported,
        isTrue,
        reason:
            'this test needs a real AF_UNIX bind, so it must not silently skip',
      );

      final bind = _RealUdsHalfBoundBind(socketPath);
      IOOverrides.global = bind;

      // `start()` takes the lock, binds a real UDS (the file appears), throws in
      // `_listen()`, then `_discardBoundListener()` unlinks that file and closes
      // that listener before falling back to TCP.
      await ExternalControl.start();

      IOOverrides.global = null;

      expect(bind.udsBinds, 1, reason: 'the Unix Socket branch really ran');
      expect(bind.tcpBinds, 1, reason: 'the TCP fallback really ran');
      expect(
        bind.typeAfterBind,
        FileSystemEntityType.unixDomainSock,
        reason: 'the OS must report a real Unix-domain socket at that path',
      );
      expect(bind.faulted, hasLength(1));
      expect(
        bind.faulted.single.closed,
        isTrue,
        reason: 'the real listener must be closed, not leaked',
      );
      expect(
        FileSystemEntity.typeSync(socketPath),
        FileSystemEntityType.notFound,
        reason: 'the half-bound socket file must be unlinked',
      );

      // The TCP channel that survived the fault is still a usable one.
      await ExternalControl.stop();
      expect(
        FileSystemEntity.typeSync(socketPath),
        FileSystemEntityType.notFound,
        reason: 'stop() must not resurrect the file',
      );
    });
  });

  group('non-owner', () {
    test('stop() without ownership leaves the control socket alone', () async {
      if (!udsSupported) return;

      // Somebody else's socket.
      File(socketPath).writeAsStringSync('not ours');

      await ExternalControl.stop();

      expect(
        FileSystemEntity.typeSync(socketPath),
        isNot(FileSystemEntityType.notFound),
        reason: 'a process that never owned the channel must not unlink it',
      );
    });
  });

  group('two real OS processes', () {
    test('a foreign holder blocks start(); RELEASE hands the lock over',
        () async {
      if (!udsSupported) return;

      File(socketPath).writeAsStringSync('first instance');

      // 1) A real second OS process takes the lock.
      final first = await holdLockInAnotherProcess();
      expect(first.process.pid, greaterThan(0));

      // 2) While it holds the lock this instance must decline before touching
      // the path, and a non-owner stop() must not clean it up either.
      await ExternalControl.start();
      expect(
        FileSystemEntity.typeSync(socketPath),
        isNot(FileSystemEntityType.notFound),
        reason: 'the second instance must not delete the first one\'s socket',
      );
      expect(
        File(socketPath).readAsStringSync(),
        'first instance',
        reason: 'the file must be untouched, not replaced',
      );
      await ExternalControl.stop();
      expect(File(socketPath).readAsStringSync(), 'first instance');

      // 3) The lock sidecar is never deleted or replaced — not even while the
      // lock is held and handed over.
      expect(
        File(lockPath).existsSync(),
        isTrue,
        reason: 'the sidecar must survive the whole handover',
      );

      // 4) Explicit RELEASE. `release()` waits for the `RELEASED` line, which
      // only the real `dart` child can print — that is what proves the process
      // holding the lock ran to completion, not just the shell around it.
      await first.release();

      // 5) A *second* independent process can now take the same lock file. This
      // is only possible if the first one really let go of it.
      final second = await holdLockInAnotherProcess();
      expect(second.process.pid, isNot(first.process.pid));

      // 6) And this instance can own the channel again.
      await ExternalControl.start();
      expect(
        FileSystemEntity.typeSync(socketPath),
        isNot(FileSystemEntityType.notFound),
        reason: 'the survivor now owns the channel',
      );

      await second.release();
      expect(
        File(lockPath).existsSync(),
        isTrue,
        reason: 'the sidecar is never removed by the handover',
      );
    });
  });
}

/// Fails every `ServerSocket.bind`, so `start()` has to unwind its lock.
final class _FailingBind extends IOOverrides {
  @override
  Future<ServerSocket> serverSocketBind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
  }) async {
    throw const SocketException('bind blocked for test');
  }
}

/// Redirects every `path_provider` call into a sandbox directory.
///
/// Same shape as `_FakePathProviderPlatform` in
/// `test/views/layout_overflow_repro_test.dart`.
class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform(this.dir);

  final Directory dir;

  @override
  Future<String?> getTemporaryPath() async => dir.path;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;

  @override
  Future<String?> getLibraryPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getExternalStoragePath() async => dir.path;

  @override
  Future<List<String>?> getExternalCachePaths() async => [dir.path];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [dir.path];

  @override
  Future<String?> getDownloadsPath() async => dir.path;
}

/// A `ServerSocket` that binds fine but throws when someone starts listening.
///
/// Models a channel that got past the bind and then failed — the state where
/// `_server` is already set, so a missing unwind both leaks the listener and
/// makes every later `start()` a no-op.
final class _BoundButUnlistenable implements ServerSocket {
  bool closed = false;

  @override
  StreamSubscription<Socket> listen(
    void Function(Socket event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    throw StateError('listen failed for test');
  }

  @override
  Future<ServerSocket> close() async {
    closed = true;
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Hands out [_BoundButUnlistenable] instances instead of real listeners.
final class _HalfBoundBind extends IOOverrides {
  final List<_BoundButUnlistenable> created = <_BoundButUnlistenable>[];

  @override
  Future<ServerSocket> serverSocketBind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
  }) async {
    final server = _BoundButUnlistenable();
    created.add(server);
    return server;
  }
}

/// A **real** bound listener whose `listen()` throws.
///
/// `close()` is delegated to the real socket, so the production cleanup closes a
/// real listener; the wrapper only refuses to be consumed.
final class _RealUdsHalfBound implements ServerSocket {
  _RealUdsHalfBound(this._real);

  final ServerSocket _real;
  bool closed = false;

  @override
  StreamSubscription<Socket> listen(
    void Function(Socket event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    throw StateError('listen failed for test');
  }

  @override
  Future<ServerSocket> close() {
    closed = true;
    return _real.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Performs the **real** bind and faults only the Unix-domain branch.
///
/// `super.serverSocketBind` reaches the native implementation, so the UDS file
/// on disk is genuine and the TCP fallback binds normally — the fault injection
/// never replaces the socket itself.
final class _RealUdsHalfBoundBind extends IOOverrides {
  _RealUdsHalfBoundBind(this.socketPath);

  final String socketPath;

  final List<_RealUdsHalfBound> faulted = <_RealUdsHalfBound>[];
  int udsBinds = 0;
  int tcpBinds = 0;

  /// What the OS reported at the socket path right after the bind returned.
  FileSystemEntityType? typeAfterBind;

  @override
  Future<ServerSocket> serverSocketBind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
  }) async {
    final real = await super.serverSocketBind(
      address,
      port,
      backlog: backlog,
      v6Only: v6Only,
      shared: shared,
    );

    final isUds =
        address is InternetAddress &&
        address.type == InternetAddressType.unix;
    if (!isUds) {
      tcpBinds++;
      return real;
    }

    udsBinds++;
    typeAfterBind = FileSystemEntity.typeSync(socketPath);
    final wrapper = _RealUdsHalfBound(real);
    faulted.add(wrapper);
    return wrapper;
  }
}

/// A lock-holding child process plus the explicit release handshake.
///
/// P7-B3-A: `kill()` alone is not enough here. `Process.start(..., runInShell:
/// true)` puts a shell between the test and the real `dart` child, so the shell's
/// `exitCode` says nothing about the process that actually holds the lock. This
/// wrapper drives the `RELEASE` -> `RELEASED` -> exit sequence instead.
final class _LockHolder {
  _LockHolder(this.process, this._released);

  final Process process;
  final Future<void> _released;

  /// Sends `RELEASE` and waits until the child has unlocked, closed its handle,
  /// printed `RELEASED` and exited.
  Future<void> release() async {
    process.stdin.writeln('RELEASE');
    await process.stdin.flush();
    await _released.timeout(const Duration(seconds: 30));
    await process.exitCode.timeout(const Duration(seconds: 30));
  }
}
