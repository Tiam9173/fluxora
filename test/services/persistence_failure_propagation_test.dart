import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P2.5-E (E-1) — persistence failure truth.
///
/// A failed write must be an **operation failure**, not a log-only warning:
/// `updateConfig` / `updateFallbackPool` now propagate it, so no caller (or UI)
/// can observe a false success. The write is made to fail by putting a
/// DIRECTORY where the target file must go — `AtomicConfigStorage.save` then
/// deterministically rethrows.
void main() {
  late Directory tmp;
  late String configPath;
  late String poolPath;
  late String statsPath;
  final manager = ChainProxyManager();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_p25e_persist_');
    configPath = p.join(tmp.path, 'chain_proxies.json');
    poolPath = p.join(tmp.path, 'chain_fallback_pool.json');
    statsPath = p.join(tmp.path, 'chain_reliability_stats.json');
    ChainProxyManager.configFilePathOverride = configPath;
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;
    ChainProxyManager.reliabilityStatsFilePathOverride = statsPath;
    ChainProxyManager.coreConfigReloadOverride = null;
  });

  tearDown(() async {
    await manager.flushReliabilityStats();
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    ChainProxyManager.coreConfigReloadOverride = null;
    await deleteTempDirWithRetry(tmp);
  });

  /// Makes [path] unwritable by putting a DIRECTORY where the file must go.
  Future<void> block(String path) async {
    if (FileSystemEntity.isFileSync(path)) await File(path).delete();
    Directory(path).createSync(recursive: true);
  }

  const poolWithOneExit = ChainFallbackPool(
    exitCandidates: [
      ChainFallbackCandidate(
        nodeName: 'X-EXIT',
        role: FallbackCandidateRole.exit,
      ),
    ],
  );

  // ── A. success path unchanged ────────────────────────────────────────────
  test('A. a successful save persists a versioned file', () async {
    await manager.updateConfig(
      (c) => c.copyWith(enable: true, hop1Node: 'A-1'),
      reloadCore: false,
    );

    final json =
        jsonDecode(await File(configPath).readAsString())
            as Map<String, dynamic>;
    expect(json['enable'], isTrue);
    expect(json['hop1Node'], 'A-1');
    expect(json['version'], 1, reason: 'P2.5-C stamping is unaffected');
  });

  // ── B. config write failure → operation fails ────────────────────────────
  test('B. a failed config write makes updateConfig FAIL (no false success)',
      () async {
    await block(configPath);

    await expectLater(
      manager.updateConfig((c) => c.copyWith(enable: true), reloadCore: false),
      throwsA(anything),
      reason: 'a failed persist must never complete normally',
    );

    // …and nothing was fabricated on disk.
    expect(FileSystemEntity.isDirectorySync(configPath), isTrue);
  });

  // ── C. fallback pool write failure → operation fails ─────────────────────
  test('C. a failed pool write makes updateFallbackPool FAIL', () async {
    await block(poolPath);

    await expectLater(
      manager.updateFallbackPool((_) => poolWithOneExit),
      throwsA(anything),
    );
    expect(FileSystemEntity.isDirectorySync(poolPath), isTrue);
  });

  // ── D. a reload failure still propagates after a successful save ─────────
  test('D. a reload failure still propagates (P2.4-C behaviour kept)', () async {
    ChainProxyManager.coreConfigReloadOverride = () async =>
        throw StateError('reload boom');

    await expectLater(
      manager.updateConfig((c) => c.copyWith(enable: true)),
      throwsA(isA<StateError>()),
    );
  });

  // ── E. flush reports failure instead of ignoring the bool ────────────────
  test('E. flushReliabilityStats reports a failed write without throwing',
      () async {
    // Mark the stats store dirty through the real production entry.
    await manager.updateFallbackPool((_) => poolWithOneExit);
    await block(statsPath);

    final ok = await manager.flushReliabilityStats();
    expect(
      ok,
      isFalse,
      reason: 'the save() bool must not be ignored',
    );
  });

  // ── F. flush with nothing pending still reports success ──────────────────
  test('F. flushReliabilityStats returns true when nothing is pending',
      () async {
    expect(await manager.flushReliabilityStats(), isTrue);
  });
}
