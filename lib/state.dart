import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/plugins/app.dart';
import 'package:fluxora/plugins/service.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/providers/state.dart' as providers_state;

import 'package:fluxora/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as flutter_riverpod;
import 'package:material_color_utilities/palettes/core_palette.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:synchronized/synchronized.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common/common.dart';
import 'controller.dart';
import 'manager/chain_proxy_manager.dart';
import 'manager/warp_manager.dart';
import 'manager/profile_chain_manager.dart';
import 'models/models.dart';
import 'package:fluxora/common/node_overrides.dart';

typedef UpdateTasks = List<FutureOr Function()>;

class GlobalState {
  static GlobalState? _instance;
  Map<CacheTag, FixedMap<String, double>> computeHeightMapCache = {};
  bool isService = false;
  bool isExiting = false;
  bool isScreenOn = true;

  /// 重启内核时是否保持 VPN 服务在线。
  ///
  /// `false`（默认）沿用 Bettbox 的行为：服务状态跟着内核走，通知栏会看到
  /// 服务短暂断开。`true` 保持隧道不断，避免所有 App 在重启窗口内掉网。
  bool restartCoreKeepsService = false;
  Timer? timer;
  Timer? groupsUpdateTimer;
  Config? _config;

  bool get hasConfig => _config != null;

  Config get config =>
      _config ??
      Config(
        themeProps: defaultThemeProps,
        patchClashConfig: system.isAndroid
            ? const ClashConfig(findProcessMode: FindProcessMode.always)
            : defaultClashConfig,
        networkProps: defaultNetworkProps.copyWith(
          systemProxy: system.isDesktop,
        ),
        appSetting: defaultAppSettingProps.copyWith(
          showStartSwitch: _isAndroidTV ?? false,
        ),
      );

  set config(Config value) => _config = value;
  late AppState appState;
  bool isPre = true;
  String? coreSHA256;
  late PackageInfo packageInfo;
  Function? updateCurrentDelayDebounce;
  VoidCallback? focusDashboardStartSwitch;
  bool isDashboardStartSwitchFocused = false;
  late Measure measure;
  late CommonTheme theme;
  late Color accentColor;
  // ignore: deprecated_member_use
  CorePalette? corePalette;
  DateTime? startTime;
  UpdateTasks tasks = [];
  final navigatorKey = GlobalKey<NavigatorState>();
  final backgroundMode = ValueNotifier<bool>(false);
  final animationEnabled = ValueNotifier<bool>(true);

  /// True while the app is only hosting the notification switch card over the
  /// desktop. The window is translucent in that mode, so anything the app drew
  /// besides the card would float on the launcher.
  final cardOnlyMode = ValueNotifier<bool>(false);
  AppController? _appController;
  bool? _isAndroidTV;
  int _taskLoopToken = 0;
  bool _isExecutingTasks = false;
  bool _needsTaskRestart = false;
  Timer? _backgroundCleanupTimer;
  final Lock _scriptEvaluateLock = Lock();
  bool isInit = false;

  bool get hasMediaUnlockWidget {
    final widgets = system.isAndroid
        ? config.appSetting.mobileDashboardWidgets
        : config.appSetting.desktopDashboardWidgets;
    return widgets.contains(DashboardWidget.mediaUnlock) ||
        widgets.contains(DashboardWidget.mediaUnlockSmall);
  }

  bool get isStart => startTime != null && startTime!.isBeforeNow;

  /// Whether [appController] has been bound. Production binds it once in
  /// `application.dart`; unit tests that never boot the app must not be forced
  /// to construct an [AppController] just to read global state.
  bool get hasAppController => _appController != null;

  AppController get appController => _appController!;

  set appController(AppController appController) {
    _appController = appController;
    isInit = true;
  }

  GlobalState._internal();

  factory GlobalState() {
    _instance ??= GlobalState._internal();
    return _instance!;
  }

