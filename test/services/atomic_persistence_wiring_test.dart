import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/atomic_config_storage.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P2.4-A — Atomic persistence integration.
///
/// Proves the REAL production wiring: `ChainProxyManager` (and the reliability
/// store it drives) now write through `AtomicConfigStorage`, while the on-disk
/// JSON schema is byte-for-byte unchanged. These tests drive the manager's own
/// save entry points (`updateConfig` / `updateFallbackPool` /
/// `flushReliabilityStats`) — never the storage directly for the write path.
void main() {
  late Directory tmp;
  late String configPath;
  late String poolPath;
  late String statsPath;
  late ChainProxyManager manager;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_p24a_');
    configPath = p.join(tmp.path, 'chain_proxies.json');
    poolPath = p.join(tmp.path, 'chain_fallback_pool.json');
    statsPath = p.join(tmp.path, 'chain_reliability_stats.json');
    ChainProxyManager.configFilePathOverride = configPath;
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;
    ChainProxyManager.reliabilityStatsFilePathOverride = statsPath;
    ChainProxyManager.chainProbeOverride = null;
    manager = ChainProxyManager();
  });

  tearDown(() async {
    // P2.3-C ordering: flush (cancels the debounce timer) → drop overrides →
    // delete with a bounded retry.
    await manager.flushReliabilityStats();
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    ChainProxyManager.chainProbeOverride = null;
    await deleteTempDirWithRetry(tmp);
  });

  Future<Map<String, dynamic>> readJson(String path) async =>
      jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

  // ── A. normal save through the manager → valid JSON on disk ──────────────
  test('A. manager save writes a valid JSON file (atomic path)', () async {
    await manager.updateConfig(
      (c) => c.copyWith(enable: true, hop1Node: 'HK-01', hop2Node: 'US-01'),
      reloadCore: false,
    );

    final file = File(configPath);
    expect(await file.exists(), isTrue);
    final json = await readJson(configPath);
    expect(json['enable'], isTrue);
    expect(json['hop1Node'], 'HK-01');
    expect(json['hop2Node'], 'US-01');
    // No leftover temp files.
    final leftovers = tmp
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.tmp'))
        .toList();
    expect(leftovers, isEmpty, reason: 'atomic save must not leak .tmp files');
  });

  // ── B. existing file is replaced by the new content ─────────────────────
  test('B. a second save replaces the previous content', () async {
    await manager.updateConfig(
      (c) => c.copyWith(enable: true, hop1Node: 'OLD-1', hop2Node: 'OLD-2'),
      reloadCore: false,
    );
    expect((await readJson(configPath))['hop1Node'], 'OLD-1');

    await manager.updateConfig(
      (c) => c.copyWith(hop1Node: 'NEW-1', hop2Node: 'NEW-2'),
      reloadCore: false,
    );
    final json = await readJson(configPath);
    expect(json['hop1Node'], 'NEW-1');
    expect(json['hop2Node'], 'NEW-2');

    // …and the payload still round-trips through the model unchanged.
    final restored = ChainProxyConfig.fromJson(json);
    expect(restored.hop1Node, 'NEW-1');
    expect(restored.hop2Node, 'NEW-2');
    expect(restored.enable, isTrue);
  });

  // ── C. the atomic mechanism is engaged (backup created, target intact) ───
  test('C. atomic write keeps a .bak of the previous good file', () async {
    await manager.updateConfig(
      (c) => c.copyWith(enable: true, hop1Node: 'A-1', hop2Node: 'A-2'),
      reloadCore: false,
    );
    // First save: target written, no backup yet (nothing existed before).
    expect(File('$configPath.bak').existsSync(), isFalse);

    await manager.updateConfig(
      (c) => c.copyWith(hop1Node: 'B-1'),
      reloadCore: false,
    );
    // Second save: the previous good file is preserved as `.bak`.
    expect(File('$configPath.bak').existsSync(), isTrue);
    expect((await readJson(configPath))['hop1Node'], 'B-1');
    expect((await readJson('$configPath.bak'))['hop1Node'], 'A-1');
  });

  // ── D. recovery from `.bak` when the main file is corrupted ─────────────
  test(
    'D. corrupt main file recovers from the .bak of the same path',
    () async {
      await manager.updateConfig(
        (c) => c.copyWith(enable: true, hop1Node: 'GOOD-1', hop2Node: 'GOOD-2'),
        reloadCore: false,
      );
      await manager.updateConfig(
        (c) => c.copyWith(hop1Node: 'GOOD-3'),
        reloadCore: false,
      );
      // Simulate a crash that truncated the main file.
      await File(configPath).writeAsString('{ truncated', flush: true);

      final recovered = await AtomicConfigStorage(configPath).load();
      expect(recovered, isNotNull);
      expect(recovered!['hop1Node'], 'GOOD-1', reason: 'restored from .bak');
    },
  );

  // ── E. the three persistence paths never collide ────────────────────────
  test('E. the three persistence paths use independent files', () async {
    await manager.updateConfig(
      (c) => c.copyWith(enable: true, hop1Node: 'E-1', hop2Node: 'E-2'),
      reloadCore: false,
    );
    await manager.updateFallbackPool(
      (_) => const ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'E-EXIT',
            role: FallbackCandidateRole.exit,
          ),
        ],
      ),
    );
    await manager.flushReliabilityStats();

    // Each file exists and carries only its own shape.
    expect(File(configPath).existsSync(), isTrue);
    expect(File(poolPath).existsSync(), isTrue);

    final config = await readJson(configPath);
    final pool = await readJson(poolPath);
    expect(config.containsKey('hop1Node'), isTrue);
    expect(config.containsKey('exitCandidates'), isFalse);
    expect(pool.containsKey('exitCandidates'), isTrue);
    expect(pool.containsKey('hop1Node'), isFalse);
    // Different files, no cross-write.
    expect(File(configPath).path, isNot(File(poolPath).path));
  });

  // ── F. reliability schema is unchanged (version 1, same shape) ──────────
  test(
    'F. reliability stats keep version:1 and the role→node→fp shape',
    () async {
      await manager.updateFallbackPool(
        (_) => const ChainFallbackPool(
          exitCandidates: [
            ChainFallbackCandidate(
              nodeName: 'F-EXIT',
              role: FallbackCandidateRole.exit,
            ),
          ],
        ),
      );
      ChainProxyManager.chainProbeOverride = (cfg) async => ChainProbeReport(
        mode: cfg.hopMode,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.failed,
        failureHop: 2,
        hops: [
          HopProbeState(
            hopIndex: 2,
            role: HopRole.hop2Exit,
            nodeName: 'F-EXIT',
            nodeAddress: '127.0.0.1',
            status: HopProbeStatus.timeout,
            healthStatus: ChainHealthStatus.failed,
          ),
        ],
        timestamp: DateTime.now(),
      );
      await manager.probeCurrentChain();
      await manager.flushReliabilityStats();

      final json = await readJson(statsPath);
      expect(json['version'], 1, reason: 'schema version must stay 1');
      expect(json.containsKey('statsByContext'), isTrue);
      final exit = (json['statsByContext'] as Map)['exit'] as Map;
      expect(exit.containsKey('F-EXIT'), isTrue);
    },
  );

  // ── G. fallback pool still persists config only (no runtime fields) ─────
  test('G. fallback pool persistence excludes runtime-only fields', () async {
    await manager.updateFallbackPool(
      (_) => const ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'G-EXIT',
            role: FallbackCandidateRole.exit,
            priority: 7,
          ),
        ],
      ),
    );

    final json = await readJson(poolPath);
    final candidate =
        ((json['exitCandidates'] as List).first) as Map<String, dynamic>;
    // Persisted (P1.1-E boundary).
    expect(candidate['nodeName'], 'G-EXIT');
    expect(candidate['role'], 'exit');
    expect(candidate.containsKey('enabled'), isTrue);
    expect(candidate.containsKey('priority'), isTrue);
    // Never persisted.
    for (final runtimeKey in [
      'health',
      'latencyMs',
      'lastChecked',
      'statsByContext',
      'cooldownUntil',
      'networkFingerprint',
    ]) {
      expect(
        candidate.containsKey(runtimeKey),
        isFalse,
        reason: '$runtimeKey must stay RAM-only',
      );
    }
  });
}
