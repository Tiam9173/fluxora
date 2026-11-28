import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/lib.dart';
import 'package:fluxora/common/common.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'each stalled native startup stage releases readiness and allows retry',
    () async {
      System.platformOverride = 'android';
      final servicePort = ReceivePort();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      String? blockedMethod = 'isServiceEngineRunning';
      var response = Completer<bool>();
      var running = true;
      messenger.setMockMethodCallHandler(const MethodChannel('service'), (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == blockedMethod) return response.future;
        if (call.method == 'isServiceEngineRunning') return running;
        if (call.method == 'reconnectIpc' || call.method == 'init') {
          IsolateNameServer.lookupPortByName(
            mainIsolate,
          )!.send(servicePort.sendPort);
        }
        return true;
      });
      final bridge = ClashLib();
      addTearDown(() {
        servicePort.close();
        bridge.receiverPort.close();
        IsolateNameServer.removePortNameMapping(mainIsolate);
        messenger.setMockMethodCallHandler(
          const MethodChannel('service'),
          null,
        );
        System.platformOverride = null;
      });

      expect(
        await bridge.preload().timeout(const Duration(seconds: 4)),
        isFalse,
      );
      expect(calls, ['isServiceEngineRunning']);
      response.complete(false);
      await Future<void>.delayed(Duration.zero);
      expect(calls, [
        'isServiceEngineRunning',
      ], reason: 'a late native reply must not continue the failed startup');

      for (final method in ['reconnectIpc', 'destroy', 'init']) {
        blockedMethod = null;
        running = true;
        await bridge.refreshIpc().timeout(const Duration(seconds: 2));
        expect(await bridge.preload(), isTrue);

        calls.clear();
        blockedMethod = method;
        running = method == 'reconnectIpc';
        response = Completer<bool>();
        final reconnect = bridge.refreshIpc();
        final readiness = bridge.preload();
        await expectLater(
          reconnect.timeout(const Duration(seconds: 8)),
          throwsA(
            isA<TimeoutException>().having(
              (error) => error.duration,
              'bounded native request',
              Duration(seconds: method == 'init' ? 6 : 2),
            ),
          ),
        );
        expect(await readiness, isFalse);
        expect(calls.last, method);
        final completedCalls = List<String>.from(calls);
        response.complete(true);
        await Future<void>.delayed(Duration.zero);
        expect(calls, completedCalls);
      }

      blockedMethod = null;
      running = true;
      await bridge.refreshIpc().timeout(const Duration(seconds: 2));
      expect(await bridge.preload(), isTrue);
    },
  );
}
