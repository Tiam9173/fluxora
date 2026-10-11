import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';

/// P2.5-D — Support Package production wiring.
///
/// Proves the REAL chain (not a mocked ZIP):
///
///   ChainProxyManager.createSupportPackage()
///     → ChainSupportPackageService.createPackage(this)
///       → ChainSupportPackageService.exportPackage(package)
///         → REAL ZIP on disk containing the REAL diagnostic report
void main() {
  final manager = ChainProxyManager();

  setUp(() => chainTelemetryService.clear());
  tearDown(() => chainTelemetryService.clear());

  test('A. createSupportPackage produces a REAL, readable ZIP', () async {
    chainTelemetryService.record(
      ChainTelemetryEvent(
        type: ChainTelemetryEventType.probeFailed,
        timestamp: DateTime.now(),
        nodeName: 'US-01',
        role: 'exit',
        message: 'timeout',
      ),
    );

    await manager.createSupportPackage();

    expect(manager.lastGeneratedPackage, isNotNull);
    final path = manager.lastGeneratedPackagePath;
    expect(path, isNotNull, reason: 'the real file path must be published');

    final file = File(path!);
    expect(await file.exists(), isTrue, reason: 'real file on disk');

    final bytes = await file.readAsBytes();
    expect(bytes.length, greaterThan(0));
    expect(bytes.sublist(0, 2), [0x50, 0x4B], reason: 'ZIP magic (PK)');

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, contains('README.md'));
    expect(names, contains('summary.md'));
    expect(names, contains('telemetry.json'));

    await file.delete();
  });

  test('B. empty telemetry still yields a real ZIP (no fabricated success)',
      () async {
    await manager.createSupportPackage();

    final path = manager.lastGeneratedPackagePath;
    expect(path, isNotNull);

    final bytes = await File(path!).readAsBytes();
    expect(bytes.sublist(0, 2), [0x50, 0x4B]);
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.files, isNotEmpty);

    await File(path).delete();
  });
}
