import 'package:flutter/foundation.dart';
import 'common.dart';
import 'chain_score.dart';
import 'protocol_capability.dart';
import '../services/chain_probe_service.dart';
import '../services/proxy_semantic_classifier.dart';

@immutable
class ChainProxyNodeViewModel {
  final Proxy proxy;
  final String nodeName;
  final ChainScore? score;
  final ChainHealthStatus health;
  final int? latencyMs;
  final CapabilityEvidenceType capabilityEvidence;
  final bool isLocked;
  final bool isFailoverCandidate;
  final ProxySemanticType semanticType;
  final bool hasObservedTelemetry;

  const ChainProxyNodeViewModel({
    required this.proxy,
    required this.nodeName,
    this.score,
    this.health = ChainHealthStatus.unknown,
    this.latencyMs,
    this.capabilityEvidence = CapabilityEvidenceType.unknown,
    this.isLocked = false,
    this.isFailoverCandidate = false,
    this.semanticType = ProxySemanticType.unknown,
    this.hasObservedTelemetry = false,
  });

  bool get isNonConnectable => semanticType == ProxySemanticType.nonConnectable;
  bool get isUntested => !hasObservedTelemetry;

  /// Allows UI to check if the node is strongly recommended
  bool get isRecommended => (score?.totalScore ?? 0) >= 80;

  bool get isExploration => (score?.confidence ?? 0.0) >= 1.0 && latencyMs == null;

  /// Tie-breaker logic matching Auto Failover's fallback logic
  int compareTo(ChainProxyNodeViewModel other) {
    // 0. Health tier first — the SAME ordering `ChainFallbackService` applies
    //    before it scores candidates (healthy < degraded < unknown < failed /
    //    unavailable / checking / cancelled).
    //
    //    P1.3-A1: previously the UI sorted by capability → score → name while
    //    failover sank unhealthy nodes first, so a `failed` node with a high
    //    score outranked a healthy one in the picker but lost in failover — the
    //    two decision surfaces disagreed about the same health datum.
    final byHealth = _healthRank(health).compareTo(_healthRank(other.health));
    if (byHealth != 0) return byHealth;

    // 1. Capable vs Incapable
    final thisCapable = capabilityEvidence != CapabilityEvidenceType.runtimeRejected;
    final otherCapable = other.capabilityEvidence != CapabilityEvidenceType.runtimeRejected;
    if (thisCapable && !otherCapable) return -1;
    if (!thisCapable && otherCapable) return 1;

    // 2. Score
    if (score != null && other.score != null) {
      if (score!.totalScore != other.score!.totalScore) {
        return other.score!.totalScore.compareTo(score!.totalScore); // Descending
      }
    } else if (score != null) {
      return -1;
    } else if (other.score != null) {
      return 1;
    }

    // 3. Alphabetical Determinism
    return nodeName.compareTo(other.nodeName);
  }

  /// P1.3-C4-Step5 — the 「延迟」 sort key, as an explicit and testable rule.
  ///
  /// Two tiers:
  ///   1. nodes that have a valid latency — ascending;
  ///   2. nodes that do not (`latencyMs == null`: missing / stale / foreign
  ///      network) — **last**, kept in a deterministic `nodeName` order because
  ///      `List.sort` is not stable.
  ///
  /// A `null` latency is never treated as `0 ms` and never wins tier 1. This
  /// replaces the previous `?? 99999` sentinel, which could collide with a real
  /// (if absurd) latency of 99999 ms.
  static int compareByLatency(
    ChainProxyNodeViewModel a,
    ChainProxyNodeViewModel b,
  ) {
    final aLat = a.latencyMs;
    final bLat = b.latencyMs;
    if (aLat == null && bLat == null) return a.nodeName.compareTo(b.nodeName);
    if (aLat == null) return 1;
    if (bLat == null) return -1;
    if (aLat != bLat) return aLat.compareTo(bLat);
    return a.nodeName.compareTo(b.nodeName);
  }

  /// Mirrors `ChainFallbackService.selectCandidates`'s local `healthRank`
  /// exactly (healthy 1 < degraded 2 < unknown 3 < everything else 4).
  ///
  /// Kept as a private copy on purpose: the failover side is outside this
  /// change's scope, so the two must stay in sync by hand for now.
  static int _healthRank(ChainHealthStatus status) => switch (status) {
    ChainHealthStatus.healthy => 1,
    ChainHealthStatus.degraded => 2,
    ChainHealthStatus.unknown => 3,
    _ => 4,
  };
}
