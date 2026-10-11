import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:path/path.dart' as p;

/// P1.1-E — Fallback Pool persistence + CRUD.
///
/// The pool persists ONLY its *configuration* (nodeName / role / enabled /
/// priority). Runtime telemetry (health / latencyMs / lastChecked /
/// statsByContext / cooldownUntil) must never be written to disk — it stays
/// RAM-only and is P2 scope.
///
/// Persistence tests use [ChainProxyManager.fallbackPoolFilePathOverride] so
/// they never touch the real application data directory.
void main() {
  late Directory tmp;
  late String poolPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_pool_unit_');
    poolPath = p.join(tmp.path, 'chain_fallback_pool.json');
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;
  });

  tearDown(() {
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  group('ChainFallbackPool config-only serialization', () {
    test('empty pool serializes and deserializes', () {
      const pool = ChainFallbackPool();
      final json = pool.toJson();
      expect(json['entryCandidates'] as List, isEmpty);
      expect(json['relayCandidates'] as List, isEmpty);
      expect(json['exitCandidates'] as List, isEmpty);

      final restored = ChainFallbackPool.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(restored.isEmpty, isTrue);
      expect(restored.totalCandidateCount, 0);
    });

    test('multiple candidates round-trip with role + flags preserved', () {
      const pool = ChainFallbackPool(
        entryCandidates: [
          ChainFallbackCandidate(
            nodeName: 'HK-01',
            role: FallbackCandidateRole.entry,
            priority: 1,
          ),
          ChainFallbackCandidate(
            nodeName: 'JP-02',
            role: FallbackCandidateRole.entry,
            enabled: false,
            priority: 3,
          ),
        ],
        relayCandidates: [
          ChainFallbackCandidate(
            nodeName: 'SG-03',
            role: FallbackCandidateRole.relay,
          ),
        ],
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'US-04',
            role: FallbackCandidateRole.exit,
          ),
        ],
      );

      final restored = ChainFallbackPool.fromJson(
        jsonDecode(jsonEncode(pool.toJson())) as Map<String, dynamic>,
      );

      expect(restored.totalCandidateCount, 4);
      expect(
        restored.entryCandidates.map((c) => c.nodeName).toList(),
        ['HK-01', 'JP-02'],
      );
      expect(restored.entryCandidates[0].priority, 1);
      expect(restored.entryCandidates[1].priority, 3);
      expect(restored.entryCandidates[1].enabled, isFalse);
      expect(restored.relayCandidates.single.nodeName, 'SG-03');
      expect(restored.relayCandidates.single.role, FallbackCandidateRole.relay);
      expect(restored.exitCandidates.single.nodeName, 'US-04');
      expect(restored.exitCandidates.single.role, FallbackCandidateRole.exit);
    });

    test('config-only JSON excludes runtime telemetry', () {
      final stats = ChainReliabilityStats(
        weightedSuccess: 5,
        weightedFailure: 1,
        consecutiveFailures: 0,
        lastUpdated: DateTime(2026, 1, 1),
        totalSamples: 6,
        networkFingerprint: 'fp-1',
      );
      final pool = ChainFallbackPool(
        entryCandidates: [
          ChainFallbackCandidate(
            nodeName: 'HK-01',
            role: FallbackCandidateRole.entry,
            health: ChainHealthStatus.healthy,
            latencyMs: 88,
            lastChecked: DateTime(2026, 1, 1),
            statsByContext: {'fp-1': stats},
            cooldownUntil: DateTime(2026, 1, 2),
          ),
        ],
      );

      final entry =
          (pool.toJson()['entryCandidates'] as List).first
              as Map<String, dynamic>;
      expect(entry.keys.toSet(), {'nodeName', 'role', 'enabled', 'priority'});
      expect(entry.containsKey('health'), isFalse);
      expect(entry.containsKey('latencyMs'), isFalse);
      expect(entry.containsKey('lastChecked'), isFalse);
      expect(entry.containsKey('statsByContext'), isFalse);
      expect(entry.containsKey('cooldownUntil'), isFalse);
    });

    test('includeRuntimeState:true does carry runtime telemetry (control)', () {
      final pool = ChainFallbackPool(
        entryCandidates: [
          ChainFallbackCandidate(
            nodeName: 'HK-01',
            role: FallbackCandidateRole.entry,
            health: ChainHealthStatus.healthy,
            latencyMs: 88,
          ),
        ],
      );
      final entry =
          (pool.toJson(includeRuntimeState: true)['entryCandidates'] as List)
                  .first
              as Map<String, dynamic>;
      expect(entry['health'], 'healthy');
      expect(entry['latencyMs'], 88);
    });
  });

  group('ChainProxyManager fallback pool CRUD + persistence', () {
    late ChainProxyManager manager;

    setUp(() async {
      manager = ChainProxyManager();
      await manager.updateFallbackPool((_) => const ChainFallbackPool());
    });

    test('addFallbackCandidate persists config-only and is idempotent',
        () async {
      await manager.addFallbackCandidate(
        nodeName: 'HK-01',
        role: FallbackCandidateRole.entry,
      );
      await manager.addFallbackCandidate(
        nodeName: 'HK-01',
        role: FallbackCandidateRole.entry,
      );
      expect(manager.fallbackPool.entryCandidates.length, 1);

      final file = File(poolPath);
      expect(file.existsSync(), isTrue);
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final entry =
          (raw['entryCandidates'] as List).first as Map<String, dynamic>;
      expect(entry['nodeName'], 'HK-01');
      expect(entry['role'], 'entry');
      expect(entry.containsKey('health'), isFalse);
      expect(entry.containsKey('statsByContext'), isFalse);
    });

    test('blank node name is ignored', () async {
      await manager.addFallbackCandidate(
        nodeName: '   ',
        role: FallbackCandidateRole.entry,
      );
      expect(manager.fallbackPool.isEmpty, isTrue);
    });

    test('removeFallbackCandidate removes only the matching role bucket',
        () async {
      await manager.addFallbackCandidate(
        nodeName: 'A',
        role: FallbackCandidateRole.entry,
      );
      await manager.addFallbackCandidate(
        nodeName: 'A',
        role: FallbackCandidateRole.exit,
      );
      await manager.removeFallbackCandidate(
        nodeName: 'A',
        role: FallbackCandidateRole.entry,
      );

      expect(manager.fallbackPool.entryCandidates, isEmpty);
      expect(manager.fallbackPool.exitCandidates.single.nodeName, 'A');
    });

    test('setFallbackCandidateEnabled toggles and persists', () async {
      await manager.addFallbackCandidate(
        nodeName: 'A',
        role: FallbackCandidateRole.entry,
      );
      await manager.setFallbackCandidateEnabled(
        nodeName: 'A',
        role: FallbackCandidateRole.entry,
        enabled: false,
      );
      expect(manager.fallbackPool.entryCandidates.single.enabled, isFalse);

      final raw = jsonDecode(File(poolPath).readAsStringSync())
          as Map<String, dynamic>;
      final entry =
          (raw['entryCandidates'] as List).first as Map<String, dynamic>;
      expect(entry['enabled'], isFalse);
    });

    test('setFallbackCandidateRole moves a candidate between buckets',
        () async {
      await manager.addFallbackCandidate(
        nodeName: 'A',
        role: FallbackCandidateRole.entry,
      );
      await manager.setFallbackCandidateRole(
        nodeName: 'A',
        fromRole: FallbackCandidateRole.entry,
        toRole: FallbackCandidateRole.relay,
      );
      expect(manager.fallbackPool.entryCandidates, isEmpty);
      expect(manager.fallbackPool.relayCandidates.single.nodeName, 'A');
      expect(
        manager.fallbackPool.relayCandidates.single.role,
        FallbackCandidateRole.relay,
      );
    });

    test('restore: persisted file reloads into an equal pool', () async {
      await manager.addFallbackCandidate(
        nodeName: 'HK-01',
        role: FallbackCandidateRole.entry,
      );
      await manager.addFallbackCandidate(
        nodeName: 'US-02',
        role: FallbackCandidateRole.exit,
      );
      await manager.setFallbackCandidateEnabled(
        nodeName: 'US-02',
        role: FallbackCandidateRole.exit,
        enabled: false,
      );

      // Same decode step as `ChainProxyManager.init()` performs on startup.
      final raw = jsonDecode(File(poolPath).readAsStringSync())
          as Map<String, dynamic>;
      final restored = ChainFallbackPool.fromJson(raw);

      expect(restored.totalCandidateCount, 2);
      expect(restored.entryCandidates.single.nodeName, 'HK-01');
      expect(restored.entryCandidates.single.enabled, isTrue);
      expect(restored.exitCandidates.single.nodeName, 'US-02');
      expect(restored.exitCandidates.single.enabled, isFalse);
    });

    test('setFallbackPool (D1/D2 runtime path) does NOT persist', () async {
      await manager.addFallbackCandidate(
        nodeName: 'A',
        role: FallbackCandidateRole.entry,
      );
      final before = File(poolPath).readAsStringSync();

      // Simulate the D1/D2 probe write-back: runtime telemetry only.
      final runtimePool = manager.fallbackPool.copyWith(
        entryCandidates: [
          manager.fallbackPool.entryCandidates.single.copyWith(
            health: ChainHealthStatus.healthy,
            latencyMs: 42,
          ),
        ],
      );
      await manager.setFallbackPool(runtimePool);

      expect(File(poolPath).readAsStringSync(), before);
      expect(manager.fallbackPool.entryCandidates.single.latencyMs, 42);
    });
  });
}
