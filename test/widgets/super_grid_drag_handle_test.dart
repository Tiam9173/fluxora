import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/widgets/widgets.dart';

/// item 6 — `SuperGrid`'s optional drag handle.
///
/// The point of the handle is that the **card keeps its own gestures**: without
/// it the card is wrapped in an `AbsorbPointer` and is itself the drag source, so
/// a host whose cards have a tap or a long-press would lose them. The profiles
/// grid is that host — its long-press opens the subscription editor.
///
/// These tests pin the observable behaviour (does a tap on the card content
/// arrive?) rather than the `AbsorbPointer` itself, so a refactor that keeps the
/// behaviour still passes.
void main() {
  /// Pumps a one-item grid, optionally with a handle, and reports how many times
  /// the card's own tap fired.
  ///
  /// [disableAnimations] drives the real accessibility path: it is set on the
  /// test platform dispatcher, so `MediaQuery` picks it up exactly the way the OS
  /// switch reaches the app in production (no synthetic `MediaQuery` in the tree).
  Future<int Function()> pumpGrid(
    WidgetTester tester, {
    required bool withHandle,
    bool disableAnimations = false,
  }) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: disableAnimations);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: SuperGrid(
              crossAxisCount: 1,
              dragHandleBuilder: withHandle
                  ? (index) => const SizedBox(
                      width: 24,
                      height: 24,
                      child: Text('handle'),
                    )
                  : null,
              children: [
                GridItem(
                  key: const ValueKey('a'),
                  child: GestureDetector(
                    onTap: () => taps++,
                    child: const SizedBox(
                      width: 200,
                      height: 100,
                      child: Text('card'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // `pumpAndSettle` never returns with the wobble running: `SuperGrid` keeps
    // scheduling frames, so the frame queue is never empty. Pump a fixed number
    // of frames instead — the reduced-motion tests call `pumpAndSettle` on
    // purpose, because that is exactly what proves the loop stopped.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return () => taps;
  }

  testWidgets('without a handle the card is inert (original behaviour)', (
    tester,
  ) async {
    // Documented on purpose: this is what the dashboard relies on, and it is why
    // the handle has to exist at all. If this ever starts passing as `1`, the
    // dashboard's interaction model changed.
    final taps = await pumpGrid(tester, withHandle: false);
    await tester.tap(find.text('card'), warnIfMissed: false);
    await tester.pump();
    expect(taps(), 0);
  });

  testWidgets('with a handle the card still receives taps', (tester) async {
    final taps = await pumpGrid(tester, withHandle: true);
    await tester.tap(find.text('card'), warnIfMissed: false);
    await tester.pump();
    expect(taps(), 1);
  });

  testWidgets('the handle is rendered in handle mode', (tester) async {
    await pumpGrid(tester, withHandle: true);
    expect(find.text('handle'), findsOneWidget);
  });

  testWidgets('no handle is rendered without the builder', (tester) async {
    await pumpGrid(tester, withHandle: false);
    expect(find.text('handle'), findsNothing);
  });

  // ── §10.5 reduced motion ───────────────────────────────────────────────────
  //
  // The wobble is `.repeat()`-driven, and `AnimationController` only shortens
  // *one-shot* animations under `disableAnimations` — a looping controller keeps
  // running at full speed. These tests therefore assert the loop itself stops,
  // using the frame queue as the observable rather than a screenshot.

  testWidgets('reduced motion stops the wobble loop', (tester) async {
    await pumpGrid(tester, withHandle: false, disableAnimations: true);
    // Would time out if the loop were still scheduling frames.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('the wobble keeps running without reduced motion', (tester) async {
    await pumpGrid(tester, withHandle: false, disableAnimations: false);
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('reduced motion keeps the card inert without a handle', (
    tester,
  ) async {
    final taps = await pumpGrid(
      tester,
      withHandle: false,
      disableAnimations: true,
    );
    await tester.tap(find.text('card'), warnIfMissed: false);
    await tester.pump();
    expect(taps(), 0);
  });

  testWidgets('toggling reduce motion mid-session stops the wobble', (
    tester,
  ) async {
    await pumpGrid(tester, withHandle: false, disableAnimations: false);
    expect(tester.binding.hasScheduledFrame, isTrue);

    // Same tree, only the MediaQuery flag differs: the State is preserved, so
    // this exercises `didChangeDependencies` rather than a fresh `initState`.
    await pumpGrid(tester, withHandle: false, disableAnimations: true);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('handle mode is unaffected by reduced motion', (tester) async {
    final taps = await pumpGrid(
      tester,
      withHandle: true,
      disableAnimations: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('handle'), findsOneWidget);
    await tester.tap(find.text('card'), warnIfMissed: false);
    await tester.pump();
    expect(taps(), 1);
  });
}
