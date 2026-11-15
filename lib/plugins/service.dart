import 'dart:async';
import 'dart:convert';

import 'package:fluxora/common/system.dart';
import 'package:fluxora/models/core.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/services.dart';

import '../clash/lib.dart';

typedef NativeEventCallback =
    Future<void> Function(String method, dynamic arguments);

class Service {
  static final Service _instance = Service._internal();
  final MethodChannel methodChannel = const MethodChannel('service');

  final List<NativeEventCallback> _nativeEventCallbacks = [];

  Service._internal() {
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  factory Service() => _instance;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    for (final callback in List.of(_nativeEventCallbacks)) {
      await callback(call.method, call.arguments);
    }
  }

  void addNativeEventCallback(NativeEventCallback callback) {
    _nativeEventCallbacks.add(callback);
  }

  void removeNativeEventCallback(NativeEventCallback callback) {
    _nativeEventCallbacks.remove(callback);
  }

  Future<bool?> init() => methodChannel.invokeMethod<bool>('init');

  Future<bool?> destroy() => methodChannel.invokeMethod<bool>('destroy');

  Future<bool> waitForVpnStart({
    AndroidVpnOptions? options,
    Duration timeout = const Duration(seconds: 90),
    Duration pollInterval = const Duration(milliseconds: 250),
    Future<void>? cancellation,
  }) async {
    final result = Completer<bool>();
    void fail() {
      if (!result.isCompleted) result.complete(false);
    }

    Future<void> onEvent(String method, dynamic arguments) async {
      if (method == 'vpnStartFailed') fail();
    }

    addNativeEventCallback(onEvent);
    final deadline = Timer(timeout, fail);
    cancellation?.then((_) => fail());
    try {
      final optionsRequest = options == null
          ? clashLib?.getAndroidVpnOptions()
          : null;
      final resolved =
          options ??
          (optionsRequest == null
              ? null
              : await Future.any<AndroidVpnOptions?>([
                  optionsRequest,
                  result.future.then((_) => null),
                ]));
      if (result.isCompleted) return false;
      final accepted = methodChannel
          .invokeMethod<bool>('startVpn', {'data': json.encode(resolved)})
          .then((value) => value == true);
      if (!await Future.any([accepted, result.future])) {
        return false;
      }
      while (!result.isCompleted) {
        final running = await Future.any([getStatus(), result.future]);
        if (running) return true;
        await Future.any<void>([
          Future<void>.delayed(pollInterval),
          result.future,
        ]);
      }
      return await result.future;
    } finally {
      deadline.cancel();
      removeNativeEventCallback(onEvent);
    }
  }

  Future<bool?> stopVpn() => methodChannel.invokeMethod<bool>('stopVpn');

  Future<bool?> smartStop() => methodChannel.invokeMethod<bool>('smartStop');

  Future<bool?> smartResume() async {
    final options = await clashLib?.getAndroidVpnOptions();
    return await methodChannel.invokeMethod<bool>('smartResume', {
      'data': json.encode(options),
    });
  }

  Future<void> setSmartStopped(bool value) async {
    await methodChannel.invokeMethod<bool>('setSmartStopped', {'value': value});
  }

  Future<bool> isSmartStopped() async {
    return await methodChannel.invokeMethod<bool>('isSmartStopped') ?? false;
  }

  Future<List<String>> getLocalIpAddresses() async {
    return await methodChannel.invokeListMethod<String>(
          'getLocalIpAddresses',
        ) ??
        const [];
  }

  Future<List<String>> getLocalGateways() async {
    return await methodChannel.invokeListMethod<String>('getLocalGateways') ??
        const [];
  }

  Future<bool?> setQuickResponse(bool enabled) async {
    return await methodChannel.invokeMethod<bool>('setQuickResponse', {
      'enabled': enabled,
    });
  }

  Future<bool> isServiceEngineRunning() async {
    return await methodChannel.invokeMethod<bool>('isServiceEngineRunning') ??
        false;
  }

  Future<bool> getStatus() async {
    return await methodChannel.invokeMethod<bool>('status') ?? false;
  }

  Future<bool?> setHighPriorityNotification(bool enabled) async {
    return await methodChannel.invokeMethod<bool>(
      'setHighPriorityNotification',
      {'enabled': enabled},
    );
  }

  Future<bool?> reconnectIpc() =>
      methodChannel.invokeMethod<bool>('reconnectIpc');
}

Service? get service =>
    system.isAndroid && !globalState.isService ? Service() : null;
