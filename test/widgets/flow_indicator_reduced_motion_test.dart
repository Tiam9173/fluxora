import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/widgets/fluxora/fluxora.dart';

/// Phase 00.6-F10 — `FluxoraFlowIndicator`'s reduced-motion contract.
///
/// The indicator is the one brand component that **loops** while connected, so
/// after the grid's wobble it is the highest-value reduced-motion target. Its
/// guard lives in `_loopDurationFor` (returns `null` under reduced motion, which
/// parks the controller at 0) and until this file it had only been audited
/// statically — `F10-A` recorded it as "guarded but untested", and `F10-C` left
/// it in the not-yet-covered list.
///
/// Observation is `hasScheduledFrame` rather than a painter field: the animation
/// is an `AnimationController.repeat()`, which never settles, so
/// `pumpAndSettle` **times out** while the loop runs. That timeout is exactly the
/// failure mode these tests are built to catch, so it doubles as the assertion.
void main() {
  Future<void> pumpIndicator(
    WidgetTester tester, {
    required FluxoraFlowState state,
    required bool disableAnimations,
  }) async {
    // Drives the real accessibility path: the flag is set on the test platform
    // dispatcher, so `MediaQuery` picks it up the way the OS switch reaches the
    // app in production (no synthetic `MediaQuery` wrapper in the tree).
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: disableAnimations);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FluxoraFlowIndicator(state: state, semanticLabel: 'flow'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('looping states', () {
    testWidgets('connected keeps looping without reduced motion', (
      tester,
    ) async {
      await pumpIndicator(
        tester,
        state: FluxoraFlowState.connected,
        disableAnimations: false,
      );
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('connected stops looping under reduced motion', (tester) async {
      await pumpIndicator(
        tester,
        state: FluxoraFlowState.connected,
        disableAnimations: true,
      );
      // Would time out if the loop were still scheduling frames.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('connecting keeps looping without reduced motion', (
      tester,
    ) async {
      await pumpIndicator(
        tester,
        state: FluxoraFlowState.connecting,
        disableAnimations: false,
      );
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('connecting stops looping under reduced motion', (
      tester,
    ) async {
      await pumpIndicator(
        tester,
        state: FluxoraFlowState.connecting,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('static states', () {
    testWidgets('idle never schedules frames', (tester) async {
      await pumpIndicator(
        tester,
        state: FluxoraFlowState.idle,
        disableAnimations: false,
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('error never schedules frames', (tester) async {
      await pumpIndicator(
        tester,
        state: FluxoraFlowState.error,
        disableAnimations: false,
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('mid-session toggle', () {
    testWidgets('turning reduced motion on stops a running loop', (
      tester,
    ) async {
      await pumpIndicator(
        tester,
        state: FluxoraFlowState.connected,
        disableAnimations: false,
      );
      expect(tester.binding.hasScheduledFrame, isTrue);

      // Same widget type and position, only the MediaQuery flag differs, so the
      // State survives and this exercises `didChangeDependencies` instead of a
      // fresh `initState`.
      await pumpIndicator(
        tester,
        state: FluxoraFlowState.connected,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('turning reduced motion off resumes the loop', (tester) async {
      await pumpIndicator(
        tester,
        state: FluxoraFlowState.connected,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);

      await pumpIndicator(
        tester,
        state: FluxoraFlowState.connected,
        disableAnimations: false,
      );
      expect(tester.binding.hasScheduledFrame, isTrue);
    });
  });

  group('the mark itself survives reduced motion', () {
    testWidgets('reduced motion keeps the indicator on screen', (tester) async {
      await pumpIndicator(
        tester,
        state: FluxoraFlowState.connected,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();

      // Stopping the loop must not remove the brand mark — the state is still
      // communicated, just without motion.
      expect(find.byType(FluxoraFlowIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantic label is preserved under reduced motion', (
      tester,
    ) async {
      await pumpIndicator(
        tester,
        state: FluxoraFlowState.connected,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('flow'), findsOneWidget);
    });
  });
}
