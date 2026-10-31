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

/// The mobile shell paints the bottom dock **over** the page:
///
/// ```dart
/// Stack(children: [
///   Positioned.fill(child: pageContent),
///   Positioned(bottom: 0, child: navBar),
/// ])
/// ```
///
/// so the page loses the bottom slice of its own viewport. Nothing reserved it:
/// `generateListView` pads by `24 + MediaQuery.padding.bottom`, and that value
/// only ever carried the *system* inset.
///
/// Measured before the fix on a 390×844 phone: the dock covered y 762–844
/// (height 82) while the last list row sat at y 782–802 — the final row was
/// fully hidden and could not be tapped.
///
/// These tests drive the real `HomePage` in mobile mode with a real
/// `generateListView` page, scroll to the end, and compare the last row against
/// the dock's top edge.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  var tapped = <int>[];

  setUp(() {
    tapped = <int>[];
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

  /// Pumps the real mobile shell with one page whose body is a
  /// `generateListView` list of [itemCount] rows.
  Future<void> pumpMobileShell(
    WidgetTester tester, {
    double textScale = 1.0,
    int itemCount = 40,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final items = [
      NavigationItem(
        icon: const Icon(Icons.dashboard),
        label: PageLabel.dashboard,
        builder: (_) => CommonScaffold(
          title: 'fake-page',
          body: generateListView([
            for (var i = 0; i < itemCount; i++)
              ListTile(
                dense: true,
                title: Text('item-$i'),
                onTap: () => tapped.add(i),
              ),
          ]),
        ),
      ),
    ];

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
    // First frame lays the dock out; the post-frame measurement then stores its
    // height and rebuilds with the inset.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  double dockTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(AuroraBottomNavBar)).dy;

  group('mobile dock inset', () {
    testWidgets('the last list row is not covered by the dock', (tester) async {
      await pumpMobileShell(tester);
      await scrollToEnd(tester);

      final lastRowBottom = tester.getBottomLeft(find.text('item-39')).dy;

      expect(
        lastRowBottom,
        lessThanOrEqualTo(dockTop(tester)),
        reason:
            'scrolled to the end, the final row must sit above the floating '
            'dock (dock top ${dockTop(tester)}, row bottom $lastRowBottom)',
      );
    });

    testWidgets('the last list row can actually be tapped', (tester) async {
      // The row being *drawn* above the dock is not enough — it also has to
      // receive the hit. Before the fix it was painted underneath the dock and
      // the tap landed on the dock instead.
      await pumpMobileShell(tester);
      await scrollToEnd(tester);

      await tester.tap(find.text('item-39'));
      await tester.pump();

      expect(tapped, contains(39));
    });

    testWidgets('the inset survives a 1.4x text scale', (tester) async {
      // The dock contains a label under every icon, so it grows with the text
      // scale. A hardcoded inset would under-reserve exactly here.
      await pumpMobileShell(tester, textScale: 1.4);
      await scrollToEnd(tester);

      final lastRowBottom = tester.getBottomLeft(find.text('item-39')).dy;
      expect(
        lastRowBottom,
        lessThanOrEqualTo(dockTop(tester)),
        reason: 'the measured inset must follow the dock, not a fixed number',
      );
    });

    testWidgets('the dock still sits flush with the bottom edge', (
      tester,
    ) async {
      // Regression guard: the fix adds an inset to the *page*, it must not move
      // the dock or shrink it.
      await pumpMobileShell(tester);

      final rect = tester.getRect(find.byType(AuroraBottomNavBar));
      expect(rect.bottom, 844);
      expect(rect.top, greaterThan(0));
    });

    testWidgets('a short list still ends above the dock', (tester) async {
      // Fewer rows than fill the viewport: nothing scrolls, so the inset must
      // not push the content around.
      await pumpMobileShell(tester, itemCount: 3);

      expect(find.text('item-2'), findsOneWidget);
      final lastRowBottom = tester.getBottomLeft(find.text('item-2')).dy;
      expect(lastRowBottom, lessThan(dockTop(tester)));
    });
  });
  group('breakpoint boundaries', () {
    // `getViewMode` is the single source of truth for the three layouts
    // (`utils.dart:949`), with `maxMobileWidth = 600` and `maxLaptopWidth = 840`
    // (`constant.dart:61-62`). Pinned at both sides so a future "round number"
    // tweak cannot silently move the mobile shell onto tablets.
    test('mobile ends at 600 inclusive', () {
      expect(utils.getViewMode(320), ViewMode.mobile);
      expect(utils.getViewMode(599), ViewMode.mobile);
      expect(utils.getViewMode(600), ViewMode.mobile);
    });

    test('laptop runs from 601 to 840 inclusive', () {
      expect(utils.getViewMode(601), ViewMode.laptop);
      expect(utils.getViewMode(840), ViewMode.laptop);
    });

    test('desktop starts at 841', () {
      expect(utils.getViewMode(841), ViewMode.desktop);
      expect(utils.getViewMode(1440), ViewMode.desktop);
    });
  });

  group('narrow window', () {
    testWidgets('a 320x640 window at 1.4x keeps the last row clear', (
      tester,
    ) async {
      // Worst realistic case: narrow phone plus the largest supported text
      // scale. The dock grows, so the measured inset has to follow it.
      await pumpMobileShell(tester, textScale: 1.4, size: const Size(320, 640));
      await scrollToEnd(tester);

      final lastRowBottom = tester.getBottomLeft(find.text('item-39')).dy;
      expect(
        lastRowBottom,
        lessThanOrEqualTo(dockTop(tester)),
        reason: 'the final row must stay above the dock at 320x640 / 1.4x',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
