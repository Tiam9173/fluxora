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

/// Phase 00.6-F10-C — the mobile page transition must obey reduce motion.
///
/// `_HomePageView` is library-private, so the only public entry is [HomePage].
/// The navigation list and the current page are therefore overridden with two
/// throwaway pages, which keeps the pumped tree small while still running the
/// real `AnimatedSwitcher` that production builds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<NavigationItem> items;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  setUp(() {
    globalState.appState = AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.dashboard,
    );
    items = [
      NavigationItem(
        icon: const Icon(Icons.dashboard),
        label: PageLabel.dashboard,
        builder: (_) => const Text('page-dashboard'),
      ),
      NavigationItem(
        icon: const Icon(Icons.folder),
        label: PageLabel.profiles,
        builder: (_) => const Text('page-profiles'),
      ),
    ];
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

  Future<void> pumpHome(WidgetTester tester, {required bool reduce}) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduce);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

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
  }

  /// The page switcher is the `AnimatedSwitcher` that wraps the current page,
  /// so anchor on the page text rather than `find.byType` (the nav bar and
  /// `CommonTargetIcon` bring their own switchers).
  Duration pageSwitcherDuration(WidgetTester tester) {
    final switcher = tester.widget<AnimatedSwitcher>(
      find
          .ancestor(
            of: find.text('page-dashboard'),
            matching: find.byType(AnimatedSwitcher),
          )
          .first,
    );
    return switcher.duration;
  }

  testWidgets('reduce motion removes the page cross-fade', (tester) async {
    await pumpHome(tester, reduce: true);

    expect(pageSwitcherDuration(tester), Duration.zero);
  });

  testWidgets('without reduce motion the transition keeps the token duration', (
    tester,
  ) async {
    await pumpHome(tester, reduce: false);

    // Pinned to the token, not to a literal: the value is whatever
    // `FluxoraMotion.slow` currently is.
    expect(pageSwitcherDuration(tester), FluxoraMotion.slow);
    expect(pageSwitcherDuration(tester), isNot(Duration.zero));
  });
}
