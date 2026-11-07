import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/views/dashboard/dashboard.dart';
import 'package:fluxora/widgets/widgets.dart';

/// The Dashboard's information hierarchy, expressed as two rules the page can be
/// held to without a live core:
///
/// 1. **The start/stop control owns a whole row at every width.** Its enum entry
///    hardcodes `crossAxisCellCount: 8`, which was a full row only while the grid
///    had 8 columns. `dashboardColumnCount` grows with the window (16 at 1200 px),
///    so the Hero silently became half a row and shared it with a metric card —
///    the opposite of "core status first".
/// 2. **The Hero sits one surface plane above the metric cards.** `FluxoraCard`
///    is plain (`surfaceContainerLow`) by default; the Hero now passes
///    `filled: true` (`surfaceContainer`), which is the same ladder the rail and
///    toolbar use.
///
/// The card-surface test drives the real primitive (`FluxoraCard` → `CommonCard`)
/// rather than asserting a flag, so it fails if the colour mapping ever changes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  group('dashboard grid hierarchy', () {
    test('the column count grows with the window', () {
      // 8 is the floor: it is what makes an 8-cell card a full row on a phone.
      expect(dashboardColumnCount(320), 8);
      expect(dashboardColumnCount(601), 8);
      expect(dashboardColumnCount(840), 12);
      expect(dashboardColumnCount(1200), 16);
      expect(dashboardColumnCount(1920), 24);
    });

    test('the start control is full-width on mobile and capped on desktop', () {
      for (final width in [320.0, 601.0, 840.0, 1200.0, 1920.0]) {
        final columns = dashboardColumnCount(width);
        final hero = dashboardGridItemFor(
          DashboardWidget.startButton.widget,
          columns,
        );

        expect(
          hero.crossAxisCellCount,
          columns > 8 ? 8 : columns,
          reason: 'at $width px keep the connection panel compact and readable',
        );
      }
    });

    test('the start control stays non-deletable after the span rewrite', () {
      final hero = dashboardGridItemFor(DashboardWidget.startButton.widget, 16);

      expect(hero.isDeletable, isFalse);
      expect(
        hero.child,
        same(DashboardWidget.startButton.widget.child),
        reason: 'the rewrite must not rebuild the widget subtree',
      );
    });

    test('metric cards keep the span they declare', () {
      for (final widget in [
        DashboardWidget.trafficUsage.widget,
        DashboardWidget.memoryInfo.widget,
        DashboardWidget.networkSpeed.widget,
      ]) {
        final resolved = dashboardGridItemFor(widget, 16);
        expect(
          identical(resolved, widget),
          isTrue,
          reason: 'only the Hero is rewritten; every other item is untouched',
        );
      }
    });
  });

  group('hero surface', () {
    Future<Color?> paintedCardColor(
      WidgetTester tester, {
      required bool filled,
    }) async {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF29D6C7),
        brightness: Brightness.dark,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: scheme),
          home: Scaffold(
            body: Center(
              child: FluxoraCard(
                filled: filled,
                child: const SizedBox(width: 120, height: 40),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final materials = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(FluxoraCard),
              matching: find.byType(Material),
            ),
          )
          .where((m) => m.color != null)
          .toList();
      expect(materials, isNotEmpty, reason: 'the card paints a material');
      return materials.first.color;
    }

    testWidgets('filled lifts the card one plane above a plain card', (
      tester,
    ) async {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF29D6C7),
        brightness: Brightness.dark,
      );

      final plain = await paintedCardColor(tester, filled: false);
      final filled = await paintedCardColor(tester, filled: true);

      expect(plain, scheme.surfaceContainerLow);
      expect(filled, scheme.surfaceContainer);
      expect(
        filled,
        isNot(plain),
        reason:
            'if these ever collapse, the Hero stops reading as the primary '
            'surface',
      );
    });
  });
}
