import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/manager/app_manager.dart';
import 'package:fluxora/views/theme.dart';
import 'package:fluxora/views/about.dart';
import 'package:fluxora/views/application_setting.dart';
import 'package:fluxora/views/config/config.dart';
import 'package:fluxora/views/dashboard/widgets/network_detection.dart';
import 'package:fluxora/views/dashboard/widgets/start_button.dart';
import 'package:fluxora/views/logs.dart';
import 'package:fluxora/views/connection/requests.dart';
import 'package:fluxora/views/proxies/notification_switch_card.dart';
import 'package:fluxora/widgets/widgets.dart';

import '../support/recording_app_controller.dart';
import '../theme/hybrid_glass_test.dart' show glassTestTheme;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await preferences.sharedPreferencesCompleter.future;
    await AppLocalizations.load(const Locale('zh', 'CN'));
    globalState.packageInfo = PackageInfo(
      appName: 'Fluxora',
      packageName: 'io.fluxora.app',
      version: '0.0.0-test',
      buildNumber: '0',
    );
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget page, {
    Brightness brightness = Brightness.dark,
    FluxoraSurfaceStyle style = FluxoraSurfaceStyle.hybrid,
    Size size = const Size(1200, 800),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    globalState.config = Config(themeProps: ThemeProps(surfaceStyle: style));
    globalState.appState = AppState(
      viewSize: size,
      brightness: brightness,
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
          (ref) =>
              const StartButtonSelectorState(isInit: true, hasProfile: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: glassTestTheme(brightness, style),
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
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Consumer(
                builder: (context, ref, _) {
                  globalState.theme = CommonTheme.of(context, 1);
                  globalState.measure = Measure.of(context, 1);
                  globalState.appController = RecordingAppController(
                    context,
                    ref,
                  );
                  return RepaintBoundary(
                    key: const ValueKey('glass-capture'),
                    child: page,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  final pages = <String, Widget Function()>{
    'theme': () => const CommonScaffold(title: '主题', body: ThemeView()),
    'about': () => const CommonScaffold(title: '关于', body: AboutView()),
    'settings': () =>
        const CommonScaffold(title: '应用设置', body: ApplicationSettingView()),
    'config': () => const CommonScaffold(title: '覆写配置', body: ConfigView()),
    'logs': () => LogsView(historyLoader: () async => []),
    'requests': () => const RequestsView(),
    'node-picker': () =>
        const Scaffold(body: SwitchCard(onSelect: _ignoreSelect)),
    'connection': () => CommonScaffold(
      title: '总览',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const StartButton(),
            const SizedBox(height: 16),
            const NetworkDetection(),
          ],
        ),
      ),
    ),
  };

  for (final entry in pages.entries) {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(1200, 800), const Size(360, 780)]) {
        testWidgets('${entry.key} $brightness at $size', (tester) async {
          await pump(tester, entry.value(), brightness: brightness, size: size);
          expect(tester.takeException(), isNull);
          expect(
            find.byType(BackdropFilter),
            findsNothing,
            reason: 'Content pages must never blur each card or row',
          );
          if (const bool.fromEnvironment('GLASS_CAPTURE') &&
              size.width == 1200) {
            await _capture(tester, '${entry.key}-${brightness.name}');
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        });
      }
    }
  }

  testWidgets(
    'theme material selection uses existing config persistence model',
    (tester) async {
      final container = await pump(tester, pages['theme']!());
      final classic = find.byKey(const ValueKey('surface-style-classic'));
      await tester.ensureVisible(classic);
      await tester.tap(classic);
      await tester.pump();
      expect(
        container.read(themeSettingProvider).surfaceStyle,
        FluxoraSurfaceStyle.classic,
      );
      final restored = ThemeProps.fromJson(
        jsonDecode(jsonEncode(container.read(themeSettingProvider))),
      );
      expect(restored.surfaceStyle, FluxoraSurfaceStyle.classic);
      final reduced = find.byKey(const ValueKey('surface-style-reduced'));
      await tester.tap(reduced);
      await tester.pump();
      expect(
        container.read(themeSettingProvider).surfaceStyle,
        FluxoraSurfaceStyle.reduced,
      );
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );

  for (final style in [
    FluxoraSurfaceStyle.classic,
    FluxoraSurfaceStyle.reduced,
  ]) {
    testWidgets('$style theme page at 320px and 2x text', (tester) async {
      await pump(
        tester,
        pages['theme']!(),
        style: style,
        size: const Size(320, 800),
        scale: 2,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('surface-style-reduced')),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('glass desktop navigation collapses and resizes: $brightness', (
      tester,
    ) async {
      await pump(
        tester,
        AppSidebarContainer(child: pages['theme']!()),
        brightness: brightness,
      );
      final rail = find.byKey(const ValueKey('desktop-sidebar'));
      expect(tester.getSize(rail).width, 208);
      await tester.tap(find.byKey(const ValueKey('toggle-desktop-sidebar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getSize(rail).width, 68);
      tester.view.physicalSize = const Size(640, 700);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
      if (const bool.fromEnvironment('GLASS_CAPTURE')) {
        tester.view.physicalSize = const Size(1200, 800);
        await tester.pump(const Duration(milliseconds: 250));
        await tester.tap(find.byKey(const ValueKey('toggle-desktop-sidebar')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await _capture(tester, 'sidebar-${brightness.name}');
      }
    });

    for (final style in [
      FluxoraSurfaceStyle.hybrid,
      FluxoraSurfaceStyle.reduced,
    ]) {
      testWidgets(
        'mobile dock $style $brightness has bounded filter and activation',
        (tester) async {
          var selected = -1;
          final items = navigation
              .getItems(hasProxies: true)
              .where(
                (item) =>
                    item.modes.isEmpty ||
                    item.modes.contains(NavigationItemMode.mobile),
              )
              .toList();
          await pump(
            tester,
            Scaffold(
              body: pages['connection']!(),
              bottomNavigationBar: AuroraBottomNavBar(
                navigationItems: items,
                selectedIndex: 0,
                onTabChange: (value) => selected = value,
              ),
            ),
            brightness: brightness,
            style: style,
            size: const Size(390, 844),
          );
          expect(
            find.byType(BackdropFilter),
            style == FluxoraSurfaceStyle.hybrid ? findsOneWidget : findsNothing,
          );
          if (style == FluxoraSurfaceStyle.hybrid) {
            final filterSize = tester.getSize(find.byType(BackdropFilter));
            expect(filterSize.height, lessThan(120));
            if (const bool.fromEnvironment('GLASS_CAPTURE')) {
              await _capture(tester, 'mobile-${brightness.name}');
            }
          }
          final dock = find.byType(AuroraBottomNavBar);
          final icon = find.descendant(
            of: dock,
            matching: find.byIcon(Icons.hub_outlined),
          );
          await tester.tap(icon);
          expect(selected, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

void _ignoreSelect(String name, String group) {}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('glass-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/hybrid_glass/captures/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
