import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:fluxora/enum/enum.dart';

void main() {
  testWidgets(
    'every configured delay animation runs with low-effects material',
    (tester) async {
      for (final type in DelayAnimationType.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              extensions: const [
                FluxoraMaterial(style: FluxoraSurfaceStyle.reduced),
              ],
            ),
            home: DelayAnimation(type: type, size: 24, color: Colors.indigo),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byIcon(Icons.hourglass_top_rounded), findsNothing);
        if (type != DelayAnimationType.none) {
          expect(tester.hasRunningAnimations, isTrue, reason: type.name);
        }
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  Future<void> chart(
    WidgetTester tester,
    List<Point> points, {
    Duration duration = const Duration(milliseconds: 320),
    bool reduced = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: SizedBox(
            width: 240,
            height: 120,
            child: LineChart(
              points: points,
              color: Colors.indigo,
              duration: duration,
            ),
          ),
        ),
      ),
    ),
  );

  LineChartPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<LineChartPainter>()
      .single;

  const a = [Point(0, 0), Point(1, 10), Point(2, 0)];
  const b = [Point(0, 10), Point(1, 0), Point(2, 10)];

  testWidgets('chart can enable animation after a zero-duration mount', (
    tester,
  ) async {
    await chart(tester, a, duration: Duration.zero);
    await chart(tester, b);
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
    expect(painter(tester).progress, inExclusiveRange(0.0, 1.0));
    await tester.pumpAndSettle();
    expect(painter(tester).progress, 1);
  });

  testWidgets(
    'chart data is immediate under reduced motion, including a mid-tween toggle',
    (tester) async {
      await chart(tester, a);
      await chart(tester, b);
      await tester.pump(const Duration(milliseconds: 80));
      await chart(tester, b, reduced: true);
      expect(painter(tester).progress, 1);
      expect(painter(tester).hasAnimation, isFalse);
      await chart(tester, a, reduced: true);
      expect(painter(tester).points, a);
      expect(painter(tester).progress, 1);
    },
  );

  testWidgets('empty chart remains renderable with motion enabled', (
    tester,
  ) async {
    await chart(tester, const []);
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.takeException(), isNull);
    await chart(tester, a);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('rapid chart samples start from the current painted geometry', (
    tester,
  ) async {
    await chart(tester, a);
    await chart(tester, b);
    await tester.pump(const Duration(milliseconds: 90));
    final prior = painter(tester);
    final visible = prior.getInterpolatePoints(
      prior.prevPoints,
      prior.points,
      prior.progress,
    );
    await chart(tester, a);
    final next = painter(tester);
    final resumed = next.getInterpolatePoints(
      next.prevPoints,
      next.points,
      next.progress,
    );
    for (var i = 0; i < visible.length; i++) {
      expect(resumed[i].x, closeTo(visible[i].x, 0.00001));
      expect(resumed[i].y, closeTo(visible[i].y, 0.00001));
    }
    await tester.pumpAndSettle();
    expect(painter(tester).points, a);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'changing motion preference during navigation hides the old page immediately',
    (tester) async {
      Widget pages(int index, Duration duration) => MaterialApp(
        home: KeptPageView(
          index: index,
          duration: duration,
          inCurve: FluxoraMotion.enter,
          outCurve: FluxoraMotion.exit,
          enterOffset: FluxoraMotion.enterOffset,
          pageBuilder: (_, i) => Text('page-$i'),
        ),
      );
      await tester.pumpWidget(pages(0, FluxoraMotion.base));
      await tester.pumpWidget(pages(1, FluxoraMotion.base));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(pages(1, Duration.zero));
      expect(find.text('page-0'), findsNothing);
      expect(find.text('page-1'), findsOneWidget);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'explicit motion off suppresses transitions independently of material',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [
              FluxoraMaterial(
                style: FluxoraSurfaceStyle.reduced,
                motionStyle: FluxoraMotionStyle.off,
              ),
            ],
          ),
          home: Builder(
            builder: (context) {
              expect(FluxoraMotion.ofContext(context).base, Duration.zero);
              return const FadeBox(child: Text('static'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('static'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
}
