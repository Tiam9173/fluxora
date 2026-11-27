import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/state.dart';

class _HungStopCore extends Fake implements ClashHandlerInterface {
  @override
  Future<bool> stopListener() => Completer<bool>().future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
