import 'package:flutter/foundation.dart';
import 'common.dart';
import 'chain_score.dart';
import 'protocol_capability.dart';
import '../services/chain_probe_service.dart';

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
  

  const ChainProxyNodeViewModel({
    required this.proxy,
    required this.nodeName,
    this.score,
    this.health = ChainHealthStatus.unknown,
    this.latencyMs,
    this.capabilityEvidence = CapabilityEvidenceType.unknown,
    this.isLocked = false,
    this.isFailoverCandidate = false,
    
  });

  /// Allows UI to check if the node is strongly recommended
  bool get isRecommended => (score?.totalScore ?? 0) >= 80;

  bool get isExploration => (score?.confidence ?? 0.0) >= 1.0 && latencyMs == null;

  /// Tie-breaker logic matching Auto Failover's fallback logic
  int compareTo(ChainProxyNodeViewModel other) {
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
}
