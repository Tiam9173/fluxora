import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
// Test-only platform fakes, matching the existing AppPath isolation tests.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:fluxora/views/views.dart'
    show RequestsConnectionsView, LogsView, ResourcesView, ScriptsView;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/manager/app_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/pages/home.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/plugins/vpn.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/services/system_proxy_readback.dart';
import 'package:fluxora/views/theme.dart';
import 'package:fluxora/views/app_icons.dart';
import 'package:fluxora/views/about.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fluxora/views/config/config.dart';
import 'package:fluxora/views/dashboard/widgets/memory_info.dart';
import 'package:fluxora/views/dashboard/widgets/network_speed.dart';
import 'package:fluxora/views/dashboard/widgets/traffic_usage.dart';
import 'package:fluxora/views/dashboard/widgets/start_button.dart';
import 'package:fluxora/views/tools.dart';
import 'package:fluxora/views/profiles/profiles.dart';
import 'package:fluxora/views/proxies/proxies.dart';
import 'package:fluxora/views/proxies/list.dart';
import 'package:fluxora/views/proxies/notification_switch_card.dart';
import 'package:fluxora/widgets/widgets.dart';

import '../support/recording_app_controller.dart';
import '../support/render_capture.dart';

// Screenshot scenes need the same soft elevation shadows as the application.
class _VisualBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _VisualPaths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
  @override
  Future<String?> getDownloadsPath() async => Directory.systemTemp.path;
}

class _VisualController extends RecordingAppController {
  _VisualController(BuildContext context, this.bindingRef)
    : super(context, bindingRef);
  final WidgetRef bindingRef;
  Completer<void>? operation;
  Completer<void>? proxyReply;
  @override
  Future<void> changeProxy({
    required String groupName,
    required String proxyName,
  }) =>
      proxyReply?.future ??
      super.changeProxy(groupName: groupName, proxyName: proxyName);
  @override
  Future<void> updateStatus(bool isStart) {
    operation = Completer<void>();
    return operation!.future;
  }

  @override
  void toPage(PageLabel pageLabel) {
    super.toPage(pageLabel);
    bindingRef.read(currentPageLabelProvider.notifier).value = pageLabel;
  }
}

class _VisualCore implements ClashHandlerInterface {
  Completer<Result>? configRead;
  @override
  Future<Result> getConfig(String path, {String? ageSecretKey}) {
    return configRead?.future ??
        Future.value(Result.success(<String, dynamic>{}));
  }

  @override
  Future<String> getMemory() async => '0';
  @override
  bool get hasLiveProcess => false;
  @override
  Future<String> getConnections() async => '{"connections":[]}';
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected core call in UI test: ${invocation.memberName}',
  );
}

