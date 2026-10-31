import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/manager/app_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Desktop shell baseline — the measured geometry the toolbar and content area
/// actually produce today.
///
/// Phase 02 has to be able to tell "this is the design" apart from "this drifted",
/// and the only way is to record the numbers. Everything below was measured on
/// 2026-10-28 through `AppSidebarContainer` with a real `CommonScaffold`; the
/// assertions are the specification, not a guess at what the design should be.
///
/// Recorded values (601 / 840 / 1200 wide, 800 tall):
///
/// | measurement                     | value |
/// | ------------------------------- | ----- |
/// | rail width (`AuroraNavigationRail`) | 80 |
/// | content area starts at          | 81 — the rail's 1 px right border sits |
/// |                                 | *outside* the rail widget, so the shell |
/// |                                 | column is 81 wide and there is no gutter |
/// | page title glyph x              | contentOrigin + 16 |
/// | first content card left edge    | rail.right + 16 |
/// | first card's inner text x       | rail.right + 32 (card padding, **not** misalignment) |
/// | trailing action glyph right     | appBar.right − 20 |
/// | content card right edge         | appBar.right − 16 |
///
/// The 4 px difference on the right is **optical**: a 24 px icon glyph carries
/// its own whitespace, so it is inset 8 px inside its `IconButton` on top of the
/// 8 px spacer `genActions` adds. Aligning the *glyph box* to 16 would make the
/// icon look tighter than the cards beside it. It is pinned, not "fixed".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  Future<void> pumpDesktop(
    WidgetTester tester, {
    required double width,
    double height = 800,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    globalState.appState = AppState(
      viewSize: Size(width, height),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.dashboard,
    );

    final items = navigation.getItems();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationStateProvider.overrideWith(
            (ref) => NavigationState(
              pageLabel: PageLabel.dashboard,
              navigationItems: items,
              viewMode: ViewMode.desktop,
              locale: 'zh_CN',
              currentIndex: 0,
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) {
              globalState.theme = CommonTheme.of(ctx, 1.0);
              globalState.measure = Measure.of(ctx, 1.0);
              return Scaffold(
                body: AppSidebarContainer(
                  child: CommonScaffold(
                    title: 'page-title',
                    actions: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.save_as_outlined),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                    body: generateListView([
                      for (var i = 0; i < 8; i++)
                        ListTile(title: Text('row-$i')),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('desktop shell baseline', () {
    for (final width in [601.0, 840.0, 1200.0]) {
      testWidgets('rail width and content origin are stable @ $width', (
        tester,
      ) async {
        await pumpDesktop(tester, width: width);

        final rail = tester.getRect(find.byType(AuroraNavigationRail));
        expect(rail.width, 80, reason: 'collapsed rail with labels');

        // Content is an `Expanded` sibling: it starts at the rail column's right
        // edge — the rail's own 1 px right border is painted outside the
        // rail widget, so the column is one pixel wider. There is no
        // extra gutter; every horizontal inset comes from the page itself.
        const contentOrigin = 81.0;
        final card = tester.getRect(find.byType(CommonCard).first);
        expect(card.left, contentOrigin + 16);
      });

      testWidgets('the title lines up with the content edge @ $width', (
        tester,
      ) async {
        await pumpDesktop(tester, width: width);

        final title = tester.getTopLeft(find.text('page-title')).dx;
        final card = tester.getRect(find.byType(CommonCard).first);

        // The title aligns with the *card edge*, not with the text inside the
        // card — that inner 16 px is the card's own padding.
        expect(title, card.left);
        expect(title, 81 + 16);
      });

      testWidgets('card inner text is inset by the card padding @ $width', (
        tester,
      ) async {
        await pumpDesktop(tester, width: width);

        final card = tester.getRect(find.byType(CommonCard).first);
        final rowText = tester.getTopLeft(find.text('row-0')).dx;

        expect(
          rowText - card.left,
          16,
          reason: 'this gap is card padding, not a title/content misalignment',
        );
      });

      testWidgets('trailing action sits 4 px inside the card edge @ $width', (
        tester,
      ) async {
        await pumpDesktop(tester, width: width);

        final appBar = tester.getRect(find.byType(AppBar));
        final actionGlyph = tester.getRect(find.byIcon(Icons.delete_outline));
        final card = tester.getRect(find.byType(CommonCard).first);

        expect(appBar.right - card.right, 16);
        expect(
          appBar.right - actionGlyph.right,
          20,
          reason:
              'icon glyph is optically inset 4 px further than the card edge '
              '(8 px genActions spacer + 8 px IconButton padding)',
        );
      });
    }

    testWidgets('no overflow at the narrowest desktop width', (tester) async {
      await pumpDesktop(tester, width: 601);

      expect(tester.takeException(), isNull);
    });
  });
}
