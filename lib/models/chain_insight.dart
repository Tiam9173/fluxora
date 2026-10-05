import 'package:flutter/foundation.dart';
import 'package:fluxora/models/chain_telemetry.dart';

enum TrendDirection { improving, stable, degrading, insufficientData }

enum StabilityForecast { highlyStable, stable, volatile, critical }

@immutable
class AnomalyDetection {
  final bool hasLatencySpike;
  final bool hasFailureBurst;
  final String? anomalyDescription;

  const AnomalyDetection({
    required this.hasLatencySpike,
    required this.hasFailureBurst,
    this.anomalyDescription,
  });
}

@immutable
class FailureCorrelation {
  final String? highlyCorrelatedNode;
  final String? highlyCorrelatedRole;
  final String description;

  const FailureCorrelation({
    this.highlyCorrelatedNode,
    this.highlyCorrelatedRole,
    required this.description,
  });
}

@immutable
class ChainAdaptiveInsight {
  final TrendDirection latencyTrend;
  final TrendDirection reliabilityTrend;
  final AnomalyDetection anomalyDetection;
  final FailureCorrelation failureCorrelation;
  final StabilityForecast forecast;

  const ChainAdaptiveInsight({
    required this.latencyTrend,
    required this.reliabilityTrend,
    required this.anomalyDetection,
    required this.failureCorrelation,
    required this.forecast,
  });

  factory ChainAdaptiveInsight.empty() {
    return const ChainAdaptiveInsight(
      latencyTrend: TrendDirection.insufficientData,
      reliabilityTrend: TrendDirection.insufficientData,
      anomalyDetection: AnomalyDetection(
        hasLatencySpike: false,
        hasFailureBurst: false,
      ),
      failureCorrelation: FailureCorrelation(
        description: 'Insufficient data for correlation',
      ),
      forecast: StabilityForecast.stable,
    );
  }

  factory ChainAdaptiveInsight.fromTelemetry(ChainTelemetrySnapshot telemetry) {
    final events = telemetry.recentEvents;
    if (events.length < 5) {
      return ChainAdaptiveInsight.empty();
    }

    // 1. Split for Trend Analysis
    final half = events.length ~/ 2;
    final olderHalf = events.sublist(0, half);
    final newerHalf = events.sublist(half);

    double calcAvgLatency(List<ChainTelemetryEvent> list) {
      int count = 0;
      double total = 0;
      for (final e in list) {
        if (e.type == ChainTelemetryEventType.probeCompleted &&
            e.metadata != null) {
          final lat = e.metadata!['latencyMs'];
          if (lat is num && lat > 0) {
            total += lat.toDouble();
            count++;
          }
        }
      }
      return count > 0 ? total / count : 0.0;
    }

    double calcFailRate(List<ChainTelemetryEvent> list) {
      int fails = list.where((e) => e.type.isFailure).length;
      return list.isEmpty ? 0.0 : fails / list.length;
    }

    final oldLat = calcAvgLatency(olderHalf);
    final newLat = calcAvgLatency(newerHalf);

    TrendDirection latTrend = TrendDirection.insufficientData;
    if (oldLat > 0 && newLat > 0) {
      if (newLat > oldLat * 1.2) {
        latTrend = TrendDirection.degrading;
      } else if (newLat < oldLat * 0.8) {
        latTrend = TrendDirection.improving;
      } else {
        latTrend = TrendDirection.stable;
      }
    }

    final oldFail = calcFailRate(olderHalf);
    final newFail = calcFailRate(newerHalf);

    TrendDirection relTrend = TrendDirection.insufficientData;
    if (olderHalf.isNotEmpty && newerHalf.isNotEmpty) {
      if (newFail > oldFail + 0.1) {
        relTrend = TrendDirection.degrading;
      } else if (newFail < oldFail - 0.1) {
        relTrend = TrendDirection.improving;
      } else {
        relTrend = TrendDirection.stable;
      }
    }

    // 2. Anomaly Detection
    bool hasSpike = false;
    if (oldLat > 0 && newLat > oldLat * 2.0) hasSpike = true;

    bool hasBurst = false;
    int recentFails = 0;
    final burstWindow = events.length < 10 ? events.length : 10;
    for (int i = events.length - burstWindow; i < events.length; i++) {
      if (events[i].type.isFailure) recentFails++;
    }
    if (recentFails >= 3 && (recentFails / burstWindow) >= 0.5) {
      hasBurst = true;
    }

    String? anomalyDesc;
    if (hasSpike && hasBurst) {
      anomalyDesc = 'Critical latency spike and failure burst detected.';
    } else if (hasSpike) {
      anomalyDesc = 'Sudden latency degradation detected.';
    } else if (hasBurst) {
      anomalyDesc = 'Sudden burst of failures detected.';
    }

    // 3. Failure Correlation
    final nodeFailures = <String, int>{};
    final nodeTotals = <String, int>{};
    for (final e in events) {
      if (e.nodeName != null &&
          e.nodeName!.isNotEmpty &&
          e.role != null &&
          e.role!.isNotEmpty) {
        final key = '${e.role}:${e.nodeName}';
        nodeTotals[key] = (nodeTotals[key] ?? 0) + 1;
        if (e.type.isFailure) {
          nodeFailures[key] = (nodeFailures[key] ?? 0) + 1;
        }
      }
    }

    String? correlatedNode;
    String? correlatedRole;
    String corrDesc = 'No strong failure correlations found.';
    double highestCorrRate = 0;

    nodeFailures.forEach((key, failCount) {
      final total = nodeTotals[key] ?? 1;
      if (total >= 3 && failCount >= 2) {
        final rate = failCount / total;
        if (rate > 0.6 && rate > highestCorrRate) {
          highestCorrRate = rate;
          final parts = key.split(':');
          if (parts.length >= 2) {
            correlatedRole = parts[0];
            correlatedNode = parts[1];
          }
        }
      }
    });

    if (correlatedNode != null) {
      corrDesc =
          'Failures are highly correlated with $correlatedRole node: $correlatedNode';
    }

    // 4. Stability Forecast
    StabilityForecast forecast = StabilityForecast.stable;
    if (hasBurst || relTrend == TrendDirection.degrading) {
      forecast = StabilityForecast.volatile;
    }
    if (hasBurst && hasSpike) {
      forecast = StabilityForecast.critical;
    }
    if (!hasBurst &&
        !hasSpike &&
        relTrend == TrendDirection.improving &&
        newFail == 0) {
      forecast = StabilityForecast.highlyStable;
    }

    return ChainAdaptiveInsight(
      latencyTrend: latTrend,
      reliabilityTrend: relTrend,
      anomalyDetection: AnomalyDetection(
        hasLatencySpike: hasSpike,
        hasFailureBurst: hasBurst,
        anomalyDescription: anomalyDesc,
      ),
      failureCorrelation: FailureCorrelation(
        highlyCorrelatedNode: correlatedNode,
        highlyCorrelatedRole: correlatedRole,
        description: corrDesc,
      ),
      forecast: forecast,
    );
  }
}