void main() {
  _VisualBinding();
  late ClashHandlerInterface originalCore;
  late PathProviderPlatform originalPaths;
  late String? originalReadbackPlatform;
  setUpAll(() async {
    originalReadbackPlatform = SystemProxyReadbackService.platformOverride;
    SystemProxyReadbackService.platformOverride = 'ui-fixture';
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _VisualPaths();
    originalCore = clashCore.clashInterface;
    clashCore.clashInterface = _VisualCore();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('app'), (call) async {
          if (call.method == 'getLauncherIcon') {
            return {'style': 'official', 'useDarkIcon': false};
          }
          return true;
        });
    globalState.packageInfo = PackageInfo(
      appName: 'Fluxora',
      packageName: 'io.fluxora.app',
      version: '1.1.2-rc.2',
      buildNumber: '2026110701',
    );
    SharedPreferences.setMockInitialValues({});
    await preferences.sharedPreferencesCompleter.future;
    await AppLocalizations.load(const Locale('zh', 'CN'));
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  tearDownAll(() {
    clashCore.clashInterface = originalCore;
    PathProviderPlatform.instance = originalPaths;
    SystemProxyReadbackService.platformOverride = originalReadbackPlatform;
  });
  tearDown(() => System.platformOverride = null);

  Future<ProviderContainer> show(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    Size size = const Size(390, 844),
    bool empty = false,
    bool reduce = false,
    double textScale = 1,
    PageLabel page = PageLabel.dashboard,
    List<DashboardWidget>? dashboardWidgets,
    List<Group> groups = const [],
  }) async {
    final morePage = [
      PageLabel.connections,
      PageLabel.logs,
      PageLabel.resources,
      PageLabel.script,
    ].contains(page);
    System.platformOverride = size.width < 1000 ? 'android' : 'windows';
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    globalState.config = Config(
      appSetting: AppSettingProps(
        locale: 'zh_CN',
        mobileDashboardWidgets:
            dashboardWidgets ?? defaultAndroidDashboardWidgets,
        desktopDashboardWidgets: dashboardWidgets ?? defaultDashboardWidgets,
      ),
      themeProps: const ThemeProps(useHarmonyFont: true),
      profiles: empty
          ? []
          : const [
              Profile(
                id: 'visual-fixture',
                label: '日常网络',
                currentGroupName: '节点选择',
                autoUpdateDuration: Duration(days: 1),
                selectedMap: {'节点选择': '东京 · 高速线路 01'},
              ),
            ],
      currentProfileId: empty ? null : 'visual-fixture',
    );
    globalState.appState = AppState(
      viewSize: size,
      brightness: brightness,
      pageLabel: morePage ? PageLabel.tools : page,
      groups: groups,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    final container = ProviderContainer(
      overrides: [
        startButtonSelectorStateProvider.overrideWith(
          (ref) => StartButtonSelectorState(isInit: true, hasProfile: !empty),
        ),
      ],
    );
    addTearDown(container.dispose);
    var bound = false;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final appearance = ref.watch(themeSettingProvider);
            return MaterialApp(
              navigatorKey: globalState.navigatorKey,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: reduce,
                  textScaler: TextScaler.linear(textScale),
                  padding: const EdgeInsets.only(bottom: 24),
                ),
                child: RepaintBoundary(
                  key: const ValueKey('refinement-capture'),
                  child: child!,
                ),
              ),
              theme: fluxoraMaterialTheme(
                ThemeData(
                  fontFamily: 'HarmonyOS_Sans',
                  colorScheme: ref.watch(genColorSchemeProvider(brightness)),
                ),
                appearance.surfaceStyle,
                motionStyle: appearance.motionStyle,
                glassIntensity: appearance.glassIntensity,
              ),
              locale: const Locale('zh', 'CN'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: reduce,
                    textScaler: TextScaler.linear(textScale),
                    padding: const EdgeInsets.only(bottom: 24),
                  ),
                  child: Consumer(
                    builder: (context, ref, _) {
                      globalState.theme = CommonTheme.of(context, textScale);
                      globalState.measure = Measure.of(context, textScale);
                      if (!bound) {
                        bound = true;
                        globalState.appController = _VisualController(
                          context,
                          ref,
                        );
                      }
                      return const RepaintBoundary(
                        key: ValueKey('refinement-home'),
                        child: Material(
                          child: AppSidebarContainer(child: HomePage()),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    if (morePage) {
      final entry = find.text(Intl.message(page.name)).last;
      await tester.scrollUntilVisible(
        entry,
        280,
        scrollable: find
            .descendant(
              of: find
                  .descendant(
                    of: find.byType(ToolsView),
                    matching: find.byType(ListView),
                  )
                  .first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      final expected = switch (page) {
        PageLabel.connections => RequestsConnectionsView,
        PageLabel.logs => LogsView,
        PageLabel.resources => ResourcesView,
        PageLabel.script => ScriptsView,
        _ => throw StateError('Not a secondary page'),
      };
      expect(find.byType(expected), findsOneWidget);
    }
    return container;
  }

  for (final expanded in [false, true]) {
    testWidgets(
      'many strategy groups remain reachable above the dock expanded=$expanded',
      (tester) async {
        final groups = [
          for (var i = 0; i < 24; i++)
            Group(
              type: i.isEven ? GroupType.URLTest : GroupType.Selector,
              name: '策略组 $i',
              now: '节点 $i',
              all: [Proxy(name: '节点 $i', type: 'VLESS')],
            ),
        ];
        final container = await show(
          tester,
          size: const Size(320, 740),
          textScale: 2,
          page: PageLabel.proxies,
          reduce: true,
          groups: groups,
        );
        container
            .read(proxiesStyleSettingProvider.notifier)
            .updateState((s) => s.copyWith(type: ProxiesType.list));
        final profile = container.read(currentProfileProvider)!;
        container
            .read(profilesProvider.notifier)
            .setProfile(
              profile.copyWith(
                unfoldSet: expanded ? groups.map((g) => g.name).toSet() : {},
              ),
            );
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(
              of: find.byType(ProxiesListView),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        final last = find.byKey(const ValueKey('header_策略组 23'));
        expect(last, findsOneWidget);
        final dockTop = tester.getTopLeft(find.byType(AuroraBottomNavBar)).dy;
        expect(tester.getBottomRight(last).dy, lessThanOrEqualTo(dockTop));
        if (expanded) {
          final node = find.byKey(const ValueKey('策略组 23.节点 23'));
          expect(tester.getBottomRight(node).dy, lessThanOrEqualTo(dockTop));
        }
        expect(tester.takeException(), isNull);
        await capture(tester, 'groups-last-expanded-$expanded');
        await tester.tap(find.byKey(const ValueKey('toggle-group-策略组 23')));
        await tester.pumpAndSettle();
        expect(container.read(unfoldSetProvider).contains('策略组 23'), !expanded);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'connection node opens the shared picker and subscriptions without toggling VPN',
    (tester) async {
      final container = await show(
        tester,
        reduce: true,
        groups: [
          Group(
            type: GroupType.Selector,
            name: '节点选择',
            all: const [Proxy(name: '东京 · 高速线路 01', type: 'VLESS')],
          ),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('connection-node-picker')));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchCard), findsOneWidget);
      expect(
        (globalState.appController as _VisualController).operation,
        isNull,
      );
      await capture(tester, 'home-node-picker');
      await tester.tap(find.byKey(const ValueKey('switch-card-profiles')));
      await tester.pumpAndSettle();
      expect(container.read(currentPageLabelProvider), PageLabel.profiles);
      expect(find.byType(SwitchCard), findsNothing);
      expect(
        (globalState.appController as _VisualController).operation,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'custom options opens immediately with retryable failure and no global loading strip',
    (tester) async {
      final core = clashCore.clashInterface as _VisualCore;
      core.configRead = Completer<Result>();
      addTearDown(() => core.configRead = null);
      final container = await show(tester, page: PageLabel.proxies);
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip(appLocalizations.custom));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await capture(tester, 'custom-options-before-load');
      expect(
        find.text('正在读取配置选项'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      expect(container.read(loadingProvider), isFalse);
      await capture(tester, 'custom-options-loading');
      core.configRead!.complete(Result.error('离线测试：读取失败'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('options-retry')), findsOneWidget);
      await capture(tester, 'custom-options-error');
      core.configRead = Completer<Result>()
        ..complete(
          Result.success(<String, dynamic>{
            'proxy-groups': [
              {'name': '测试分组'},
            ],
            'rule': [],
          }),
        );
      await tester.tap(find.byKey(const ValueKey('options-retry')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      expect(find.text('测试分组'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a rejected picker selection stays open and preserves the previous node',
    (tester) async {
      final container = await show(
        tester,
        reduce: true,
        dashboardWidgets: [DashboardWidget.startButton],
        groups: [
          Group(
            type: GroupType.URLTest,
            name: '节点选择',
            now: '东京 · 高速线路 01',
            all: const [
              Proxy(name: '东京 · 高速线路 01', type: 'VLESS'),
              Proxy(name: '新加坡线路', type: 'Trojan'),
            ],
          ),
        ],
      );
      final controller = globalState.appController as _VisualController;
      controller.proxyReply = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('connection-node-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新加坡线路'));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('switch-card-profiles')),
            )
            .onPressed,
        isNull,
      );
      controller.proxyReply!.completeError(StateError('离线测试：内核拒绝选择'));
      await tester.pumpAndSettle();
      expect(find.textContaining('内核拒绝选择'), findsOneWidget);
      expect(container.read(selectedMapProvider)['节点选择'], '东京 · 高速线路 01');
      expect(find.byType(SwitchCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'node-picker-error');
    },
  );

  testWidgets(
    'material and motion controls stay independent and persist in the existing settings',
    (tester) async {
      final container = await show(tester, page: PageLabel.tools);
      await tester.tap(find.text(appLocalizations.theme).first);
      await tester.pumpAndSettle();
      final sliderFinder = find.byKey(const ValueKey('glass-intensity'));
      await tester.ensureVisible(sliderFinder);
      final slider = tester.widget<Slider>(sliderFinder);
      slider.onChanged!(.9);
      await tester.pump();
      expect(container.read(themeSettingProvider).glassIntensity, .55);
      slider.onChangeEnd!(.9);
      await tester.pumpAndSettle();
      expect(container.read(themeSettingProvider).glassIntensity, .9);
      await tester.ensureVisible(find.byKey(const ValueKey('motion-fluid')));
      await tester.tap(find.byKey(const ValueKey('motion-fluid')));
      await tester.pumpAndSettle();
      expect(
        container.read(themeSettingProvider).motionStyle,
        FluxoraMotionStyle.fluid,
      );
      await capture(tester, 'custom-material-motion');
      await tester.tap(find.byKey(const ValueKey('motion-off')));
      await tester.pumpAndSettle();
      expect(
        FluxoraMotion.ofContext(
          tester.element(find.byType(ThemeView)),
        ).reduceMotion,
        isTrue,
      );
      expect(
        container.read(themeSettingProvider).surfaceStyle,
        FluxoraSurfaceStyle.hybrid,
      );
    },
  );

  testWidgets(
    'notification subscription action navigates without stopping the service',
    (tester) async {
      final container = await show(
        tester,
        reduce: true,
        dashboardWidgets: [DashboardWidget.startButton],
      );
      const channel = MethodChannel('vpn');
      final calls = <String>[];
      var pending = '';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return switch (call.method) {
              'isCardOnlyLaunch' => false,
              'consumePendingNotificationAction' => pending,
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final listener = Vpn();
      await tester.pump();
      pending = 'profiles';
      await listener.consumePendingNotificationAction();
      await tester.pumpAndSettle();
      expect(container.read(currentPageLabelProvider), PageLabel.profiles);
      expect(calls, isNot(contains('stop')));
      expect(calls, isNot(contains('stopVpn')));
      expect(
        (globalState.appController as _VisualController).operation,
        isNull,
      );
    },
  );

  testWidgets('Classic app bar uses the existing scrolled-under surface role', (
    tester,
  ) async {
    final container = await show(tester, page: PageLabel.tools, reduce: true);
    container
        .read(themeSettingProvider.notifier)
        .updateState(
          (s) => s.copyWith(surfaceStyle: FluxoraSurfaceStyle.classic),
        );
    await tester.pumpAndSettle();
    final bar = find
        .descendant(of: find.byType(ToolsView), matching: find.byType(AppBar))
        .first;
    Color? painted() => tester
        .widget<Material>(
          find.descendant(of: bar, matching: find.byType(Material)).first,
        )
        .color;
    final scheme = Theme.of(tester.element(bar)).colorScheme;
    expect(painted(), scheme.surface);
    await capture(tester, 'classic-toolbar-rest');
    final scroll = find
        .descendant(
          of: find.byType(ToolsView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scroll, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(painted(), scheme.surfaceContainer);
    await capture(tester, 'classic-toolbar-scrolled');
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final size in [const Size(390, 844), const Size(1280, 900)]) {
      testWidgets('actual home and settings $brightness $size', (tester) async {
        final container = await show(
          tester,
          brightness: brightness,
          size: size,
        );
        expect(tester.takeException(), isNull);
        final screen = size.width < 600 ? 'mobile' : 'desktop';
        final scheme = Theme.of(
          tester.element(find.byType(StartButton)),
        ).colorScheme;
        final backgrounds = [
          Color.alphaBlend(
            FluxoraColors.flowViolet.withValues(alpha: .22),
            scheme.surfaceContainer,
          ),
          Color.alphaBlend(
            FluxoraColors.auroraBlue.withValues(alpha: .06),
            scheme.surfaceContainer,
          ),
          scheme.surfaceContainerHigh,
        ];
        for (final foreground in [scheme.onSurface, scheme.onSurfaceVariant]) {
          for (final background in backgrounds) {
            final a = foreground.computeLuminance();
            final b = background.computeLuminance();
            expect(
              a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
        expect(
          tester
              .getSize(find.byTooltip(appLocalizations.powerSwitch))
              .shortestSide,
          greaterThanOrEqualTo(48),
        );
        if (size.width < 600) {
          expect(
            tester
                .getSize(
                  find
                      .ancestor(
                        of: find.byKey(const ValueKey('aurora-dock-selection')),
                        matching: find.byType(InkWell),
                      )
                      .first,
                )
                .shortestSide,
            greaterThanOrEqualTo(48),
          );
        }
        await capture(tester, '$screen-home-${brightness.name}');
        if (size.width < 600) {
          await tester.ensureVisible(find.byType(MemoryInfo));
          await tester.pump(const Duration(milliseconds: 500));
          final dockTop = tester.getTopLeft(find.byType(AuroraBottomNavBar)).dy;
          expect(
            tester.getBottomRight(find.byType(MemoryInfo)).dy,
            lessThanOrEqualTo(dockTop),
          );
          await capture(tester, '$screen-home-scrolled-${brightness.name}');
        }
        final navigation = size.width < 600
            ? find.byType(AuroraBottomNavBar)
            : find.byType(AuroraNavigationRail);
        await tester.tap(
          find.descendant(
            of: navigation,
            matching: find.byIcon(Icons.tune_rounded),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(ToolsView), findsOneWidget);
        expect(
          find.byKey(const ValueKey('settings-appearance')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await capture(tester, '$screen-settings-${brightness.name}');
        await tester.ensureVisible(
          find.byKey(const ValueKey('settings-resources')),
        );
        await tester.pumpAndSettle();
        await capture(tester, '$screen-settings-resources-${brightness.name}');
        final toolsScroll = find
            .descendant(
              of: find.byType(ToolsView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.drag(toolsScroll, const Offset(0, 1800));
        await tester.pumpAndSettle();

        await tester.tap(find.text(appLocalizations.theme).first);
        await tester.pumpAndSettle();
        expect(find.byType(ThemeView), findsOneWidget);
        await capture(tester, 'theme-$screen-${brightness.name}');
        final reduced = find.byKey(const ValueKey('surface-style-reduced'));
        await tester.ensureVisible(reduced);
        await tester.tap(reduced);
        await tester.pumpAndSettle();
        expect(
          container.read(themeSettingProvider).surfaceStyle,
          FluxoraSurfaceStyle.reduced,
        );
        expect(tester.takeException(), isNull);
        if (size.width < 600) {
          await tester.ensureVisible(find.byType(AppIconsItem));
          await tester.tap(find.byType(AppIconsItem));
          await tester.pumpAndSettle();
          expect(find.byType(AppIconsView), findsOneWidget);
          await capture(tester, 'app-icons-${brightness.name}');
          await tester.ensureVisible(find.byType(NotificationIconsItem));
          await tester.pumpAndSettle();
          await capture(tester, 'notification-icons-${brightness.name}');
          Navigator.of(tester.element(find.byType(AppIconsView))).pop();
          await tester.pumpAndSettle();
        }
        final back = find.byIcon(Icons.arrow_back);
        await tester.tap(
          back.evaluate().isNotEmpty
              ? back.first
              : find.byIcon(Icons.close).first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(ToolsView), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }

  for (final brightness in Brightness.values) {
    for (final size in [const Size(390, 844), const Size(1280, 900)]) {
      testWidgets('all dashboard components $brightness $size', (tester) async {
        final platform = size.width < 1000
            ? SupportPlatform.Android
            : SupportPlatform.Windows;
        final widgets = DashboardWidget.values
            .where((item) => item.platforms.contains(platform))
            .toList();
        await show(
          tester,
          brightness: brightness,
          size: size,
          dashboardWidgets: widgets,
          reduce: true,
        );
        expect(tester.takeException(), isNull);
        for (final item in widgets) {
          expect(
            find.byType(item.widget.child.runtimeType),
            findsOneWidget,
            reason: item.name,
          );
        }
        final scrollable = find
            .descendant(
              of: find.byKey(const ValueKey('refinement-home')),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        final offsets = <double>[0];
        while (offsets.last < position.maxScrollExtent) {
          offsets.add(
            (offsets.last + size.height * .65).clamp(
              0,
              position.maxScrollExtent,
            ),
          );
        }
        for (var index = 0; index < offsets.length; index++) {
          position.jumpTo(offsets[index]);
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            'components-${platform.name}-${brightness.name}-$index',
          );
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }

  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets('dashboard catalog, reorder and removal persist $size', (
      tester,
    ) async {
      final container = await show(
        tester,
        size: size,
        reduce: true,
        textScale: size.width < 1000 ? 2 : 1,
        dashboardWidgets: [
          DashboardWidget.startButton,
          DashboardWidget.networkSpeedSmall,
        ],
      );
      await tester.tap(find.byKey(const ValueKey('dashboard-edit-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-add-components')));
      await tester.pumpAndSettle();
      final catalog = find.byKey(const ValueKey('catalog-networkSpeed'));
      expect(catalog, findsOneWidget);
      // The catalog must never instantiate live controls merely to preview them.
      expect(
        find.descendant(of: catalog, matching: find.byType(FluxoraSpeedGauge)),
        findsNothing,
      );
      await capture(tester, 'catalog-${size.width.toInt()}');
      await tester.tap(catalog);
      await tester.pumpAndSettle();
      List<DashboardWidget> saved() => size.width < 1000
          ? container.read(appSettingProvider).mobileDashboardWidgets
          : container.read(appSettingProvider).desktopDashboardWidgets;
      expect(saved(), [
        DashboardWidget.startButton,
        DashboardWidget.networkSpeedSmall,
        DashboardWidget.networkSpeed,
      ]);
      await tester.tapAt(Offset(size.width < 1000 ? 8 : 300, 100));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-organize')));
      await tester.pumpAndSettle();
      await capture(tester, 'organize-initial-${size.width.toInt()}');
      final protected = tester.widget<IconButton>(
        find.byKey(const ValueKey('remove-startButton')),
      );
      expect(protected.onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('move-down-startButton')));
      await tester.pumpAndSettle();
      expect(saved().first, DashboardWidget.networkSpeedSmall);
      await capture(tester, 'organize-${size.width.toInt()}');
      await tester.tap(find.byKey(const ValueKey('remove-networkSpeed')));
      await tester.pumpAndSettle();
      expect(saved(), [
        DashboardWidget.networkSpeedSmall,
        DashboardWidget.startButton,
      ]);
      await tester.tapAt(Offset(size.width < 1000 ? 8 : 300, 100));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-edit-toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(SuperGrid), findsNothing);
      expect(saved().contains(DashboardWidget.startButton), isTrue);
      expect(tester.takeException(), isNull);
      // Recreate the widget tree using the saved preference, as after reopening.
      final retained = saved();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      final reopened = await show(
        tester,
        size: size,
        reduce: true,
        dashboardWidgets: retained,
      );
      expect(
        size.width < 1000
            ? reopened.read(appSettingProvider).mobileDashboardWidgets
            : reopened.read(appSettingProvider).desktopDashboardWidgets,
        retained,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  for (final brightness in Brightness.values) {
    for (final page in [
      PageLabel.profiles,
      PageLabel.proxies,
      PageLabel.connections,
      PageLabel.logs,
      PageLabel.resources,
      PageLabel.script,
    ]) {
      testWidgets('secondary page $page $brightness', (tester) async {
        await show(
          tester,
          brightness: brightness,
          page: page,
          empty: true,
          reduce: true,
        );
        expect(tester.takeException(), isNull);
        await capture(tester, 'page-${page.name}-${brightness.name}');
        if (page == PageLabel.proxies) {
          final action = find.descendant(
            of: find.byType(FluxoraEmptyState),
            matching: find.byType(FilledButton),
          );
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(
            (globalState.appController as _VisualController).pages.last,
            PageLabel.profiles,
          );
        }
        if (page == PageLabel.profiles) {
          final action = find.descendant(
            of: find.byType(FluxoraEmptyState),
            matching: find.byType(FilledButton),
          );
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await capture(tester, 'profile-add-${brightness.name}');
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }

    testWidgets('traffic totals and detail keep sampled values $brightness', (
      tester,
    ) async {
      final container = await show(
        tester,
        brightness: brightness,
        reduce: !const bool.fromEnvironment('MOTION_CAPTURE'),
        dashboardWidgets: [DashboardWidget.trafficUsage],
      );
      container.read(totalTrafficProvider.notifier).value = Traffic(
        up: 2048,
        down: 2097152,
      );
      await tester.pumpAndSettle();
      expect(find.text('2.00 KB'), findsOneWidget);
      expect(find.text('2.00 MB'), findsOneWidget);
      await tester.tap(find.byType(TrafficUsage));
      await tester.pump();
      if (const bool.fromEnvironment('MOTION_CAPTURE')) {
        for (var i = 0; i < 7; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          await capture(
            tester,
            'motion-dialog-${brightness.name}/${i.toString().padLeft(3, '0')}',
          );
        }
      }
      await tester.pumpAndSettle();
      expect(find.byType(CommonDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'traffic-detail-${brightness.name}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('populated profiles and proxy list $brightness', (
      tester,
    ) async {
      await show(
        tester,
        brightness: brightness,
        page: PageLabel.profiles,
        reduce: true,
      );
      expect(find.text('日常网络'), findsWidgets);
      expect(tester.takeException(), isNull);
      await capture(tester, 'profiles-populated-${brightness.name}');
      await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text(appLocalizations.aggregateManage), findsOneWidget);
      await capture(tester, 'profile-actions-${brightness.name}');
      Navigator.of(
        tester.element(find.byType(PopupMenuItem<String>).first),
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-sort')));
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableProfilesSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(ReorderableProfilesSheet))).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await show(
        tester,
        brightness: brightness,
        page: PageLabel.proxies,
        reduce: true,
        groups: [
          Group(
            type: GroupType.Selector,
            name: '节点选择',
            all: const [
              Proxy(name: '东京 · 高速线路 01', type: 'VLESS'),
              Proxy(name: '新加坡 · 长名称节点用于验证窄屏显示 02', type: 'Trojan'),
              Proxy(name: '法兰克福 03', type: 'Shadowsocks'),
            ],
          ),
        ],
      );
      expect(find.text('东京 · 高速线路 01'), findsWidgets);
      expect(tester.takeException(), isNull);
      await capture(tester, 'proxies-populated-${brightness.name}');
      await tester.tap(find.byTooltip(appLocalizations.more).first);
      await tester.pumpAndSettle();
      expect(find.text('节点操作'), findsOneWidget);
      expect(find.text('路由工具'), findsOneWidget);
      await capture(tester, 'proxy-actions-${brightness.name}');
      final beforeHidden = ProviderScope.containerOf(
        tester.element(find.byType(ProxiesView)),
      ).read(proxiesStyleSettingProvider).showHiddenItems;
      await tester.tap(find.text(appLocalizations.showHiddenItems));
      await tester.pumpAndSettle();
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(ProxiesView)),
        ).read(proxiesStyleSettingProvider).showHiddenItems,
        !beforeHidden,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('connection configuration sections $brightness', (
      tester,
    ) async {
      await show(
        tester,
        brightness: brightness,
        page: PageLabel.tools,
        reduce: true,
      );
      final config = find.text(appLocalizations.basicConfig).first;
      await tester.ensureVisible(config);
      await tester.tap(config);
      await tester.pumpAndSettle();
      expect(find.byType(ConfigView), findsOneWidget);
      expect(find.text('连接基础'), findsOneWidget);
      await capture(tester, 'config-${brightness.name}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('About shows the applied artwork $brightness', (tester) async {
      final container = await show(
        tester,
        brightness: brightness,
        page: PageLabel.tools,
        reduce: true,
      );
      final scroll = find
          .descendant(
            of: find.byType(ToolsView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text(appLocalizations.about),
        350,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(appLocalizations.about));
      await tester.pumpAndSettle();
      expect(find.byType(AboutView), findsOneWidget);
      container
          .read(themeSettingProvider.notifier)
          .updateState(
            (s) => s.copyWith(
              appIconStyle: 'sunset',
              useDarkIcon: brightness == Brightness.dark,
            ),
          );
      await tester.pumpAndSettle();
      await capture(tester, 'about-${brightness.name}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('theme keeps controls reachable at 320px and double text size', (
    tester,
  ) async {
    await show(
      tester,
      size: const Size(320, 740),
      textScale: 2,
      page: PageLabel.tools,
      reduce: true,
    );
    await tester.ensureVisible(find.text(appLocalizations.theme).first);
    await tester.tap(find.text(appLocalizations.theme).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'theme-narrow-large-text');
    final dark = find.byKey(const ValueKey('theme-mode-dark'));
    await tester.ensureVisible(dark);
    await tester.tap(dark);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  for (final size in [
    const Size(375, 812),
    const Size(844, 390),
    const Size(768, 1024),
  ]) {
    testWidgets('empty dashboard, large text and reduced motion $size', (
      tester,
    ) async {
      await show(tester, size: size, empty: true, reduce: true, textScale: 2);
      expect(tester.takeException(), isNull);
      await capture(tester, 'empty-${size.width.toInt()}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
  for (final brightness in Brightness.values) {
    for (final size in [const Size(390, 844), const Size(1280, 900)]) {
      testWidgets('motion state and navigation frames $brightness $size', (
        tester,
      ) async {
        final container = await show(
          tester,
          brightness: brightness,
          size: size,
        );
        final controller = globalState.appController as _VisualController;
        final prefix = 'motion-${size.width.toInt()}-${brightness.name}';
        var frame = 0;
        Future<void> frames(int count) async {
          for (var i = 0; i < count; i++) {
            await tester.pump(const Duration(milliseconds: 40));
            await capture(
              tester,
              '$prefix/${(frame++).toString().padLeft(3, '0')}',
            );
          }
        }

        await frames(2);
        await tester.tap(find.byTooltip(appLocalizations.powerSwitch));
        await tester.pump();
        expect(find.text(appLocalizations.startVpn), findsOneWidget);
        expect(find.text(appLocalizations.coreConnected), findsNothing);
        await frames(6);
        container.read(runTimeProvider.notifier).value = 156000;
        controller.operation!.complete();
        await tester.pump();
        await frames(7);
        expect(find.text(appLocalizations.coreConnected), findsOneWidget);
        await tester.tap(find.byTooltip(appLocalizations.powerSwitch));
        await tester.pump();
        expect(find.text(appLocalizations.stopVpn), findsOneWidget);
        await frames(6);
        container.read(runTimeProvider.notifier).value = null;
        controller.operation!.complete();
        await tester.pump();
        await frames(7);
        expect(find.text(appLocalizations.serviceReady), findsOneWidget);
        await tester.tap(find.byTooltip(appLocalizations.powerSwitch));
        await tester.pump();
        controller.operation!.completeError(
          StateError('Controlled connection failure'),
        );
        await tester.pump();
        await frames(4);
        expect(
          find.textContaining('Controlled connection failure'),
          findsOneWidget,
        );
        if (size.width < 600) {
          expect(
            tester
                .getRect(find.textContaining('Controlled connection failure'))
                .bottom,
            lessThan(tester.getRect(find.byType(AuroraBottomNavBar)).top),
            reason: 'failure feedback must stay above the floating navigation',
          );
        } else {
          expect(
            tester
                .getSize(find.textContaining('Controlled connection failure'))
                .width,
            greaterThanOrEqualTo(240),
            reason: 'sidebar content must retain a readable snackbar width',
          );
        }
        final navigation = size.width < 600
            ? find.byType(AuroraBottomNavBar)
            : find.byType(AuroraNavigationRail);
        await tester.tap(
          find.descendant(
            of: navigation,
            matching: find.byIcon(Icons.tune_rounded),
          ),
        );
        await tester.pump();
        await frames(6);
        expect(find.byType(ToolsView), findsOneWidget);
        expect(container.read(currentPageLabelProvider), PageLabel.tools);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
  for (final brightness in Brightness.values) {
    testWidgets(
      'network result motion uses only supplied result states $brightness',
      (tester) async {
        final prior = detectionState.state.value;
        addTearDown(() => detectionState.state.value = prior);
        detectionState.state.value = const NetworkDetectionState(
          isLoading: true,
          ipInfo: null,
        );
        await show(
          tester,
          brightness: brightness,
          dashboardWidgets: [DashboardWidget.networkDetection],
        );
        var frame = 0;
        for (final result in [
          const NetworkDetectionState(
            isLoading: false,
            ipInfo: IpInfo(ip: '2001:db8::42', countryCode: 'JP'),
          ),
          const NetworkDetectionState(
            isLoading: false,
            ipInfo: IpInfo(ip: '192.0.2.42', countryCode: 'SG'),
          ),
          const NetworkDetectionState(
            isLoading: false,
            ipInfo: null,
            errorMessage: '检测失败',
          ),
        ]) {
          detectionState.state.value = result;
          await tester.pump();
          for (var i = 0; i < 7; i++) {
            await tester.pump(const Duration(milliseconds: 40));
            await capture(
              tester,
              'motion-network-${brightness.name}/${(frame++).toString().padLeft(3, '0')}',
            );
          }
          expect(
            find.text(result.ipInfo?.ip ?? result.errorMessage!),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'proxy selection motion follows persisted selection $brightness',
      (tester) async {
        final container = await show(
          tester,
          brightness: brightness,
          page: PageLabel.proxies,
          groups: [
            Group(
              type: GroupType.Selector,
              name: '节点选择',
              all: const [
                Proxy(name: '东京 · 高速线路 01', type: 'VLESS'),
                Proxy(name: '新加坡 02', type: 'Trojan'),
              ],
            ),
          ],
        );
        await capture(tester, 'motion-node-${brightness.name}/000');
        final profile = container.read(currentProfileProvider)!;
        container
            .read(profilesProvider.notifier)
            .setProfile(profile.copyWith(selectedMap: {'节点选择': '新加坡 02'}));
        await tester.pump();
        for (var i = 1; i <= 7; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          await capture(
            tester,
            'motion-node-${brightness.name}/${i.toString().padLeft(3, '0')}',
          );
        }
        final tiles = tester.widgetList<FluxoraProxyTile>(
          find.byType(FluxoraProxyTile),
        );
        expect(tiles.singleWhere((w) => w.name == '新加坡 02').selected, isTrue);
        expect(
          tiles.singleWhere((w) => w.name == '东京 · 高速线路 01').selected,
          isFalse,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'speed graph renders supplied samples with local motion $brightness',
      (tester) async {
        final container = await show(
          tester,
          brightness: brightness,
          dashboardWidgets: [DashboardWidget.networkSpeed],
        );
        final samples = container.read(trafficsProvider.notifier);
        samples.addTraffic(Traffic(down: 16384, up: 2048));
        samples.addTraffic(Traffic(down: 32768, up: 4096));
        dashboardRefreshManager.tick1s.value++;
        await tester.pump(const Duration(milliseconds: 400));
        await capture(tester, 'motion-chart-${brightness.name}/000');
        samples.addTraffic(Traffic(down: 65536, up: 8192));
        dashboardRefreshManager.tick1s.value++;
        await tester.pump();
        for (var i = 1; i <= 9; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          await capture(
            tester,
            'motion-chart-${brightness.name}/${i.toString().padLeft(3, '0')}',
          );
        }
        expect(find.text('64.0 KB/s'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'desktop card hover keeps layout and pointer feedback $brightness',
      (tester) async {
        await show(tester, brightness: brightness, size: const Size(1280, 900));
        final target = find.byType(NetworkSpeed);
        final before = tester.getRect(target);
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(target));
        for (var i = 0; i < 7; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          await capture(
            tester,
            'motion-hover-${brightness.name}/${i.toString().padLeft(3, '0')}',
          );
        }
        expect(tester.getRect(target), before);
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  const aurora = bool.fromEnvironment('AURORA_CAPTURE');
  const motion = bool.fromEnvironment('MOTION_CAPTURE');
  if (!motion &&
      !aurora &&
      !const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
    return;
  }
  final folder = motion
      ? 'motion_full'
      : aurora
      ? 'aurora_refresh'
      : 'ui_refinement';
  await tester.runAsync(() async {
    for (final element in tester.elementList(find.byType(Image))) {
      final image = element.widget as Image;
      if (image.image is AssetImage) await precacheImage(image.image, element);
    }
  });
  await tester.pump();
  await captureFlutterFrame(
    tester,
    find.byKey(const ValueKey('refinement-capture')),
    'build/$folder/captures/$name.png',
  );
}
