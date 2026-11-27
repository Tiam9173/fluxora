import 'package:fluxora/models/models.dart';
import 'package:fluxora/views/profiles/profiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows member counts and supports large text on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selectedId = '';

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Scaffold(
            body: AggregateSubscriptionSwitcher(
              aggregates: const [
                AggregateProfile(
                  id: 'work',
                  name: 'Work',
                  memberIds: ['a', 'b'],
                ),
                AggregateProfile(id: 'travel', name: 'Travel'),
              ],
              selectedId: 'work',
              enabled: true,
              onSelected: (id) => selectedId = id,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(chips.map((chip) => chip.selected), [true, false]);
    expect(find.text('Work · 2'), findsOneWidget);
    expect(find.text('Travel · 0'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Travel · 0'));
    await tester.pump();
    expect(selectedId, 'travel');
    expect(tester.takeException(), isNull);
  });
}
