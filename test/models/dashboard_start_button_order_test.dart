import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';

/// The start button is the dashboard's connection Hero (D4.6): full width and
/// `isDeletable: false`. It used to sit **last** in both default widget lists,
/// so a fresh install needed a scroll before the main switch was visible.
///
/// This pins the visible-first contract.
void main() {
  group('dashboard start button leads the first screen', () {
    test('it is the first default widget on desktop', () {
      expect(defaultDashboardWidgets.first, DashboardWidget.startButton);
    });

    test('it is the first default widget on Android', () {
      expect(defaultAndroidDashboardWidgets.first, DashboardWidget.startButton);
    });

    test('it appears exactly once in each default list', () {
      expect(
        defaultDashboardWidgets
            .where((w) => w == DashboardWidget.startButton)
            .length,
        1,
      );
      expect(
        defaultAndroidDashboardWidgets
            .where((w) => w == DashboardWidget.startButton)
            .length,
        1,
      );
    });
  });

  group('the Hero is a full-width, undeletable card', () {
    test('spans the whole grid row', () {
      // The dashboard grid uses 8 columns; the Hero must span all of them so
      // leading the list costs exactly one full-width row.
      expect(DashboardWidget.startButton.widget.crossAxisCellCount, 8);
    });

    test('cannot be removed in edit mode', () {
      expect(DashboardWidget.startButton.widget.isDeletable, isFalse);
    });
  });

  // The provider re-inserts the Hero when a stored list predates it. Appending
  // it there would reintroduce the same "below the fold" problem for those
  // users, so the fallback must prepend.
  test('every other default widget is still present', () {
    expect(defaultDashboardWidgets.length, 10);
    expect(defaultAndroidDashboardWidgets.length, 7);
    // Spot-check that reordering did not drop or duplicate anything.
    for (final w in const [
      DashboardWidget.networkSpeed,
      DashboardWidget.trafficUsage,
      DashboardWidget.networkDetection,
      DashboardWidget.memoryInfo,
      DashboardWidget.connectionsCount,
    ]) {
      expect(
        defaultDashboardWidgets.contains(w),
        isTrue,
        reason: '$w missing from the desktop defaults',
      );
      expect(
        defaultAndroidDashboardWidgets.contains(w),
        isTrue,
        reason: '$w missing from the Android defaults',
      );
    }
  });
}