  Future<void> initApp(int version) async {
    isExiting = false;
    coreSHA256 = const String.fromEnvironment('CORE_SHA256');
    if (system.isWindows && (coreSHA256 == null || coreSHA256!.isEmpty)) {
      coreSHA256 = await _calcCoreSHA256();
    }
    isPre = const String.fromEnvironment('APP_ENV') != 'stable';
    appState = AppState(
      brightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
      version: version,
      viewSize: Size.zero,
      requests: FixedList(maxLength),
      logs: FixedList(maxLength),
      traffics: FixedList(30),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    await _initDynamicColor();
    await init();
  }

  Future<String?> _calcCoreSHA256() async {
    try {
      final file = File(appPath.corePath);
      if (!await file.exists()) return null;
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString();
    } catch (e) {
      commonPrint.log('Failed to calculate core SHA256: $e');
      return null;
    }
  }

  Future<void> _initDynamicColor() async {
    try {
      corePalette = await DynamicColorPlugin.getCorePalette();
      accentColor =
          await DynamicColorPlugin.getAccentColor() ??
          Color(defaultPrimaryColor);
    } catch (_) {}
  }

  Future<void> init() async {
    final platformInfo = await PackageInfo.fromPlatform();
    packageInfo = PackageInfo(
      appName: AppIdentity.displayName,
      packageName: AppIdentity.packageId,
      version: AppIdentity.appVersion.isNotEmpty
          ? AppIdentity.appVersion
          : platformInfo.version,
      buildNumber: AppIdentity.appVersion.isNotEmpty
          ? ''
          : platformInfo.buildNumber,
      buildSignature: platformInfo.buildSignature,
      installerStore: platformInfo.installerStore,
    );
    if (system.isAndroid) {
      _isAndroidTV = await app.isAndroidTV();
    }
    config =
        await preferences.getConfig() ??
        Config(
          themeProps: defaultThemeProps,
          patchClashConfig: system.isAndroid
              ? const ClashConfig(findProcessMode: FindProcessMode.always)
              : defaultClashConfig,
          networkProps: defaultNetworkProps.copyWith(
            systemProxy: system.isDesktop,
          ),
          appSetting: defaultAppSettingProps.copyWith(
            // Android TV always showed it; a phone now does too. On a phone the
            // Hero sits at the top of the dashboard grid, but the title-bar
            // switch stays reachable without scrolling — which is the whole
            // point. Desktop keeps it off: it has the tray and the Hero is
            // already prominent there.
            showStartSwitch: defaultShowStartSwitch(
              isAndroidTV: _isAndroidTV == true,
            ),
          ),
        );
    // P1 ② — move legacy inline script content into side files before
    // anything reads it, and persist right away so the migration runs once.
    final scriptProps = await config.scriptProps.externalize();
    if (scriptProps != config.scriptProps) {
      config = config.copyWith(scriptProps: scriptProps);
      await preferences.saveConfig(config);
    }
    await globalState.migrateOldData(config);
    await chainProxyManager.init();
    await warpManager.init();
    await profileChainManager.init();
    final locale =
        utils.getLocaleForString(config.appSetting.locale) ??
        utils.getSystemLocale();
    await AppLocalizations.load(locale);
  }

  bool get isAndroidTV => _isAndroidTV ?? false;

  String get ua => config.patchClashConfig.globalUa ?? packageInfo.ua;

  Future<void> startUpdateTasks([UpdateTasks? tasks]) async {
    if (tasks != null) {
      this.tasks = tasks;
    }
    final token = ++_taskLoopToken;
    timer?.cancel();
    timer = null;
    if (_isExecutingTasks) {
      _needsTaskRestart = true;
      return;
    }
    await _runUpdateLoop(token);
  }

  Future<void> _runUpdateLoop(int token) async {
    if (token != _taskLoopToken) return;
    _isExecutingTasks = true;
    try {
      await executorUpdateTask();
    } finally {
      _isExecutingTasks = false;
    }
    if (_needsTaskRestart) {
      _needsTaskRestart = false;
      await _runUpdateLoop(_taskLoopToken);
      return;
    }
    if (token != _taskLoopToken) return;
    timer = Timer(const Duration(seconds: 1), () {
      unawaited(_runUpdateLoop(token));
    });
  }

  Future<void> executorUpdateTask() async {
    for (final task in tasks) {
      try {
        await task();
      } catch (e) {
        commonPrint.log('Background task failed: $e');
      }
    }
    timer = null;
  }

  void stopUpdateTasks() {
    _taskLoopToken++;
    _needsTaskRestart = false;
    timer?.cancel();
    timer = null;
  }

  Future<void> handleBackground() async {
    if (system.isDesktop) {
      final isMinimized = await window?.isMinimized ?? false;
      final isVisible = await window?.isVisible ?? true;
      if (!isMinimized && isVisible) {
        return;
      }
      animationEnabled.value = false;
    }
    if (!backgroundMode.value) {
      backgroundMode.value = true;
      _scheduleBackgroundCleanup();
    }
    render?.pause();

    final vpnProps = appController.ref.read(vpnSettingProvider);
    final keepTrafficUpdates =
        (system.isAndroid && vpnProps.networkSpeedNotification) ||
        (system.isMacOS && vpnProps.enableTraySpeed);
    if (!keepTrafficUpdates) {
      stopUpdateTasks();
    }

    dashboardRefreshManager.stop();
  }

  void handleForeground() {
    if (system.isDesktop) {
      animationEnabled.value = true;
    }
    if (!backgroundMode.value) {
      return;
    }
    backgroundMode.value = false;
    _backgroundCleanupTimer?.cancel();
    _backgroundCleanupTimer = null;
    _syncVpnState();
  }

  @visibleForTesting
  Future<void> testSyncVpnState() => _syncVpnState();

  Future<void> _syncVpnState() async {
    if (!system.isAndroid) return;
    try {
      final actuallyRunning = await service?.getStatus() ?? false;
      final flutterState = appState.runTime != null;

      if (actuallyRunning && !flutterState) {
        await updateStartTime();
        if (startTime != null) {
          appState = appState.copyWith(runTime: 0);
          await startUpdateTasks([appController.updateTraffic]);
        }
      } else if (!actuallyRunning && flutterState) {
        appState = appState.copyWith(runTime: null);
        startTime = null;
      }
    } catch (e) {
      commonPrint.log('Sync VPN state error: $e');
    }
  }

  Future<void> resumeForegroundUpdates() async {
    dashboardRefreshManager.start();
    if (!isStart) {
      return;
    }

    await appController.updateRunTime();
    await appController.updateTraffic();
    await startUpdateTasks([
      appController.updateRunTime,
      appController.updateTraffic,
    ]);
  }

  void _scheduleBackgroundCleanup() {
    _backgroundCleanupTimer?.cancel();
    _backgroundCleanupTimer = Timer(const Duration(minutes: 3), () {
      _backgroundCleanupTimer = null;
      if (!backgroundMode.value) {
        return;
      }
      cleanupBackgroundResources();
    });
  }

  void cleanupBackgroundResources() async {
    if (!backgroundMode.value) return;

    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clearLiveImages();

    await Future.delayed(const Duration(milliseconds: 250));
    if (!backgroundMode.value) return;
    WidgetsBinding.instance.handleMemoryPressure();

    await Future.delayed(const Duration(milliseconds: 250));
    if (!backgroundMode.value) return;
    await clashCore.requestGc();
  }

  Future<void> handleStart([
    UpdateTasks? tasks,
    bool includeVpnService = true,
  ]) async {
    startTime ??= DateTime.now();
    if (system.isAndroid && isService) {
      await clashLibHandler?.startListener();
    } else {
      await clashCore.startListener();
    }
    if (includeVpnService) {
      await service?.startVpn();
    }
    final prefs = await preferences.sharedPreferencesCompleter.future;
    await prefs?.setBool('is_vpn_running', true);

    if (system.isAndroid) {
      await service?.setQuickResponse(config.vpnProps.quickResponse);
      await service?.setHighPriorityNotification(
        config.vpnProps.highPriorityNotification,
      );
    }
    await startUpdateTasks(tasks);
  }

  @visibleForTesting
  DateTime? testStartTimeOverride;

  Future updateStartTime() async {
    if (testStartTimeOverride != null) {
      startTime = testStartTimeOverride;
      return;
    }
    startTime = await clashLib?.getRunTime();
  }

  void updateWakelockState(bool enabled) {
    if (_appController != null) {
      final container = _appController!.context;
      if (container.mounted) {
        final providerContainer = flutter_riverpod.ProviderScope.containerOf(
          container,
          listen: false,
        );
        providerContainer
                .read(providers_state.wakelockStateProvider.notifier)
                .state =
            enabled;
      }
    }
  }

  /// VPN 服务当前是否真的在跑。
  ///
  /// `stopVpn()` 返回不代表系统已经拆完隧道，重启内核时要靠这个轮询确认，
  /// 否则紧接着的 start 会撞上旧会话。
  Future<bool> isVpnServiceRunning() async => await service?.getStatus() ?? false;

  Future handleStop([bool includeVpnService = true]) async {
    startTime = null;
    if (system.isAndroid && isService) {
      await clashLibHandler?.stopListener();
    } else {
      await clashCore.stopListener();
    }
    if (!includeVpnService) {
      stopUpdateTasks();
      return;
    }
    await service?.stopVpn();
    final prefs = await preferences.sharedPreferencesCompleter.future;
    await prefs?.setBool('is_vpn_running', false);
    if (system.isDesktop) {
      await prefs?.setBool('is_tun_running', false);
    }
    stopUpdateTasks();
  }

  Future<bool?> showMessage({
    String? title,
    required InlineSpan message,
    String? confirmText,
    bool cancelable = true,
  }) async {
    return await showCommonDialog<bool>(
      child: Builder(
        builder: (context) {
          return CommonDialog(
            title: title ?? appLocalizations.tip,
            actions: [
              if (cancelable)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(appLocalizations.cancel),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text(confirmText ?? appLocalizations.confirm),
              ),
            ],
            child: Container(
              width: 300,
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.labelLarge,
                    children: [message],
                  ),
                  style: const TextStyle(overflow: TextOverflow.visible),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<T?> showCommonDialog<T>({
    required Widget child,
    bool dismissible = true,
  }) async {
    final state = navigatorKey.currentState;
    if (state == null) return null;
    final context = state.context;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showGeneralDialog<T>(
      context: context,
      barrierColor: isDark ? const Color(0xCC000000) : const Color(0x99000000),
      barrierDismissible: dismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return RepaintBoundary(
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: curved.drive(Tween<double>(begin: 0.94, end: 1.0)),
              child: child,
            ),
          ),
        );
      },
    );
  }

  bool _dialogWarmedUp = false;

  void warmupCommonDialog() {
    if (_dialogWarmedUp) return;
    _dialogWarmedUp = true;

    final state = navigatorKey.currentState;
    if (state == null) return;
    final overlayState = state.overlay;
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          entry.remove();
          entry.dispose();
        });
        return Offstage(
          offstage: true,
          child: RepaintBoundary(
            child: Material(
              type: MaterialType.transparency,
              child: FadeTransition(
                opacity: const AlwaysStoppedAnimation(1.0),
                child: ScaleTransition(
                  scale: const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(blurRadius: 10, color: Colors.black12),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline),
                        SizedBox(height: 8),
                        Text('warmup'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(entry);
  }

  void showNotifier(
    String text, {
    VoidCallback? onAction,
    String? actionLabel,
    bool showCountdown = false,
  }) {
    if (text.isEmpty) return;
    navigatorKey.currentContext?.showNotifier(
      text,
      onAction: onAction,
      actionLabel: actionLabel,
      showCountdown: showCountdown,
    );
  }

  Future<void> openUrl(String url, {bool needConfirm = false}) async {
    if (needConfirm) {
      final res = await showMessage(
        message: TextSpan(text: url),
        title: appLocalizations.externalLink,
        confirmText: appLocalizations.go,
      );
      if (res != true) {
        return;
      }
    }
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> migrateOldData(Config config) async {
    final clashConfig = await preferences.getClashConfig();
    if (clashConfig != null) {
      config = config.copyWith(patchClashConfig: clashConfig);
      preferences.clearClashConfig();
      preferences.saveConfig(config);
    }

    if (config.appSetting.locale == null) {
      // First run: store the "follow system" sentinel rather than the locale
      // resolved right now. Writing the concrete value pinned a fresh install
      // to whatever language the device happened to use at that moment, so
      // changing the system language afterwards had no effect.
      config = config.copyWith(
        appSetting: config.appSetting.copyWith(locale: systemLocaleValue),
      );
      preferences.saveConfig(config);
      this.config = config;
    }
  }

  CoreState getCoreState() {
    final currentProfile = config.currentProfile;
    return CoreState(
      vpnProps: config.vpnProps,
      onlyStatisticsProxy: config.appSetting.onlyStatisticsProxy,
      currentProfileName: currentProfile?.label ?? currentProfile?.id ?? '',
      bypassDomain: config.networkProps.bypassDomain,
    );
  }

  Future<SetupParams> getSetupParams({required ClashConfig pathConfig}) async {
    final clashConfig = await patchRawConfig(patchConfig: pathConfig);
    await _writeRunningConfig(clashConfig);
    return SetupParams(
      selectedMap: config.currentProfile?.selectedMap ?? {},
      testUrl: config.appSetting.testUrl,
      overrideTestUrl: config.overrideTestUrl,
    );
  }

  Future<void> _writeRunningConfig(Map<String, dynamic> clashConfig) async {
    final content = await encodeCompactYamlTask(clashConfig);
    final configPath = await appPath.configFilePath;
    final tempFile = File('$configPath.tmp');
    await tempFile.writeAsString(content, flush: true);
    try {
      await tempFile.rename(configPath);
    } catch (_) {
      final targetFile = File(configPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(configPath);
    }
  }

  Future<Map<String, dynamic>> patchRawConfig({
    required ClashConfig patchConfig,
    Profile? profile,
  }) async {
    final targetProfile = profile ?? config.currentProfile;
    if (targetProfile == null) {
      return <String, dynamic>{};
    }
    final profileId = targetProfile.id;
    final configMap = await getProfileConfig(profileId);
    final rawConfig = await handleEvaluate(configMap, profile: targetProfile);
    final originalProxyGroups = rawConfig['proxy-groups'];

    final realPatchConfig = patchConfig.copyWith(
      dns: patchConfig.dns.copyWith(
        fakeIpRangeV6: patchConfig.dns.effectiveFakeIpRangeV6(
          ipv6Enabled: patchConfig.ipv6,
        ),
      ),
      tun: patchConfig.tun.getRealTun(
        config.networkProps.bypassPrivateRoute,
        fakeIpRange: patchConfig.dns.fakeIpRange,
        fakeIpRangeV6: patchConfig.dns.effectiveFakeIpRangeV6(
          ipv6Enabled: patchConfig.ipv6,
        ),
        bypassPrivateRouteAddress:
            config.networkProps.realBypassPrivateRouteAddress,
      ),
    );
    // 通知栏切换卡片走的是内核的 HTTP 接口，控制器必须是开着的。用户关掉
    // 「外部控制器」时仍然绑到本机回环地址：只有本机进程能访问，和"对局域网
    // 开放"是两件事，后者才由 allowLan 控制。
    // 卡片功能依赖内核 HTTP 接口；用户可以在设置里关掉这个强制开启。
    final forceLoopback = (await Preferences()
            .sharedPreferencesCompleter
            .future)
        ?.getBool('force_loopback_controller') ??
        true;
    final controllerValue =
        (realPatchConfig.externalController == ExternalControllerStatus.open ||
                forceLoopback)
            ? ExternalControllerStatus.open.value
            : realPatchConfig.externalController.value;
    rawConfig['external-controller'] = realPatchConfig.allowLan
        ? controllerValue.replaceAll('127.0.0.1', '0.0.0.0')
        : controllerValue;
    {
      final secret = realPatchConfig.secret;
      if (secret != null && secret.isNotEmpty) {
        rawConfig['secret'] = secret;
      }
      // 通知栏切换卡片是原生 Activity，它不跑 Flutter，拿不到这份配置。
      // 把地址和密钥写进 SharedPreferences，原生侧直接读。
      unawaited(_persistCoreEndpoint(
        rawConfig['external-controller']?.toString(),
        realPatchConfig.secret,
      ));
    }
    rawConfig['external-ui'] = await appPath.uiPath;
    rawConfig['external-ui-url'] =
        'https://github.com/Zephyruso/zashboard/releases/latest/download/dist.zip';
    rawConfig.remove('external-ui-name');
    if (rawConfig['interface-name'] == null) {
      rawConfig['interface-name'] = '';
    }
    rawConfig['tcp-concurrent'] = realPatchConfig.tcpConcurrent;
    rawConfig['unified-delay'] = realPatchConfig.unifiedDelay;
    rawConfig['ipv6'] = realPatchConfig.ipv6;
    rawConfig['log-level'] = realPatchConfig.logLevel.name;
    rawConfig['port'] = 0;
    rawConfig['socks-port'] = 0;
    rawConfig['keep-alive-interval'] = realPatchConfig.keepAliveInterval;
    rawConfig['mixed-port'] = realPatchConfig.mixedPort;
    rawConfig['port'] = realPatchConfig.port;
    rawConfig['socks-port'] = realPatchConfig.socksPort;
    rawConfig['redir-port'] = realPatchConfig.redirPort;
    rawConfig['tproxy-port'] = realPatchConfig.tproxyPort;
    rawConfig['find-process-mode'] = realPatchConfig.findProcessMode.name;
    rawConfig['allow-lan'] = realPatchConfig.allowLan;
    // item 6 (Bettbox 1.19.3) — LAN proxy credentials.
    //
    // Only emitted when there is something to authenticate: an absent key and an
    // empty array both mean "no credentials required" to mihomo, but leaving the
    // key out keeps the generated config identical to before for every user who
    // never touches this feature. `skip-auth-prefixes` rides along because it is
    // meaningless without credentials to skip.
    if (realPatchConfig.authentication.isNotEmpty) {
      rawConfig['authentication'] = realPatchConfig.authentication;
      rawConfig['skip-auth-prefixes'] = realPatchConfig.skipAuthPrefixes;
    }
    rawConfig['mode'] = realPatchConfig.mode.name;
    if (rawConfig['tun'] == null) {
      rawConfig['tun'] = <String, dynamic>{};
    }
    rawConfig['tun']['enable'] = realPatchConfig.tun.enable;
    rawConfig['tun']['device'] = realPatchConfig.tun.device;
    final dnsHijack = realPatchConfig.tun.dnsHijack;
    rawConfig['tun']['dns-hijack'] = dnsHijack.isEmpty
        ? const ['any:53']
        : dnsHijack;
    rawConfig['tun']['stack'] = realPatchConfig.tun.stack.name;
    rawConfig['tun']['route-address'] = realPatchConfig.tun.routeAddress;
    rawConfig['tun']['route-exclude-address'] =
        realPatchConfig.tun.routeExcludeAddress;
    rawConfig['tun']['auto-route'] = !system.isAndroid;
    rawConfig['tun']['auto-detect-interface'] = !system.isAndroid;
    rawConfig['tun']['auto-redirect'] = system.isLinux;
    rawConfig['tun']['strict-route'] = realPatchConfig.tun.strictRoute;
    rawConfig['tun']['endpoint-independent-nat'] =
        realPatchConfig.tun.endpointIndependentNat;
    rawConfig['tun']['disable-icmp-forwarding'] =
        realPatchConfig.tun.disableIcmpForwarding;
    rawConfig['tun']['mtu'] = realPatchConfig.tun.mtu;
    rawConfig['geodata-loader'] = realPatchConfig.geodataLoader.name;
    rawConfig['geodata-mode'] = false;
    if (rawConfig['sniffer']?['sniff'] != null) {
      for (final value in (rawConfig['sniffer']?['sniff'] as Map).values) {
        if (value['ports'] != null && value['ports'] is List) {
          value['ports'] =
              value['ports']?.map((item) => item.toString()).toList() ?? [];
        }
      }
    }
    if (rawConfig['profile'] == null) {
      rawConfig['profile'] = <String, dynamic>{};
    }
    if (rawConfig['proxy-providers'] != null) {
      final proxyProviders = rawConfig['proxy-providers'] as Map;
      for (final key in proxyProviders.keys) {
        final proxyProvider = proxyProviders[key];
        if (proxyProvider['type'] != 'http') {
          continue;
        }
        if (proxyProvider['url'] != null) {
          proxyProvider['path'] = await appPath.getProvidersFilePath(
            targetProfile.id,
            'proxies',
            proxyProvider['url'],
          );
        }
      }
    }

    if (rawConfig['rule-providers'] != null) {
      final ruleProviders = rawConfig['rule-providers'] as Map;
      for (final key in ruleProviders.keys) {
        final ruleProvider = ruleProviders[key];
        if (ruleProvider['type'] != 'http') {
          continue;
        }
        if (ruleProvider['url'] != null) {
          ruleProvider['path'] = await appPath.getProvidersFilePath(
            targetProfile.id,
            'rules',
            ruleProvider['url'],
          );
        }
      }
    }

    if (rawConfig['profile']['store-selected'] == null) {
      rawConfig['profile']['store-selected'] = true;
    }
    if (rawConfig['profile']['store-fake-ip'] == null) {
      rawConfig['profile']['store-fake-ip'] = true;
    }
    rawConfig['geox-url'] = realPatchConfig.geoXUrl.toJson();
    rawConfig['global-ua'] = realPatchConfig.globalUa;
    if (rawConfig['hosts'] == null) {
      rawConfig['hosts'] = <String, dynamic>{};
    }
    for (final host in realPatchConfig.hosts.entries) {
      rawConfig['hosts'][host.key] = host.value.splitByMultipleSeparators;
    }

    rawConfig['hosts']['dns.msftncsi.com'] = [
      '131.107.255.255',
      'fd3e:4f5a:5b81::1',
    ];

    if (rawConfig['dns'] == null) {
      rawConfig['dns'] = <String, dynamic>{};
    }
    final isEnableDns = rawConfig['dns']['enable'] == true;
    final overrideDns = globalState.config.overrideDns;
    if (overrideDns || !isEnableDns) {
      final originalDns = rawConfig['dns'] is Map
          ? (rawConfig['dns'] as Map).cast<String, dynamic>()
          : null;
      final originalHosts = rawConfig['hosts'] is Map
          ? (rawConfig['hosts'] as Map).cast<String, dynamic>()
          : null;
      final dns = switch (!isEnableDns) {
        true => realPatchConfig.dns.copyWith(
          nameserver: [...realPatchConfig.dns.nameserver, 'system://'],
        ),
        false => realPatchConfig.dns,
      };
      rawConfig['dns'] = dns.toJson();
      rawConfig['dns']['nameserver-policy'] = <String, dynamic>{};
      for (final entry in dns.nameserverPolicy.entries) {
        rawConfig['dns']['nameserver-policy'][entry.key] =
            entry.value.splitByMultipleSeparators;
      }
      applyDnsNodeOverride(
        rawConfig,
        originalDns: originalDns,
        originalHosts: originalHosts,
      );
    }

    if (rawConfig['dns'] != null &&
        rawConfig['dns']['fallback-filter'] != null) {
      if (rawConfig['dns']['fallback-filter'] is Map) {
        (rawConfig['dns']['fallback-filter'] as Map).remove('geosite');
      }
    }

    if (system.isAndroid && rawConfig['dns']['listen'] != null) {
      final listen = rawConfig['dns']['listen'] as String;
      if (listen.endsWith(':53')) {
        rawConfig['dns']['listen'] = listen.replaceAll(':53', ':10053');
      }
      final noProviders =
          rawConfig['proxy-providers'] == null &&
          rawConfig['rule-providers'] == null;
      final proxyServerNameserver = rawConfig['dns']['proxy-server-nameserver'];
      final hasLocalProxyServerNameserver = switch (proxyServerNameserver) {
        List list => list.any((e) => e.toString().startsWith('127.0.0.1')),
        String str => str.startsWith('127.0.0.1'),
        _ => false,
      };
      if (noProviders &&
          hasLocalProxyServerNameserver &&
          listen.startsWith('0.0.0.0')) {
        rawConfig['dns']['listen'] =
            '127.0.0.1${listen.substring('0.0.0.0'.length)}';
      }
    }

    if (rawConfig['ntp'] == null) {
      rawConfig['ntp'] = {};
    }
    final overrideNtp = globalState.config.overrideNtp;
    if (overrideNtp) {
      final ntp = realPatchConfig.ntp;
      rawConfig['ntp'] = ntp.toJson();
    }
    if (system.isAndroid) {
      rawConfig['ntp']['write-to-system'] = false;
    }
    if (rawConfig['sniffer'] == null) {
      rawConfig['sniffer'] = {};
    }
    final overrideSniffer = globalState.config.overrideSniffer;
    if (overrideSniffer) {
      final sniffer = realPatchConfig.sniffer;
      rawConfig['sniffer'] = sniffer.toJson();
    }
    final guiTunnels = realPatchConfig.tunnels;
    if (guiTunnels.isNotEmpty) {
      final existingTunnels = rawConfig['tunnels'] as List? ?? [];
      final allTunnels = [
        ...existingTunnels,
        ...guiTunnels.map((t) => t.toClashJson()),
      ];
      rawConfig['tunnels'] = allTunnels;
    }
    if (rawConfig['experimental'] == null) {
      rawConfig['experimental'] = {};
    }
    final overrideExperimental = globalState.config.overrideExperimental;
    if (overrideExperimental) {
      final experimental = realPatchConfig.experimental;
      rawConfig['experimental'] = experimental.toJson();
    }

    final nodeExcludeFilter = globalState.config.nodeExcludeFilter;
    final healthCheckTimeout = globalState.config.healthCheckTimeout;
    if ((nodeExcludeFilter.isNotEmpty || healthCheckTimeout != 5000) &&
        rawConfig['proxy-groups'] is List) {
      RegExp? filterRegex;
      if (nodeExcludeFilter.isNotEmpty) {
        try {
          filterRegex = RegExp(nodeExcludeFilter);
        } catch (_) {}
      }

      final proxyGroups = rawConfig['proxy-groups'] as List;

      final Set<String> protectedNames = {
        'DIRECT',
        'REJECT',
        'REJECT-DROP',
        'COMPATIBLE',
        'PASS',
      };
      for (final g in proxyGroups) {
        if (g is Map && g['name'] is String) {
          protectedNames.add(g['name'] as String);
        }
      }

      for (final group in proxyGroups) {
        if (group is! Map) continue;

        if (filterRegex != null && group['use'] != null) {
          final existing = group['exclude-filter'];
          if (existing is String && existing.isNotEmpty) {
            group['exclude-filter'] = '$existing|$nodeExcludeFilter';
          } else {
            group['exclude-filter'] = nodeExcludeFilter;
          }
        }

        if (filterRegex != null && group['proxies'] is List) {
          final proxiesList = group['proxies'] as List;
          final filtered = proxiesList.where((item) {
            if (item is! String || protectedNames.contains(item)) return true;
            return !filterRegex!.hasMatch(item);
          }).toList();

          if (filtered.isEmpty &&
              (group['use'] == null ||
                  (group['use'] is List && group['use'].isEmpty))) {
            filtered.add('DIRECT');
          }
          group['proxies'] = filtered;
        }

        if (healthCheckTimeout != 5000) {
          group['timeout'] ??= healthCheckTimeout;
        }
      }

      if (filterRegex != null && rawConfig['proxy-providers'] is Map) {
        final proxyProviders = rawConfig['proxy-providers'] as Map;
        for (final provider in proxyProviders.values) {
          if (provider is! Map) continue;
          final existing = provider['exclude-filter'];
          if (existing is String && existing.isNotEmpty) {
            provider['exclude-filter'] = '$existing|$nodeExcludeFilter';
          } else {
            provider['exclude-filter'] = nodeExcludeFilter;
          }
        }
      }
    }

    if (rawConfig['proxy-groups'] is List) {
      final proxyGroups = rawConfig['proxy-groups'] as List;
      for (final group in proxyGroups) {
        if (group is! Map) continue;
        final tolerance = group['tolerance'];
        if (tolerance != null) {
          if (tolerance is double) {
            group['tolerance'] = tolerance.toInt();
          } else if (tolerance is String) {
            group['tolerance'] = int.tryParse(tolerance) ?? tolerance;
          }
        }
      }
    }

    var rules = [];
    if (rawConfig['rules'] != null) {
      rules = rawConfig['rules'];
      rawConfig.remove('rules');
    } else if (rawConfig['rule'] != null) {
      rules = rawConfig['rule'];
      rawConfig.remove('rule');
    }

    final scriptActive =
        config.scriptProps.currentScript != null &&
        targetProfile.useScriptOverride;

    final overrideData = targetProfile.overrideData;
    if (overrideData.enable && !scriptActive) {
      if (overrideData.rule.type == OverrideRuleType.override) {
        rules = overrideData.runningRule;
      } else {
        rules = [...overrideData.runningRule, ...rules];
      }
    }

    // item 6 (Bettbox 1.19.3) — loopback protection. A packet inside the tunnel
    // aimed at one of our own listener ports would be routed back into the proxy
    // itself: no useful work, and a plausible way to spin. Reject it outright.
    if (config.vpnProps.loopbackProtection) {
      rules = [
        ...buildLoopbackRules(patchConfig, isAndroid: system.isAndroid),
        ...rules,
      ];
    }

    if (config.vpnProps.disableQuic) {
      // Resolve "follow system" / unset before the language check.
      final isRussian =
          (utils.getLocaleForString(config.appSetting.locale) ??
                      utils.getSystemLocale())
                  .languageCode ==
              'ru';
      final quicRules = config.vpnProps.excludeChina && !isRussian
          ? [
              'AND,((NETWORK,UDP),(DST-PORT,443),(NOT,((OR,((GEOSITE,geolocation-cn),(GEOIP,CN,no-resolve)))))),REJECT',
            ]
          : ['AND,((NETWORK,UDP),(DST-PORT,443)),REJECT'];
      rules = [...quicRules, ...rules];
    }

    if (rawConfig['proxy-groups'] == null && originalProxyGroups != null) {
      rawConfig['proxy-groups'] = originalProxyGroups;
    }

    final globalClientFingerprint = rawConfig['global-client-fingerprint'];
    if (rawConfig['proxies'] is List) {
      final proxiesList = rawConfig['proxies'] as List;
      for (final proxy in proxiesList) {
        if (proxy is! Map) continue;

        final type = proxy['type']?.toString().toLowerCase();
        final isTls = proxy['tls'] == true;

        bool supportClientFingerprint = false;
        if (type == 'trojan' || type == 'anytls') {
          supportClientFingerprint = true;
        } else if ((type == 'vmess' || type == 'vless') && isTls) {
          supportClientFingerprint = true;
        }

        if (supportClientFingerprint) {
          if (globalClientFingerprint != null &&
              proxy['client-fingerprint'] == null) {
            proxy['client-fingerprint'] = globalClientFingerprint;
          }
        }

        final realityOpts = proxy['reality-opts'];
        if (realityOpts is Map) {
          final shortId = realityOpts['short-id'];
          if (shortId is int) {
            realityOpts['short-id'] = shortId.toString();
          }
        }
      }
    }

    if (targetProfile.groupSwitches.isNotEmpty &&
        !scriptActive &&
        rawConfig['proxy-groups'] is List) {
      final disabledGroups = targetProfile.groupSwitches.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toSet();
      if (disabledGroups.isNotEmpty) {
        final proxyGroups = rawConfig['proxy-groups'] as List;
        proxyGroups.removeWhere((g) {
          if (g is Map && g['name'] is String) {
            return disabledGroups.contains(g['name']);
          }
          return false;
        });
        for (int i = 0; i < rules.length; i++) {
          if (rules[i] is String) {
            final parsed = ParsedRule.parseString(rules[i] as String);
            if (parsed.ruleTarget != null &&
                disabledGroups.contains(parsed.ruleTarget)) {
              rules[i] = parsed.copyWith(ruleTarget: 'PASS').value;
            }
          }
        }
      }
    }

    rawConfig.remove('rule');
    rawConfig['rules'] = rules;

    // 多订阅聚合：先注入 provider，后面的链路/组生成才能看到聚合节点。
    final aggregateProxies =
        await _injectAggregateProviders(rawConfig, targetProfile.id);

    // Apply chain proxy configuration if enabled (including WebRTC leak prevention rules)
    chainProxyManager.applyToClashConfig(
      rawConfig,
      extraProxyConfigs: aggregateProxies,
    );

    // Apply Cloudflare WARP on Proxy configuration if enabled (including Google anti-redirect & AI unlock rules)
    warpManager.applyToClashConfig(rawConfig);

    // Apply profile pre-proxy and landing-proxy chain configuration if enabled (v2rayN-style chaining)
    profileChainManager.applyToClashConfig(rawConfig, targetProfile.id);

    return rawConfig;
  }

  /// 把其它勾选了「参与聚合」的订阅注入成 `proxy-providers`。
  ///
  /// 用 `type: file` 指向订阅已经下载好的本地缓存，而不是 `type: http` 重新
  /// 拉一遍：内核本来就要读这个文件，网络和解析都是白付的。
  ///
  /// 重名交给内核的 `override.additional-prefix`，我们不自己改名——那等于把
  /// 内核已经做好的事再做一遍，还得先算出全集冲突。
  Future<Map<String, Map<String, dynamic>>> _injectAggregateProviders(
    Map<String, dynamic> rawConfig,
    String currentProfileId,
  ) async {
    final others = config.profiles
        .where((p) => p.id != currentProfileId && p.joinAggregate)
        .toList();
    if (others.isEmpty) return const {};

    final providers = <String, dynamic>{};
    // 供链路挑选跳板用：provider 节点不在 rawConfig['proxies'] 里，但用户能
    // 在代理页看到它们。直接读订阅文件构造，而不是问内核要 —— 内核要下一次
    // 重启才会加载刚写进去的 provider。
    final providerProxies = <String, Map<String, dynamic>>{};
    final providerNames = <String>[];
    for (final profile in others) {
      final path = await appPath.getProfilePath(profile.id);
      if (!await File(path).exists()) {
        // 还没下载过就跳过：注入一个指向空文件的 provider 会让内核直接报错。
        commonPrint.log('aggregate: skip ${profile.id}, no cached config');
        continue;
      }
      final alias = profile.aggregateAlias.isNotEmpty
          ? profile.aggregateAlias
          : (profile.label ?? profile.id);
      final key = 'agg_${profile.id}';
      providers[key] = {
        'type': 'file',
        'path': path,
        'override': {'additional-prefix': '[$alias] '},
        'health-check': {
          'enable': true,
          'url': 'https://www.gstatic.com/generate_204',
          'interval': 300,
          'lazy': true,
        },
        if ((profile.ageSecretKey ?? '').isNotEmpty)
          'age-secret-key': profile.ageSecretKey,
      };
      providerNames.add(key);

      try {
        final nodeConfig = await getProfileConfig(profile.id);
        final nodes = nodeConfig['proxies'];
        if (nodes is List) {
          for (final node in nodes) {
            if (node is! Map || node['name'] == null) continue;
            // 前缀必须和 override.additional-prefix 完全一致，否则选中的名字
            // 在运行时对不上内核里的节点。
            final prefixed = '[$alias] ${node['name']}';
            providerProxies[prefixed] = Map<String, dynamic>.from(node);
          }
        }
      } catch (e) {
        commonPrint.log('aggregate: read nodes of ${profile.id} failed: $e');
      }
    }
    if (providers.isEmpty) return const {};

    final existingProviders = rawConfig['proxy-providers'];
    rawConfig['proxy-providers'] = <String, dynamic>{
      if (existingProviders is Map)
        ...Map<String, dynamic>.from(existingProviders),
      ...providers,
    };

    final groups = rawConfig['proxy-groups'];
    if (groups is! List) return providerProxies;
    const aggregateGroup = '🌐 聚合节点';
    const aggregateAutoGroup = '♻️ 聚合自动选择';
    groups.add(<String, dynamic>{
      'name': aggregateGroup,
      'type': 'select',
      'use': providerNames,
    });
    groups.add(<String, dynamic>{
      'name': aggregateAutoGroup,
      'type': 'url-test',
      'url': 'https://www.gstatic.com/generate_204',
      'interval': 300,
      'use': providerNames,
    });

    // 挂进主选择组，否则用户得先去代理页手动找这个组。
    // 约定第一个 select 组就是主选择组。
    for (final group in groups) {
      if (group is! Map) continue;
      if (group['type'] != 'select') continue;
      if (group['name'] == aggregateGroup) continue;
      final proxies = group['proxies'];
      if (proxies is! List) continue;
      if (!proxies.contains(aggregateGroup)) {
        proxies.insert(0, aggregateGroup);
      }
      break;
    }
    return providerProxies;
  }

  /// 供原生卡片读取：内核地址 + 密钥。
  Future<void> _persistCoreEndpoint(String? endpoint, String? secret) async {
    try {
      final prefs = await Preferences().sharedPreferencesCompleter.future;
      if (endpoint != null && endpoint.isNotEmpty) {
        await prefs?.setString('core_endpoint', endpoint);
      }
      await prefs?.setString('core_secret', secret ?? '');
      // 卡片默认停在用户当前用的分组上，而不是每次都从第一个组开始。
      final group = config.currentProfile?.currentGroupName;
      if (group != null && group.isNotEmpty) {
        await prefs?.setString('core_group', group);
      }
      // 卡片测速要用和 App 相同的目标地址，否则同一节点两边数字对不上。
      final testUrl = config.appSetting.testUrl;
      if (testUrl.isNotEmpty) {
        await prefs?.setString('core_test_url', testUrl);
      }
    } catch (e) {
      commonPrint.log('persist core endpoint failed: $e');
    }
  }

  Future<Map<String, dynamic>> getProfileConfig(String profileId) async {
    final profile = config.profiles.getProfile(profileId);
    final ageSecretKey = profile?.ageSecretKey;
    final configMap = await switch (clashLibHandler != null) {
      true => clashLibHandler!.getConfig(profileId, ageSecretKey: ageSecretKey),
      false => clashCore.getConfig(profileId, ageSecretKey: ageSecretKey),
    };
    configMap['rules'] = configMap['rule'];
    configMap.remove('rule');
    // 本地覆盖在离开这个函数之前叠加：`patchRawConfig` 直接消费它的结果，
    // 所以内核、链路生成、详情面板看到的是同一份「用户改过」的配置。
    await NodeOverrideStore.instance.ensureLoaded();
    NodeOverrideStore.instance.apply(profileId, configMap);
    return configMap;
  }

  Future<Map<String, dynamic>> handleEvaluate(
    Map<String, dynamic> config, {
    Profile? profile,
  }) async {
    return _scriptEvaluateLock.synchronized(() async {
      final currentScript = globalState.config.scriptProps.currentScript;
      if (currentScript == null) return config;

      if (profile != null && !profile.useScriptOverride) return config;

      config['proxy-providers'] ??= <String, dynamic>{};

      try {
        return await JavaScriptRuntimeManager.evaluateScript(
          await currentScript.readContent(),
          config,
          customOptions: currentScript.customOptions,
        );
      } catch (e) {
        commonPrint.log('Script execution failed: $e');
        globalState.showNotifier(
          '${appLocalizations.profileParseErrorDesc}: $e',
        );
        return config;
      }
    });
  }
}

class DashboardRefreshManager {
  Timer? _timer;
  bool _isRunning = false;
  int _counter = 0;
  int _tickToken = 0;

  final tick1s = ValueNotifier<int>(0);
  final tick2s = ValueNotifier<int>(0);
  final tick5s = ValueNotifier<int>(0);

  bool get isRunning => _isRunning;

  Future<bool> _isActive() async {
    if (system.isDesktop) {
      final isPinned = globalState.config.windowProps.isPinned;
      if (isPinned) return true;
      final visible = await window?.isVisible;
      if (visible == false) {
        return false;
      }
      final minimized = await window?.isMinimized ?? false;
      if (minimized) {
        return false;
      }
      return true;
    }

    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      return false;
    }
    return true;
  }

  Future<void> _tryTick(int token) async {
    if (!await _isActive()) {
      return;
    }
    if (token != _tickToken) return;
    _counter++;
    tick1s.value++;
    if (_counter % 2 == 0) {
      tick2s.value++;
    }
    if (_counter % 5 == 0) {
      tick5s.value++;
    }
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tryTick(_tickToken);
    });
  }

  void stop() {
    if (!_isRunning) return;
    _tickToken++;
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }
}

final dashboardRefreshManager = DashboardRefreshManager();

final globalState = GlobalState();

class DetectionState {
  static DetectionState? _instance;
  bool? _preIsStart;
  int _requestId = 0;
  CancelToken? _cancelToken;
  bool _isIpMasked = false;
  IpInfo? _rawIpInfo;

  final state = ValueNotifier<NetworkDetectionState>(
    const NetworkDetectionState(
      isLoading: true,
      ipInfo: null,
      errorMessage: null,
    ),
  );

  DetectionState._internal();

  factory DetectionState() {
    _instance ??= DetectionState._internal();
    return _instance!;
  }

  bool get isIpMasked => _isIpMasked;
  IpInfo? get rawIpInfo => _rawIpInfo;

  IpInfo? _maskIpInfo(IpInfo? ipInfo) {
    if (ipInfo == null) return null;
    return _isIpMasked ? ipInfo.copyWith(ip: '*** *** *** ***') : ipInfo;
  }

  void toggleIpPrivacy() {
    _isIpMasked = !_isIpMasked;
    if (_rawIpInfo != null) {
      state.value = state.value.copyWith(ipInfo: _maskIpInfo(_rawIpInfo));
    }
  }

  void manualRefresh() {
    _rawIpInfo = null;
    _isIpMasked = false;
    state.value = state.value.copyWith(
      isLoading: true,
      ipInfo: null,
      errorMessage: null,
    );
    startCheck(immediate: true, showLoading: true);
  }

  void _onIpProgress(int requestId, IpInfo info) {
    if (requestId != _requestId) return;
    _rawIpInfo = info;
    state.value = state.value.copyWith(
      isLoading: false,
      ipInfo: _maskIpInfo(_rawIpInfo),
      errorMessage: null,
    );
  }

  Future<void> switchToDomesticIp() async {
    _rawIpInfo = null;
    _isIpMasked = false;

    _cancelPreviousRequest();
    _cancelToken = CancelToken();
    final requestId = ++_requestId;

    state.value = state.value.copyWith(
      isLoading: true,
      ipInfo: null,
      errorMessage: null,
    );

    final res = await request.checkIpDomestic(
      cancelToken: _cancelToken,
      onUpdate: (info) => _onIpProgress(requestId, info),
    );

    if (requestId != _requestId) return;

    _handleResponse(res);
  }

  void startCheck({
    bool immediate = false,
    bool showLoading = false,
    bool clearPrevious = false,
  }) {
    final appState = globalState.appState;
    if (!appState.isInit) return;

    if (clearPrevious) {
      _rawIpInfo = null;
      _cancelPreviousRequest();
      state.value = state.value.copyWith(
        isLoading: true,
        ipInfo: null,
        errorMessage: null,
      );
    } else if (showLoading || state.value.ipInfo == null) {
      state.value = state.value.copyWith(
        isLoading: true,
        errorMessage: null,
      );
    }

    final delay = immediate
        ? Duration.zero
        : const Duration(milliseconds: 1000);

    debouncer.call(
      FunctionTag.checkIp,
      () => _checkIp(showLoading: showLoading || clearPrevious),
      duration: delay,
    );
  }

  void tryStartCheck() {
    if (!state.value.isLoading &&
        state.value.ipInfo == null &&
        (_preIsStart == null || state.value.errorMessage != null)) {
      startCheck();
    }
  }

  void _cancelPreviousRequest() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  void _handleResponse(Result<IpInfo?> res) {
    if (res.isError) {
      if (res.message == 'cancelled') {
        state.value = state.value.copyWith(
          isLoading: false,
          errorMessage: null,
        );
        return;
      }
      _rawIpInfo = null;
      state.value = state.value.copyWith(
        isLoading: false,
        ipInfo: null,
        errorMessage: appLocalizations.tryManualRefresh,
      );
      return;
    }

    if (res.data != null) {
      _rawIpInfo ??= res.data;
    }
    state.value = state.value.copyWith(
      isLoading: false,
      ipInfo: _maskIpInfo(_rawIpInfo),
      errorMessage: _rawIpInfo != null
          ? null
          : (state.value.ipInfo == null
              ? appLocalizations.tryManualRefresh
              : null),
    );
  }

  Future<void> _checkIp({bool showLoading = false}) async {
    final appState = globalState.appState;

    if (!appState.isInit) return;

    final isStart = appState.runTime != null;

    final isStateChanged = _preIsStart != isStart;
    _preIsStart = isStart;

    if (!isStart &&
        _rawIpInfo != null &&
        !state.value.isLoading &&
        !isStateChanged) {
      return;
    }

    _cancelPreviousRequest();
    _cancelToken = CancelToken();
    final requestId = ++_requestId;

    final shouldShowLoading =
        showLoading || state.value.ipInfo == null || isStateChanged;
    if (shouldShowLoading) {
      _rawIpInfo = null;
      state.value = state.value.copyWith(
        isLoading: true,
        errorMessage: null,
        ipInfo: isStateChanged ? null : state.value.ipInfo,
      );
    }

    final timeout = const Duration(seconds: 12);

    final res = isStart
        ? await request.checkIp(
            cancelToken: _cancelToken,
            timeout: timeout,
            onUpdate: (info) => _onIpProgress(requestId, info),
          )
        : await request.checkIpDomestic(
            cancelToken: _cancelToken,
            timeout: timeout,
            onUpdate: (info) => _onIpProgress(requestId, info),
          );

    if (requestId != _requestId) return;

    if (isStart && (res.isError || res.data == null)) {
      _handleResponse(res);

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (state.value.ipInfo == null &&
            !state.value.isLoading &&
            globalState.appState.runTime != null) {
          startCheck(immediate: true);
        }
      });
    } else {
      _handleResponse(res);
    }
  }
}

final detectionState = DetectionState();

class MediaUnlockStateNotifier {
  static MediaUnlockStateNotifier? _instance;
  final _checker = MediaUnlockChecker();
  int _requestId = 0;
  Timer? _nodeChangeTimer;
  static const _nodeChangeDelay = Duration(milliseconds: 800);

  final state = ValueNotifier<MediaUnlockState>(
    const MediaUnlockState(),
  );

  MediaUnlockStateNotifier._internal();

  factory MediaUnlockStateNotifier() {
    _instance ??= MediaUnlockStateNotifier._internal();
    return _instance!;
  }

  List<MediaPlatform> get pinnedPlatforms {
    final pinned = globalState.config.appSetting.pinnedMediaPlatforms;
    return (pinned.isNotEmpty ? pinned : defaultPinnedMediaPlatforms)
        .take(4)
        .toList();
  }

  void checkSingle(MediaPlatform platform) async {
    if (state.value.testingPlatforms.contains(platform)) return;
    final requestId = _requestId;
    final currentTesting =
        Set<MediaPlatform>.from(state.value.testingPlatforms)..add(platform);
    state.value = state.value.copyWith(testingPlatforms: currentTesting);

    try {
      final res = await _checker.checkPlatform(platform).timeout(
        const Duration(seconds: 8),
        onTimeout: () => MediaUnlockResult(
          platform: platform,
          status: MediaUnlockStatus.failed,
        ),
      );
      if (requestId != _requestId) return;
      final finalMap =
          Map<MediaPlatform, MediaUnlockResult>.from(state.value.results);
      finalMap[platform] = res;
      final nextTesting =
          Set<MediaPlatform>.from(state.value.testingPlatforms)..remove(platform);
      state.value = state.value.copyWith(
        results: finalMap,
        testingPlatforms: nextTesting,
        lastChecked: DateTime.now(),
      );
    } catch (_) {
      if (requestId != _requestId) return;
      final finalMap =
          Map<MediaPlatform, MediaUnlockResult>.from(state.value.results);
      finalMap.putIfAbsent(
        platform,
        () => MediaUnlockResult(
          platform: platform,
          status: MediaUnlockStatus.failed,
        ),
      );
      final nextTesting =
          Set<MediaPlatform>.from(state.value.testingPlatforms)..remove(platform);
      state.value = state.value.copyWith(
        results: finalMap,
        testingPlatforms: nextTesting,
        lastChecked: DateTime.now(),
      );
    }
  }

  void checkPlatforms(
    List<MediaPlatform> platforms, {
    bool force = false,
    bool isFullCheck = false,
  }) async {
    final isRunning = globalState.appState.runTime != null;
    if (!isRunning && !force) return;

    final targetPlatforms = platforms
        .where((p) => !state.value.testingPlatforms.contains(p))
        .toList();
    if (targetPlatforms.isEmpty) return;

    final requestId = ++_requestId;
    final pendingTesting =
        Set<MediaPlatform>.from(state.value.testingPlatforms)
          ..addAll(targetPlatforms);

    state.value = state.value.copyWith(
      isLoading: isFullCheck ? true : state.value.isLoading,
      testingPlatforms: pendingTesting,
    );

    Timer? throttleTimer;
    final bufferResults = <MediaPlatform, MediaUnlockResult>{};

    void flushUpdates() {
      throttleTimer?.cancel();
      throttleTimer = null;
      if (requestId != _requestId || bufferResults.isEmpty) return;
      final updates = Map<MediaPlatform, MediaUnlockResult>.from(bufferResults);
      bufferResults.clear();
      final nextResults =
          Map<MediaPlatform, MediaUnlockResult>.from(state.value.results)
            ..addAll(updates);
      final nextTesting =
          Set<MediaPlatform>.from(state.value.testingPlatforms)
            ..removeAll(updates.keys);
      state.value = state.value.copyWith(
        results: nextResults,
        testingPlatforms: nextTesting,
      );
    }

    try {
      final results = await _checker.checkAll(
        platforms: targetPlatforms,
        onProgress: (res) {
          if (requestId != _requestId) return;
          bufferResults[res.platform] = res;
          throttleTimer ??= Timer(
            const Duration(milliseconds: 100),
            flushUpdates,
          );
        },
      ).timeout(
        Duration(seconds: (targetPlatforms.length / 8).ceil() * 8 + 5),
        onTimeout: () {
          _checker.cancel();
          final timeoutMap = <MediaPlatform, MediaUnlockResult>{};
          for (final p in targetPlatforms) {
            timeoutMap[p] = bufferResults[p] ??
                state.value.results[p] ??
                MediaUnlockResult(
                  platform: p,
                  status: MediaUnlockStatus.failed,
                );
          }
          return timeoutMap;
        },
      );
      if (requestId != _requestId) return;
      flushUpdates();
      final nextResults =
          Map<MediaPlatform, MediaUnlockResult>.from(state.value.results)
            ..addAll(results);
      final nextTesting =
          Set<MediaPlatform>.from(state.value.testingPlatforms)
            ..removeAll(targetPlatforms);
      state.value = state.value.copyWith(
        isLoading: isFullCheck ? false : state.value.isLoading,
        results: nextResults,
        testingPlatforms: nextTesting,
        lastChecked: DateTime.now(),
      );
    } catch (_) {
      throttleTimer?.cancel();
      if (requestId != _requestId) return;
      flushUpdates();
      final fallbackResults =
          Map<MediaPlatform, MediaUnlockResult>.from(state.value.results);
      for (final p in targetPlatforms) {
        fallbackResults.putIfAbsent(
          p,
          () => MediaUnlockResult(
            platform: p,
            status: MediaUnlockStatus.failed,
          ),
        );
      }
      final nextTesting =
          Set<MediaPlatform>.from(state.value.testingPlatforms)
            ..removeAll(targetPlatforms);
      state.value = state.value.copyWith(
        isLoading: isFullCheck ? false : state.value.isLoading,
        results: fallbackResults,
        testingPlatforms: nextTesting,
        lastChecked: DateTime.now(),
      );
    }
  }

  void checkPinned({bool force = false, List<MediaPlatform>? platforms}) {
    checkPlatforms(platforms ?? pinnedPlatforms, force: force);
  }

  void checkAll({
    bool force = false,
    List<MediaPlatform>? platforms,
  }) {
    final targets = platforms ?? MediaPlatform.values;
    final isFull = targets.length >= MediaPlatform.values.length;
    checkPlatforms(targets, force: force, isFullCheck: isFull);
  }

  void startCheckOnNodeChange() {
    final isRunning = globalState.appState.runTime != null;
    if (!isRunning) return;
    if (!globalState.hasMediaUnlockWidget) return;
    if (!globalState.config.appSetting.mediaUnlockRefreshOnNodeChange) return;
    _checker.cancel();
    _nodeChangeTimer?.cancel();
    final nextResults =
        Map<MediaPlatform, MediaUnlockResult>.from(state.value.results);
    for (final p in pinnedPlatforms) {
      nextResults.remove(p);
    }
    state.value = state.value.copyWith(
      results: nextResults,
      testingPlatforms: {},
      isLoading: false,
    );
    _nodeChangeTimer = Timer(_nodeChangeDelay, () {
      checkPinned(force: true);
    });
  }

  void tryStartCheck() {
    final isRunning = globalState.appState.runTime != null;
    if (!isRunning) return;
    if (!globalState.hasMediaUnlockWidget) return;
    if (state.value.isLoading || state.value.testingPlatforms.isNotEmpty) return;
    final needsInitialCheck =
        pinnedPlatforms.any((p) => !state.value.results.containsKey(p));
    if (!needsInitialCheck) return;
    checkPinned();
  }
}

final mediaUnlockState = MediaUnlockStateNotifier();


/// item 6 (Bettbox 1.19.3) — the rules that make up loopback protection.
///
/// A packet inside the tunnel aimed at one of our own listener ports would be
/// routed back into the proxy itself: no useful work, and a plausible way to
/// spin. Both address families are covered because a v6 misroute loops just as
/// well as a v4 one.
///
/// The Android extra blocks the DoT port against TEST-NET-2, which is where the
/// platform's private-DNS probe lands.
///
/// Pure and top-level so the rule text can be asserted directly — the call site
/// sits in the middle of a large async config patch and is not reachable from a
/// unit test.
List<String> buildLoopbackRules(
  ClashConfig patchConfig, {
  required bool isAndroid,
}) {
  final listenPorts = patchConfig.listenPorts;
  return [
    if (listenPorts.isNotEmpty) ...[
      'AND,((DST-PORT,$listenPorts),(IP-CIDR,127.0.0.0/8,no-resolve)),REJECT',
      'AND,((DST-PORT,$listenPorts),(IP-CIDR6,::1/128,no-resolve)),REJECT',
    ],
    if (isAndroid)
      'AND,((DST-PORT,853),(IP-CIDR,198.51.100.0/30,no-resolve)),REJECT',
  ];
}
