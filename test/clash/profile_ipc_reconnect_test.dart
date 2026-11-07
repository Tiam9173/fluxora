import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/lib.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'profile apply rebinds a closed service port without restarting the engine',
    () async {
      System.platformOverride = 'android';
      final oldPort = ReceivePort();
      final freshPort = ReceivePort();
      var servicePort = oldPort.sendPort;
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('service'), (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == 'isServiceEngineRunning') return true;
        if (call.method == 'reconnectIpc') {
          IsolateNameServer.lookupPortByName(mainIsolate)!.send(servicePort);
          return true;
        }
        throw StateError('Unexpected service mutation: ${call.method}');
      });
      final bridge = ClashLib();
      addTearDown(() {
        oldPort.close();
        freshPort.close();
        bridge.receiverPort.close();
        IsolateNameServer.removePortNameMapping(mainIsolate);
        messenger.setMockMethodCallHandler(
          const MethodChannel('service'),
          null,
        );
        System.platformOverride = null;
      });
      await bridge.preload().timeout(const Duration(seconds: 2));
      oldPort.close();
      servicePort = freshPort.sendPort;
      freshPort.listen((raw) {
        final action = jsonDecode(raw as String) as Map<String, dynamic>;
        IsolateNameServer.lookupPortByName(mainIsolate)!.send(
          jsonEncode({...action, 'data': 'configuration-applied', 'code': 0}),
        );
      });
      await bridge.refreshIpc().timeout(const Duration(seconds: 2));
      final ack = await bridge.invoke<String>(
        method: ActionMethod.setupConfig,
        data: 'profile-B',
        timeout: const Duration(seconds: 1),
      );
      expect(ack, 'configuration-applied');
      expect(calls.where((method) => method == 'reconnectIpc'), hasLength(2));
      expect(calls, isNot(contains('destroy')));
      expect(calls, isNot(contains('init')));
    },
  );
}
