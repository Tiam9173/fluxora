import 'dart:async';
import 'dart:collection';
import 'dart:convert';

// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';

/// Models the native 50-worker delay batch without opening sockets or a core.
class _QueuedCore extends ClashHandlerInterface {
  final _queue = Queue<Action>();
  final budgetsMs = <int>[];
  int active = 0;
  int peak = 0;
  int dispatched = 0;

  @override
  void sendMessage(String message) {
    final action = Action.fromJson(jsonDecode(message));
    if (action.method != ActionMethod.asyncTestDelay) {
      scheduleMicrotask(
        () => handleResult(
          ActionResult(id: action.id, method: action.method, data: true),
        ),
      );
      return;
    }
    dispatched++;
    final data = jsonDecode(action.data as String) as Map<String, dynamic>;
    budgetsMs.add(data['timeout'] as int);
    if ((data['proxy-name'] as String).startsWith('silent-')) {
      return;
    }
    _queue.add(action);
    _drain();
  }

  void _drain() {
    while (active < 50 && _queue.isNotEmpty) {
      final action = _queue.removeFirst();
      active++;
      if (active > peak) peak = active;
      Timer(const Duration(seconds: 4), () {
        active--;
        final data = jsonDecode(action.data as String);
        handleResult(
          ActionResult(
            id: action.id,
            method: action.method,
            data: jsonEncode(
              Delay(
                name: data['proxy-name'],
                url: data['test-url'],
                value: 4000,
              ),
            ),
          ),
        );
        _drain();
      });
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('real request deadlines release slots for queued healthy nodes', () {
    fakeAsync((clock) {
      final core = _QueuedCore();
      var failed = 0;
      for (var i = 0; i < 50; i++) {
        core.asyncTestDelay('https://example.test/204', 'silent-$i').then((
          raw,
        ) {
          if (Delay.fromJson(jsonDecode(raw)).value == -1) failed++;
        });
      }
      Delay? recovered;
      core.asyncTestDelay('https://example.test/204', 'healthy').then((raw) {
        recovered = Delay.fromJson(jsonDecode(raw));
      });
      clock.flushMicrotasks();
      expect(core.dispatched, 50);
      expect(core.budgetsMs, everyElement(10000));
      clock.elapse(const Duration(seconds: 11));
      clock.flushMicrotasks();
      expect(failed, 0);
      // The healthy request only enters the native queue after the first
      // batch's 12-second deadlines, then keeps its own cleanup timer.
      clock.elapse(const Duration(seconds: 14));
      clock.flushMicrotasks();
      expect(failed, 50);
      expect(recovered?.value, 4000);
      expect(core.callbackCompleterMap, isEmpty);
    });
  });

  test('manual probes allow the DNS budget plus a short node handshake', () {
    fakeAsync((clock) {
      final core = _QueuedCore();
      String? result;
      core.asyncTestDelay('https://example.test/204', 'node').then((raw) {
        result = raw;
      });
      clock.flushMicrotasks();
      expect(core.budgetsMs, [10000]);
      clock.elapse(const Duration(seconds: 10));
      clock.flushMicrotasks();
      expect(result, isNotNull);
      expect(Delay.fromJson(jsonDecode(result!)).value, 4000);
    });
  });

  for (final count in [100, 250, 500]) {
    test(
      '$count healthy nodes do not time out while waiting for a native slot',
      () {
        fakeAsync((clock) {
          final core = _QueuedCore();
          final results = <Delay>[];
          for (var i = 0; i < count; i++) {
            core.asyncTestDelay('https://example.test/204', 'node-$i').then((
              raw,
            ) {
              results.add(Delay.fromJson(jsonDecode(raw)));
            });
          }
          clock.flushMicrotasks();
          core.forceGc(); // Control actions must stay independent of the delay queue.
          clock.elapse(const Duration(seconds: 60));
          expect(results, hasLength(count));
          expect(results.every((r) => r.value == 4000), isTrue);
          expect(core.peak, 50);
          expect(core.callbackCompleterMap, isEmpty);
        });
      },
    );
  }
}
