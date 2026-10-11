import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/latency_state.dart';
import 'package:fluxora/services/chain_adaptive_score_service.dart';
import 'package:fluxora/services/network_fingerprint_provider.dart';

/// P1.3-C4-Step4 — freshness gate, score-entry level.
///
/// The two code paths are asserted **separately** and must never be conflated:
///
///   group 1 — gated path  (`chainLatency != null`)  → freshness decides
///   group 2 — β path      (`chainLatency == null`)  → legacy shim, bit-identical
///
/// `-1` yields 50 on **both** paths, but for a different reason (new `< 0` guard
/// vs the legacy `>= 0` guard) — hence two independent cases.
///
/// `now` is injected on every call, so nothing here depends on the wall clock.
void main() {
  final now = DateTime(2026, 1, 1, 12, 0, 0);
  final currentFp = networkFingerprintProvider.getCurrentFingerprint();

  /// A candidate that **carries** a structured chain-scope observation.
  ChainFallbackCandidate gated({
    required int latencyMs,
    required DateTime testedAt,
    String? fingerprint,
  }) {
    return ChainFallbackCandidate(
      nodeName: 'node',
      role: FallbackCandidateRole.exit,
      chainLatency: LatencyState(
        latencyMs: latencyMs,
        scope: LatencyScope.chain,
        source: LatencySource.failover,
        testedAt: testedAt,
        fingerprint: fingerprint ?? currentFp,
      ),
    );
  }

  /// A candidate with **no** structured state — the β compat shape, which is
  /// exactly what every pre-Step4 test fixture looks like.
  ChainFallbackCandidate beta({int? latencyMs}) {
    return ChainFallbackCandidate(
      nodeName: 'node',
      role: FallbackCandidateRole.exit,
      latencyMs: latencyMs,
    );
  }

  double latencyScoreOf(ChainFallbackCandidate candidate) {
    return ChainAdaptiveScoreService.calculateNodeScore(
      candidate: candidate,
      now: now,
    ).latencyScore;
  }

  group('Step4 — gated path (chainLatency != null)', () {
    test('A. trusted (4 min) → raw score 90', () {
      expect(
        latencyScoreOf(
          gated(
            latencyMs: 100,
            testedAt: now.subtract(const Duration(minutes: 4)),
          ),
        ),
        90.0,
      );
    });

    test('B. degraded (10 min) → 50 + (90 − 50) × 0.5 = 70', () {
      expect(
        latencyScoreOf(
          gated(
            latencyMs: 100,
            testedAt: now.subtract(const Duration(minutes: 10)),
          ),
        ),
        70.0,
      );
    });

    test('C. unknown (31 min) → neutral 50', () {
      expect(
        latencyScoreOf(
          gated(
            latencyMs: 100,
            testedAt: now.subtract(const Duration(minutes: 31)),
          ),
        ),
        50.0,
      );
    });

    test('D. fingerprint mismatch → neutral 50', () {
      expect(
        latencyScoreOf(
          gated(
            latencyMs: 100,
            testedAt: now.subtract(const Duration(minutes: 1)),
            fingerprint: 'some-other-network',
          ),
        ),
        50.0,
      );
    });

    test('H. negative latency → neutral 50 (new < 0 guard)', () {
      expect(
        latencyScoreOf(
          gated(
            latencyMs: -1,
            testedAt: now.subtract(const Duration(minutes: 1)),
          ),
        ),
        50.0,
      );
    });

    test('H2. zero latency → 100 (keeps the legacy quirk, same rawScore)', () {
      expect(
        latencyScoreOf(
          gated(
            latencyMs: 0,
            testedAt: now.subtract(const Duration(minutes: 1)),
          ),
        ),
        100.0,
      );
    });
  });

  group('Step4 — β compat path (chainLatency == null)', () {
    test('E. latencyMs 100 → 90 (bit-identical to pre-Step4)', () {
      expect(latencyScoreOf(beta(latencyMs: 100)), 90.0);
    });

    test('F. latencyMs null → 50 (bit-identical to pre-Step4)', () {
      expect(latencyScoreOf(beta()), 50.0);
    });

    test('G. latencyMs -1 → 50 (legacy >= 0 guard, NOT the new one)', () {
      expect(latencyScoreOf(beta(latencyMs: -1)), 50.0);
    });

    test('G2. latencyMs 0 → 100 (bit-identical to pre-Step4)', () {
      expect(latencyScoreOf(beta(latencyMs: 0)), 100.0);
    });

    test('G3. latencyMs 1000 → 0 (bit-identical to pre-Step4)', () {
      expect(latencyScoreOf(beta(latencyMs: 1000)), 0.0);
    });

    test('G4. latencyMs 2000 → 0 (clamped, bit-identical to pre-Step4)', () {
      expect(latencyScoreOf(beta(latencyMs: 2000)), 0.0);
    });
  });
}
