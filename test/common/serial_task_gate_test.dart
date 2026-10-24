import 'dart:async';

import 'package:fluxora/common/function.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('queued calls coalesce into one follow-up and never overlap', () async {
    final gate = SerialTaskGate();
    final first = Completer<void>();
    var runs = 0;
    var active = 0;
    var maxActive = 0;

    Future<void> task() async {
      runs++;
      active++;
      if (active > maxActive) maxActive = active;
      if (runs == 1) await first.future;
      active--;
    }

    final a = gate.run(task);
    final b = gate.run(task);
    final c = gate.run(task);

    expect(runs, 1);
    first.complete();
    await Future.wait([a, b, c]);

    expect(runs, 2);
    expect(maxActive, 1);
  });

  test('a failed task releases the gate for the next run', () async {
    final gate = SerialTaskGate();

    await expectLater(
      gate.run(() async => throw StateError('refresh failed')),
      throwsStateError,
    );

    var ran = false;
    await gate.run(() async {
      ran = true;
    });
    expect(ran, isTrue);
  });
}
