import 'package:fluxora/models/chain_telemetry.dart';
import 'dart:io';
import 'package:fluxora/models/chain_diagnostic_report.dart';
import 'package:fluxora/models/chain_analytics.dart';
import 'package:fluxora/models/chain_insight.dart';
import 'package:fluxora/models/chain_decision.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';

abstract class IChainDiagnosticExportService {
  Future<File> exportReport(ChainProxyManager manager);
  ChainDiagnosticReport buildReport(ChainProxyManager manager);
}

class ChainDiagnosticExportService implements IChainDiagnosticExportService {
  @override
  ChainDiagnosticReport buildReport(ChainProxyManager manager) {
    final telemetry = manager.telemetrySnapshot;
    final intelligence = ChainIntelligenceSnapshot.fromTelemetry(telemetry);
    final insight = ChainAdaptiveInsight.fromTelemetry(telemetry);
    final decision = ChainDecisionSupport.fromInsight(insight);

    final summary = ChainDiagnosticSummary(
      healthScore: intelligence.healthScore,
      stability: insight.forecast.name,
      totalEvents: telemetry.totalEvents,
      failures: telemetry.failedEvents,
      successfulRecoveries: 0,
    );

    final topologyStr = manager.config.enable
        ? 'Entry: ${manager.config.hop1Node}\nRelay: ${manager.config.hop2Node}\nExit: ${manager.config.hop3Node}'
        : 'Disabled';

    return ChainDiagnosticReport(
      reportId: 'DIAG-${DateTime.now().millisecondsSinceEpoch}',
      generatedAt: DateTime.now(),
      summary: summary,
      topology: topologyStr,
      telemetry: telemetry,
      intelligence: intelligence,
      insight: insight,
      decisions: decision.recommendations.map((e) => e.title).toList(),
    );
  }

  @override
  Future<File> exportReport(ChainProxyManager manager) async {
    final report = buildReport(manager);
    final md = _generateMarkdown(report);

    final filename =
        'Fluxora-Chain-Diagnostic-${_formatDate(report.generatedAt)}.md';
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$filename');

    await file.writeAsString(md);
    return file;
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}-${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _generateMarkdown(ChainDiagnosticReport report) {
    final buffer = StringBuffer();
    buffer.writeln('# Fluxora Chain Diagnostic Report');
    buffer.writeln('');
    buffer.writeln('Report ID: ${report.reportId}');
    buffer.writeln('Generated At: ${report.generatedAt.toIso8601String()}');
    buffer.writeln('');

    buffer.writeln('## Summary');
    buffer.writeln('Health: ${report.summary.healthScore}/100');
    buffer.writeln('Status: ${report.summary.stability}');
    buffer.writeln('Total Events: ${report.summary.totalEvents}');
    buffer.writeln('Failures: ${report.summary.failures}');
    buffer.writeln('');

    buffer.writeln('## Topology');
    buffer.writeln(report.topology);
    buffer.writeln('');

    buffer.writeln('## Intelligence');
    buffer.writeln(
      'Risk: ${report.insight.failureCorrelation.description.isNotEmpty ? report.insight.failureCorrelation.description : "None"}',
    );
    buffer.writeln('');

    buffer.writeln('## Recommendation');
    for (var rec in report.decisions) {
      buffer.writeln('- $rec');
    }
    buffer.writeln('');

    buffer.writeln('## Recent Events');
    if (report.telemetry.recentEvents.isEmpty) {
      buffer.writeln('No telemetry available');
    } else {
      for (var ev in report.telemetry.recentEvents.take(50)) {
        buffer.writeln(
          '${_formatTime(ev.timestamp)} [${ev.type.name}] ${ev.type.isFailure ? "Failed" : "Success"}',
        );
      }
    }

    return buffer.toString();
  }

  static Map<String, dynamic>? sanitizeDiagnosticData(
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final sanitized = <String, dynamic>{};
    final sensitiveKeys = [
      'password',
      'passwd',
      'secret',
      'token',
      'uuid',
      'subscription',
      'url',
      'credential',
      'auth',
      'header',
    ];

    data.forEach((key, value) {
      final lowerKey = key.toLowerCase();
      bool isSensitive = sensitiveKeys.any((s) => lowerKey.contains(s));
      if (isSensitive) {
        sanitized[key] = '[REDACTED]';
      } else {
        if (value is String && value.length > 256) {
          sanitized[key] = '${value.substring(0, 256)}...[TRUNCATED]';
        } else {
          sanitized[key] = value;
        }
      }
    });
    return sanitized;
  }
}

final chainDiagnosticExportService = ChainDiagnosticExportService();
