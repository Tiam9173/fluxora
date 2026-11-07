import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/views/dashboard/widgets/speed_test_card.dart';

/// Phase 00.6-F10 — `SpeedTestCard`'s reduced-motion contract.
///
/// The arc follows the supplied reading over 320 ms; the numeric reading is
/// immediate. Motion off and the default OS preference suppress the arc tween.
///
/// Opening the card without a running core reads no native status or network.
///
/// What is asserted is the *resolved* `TweenAnimationBuilder.duration` on the
/// live widget, not a source string: that value is exactly what decides whether
/// the headline animates or jumps.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The card reads the process-wide `appLocalizations`.
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  /// Pumps the card on its own, with the OS reduce-motion flag set through the
  /// real platform dispatcher (the same path the accessibility switch takes in
  /// production).
  Future<void> pumpCard(
    WidgetTester tester, {
    required bool disableAnimations,
    bool lowEffects = false,
    FluxoraMotionStyle motionStyle = FluxoraMotionStyle.system,
  }) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: disableAnimations);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await tester.pumpWidget(
      MaterialApp(
        themeAnimationDuration: Duration.zero,
        theme: ThemeData(
          extensions: [
            FluxoraMaterial(
              motionStyle: motionStyle,
              style: lowEffects
                  ? FluxoraSurfaceStyle.reduced
                  : FluxoraSurfaceStyle.classic,
            ),
          ],
        ),
        home: const Scaffold(body: SpeedTestCard()),
      ),
    );
    // Let `_syncOnce()` resolve; it completes synchronously against the absent
    // native lib.
    await tester.pump();
  }

  Duration headlineTweenDuration(WidgetTester tester) {
    final tween = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>),
    );
    return tween.duration;
  }

  testWidgets('the arc tweens over 320 ms without reduced motion', (
    tester,
  ) async {
    await pumpCard(tester, disableAnimations: false);

    expect(headlineTweenDuration(tester), const Duration(milliseconds: 320));
  });

  testWidgets('low-effects material keeps the chosen arc motion', (
    tester,
  ) async {
    await pumpCard(tester, disableAnimations: false, lowEffects: true);
    await tester.pumpAndSettle();
    expect(headlineTweenDuration(tester), const Duration(milliseconds: 320));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the headline lands immediately under reduced motion', (
    tester,
  ) async {
    await pumpCard(tester, disableAnimations: true);

    expect(headlineTweenDuration(tester), Duration.zero);
  });

  testWidgets('reduced motion still renders the card', (tester) async {
    await pumpCard(tester, disableAnimations: true);
    await tester.pumpAndSettle();

    expect(find.byType(SpeedTestCard), findsOneWidget);
    // The card's own title proves the tree built past the tween.
    expect(find.byKey(const ValueKey('speed-test-start')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion leaves no frame scheduled', (tester) async {
    await pumpCard(tester, disableAnimations: true);
    // A zero-duration tween settles in one frame; anything still scheduled
    // would mean a loop survived the flag.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('toggling reduced motion mid-session re-resolves the tween', (
    tester,
  ) async {
    await pumpCard(tester, disableAnimations: false);
    expect(headlineTweenDuration(tester), const Duration(milliseconds: 320));

    // Same widget type and position, only the MediaQuery flag differs, so the
    // State survives and `build` re-reads `MediaQuery.disableAnimations`.
    await pumpCard(tester, disableAnimations: true);
    expect(headlineTweenDuration(tester), Duration.zero);
  });

  testWidgets('explicit fluid motion and off work independently of the OS', (
    tester,
  ) async {
    await pumpCard(
      tester,
      disableAnimations: true,
      motionStyle: FluxoraMotionStyle.fluid,
    );
    expect(headlineTweenDuration(tester), const Duration(milliseconds: 400));
    await pumpCard(
      tester,
      disableAnimations: false,
      motionStyle: FluxoraMotionStyle.off,
    );
    expect(headlineTweenDuration(tester), Duration.zero);
  });
}
