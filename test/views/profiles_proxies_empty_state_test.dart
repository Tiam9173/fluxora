import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Test-only: `path_provider` is a transitive dependency. Faking the platform
// instance is the only way to make `appPath` resolvable in a VM test — same
// pattern as `mobile_narrow_layout_test.dart`.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/clash/core.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/profiles/add_profile.dart';
import 'package:fluxora/views/profiles/profiles.dart';
import 'package:fluxora/views/proxies/proxies.dart';
import 'package:fluxora/views/proxies/tab.dart';
import 'package:fluxora/widgets/widgets.dart';

import '../support/render_capture.dart';

/// Phase 1C-2 B4 — pins the migrated empty state of the profiles / proxies
/// pages.
///
/// Before B4 all three pages rendered `NullStatus`; they now render
/// `FluxoraEmptyState`. None of the three had any test coverage of its empty
/// branch, so this file is the first contract check: with no data the new
/// component must be present, the old one must be gone, and nothing may
/// overflow — including at 280 dp with a 1.4x text scale.
///
/// The empty branches are reachable through the default provider state:
/// `profilesProvider` seeds from `globalState.config.profiles` (empty by
/// default), `groupsProvider` seeds from `globalState.appState.groups`
/// (`@Default([])`), and `proxiesTabStateProvider` derives from the groups.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory appPathSandbox;

  setUpAll(() async {
    appPathSandbox = Directory.systemTemp.createTempSync('fluxora_empty_b4_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(appPathSandbox);
    await AppLocalizations.load(const Locale('zh', 'CN'));
    if (const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
      await (FontLoader('HarmonyOS_Sans')..addFont(
            rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  tearDownAll(() async {
    try {
      await appPathSandbox.delete(recursive: true);
    } catch (_) {
      // Best effort: the OS may still hold a handle on the temp dir.
    }
  });

  setUp(() {
    globalState.appState = AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.dark,
      requests: FixedList(0),
      version: 1,
      logs: FixedList(0),
      traffics: FixedList(0),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
  });

  /// `globalState.theme` / `globalState.measure` are `late` globals that
  /// production fills in `ThemeManager`; seeded from a `Builder` inside the
  /// live tree, same as `mobile_narrow_layout_test.dart`.
  Widget seedGlobals(Widget child) {
    return Builder(
      builder: (ctx) {
        globalState.theme = CommonTheme.of(ctx, 1.0);
        globalState.measure = Measure.of(ctx, 1.0);
        return child;
      },
    );
  }

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    double textScale,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: ThemeData(
              brightness: brightness,
              fontFamily: const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')
                  ? 'HarmonyOS_Sans'
                  : null,
            ),
            home: Builder(
              builder: (ctx) => MediaQuery(
                data: MediaQuery.of(
                  ctx,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: RepaintBoundary(
                  key: const ValueKey('page-capture'),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
  }

  for (final (name, page) in const [
    ('profiles', ProfilesView()),
    ('proxies', ProxiesView()),
  ]) {
    for (final (size, scale, brightness) in const [
      (Size(1280, 760), 1.0, Brightness.light),
      (Size(280, 560), 1.4, Brightness.dark),
    ]) {
      testWidgets('$name first import opens the shared sheet at $size', (
        tester,
      ) async {
        await pumpAt(
          tester,
          size,
          scale,
          seedGlobals(page),
          brightness: brightness,
        );
        final importButton = find.byKey(const ValueKey('import-first-profile'));
        expect(importButton, findsOneWidget);
        expect(tester.getCenter(importButton).dx, closeTo(size.width / 2, 1));
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
          await captureFlutterFrame(
            tester,
            find.byKey(const ValueKey('page-capture')),
            'build/ui_refinement/captures/first-import-$name-${brightness.name}.png',
          );
        }
        await tester.tap(importButton);
        await tester.pumpAndSettle();
        expect(find.byType(AddProfileView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a long subscription name keeps its full tooltip', (
    tester,
  ) async {
    const name = '海外专线 · 企业版 · 美国西部移动优化订阅完整名称';
    final original = globalState.config;
    addTearDown(() => globalState.config = original);
    globalState.config = original.copyWith(
      profiles: [
        Profile(
          id: 'long-subscription-name',
          label: name,
          url: 'https://fixture.test/profile',
          autoUpdateDuration: const Duration(days: 1),
          subscriptionInfo: const SubscriptionInfo(
            total: 1 << 30,
            download: 1 << 27,
            expire: 1800000000,
          ),
        ),
      ],
      currentProfileId: 'long-subscription-name',
    );
    await pumpAt(
      tester,
      const Size(280, 560),
      1.4,
      seedGlobals(
        Consumer(
          builder: (context, ref, _) {
            globalState.appController = _ProviderController(context, ref);
            return const ProfilesView();
          },
        ),
      ),
    );
    expect(find.byTooltip(name), findsOneWidget);
    expect(find.byKey(const ValueKey('import-first-profile')), findsNothing);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
      await captureFlutterFrame(
        tester,
        find.byKey(const ValueKey('page-capture')),
        'build/ui_refinement/captures/subscription-long-name.png',
      );
    }
  });

  testWidgets('empty HTTP node source can be updated from the proxy page', (
    tester,
  ) async {
    final provider = ExternalProvider(
      name: 'Fixture',
      vehicleType: 'HTTP',
      type: 'Proxy',
      count: 0,
      updateAt: DateTime(2026),
    );
    globalState.appState = globalState.appState.copyWith(providers: [provider]);
    final original = clashCore.clashInterface;
    final core = _ProviderCore(provider);
    clashCore.clashInterface = core;
    addTearDown(() => clashCore.clashInterface = original);

    await pumpAt(
      tester,
      const Size(280, 560),
      1.4,
      seedGlobals(
        Consumer(
          builder: (context, ref, _) {
            globalState.appController = _ProviderController(context, ref);
            return const ProxiesView();
          },
        ),
      ),
    );
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
      await captureFlutterFrame(
        tester,
        find.byKey(const ValueKey('page-capture')),
        'build/ui_refinement/captures/subscription-provider-empty.png',
      );
    }

    await tester.tap(find.widgetWithText(TextButton, appLocalizations.update));
    await tester.pumpAndSettle();
    expect(core.updates, ['Fixture']);
    expect(find.byType(MaterialBanner), findsNothing);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
      await captureFlutterFrame(
        tester,
        find.byKey(const ValueKey('page-capture')),
        'build/ui_refinement/captures/subscription-provider-loaded.png',
      );
    }
  });

  for (final entry in const <String, Widget>{
    'ProfilesView': ProfilesView(),
    'ProxiesTabView': ProxiesTabView(),
    'ProxiesView': ProxiesView(),
  }.entries) {
    for (final size in const [Size(360, 640), Size(280, 560)]) {
      for (final textScale in const [1.0, 1.4]) {
        testWidgets('${entry.key} 空态渲染 FluxoraEmptyState 且不溢出 @ '
            '${size.width}x${size.height} + ${textScale}x', (tester) async {
          await pumpAt(tester, size, textScale, seedGlobals(entry.value));

          expect(find.byType(FluxoraEmptyState), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

class _ProviderCore extends Fake implements ClashHandlerInterface {
  final ExternalProvider provider;
  final updates = <String>[];

  _ProviderCore(this.provider);

  @override
  Future<String> updateExternalProvider(String providerName) async {
    updates.add(providerName);
    return '';
  }

  @override
  Future<String> getExternalProvider(String externalProviderName) async =>
      jsonEncode(provider.copyWith(count: 1).toJson());
}

class _ProviderController extends AppController {
  _ProviderController(super.context, super.ref);

  @override
  void updateGroupsDebounce() {}
}

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform(this.dir);

  final Directory dir;

  @override
  Future<String?> getTemporaryPath() async => dir.path;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;

  @override
  Future<String?> getLibraryPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getExternalStoragePath() async => dir.path;

  @override
  Future<List<String>?> getExternalCachePaths() async => [dir.path];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [dir.path];

  @override
  Future<String?> getDownloadsPath() async => dir.path;
}
