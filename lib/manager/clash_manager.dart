import 'dart:async';

import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/app.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/providers/state.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClashManager extends ConsumerStatefulWidget {
  final Widget child;

  const ClashManager({super.key, required this.child});

  @override
  ConsumerState<ClashManager> createState() => _ClashContainerState();
}

class _ClashContainerState extends ConsumerState<ClashManager>
    with AppMessageListener {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    clashMessage.addListener(this);
    ref.listenManual(needSetupProvider, (prev, next) {
      if (prev != next) {
        final profileChanged = prev?.a != next.a;
        // Reload notifications must not inherit a completed lifecycle lock.
        Zone.root.run(() {
          // DNS-only edits rebuild the active config without presenting them as
          // a profile switch or clearing unrelated runtime state.
          if (prev != null &&
              !profileChanged &&
              prev.b == next.b &&
              prev.c != next.c) {
            unawaited(
              globalState.appController.applyProfile().catchError((
                Object error,
                StackTrace stackTrace,
              ) {
                commonPrint.log('DNS profile apply failed: $error');
              }),
            );
            return;
          }
          unawaited(
            globalState.appController
                .handleChangeProfile(previousProfileId: prev?.a)
                .catchError((Object error, StackTrace stackTrace) {
                  commonPrint.log('Profile change failed: $error');
                }),
          );
        });
      }
    });
    ref.listenManual(coreStateProvider, (prev, next) async {
      if (prev != next) {
        await clashCore.setState(next);
      }
    });
    ref.listenManual(updateParamsProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.updateClashConfigDebounce();
      }
    });

    ref.listenManual(appSettingProvider.select((state) => state.openLogs), (
      prev,
      next,
    ) {
      if (next) {
        clashCore.startLog();
      } else {
        clashCore.stopLog();
      }
    });
  }

  @override
  Future<void> dispose() async {
    clashMessage.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onDelay(Delay delay) async {
    super.onDelay(delay);
    final appController = globalState.appController;
    appController.setDelay(delay, background: true);
    debouncer.call(FunctionTag.updateDelay, () async {
      appController.updateGroupsDebounce();
    }, duration: const Duration(milliseconds: 5000));
  }

  @override
  void onLog(Log log) {
    ref.read(logsProvider.notifier).addLog(log);
    if (log.logLevel == LogLevel.error) {
      globalState.showNotifier(log.payload);
    }
    super.onLog(log);
  }

  @override
  void onRequest(TrackerInfo trackerInfo) async {
    ref.read(requestsProvider.notifier).addRequest(trackerInfo);
    super.onRequest(trackerInfo);
  }

  @override
  Future<void> onLoaded(String providerName) async {
    ref
        .read(providersProvider.notifier)
        .setProvider(await clashCore.getExternalProvider(providerName));
    globalState.appController.updateGroupsDebounce();
    super.onLoaded(providerName);
  }
}
