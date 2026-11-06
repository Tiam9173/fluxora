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

/// Desktop content alignment with a 68px narrow rail or 208px expanded sidebar.
/// Borders paint inside the sidebar; page gutters and app-bar metrics stay intact.
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
        final sidebarWidth = width <= maxLaptopWidth ? 68.0 : 208.0;
        expect(rail.width, sidebarWidth);

        final contentOrigin = sidebarWidth;
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
        expect(title, (width <= maxLaptopWidth ? 68 : 208) + 16);
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
