import 'dart:convert';

import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/proxies/common.dart';
import 'package:fluxora/views/proxies/notification_switch_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract mixin class VpnListener {
  void onDnsChanged(String dns) {}

  void onScreenStateChanged(bool isOn) {}

  void onNetworkChanged() {}
}

class Vpn {
  static final Vpn _instance = Vpn._internal();
  final MethodChannel methodChannel = const MethodChannel('vpn');

  Vpn._internal() {
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'gc':
          clashCore.requestGc(forceFreeOSMemory: true);
          break;
        case 'closeConnections':
          clashCore.closeConnections();
          break;
        case 'status':
          return clashLibHandler?.getRunTime() != null;
        case 'dnsChanged':
          for (final listener in _listeners) {
            listener.onDnsChanged(call.arguments as String);
          }
          break;
        case 'screenStateChanged':
          final isOn = call.arguments as bool;
          globalState.isScreenOn = isOn;
          for (final listener in _listeners) {
            listener.onScreenStateChanged(isOn);
          }
          break;
        case 'networkChanged':
          for (final listener in _listeners) {
            listener.onNetworkChanged();
          }
          break;
        // Notification action buttons.
        case 'notificationSwitch':
          // The activity is launched before this arrives, but on a cold start
          // the navigator is not mounted yet. Retry briefly rather than drop
          // the request — a button that silently does nothing is the worst
          // possible outcome here.
          for (var attempt = 0; attempt < 10; attempt++) {
            if (globalState.navigatorKey.currentContext != null) break;
            await Future.delayed(const Duration(milliseconds: 150));
          }
          final context = globalState.navigatorKey.currentContext;
          if (context == null) {
            commonPrint.log(
              'notificationSwitch: no navigator context, card not shown',
            );
          } else {
            commonPrint.log('notificationSwitch: opening switch card');
            // The context was re-read after the retry loop, so it is current.
            // ignore: use_build_context_synchronously
            showNotificationSwitchCard(context);
          }
          break;
        case 'notificationReset':
          // ownbox's RESET_UPSTREAM_CONNECTIONS semantics: drop the existing
          // upstream connections and let the core rebuild them from the current
          // config, so the selected node and profile stay exactly as they are.
          commonPrint.log('notificationReset: resetting upstream connections');
          clashCore.resetConnections();
          break;
        case 'notificationSpeedTest':
          final controller = globalState.appController;
          final groupName = controller.getCurrentGroupName();
          final group = globalState.appState.groups
              .where((element) => element.name == groupName)
              .firstOrNull;
          if (group == null) {
            commonPrint.log(
              'notificationSpeedTest: group "$groupName" not found '
              '(${globalState.appState.groups.length} groups)',
            );
            break;
          }
          commonPrint.log(
            'notificationSpeedTest: group "$groupName", '
            '${group.all.length} proxies',
          );
          await delayTest(
            group.all,
            testUrl: group.testUrl,
            groupName: groupName,
          );
          commonPrint.log('notificationSpeedTest: done');
          break;
        default:
      }
    });
  }

  factory Vpn() => _instance;

  final ObserverList<VpnListener> _listeners = ObserverList<VpnListener>();

  Future<bool?> start(AndroidVpnOptions options) async {
    return await methodChannel.invokeMethod<bool>('start', {
      'data': jsonEncode(options),
    });
  }

  Future<bool?> stop() => methodChannel.invokeMethod<bool>('stop');

  Future<List<String>> getLocalIpAddresses() async {
    return await methodChannel.invokeListMethod<String>(
          'getLocalIpAddresses',
        ) ??
        const [];
  }

  Future<List<String>> getLocalGateways() async {
    return await methodChannel.invokeListMethod<String>(
          'getLocalGateways',
        ) ??
        const [];
  }

  Future<void> setSmartStopped(bool value) async {
    await methodChannel.invokeMethod<bool>('setSmartStopped', {'value': value});
  }

  Future<bool> isSmartStopped() async {
    return await methodChannel.invokeMethod<bool>('isSmartStopped') ?? false;
  }

  Future<bool?> smartStop() => methodChannel.invokeMethod<bool>('smartStop');

  Future<bool?> smartResume(AndroidVpnOptions options) async {
    return await methodChannel.invokeMethod<bool>('smartResume', {
      'data': jsonEncode(options),
    });
  }

  Future<bool> getStatus() async {
    return await methodChannel.invokeMethod<bool>('status') ?? false;
  }

  Future<void> updateNotificationSpeed(
    String profileName,
    String speedInfo,
  ) async {
    await methodChannel.invokeMethod<void>('updateNotificationSpeed', {
      'profileName': profileName,
      'speedInfo': speedInfo,
    });
  }

  void addListener(VpnListener listener) => _listeners.add(listener);

  void removeListener(VpnListener listener) => _listeners.remove(listener);
}

Vpn? get vpn => globalState.isService ? Vpn() : null;
