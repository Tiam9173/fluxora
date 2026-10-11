import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/latency_freshness.dart';
import 'package:fluxora/models/latency_state.dart';

/// P1.3-C4-Step5 — the UI visibility rule (`LatencyFreshness.visibleLatencyMs`).
///
/// Decision Q3: a `trusted` **or** `degraded` node latency is shown at its raw
/// value — D-3's down-weighting is a *scoring* rule and must never change the
/// number the user reads. Everything unusable collapses to `null` (the card
/// already has a "unknown" branch), and nothing is ever back-filled from
/// `chainLatency`.
///
/// `now` is injected explicitly, so these tests never depend on the wall clock.
void main() {
  final now = DateTime(2026, 1, 1, 12, 0, 0);
  const fp = 'wifi-home';

  LatencyState state({
    int latencyMs = 100,
    required DateTime testedAt,
    required String fingerprint,
    LatencyScope scope = LatencyScope.node,
  }) {
    return LatencyState(
      latencyMs: latencyMs,
      scope: scope,
      source: LatencySource.failover,
      testedAt: testedAt,
      fingerprint: fingerprint,
    );
  }

  int? visible(
    LatencyState? s, {
    LatencyScope? expectedScope = LatencyScope.node,
  }) {
    return LatencyFreshness.visibleLatencyMs(
      state: s,
      now: now,
      currentFingerprint: fp,
      expectedScope: expectedScope,
    );
  }

  group('LatencyFreshness.visibleLatencyMs — Step5 UI rule', () {
    test('B1. trusted (4 min) → raw node latency', () {
      expect(
        visible(state(testedAt: now.subtract(const Duration(minutes: 4)), fingerprint: fp)),
        100,
      );
    });

    test('B2. degraded (10 min) → raw node latency (Q3: display is not scored)', () {
      expect(
        visible(state(testedAt: now.subtract(const Duration(minutes: 10)), fingerprint: fp)),
        100,
        reason: 'D-3 down-weights the SCORE only; the shown value stays raw',
      );
    });

    test('B3. stale (31 min) → null (unknown, never a fabricated number)', () {
      expect(
        visible(state(testedAt: now.subtract(const Duration(minutes: 31)), fingerprint: fp)),
        isNull,
      );
    });

    test('B4. fingerprint mismatch → null (a foreign network reading)', () {
      expect(
        visible(state(testedAt: now.subtract(const Duration(minutes: 1)), fingerprint: '4g')),
        isNull,
      );
    });

    test('B5. missing node latency → null (no fallback to chainLatency)', () {
      expect(visible(null), isNull);
    });

    test('B6. wrong scope (a chain-scope object) → null (Q6 guard)', () {
      expect(
        visible(
          state(
            testedAt: now.subtract(const Duration(minutes: 1)),
            fingerprint: fp,
            scope: LatencyScope.chain, // ← passing the chain object by mistake
          ),
        ),
        isNull,
        reason: 'a chain total must never be read as a node latency',
      );
    });
  });
}
