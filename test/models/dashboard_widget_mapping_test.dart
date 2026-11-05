import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Saving the dashboard layout maps each grid tile back to its enum value.
///
/// Reported: add or reorder the home widgets, save, and nothing changes.
///
/// The Hero is re-wrapped into a full-width `GridItem` before it reaches the
/// grid (`dashboardGridItemFor`), so the tile the grid hands back is **not**
/// the instance stored in `DashboardWidget.startButton.widget`. Mapping by
/// value equality then misses, `indexWhere` returns -1, and indexing with -1
/// threw inside the post-frame save callback — the write never happened.
void main() {
  test('a full-width Hero maps back to startButton', () {
    final rewrapped = GridItem(
      crossAxisCellCount: 4, // the phone column count, not the stored 8
      mainAxisCellCount: DashboardWidget.startButton.widget.mainAxisCellCount,
      isDeletable: DashboardWidget.startButton.widget.isDeletable,
      child: DashboardWidget.startButton.widget.child,
    );

    expect(
      DashboardWidget.getDashboardWidget(rewrapped),
      DashboardWidget.startButton,
    );
  });

  test('an untouched tile still maps by value', () {
    expect(
      DashboardWidget.getDashboardWidget(DashboardWidget.networkSpeed.widget),
      DashboardWidget.networkSpeed,
    );
  });

  test('an unknown tile maps to null instead of throwing', () {
    final stranger = GridItem(
      crossAxisCellCount: 1,
      child: const SizedBox.shrink(),
    );

    expect(DashboardWidget.getDashboardWidget(stranger), isNull);
  });
}
