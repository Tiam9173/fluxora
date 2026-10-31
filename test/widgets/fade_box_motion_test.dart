import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Reduced Motion for the three scale-based transitions in `fade_box.dart`.
///
/// §10.5 makes reduced motion mandatory and §10.4 forbids large scale changes.
/// These widgets are used all over the app (message manager, backup, dashboard
/// cards, profiles), so they were the biggest unguarded surface:
///
/// | widget | what it played | now, under reduced motion |
/// | --- | --- | --- |
/// | `FadeThroughBox` | fade + 0.92 → 1.0 scale, 300 ms | duration zero |
/// | `FadeScaleBox` | fade + scale, 300 ms | duration zero |
/// | `FadeScaleEnterBox` | 0.70 → 1.00 entrance | controller jumps to its end |
///
/// `FadeBox` is a **pure fade** and is deliberately left alone: opacity alone is
/// not the "displacement / scale / parallax / loop" the spec asks to suppress.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setReducedMotion(WidgetTester tester, {required bool reduce}) {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduce);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
  }

  Widget app(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  /// Opacity of the `FadeTransition` that wraps [text] right now.
  double opacityOf(WidgetTester tester, String text) => tester
      .widget<FadeTransition>(
        find
            .ancestor(of: find.text(text), matching: find.byType(FadeTransition))
            .first,
      )
      .opacity
      .value;

  group('FadeThroughBox', () {
    testWidgets('shows the new child at full opacity under reduced motion', (
      tester,
    ) async {
      setReducedMotion(tester, reduce: true);

      await tester.pumpWidget(app(const FadeThroughBox(child: Text('one'))));
      await tester.pumpAndSettle();

      await tester.pumpWidget(app(const FadeThroughBox(child: Text('two'))));
      await tester.pump();

      expect(
        opacityOf(tester, 'two'),
        1.0,
        reason: 'duration collapses to zero, so there is no ramp to sit on',
      );
      expect(find.text('one'), findsNothing);
    });
  });

  group('FadeScaleBox', () {
    testWidgets('shows the new child at full opacity under reduced motion', (
      tester,
    ) async {
      setReducedMotion(tester, reduce: true);

      await tester.pumpWidget(app(const FadeScaleBox(child: Text('one'))));
      await tester.pumpAndSettle();

      await tester.pumpWidget(app(const FadeScaleBox(child: Text('two'))));
      await tester.pump();

      expect(opacityOf(tester, 'two'), 1.0);
      expect(find.text('one'), findsNothing);
    });
  });

  group('FadeScaleEnterBox', () {
    double scaleOf(WidgetTester tester) => tester
        .widget<ScaleTransition>(
          find
              .descendant(
                of: find.byType(FadeScaleEnterBox),
                matching: find.byType(ScaleTransition),
              )
              .first,
        )
        .scale
        .value;

    testWidgets('enters from 0.70 when motion is allowed', (tester) async {
      setReducedMotion(tester, reduce: false);

      await tester.pumpWidget(app(const FadeScaleEnterBox(child: Text('x'))));
      await tester.pump();

      expect(
        scaleOf(tester),
        lessThan(0.8),
        reason: 'the entrance starts near 0.70 and grows',
      );

      await tester.pumpAndSettle();
      expect(scaleOf(tester), 1.0);
    });

    testWidgets('is already at full scale under reduced motion', (
      tester,
    ) async {
      setReducedMotion(tester, reduce: true);

      await tester.pumpWidget(app(const FadeScaleEnterBox(child: Text('x'))));
      await tester.pump();

      expect(
        scaleOf(tester),
        1.0,
        reason: 'a 30% zoom is exactly what reduced motion suppresses',
      );
    });

    testWidgets('leaves no running controller behind', (tester) async {
      setReducedMotion(tester, reduce: false);

      await tester.pumpWidget(app(const FadeScaleEnterBox(child: Text('x'))));
      await tester.pumpAndSettle();

      // Unmounting must dispose the controller; a live ticker would fail the
      // binding's "no pending timers" check at teardown.
      await tester.pumpWidget(app(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });
}
