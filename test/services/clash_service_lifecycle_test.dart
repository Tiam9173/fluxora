import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/service.dart';
import 'package:fluxora/common/common.dart';

/// `ClashService` socket lifecycle — R7-6 teardown bookkeeping + R7-15.1
/// ownership, bind-failure propagation and multi-instance safety.
///
/// `ClashService._internal()` starts `_initTransport()` unawaited, and that path
/// binds `<systemTemp>\Fluxora_<unique>.sock` and spawns the core.
///
/// Three things used to be wrong (see
/// `PHASE_06_8_R7_15_SOCKET_LIFECYCLE_AUDIT_REPORT.md`):
///
///  * the file name was `Fluxora_<0..9999>.sock`, so two processes could pick
///    the same one;
///  * the bind path **unlinked** that name first, unconditionally — a collision
///    therefore deleted the other instance's live socket;
///  * a failed bind never completed `serverCompleter`, so `preload()` waited
///    forever and the app never finished starting.
///
/// What is pinned here: instance-unique names, exclusive bind, ownership-gated
/// unlink, and an error path that reaches every waiter.
///
/// Two seams make a real bind observable without launching a core:
///  * [ClashService.skipCoreSpawnForTest] — bind for real, stop before
///    `Process.start` (which cannot be faked);
///  * [ClashService.resetForTest] — drop the singleton so the next
///    `ClashService()` binds again.
///
/// Bind failures and slow binds are injected with `IOOverrides.serverSocketBind`
/// (the SDK's own hook, `dart-sdk/lib/io/socket.dart:343`), so no production
/// seam exists for them.
void main() {
  // `_initServer`'s error handler calls `globalState.showNotifier`, which reads
  // `WidgetsBinding.instance`. Without a binding the bind-failure path throws
  // from the error handler instead of from the bind.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every `Fluxora_*.sock` **this process** created in the system temp dir.
  ///
  /// Deliberately **not** `whereType<File>()`: on Windows a bound AF_UNIX socket
  /// is a reparse point, so `listSync` reports it as `Link` even though
  /// `File(path).existsSync()` is `true` (`entityType` is `unixDomainSock`).
  ///
  /// Scoped to this pid because `flutter test` runs test **files** in parallel:
  /// another file binding its own `Fluxora_<otherPid>_…sock` would otherwise be
  /// counted here. Every caller only ever asks for the sockets this process
  /// made (`difference(before)`), and `decoy()` already builds a pid-scoped
  /// name, so the filter matches what the assertions actually mean.
  Set<String> socketFiles() => Directory.systemTemp
      .listSync(followLinks: false)
      .map((e) => e.path)
      .where(
        (p) =>
            p.endsWith('.sock') &&
            p.split(Platform.pathSeparator).last.startsWith('Fluxora_${pid}_'),
      )
      .toSet();

  File decoy(String suffix) => File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'Fluxora_${pid}_0_$suffix.sock',
  );

  ClashService? service;

  setUp(() {
    ClashService.resetForTest();
    ClashService.skipTransportForTest = false;
    ClashService.skipCoreSpawnForTest = true;
    // Keeps `shutdown()` off the Windows helper path (`helperClient.stopCore`),
    // which would try to reach the HelperService named pipe.
    System.platformOverride = 'linux';
  });

  tearDown(() async {
    final s = service;
    service = null;
    if (s != null) {
      try {
        await s.destroy();
      } catch (_) {
        // Best effort: the test already asserted what it needed.
      }
    }
    IOOverrides.global = null;
    ClashService.resetForTest();
    ClashService.skipCoreSpawnForTest = false;
    ClashService.skipTransportForTest = true;
    System.platformOverride = null;
  });

  /// Constructs the service and waits until the bind settled.
  Future<ClashService> startService() async {
    final s = ClashService();
    service = s;
    await s.preload();
    return s;
  }

  group('socket name uniqueness', () {
    test('socketFileName() never repeats and carries the pid', () {
      final names = {for (var i = 0; i < 64; i++) ClashService.socketFileName()};

      expect(names.length, 64, reason: 'a repeated name is a collision');
      for (final name in names) {
        expect(name, startsWith('Fluxora_${pid}_'));
        expect(name, endsWith('.sock'));
        // Kept short enough for the platform limits (Linux 108 / macOS 104).
        expect(name.length, lessThan(48));
      }
    });

    test('two consecutive instances bind different files', () async {
      final before = socketFiles();

      final first = await startService();
      final firstFiles = socketFiles().difference(before);
      expect(firstFiles.length, 1);
      await first.destroy();

      ClashService.resetForTest();
      service = null;

      await startService();
      final secondFiles = socketFiles().difference(before);
      expect(secondFiles.length, 1);
      expect(
        secondFiles.single,
        isNot(firstFiles.single),
        reason: 'each instance must get its own path',
      );
    });
  });

  group('bind failure', () {
    test('reaches preload() as the original error instead of hanging', () async {
      IOOverrides.global = _FailingBind();

      final s = ClashService();
      service = s;

      await expectLater(
        s.preload().timeout(const Duration(seconds: 5)),
        throwsA(isA<SocketException>()),
        reason: 'a failed bind must fail the waiter, not park it forever',
      );
    });

    test('does not delete an unrelated socket file', () async {
      final foreign = decoy('99');
      await foreign.create(recursive: true);
      addTearDown(() {
        if (foreign.existsSync()) foreign.deleteSync();
      });

      IOOverrides.global = _FailingBind();
      final s = ClashService();
      service = s;
      await expectLater(s.preload(), throwsA(isA<SocketException>()));

      expect(
        foreign.existsSync(),
        isTrue,
        reason: 'a failed bind must never unlink a path it does not own',
      );
    });

    test('destroy() after a failed bind returns instead of rethrowing', () async {
      IOOverrides.global = _FailingBind();
      final s = ClashService();
      service = s;
      await expectLater(s.preload(), throwsA(isA<SocketException>()));

      IOOverrides.global = null;
      expect(
        await Future<bool>.value(s.destroy()).timeout(const Duration(seconds: 5)),
        isTrue,
        reason: 'teardown must not rethrow the bind error',
      );
    });
  });

  group('teardown ownership', () {
    test('shutdown() unlinks the socket it created', () async {
      final before = socketFiles();
      final s = await startService();

      final mine = socketFiles().difference(before);
      expect(mine.length, 1);
      expect(File(mine.single).existsSync(), isTrue);

      expect(await s.shutdown(), isTrue);
      expect(
        File(mine.single).existsSync(),
        isFalse,
        reason: 'shutdown must remove its own socket file',
      );
    });

    test('shutdown() leaves another instance\'s socket alone', () async {
      final foreign = decoy('98');
      await foreign.create(recursive: true);
      addTearDown(() {
        if (foreign.existsSync()) foreign.deleteSync();
      });

      final before = socketFiles();
      final s = await startService();
      final mine = socketFiles().difference(before);
      expect(mine.length, 1);

      await s.shutdown();

      expect(File(mine.single).existsSync(), isFalse);
      expect(
        foreign.existsSync(),
        isTrue,
        reason: 'only the owned path may be unlinked',
      );
    });

    test('destroy() is idempotent on a bound service', () async {
      final s = await startService();

      expect(await s.destroy(), isTrue);
      expect(await s.destroy(), isTrue);
    });
  });

  group('destroy during a pending bind', () {
    test('destroy() returns without waiting for the bind', () async {
      IOOverrides.global = _SlowBind(const Duration(milliseconds: 300));

      final s = ClashService();
      service = s;
      // Attach the waiter first: the bind completes after destroy(), and the
      // completer's error must have a listener.
      unawaited(s.preload().then<void>((_) {}, onError: (Object _) {}));

      await expectLater(
        Future<bool>.value(s.destroy()).timeout(const Duration(seconds: 2)),
        completion(isTrue),
        reason: 'destroy() must act on ownership, not on the completer',
      );
    });

    test('a bind that lands after destroy() is released, not leaked', () async {
      final before = socketFiles();
      IOOverrides.global = _SlowBind(const Duration(milliseconds: 300));

      final s = ClashService();
      service = s;
      unawaited(s.preload().then<void>((_) {}, onError: (Object _) {}));

      await s.destroy();

      // Let the delayed bind finish and the late release run.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      expect(
        socketFiles().difference(before),
        isEmpty,
        reason:
            'a listener that lands after destroy() must be closed and unlinked',
      );
    });
  });

  group('R7-15.4 shutdown → reStart', () {
    test('reStart() after shutdown() binds a live listener again', () async {
      final before = socketFiles();
      final s = await startService();

      final mine = socketFiles().difference(before);
      expect(mine.length, 1, reason: 'the first bind created exactly one file');
      final path = mine.single;

      await s.shutdown();
      expect(
        File(path).existsSync(),
        isFalse,
        reason: 'shutdown releases the listener and unlinks its file',
      );

      await s.reStart();

      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'a restart must give the core a path that actually listens',
      );
      expect(
        s.hasLiveProcess,
        isFalse,
        reason: 'the core spawn is skipped by the test seam',
      );
    });

    test('the re-bound listener is fresh, not the released one', () async {
      final before = socketFiles();
      final s = await startService();
      final path = socketFiles().difference(before).single;

      await s.shutdown();
      await s.reStart();

      // `preload()` awaits `serverCompleter`. It only resolves if `_doRestart`
      // created a *new* completer — reusing the completed one would have let it
      // return while the listener was still closed.
      expect(
        await Future<bool>.value(s.preload()).timeout(const Duration(seconds: 5)),
        isTrue,
      );
      expect(File(path).existsSync(), isTrue);
    });

    test('repeated shutdown → reStart cycles keep working', () async {
      final before = socketFiles();
      final s = await startService();
      final path = socketFiles().difference(before).single;

      for (var i = 0; i < 3; i++) {
        await s.shutdown();
        expect(File(path).existsSync(), isFalse, reason: 'cycle $i: released');

        await s.reStart();
        expect(File(path).existsSync(), isTrue, reason: 'cycle $i: re-bound');
        expect(
          socketFiles().difference(before).length,
          1,
          reason: 'cycle $i must not leave a second listener behind',
        );
      }
    });

    test('a failed re-bind propagates the original error', () async {
      final s = await startService();
      await s.shutdown();

      IOOverrides.global = _FailingBind();

      await expectLater(
        Future<void>.value(s.reStart()).timeout(const Duration(seconds: 5)),
        throwsA(isA<SocketException>()),
        reason: 'the caller must see the bind failure, not a silent success',
      );
    });

    test('destroy() blocks a later reStart() from resurrecting', () async {
      final before = socketFiles();
      final s = await startService();
      final path = socketFiles().difference(before).single;

      await s.destroy();

      await expectLater(
        Future<void>.value(s.reStart()).timeout(const Duration(seconds: 5)),
        throwsA(isA<StateError>()),
        reason: 'a destroyed instance must never come back to life',
      );
      expect(
        File(path).existsSync(),
        isFalse,
        reason: 'a blocked restart must not leave a new socket behind',
      );
      expect(socketFiles().difference(before), isEmpty);
    });
  });

  group('R7-6 test isolation seam', () {
    const hangGuard = Timeout(Duration(seconds: 5));

    setUp(() {
      // Must precede the first `ClashService()` call in these tests.
      ClashService.resetForTest();
      ClashService.skipTransportForTest = true;
    });

    test('destroy() completes when the transport never started', () async {
      final s = ClashService();
      service = s;

      expect(
        await s.destroy(),
        isTrue,
        reason: 'a destroy() that awaits an uncompleted bind hangs forever',
      );
    }, timeout: hangGuard);

    test('destroy() is idempotent', () async {
      final s = ClashService();
      service = s;

      expect(await s.destroy(), isTrue);
      expect(await s.destroy(), isTrue);
    }, timeout: hangGuard);

    test('shutdown() is safe when the transport never started', () async {
      final s = ClashService();
      service = s;

      expect(await s.shutdown(), isTrue);
    }, timeout: hangGuard);

    test('shutdown() then destroy() — the production exit order', () async {
      final s = ClashService();
      service = s;

      expect(await s.shutdown(), isTrue);
      expect(await s.destroy(), isTrue);
    }, timeout: hangGuard);

    test('the seam binds nothing', () async {
      final before = socketFiles();
      final s = ClashService();
      service = s;

      await s.destroy();
      expect(
        socketFiles().difference(before),
        isEmpty,
        reason: 'the seam must keep the transport from starting',
      );
    }, timeout: hangGuard);
  });
}

/// Fails every `ServerSocket.bind` with a [SocketException].
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

/// Delays the real bind, so a caller can race it.
final class _SlowBind extends IOOverrides {
  _SlowBind(this.delay);

  final Duration delay;

  @override
  Future<ServerSocket> serverSocketBind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
  }) async {
    await Future<void>.delayed(delay);
    // `super` reaches the real bind — calling `ServerSocket.bind` here would
    // re-enter this override.
    return super.serverSocketBind(
      address,
      port,
      backlog: backlog,
      v6Only: v6Only,
      shared: shared,
    );
  }
}
