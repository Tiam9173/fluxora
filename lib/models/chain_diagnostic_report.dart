import 'package:flutter/foundation.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/models/chain_analytics.dart';
import 'package:fluxora/models/chain_insight.dart';

@immutable
class ChainDiagnosticSummary {
  final int healthScore;
  final String stability;
  final int totalEvents;
  final int failures;
  final int successfulRecoveries;

  const ChainDiagnosticSummary({
    required this.healthScore,
    required this.stability,
    required this.totalEvents,
    required this.failures,
    required this.successfulRecoveries,
  });
}

@immutable
class ChainDiagnosticReport {
  final String reportId;
  final DateTime generatedAt;
  final ChainDiagnosticSummary summary;
  final String topology;
  final ChainTelemetrySnapshot telemetry;
  final ChainIntelligenceSnapshot intelligence;
  final ChainAdaptiveInsight insight;
  final List<String> decisions;

  const ChainDiagnosticReport({
    required this.reportId,
    required this.generatedAt,
    required this.summary,
    required this.topology,
    required this.telemetry,
    required this.intelligence,
    required this.insight,
    required this.decisions,
  });
}
