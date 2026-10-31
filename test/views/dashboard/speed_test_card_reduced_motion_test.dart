import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/views/dashboard/widgets/speed_test_card.dart';

/// Phase 00.6-F10 — `SpeedTestCard`'s reduced-motion contract.
///
/// The card tweens its headline number from the previous frame to the current
/// one over 320 ms. Under reduced motion that tween must collapse to zero so the
/// number lands immediately instead of sliding (`D4_BRAND_PROJECT` §10.5).
///
/// The card is reachable in a VM test because `speedTestStatus()` degrades
/// safely: `speedTestStatusRaw()` returns `'not-lib-handler'` when the native
/// lib is absent, `jsonDecode` throws, and the catch returns a default
/// `SpeedTestProgress` — so no bridge call, timer or watchdog is left pending.
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
  }) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: disableAnimations);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SpeedTestCard())),
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

  testWidgets('the headline tweens over 320 ms without reduced motion', (
    tester,
  ) async {
    await pumpCard(tester, disableAnimations: false);

    expect(headlineTweenDuration(tester), const Duration(milliseconds: 320));
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
    expect(find.text(appLocalizations.networkSpeed), findsOneWidget);
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
}
