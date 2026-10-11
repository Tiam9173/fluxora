import 'package:flutter/foundation.dart';

/// The adaptive score of a node (or, potentially, of a whole chain).
///
/// ## Production status (P1.3-A3)
///
/// **ACTIVE** — populated by `ChainAdaptiveScoreService.calculateNodeScore`
/// and read by both decision surfaces:
///   * `adaptive_ranking_provider` → the intelligent node picker ordering;
///   * `chain_fallback_service.selectCandidates` → the failover candidate order.
///
/// **Reserved** — declared, carried through the formula and covered by tests,
/// but never populated by any production path: [flapPenalty], [hopPenalty].
/// They are documented below so a reader does not mistake them for live inputs.
@immutable
class ChainScore {
  final double totalScore;
  final double confidence;
  final double reliabilityScore;
  final double capabilityScore;
  final double latencyScore;

  /// **Reserved** — the flap-dampening penalty.
  ///
  /// `calculateNodeScore` accepts it as an optional parameter (default `0.0`)
  /// and subtracts it from the base score, but **no production caller ever
  /// passes a non-zero value**, so this is always `0.0` today.
  ///
  /// Flap governance currently lives in `ChainFlapDampenerService`, which acts
  /// as a *session-level gate* before `triggerAutoFailover` — it does not feed
  /// the score. This field is the reserved integration point for a future
  /// "flap history → score" path (candidate: P1.3-C Score Model Evolution).
  final double flapPenalty;

  /// **Reserved** — the multi-hop chain penalty.
  ///
  /// Only ever assigned by `calculateChainScore`, which has **no production
  /// caller**: production scoring is node-level only, and `calculateNodeScore`
  /// always writes `0.0` here. Note that `calculateChainScore`'s input (one
  /// `ChainScore` per hop) has no producer in production either, so wiring this
  /// up requires a chain-level scoring pipeline, not just a call site.
  final double hopPenalty;

  const ChainScore({
    required this.totalScore,
    required this.confidence,
    required this.reliabilityScore,
    required this.capabilityScore,
    required this.latencyScore,
    required this.flapPenalty,
    required this.hopPenalty,
  });

  Map<String, dynamic> get breakdown => {
    'totalScore': totalScore,
    'confidence': confidence,
    'reliabilityScore': reliabilityScore,
    'capabilityScore': capabilityScore,
    'latencyScore': latencyScore,
    'flapPenalty': flapPenalty,
    'hopPenalty': hopPenalty,
  };

  @override
  String toString() {
    return 'ChainScore(total: $totalScore, breakdown: $breakdown)';
  }
}
