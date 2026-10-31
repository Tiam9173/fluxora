import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/pages/home.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';

/// The mobile dock's bottom reserve, now driven by the measured height.
///
/// `getFloatingBottomBarReserveHeight` used to return a fixed 84 px — an estimate
/// of the `GNav` dock that Phase 02.2 replaced. The Aurora dock measures 77 px at
/// 1.0× and 92 px at 2.0×, so the constant over-reserved at normal text and
/// **under-reserved by 8 px** at 2.0×. The shell now publishes its measurement
/// through `FloatingDockMetrics`, and the helper prefers it while keeping 84 as
/// a floor.
///
/// These tests cover both layers: the helper's arithmetic (no dock mounted) and
/// the real shell, where the measurement only lands after the first frame.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  // ── Layer 1: the helper, with no dock mounted ─────────────────────────────

  /// Reads the helper under a synthetic `MediaQuery`, optionally inside a
  /// `FloatingDockMetrics` subtree.
  Future<double> reserveWith(
    WidgetTester tester, {
    double viewBottom = 0,
    double keyboardBottom = 0,
    double dockHeight = 0,
  }) async {
    var value = 0.0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: viewBottom),
            viewInsets: EdgeInsets.only(bottom: keyboardBottom),
          ),
          child: Builder(
            builder: (ctx) {
              final reader = Builder(
                builder: (inner) {
                  value = getFloatingBottomBarReserveHeight(inner);
                  return const SizedBox.shrink();
                },
              );
              return dockHeight > 0
                  ? FloatingDockMetrics(height: dockHeight, child: reader)
                  : reader;
            },
          ),
        ),
      ),
    );
    return value;
  }

  group('helper — measured height wins, 84 is a floor', () {
    testWidgets('no dock mounted falls back to 84', (tester) async {
      expect(await reserveWith(tester), 84.0);
    });

    testWidgets('the fallback still adds the system inset', (tester) async {
      // 48 px gesture bar: the dock would grow by 36 px over its 12 px minimum.
      expect(await reserveWith(tester, viewBottom: 48), 120.0);
    });

    testWidgets('a dock taller than the floor is used as-is', (tester) async {
      // 2.0× text: the dock measures 92, the constant was 8 px short.
      expect(await reserveWith(tester, dockHeight: 92), 92.0);
    });

    testWidgets('a dock shorter than the floor does not shrink the reserve', (
      tester,
    ) async {
      // 1.0× text: the dock is 77. Keeping the floor means nothing moves for
      // existing layouts.
      expect(await reserveWith(tester, dockHeight: 77), 84.0);
    });

    testWidgets('the measured height already contains the safe area', (
      tester,
    ) async {
      // Adding the inset on top of a measured dock would double-count it.
      expect(
        await reserveWith(tester, dockHeight: 92, viewBottom: 48),
        92.0,
      );
    });

    testWidgets('the keyboard inset is not part of the reserve', (
      tester,
    ) async {
      // `viewInsets` (keyboard) is not the dock; only `viewPadding` feeds the
      // fallback.
      expect(await reserveWith(tester, keyboardBottom: 320), 84.0);
    });
  });

  // ── Layer 2: the real shell ───────────────────────────────────────────────

  setUp(() {
    globalState.appState = AppState(
      viewSize: const Size(390, 844),
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

  /// What the page saw on its last build.
  late BuildContext? pageContext;
  double reserveSeen = 0;
  double metricSeen = 0;

  Widget seedGlobals(Widget child) {
    return Builder(
      builder: (ctx) {
        globalState.theme = CommonTheme.of(ctx, 1.0);
        globalState.measure = Measure.of(ctx, 1.0);
        return child;
      },
    );
  }

  /// Pumps the real mobile shell and reports what the page saw.
  Future<({double reserve, double paddingBottom, double dockHeight})>
  pumpShell(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    globalState.appState = AppState(
      viewSize: size,
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.dashboard,
    );

    var reserve = 0.0;
    var paddingBottom = 0.0;

    final items = [
      NavigationItem(
        icon: const Icon(Icons.dashboard),
        label: PageLabel.dashboard,
        builder: (_) => Builder(
          builder: (ctx) {
            pageContext = ctx;
            reserve = getFloatingBottomBarReserveHeight(ctx);
            metricSeen = FloatingDockMetrics.maybeHeightOf(ctx);
            paddingBottom = MediaQuery.of(ctx).padding.bottom;
            return page;
          },
        ),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationStateProvider.overrideWith(
            (ref) => NavigationState(
              pageLabel: PageLabel.dashboard,
              navigationItems: items,
              viewMode: ViewMode.mobile,
              locale: 'zh_CN',
              currentIndex: 0,
            ),
          ),
          currentNavigationItemsStateProvider.overrideWith(
            (ref) => NavigationItemsState(value: items),
          ),
          isMobileViewProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => MediaQuery(
              data: MediaQuery.of(
                ctx,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: seedGlobals(const HomePage()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final dock = tester.getRect(find.byType(AuroraBottomNavBar));
    return (
      reserve: reserve,
      paddingBottom: paddingBottom,
      dockHeight: dock.height,
    );
  }

  /// A page that reserves the dock the way the six call sites do.
  Widget reservePage() => Builder(
    builder: (ctx) => CommonScaffold(
      title: 'reserve',
      body: ListView(
        padding: EdgeInsets.only(
          bottom: 16 + getFloatingBottomBarReserveHeight(ctx),
        ),
        children: [
          for (var i = 0; i < 40; i++)
            ListTile(dense: true, title: Text('row-$i')),
        ],
      ),
    ),
  );

  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -8000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final (label, size, scale) in [
    ('390 @1.0x', const Size(390, 844), 1.0),
    ('390 @1.4x', const Size(390, 844), 1.4),
    ('390 @2.0x', const Size(390, 844), 2.0),
    ('390 @3.0x', const Size(390, 844), 3.0),
    ('320 @2.0x', const Size(320, 640), 2.0),
  ]) {
    testWidgets('the reserve never falls below the dock ($label)', (
      tester,
    ) async {
      final result = await pumpShell(
        tester,
        reservePage(),
        size: size,
        textScale: scale,
      );

      expect(
        result.reserve,
        greaterThanOrEqualTo(result.dockHeight),
        reason:
            'reserve ${result.reserve} vs dock ${result.dockHeight} — a fixed '
            'constant could not promise this at large text',
      );

      await scrollToEnd(tester);
      final dock = tester.getRect(find.byType(AuroraBottomNavBar));
      final last = tester.getRect(find.text('row-39'));
      expect(
        last.bottom,
        lessThanOrEqualTo(dock.top),
        reason: 'the last row must scroll clear of the dock ($label)',
      );
    });
  }

  testWidgets('generateListView keeps its own injection, no double reserve', (
    tester,
  ) async {
    await pumpShell(
      tester,
      CommonScaffold(
        title: 'list',
        body: generateListView([
          for (var i = 0; i < 40; i++)
            ListTile(dense: true, title: Text('row-$i')),
        ]),
      ),
    );

    final dock = tester.getRect(find.byType(AuroraBottomNavBar));
    final list = tester.widget<ListView>(find.byType(ListView));
    final bottom = (list.padding! as EdgeInsets).bottom;

    expect(
      bottom,
      24 + dock.height,
      reason:
          'the list reserves the injected dock height once — adding the helper '
          'on top would double it',
    );
  });

  // ── The metric's lifetime ────────────────────────────────────────────────
  //
  // `_dockHeight` lives in the shell's State, so "it was measured once" is not
  // the same as "it is still current". These tests drive the ways the dock can
  // change size after the first frame and read the helper from inside the page.

  /// The real shell, without a pinned text scale, so the engine value is what
  /// the dock sees.
  Widget engineShell(Widget page) {
    final items = [
      NavigationItem(
        icon: const Icon(Icons.dashboard),
        label: PageLabel.dashboard,
        builder: (_) => Builder(
          builder: (ctx) {
            pageContext = ctx;
            reserveSeen = getFloatingBottomBarReserveHeight(ctx);
            metricSeen = FloatingDockMetrics.maybeHeightOf(ctx);
            return page;
          },
        ),
      ),
    ];
    return ProviderScope(
      overrides: [
        navigationStateProvider.overrideWith(
          (ref) => NavigationState(
            pageLabel: PageLabel.dashboard,
            navigationItems: items,
            viewMode: ViewMode.mobile,
            locale: 'zh_CN',
            currentIndex: 0,
          ),
        ),
        currentNavigationItemsStateProvider.overrideWith(
          (ref) => NavigationItemsState(value: items),
        ),
        isMobileViewProvider.overrideWith((ref) => true),
      ],
      child: MaterialApp(home: seedGlobals(const HomePage())),
    );
  }

  testWidgets('a text-scale change re-measures and republishes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    globalState.appState = AppState(
      viewSize: const Size(390, 844),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.dashboard,
    );

    await tester.pumpWidget(
      engineShell(
        Builder(
          builder: (ctx) => CommonScaffold(
            title: 'r',
            body: ListView(
              padding: EdgeInsets.only(
                bottom: 16 + getFloatingBottomBarReserveHeight(ctx),
              ),
              children: [
                for (var i = 0; i < 40; i++)
                  ListTile(dense: true, title: Text('row-$i')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final before = tester.getRect(find.byType(AuroraBottomNavBar)).height;
    expect(reserveSeen, greaterThanOrEqualTo(before));

    // Engine-level change: `MediaQuery.fromView` rebuilds, the dock grows, and
    // the shell has to notice — a cached `_dockHeight` would not.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    final after = tester.getRect(find.byType(AuroraBottomNavBar)).height;
    expect(
      after,
      greaterThan(before),
      reason: 'the dock really grew at 2.0x — otherwise this proves nothing',
    );
    expect(
      reserveSeen,
      greaterThanOrEqualTo(after),
      reason:
          'reserve $reserveSeen vs dock $after: a stale _dockHeight would leave '
          'the last row under the dock',
    );
    expect(metricSeen, greaterThanOrEqualTo(after));
  });

  testWidgets('the page reads the same height the dock renders', (
    tester,
  ) async {
    // Direct evidence that the metric reaches the reserve pages instead of them
    // silently falling back to the floor.
    await pumpShell(
      tester,
      CommonScaffold(title: 'plain', body: const SizedBox.expand()),
      textScale: 2.0,
    );

    final dock = tester.getRect(find.byType(AuroraBottomNavBar)).height;
    expect(
      metricSeen,
      dock,
      reason: 'the published metric must equal the painted dock height',
    );
  });

  testWidgets('a dialog above the shell does not inherit the dock height', (
    tester,
  ) async {
    // Dialogs go through the root navigator, which sits above the shell's
    // `FloatingDockMetrics`. They must fall back to the floor rather than
    // reserve a dock they are not under.
    await pumpShell(
      tester,
      CommonScaffold(title: 'plain', body: const SizedBox.expand()),
      textScale: 2.0,
    );

    var dialogReserve = -1.0;
    showDialog<void>(
      context: pageContext!,
      builder: (ctx) {
        dialogReserve = getFloatingBottomBarReserveHeight(ctx);
        return const SizedBox.shrink();
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(dialogReserve, 84.0);
  });

  testWidgets('a safe-area change re-measures and republishes', (
    tester,
  ) async {
    // Same mechanism as the text-scale case, different trigger: the dock's own
    // `SafeArea` grows with the gesture bar, so the measurement has to follow.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);

    globalState.appState = AppState(
      viewSize: const Size(390, 844),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.dashboard,
    );

    await tester.pumpWidget(
      engineShell(CommonScaffold(title: 'r', body: const SizedBox.expand())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final before = tester.getRect(find.byType(AuroraBottomNavBar)).height;

    // A 48 px gesture bar: the dock grows by 36 px over its 12 px minimum.
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    tester.view.padding = const FakeViewPadding(bottom: 48);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    final after = tester.getRect(find.byType(AuroraBottomNavBar)).height;
    expect(
      after,
      greaterThan(before),
      reason: 'the dock grew with the safe area — otherwise this proves nothing',
    );
    expect(
      reserveSeen,
      greaterThanOrEqualTo(after),
      reason: 'reserve $reserveSeen vs dock $after after the inset appeared',
    );
  });

  testWidgets('switching pages keeps the same measured height', (
    tester,
  ) async {
    // Both pages live inside the same `_HomePageView`, i.e. the same metrics
    // subtree, so neither can pick up a stale value from the other.
    final seen = <PageLabel, double>{};
    final items = [
      for (final label in [PageLabel.dashboard, PageLabel.profiles])
        NavigationItem(
          icon: const Icon(Icons.dashboard),
          label: label,
          builder: (_) => Builder(
            builder: (ctx) {
              seen[label] = FloatingDockMetrics.maybeHeightOf(ctx);
              return CommonScaffold(
                title: label.name,
                body: const SizedBox.expand(),
              );
            },
          ),
        ),
    ];

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationStateProvider.overrideWith(
            (ref) => NavigationState(
              pageLabel: PageLabel.dashboard,
              navigationItems: items,
              viewMode: ViewMode.mobile,
              locale: 'zh_CN',
              currentIndex: 0,
            ),
          ),
          currentNavigationItemsStateProvider.overrideWith(
            (ref) => NavigationItemsState(value: items),
          ),
          isMobileViewProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(home: seedGlobals(const HomePage())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final dock = tester.getRect(find.byType(AuroraBottomNavBar)).height;
    expect(seen[PageLabel.dashboard], dock);
    // The second page may not have been built yet (lazy), but when it is, it
    // must report the same height — never 0 or another host's value.
    for (final value in seen.values) {
      expect(value, dock);
    }
  });

  testWidgets('the first frame falls back to the floor, then settles', (
    tester,
  ) async {
    // The measurement is post-frame, so the very first build cannot know the
    // dock height. It must reserve the floor (never 0), then converge — this is
    // the one visible transition the design accepts, and only at large text.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    globalState.appState = AppState(
      viewSize: const Size(390, 844),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.dashboard,
    );

    await tester.pumpWidget(
      engineShell(CommonScaffold(title: 'r', body: const SizedBox.expand())),
    );
    expect(
      reserveSeen,
      84.0,
      reason: 'frame one has no measurement yet — it must not reserve 0',
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final dock = tester.getRect(find.byType(AuroraBottomNavBar)).height;
    expect(dock, greaterThan(84), reason: '2.0x really is taller than the floor');
    expect(reserveSeen, dock);
  });

  testWidgets('the FAB keeps its clearance at 2.0x', (tester) async {
    await pumpShell(
      tester,
      Builder(
        builder: (ctx) => CommonScaffold(
          title: 'fab',
          body: const SizedBox.expand(),
          floatingActionButton: Padding(
            padding: EdgeInsets.only(
              bottom: getFloatingBottomBarFABReserveHeight(ctx),
            ),
            child: FloatingActionButton(
              heroTag: null,
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
      textScale: 2.0,
    );

    final dock = tester.getRect(find.byType(AuroraBottomNavBar));
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(
      dock.top - fab.bottom,
      greaterThanOrEqualTo(16),
      reason: 'the FAB reserve must not be eaten by a taller dock',
    );
  });
}
