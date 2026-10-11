import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';

/// P2.5-D — Diagnostic production wiring.
///
/// Proves the REAL chain (not "manager method != null"):
///
///   ChainProxyManager.exportChainDiagnosticReport()
///     → ChainDiagnosticExportService.exportReport(this)
///       → report built from the manager's REAL telemetry + REAL chain config
///         → REAL Markdown file on disk
///
/// No mock service, no placeholder report.
void main() {
  final manager = ChainProxyManager();

  setUp(() => chainTelemetryService.clear());
  tearDown(() => chainTelemetryService.clear());

  test('A. export delegates to the real service and writes a real file',
      () async {
    // Seed the REAL telemetry service — the same source the manager exposes.
    chainTelemetryService.record(
      ChainTelemetryEvent(
        type: ChainTelemetryEventType.probeCompleted,
        timestamp: DateTime.now(),
        nodeName: 'HK-01',
        role: 'entry',
        message: 'ok',
      ),
    );

    final file = await manager.exportChainDiagnosticReport();
    expect(file, isNotNull, reason: 'must delegate, not return null');
    expect(await file!.exists(), isTrue, reason: 'a real file on disk');

    final content = await file.readAsString();
    expect(content, contains('# Fluxora Chain Diagnostic Report'));
    expect(content, contains('Report ID: DIAG-'));
    expect(content, contains('Total Events: 1'), reason: 'from real telemetry');
    expect(
      content,
      contains('[probeCompleted] Success'),
      reason: 'the real recorded event is rendered',
    );
    expect(content, isNot(contains('TODO')), reason: 'never a placeholder');

    await file.delete();
  });

  test('B. empty telemetry yields an honest report, never a fabricated one',
      () async {
    final file = await manager.exportChainDiagnosticReport();
    expect(file, isNotNull);
    final content = await file!.readAsString();
    expect(content, contains('Total Events: 0'));
    expect(content, contains('No telemetry available'));
    await file.delete();
  });

  test('C. the report reflects the REAL chain config (no hardcoded topology)',
      () async {
    // The default in-memory config is disabled; the topology line is derived
    // from it, so a hardcoded value would not produce 'Disabled'.
    expect(manager.config.enable, isFalse);

    final file = await manager.exportChainDiagnosticReport();
    expect(file, isNotNull);
    final content = await file!.readAsString();
    expect(content, contains('Disabled'));
    await file.delete();
  });
}
