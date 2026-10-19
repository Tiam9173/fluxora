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


  /// Notification buttons are drawn by Android, so their labels have to be
  /// handed over: string resources follow the system language, not the in-app
  /// one.
  Future<void> _syncNotificationLabels() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        final labels = {
          'stop': appLocalizations.stop,
          'switch': appLocalizations.switchProxy,
          'reset': appLocalizations.reset,
        };
        await methodChannel.invokeMethod('setNotificationLabels', {
          'labels': labels,
        });
        return;
      } catch (_) {
        // Localizations are not ready during the first frames.
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
    commonPrint.log('setNotificationLabels: gave up, localizations never ready');
  }

  Future<void> consumePendingNotificationAction() async {
    // Checked before the navigator: in card-only mode the root is replaced, so
    // there is never a navigator to wait for.
    try {
      final cardOnly = await methodChannel.invokeMethod<bool>('isCardOnlyLaunch');
      if (cardOnly == true) {
        globalState.cardOnlyMode.value = true;
        return;
      }
    } catch (e) {
      commonPrint.log('isCardOnlyLaunch failed: $e');
    }
    for (var attempt = 0; attempt < 20; attempt++) {
      if (globalState.navigatorKey.currentContext != null) {
        String? action;
        try {
          action = await methodChannel
              .invokeMethod<String>('consumePendingNotificationAction');
        } catch (e) {
          commonPrint.log('consumePendingNotificationAction failed: $e');
        }
        // Re-read after the await: the navigator may have been replaced.
        final context = globalState.navigatorKey.currentContext;
        if (action == 'switch' && context != null) {
          // ignore: use_build_context_synchronously
          showNotificationSwitchCard(context);
        }
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Vpn._internal() {
    // A notification button can cold-start the app, so the request may already
    // be waiting before this handler exists. Push the labels and consume it
    // once the channel is live.
    _syncNotificationLabels();
    consumePendingNotificationAction();
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
        case 'notificationStop':
          // The app's own stop path, not a bare service kill: it also tears
          // down the core and tells the state machine the tunnel is gone.
          commonPrint.log('notificationStop: stopping via app controller');
          await globalState.handleStop();
          break;
        case 'notificationSwitch':
          // A card-only launch replaces the whole tree, so there is no dialog to
          // show: flip the root instead.
          if (await methodChannel.invokeMethod<bool>('isCardOnlyLaunch') == true) {
            globalState.cardOnlyMode.value = true;
            break;
          }
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
          // Restart the core rather than only dropping connections: that is the
          // existing recovery path, and it rebuilds DNS and every upstream at
          // once. A reset that leaves a broken resolver in place is not a reset.
          commonPrint.log('notificationReset: restarting core');
          await globalState.appController.restartCore();
          // The notification flash already happened natively when the button
          // was pressed, so it stays visible even if this path is slow.
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
