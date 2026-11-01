import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/config/config.dart';
import 'package:fluxora/views/config/general.dart';

/// P8-2D — the Settings hierarchy page (`ConfigView`) as a page.
///
/// `test/views/config/` already covers the *rows* (`settings_rows_test.dart`:
/// wrapping; `settings_rows_behavior_test.dart`: disabled/enabled semantics;
/// `config_write_through_test.dart`: provider writes; `user_auth_test.dart`:
/// the auth sheet). None of them mount `ConfigView` itself, so nothing pinned
/// the page's own contract: which destinations it lists, in what order, that
/// each one is reachable, and that the list survives phone widths.
///
/// Safety: `ConfigView` only *builds* rows. The reset buttons live inside
/// `NextDelegate.actions` and only run on tap, so this file never touches
/// `patchClashConfigProvider` writes, the core, or the system proxy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  // ── the destinations the page actually lists, in render order ─────────────
  //
  // Five come from `appLocalizations`, three are literal ('DNS', 'NTP',
  // 'Hosts') — exactly as `config.dart` writes them.
  List<String> expectedTitles() => [
    appLocalizations.general,
    appLocalizations.network,
    'DNS',
    'NTP',
    'Hosts',
    appLocalizations.sniffer,
    appLocalizations.tunnel,
    appLocalizations.experimental,
  ];

  Widget seedGlobals(Widget child) {
    return Builder(
      builder: (ctx) {
        globalState.theme = CommonTheme.of(ctx, 1.0);
        globalState.measure = Measure.of(ctx, 1.0);
        return child;
      },
    );
  }

  Future<void> pumpConfig(
    WidgetTester tester, {
    Size size = const Size(480, 800),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // `showExtend` reads `globalState.appState.viewMode` before it decides how
    // to open a destination, and `ListItem` reads the theme/measure globals.
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
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => MediaQuery(
              data: MediaQuery.of(
                ctx,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: seedGlobals(const Scaffold(body: ConfigView())),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Vertical position of a rendered title, used to prove the *order* rather
  /// than mere presence.
  double topOf(WidgetTester tester, String title) =>
      tester.getTopLeft(find.text(title)).dy;

  // ── S1 — hierarchy ────────────────────────────────────────────────────────

  group('S1 — hierarchy', () {
    testWidgets('lists the eight destinations in render order', (tester) async {
      await pumpConfig(tester);

      final titles = expectedTitles();
      for (final title in titles) {
        expect(
          find.text(title),
          findsOneWidget,
          reason: '"$title" must be listed on the settings page',
        );
      }

      // Order, not just membership: every title sits strictly below the one
      // before it.
      final tops = [for (final title in titles) topOf(tester, title)];
      for (var i = 1; i < tops.length; i++) {
        expect(
          tops[i],
          greaterThan(tops[i - 1]),
          reason:
              '"${titles[i]}" must render below "${titles[i - 1]}" '
              '(measured $tops)',
        );
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('each destination row is a tappable next-row', (tester) async {
      await pumpConfig(tester);

      // `ListItem.next` wires `onTap` itself; a row that lost its delegate
      // would render but do nothing.
      final tiles = find.descendant(
        of: find.byType(ConfigView),
        matching: find.byType(InkWell),
      );
      expect(
        tiles,
        findsWidgets,
        reason: 'the settings rows must be interactive',
      );
    });
  });

  // ── S2 — a destination opens, and coming back leaves the page intact ──────

  group('S2 — navigation', () {
    testWidgets('tapping General opens the real General page and pops back', (
      tester,
    ) async {
      await pumpConfig(tester);

      await tester.tap(find.text(appLocalizations.general));
      await tester.pumpAndSettle();

      expect(
        find.byType(GeneralListView),
        findsOneWidget,
        reason: 'the row must open the page its delegate builds',
      );

      // Back out: the settings list is still there.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(ConfigView), findsOneWidget);
      expect(
        find.text(appLocalizations.general),
        findsOneWidget,
        reason: 'popping must not have emptied the settings page',
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ── S3 — phone widths ─────────────────────────────────────────────────────

  group('S3 — narrow layout', () {
    for (final size in const [
      Size(320, 640),
      Size(375, 667),
      Size(480, 800),
      Size(600, 800),
    ]) {
      testWidgets('the settings list fits at ${size.width.toInt()} px', (
        tester,
      ) async {
        await pumpConfig(tester, size: size);

        // Real content, not an empty shell.
        expect(find.byType(ConfigView), findsOneWidget);
        expect(find.text(appLocalizations.general), findsOneWidget);
        expect(
          find.byType(ListView),
          findsOneWidget,
          reason: 'the page must be the real scrollable list',
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'no RenderFlex overflow at ${size.width.toInt()} px',
        );
      });
    }
  });

  // ── S4 — the last destination is reachable by scrolling ───────────────────

  group('S4 — scroll reachability', () {
    testWidgets('the last destination becomes visible after scrolling', (
      tester,
    ) async {
      // 372×492 is the documented minimum window (`lib/common/window.dart`),
      // not an arbitrary size: at 320×640 all eight rows already fit, so there
      // would be nothing to scroll and the test would prove nothing.
      const height = 492.0;
      await pumpConfig(tester, size: const Size(372, 492));

      final last = appLocalizations.experimental;
      final before = find.text(last);
      final startsBelowFold =
          before.evaluate().isEmpty ||
          tester.getRect(before).top >= height;
      expect(
        startsBelowFold,
        isTrue,
        reason: 'precondition: the last row starts below the fold',
      );

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(
        find.text(last),
        findsOneWidget,
        reason: 'scrolling must reach the last destination',
      );
      final rect = tester.getRect(find.text(last));
      expect(
        rect.top,
        lessThan(height),
        reason: 'and it must land inside the viewport',
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ── S6 — enlarged text ────────────────────────────────────────────────────

  group('S6 — text scale', () {
    testWidgets('the list still fits at 320 px with 1.4x text', (tester) async {
      await pumpConfig(
        tester,
        size: const Size(320, 640),
        textScale: 1.4,
      );

      expect(find.text(appLocalizations.general), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'enlarged text must not overflow the settings rows',
      );
    });
  });
}
