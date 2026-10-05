import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:fluxora/models/chain_support_package.dart';
import 'package:fluxora/services/chain_diagnostic_export_service.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';

abstract class IChainSupportPackageService {
  Future<ChainSupportPackage> createPackage(
    ChainProxyManager manager, {
    List<ChainSupportSection>? sections,
  });
  Future<File> exportPackage(ChainSupportPackage package);
}

class ChainSupportPackageService implements IChainSupportPackageService {
  static const int maxFileSize = 2 * 1024 * 1024; // 2MB
  static const int maxPackageSize = 10 * 1024 * 1024; // 10MB

  @override
  Future<ChainSupportPackage> createPackage(
    ChainProxyManager manager, {
    List<ChainSupportSection>? sections,
  }) async {
    final report = chainDiagnosticExportService.buildReport(manager);
    final included =
        sections ??
        const [
          ChainSupportSection.summary,
          ChainSupportSection.telemetry,
          ChainSupportSection.intelligence,
          ChainSupportSection.insight,
          ChainSupportSection.decision,
        ];

    return ChainSupportPackage(
      id: 'PKG-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      appVersion: 'v1.1.0',
      platform: Platform.operatingSystem,
      diagnostic: report,
      includedSections: included,
      sizeEstimate: 0,
    );
  }

  @override
  Future<File> exportPackage(ChainSupportPackage package) async {
    final archive = Archive();
    int currentPackageSize = 0;

    void addFile(String name, String content) {
      final bytes = utf8.encode(content);
      var truncatedBytes = bytes;
      if (bytes.length > maxFileSize) {
        final truncatedContent = '\n\n...[TRUNCATED_DUE_TO_SIZE]';
        truncatedBytes = utf8.encode(truncatedContent);
      }

      if (currentPackageSize + truncatedBytes.length > maxPackageSize) {
        return; // Skip adding to avoid exceeding total package size
      }

      currentPackageSize += truncatedBytes.length;
      archive.addFile(ArchiveFile(name, truncatedBytes.length, truncatedBytes));
    }

    final diag = package.diagnostic;

    // 1. README.md
    addFile(
      'README.md',
      '# Fluxora Chain Diagnostic Support Package\nID: ${package.id}\nGenerated At: ${package.createdAt.toIso8601String()}',
    );

    // 2. Summary
    if (package.includedSections.contains(ChainSupportSection.summary)) {
      addFile(
        'summary.md',
        '# Summary\nHealth Score: ${diag.summary.healthScore}\nFailures: ${diag.summary.failures}\nTotal Events: ${diag.summary.totalEvents}\n\n## Topology\n${diag.topology}',
      );
    }

    // 3. Telemetry
    if (package.includedSections.contains(ChainSupportSection.telemetry)) {
      final telemetryJson = jsonEncode({
        'totalEvents': diag.telemetry.totalEvents,
        'failedEvents': diag.telemetry.failedEvents,
        'recentEvents': diag.telemetry.recentEvents
            .map(
              (e) => {
                'id': e.id,
                'type': e.type.name,
                'timestamp': e.timestamp.toIso8601String(),
                'metadata': sanitizeEnhanced(e.metadata),
              },
            )
            .toList(),
      });
      addFile('telemetry.json', telemetryJson);
    }

    // 4. Intelligence
    if (package.includedSections.contains(ChainSupportSection.intelligence)) {
      final intJson = jsonEncode({
        'healthScore': diag.intelligence.healthScore,
        'dominantFailure': diag.intelligence.failureAnalytics.topErrorCode,
        'averageLatency': diag.intelligence.averageLatencyMs,
      });
      addFile('intelligence.json', intJson);
    }

    // 5. Insight
    if (package.includedSections.contains(ChainSupportSection.insight)) {
      final insightJson = jsonEncode({
        'forecast': diag.insight.forecast.name,
        'anomalyDescription': diag.insight.anomalyDetection.anomalyDescription,
        'failureCorrelation': diag.insight.failureCorrelation.description,
      });
      addFile('insight.json', insightJson);
    }

    // 6. Decision
    if (package.includedSections.contains(ChainSupportSection.decision)) {
      final decisionJson = jsonEncode({'recommendations': diag.decisions});
      addFile('decision.json', decisionJson);
    }

    // Encode Zip
    final zipData = ZipEncoder().encode(archive);

    // Save to temp
    final tempDir = Directory.systemTemp;
    final filename =
        'Fluxora_Chain_Diagnostic_${_formatDate(package.createdAt)}.zip';
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(zipData);

    return file;
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
  }

  static Map<String, dynamic>? sanitizeEnhanced(Map<String, dynamic>? data) {
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
      'privatekey',
      'secretkey',
      'accesstoken',
      'refreshtoken',
      'cookie',
      'authorization',
      'proxypassword',
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

final chainSupportPackageService = ChainSupportPackageService();
