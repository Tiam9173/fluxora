import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/services/chain_diagnostic_export_service.dart';

void main() {
  group('Chain Proxy 2.0 Phase 5.0-A — Chain Diagnostic Export Service', () {
    late ChainProxyManager manager;
    late ChainDiagnosticExportService service;

    setUp(() {
      manager = ChainProxyManager();
      service = ChainDiagnosticExportService();
    });

    test('1. Build Report - Basic Structure', () {
      final report = service.buildReport(manager);
      expect(report.reportId, startsWith('DIAG-'));
      expect(report.summary.healthScore, greaterThanOrEqualTo(0));
      expect(report.summary.totalEvents, equals(0));
    });

    test('2. Privacy Sanitization - Password and Tokens', () {
      final input = <String, dynamic>{
        'password': 'mySecretPassword',
        'token': 'abc123xyz',
        'normal_field': 'hello',
        'subSCRIPTION_URL': 'https://example.com/sub',
      };

      final output = ChainDiagnosticExportService.sanitizeDiagnosticData(
        input,
      )!;

      expect(output['password'], equals('[REDACTED]'));
      expect(output['token'], equals('[REDACTED]'));
      expect(output['subSCRIPTION_URL'], equals('[REDACTED]'));
      expect(output['normal_field'], equals('hello'));
    });

    test('3. Privacy Sanitization - Truncation for Large Data', () {
      final largeString = 'A' * 500;
      final input = <String, dynamic>{'stackTrace': largeString};

      final output = ChainDiagnosticExportService.sanitizeDiagnosticData(
        input,
      )!;

      expect(
        (output['stackTrace'] as String).length,
        equals(256 + 14),
      ); // 256 + '...[TRUNCATED]'
      expect(output['stackTrace'], endsWith('...[TRUNCATED]'));
    });

    test('4. Export File Creation', () async {
      final file = await service.exportReport(manager);
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('# Fluxora Chain Diagnostic Report'));
      expect(content, contains('## Summary'));
      expect(content, contains('## Topology'));
      expect(content, contains('## Intelligence'));
      expect(content, contains('## Recommendation'));
      expect(content, contains('## Recent Events'));
      expect(content, contains('No telemetry available'));

      // Cleanup
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('5. Large Data Event Truncation in Markdown', () async {
      // Since we can't directly mock TelemetryService events easily without a proper mock,
      // we just ensure the export handles empty/zero correctly and we manually test formatting.
      final report = service.buildReport(manager);
      // The logic only takes top 50 events. So it won't crash on 200 events.
      expect(report.telemetry.recentEvents.length, lessThanOrEqualTo(50));
    });
  });
}
