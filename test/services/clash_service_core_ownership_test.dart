import 'dart:io';

import 'package:fluxora/clash/clash.dart';
import 'package:flutter_test/flutter_test.dart';

/// P9-S06 — only the instance whose core was started **through** the helper may
/// stop it.
///
/// No FluxoraCore and no Windows service is started. The helper is replaced by
/// [ClashServiceStartHooks.stopCore]; the direct branch uses a real short-lived
/// `cmd` child (never the core binary) so the kill path is exercised for real.
void main() {
  late List<String> log;

  setUp(() {
    log = <String>[];
    ClashService.skipTransportForTest = true;
    ClashService.skipCoreSpawnForTest = false;
    ClashService.coreReadyTimeout = const Duration(milliseconds: 30);
    ClashService.startHooksForTest = null;
    ClashService.resetForTest();
  });

  tearDown(() {
    ClashService.startHooksForTest = null;
    ClashService.skipTransportForTest = false;
    ClashService.skipCoreSpawnForTest = false;
    ClashService.coreReadyTimeout = const Duration(seconds: 5);
    ClashService.resetForTest();
  });

  /// A service whose constructor did not bind; [serverCompleter] is completed by
  /// hand so `_doRestart` can get past the bind without a real transport.
  Future<ClashService> serviceWithBind() async {
    final service = ClashService();
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close());
    service.serverCompleter.complete(server);
    return service;
  }

  group('shutdown ownership', () {
    test('T-1 helper-started core stops it exactly once', () async {
      var stops = 0;
      ClashService.startHooksForTest = ClashServiceStartHooks(
        stopCore: () async {
          stops++;
          log.add('stopCore');
          return true;
        },
      );

      final service = ClashService();
      service.coreStartedViaHelperForTest = true;

      await service.shutdown();

      expect(stops, 1);
      expect(log, ['stopCore']);
      // Windows-only: `shutdown()` only asks the helper to stop the core under
      // `if (system.isWindows && _coreStartedViaHelper)` (service.dart:816). Off
      // Windows the helper branch does not exist, so zero stops is correct there
      // and this expectation cannot hold. T-2 below still covers the direct path
      // on every platform.
    }, skip: !Platform.isWindows);

    test('T-2 a directly spawned core never sends core.stop', () async {
      var stops = 0;
      ClashService.startHooksForTest = ClashServiceStartHooks(
        stopCore: () async {
          stops++;
          return true;
        },
      );

      final service = ClashService();
      service.coreStartedViaHelperForTest = false;

      await service.shutdown();

      expect(
        stops,
        0,
        reason: 'the helper owns one global core; this instance never used it',
      );
    });
  });

  group('failed-start cleanup', () {
    test('T-3 a failing helper cleanup is contained, not propagated', () async {
      var stops = 0;
      ClashService.startHooksForTest = ClashServiceStartHooks(
        stopCore: () async {
          stops++;
          throw const FormatException('stop failed');
        },
      );

      final service = ClashService();

      // The caller is already unwinding from the original start failure. If this
      // threw, it would replace that failure with a cleanup error — so it must
      // swallow and log instead.
      await service.abortFailedStartForTest(viaHelper: true);

      expect(stops, 1, reason: 'the cleanup was still attempted');
    });

    test(
      'T-4 a direct abort kills the child and releases the reference',
      () async {
        final service = ClashService();
        // Portable child: the abort path under test is platform-neutral.
        final child = Platform.isWindows
            ? await Process.start('cmd', [
                '/c',
                'ping',
                '-n',
                '20',
                '127.0.0.1',
              ])
            : await Process.start('sleep', ['20']);
        addTearDown(() {
          try {
            child.kill(ProcessSignal.sigkill);
          } catch (_) {}
        });

        service.process = child;
        await service.abortFailedStartForTest(viaHelper: false);

        expect(
          service.process,
          isNull,
          reason: 'the handle must be dropped, or the next start leaks it',
        );
      },
    );

    test('T-5 a new start drops the previous claim once it is settled', () async {
      // `skipCoreSpawnForTest` returns before any launch, which is exactly the
      // point: the claim is settled at the top of every start, not by the branch.
      ClashService.skipCoreSpawnForTest = true;
      // The hook is mandatory here: without it the real `helperClient` would be
      // asked to stop whatever helper this machine is running.
      ClashService.startHooksForTest = ClashServiceStartHooks(
        stopCore: () async => true,
      );
      final service = await serviceWithBind();

      service.coreStartedViaHelperForTest = true;
      await service.reStart();

      expect(
        service.coreStartedViaHelperForTest,
        isFalse,
        reason: 'ownership belongs to one start, not to the instance forever',
      );
    });
  });
}
