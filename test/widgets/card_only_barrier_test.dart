import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Characterisation test for the card-only barrier in `application.dart`.
///
/// Card-only mode builds the card inside a full-screen opaque `GestureDetector`
/// whose `onTap` closes the card; closing calls `closeCardActivity` →
/// `finishAndRemoveTask`, so a stray close looks like "the app quit". That made
/// the barrier the obvious suspect for "tapping the card closes the app".
///
/// It is **not** the cause. `Material` does hit-test its own area, so the inner
/// detector — even with the default `HitTestBehavior.deferToChild` — already
/// swallows taps that land on the card. These cases pin that down so the next
/// investigation does not "fix" the barrier again and call it done.
///
/// The real defect lives in the native switch card
/// (`SwitchCardActivity.btn_profiles`), which finished its own task before the
/// app had come up.
void main() {
  const cardKey = Key('card-body');

  /// Mirrors `application.dart`'s card-only branch, minus the real card.
  Widget host({
    required VoidCallback onClose,
    required HitTestBehavior innerBehavior,
  }) {
    return MaterialApp(
      home: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: Center(
            child: GestureDetector(
              behavior: innerBehavior,
              onTap: () {},
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                color: Colors.white,
                child: const SizedBox(
                  key: cardKey,
                  width: 200,
                  height: 100,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final behavior in [
    HitTestBehavior.deferToChild,
    HitTestBehavior.opaque,
  ]) {
    testWidgets('a tap on the card never closes it (inner: $behavior)', (
      tester,
    ) async {
      var closed = 0;
      await tester.pumpWidget(
        host(onClose: () => closed++, innerBehavior: behavior),
      );

      await tester.tapAt(tester.getCenter(find.byKey(cardKey)));
      await tester.pump();

      expect(closed, 0, reason: 'the card must swallow its own taps');
    });
  }

  testWidgets('tapping outside the card still closes it', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      host(
        onClose: () => closed++,
        innerBehavior: HitTestBehavior.deferToChild,
      ),
    );

    // Top-left corner: outside the centred 200x100 card.
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();

    expect(closed, 1, reason: 'tap-outside-to-dismiss must survive');
  });
}
