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
  Future<int Function()> pumpGrid(
    WidgetTester tester, {
    required bool withHandle,
  }) async {
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
    // `pumpAndSettle` never returns here: `SuperGrid` runs a continuous shake
    // animation, so the frame queue is never empty. Pump a fixed number of
    // frames instead.
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
}
