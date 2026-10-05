import 'package:flutter/foundation.dart';

@immutable
class ChainScore {
  final double totalScore;
  final double confidence;
  final double reliabilityScore;
  final double capabilityScore;
  final double latencyScore;
  final double flapPenalty;
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
