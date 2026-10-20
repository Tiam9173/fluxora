import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/external_control.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/manager/hotkey_manager.dart';
import 'package:fluxora/manager/manager.dart';
import 'package:fluxora/plugins/app.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controller.dart';
import 'pages/pages.dart';
import 'package:fluxora/plugins/vpn.dart';
import 'package:fluxora/views/proxies/notification_switch_card.dart';
import 'package:flutter/services.dart';

/// P2.6-D: error boundary for fire-and-forget background tasks.
///
/// `unawaited(...)` only silences the "discarded future" signal — it does **not**
/// stop an async failure from becoming an *unhandled* async error. A `Timer`
/// callback has no `await` boundary above it, so a failure there surfaces as a
/// raw zone error instead of a diagnosable log line.
///
/// This keeps the task fire-and-forget (the caller is never awaited, so startup
/// and the timer loop are not blocked) while making a failure observable. The
/// error is **not** swallowed: it is handed to [onError] when provided, and
/// logged otherwise.
Future<void> runDetachedTask(
  Future<void> Function() task, {
  String label = 'detached task',
  void Function(Object error, StackTrace stackTrace)? onError,
}) async {
  try {
    await task();
  } catch (error, stackTrace) {
    if (onError != null) {
      onError(error, stackTrace);
      return;
    }
    commonPrint.log('[$label] failed: $error\n$stackTrace');
  }
}

