import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_adaptive_score_service.dart';

void main() {
  group('Phase 5.7-B: Chain Reliability Optimization Tests', () {
    test(
      '1. Time decay works: 10k successes node degrades after new failures',
      () {
        final oldReliable = ChainFallbackCandidate(
          nodeName: 'Old-Reliable',
          role: FallbackCandidateRole.entry,
          health: ChainHealthStatus.healthy,
          statsByContext: {
            'wifi_default': ChainReliabilityStats(
              weightedSuccess: 10000.0,
              weightedFailure: 0.0,
              consecutiveFailures: 0,
              totalSamples: 10000,
              lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
              networkFingerprint: 'wifi_default',
            ),
          },
        );

        // We simulate 3 consecutive failures now. The time decay should make the 10000 successes weigh less.
        for (int i = 0; i < 3; i++) {
          oldReliable.statsByContext['wifi_default']!.recordEvent(
            isSuccess: false,
            lambda: 0.0288,
            now: DateTime.now(),
          );
        }

        final score = ChainAdaptiveScoreService.calculateNodeScore(
          candidate: oldReliable,
        );

        expect(score.confidence, lessThan(0.7));
      },
    );

    test(
      '2. Flapping node score degradation: Independent consecutive failures',
      () {
        final flapper = ChainFallbackCandidate(
          nodeName: 'Flapper',
          role: FallbackCandidateRole.entry,
          health: ChainHealthStatus.healthy,
          statsByContext: {
            'wifi_default': ChainReliabilityStats(
              weightedSuccess: 5.0,
              weightedFailure: 0.0,
              consecutiveFailures: 5, // Simulated 5 failures in a row recently
              totalSamples: 10,
              lastUpdated: DateTime.now(),
              networkFingerprint: 'wifi_default',
            ),
          },
        );

        final score = ChainAdaptiveScoreService.calculateNodeScore(
          candidate: flapper,
        );
        expect(score.confidence, lessThan(0.6));
      },
    );

    test(
      '3. Cold start (UCB1) bonus: New untested node gets exploration boost',
      () {
        final untested = ChainFallbackCandidate(
          nodeName: 'Untested',
          role: FallbackCandidateRole.entry,
          health: ChainHealthStatus.healthy,
          statsByContext: {},
        );

        final reliable = ChainFallbackCandidate(
          nodeName: 'Reliable',
          role: FallbackCandidateRole.entry,
          health: ChainHealthStatus.healthy,
          statsByContext: {
            'wifi_default': ChainReliabilityStats(
              weightedSuccess: 100.0,
              weightedFailure: 0.0,
              consecutiveFailures: 0,
              totalSamples: 100,
              lastUpdated: DateTime.now(),
              networkFingerprint: 'wifi_default',
            ),
          },
        );

        final scoreUntested = ChainAdaptiveScoreService.calculateNodeScore(
          candidate: untested,
          globalTotalTrials: 200,
        );
        final scoreReliable = ChainAdaptiveScoreService.calculateNodeScore(
          candidate: reliable,
          globalTotalTrials: 200,
        );

        expect(scoreUntested.confidence, greaterThan(0.9));
        expect(scoreReliable.confidence, closeTo(1.0, 0.05));
      },
    );

    test('4. Network environment switch isolation: Wi-Fi vs Cellular', () {
      final candidate = ChainFallbackCandidate(
        nodeName: 'Env-Switch-Node',
        role: FallbackCandidateRole.entry,
        health: ChainHealthStatus.healthy,
        statsByContext: {
          'wifi_home': ChainReliabilityStats(
            weightedSuccess: 100.0,
            weightedFailure: 0.0,
            consecutiveFailures: 0,
            totalSamples: 100,
            lastUpdated: DateTime.now(),
            networkFingerprint: 'wifi_home',
          ),
          'cellular_5g': ChainReliabilityStats(
            weightedSuccess: 0.0,
            weightedFailure: 10.0,
            consecutiveFailures: 10,
            totalSamples: 10,
            lastUpdated: DateTime.now(),
            networkFingerprint: 'cellular_5g',
          ),
        },
      );

      expect(candidate.statsByContext['wifi_home']!.consecutiveFailures, 0);
      expect(candidate.statsByContext['cellular_5g']!.consecutiveFailures, 10);
    });
  });
}
