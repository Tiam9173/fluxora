import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/views/dashboard/widget_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('layout preview shows the selected widget proportions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 280));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 200,
              child: DashboardWidgetPreview(
                type: DashboardWidget.memoryInfo,
                layout: DashboardWidgetLayout.oneByFour,
              ),
            ),
          ),
        ),
      ),
    );

    final preview = tester.getSize(
      find.byKey(
        const ValueKey('dashboard-widget-preview-memoryInfo-oneByFour'),
      ),
    );
    expect(preview.height, closeTo(200, .1));
    expect(preview.width, closeTo(40, .1));
  });

  testWidgets('widget previews adapt to narrow and short layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final type in [
      DashboardWidget.networkSpeed,
      DashboardWidget.startButton,
      DashboardWidget.intranetIp,
      DashboardWidget.tunButton,
      DashboardWidget.networkDetection,
      DashboardWidget.outboundMode,
    ]) {
      for (final layout in [
        DashboardWidgetLayout.oneByTwo,
        DashboardWidgetLayout.oneByFour,
        DashboardWidgetLayout.twoByTwo,
        DashboardWidgetLayout.twoByOne,
        DashboardWidgetLayout.fourByOne,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 260,
                  height: 240,
                  child: DashboardWidgetPreview(type: type, layout: layout),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${type.name} at ${layout.label}',
        );
      }
    }
  });
}