/// 关闭"只有卡片"的界面。
///
/// 只调用 SystemNavigator.pop() 会 finish 掉 Activity，但任务栈里若还有代理
/// 页之类的界面，系统会把它顶到前台 —— 用户看到的就是"关掉卡片却还在 App
/// 里"。原生侧先 moveTaskToBack，再 finish，才会回到点通知之前的界面。
Future<void> _closeCardOnlyMode() async {
  // 先退出卡片模式：Activity 结束后进程可能还活着，下次正常打开 App 时
  // 这个标志如果还是 true，会又只显示一张卡片。
  globalState.cardOnlyMode.value = false;
  try {
    await const MethodChannel('vpn').invokeMethod('closeCardActivity');
  } catch (_) {
    // 通道不可用（例如桌面端）时退回默认行为。
    SystemNavigator.pop();
  }
}

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application>
    with WidgetsBindingObserver {
  Timer? _autoUpdateGroupTaskTimer;
  Timer? _autoUpdateProfilesTaskTimer;

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );

  ColorScheme _getAppColorScheme({
    required Brightness brightness,
    int? primaryColor,
  }) {
    return ref.watch(genColorSchemeProvider(brightness));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    globalState.backgroundMode.addListener(_syncAutoUpdateTasks);
    _syncAutoUpdateTasks();
    globalState.appController = AppController(context, ref);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initApp());
    });
  }

  bool get _isForeground {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    return lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed;
  }

  Future<void> _initApp() async {
    final currentContext = globalState.navigatorKey.currentContext;
    if (currentContext != null && currentContext != context) {
      // P2.6-D: re-target the single controller at the mounted navigator context
      // instead of constructing a second `AppController`.
      //
      // The second construction used to replace the instance created in
      // `initState` and orphan it. That is not merely a wasted allocation: every
      // per-instance guard (`_coreLifecycleLock`, `_coreGeneration`, the
      // in-flight `_isUpdatingGroups` / `_updatingProfileIds` state) is per
      // object, so the single-flight and stale-result guarantees were silently
      // split across two controllers for the rest of the session.
      globalState.appController.rebindContext(currentContext);
    }
    await globalState.appController.init();
    try {
      await ExternalControl.start();
    } catch (e) {
      commonPrint.log('ExternalControl start failed: $e');
    }
    globalState.appController.initLink();
    if (system.isAndroid) {
      app.initShortcuts();
    }
    Future.delayed(const Duration(seconds: 3), () {
      globalState.warmupCommonDialog();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncAutoUpdateTasks();
    if (state == AppLifecycleState.resumed) {
      // A notification button can bring the app back from the background; the
      // request is stored natively and only Dart can act on it.
      Vpn().consumePendingNotificationAction();
      if (system.isAndroid &&
          globalState.config.appSetting.enableHighRefreshRate) {
        _restoreHighRefreshRate();
      }
    }
  }

  void _syncAutoUpdateTasks() {
    final shouldRun = _isForeground && !globalState.backgroundMode.value;
    if (!shouldRun) {
      _autoUpdateGroupTaskTimer?.cancel();
      _autoUpdateGroupTaskTimer = null;
      if (!system.isDesktop) {
        _autoUpdateProfilesTaskTimer?.cancel();
        _autoUpdateProfilesTaskTimer = null;
      }
      return;
    }
    if (_autoUpdateGroupTaskTimer == null) {
      _autoUpdateGroupTask();
    }
    if (_autoUpdateProfilesTaskTimer == null) {
      _autoUpdateProfilesTask();
    }
  }

  Future<void> _restoreHighRefreshRate() async {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      commonPrint.log('Failed to restore high refresh rate: $e');
    }
  }

  void _autoUpdateGroupTask() {
    _autoUpdateGroupTaskTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => globalState.appController.updateGroupsDebounce(),
    );
  }

  void _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer.periodic(
      const Duration(hours: 24),
      // P2.6-D: fire-and-forget by design (the 24h tick must not be blocked),
      // but routed through an explicit boundary: a `Timer` callback has no
      // `await` above it, so a bare `unawaited(...)` let a failure escape as an
      // unhandled async error.
      (_) => unawaited(
        runDetachedTask(
          globalState.appController.autoUpdateProfiles,
          label: 'profile auto-update',
        ),
      ),
    );
  }

  Widget _buildPlatformState(Widget child) {
    if (system.isDesktop) {
      return WindowManager(
        child: TrayManager(
          child: HotKeyManager(
            child: ProxyManager(child: SmartAutoStopManager(child: child)),
          ),
        ),
      );
    }
    return AndroidManager(
      child: TileManager(child: SmartAutoStopManager(child: child)),
    );
  }

  Widget _buildState(Widget child) {
    return AppStateManager(
      child: ClashManager(
        child: ConnectivityManager(
          onConnectivityChanged: (results) async {
            if (!results.contains(ConnectivityResult.vpn)) {
              clashCore.closeConnections();
            }
            if (system.isMacOS) {
              // Wait for DHCP and the default route to settle before moving the
              // managed DNS from the previous network to the new one.
              await Future.delayed(const Duration(seconds: 1));
              if (!mounted) return;
              final dnsState = ref.read(autoSetSystemDnsStateProvider);
              await macOS?.updateDns(!(dnsState.a && dnsState.b));
            }
            globalState.appController.updateLocalIp();
            globalState.appController.addCheckIpNumDebounce();
            // item 6 (Bettbox 1.19.5 alignment) — a network change invalidates
            // every DNS answer cached against the previous network, so flush the
            // core cache. Kept last: when the core is idle the underlying invoke
            // only resolves on its 30 s timeout (`common/future.dart:13`), and
            // the local-IP refresh above must not wait on that.
            await clashCore.flushDnsCache();
          },
          child: child,
        ),
      ),
    );
  }

  Widget _buildPlatformApp(Widget child) {
    if (system.isDesktop) {
      return WindowHeaderContainer(child: child);
    }
    return VpnManager(child: child);
  }

  Widget _buildApp(Widget child) {
    return MessageManager(child: ThemeManager(child: child));
  }

  @override
  Widget build(context) {
    return _buildPlatformState(
      _buildState(
        Consumer(
          builder: (_, ref, child) {
            final locale = ref.watch(
              appSettingProvider.select((state) => state.locale),
            );
            final themeProps = ref.watch(themeSettingProvider);
            final fontFamily = themeProps.useHarmonyFont
                ? 'HarmonyOS_Sans'
                : null;

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              // MaterialApp 自己会画一层背景色，卡片模式的透明 Material 只是
              // 盖在它上面 —— 不把它也设透明，卡片周围永远是纯黑。
              // 正常模式下每个页面都有自己的 Scaffold 背景，这层看不到。
              color: Colors.transparent,
              navigatorKey: globalState.navigatorKey,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              builder: (_, child) {
                // 必须监听而不是直接读 value：`builder` 只在路由/父级重建时
                // 跑，光改 ValueNotifier 不会让它重跑 —— 卡片模式就永远进不去，
                // 表现为"点了通知还是在 App 里弹了个普通对话框"。
                return ValueListenableBuilder<bool>(
                  valueListenable: globalState.cardOnlyMode,
                  builder: (_, cardOnly, _) {
                // Card-only mode keeps this MaterialApp (and therefore the
                // theme) but replaces everything it draws. The window behind is
                // translucent, so what shows around the card is whatever app the
                // user was in.
                if (cardOnly) {
                  final colors = Theme.of(context).colorScheme;
                  return Material(
                    color: Colors.transparent,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _closeCardOnlyMode,
                      // 一层很淡的压暗：App 内的卡片是弹在遮罩上的，没有这层
                      // 会显得卡片"浮在壁纸上"，和 App 内的观感差很多。
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.28),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: GestureDetector(
                              onTap: () {},
                              child: Material(
                                elevation: 12,
                                borderRadius: BorderRadius.circular(24),
                                clipBehavior: Clip.antiAlias,
                                color: colors.surface,
                                child: SwitchCard(
                                  onFinished: _closeCardOnlyMode,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: globalState.animationEnabled,
                    builder: (_, enabled, _) {
                      return TickerMode(
                        enabled: enabled,
                        child: AppEnvManager(
                          child: _buildApp(
                            AppSidebarContainer(
                              child: _buildPlatformApp(child!),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
                  },
                );
              },
              scrollBehavior: BaseScrollBehavior(),
              title: appName,
              locale:
                  utils.getLocaleForString(locale) ?? utils.getSystemLocale(),
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              themeMode: themeProps.themeMode,
              theme: ThemeData(
                useMaterial3: true,
                pageTransitionsTheme: _pageTransitionsTheme,
                colorScheme: _getAppColorScheme(
                  brightness: Brightness.light,
                  primaryColor: themeProps.primaryColor,
                ),
                fontFamily: fontFamily,
                // Fluxora typography (D4.2 §9): 6 levels, 3 weights. The token
                // styles leave `fontFamily` null, so they inherit the
                // `fontFamily` above (HarmonyOS_Sans or the platform default).
                textTheme: FluxoraTypography.textTheme(),
                floatingActionButtonTheme: const FloatingActionButtonThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  elevation: FluxoraElevation.raised,
                  hoverElevation: FluxoraElevation.menu,
                ),
                dialogTheme: DialogThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: FluxoraElevation.modal,
                ),
                bottomSheetTheme: const BottomSheetThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                ),
                popupMenuTheme: const PopupMenuThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  elevation: FluxoraElevation.menu,
                ),
                dividerTheme: DividerThemeData(
                  color: _getAppColorScheme(
                    brightness: Brightness.light,
                    primaryColor: themeProps.primaryColor,
                  ).outlineVariant.withValues(alpha: 0.6),
                  thickness: 1,
                  space: 1,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                    borderSide: BorderSide(
                      color: _getAppColorScheme(
                        brightness: Brightness.light,
                        primaryColor: themeProps.primaryColor,
                      ).outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                    borderSide: BorderSide(
                      color: _getAppColorScheme(
                        brightness: Brightness.light,
                        primaryColor: themeProps.primaryColor,
                      ).primary,
                      width: 2,
                    ),
                  ),
                ),
                chipTheme: ChipThemeData(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  side: BorderSide(
                    color: _getAppColorScheme(
                      brightness: Brightness.light,
                      primaryColor: themeProps.primaryColor,
                    ).outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                tooltipTheme: const TooltipThemeData(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  textStyle: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                pageTransitionsTheme: _pageTransitionsTheme,
                colorScheme: _getAppColorScheme(
                  brightness: Brightness.dark,
                  primaryColor: themeProps.primaryColor,
                ).toPureBlack(themeProps.pureBlack),
                fontFamily: fontFamily,
                // Same Fluxora typography scale as the light theme.
                textTheme: FluxoraTypography.textTheme(),
                floatingActionButtonTheme: const FloatingActionButtonThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  elevation: FluxoraElevation.raised,
                  hoverElevation: FluxoraElevation.menu,
                ),
                dialogTheme: DialogThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: FluxoraElevation.modal,
                ),
                bottomSheetTheme: const BottomSheetThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                ),
                popupMenuTheme: const PopupMenuThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  elevation: FluxoraElevation.menu,
                ),
                dividerTheme: DividerThemeData(
                  color:
                      _getAppColorScheme(
                            brightness: Brightness.dark,
                            primaryColor: themeProps.primaryColor,
                          )
                          .toPureBlack(themeProps.pureBlack)
                          .outlineVariant
                          .withValues(alpha: 0.45),
                  thickness: 1,
                  space: 1,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                    borderSide: BorderSide(
                      color:
                          _getAppColorScheme(
                                brightness: Brightness.dark,
                                primaryColor: themeProps.primaryColor,
                              )
                              .toPureBlack(themeProps.pureBlack)
                              .outlineVariant
                              .withValues(alpha: 0.45),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                    borderSide: BorderSide(
                      color: _getAppColorScheme(
                        brightness: Brightness.dark,
                        primaryColor: themeProps.primaryColor,
                      ).toPureBlack(themeProps.pureBlack).primary,
                      width: 2,
                    ),
                  ),
                ),
                chipTheme: ChipThemeData(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  side: BorderSide(
                    color:
                        _getAppColorScheme(
                              brightness: Brightness.dark,
                              primaryColor: themeProps.primaryColor,
                            )
                            .toPureBlack(themeProps.pureBlack)
                            .outlineVariant
                            .withValues(alpha: 0.45),
                  ),
                ),
                tooltipTheme: const TooltipThemeData(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  textStyle: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              home: child!,
            );
          },
          child: const HomePage(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    globalState.backgroundMode.removeListener(_syncAutoUpdateTasks);
    WidgetsBinding.instance.removeObserver(this);
    linkManager.destroy();
    _autoUpdateGroupTaskTimer?.cancel();
    _autoUpdateProfilesTaskTimer?.cancel();
    ExternalControl.stop();
    if (!system.isAndroid && !globalState.isExiting) {
      unawaited(globalState.appController.handleExit());
    }
    super.dispose();
  }
}
