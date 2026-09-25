import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/providers/app.dart';
import 'package:fluxora/providers/state.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VpnManager extends ConsumerStatefulWidget {
  final Widget child;

  const VpnManager({super.key, required this.child});

  @override
  ConsumerState<VpnManager> createState() => _VpnContainerState();
}

class _VpnContainerState extends ConsumerState<VpnManager> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(vpnStateProvider, (prev, next) {
      // Skip tip
      if (prev == null || prev == next) return;
      
      final prevProps = prev.vpnProps;
      final nextProps = next.vpnProps;
      
      // Check
      final onlySmartAutoStopChanged = prevProps.copyWith(
        smartAutoStop: nextProps.smartAutoStop,
        smartAutoStopNetworks: nextProps.smartAutoStopNetworks,
      ) == nextProps;
      
      final onlyQuickResponseChanged = prevProps.copyWith(
        quickResponse: nextProps.quickResponse,
      ) == nextProps;
      
      final onlyNetworkSpeedChanged = prevProps.copyWith(
        networkSpeedNotification: nextProps.networkSpeedNotification,
      ) == nextProps;
      
      final onlyHighPriorityNotificationChanged = prevProps.copyWith(
        highPriorityNotification: nextProps.highPriorityNotification,
      ) == nextProps;
      
      if (onlySmartAutoStopChanged ||
          onlyQuickResponseChanged ||
          onlyNetworkSpeedChanged ||
          onlyHighPriorityNotificationChanged) {
        return; // No tip needed
      }
      
      showTip();
    });
  }

  void showTip() {
    debouncer.call(FunctionTag.vpnTip, () {
      if (ref.read(runTimeProvider.notifier).isStart) {
        globalState.showNotifier(
          appLocalizations.vpnTip,
          onAction: () async {
            await globalState.appController.updateStatus(false);
            await Future.delayed(const Duration(milliseconds: 500));
            await globalState.appController.updateStatus(true);
          },
          actionLabel: appLocalizations.restart,
          showCountdown: true,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
