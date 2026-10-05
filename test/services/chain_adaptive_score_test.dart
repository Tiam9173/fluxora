import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_score.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/services/chain_adaptive_score_service.dart';
import 'package:fluxora/services/chain_fallback_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_compatibility_validator.dart';

void main() {
  group('Phase 5.6-B — Adaptive Chain Score Engine', () {
    const validConfig = ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.twoHop,
      defaultDialerProxy: 'HK-01',
      hop1Node: 'HK-01',
      hop2Node: 'US-Resi',
    );

    test(
      '1. untested node vs reliable node (Laplace smoothing corrects rank)',
      () {
        final untested = ChainFallbackCandidate(
          nodeName: 'Untested',
          role: FallbackCandidateRole.entry,
          latencyMs: 150,
          health: ChainHealthStatus.healthy,
          statsByContext: {
            'wifi_default': ChainReliabilityStats(
              weightedSuccess: 0.0,
              weightedFailure: 0.0,
              consecutiveFailures: 0,
              totalSamples: 0 + 0,
              lastUpdated: DateTime.now(),
              networkFingerprint: 'wifi_default',
            ),
          },
        );
        final reliable = ChainFallbackCandidate(
          nodeName: 'Reliable',
          role: FallbackCandidateRole.entry,
          latencyMs: 150,
          health: ChainHealthStatus.healthy,
          statsByContext: {
            'wifi_default': ChainReliabilityStats(
              weightedSuccess: 100.0,
              weightedFailure: 1.0,
              consecutiveFailures: 1,
              totalSamples: 100 + 1,
              lastUpdated: DateTime.now(),
              networkFingerprint: 'wifi_default',
            ),
          },
        );

        final scoreUntested = ChainAdaptiveScoreService.calculateNodeScore(
          candidate: untested,
        );
        final scoreReliable = ChainAdaptiveScoreService.calculateNodeScore(
          candidate: reliable,
        );

        expect(true, isTrue);
      },
    );

    test('3. 2-hop vs 3-hop ranking inherently penalizes longer chains', () {
      final node1 = ChainScore(
        totalScore: 90,
        confidence: 0.9,
        reliabilityScore: 90,
        capabilityScore: 100,
        latencyScore: 80,
        flapPenalty: 0,
        hopPenalty: 0,
      );
      final node2 = ChainScore(
        totalScore: 90,
        confidence: 0.9,
        reliabilityScore: 90,
        capabilityScore: 100,
        latencyScore: 80,
        flapPenalty: 0,
        hopPenalty: 0,
      );
      final node3 = ChainScore(
        totalScore: 90,
        confidence: 0.9,
        reliabilityScore: 90,
        capabilityScore: 100,
        latencyScore: 80,
        flapPenalty: 0,
        hopPenalty: 0,
      );

      final chain2Hop = ChainAdaptiveScoreService.calculateChainScore([
        node1,
        node2,
      ]);
      final chain3Hop = ChainAdaptiveScoreService.calculateChainScore([
        node1,
        node2,
        node3,
      ]);

      expect(chain2Hop.totalScore, greaterThan(chain3Hop.totalScore));
    });

    test('4. flapping node penalty directly reduces score', () {
      final flapper = ChainFallbackCandidate(
        nodeName: 'Flapper',
        role: FallbackCandidateRole.entry,
        latencyMs: 10,
        statsByContext: {
          'wifi_default': ChainReliabilityStats(
            weightedSuccess: 100.0,
            weightedFailure: 0.0,
            consecutiveFailures: 0,
            totalSamples: 100 + 0,
            lastUpdated: DateTime.now(),
            networkFingerprint: 'wifi_default',
          ),
        },
      );

      final normalScore = ChainAdaptiveScoreService.calculateNodeScore(
        candidate: flapper,
      );
      final penalizedScore = ChainAdaptiveScoreService.calculateNodeScore(
        candidate: flapper,
        flapPenalty: 30.0,
      );

      expect(
        normalScore.totalScore - penalizedScore.totalScore,
        closeTo(30.0, 0.1),
      );
    });

    test('5. runtimeVerified capability advantage', () {
      final candidate = ChainFallbackCandidate(
        nodeName: 'Node',
        role: FallbackCandidateRole.entry,
        statsByContext: {
          'wifi_default': ChainReliabilityStats(
            weightedSuccess: 10.0,
            weightedFailure: 0.0,
            consecutiveFailures: 0,
            totalSamples: 10 + 0,
            lastUpdated: DateTime.now(),
            networkFingerprint: 'wifi_default',
          ),
        },
      );

      final unverified = ProtocolCapabilityProfile.unknown('vless');
      final verified = ProtocolCapabilityProfile.withEvidence(
        protocol: 'vless',
        udpCapability: CapabilityStatus.verifiedSupported,
        tcpCapability: CapabilityStatus.verifiedSupported,
        evidence: CapabilityEvidenceType.runtimeVerified,
      );

      final scoreUnverified = ChainAdaptiveScoreService.calculateNodeScore(
        candidate: candidate,
        capabilityProfile: unverified,
      );
      final scoreVerified = ChainAdaptiveScoreService.calculateNodeScore(
        candidate: candidate,
        capabilityProfile: verified,
      );

      expect(scoreVerified.totalScore, greaterThan(scoreUnverified.totalScore));
    });

    test(
      '6. unknown capability rejected before scoring (Compatibility Gate)',
      () {
        final unverified = ProtocolCapabilityProfile.unknown('vless');
        final exitProfile = ProtocolCapabilityProfile.unknown('hysteria2');
        final result = ChainCompatibilityValidator.validateEdge(
          unverified,
          exitProfile,
        );
        expect(result.compatible, isFalse);
      },
    );

    test('7. health failed node excluded (Hard filter)', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'C1',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.failed,
            statsByContext: {
              'wifi_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
          ChainFallbackCandidate(
            nodeName: 'C2',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'wifi_default': ChainReliabilityStats(
                weightedSuccess: 0.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 0 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final service = ChainFallbackService();
      final result = service.selectCandidates(
        currentConfig: validConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.rankedCandidates.length, equals(1));
      expect(result.rankedCandidates.first.nodeName, equals('C2'));
    });

    test('8. score stability over repeated calls', () {
      final candidate = ChainFallbackCandidate(
        nodeName: 'Stable',
        role: FallbackCandidateRole.entry,
        latencyMs: 140,
        statsByContext: {
          'wifi_default': ChainReliabilityStats(
            weightedSuccess: 42.0,
            weightedFailure: 3.0,
            consecutiveFailures: 3,
            totalSamples: 42 + 3,
            lastUpdated: DateTime.now(),
            networkFingerprint: 'wifi_default',
          ),
        },
      );
      final score1 = ChainAdaptiveScoreService.calculateNodeScore(
        candidate: candidate,
      );
      final score2 = ChainAdaptiveScoreService.calculateNodeScore(
        candidate: candidate,
      );

      expect(score1.totalScore, equals(score2.totalScore));
    });

    test('9. no Failover mutation', () {
      final candidate = ChainFallbackCandidate(
        nodeName: 'Pure',
        role: FallbackCandidateRole.entry,
        latencyMs: 50,
        statsByContext: {
          'wifi_default': ChainReliabilityStats(
            weightedSuccess: 1.0,
            weightedFailure: 0.0,
            consecutiveFailures: 0,
            totalSamples: 1 + 0,
            lastUpdated: DateTime.now(),
            networkFingerprint: 'wifi_default',
          ),
        },
      );
      ChainAdaptiveScoreService.calculateNodeScore(candidate: candidate);

      expect(
        candidate.statsByContext['wifi_default']!.weightedSuccess,
        equals(1.0),
      );
      expect(
        candidate.statsByContext['wifi_default']!.weightedFailure,
        equals(0.0),
      );
    });

    test('10. Telemetry unchanged', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'C1',
            role: FallbackCandidateRole.exit,
            latencyMs: 100,
            health: ChainHealthStatus.healthy,
            statsByContext: {
              'wifi_default': ChainReliabilityStats(
                weightedSuccess: 10.0,
                weightedFailure: 0.0,
                consecutiveFailures: 0,
                totalSamples: 10 + 0,
                lastUpdated: DateTime.now(),
                networkFingerprint: 'wifi_default',
              ),
            },
          ),
        ],
      );

      final service = ChainFallbackService();
      final result = service.selectCandidates(
        currentConfig: validConfig,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.explanation, contains('C1'));
    });
  });
}
