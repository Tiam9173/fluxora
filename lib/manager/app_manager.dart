import 'dart:async';

import 'package:fluxora/clash/core.dart';
import 'package:fluxora/common/brand_icons.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/manager/window_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/plugins/app.dart';
import 'package:fluxora/plugins/vpn.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/widgets/aurora_navigation_rail.dart';
import 'package:fluxora/widgets/glass_surface.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationDetailsProvider = Provider((ref) {
  final profile = ref.watch(currentProfileProvider);
  final settings = ref.watch(
    vpnSettingProvider.select(
      (s) => (
        showProfile: s.notificationShowProfile,
        showNode: s.notificationShowNode,
        showSpeed: s.networkSpeedNotification,
      ),
    ),
  );
  var nodeName = '';
  if (settings.showNode && profile != null) {
    final mode = ref.watch(patchClashConfigProvider.select((s) => s.mode));
    if (mode != Mode.direct) {
      final groups = ref.watch(groupsProvider);
      final groupName = mode == Mode.global
          ? GroupName.GLOBAL.name
          : profile.currentGroupName;
      var group =
          groups.getGroup(groupName ?? '') ??
          groups
              .where(
                (group) =>
                    group.hidden != true && group.name != GroupName.GLOBAL.name,
              )
              .firstOrNull;
      final visited = <String>{};
      while (group != null && visited.add(group.name)) {
        final selected = group.getCurrentSelectedName(
          profile.selectedMap[group.name] ?? '',
        );
        if (!group.all.any((proxy) => proxy.name == selected)) break;
        group = groups.getGroup(selected);
        if (group == null) nodeName = selected;
      }
    }
  }
  return (
    profileName: profile?.label ?? profile?.id ?? '',
    nodeName: nodeName,
    showProfile: settings.showProfile,
    showNode: settings.showNode,
    showSpeed: settings.showSpeed,
  );
});

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  bool _isRefreshActive = false;
  Timer? _dashboardRefreshDebounceTimer;
  Timer? _missedUpdateCheckTimer;
  DateTime? _lastMissedUpdateCheck;
  late final VoidCallback _dashboardTickListener;
  static const _missedUpdateCheckDelay = Duration(seconds: 5);
  static const _missedUpdateCheckThrottle = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardTickListener = () {
      if (!globalState.isStart) {
        return;
      }
      unawaited(globalState.appController.updateRunTime());
    };
    dashboardRefreshManager.tick1s.addListener(_dashboardTickListener);
    ref.listenManual(layoutChangeProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (prev != next) {
          globalState.computeHeightMapCache = {};
        }
      });
    });
    ref.listenManual(checkIpProvider, (prev, next) {
      if (next.b && (prev?.a != next.a)) {
        detectionState.startCheck();
      }
    });
    ref.listenManual(checkMediaUnlockProvider, (prev, next) {
      if (next.b && (prev?.a != next.a)) {
        mediaUnlockState.startCheckOnNodeChange();
      }
    });
    if (system.isAndroid) {
      ref.listenManual(notificationDetailsProvider, (_, details) {
        unawaited(
          Vpn().setNotificationDetails(
            profileName: details.profileName,
            nodeName: details.nodeName,
            showProfile: details.showProfile,
            showNode: details.showNode,
            showSpeed: details.showSpeed,
          ),
        );
      }, fireImmediately: true);
      ref.listenManual(
        themeSettingProvider.select((s) => s.notificationIconStyle),
        (prev, next) {
          app
              .setNotificationIconStyle(BrandIcons.normalizeNotification(next))
              .catchError((Object error) {
                commonPrint.log('Notification icon sync failed: $error');
                return false;
              });
        },
        fireImmediately: true,
      );
    }
    ref.listenManual(configStateProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.savePreferencesDebounce();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDashboardRefreshState();
      detectionState.tryStartCheck();
      mediaUnlockState.tryStartCheck();
      globalState.appController.updateGroupsDebounce();
    });
    if (window == null) {
      return;
    }
    ref.listenManual(autoSetSystemDnsStateProvider, (prev, next) async {
      if (prev == next) {
        return;
      }
      final shouldSet = next.a == true && next.b == true;
      if (system.isLinux) {
        // 非 systemd 的发行版没有 resolvectl：明确告诉用户不支持，而不是
        // 让开关看起来打开了、实际什么都没做。
        if (shouldSet && !await LinuxSystemDns().isSupported) {
          globalState.showNotifier(
            appLocalizations.autoSetSystemDnsUnsupported,
          );
          return;
        }
        await linuxSystemDns?.updateDns(!shouldSet);
        return;
      }
      await macOS?.updateDns(!shouldSet);
    });
    ref.listenManual(currentBrightnessProvider, (prev, next) {
      if (prev == next) {
        return;
      }
      window?.updateMacOSBrightness(next);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _dashboardRefreshDebounceTimer?.cancel();
    _missedUpdateCheckTimer?.cancel();
    dashboardRefreshManager.tick1s.removeListener(_dashboardTickListener);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _updateDashboardRefreshState() async {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    var isVisible = true;
    var isMinimized = false;
    if (system.isDesktop) {
      final visible = await window?.isVisible;
      if (visible == false) {
        isVisible = false;
      }
      isMinimized = await window?.isMinimized ?? false;
    }
    final isPinned =
        system.isDesktop &&
        ref.read(windowSettingProvider.select((s) => s.isPinned));
    final shouldRun = system.isDesktop
        ? (isPinned || (isVisible && !isMinimized))
        : isForeground;

    if (!shouldRun) {
      _dashboardRefreshDebounceTimer?.cancel();
      _dashboardRefreshDebounceTimer = null;
      if (_isRefreshActive) {
        dashboardRefreshManager.stop();
        _isRefreshActive = false;
      }
      return;
    }

    if (_isRefreshActive) {
      return;
    }

    _dashboardRefreshDebounceTimer?.cancel();
    _dashboardRefreshDebounceTimer = Timer(
      const Duration(milliseconds: 1000),
      () {
        if (!mounted) return;
        if (_isRefreshActive) return;
        dashboardRefreshManager.start();
        _isRefreshActive = true;
      },
    );
  }

  bool get _shouldCheckMissedUpdates {
    if (_lastMissedUpdateCheck == null) return true;
    return DateTime.now().difference(_lastMissedUpdateCheck!) >
        _missedUpdateCheckThrottle;
  }

  void _scheduleMissedUpdateCheck() {
    if (!_shouldCheckMissedUpdates) return;
    _missedUpdateCheckTimer?.cancel();
    _missedUpdateCheckTimer = Timer(_missedUpdateCheckDelay, () {
      _lastMissedUpdateCheck = DateTime.now();
      globalState.appController.checkAndUpdateMissedProfiles();
    });
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    final isBackgroundState =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (state == AppLifecycleState.inactive && !system.isDesktop);

    if (isBackgroundState) {
      _missedUpdateCheckTimer?.cancel();
      globalState.appController.savePreferences();
      await globalState.handleBackground();
    } else if (state == AppLifecycleState.resumed) {
      globalState.handleForeground();
      render?.resume();
      await globalState.resumeForegroundUpdates();
      await globalState.appController.syncWakelockIfNeeded();
      _scheduleMissedUpdateCheck();
      final isInit = await clashCore.isInit;
      if (isInit) {
        globalState.appController.updateGroupsDebounce();
      }

      final hasDetection = ref
          .read(dashboardStateProvider)
          .dashboardWidgets
          .contains(DashboardWidget.networkDetection);
      if (hasDetection) {
        detectionState.tryStartCheck();
      }
      mediaUnlockState.tryStartCheck();
    }
    if (state == AppLifecycleState.resumed && system.isAndroid) {
      final hidden = ref.read(appSettingProvider.select((s) => s.hidden));
      app.updateExcludeFromRecents(hidden);
      SystemChrome.setSystemUIOverlayStyle(
        globalState.appState.systemUiOverlayStyle,
      );
    }
    if (state == AppLifecycleState.inactive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        detectionState.tryStartCheck();
      });
    }
    _updateDashboardRefreshState();
  }

  @override
  void didChangePlatformBrightness() {
    globalState.appController.updateBrightness();
    globalState.appController.updateTray();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AppEnvManager extends StatelessWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      if (globalState.isPre) {
        return Banner(
          message: 'DEBUG',
          location: BannerLocation.topEnd,
          child: child,
        );
      }
    }
    if (globalState.isPre) {
      return Banner(
        message: 'PRE',
        location: BannerLocation.topEnd,
        child: child,
      );
    }
    return child;
  }
}

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  Widget _buildLoading() {
    return Consumer(
      builder: (_, ref, _) {
        final loading = ref.watch(loadingProvider);
        final isMobileView = ref.watch(isMobileViewProvider);
        return loading && !isMobileView
            ? RotatedBox(
                quarterTurns: 1,
                child: const LinearProgressIndicator(),
              )
            : Container();
      },
    );
  }

  Widget _buildBackground({
    required BuildContext context,
    required Widget child,
  }) {
    final material = FluxoraMaterial.of(context);
    return GlassSurface(
      floating: true,
      readable: true,
      border: false,
      child: Container(
        decoration: BoxDecoration(
          color: material.enabled
              ? Colors.transparent
              : context.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(FluxoraRadius.card),
        ),
        foregroundDecoration: material.liquid
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(FluxoraRadius.card),
                border: Border.all(
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: material.enabled ? .45 : 1,
                  ),
                ),
              ),
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final isMobileView = navigationState.viewMode == ViewMode.mobile;
    if (isMobileView) {
      return child;
    }
    final currentIndex = navigationState.currentIndex;
    final showLabel = ref.watch(
      appSettingProvider.select((state) => state.showLabel),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final canExpand = constraints.maxWidth > maxLaptopWidth;
        final extended = showLabel && canExpand;
        final sidebarWidth = extended
            ? AuroraNavigationRail.extendedWidth
            : AuroraNavigationRail.collapsedWidth;
        final chinese = Localizations.localeOf(context).languageCode == 'zh';
        final toggleLabel = !canExpand
            ? (chinese ? '窗口加宽后可展开导航' : 'Widen the window to expand navigation')
            : (extended
                  ? (chinese ? '收起导航' : 'Collapse navigation')
                  : (chinese ? '展开导航' : 'Expand navigation'));
        final layout = Row(
          children: [
            // Animating this width would relayout every kept page each frame.
            SizedBox(
              key: const ValueKey('desktop-sidebar'),
              width: sidebarWidth,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  SafeArea(
                    left: false,
                    top: true,
                    right: false,
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: system.isMacOS ? 22 : FluxoraSpacing.sm,
                      ),
                      child: ScrollConfiguration(
                        behavior: ShowBarScrollBehavior(),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: FluxoraSpacing.sm,
                              vertical: FluxoraSpacing.xs,
                            ),
                            child: _buildBackground(
                              context: context,
                              child: CallbackShortcuts(
                                bindings: <ShortcutActivator, VoidCallback>{
                                  const SingleActivator(
                                    LogicalKeyboardKey.arrowUp,
                                  ): () {
                                    if (currentIndex > 0) {
                                      globalState.appController.toPage(
                                        navigationItems[currentIndex - 1].label,
                                      );
                                    }
                                  },
                                  const SingleActivator(
                                    LogicalKeyboardKey.arrowDown,
                                  ): () {
                                    if (currentIndex <
                                        navigationItems.length - 1) {
                                      globalState.appController.toPage(
                                        navigationItems[currentIndex + 1].label,
                                      );
                                    }
                                  },
                                  const SingleActivator(
                                    LogicalKeyboardKey.select,
                                  ): () {},
                                  const SingleActivator(
                                    LogicalKeyboardKey.enter,
                                  ): () {},
                                },
                                child: Focus(
                                  autofocus: true,
                                  child: AuroraNavigationRail(
                                    header: _buildNavigationHeader(
                                      context: context,
                                      showLabel: extended,
                                      canExpand: canExpand,
                                      toggleLabel: toggleLabel,
                                      onToggle: () => ref
                                          .read(appSettingProvider.notifier)
                                          .updateState(
                                            (state) => state.copyWith(
                                              showLabel: !state.showLabel,
                                            ),
                                          ),
                                    ),
                                    destinations: navigationItems
                                        .map(
                                          (e) => AuroraRailDestination(
                                            icon: e.icon,
                                            label: e.label.localizedName,
                                          ),
                                        )
                                        .toList(),
                                    selectedIndex: currentIndex,
                                    extended: extended,
                                    onDestinationSelected: (index) {
                                      final label =
                                          navigationItems[index].label;
                                      if (currentIndex == index) {
                                        final pageContext = GlobalObjectKey(
                                          label,
                                        ).currentContext;
                                        if (pageContext != null) {
                                          Navigator.of(
                                            pageContext,
                                          ).popUntil((route) => route.isFirst);
                                        }
                                      }
                                      globalState.appController.toPage(label);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildLoading(),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: ClipRect(
                child: MediaQuery.removePadding(
                  context: context,
                  removeLeft: true,
                  child: child,
                ),
              ),
            ),
          ],
        );
        // The sidebar sits outside the Navigator's overlay.
        return Overlay.wrap(child: layout);
      },
    );
  }

  Widget _buildNavigationHeader({
    required BuildContext context,
    required bool showLabel,
    required bool canExpand,
    required String toggleLabel,
    required VoidCallback onToggle,
  }) {
    final toggle = IconButton(
      key: const ValueKey('toggle-desktop-sidebar'),
      tooltip: toggleLabel,
      icon: Icon(showLabel ? Icons.menu_open : Icons.menu),
      onPressed: canExpand ? onToggle : null,
    );

    if (showLabel) {
      return Row(
        children: [
          const AppIcon(size: 32),
          const SizedBox(width: FluxoraSpacing.sm),
          Expanded(
            child: Text(
              appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          toggle,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const AppIcon(size: 36), toggle],
    );
  }
}
