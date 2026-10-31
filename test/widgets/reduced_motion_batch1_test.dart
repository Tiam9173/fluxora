import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Phase 04.1 — first batch of Reduced Motion wiring.
///
/// Six files were audited. Four have an observable, mountable component and are
/// covered behaviourally here. The other two are **not** covered by this file:
///
/// * `lib/widgets/line_chart.dart` — already has a deliberate contract pinned by
///   `chart_reduced_motion_test.dart` ("a new point set must restart the
///   tween" even under reduced motion), and no production call site passes a
///   `duration`, so there is no user-facing animation to guard. Left untouched.
/// * `lib/views/proxies/tab.dart` — its two paths live inside
///   `ConsumerStatefulWidget`s that read `delayTestCoordinator` and the proxy
///   providers at `initState`; recorded as code-verified only rather than
///   mounted through a synthetic shell.
///
/// Every assertion is about **what the user sees**: the animated value at a
/// given frame, or whether any animation is still running. None of them reads a
/// `duration` field — a test that only checks `duration == Duration.zero` would
/// pass even if the controller were never rebuilt.
///
/// The reduced-motion switch is driven through
/// `platformDispatcher.accessibilityFeaturesTestValue`, i.e. the same path the
/// OS setting takes into `MediaQuery.disableAnimations` in production. No
/// synthetic `MediaQuery` is injected into the tree.
void main() {
  Future<void> setReduceMotion(WidgetTester tester, bool reduce) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduce);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
  }

  /// The scale the `AnimatedScale` is *currently painting* (not its target).
  double paintedScale(WidgetTester tester) => tester
      .widget<ScaleTransition>(
        find.descendant(
          of: find.byType(AnimatedScale),
          matching: find.byType(ScaleTransition),
        ),
      )
      .scale
      .value;

  group('EffectGestureDetector press-shrink', () {
    Future<void> pumpDetector(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EffectGestureDetector(
                onLongPress: () {},
                child: const SizedBox(width: 120, height: 60, child: Text('t')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    /// Holds long enough for `onLongPressStart`, then advances [afterMs].
    Future<void> press(WidgetTester tester, {required int afterMs}) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('t')),
      );
      addTearDown(gesture.up);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      await tester.pump(Duration(milliseconds: afterMs));
    }

    testWidgets('motion allowed: the shrink is still ramping', (tester) async {
      await setReduceMotion(tester, false);
      await pumpDetector(tester);
      await press(tester, afterMs: 40);

      final scale = paintedScale(tester);
      expect(scale, lessThan(1.0), reason: 'the press is visible');
      expect(
        scale,
        greaterThan(0.95),
        reason: 'and it is mid-tween, not already at the target',
      );
    });

    testWidgets('reduced: the shrink lands in one frame', (tester) async {
      await setReduceMotion(tester, true);
      await pumpDetector(tester);
      await press(tester, afterMs: 0);

      expect(
        paintedScale(tester),
        0.95,
        reason: 'state kept, ramp removed — the finger is the feedback',
      );
      // Stricter than "it arrives eventually": Flutter already shortens a
      // 200 ms implicit animation to 5 % (measured: 10 ms) under
      // `disableAnimations`, which is why the scale alone cannot tell a guarded
      // build from an unguarded one. A zero duration means no ticker at all.
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: 'exactly zero, not the framework 5 % (10 ms)',
      );
    });
  });

  group('CommonExpandIcon flip', () {
    Future<void> pumpIcon(WidgetTester tester, {required bool expand}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: CommonExpandIcon(expand: expand)),
          ),
        ),
      );
      await tester.pump();
    }

    // Scoped: `MaterialApp` puts its own `RotationTransition`s in the tree.
    double turns(WidgetTester tester) => tester
        .widget<RotationTransition>(
          find
              .descendant(
                of: find.byType(CommonExpandIcon),
                matching: find.byType(RotationTransition),
              )
              .first,
        )
        .turns
        .value;

    testWidgets('motion allowed: the chevron rotates over time', (tester) async {
      await setReduceMotion(tester, false);
      await pumpIcon(tester, expand: false);
      expect(turns(tester), 0.0);

      await pumpIcon(tester, expand: true);
      await tester.pump(const Duration(milliseconds: 60));

      expect(turns(tester), greaterThan(0.0));
      expect(
        turns(tester),
        lessThan(0.5),
        reason: 'half a turn is the target; 60 ms of 200 ms is not there yet',
      );

      await tester.pumpAndSettle();
      expect(turns(tester), 0.5);
    });

    testWidgets('reduced: the chevron is already flipped', (tester) async {
      await setReduceMotion(tester, true);
      await pumpIcon(tester, expand: false);

      await pumpIcon(tester, expand: true);
      await tester.pump();

      expect(turns(tester), 0.5, reason: 'same final state, no sweep');
    });
  });

  group('CommonTabBar thumb', () {
    Future<void> pumpBar(WidgetTester tester, int value) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: CommonTabBar<int>(
                  groupValue: value,
                  onValueChanged: (_) {},
                  thumbColor: Colors.teal,
                  children: const {0: Text('one'), 1: Text('two')},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('motion allowed: the thumb slides', (tester) async {
      await setReduceMotion(tester, false);
      await pumpBar(tester, 0);
      await tester.pumpAndSettle();

      await pumpBar(tester, 1);
      await tester.pump();

      expect(
        tester.hasRunningAnimations,
        isTrue,
        reason: 'the spring is still moving the thumb',
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced: the thumb is already in place', (tester) async {
      await setReduceMotion(tester, true);
      await pumpBar(tester, 0);
      await tester.pumpAndSettle();

      await pumpBar(tester, 1);
      await tester.pump();

      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: 'selection still changes, the slide does not',
      );
    });
  });

  group('showModalSideSheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showModalSideSheet<void>(
                    context: context,
                    builder: (_) => const SizedBox(
                      width: 300,
                      child: Text('sheet-body'),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
    }

    testWidgets('motion allowed: the panel travels in', (tester) async {
      await setReduceMotion(tester, false);
      await openSheet(tester);

      final first = tester.getTopLeft(find.text('sheet-body'));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getTopLeft(find.text('sheet-body'));
      await tester.pumpAndSettle();
      final settled = tester.getTopLeft(find.text('sheet-body'));

      expect(
        mid.dx,
        isNot(settled.dx),
        reason: 'the panel is still sliding at 100 ms',
      );
      expect(
        first.dx,
        isNot(settled.dx),
        reason: 'and it started off-screen',
      );
    });

    testWidgets('reduced: the panel is already at its resting place', (
      tester,
    ) async {
      await setReduceMotion(tester, true);
      await openSheet(tester);

      final first = tester.getTopLeft(find.text('sheet-body'));
      await tester.pumpAndSettle();
      final settled = tester.getTopLeft(find.text('sheet-body'));

      expect(
        first.dx,
        settled.dx,
        reason: 'no travel — the sheet appears where it belongs',
      );
    });
  });
}
