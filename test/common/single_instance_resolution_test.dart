import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/main.dart';

/// S4 / P9-B2 — the single-instance decision table, lock-first.
///
/// A second launch has exactly three outcomes, and only one of them is a
/// failure. These use fakes so the table is checked without a window, a lock
/// file or a running instance.
///
/// P9-B2 changed the *order*: the lock is now asked first, and the control
/// channel is only consulted when the lock is held. Reading the channel first
/// made every start whose port file was stale pay three one-second timeouts.
void main() {
  Future<bool> Function() probeReturning(bool value, {int throwsFirst = 0}) {
    var calls = 0;
    return () async {
      calls++;
      if (calls <= throwsFirst) throw StateError('probe could not tell');
      return value;
    };
  }

  /// A lock that is busy for [busyCalls] attempts and free afterwards. Models
  /// the restart hand-off: the outgoing process still holds it for a moment.
  Future<bool> Function() lockBusyFor(int busyCalls) {
    var calls = 0;
    return () async {
      calls++;
      return calls > busyCalls;
    };
  }

  Future<SingleInstanceDecision> resolve({
    required Future<bool> Function() probe,
    required Future<bool> Function() acquire,
  }) {
    return resolveSingleInstance(
      probe: probe,
      acquire: acquire,
      acquireDelay: Duration.zero,
      probeDelay: Duration.zero,
    );
  }

  test('a free lock starts without ever touching the control channel', () async {
    var probeCalls = 0;
    final decision = await resolve(
      probe: () async {
        probeCalls++;
        return true;
      },
      acquire: () async => true,
    );

    expect(decision, SingleInstanceDecision.start);
    expect(
      probeCalls,
      0,
      reason: 'the lock is authoritative; a stale port file must cost nothing',
    );
  });

  test('a lock that frees up during the hand-off still starts', () async {
    // The restart case: the outgoing process is inside its teardown when the
    // successor asks, so the first attempts fail and a later one wins.
    var probeCalls = 0;
    final decision = await resolve(
      probe: () async {
        probeCalls++;
        return true;
      },
      acquire: lockBusyFor(3),
    );

    expect(decision, SingleInstanceDecision.start);
    expect(
      probeCalls,
      0,
      reason: 'winning the lock is proof of ownership; no probe is needed',
    );
  });

  test('a held lock hands off to the running instance', () async {
    final decision = await resolve(
      probe: probeReturning(true),
      acquire: () async => false,
    );

    expect(decision, SingleInstanceDecision.surfacedExisting);
  });

  test('nothing answered and the lock is held refuses to start', () async {
    final decision = await resolve(
      probe: probeReturning(false),
      acquire: () async => false,
    );

    expect(
      decision,
      SingleInstanceDecision.blocked,
      reason: 'fail closed: never start a second full instance unlocked',
    );
  });

  test('the lock is re-checked after a silent probe', () async {
    // The holder finished exiting while we were probing: it still held the lock
    // in phase 1, nobody answered, and by phase 3 it is gone. Blocking here
    // would strand a legitimate restart.
    var probeCalls = 0;
    final decision = await resolve(
      probe: () async {
        probeCalls++;
        return false;
      },
      acquire: lockBusyFor(kSingleInstanceAcquireAttempts),
    );

    expect(decision, SingleInstanceDecision.start);
    expect(probeCalls, 1, reason: 'a definitive "not running" is not retried');
  });

  test('a probe that cannot tell is retried before giving up', () async {
    final probe = probeReturning(true, throwsFirst: 2);
    final decision = await resolve(
      probe: probe,
      acquire: () async => false,
    );

    expect(
      decision,
      SingleInstanceDecision.surfacedExisting,
      reason: 'the third attempt answers, so the peer is running',
    );
  });

  test('a probe that never answers falls through to the lock', () async {
    final decision = await resolve(
      probe: probeReturning(false, throwsFirst: 99),
      acquire: () async => true,
    );

    expect(decision, SingleInstanceDecision.start);
  });

  test('a probe that never answers and a held lock fails closed', () async {
    final decision = await resolve(
      probe: probeReturning(false, throwsFirst: 99),
      acquire: () async => false,
    );

    expect(decision, SingleInstanceDecision.blocked);
  });
}
