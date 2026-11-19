import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/service.dart';
import 'package:fluxora/common/common.dart';

// Exercise the real local listener while skipping the helper and core process.
// Unix uses an owned filesystem path and Windows uses loopback TCP.
void main() {
  // `_initServer`'s error handler calls `globalState.showNotifier`, which reads
  // `WidgetsBinding.instance`. Without a binding the bind-failure path throws
  // from the error handler instead of from the bind.
  TestWidgetsFlutterBinding.ensureInitialized();

  Set<String> socketFiles() => Directory.systemTemp
      .listSync(followLinks: false)
      .map((e) => e.path)
      .where(
        (p) =>
            p.endsWith('.sock') &&
            p.split(Platform.pathSeparator).last.startsWith('Fluxora_${pid}_'),
      )
      .toSet();

  Future<({InternetAddress address, int port})> boundEndpoint(
    ClashService service,
  ) async {
    final listener = await service.serverCompleter.future;
    final address = listener.address;
    if (Platform.isWindows) {
      expect(address, InternetAddress.loopbackIPv4);
      expect(listener.port, greaterThan(0));
    } else {
      expect(address.type, InternetAddressType.unix);
      expect(socketFiles(), contains(address.address));
    }
    return (address: address, port: listener.port);
  }

  Future<void> expectListening(
    ({InternetAddress address, int port}) endpoint,
  ) async {
    final probe = await Socket.connect(
      endpoint.address,
      endpoint.port,
      timeout: const Duration(seconds: 2),
    );
    probe.destroy();
  }

  Future<void> expectReleased(
    ({InternetAddress address, int port}) endpoint,
  ) async {
    await expectLater(
      Socket.connect(
        endpoint.address,
        endpoint.port,
        timeout: const Duration(seconds: 2),
      ).then((socket) => socket.destroy()),
      throwsA(isA<SocketException>()),
    );
    if (endpoint.address.type == InternetAddressType.unix) {
      expect(socketFiles(), isNot(contains(endpoint.address.address)));
    } else {
      final rebound = await IOOverrides.runWithIOOverrides(
        () => ServerSocket.bind(endpoint.address, endpoint.port),
        _RealBind(),
      );
      await rebound.close();
    }
  }

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
      final names = {
        for (var i = 0; i < 64; i++) ClashService.socketFileName(),
      };

      expect(names.length, 64, reason: 'a repeated name is a collision');
      for (final name in names) {
        expect(name, startsWith('Fluxora_${pid}_'));
        expect(name, endsWith('.sock'));
        // Kept short enough for the platform limits (Linux 108 / macOS 104).
        expect(name.length, lessThan(48));
      }
    });

    test('two live instances have separate endpoints', () async {
      final first = await startService();
      addTearDown(first.destroy);
      final firstEndpoint = await boundEndpoint(first);

      ClashService.resetForTest();
      final second = await startService();
      final secondEndpoint = await boundEndpoint(second);

      expect(secondEndpoint, isNot(firstEndpoint));
      await expectListening(firstEndpoint);
      await expectListening(secondEndpoint);
      await first.destroy();
      await expectReleased(firstEndpoint);
      await expectListening(secondEndpoint);
    });
  });

  group('bind failure', () {
    test(
      'reaches preload() as the original error instead of hanging',
      () async {
        IOOverrides.global = _FailingBind();

        final s = ClashService();
        service = s;

        await expectLater(
          s.preload().timeout(const Duration(seconds: 5)),
          throwsA(isA<SocketException>()),
          reason: 'a failed bind must fail the waiter, not park it forever',
        );
      },
    );

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

    test(
      'destroy() after a failed bind returns instead of rethrowing',
      () async {
        IOOverrides.global = _FailingBind();
        final s = ClashService();
        service = s;
        await expectLater(s.preload(), throwsA(isA<SocketException>()));

        IOOverrides.global = null;
        expect(
          await Future<bool>.value(
            s.destroy(),
          ).timeout(const Duration(seconds: 5)),
          isTrue,
          reason: 'teardown must not rethrow the bind error',
        );
      },
    );
  });

  group('teardown ownership', () {
    test('shutdown() releases its own endpoint', () async {
      final s = await startService();
      final endpoint = await boundEndpoint(s);
      await expectListening(endpoint);

      expect(await s.shutdown(), isTrue);
      await expectReleased(endpoint);
    });

    test('shutdown() leaves an unrelated endpoint live', () async {
      final foreign = decoy('98');
      final foreignAddress = Platform.isWindows
          ? InternetAddress.loopbackIPv4
          : InternetAddress(foreign.path, type: InternetAddressType.unix);
      final other = await ServerSocket.bind(foreignAddress, 0);
      other.listen((socket) => socket.destroy());
      addTearDown(() async {
        await other.close();
        if (foreign.existsSync()) foreign.deleteSync();
      });

      final s = await startService();
      final endpoint = await boundEndpoint(s);
      expect(await s.shutdown(), isTrue);

      await expectReleased(endpoint);
      await expectListening((address: other.address, port: other.port));
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
      final delayed = _SlowBind(const Duration(milliseconds: 300));
      IOOverrides.global = delayed;

      final s = ClashService();
      service = s;
      final preloadFailed = expectLater(
        s.preload(),
        throwsA(isA<StateError>()),
      );

      await s.destroy();

      final endpoint = await delayed.endpoint.future;
      await preloadFailed;
      await expectReleased(endpoint);
    });
  });

  group('R7-15.4 shutdown → reStart', () {
    test('reStart() after shutdown() binds a live listener again', () async {
      final s = await startService();
      final endpoint = await boundEndpoint(s);

      expect(await s.shutdown(), isTrue);
      await expectReleased(endpoint);

      await s.reStart();
      await expectListening(await boundEndpoint(s));
      expect(s.hasLiveProcess, isFalse);
    });

    test('the re-bound listener is fresh, not the released one', () async {
      final s = await startService();
      final original = await s.serverCompleter.future;

      expect(await s.shutdown(), isTrue);
      await s.reStart();

      expect(await s.preload().timeout(const Duration(seconds: 5)), isTrue);
      expect(await s.serverCompleter.future, isNot(same(original)));
      await expectListening(await boundEndpoint(s));
    });

    test('repeated shutdown → reStart cycles keep working', () async {
      final s = await startService();

      for (var i = 0; i < 3; i++) {
        final endpoint = await boundEndpoint(s);
        await expectListening(endpoint);
        expect(await s.shutdown(), isTrue, reason: 'cycle $i');
        await expectReleased(endpoint);

        await s.reStart();
        await expectListening(await boundEndpoint(s));
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
      final s = await startService();
      final endpoint = await boundEndpoint(s);
      final ready = s.serverCompleter;

      expect(await s.destroy(), isTrue);
      await expectLater(
        s.reStart().timeout(const Duration(seconds: 5)),
        throwsA(isA<StateError>()),
      );
      expect(s.serverCompleter, same(ready));
      await expectReleased(endpoint);
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

final class _RealBind extends IOOverrides {}

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
  final endpoint = Completer<({InternetAddress address, int port})>();

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
    final listener = await super.serverSocketBind(
      address,
      port,
      backlog: backlog,
      v6Only: v6Only,
      shared: shared,
    );
    endpoint.complete((address: listener.address, port: listener.port));
    return listener;
  }
}
