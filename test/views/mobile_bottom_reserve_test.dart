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
import 'package:fluxora/views/logs.dart';
import 'package:fluxora/widgets/widgets.dart';

/// The mobile shell reserves the floating dock through **one** helper,
/// `getFloatingBottomBarReserveHeight` (`constant.dart:63`). These tests pin that
/// helper and the page that was missing it.
///
/// Background: the shell injects the measured dock height into the page's
/// `MediaQuery.padding.bottom` (so plain `generateListView` pages reserve it).
/// The helper used to read `max(viewPadding.bottom, padding.bottom)` — which
/// meant it *also* consumed that injected value and returned
/// `84 + (82 - 12) = 154` instead of `84`. Dashboard, profiles, proxies and
/// tools then padded 70 px more than they should have.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

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

  Widget seedGlobals(Widget child) {
    return Builder(
      builder: (ctx) {
        globalState.theme = CommonTheme.of(ctx, 1.0);
        globalState.measure = Measure.of(ctx, 1.0);
        return child;
      },
    );
  }

  /// Pumps the real mobile shell around [page], reporting the helper's value and
  /// the ambient `padding.bottom` from inside the page.
  Future<({double reserve, double paddingBottom})> pumpMobilePage(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(390, 844),
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
            reserve = getFloatingBottomBarReserveHeight(ctx);
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
          filteredLogsProvider.overrideWithValue([
            for (var i = 0; i < 30; i++) Log.app('line-$i'),
          ]),
        ],
        child: MaterialApp(home: seedGlobals(const HomePage())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    return (reserve: reserve, paddingBottom: paddingBottom);
  }

  group('getFloatingBottomBarReserveHeight — single source', () {
    testWidgets('does not double-count the injected dock inset', (
      tester,
    ) async {
      final result = await pumpMobilePage(
        tester,
        CommonScaffold(title: 'plain', body: const SizedBox.expand()),
      );

      // The shell really did inject the dock height into `padding.bottom`…
      expect(
        result.paddingBottom,
        greaterThan(60),
        reason: 'the shell injects the measured dock height',
      );
      // …but the helper must ignore it and keep returning the dock reserve.
      expect(
        result.reserve,
        84.0,
        reason:
            'the helper must not fold the injected padding into its own '
            'reserve (that produced 154 and over-padded four pages by 70 px)',
      );
    });

    testWidgets('stays 84 regardless of the window height', (tester) async {
      final result = await pumpMobilePage(
        tester,
        CommonScaffold(title: 'plain', body: const SizedBox.expand()),
        size: const Size(320, 640),
      );

      expect(result.reserve, 84.0);
    });
  });

  group('LogsView — the page that had no reserve', () {
    /// The list is `reverse: true`, so index 0 (the newest line) renders at the
    /// bottom — directly under the dock. It only ever had a flat 16 px.
    Future<double> logsBottomPadding(WidgetTester tester) async {
      await pumpMobilePage(
        tester,
        LogsView(historyLoader: () async => <Log>[]),
      );

      final list = tester.widget<ListView>(find.byType(ListView).first);
      return (list.padding! as EdgeInsets).bottom;
    }

    testWidgets('reserves the dock on mobile', (tester) async {
      final bottom = await logsBottomPadding(tester);

      expect(
        bottom,
        greaterThanOrEqualTo(16 + 84),
        reason:
            'the newest log line must clear the dock, not sit behind it '
            '(measured $bottom)',
      );
    });

    testWidgets('the reserve clears the real dock height', (tester) async {
      // Cross-check against the dock's own painted height rather than the
      // constant, so a future dock resize cannot silently break this.
      final bottom = await logsBottomPadding(tester);
      final dockHeight = tester
          .getRect(find.byType(AuroraBottomNavBar))
          .height;

      expect(
        bottom,
        greaterThanOrEqualTo(16 + dockHeight),
        reason: 'dock is ${dockHeight}px tall, list bottom padding is $bottom',
      );
    });
  });
  // ── The FAB helper has the same injection trap ───────────────────────────
  //
  // `getFloatingBottomBarFABReserveHeight` pads the FAB above the dock. It used
  // `max(viewPadding, padding)` too, so the shell's injected dock height landed
  // in its `min(..., 12)` term and shrank the reserve from 84 to 72 — measured
  // on a 390×844 phone the FAB sat 6 px above the dock instead of 18 px.

  group('getFloatingBottomBarFABReserveHeight', () {
    Future<({double reserve, double gap})> pumpFabPage(
      WidgetTester tester,
    ) async {
      var reserve = 0.0;
      await pumpMobilePage(
        tester,
        Builder(
          builder: (ctx) {
            reserve = getFloatingBottomBarFABReserveHeight(ctx);
            return CommonScaffold(
              title: 'fab-page',
              body: const SizedBox.expand(),
              floatingActionButton: Padding(
                padding: EdgeInsets.only(bottom: reserve),
                child: FloatingActionButton(
                  heroTag: null,
                  onPressed: () {},
                  child: const Icon(Icons.add),
                ),
              ),
            );
          },
        ),
      );

      final dock = tester.getRect(find.byType(AuroraBottomNavBar));
      final fab = tester.getRect(find.byType(FloatingActionButton));
      return (reserve: reserve, gap: dock.top - fab.bottom);
    }

    testWidgets('is not shrunk by the injected dock inset', (tester) async {
      final result = await pumpFabPage(tester);

      expect(
        result.reserve,
        84.0,
        reason:
            'the injected padding.bottom must not feed the min() term — that '
            'turned 84 into 72',
      );
    });

    testWidgets('keeps the FAB comfortably clear of the dock', (tester) async {
      final result = await pumpFabPage(tester);

      // 16 px is the FAB's own Scaffold margin; anything at or below that means
      // the button is touching the dock. Before the fix this measured 6.
      expect(
        result.gap,
        greaterThanOrEqualTo(16.0),
        reason: 'measured gap above the dock: ${result.gap}',
      );
    });
  });
  // ── Keyboard inset must not leak into either reserve ─────────────────────
  //
  // Both helpers used `max(viewPadding.bottom, padding.bottom)`. With the
  // keyboard open, `padding.bottom` becomes the keyboard height, so the content
  // reserve would have become `84 + (300 - 12) = 372` — a screenful of dead
  // space while typing. Reading `viewPadding` (which the keyboard does not
  // change) keeps the reserve at the dock's height.

  group('keyboard inset', () {
    testWidgets('does not inflate the content reserve', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);

      final result = await pumpMobilePage(
        tester,
        CommonScaffold(title: 'typing', body: const SizedBox.expand()),
      );

      expect(
        result.reserve,
        84.0,
        reason: 'the keyboard is not the dock; the reserve must stay at 84',
      );
    });

    testWidgets('does not inflate the FAB reserve', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);

      var fabReserve = 0.0;
      await pumpMobilePage(
        tester,
        Builder(
          builder: (ctx) {
            fabReserve = getFloatingBottomBarFABReserveHeight(ctx);
            return CommonScaffold(title: 'typing', body: const SizedBox.expand());
          },
        ),
      );

      // `84 - min(300, 12)` = 72 is the same value a real phone inset produces;
      // what must never happen is a negative or inflated number.
      expect(fabReserve, inInclusiveRange(0.0, 84.0));
    });
  });
}
