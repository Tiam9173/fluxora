import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/manager/app_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/aurora_navigation_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/recording_app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecordingAppController controller;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await preferences.sharedPreferencesCompleter.future;
    await AppLocalizations.load(const Locale('zh', 'CN'));
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  setUp(() {
    globalState.accentColor = FluxoraColors.fluxCyan;
    globalState.config = const Config(themeProps: ThemeProps());
    globalState.appState = AppState(
      viewSize: const Size(1200, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.dashboard,
    );
  });

  Future<ProviderContainer> pumpSidebar(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    bool reduce = false,
    double scale = 1,
    double width = 1200,
    double height = 800,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        navigationStateProvider.overrideWith((ref) {
          final page = ref.watch(currentPageLabelProvider);
          final items = navigation
              .getItems(hasProxies: true)
              .where(
                (e) =>
                    e.modes.isEmpty ||
                    e.modes.contains(NavigationItemMode.desktop),
              )
              .toList();
          return NavigationState(
            pageLabel: page,
            navigationItems: items,
            viewMode: ViewMode.desktop,
            locale: 'zh_CN',
            currentIndex: items.indexWhere((e) => e.label == page),
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    var bound = false;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: ThemeData(
            fontFamily: 'HarmonyOS_Sans',
            colorScheme: container.read(genColorSchemeProvider(brightness)),
          ),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduce,
                textScaler: TextScaler.linear(scale),
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  globalState.theme = CommonTheme.of(context, 1);
                  globalState.measure = Measure.of(context, 1);
                  if (!bound) {
                    bound = true;
                    controller = RecordingAppController(context, ref);
                    globalState.appController = controller;
                  }
                  return RepaintBoundary(
                    key: const ValueKey('sidebar-capture'),
                    child: const Scaffold(
                      body: AppSidebarContainer(child: _PageCounter()),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder getSidebar() => find.byKey(const ValueKey('desktop-sidebar'));
  Finder getToggle() => find.byKey(const ValueKey('toggle-desktop-sidebar'));

  test(
    'default is expanded and explicit legacy preferences survive serialization',
    () {
      expect(const AppSettingProps().showLabel, isTrue);
      expect(AppSettingProps.fromJson({}).showLabel, isTrue);
      expect(AppSettingProps.fromJson({'showLabel': false}).showLabel, isFalse);
    },
  );

  testWidgets(
    'toggle changes width in one frame and retains selection and page state',
    (tester) async {
      final container = await pumpSidebar(tester);
      container.read(currentPageLabelProvider.notifier).value =
          PageLabel.profiles;
      await tester.tap(find.text('count: 0'));
      await tester.pumpAndSettle();
      expect(tester.getSize(getSidebar()).width, 208);
      final page = find.byType(_PageCounter);
      expect(tester.getSize(page).width, 992);
      await tester.tap(getToggle());
      await tester.pump();
      expect(tester.getSize(getSidebar()).width, 68);
      expect(tester.getSize(page).width, 1132);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.getSize(getSidebar()).width, 68);
      expect(find.text('count: 1'), findsOneWidget);
      expect(
        tester
            .widget<AuroraNavigationRail>(find.byType(AuroraNavigationRail))
            .selectedIndex,
        2,
      );
      final restored = Config.fromJson(
        jsonDecode(jsonEncode(globalState.config)),
      );
      expect(restored.appSetting.showLabel, isFalse);
      expect(container.read(currentPageLabelProvider), PageLabel.profiles);
      await tester.tap(getToggle());
      await tester.pump();
      expect(tester.getSize(getSidebar()).width, 208);
      expect(tester.getSize(page).width, 992);
      expect(find.text('count: 1'), findsOneWidget);
    },
  );

  testWidgets(
    'collapsed destinations have tooltips, accessible names and real routes',
    (tester) async {
      final container = await pumpSidebar(tester);
      await tester.tap(getToggle());
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();
      try {
        final items = container.read(navigationStateProvider).navigationItems;
        for (var i = 0; i < items.length; i++) {
          final label = items[i].label.localizedName;
          expect(find.text(label), findsNothing);
          expect(find.byTooltip(label), findsOneWidget);
          final entry = find.byKey(ValueKey('aurora-rail-destination-$i'));
          final semantics = tester.getSemantics(entry).getSemanticsData();
          expect(semantics.label, label);
          expect(semantics.flagsCollection.isButton, isTrue);
          await tester.tap(entry);
          await tester.pump();
          expect(controller.pages.last, items[i].label);
        }
        await tester.longPress(find.byIcon(Icons.folder_open_outlined));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text(PageLabel.profiles.localizedName), findsOneWidget);
        await tester.pumpAndSettle();
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'narrow window temporarily folds without changing saved preference',
    (tester) async {
      final container = await pumpSidebar(tester);
      for (final width in [841.0, 840.0, 601.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 400);
        await tester.pumpAndSettle();
        expect(tester.getSize(getSidebar()).width, width > 840 ? 208 : 68);
        expect(container.read(appSettingProvider).showLabel, isTrue);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('reduced motion changes width immediately', (tester) async {
    await pumpSidebar(tester, reduce: true);
    await tester.tap(getToggle());
    await tester.pump();
    expect(tester.getSize(getSidebar()).width, 68);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('both widths fit short windows and 200% text in $brightness', (
      tester,
    ) async {
      await pumpSidebar(tester, brightness: brightness, scale: 2, height: 320);
      expect(tester.takeException(), isNull);
      await tester.tap(getToggle());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.tune_rounded).hitTestable(), findsOneWidget);
    });
  }

  testWidgets('capture the real sidebar in both themes and both widths', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(const SizedBox());
      globalState.config = globalState.config.copyWith(
        appSetting: globalState.config.appSetting.copyWith(showLabel: true),
      );
      await pumpSidebar(tester, brightness: brightness);
      for (final collapsed in [false, true]) {
        if (collapsed) {
          await tester.tap(getToggle());
          await tester.pumpAndSettle();
        }
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('sidebar-capture')),
        );
        await tester.runAsync(() async {
          final screenshot = await boundary.toImage();
          final bytes = await screenshot.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final file = File(
            'build/sidebar_navigation/${brightness.name}_${collapsed ? 'collapsed' : 'expanded'}.png',
          );
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(bytes!.buffer.asUint8List());
          screenshot.dispose();
        });
      }
    }
  }, skip: !const bool.fromEnvironment('SIDEBAR_CAPTURE'));
}

class _PageCounter extends StatefulWidget {
  const _PageCounter();
  @override
  State<_PageCounter> createState() => _PageCounterState();
}

class _PageCounterState extends State<_PageCounter> {
  var count = 0;
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => count++),
      child: Text('count: $count'),
    ),
  );
}
