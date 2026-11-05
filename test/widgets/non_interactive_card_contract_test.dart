import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/views/hotkey.dart';
import 'package:fluxora/widgets/card.dart';

/// P10 reality close-out — a surface that has no action must not look like one.
///
/// `CommonCard` decides `isInteractive` from `onPressed != null` and feeds that
/// into both `OutlinedButton.onPressed` and `tapTargetSize`. Passing an empty
/// callback therefore produced an **enabled button that does nothing**: ripple,
/// hover, focus ring and button semantics on a pure label. Passing nothing
/// keeps it inert.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('a card with no action is not an enabled button', (tester) async {
    await tester.pumpWidget(host(const CommonCard(child: Text('label'))));

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(
      button.enabled,
      isFalse,
      reason: 'a card without an action must not advertise a tap',
    );
  });

  testWidgets('a card with an action stays enabled and fires', (tester) async {
    // Control case: proves the assertion above is not passing for the wrong
    // reason (e.g. no button rendered at all).
    var taps = 0;
    await tester.pumpWidget(
      host(CommonCard(onPressed: () => taps++, child: const Text('label'))),
    );

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.enabled, isTrue);

    await tester.tap(find.byType(OutlinedButton));
    expect(taps, 1);
  });

  testWidgets('KeyboardKeyBox is a label, not a button', (tester) async {
    // Regression: this card used to pass `onPressed: () {}`, so every hotkey
    // key rendered as a pressable button that did nothing when tapped.
    await tester.pumpWidget(
      host(const KeyboardKeyBox(keyboardKey: PhysicalKeyboardKey.space)),
    );

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(
      button.enabled,
      isFalse,
      reason: 'a key label must not advertise a tap that does nothing',
    );
  });
}
