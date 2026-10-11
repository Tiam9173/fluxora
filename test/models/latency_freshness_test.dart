import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/latency_freshness.dart';
import 'package:fluxora/models/latency_state.dart';

/// P1.3-C4-Step4 — freshness gate, pure-function level.
///
/// Fully deterministic: `now` is always injected explicitly, so these tests
/// never depend on the wall clock.
///
/// Frozen contract:
///   D-1  trusted ≤ 5 min ｜ degraded 5–30 min ｜ unknown > 30 min / mismatch / missing
///   D-3  degraded = 50 + (raw − 50) × 0.5
///   F-2  unknown ⇒ 50.0
LatencyState _state({
  int latencyMs = 100,
  required DateTime testedAt,
  required String fingerprint,
}) {
  return LatencyState(
    latencyMs: latencyMs,
    scope: LatencyScope.chain,
    source: LatencySource.failover,
    testedAt: testedAt,
    fingerprint: fingerprint,
  );
}

void main() {
  final now = DateTime(2026, 1, 1, 12, 0, 0);
  const fp = 'wifi-home';

  group('LatencyFreshness.evaluate — D-1 thresholds', () {
    test('1. 4 min old + matching fingerprint → trusted', () {
      expect(
        LatencyFreshness.evaluate(
          state: _state(testedAt: now.subtract(const Duration(minutes: 4)), fingerprint: fp),
          now: now,
          currentFingerprint: fp,
        ),
        LatencyFreshness.trusted,
      );
    });

    test('2. exactly 5 min → trusted (D-1 boundary: ≤ 5min)', () {
      expect(
        LatencyFreshness.evaluate(
          state: _state(testedAt: now.subtract(const Duration(minutes: 5)), fingerprint: fp),
          now: now,
          currentFingerprint: fp,
        ),
        LatencyFreshness.trusted,
      );
    });

    test('3. 5 min + 1 s → degraded', () {
      expect(
        LatencyFreshness.evaluate(
          state: _state(
            testedAt: now.subtract(const Duration(minutes: 5, seconds: 1)),
            fingerprint: fp,
          ),
          now: now,
          currentFingerprint: fp,
        ),
        LatencyFreshness.degraded,
      );
    });

    test('4. 10 min old → degraded', () {
      expect(
        LatencyFreshness.evaluate(
          state: _state(testedAt: now.subtract(const Duration(minutes: 10)), fingerprint: fp),
          now: now,
          currentFingerprint: fp,
        ),
        LatencyFreshness.degraded,
      );
    });

    test('5. exactly 30 min → degraded (D-1 boundary: ≤ 30min)', () {
      expect(
        LatencyFreshness.evaluate(
          state: _state(testedAt: now.subtract(const Duration(minutes: 30)), fingerprint: fp),
          now: now,
          currentFingerprint: fp,
        ),
        LatencyFreshness.degraded,
      );
    });

    test('6. 30 min + 1 s → unknown', () {
      expect(
        LatencyFreshness.evaluate(
          state: _state(
            testedAt: now.subtract(const Duration(minutes: 30, seconds: 1)),
            fingerprint: fp,
          ),
          now: now,
          currentFingerprint: fp,
        ),
        LatencyFreshness.unknown,
      );
    });

    test('7. 31 min old → unknown', () {
      expect(
        LatencyFreshness.evaluate(
          state: _state(testedAt: now.subtract(const Duration(minutes: 31)), fingerprint: fp),
          now: now,
          currentFingerprint: fp,
        ),
        LatencyFreshness.unknown,
      );
    });
  });

  group('LatencyFreshness.evaluate — context / missing', () {
    test('8. fingerprint mismatch → unknown (a fresh value on another network)', () {
      expect(
        LatencyFreshness.evaluate(
          state: _state(testedAt: now.subtract(const Duration(minutes: 1)), fingerprint: '4g'),
          now: now,
          currentFingerprint: fp,
        ),
        LatencyFreshness.unknown,
      );
    });

    test('9. null state → unknown', () {
      expect(
        LatencyFreshness.evaluate(state: null, now: now, currentFingerprint: fp),
        LatencyFreshness.unknown,
      );
    });

    test('10. future testedAt (negative age) → trusted, no crash', () {
      expect(
        LatencyFreshness.evaluate(
          state: _state(testedAt: now.add(const Duration(minutes: 1)), fingerprint: fp),
          now: now,
          currentFingerprint: fp,
        ),
        LatencyFreshness.trusted,
      );
    });
  });

  group('LatencyFreshness.rawScore — unchanged legacy formula', () {
    test('11. rawScore(100) → 90', () {
      expect(LatencyFreshness.rawScore(100), 90.0);
    });

    test('12. rawScore(0) → 100', () {
      expect(LatencyFreshness.rawScore(0), 100.0);
    });

    test('13. rawScore(1000) → 0', () {
      expect(LatencyFreshness.rawScore(1000), 0.0);
    });

    test('14. rawScore(2000) → 0 (clamped)', () {
      expect(LatencyFreshness.rawScore(2000), 0.0);
    });
  });

  group('LatencyFreshness.degrade — D-3', () {
    test('15. degrade(90) → 70', () {
      expect(LatencyFreshness.degrade(90), 70.0);
    });

    test('16. degrade(50) → 50 (fixed point)', () {
      expect(LatencyFreshness.degrade(50), 50.0);
    });

    test('17. degrade(0) → 25', () {
      expect(LatencyFreshness.degrade(0), 25.0);
    });

    test('18. degrade(100) → 75', () {
      expect(LatencyFreshness.degrade(100), 75.0);
    });
  });
}
