import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/network_matcher.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/plugins/service.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synchronized/synchronized.dart';

/// Smart Auto Stop Manager
class SmartAutoStopManager extends ConsumerStatefulWidget {
  final Widget child;

  const SmartAutoStopManager({super.key, required this.child});

  @override
  ConsumerState<SmartAutoStopManager> createState() =>
      _SmartAutoStopManagerState();
}

class _SmartAutoStopManagerState extends ConsumerState<SmartAutoStopManager> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final _checkLock = Lock();

  int _checkSequence = 0;

  late final NativeEventCallback _nativeEventCallback;

  @override
  void initState() {
    super.initState();
    _initConnectivityListener();
    _initNativeNetworkListener();
    _syncSmartStopped();
  }

  void _syncSmartStopped() async {
    if (!system.isAndroid) return;
    try {
      final isStopped = await service?.isSmartStopped() ?? false;
      if (mounted) {
        ref.read(isSmartStoppedProvider.notifier).set(isStopped);
      }
    } catch (_) {}
  }

  void _initNativeNetworkListener() {
    _nativeEventCallback = (String method, dynamic arguments) async {
      if (method == 'networkChanged') {
        _onNativeNetworkChanged();
      } else if (method == 'quickResponse') {
        final vpnProps = ref.read(vpnSettingProvider);
        if (vpnProps.quickResponse) {
          final startTime = globalState.startTime;
          if (startTime != null &&
              DateTime.now().difference(startTime) <
                  const Duration(seconds: 3)) {
            return;
          }
          clashCore.closeConnections();
        }
      }
    };
    service?.addNativeEventCallback(_nativeEventCallback);
  }

  void _onNativeNetworkChanged() async {
    if (system.isAndroid) {
      try {
        final isStopped = await service?.isSmartStopped() ?? false;
        if (mounted) {
          ref.read(isSmartStoppedProvider.notifier).set(isStopped);
        }
      } catch (_) {}
    }
    final vpnProps = ref.read(vpnSettingProvider);
    if (!vpnProps.smartAutoStop) return;
    _debouncedCheckCurrentNetwork();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.listenManual(vpnSettingProvider, (prev, next) {
      if (prev?.smartAutoStop != next.smartAutoStop ||
          prev?.smartAutoStopNetworks != next.smartAutoStopNetworks) {
        _onSettingsChanged();
      }
    });
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      _onConnectivityChanged(results);
    },
    // P2.6-A: the connectivity EventChannel can deliver an error (e.g. no plugin
    // implementation). Without a handler that becomes an unhandled async error —
    // the same case `NetworkFingerprintProvider.start()` already guards.
    onError: (_) {});
  }

  void _onSettingsChanged() {
    final vpnProps = ref.read(vpnSettingProvider);
    if (!vpnProps.smartAutoStop) {
      // Feature disabled, if we were smart-stopped, resume.
      final isSmartStopped = ref.read(isSmartStoppedProvider);
      if (isSmartStopped) {
        ref.read(isSmartStoppedProvider.notifier).set(false);
        _restartVpn();
      }
      return;
    }
    // Re-check current network
    _checkCurrentNetwork();
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final vpnProps = ref.read(vpnSettingProvider);
    if (!vpnProps.smartAutoStop) return;

    _debouncedCheckCurrentNetwork();
  }

  void _debouncedCheckCurrentNetwork() {
    final currentSequence = ++_checkSequence;

    Future.delayed(const Duration(milliseconds: 1000), () async {
      // P2.6-A: a queued check must be invalidated by BOTH a newer check
      // (sequence) and teardown (`mounted`). `_checkSequence` is the existing
      // stale-result token; `dispose()` bumps it so every already-queued
      // callback sees a stale sequence. The `mounted` half additionally covers
      // the window between teardown and the sequence check.
      if (!mounted || currentSequence != _checkSequence) {
        commonPrint.log('Smart Auto Stop: Skipping outdated network check');
        return;
      }
      await _checkCurrentNetwork();
    });
  }

  Future<void> _checkCurrentNetwork() async {
    // P2.6-A: `_checkCurrentNetwork` is also reachable directly
    // (`_onSettingsChanged`) and can be queued on `_checkLock` while the State
    // is being disposed — never touch `ref` after teardown.
    if (!mounted) return;
    await _checkLock.synchronized(() async {
      if (!mounted) return;
      final vpnProps = ref.read(vpnSettingProvider);
      if (!vpnProps.smartAutoStop) return;

      final networks = vpnProps.smartAutoStopNetworks;
      if (networks.isEmpty) return;

      final isSmartStopped = ref.read(isSmartStoppedProvider);

      // Get current IP(s) and gateway(s) — always from native on Android
      List<String> candidateIps;
      List<String> candidateGateways;
      if (system.isAndroid) {
        candidateIps = await _getNativeLocalIpAddresses();
        candidateGateways = await _getNativeLocalGateways();
      } else {
        final ip = await _getLocalIpAddress();
        candidateIps = ip != null ? [ip] : [];
        candidateGateways = await _getDesktopLocalGateways();
      }

      if (candidateIps.isEmpty && candidateGateways.isEmpty) {
        commonPrint.log('Smart Auto Stop: No IP/Gateway found. Skipping.');
        return;
      }

      // P2.6-A: the IP/gateway lookups above are `await`s — the State can be
      // disposed while they are in flight, so re-check before reading state or
      // mutating `ref` (this is the last point before the transition logic).
      if (!mounted) return;

      // Match: any IP hits an IP rule, or any gateway hits a gateway rule
      final shouldStop =
          candidateIps.any((ip) => NetworkMatcher.matchAny(ip, networks)) ||
          candidateGateways.any(
            (gw) => NetworkMatcher.matchAnyGateway(gw, networks),
          );

      commonPrint.log(
        'SmartAutoStop: IPs=${candidateIps.join(",")}, Gateways=${candidateGateways.join(",")}, RuleMatch=$shouldStop, SmartStopped=$isSmartStopped',
      );

      // Dedup: only act on state transitions
      if (shouldStop && !isSmartStopped) {
        // Need to stop, but only if VPN is actually running
        final isRunning =
            ref.read(runTimeProvider) != null || globalState.isStart;
        if (isRunning) {
          ref.read(isSmartStoppedProvider.notifier).set(true);
          commonPrint.log('Smart Auto Stop: Stopping ...');
          await _stopVpn();
        }
      } else if (!shouldStop && isSmartStopped) {
        // Need to resume
        ref.read(isSmartStoppedProvider.notifier).set(false);
        commonPrint.log('Smart Auto Stop: Restarting ...');
        await _restartVpn();
      }
    });
  }

  Future<List<String>> _getNativeLocalIpAddresses() async {
    try {
      final serviceInstance = service;
      if (serviceInstance != null) {
        final ips = await serviceInstance.getLocalIpAddresses();
        if (ips.isNotEmpty) return ips;
      }
    } catch (e) {
      commonPrint.log('Smart Auto Stop: Native IP error: $e');
    }
    // Fallback to Flutter layer
    final ip = await _getLocalIpAddress();
    return ip != null ? [ip] : [];
  }

  Future<List<String>> _getNativeLocalGateways() async {
    try {
      final serviceInstance = service;
      if (serviceInstance != null) {
        final gateways = await serviceInstance.getLocalGateways();
        if (gateways.isNotEmpty) return gateways;
      }
    } catch (e) {
      commonPrint.log('Smart Auto Stop: Native gateway error: $e');
    }
    return [];
  }

  Future<List<String>> _getDesktopLocalGateways() async {
    try {
      return await utils.getLocalGateways();
    } catch (e) {
      commonPrint.log('Smart Auto Stop: Desktop gateway error: $e');
      return [];
    }
  }

  Future<String?> _getLocalIpAddress() async {
    return await utils.getLocalIpAddress();
  }

  Future<void> _stopVpn() async {
    if (system.isAndroid) {
      // Android: Enable smart-stop mode (Blank notification)
      // This keeps the service alive but stops the VPN logic
      await service?.setSmartStopped(true);
      await service?.smartStop();

      // Update Dart state to look "stopped"
      globalState.startTime = null;
      clashCore.resetTraffic();
      ref.read(trafficsProvider.notifier).clear();
      ref.read(totalTrafficProvider.notifier).value = Traffic();
      ref.read(runTimeProvider.notifier).value = null;
    } else {
      // Desktop: Full stop
      await globalState.appController.updateStatus(false);
    }
  }

  Future<void> _restartVpn() async {
    if (system.isAndroid) {
      // Android: Resume from smart-stop mode
      await service?.setSmartStopped(false);
      await service?.smartResume();

      globalState.startTime = DateTime.now();
      ref.read(runTimeProvider.notifier).value = 0;
      globalState.appController.addCheckIpNumDebounce();
    } else {
      // Desktop: Full start
      await globalState.appController.updateStatus(true);
    }
  }

  @override
  void dispose() {
    // P2.6-A: invalidate every queued / in-flight debounced check BEFORE tearing
    // the listeners down. `_checkSequence` is the existing stale-result token
    // used by `_debouncedCheckCurrentNetwork`; bumping it here makes any
    // already-scheduled 1s callback bail out instead of calling
    // `_checkCurrentNetwork()` against a disposed `ref`/State. (The callback's
    // own `mounted` check covers the remaining window.)
    _checkSequence++;
    // An EventChannel cancel can complete with an error when the plugin is
    // unavailable; swallow it so teardown never produces an unhandled async
    // error (same guard as `NetworkFingerprintProvider.stop()`).
    unawaited(_connectivitySubscription?.cancel().catchError((_) {}));
    service?.removeNativeEventCallback(_nativeEventCallback);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
