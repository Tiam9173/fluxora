import '../models/chain_reliability_stats.dart';
import 'dart:math' as math;
import '../services/network_fingerprint_provider.dart';
import '../models/chain_score.dart';
import '../models/chain_fallback_pool.dart';
import '../models/protocol_capability.dart';

class ChainAdaptiveScoreService {
  /// Calculates the adaptive score for a single candidate node.
  static ChainScore calculateNodeScore({
    required ChainFallbackCandidate candidate,
    ProtocolCapabilityProfile? capabilityProfile,
    double flapPenalty = 0.0,
    int globalTotalTrials = 0,
  }) {
    final fingerprint = networkFingerprintProvider.getCurrentFingerprint();
    final stats =
        candidate.statsByContext[fingerprint] ??
        ChainReliabilityStats.initial(networkFingerprint: fingerprint);

    // 1. Laplace confidence (Reliability)
    double confidence = stats.confidence;

    // 1b. UCB Exploration
    if (globalTotalTrials > 0) {
      if (stats.totalSamples == 0) {
        // Force exploration for entirely untested nodes by bumping confidence
        confidence = 1.0;
      } else {
        // UCB1 formula: mean + C * sqrt(ln(N) / n)
        // C is an exploration constant. We use a small C (e.g. 0.2) to not completely overthrow stable nodes.
        final explorationBonus =
            0.2 * math.sqrt(math.log(globalTotalTrials) / stats.totalSamples);
        confidence = math.min(1.0, confidence + explorationBonus);
      }
    }

    // 1c. Stability Multiplier (Consecutive failure penalty)
    double stabilityMultiplier = 1.0;
    if (stats.consecutiveFailures > 0) {
      // 0.9 for 1 fail, 0.6 for 3, 0.2 for 5+
      // Using formula: max(0.2, 1.0 - (consecutiveFailures * 0.1) - some extra penalty for higher numbers?)
      if (stats.consecutiveFailures == 1)
        stabilityMultiplier = 0.9;
      else if (stats.consecutiveFailures == 2)
        stabilityMultiplier = 0.8;
      else if (stats.consecutiveFailures == 3)
        stabilityMultiplier = 0.6;
      else if (stats.consecutiveFailures == 4)
        stabilityMultiplier = 0.4;
      else
        stabilityMultiplier = 0.2;
    }

    confidence = confidence * stabilityMultiplier;
    final double reliabilityScore = confidence * 100.0;

    // 2. Latency score (0-100)
    // Assume 1000ms is the max acceptable latency for scoring normalization
    double latencyScore = 50.0; // default unknown
    if (candidate.latencyMs != null && candidate.latencyMs! >= 0) {
      latencyScore = (100.0 - (candidate.latencyMs! / 10.0)).clamp(0.0, 100.0);
    }

    // 3. Capability confidence
    double capabilityScore = 20.0; // unknown default
    if (capabilityProfile != null) {
      switch (capabilityProfile.evidence) {
        case CapabilityEvidenceType.runtimeVerified:
          capabilityScore = 100.0;
          break;
        case CapabilityEvidenceType.userConfirmed:
          capabilityScore = 80.0;
          break;
        case CapabilityEvidenceType.configDeclared:
          capabilityScore = 60.0;
          break;
        case CapabilityEvidenceType.expired:
          capabilityScore = 40.0;
          break;
        case CapabilityEvidenceType.unknown:
        case CapabilityEvidenceType.runtimeRejected:
          capabilityScore = 20.0;
          break;
      }
    }

    // 4. Base Score (Weighted)
    // Weight model: 60% Reliability, 30% Performance, 10% Capability
    double baseScore =
        (0.6 * reliabilityScore) +
        (0.3 * latencyScore) +
        (0.1 * capabilityScore);

    // 5. Flap penalty subtraction
    double finalScore = (baseScore - flapPenalty).clamp(0.0, 100.0);

    return ChainScore(
      totalScore: double.parse(finalScore.toStringAsFixed(2)),
      confidence: double.parse(confidence.toStringAsFixed(2)),
      reliabilityScore: double.parse(reliabilityScore.toStringAsFixed(2)),
      capabilityScore: double.parse(capabilityScore.toStringAsFixed(2)),
      latencyScore: double.parse(latencyScore.toStringAsFixed(2)),
      flapPenalty: double.parse(flapPenalty.toStringAsFixed(2)),
      hopPenalty: 0.0,
    );
  }

  /// Calculates the score for an entire chain route (Multi-Hop)
  static ChainScore calculateChainScore(List<ChainScore> nodeScores) {
    if (nodeScores.isEmpty) {
      return const ChainScore(
        totalScore: 0.0,
        confidence: 0.0,
        reliabilityScore: 0.0,
        capabilityScore: 0.0,
        latencyScore: 0.0,
        flapPenalty: 0.0,
        hopPenalty: 0.0,
      );
    }

    double chainRel = 1.0;
    double chainLat = 0.0;
    double chainCap = 1.0;
    double maxFlap = 0.0;
    double minConfidence = 1.0;

    for (var score in nodeScores) {
      // Multiply probabilities to inherently penalize longer chains naturally
      chainRel *= (score.reliabilityScore / 100.0);
      chainLat += score.latencyScore;
      chainCap *= (score.capabilityScore / 100.0);

      if (score.flapPenalty > maxFlap) maxFlap = score.flapPenalty;
      if (score.confidence < minConfidence) minConfidence = score.confidence;
    }

    // Explicit hop penalty logic (beyond natural probability reduction)
    double hopPenalty = (nodeScores.length > 2)
        ? (nodeScores.length - 2) * 5.0
        : 0.0;

    double finalRelScore = chainRel * 100.0;
    // Average out latency score across hops to prevent total zeroing out,
    // though real latency adds up, the score itself is a 0-100 metric.
    double avgLatScore = (chainLat / nodeScores.length).clamp(0.0, 100.0);
    double finalCapScore = chainCap * 100.0;

    double baseScore =
        (0.6 * finalRelScore) + (0.3 * avgLatScore) + (0.1 * finalCapScore);
    double finalScore = (baseScore - maxFlap - hopPenalty).clamp(0.0, 100.0);

    return ChainScore(
      totalScore: double.parse(finalScore.toStringAsFixed(2)),
      confidence: double.parse(minConfidence.toStringAsFixed(2)),
      reliabilityScore: double.parse(finalRelScore.toStringAsFixed(2)),
      capabilityScore: double.parse(finalCapScore.toStringAsFixed(2)),
      latencyScore: double.parse(avgLatScore.toStringAsFixed(2)),
      flapPenalty: double.parse(maxFlap.toStringAsFixed(2)),
      hopPenalty: double.parse(hopPenalty.toStringAsFixed(2)),
    );
  }
}
