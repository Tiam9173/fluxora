import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/views/dashboard/dashboard.dart';

/// Phase 05.3 — the dashboard grid's arithmetic, checked as pure functions.
///
/// The layout itself needs a real window (Phase 05.3 visual), but the column
/// formula is where the narrow-window behaviour is decided, and it can be
/// verified exactly.
void main() {
  test('the column count is a multiple of four and never decreases', () {
    var previous = 0;
    for (var w = 320.0; w <= 2560; w += 40) {
      final columns = dashboardColumnCount(w);
      expect(columns % 4, 0, reason: '4-cell cards stay proportional at $w');
      expect(columns, greaterThanOrEqualTo(previous), reason: 'at $w');
      previous = columns;
    }
  });

  test('the hero owns a whole row at every width', () {
    for (final width in const [372.0, 601.0, 840.0, 1200.0, 1920.0]) {
      final columns = dashboardColumnCount(width);
      final hero = dashboardGridItemFor(
        DashboardWidget.startButton.widget,
        columns,
      );
      expect(
        hero.crossAxisCellCount,
        columns,
        reason: 'the start control must not share its row at $width',
      );
    }
  });

  // Registered, not fixed: the floor of 8 columns exists so the 8-cell hero owns
  // a row, but at the 372 px window minimum the content area is only
  // 372 − 81 = 291 px, so each of the 8 cells is ~36 px wide. Dropping the floor
  // to 4 would fix that and break every card that declares a span of 8, so it
  // needs a span audit of the whole widget set — out of scope for this round.
  test('KNOWN: 8 columns at the 372 px minimum gives ~36 px cells', () {
    expect(dashboardColumnCount(372), 8);
    expect((372 - 81) / 8, lessThan(40));
  });
}
