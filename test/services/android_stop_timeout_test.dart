import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/plugins/service.dart';
import 'package:fluxora/state.dart';

class _HungStopCore extends Fake implements ClashHandlerInterface {
  @override
  Future<bool> stopListener() => Completer<bool>().future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final isHeadless in [false, true]) {
    test('core timeout still stops VPN: headless=$isHeadless', () async {
      System.platformOverride = 'android';
      globalState.isService = isHeadless;
      var stops = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('service'), (
        call,
      ) async {
        if (call.method == 'stopVpn') stops++;
        return true;
      });
      addTearDown(() {
        System.platformOverride = null;
        globalState.isService = false;
        messenger.setMockMethodCallHandler(
          const MethodChannel('service'),
          null,
        );
      });

      await Service().stopCoreAndVpn(
        stopListener: () => Completer<bool>().future,
        timeout: const Duration(milliseconds: 20),
      );
      expect(stops, 1);
    });
  }

  for (final reply in ['reject', 'error', 'hang']) {
    test(
      'native stop $reply is reported without blocking indefinitely',
      () async {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(const MethodChannel('service'), (
          call,
        ) async {
          if (reply == 'hang') return Completer<bool>().future;
          if (reply == 'error') throw PlatformException(code: 'STOP_FAILED');
          return false;
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(
            const MethodChannel('service'),
            null,
          ),
        );
        await expectLater(
          Service().stopCoreAndVpn(
            stopListener: () async => true,
            timeout: const Duration(milliseconds: 20),
          ),
          throwsA(switch (reply) {
            'hang' => isA<TimeoutException>(),
            'error' => isA<PlatformException>(),
            _ => isA<StateError>(),
          }),
        );
      },
    );
  }

  test(
    'core failure releases VPN, while listener-only stop retains it',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var stops = 0;
      messenger.setMockMethodCallHandler(const MethodChannel('service'), (
        call,
      ) async {
        stops++;
        return true;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('service'),
          null,
        ),
      );
      await Service().stopCoreAndVpn(
        stopListener: () => throw StateError('core failed'),
      );
      expect(stops, 1);
      await Service().stopCoreAndVpn(
        stopListener: () async => true,
        includeVpnService: false,
      );
      expect(stops, 1);
    },
  );

  test(
    'Android still stops the VPN when core listener shutdown hangs',
    () async {
      System.platformOverride = 'android';
      globalState.isService = false;
      var nativeStopCalled = false;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('service'), (
        call,
      ) async {
        if (call.method == 'stopVpn') {
          nativeStopCalled = true;
          return true;
        }
        if (call.method == 'isServiceEngineRunning') return false;
        return null;
      });
      final previousCore = clashCore.clashInterface;
      clashCore.clashInterface = _HungStopCore();
      addTearDown(() {
        clashCore.clashInterface = previousCore;
        globalState.isService = false;
        System.platformOverride = null;
        messenger.setMockMethodCallHandler(
          const MethodChannel('service'),
          null,
        );
      });

      await preferences.sharedPreferencesCompleter.future.timeout(
        const Duration(seconds: 2),
      );
      final watch = Stopwatch()..start();
      await globalState.handleStop().timeout(const Duration(seconds: 5));

      expect(nativeStopCalled, isTrue);
      expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
    },
  );
}
