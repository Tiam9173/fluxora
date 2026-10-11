import '../models/chain_reliability_stats.dart';

/// P1.1-D2 — behavioural availability classification for chain candidates.
///
/// P1.1-C proved that a node's connectability **cannot** be derived from its
/// configuration structure: the subscription "information placeholders"
/// (剩余流量 / 套餐到期 / 节点超时请手动更新订阅 …) carry a fully valid
/// `hysteria2` config that is structurally identical to a real node. The only
/// objective, name-independent judge is therefore **observed behaviour** — the
/// real measurements D1 records into [ChainReliabilityStats] via
/// `clashCore.getDelay`.
///
/// This classification is *presentation only*. It never mutates
/// `ChainFallbackCandidate`, scoring, failover, telemetry, the ranking cache or
/// the normal proxy list; only the Intelligent Node Center consumes it.
enum ProxySemanticType {
  /// At least one real measurement succeeded → the node actually carried
  /// traffic in this network context.
  connectable,

  /// Enough consecutive real failures to conclude the node does not carry
  /// traffic, while zero measurements ever succeeded.
  nonConnectable,

  /// Not enough real evidence to decide (never measured, or too few failures).
  ///
  /// Untested nodes MUST stay here: a newly added real node is not
  /// `nonConnectable`. This keeps the classifier free of false negatives.
  unknown,
}

/// Pure, side-effect-free classifier — no IO, no clock, no randomness.
class ProxySemanticClassifier {
  const ProxySemanticClassifier._();

  /// Consecutive real failures required before a node that has **never**
  /// succeeded is declared [ProxySemanticType.nonConnectable].
  ///
  /// Chosen conservatively so a single transient network blip cannot condemn a
  /// working node; three consecutive real failures with zero successes is
  /// treated as behavioural evidence of non-connectability.
  static const int nonConnectableFailureThreshold = 3;

  /// Classifies [stats] (the candidate's stats for the **current** network
  /// fingerprint) into a [ProxySemanticType].
  static ProxySemanticType classify(ChainReliabilityStats? stats) {
    if (stats == null || stats.totalSamples <= 0) {
      return ProxySemanticType.unknown;
    }
    if (stats.weightedSuccess > 0) {
      return ProxySemanticType.connectable;
    }
    if (stats.consecutiveFailures >= nonConnectableFailureThreshold) {
      return ProxySemanticType.nonConnectable;
    }
    return ProxySemanticType.unknown;
  }
}
