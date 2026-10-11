import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/smart_auto_stop_manager.dart';

/// P2.6-A — `SmartAutoStopManager` teardown safety.
///
/// The manager schedules a ~1s debounced network check
/// (`_debouncedCheckCurrentNetwork`). Before P2.6-A that callback stayed live
/// across `dispose()`, so it could run `_checkCurrentNetwork()` against a
/// disposed `ref`. `dispose()` now invalidates the queued checks (the existing
/// `_checkSequence` token) and the callback re-checks `mounted`.
///
/// These tests mount the REAL widget — it is a `ConsumerStatefulWidget`, so
/// teardown cannot be exercised without pumping it.
void main() {
  // The connectivity plugin is an EventChannel: both `listen()` and `cancel()`
  // touch `ServicesBinding.instance`.
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget managerTree() => ProviderScope(
    child: MaterialApp(home: SmartAutoStopManager(child: const SizedBox())),
  );

  Widget emptyTree() =>
      ProviderScope(child: MaterialApp(home: const SizedBox()));

  testWidgets('A. dispose() leaves no live delayed check behind', (tester) async {
    await tester.pumpWidget(managerTree());
    await tester.pump();

    // Tear the manager down, then wait past the 1s debounce window. A callback
    // that survived dispose() would now touch a disposed `ref` and surface as
    // an exception.
    await tester.pumpWidget(emptyTree());
    await tester.pump(const Duration(milliseconds: 1200));

    expect(tester.takeException(), isNull);
  });

  testWidgets('B. repeated mount → dispose cycles stay clean', (tester) async {
    for (var i = 0; i < 2; i++) {
      await tester.pumpWidget(managerTree());
      await tester.pump();

      await tester.pumpWidget(emptyTree());
      await tester.pump(const Duration(milliseconds: 1200));

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('C. the manager renders its child and does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(managerTree());
    await tester.pump();

    expect(find.byType(SmartAutoStopManager), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
