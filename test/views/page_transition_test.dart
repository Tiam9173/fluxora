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

/// Phase 04.2 — page transitions and navigation switching.
///
/// `_HomePageView` is library-private, so the entry point is [HomePage] with two
/// throwaway pages. That keeps the pumped tree small while still running the
/// **real** host: the same `AnimatedSwitcher` (mobile) / `PageView` (desktop)
/// production builds, the same `KeepScope`, and the same dock-height injection.
///
/// Each page is a `StatefulWidget` that counts `initState` / `dispose`, which is
/// how the "does a switch re-initialise a page" question is answered — the real
/// pages start platform work there (dashboard cards call
/// `SystemProxyReadbackService` and `ClashHandlerInterface.getMemory`), so a
/// second `initState` is a second round of real work.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Counters counters;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  setUp(() {
    counters = _Counters();
  });

  List<NavigationItem> items() => [
    NavigationItem(
      icon: const Icon(Icons.dashboard),
      label: PageLabel.dashboard,
      builder: (_) => _CountedPage(tag: 'A', counters: counters),
    ),
    NavigationItem(
      icon: const Icon(Icons.folder),
      label: PageLabel.profiles,
      builder: (_) => _CountedPage(tag: 'B', counters: counters),
    ),
  ];

  Widget seedGlobals(Widget child) => Builder(
    builder: (ctx) {
      globalState.theme = CommonTheme.of(ctx, 1.0);
      globalState.measure = Measure.of(ctx, 1.0);
      return child;
    },
  );

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    required bool mobile,
    bool reduce = false,
  }) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduce);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    final size = mobile ? const Size(400, 800) : const Size(1200, 800);
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

    final list = items();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationStateProvider.overrideWith(
            (ref) => NavigationState(
              pageLabel: PageLabel.dashboard,
              navigationItems: list,
              viewMode: mobile ? ViewMode.mobile : ViewMode.desktop,
              locale: 'zh_CN',
              currentIndex: 0,
            ),
          ),
          currentNavigationItemsStateProvider.overrideWith(
            (ref) => NavigationItemsState(value: list),
          ),
          isMobileViewProvider.overrideWith((ref) => mobile),
        ],
        child: MaterialApp(home: seedGlobals(const HomePage())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    return ProviderScope.containerOf(tester.element(find.byType(HomePage)));
  }

  void goTo(ProviderContainer c, PageLabel label) {
    c.read(currentPageLabelProvider.notifier).value = label;
  }

  group('mobile page switch', () {
    testWidgets('a switch cross-fades: both pages exist mid-transition', (
      tester,
    ) async {
      final c = await pumpHome(tester, mobile: true);

      goTo(c, PageLabel.profiles);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('page-A'),
        findsOneWidget,
        reason: 'the outgoing page is still fading out',
      );
      expect(find.text('page-B'), findsOneWidget);
      expect(
        tester.hasRunningAnimations,
        isTrue,
        reason: 'the cross-fade is in flight',
      );

      await tester.pumpAndSettle();
      expect(find.text('page-A'), findsNothing);
      expect(find.text('page-B'), findsOneWidget);
    });

    testWidgets('the entering page carries the 4 px Aurora lift', (
      tester,
    ) async {
      // §10.2: an entering element is offset by `enterOffset` and settles to 0.
      // Read through the widget the transition actually builds, not a constant.
      final c = await pumpHome(tester, mobile: true);

      goTo(c, PageLabel.profiles);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final slides = tester.widgetList<SlideTransition>(
        find.ancestor(
          of: find.text('page-B'),
          matching: find.byType(SlideTransition),
        ),
      );
      expect(slides, isNotEmpty, reason: 'the page enters with a slide');

      final dy = slides.first.position.value.dy;
      expect(dy, greaterThan(0.0), reason: 'still lifted at 60 ms');
      expect(
        dy,
        lessThanOrEqualTo(4.0),
        reason: 'never more than the 4 px token',
      );

      await tester.pumpAndSettle();
      final settled = tester
          .widgetList<SlideTransition>(
            find.ancestor(
              of: find.text('page-B'),
              matching: find.byType(SlideTransition),
            ),
          )
          .first
          .position
          .value
          .dy;
      expect(settled, 0.0);
    });

    testWidgets('reduced motion shows the new page in the first frame', (
      tester,
    ) async {
      final c = await pumpHome(tester, mobile: true, reduce: true);

      goTo(c, PageLabel.profiles);
      await tester.pump();

      expect(find.text('page-A'), findsNothing);
      expect(find.text('page-B'), findsOneWidget);
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: 'no cross-fade and no slide under reduced motion',
      );
    });

    testWidgets('reduced motion never moves the page', (tester) async {
      final c = await pumpHome(tester, mobile: true, reduce: true);

      goTo(c, PageLabel.profiles);
      await tester.pump();

      final first = tester.getTopLeft(find.text('page-B'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('page-B')),
        first,
        reason: 'enterOffset collapses to zero, so nothing travels',
      );
    });

    testWidgets('rapid switching lands on the last selection', (tester) async {
      final c = await pumpHome(tester, mobile: true);

      for (final label in [
        PageLabel.profiles,
        PageLabel.dashboard,
        PageLabel.profiles,
        PageLabel.dashboard,
      ]) {
        goTo(c, label);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('page-A'), findsOneWidget);
      expect(find.text('page-B'), findsNothing);
      expect(c.read(currentPageLabelProvider), PageLabel.dashboard);
    });

    testWidgets('the visible page matches the current label', (tester) async {
      // "selected nav item ↔ shown content" consistency for the main rail/dock.
      final c = await pumpHome(tester, mobile: true);

      goTo(c, PageLabel.profiles);
      await tester.pumpAndSettle();
      expect(c.read(currentPageLabelProvider), PageLabel.profiles);
      expect(find.text('page-B'), findsOneWidget);

      goTo(c, PageLabel.dashboard);
      await tester.pumpAndSettle();
      expect(find.text('page-A'), findsOneWidget);
    });
  });

  group('page initialisation', () {
    testWidgets('the first page mounts exactly once', (tester) async {
      // Regression: the dock-height injection used to wrap the page in a
      // `MediaQuery` only once `_dockHeight` was measured (frame 2). That changed
      // the widget type in that slot and remounted the whole subtree, so every
      // cold start ran the page's `initState` twice — and the real pages start
      // platform work there.
      await pumpHome(tester, mobile: true);

      expect(
        counters.inits['A'],
        1,
        reason: 'a second initState means a second round of real page work',
      );
      expect(counters.disposes['A'] ?? 0, 0);
    });

    testWidgets('switching away does not re-initialise the old page', (
      tester,
    ) async {
      final c = await pumpHome(tester, mobile: true);

      goTo(c, PageLabel.profiles);
      await tester.pumpAndSettle();

      expect(
        counters.inits['A'],
        1,
        reason: 'the outgoing page is disposed, never re-created',
      );
      expect(counters.inits['B'], 1);
    });

    testWidgets('the dock measurement still reaches the page', (tester) async {
      // The fix must not have cost the reserve: the injected bottom padding is
      // what keeps the last row clear of the dock. Read it from **inside** the
      // page — `HomePage`'s own context sits above the injection.
      await pumpHome(tester, mobile: true);
      final pageCtx = tester.element(find.text('page-A'));
      expect(
        MediaQuery.of(pageCtx).padding.bottom,
        greaterThan(0.0),
        reason: 'the measured dock height is still published to the page',
      );
    });
  });

  group('desktop page switch', () {
    testWidgets('switching keeps the outgoing page alive', (tester) async {
      // `PageView` + `KeepScope`: the desktop path keeps pages mounted, which is
      // why it does not need a transition to hide a rebuild.
      final c = await pumpHome(tester, mobile: false);

      goTo(c, PageLabel.profiles);
      await tester.pumpAndSettle();

      expect(find.text('page-B'), findsOneWidget);
      expect(
        counters.disposes['A'] ?? 0,
        0,
        reason: 'the desktop host keeps the page state',
      );
      expect(counters.inits['A'], 1);
    });

    testWidgets('rapid switching lands on the last selection', (tester) async {
      final c = await pumpHome(tester, mobile: false);

      for (final label in [
        PageLabel.profiles,
        PageLabel.dashboard,
        PageLabel.profiles,
      ]) {
        goTo(c, label);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('page-B'), findsOneWidget);
      expect(c.read(currentPageLabelProvider), PageLabel.profiles);
    });
  });
}

/// Counts `initState` / `dispose` per page tag.
class _Counters {
  final Map<String, int> inits = <String, int>{};
  final Map<String, int> disposes = <String, int>{};

  void init(String tag) => inits[tag] = (inits[tag] ?? 0) + 1;
  void dispose(String tag) => disposes[tag] = (disposes[tag] ?? 0) + 1;
}

class _CountedPage extends StatefulWidget {
  const _CountedPage({required this.tag, required this.counters});

  final String tag;
  final _Counters counters;

  @override
  State<_CountedPage> createState() => _CountedPageState();
}

class _CountedPageState extends State<_CountedPage> {
  @override
  void initState() {
    super.initState();
    widget.counters.init(widget.tag);
  }

  @override
  void dispose() {
    widget.counters.dispose(widget.tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('page-${widget.tag}');
}
