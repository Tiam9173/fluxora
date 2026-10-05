import 'dart:math' as math;
import 'package:flutter/foundation.dart';

@immutable
class ChainReliabilityStats {
  final double weightedSuccess;
  final double weightedFailure;
  final int consecutiveFailures;
  final DateTime lastUpdated;
  final int totalSamples;
  final String networkFingerprint;

  const ChainReliabilityStats({
    required this.weightedSuccess,
    required this.weightedFailure,
    required this.consecutiveFailures,
    required this.lastUpdated,
    required this.totalSamples,
    required this.networkFingerprint,
  });

  factory ChainReliabilityStats.initial({
    required String networkFingerprint,
    DateTime? now,
  }) {
    return ChainReliabilityStats(
      weightedSuccess: 0.0,
      weightedFailure: 0.0,
      consecutiveFailures: 0,
      lastUpdated: now ?? DateTime.now(),
      totalSamples: 0,
      networkFingerprint: networkFingerprint,
    );
  }

  /// Records an event with exponential time decay.
  ///
  /// [lambda] is the decay constant (e.g., ln(2) / halfLifeInHours).
  ChainReliabilityStats recordEvent({
    required bool isSuccess,
    required DateTime now,
    double lambda = 0.0, // Default to 0 for no decay if not specified
  }) {
    double decayFactor = 1.0;

    if (now.isAfter(lastUpdated) && lambda > 0) {
      final hoursPassed = now.difference(lastUpdated).inMinutes / 60.0;
      decayFactor = math.exp(-lambda * hoursPassed);
    }

    final decayedSuccess = weightedSuccess * decayFactor;
    final decayedFailure = weightedFailure * decayFactor;

    return ChainReliabilityStats(
      weightedSuccess: decayedSuccess + (isSuccess ? 1.0 : 0.0),
      weightedFailure: decayedFailure + (isSuccess ? 0.0 : 1.0),
      consecutiveFailures: isSuccess ? 0 : consecutiveFailures + 1,
      lastUpdated: now,
      totalSamples: totalSamples + 1,
      networkFingerprint: networkFingerprint,
    );
  }

  double get confidence {
    // Laplace smoothing applied to weighted values
    return (weightedSuccess + 1.0) / (weightedSuccess + weightedFailure + 2.0);
  }

  ChainReliabilityStats copyWith({
    double? weightedSuccess,
    double? weightedFailure,
    int? consecutiveFailures,
    DateTime? lastUpdated,
    int? totalSamples,
    String? networkFingerprint,
  }) {
    return ChainReliabilityStats(
      weightedSuccess: weightedSuccess ?? this.weightedSuccess,
      weightedFailure: weightedFailure ?? this.weightedFailure,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      totalSamples: totalSamples ?? this.totalSamples,
      networkFingerprint: networkFingerprint ?? this.networkFingerprint,
    );
  }
}
