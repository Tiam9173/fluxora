import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_reliability_stats_persistence.dart';
import 'package:path/path.dart' as p;

/// P2.1 — Reliability Stats Persistence.
///
/// The production-path group goes through the REAL manager write-back
/// (`probeCurrentChain` → `_writeBackProbeResultsToCandidates` → `recordEvent`
/// → `statsByContext` → `_scheduleReliabilityPersist` → debounced persistence).
/// `setFallbackPool` is memory-only and is NOT on this path. Statistics are
/// never injected by hand to fake the result.
void main() {
  late Directory tmp;
  late String statsPath;
  late ChainProxyManager manager;

  const fp = 'wifi_default';

  ChainReliabilityStats stats({
    double ws = 3.0,
    double wf = 1.0,
    int cf = 0,
    int total = 4,
  }) => ChainReliabilityStats(
    weightedSuccess: ws,
    weightedFailure: wf,
    consecutiveFailures: cf,
    lastUpdated: DateTime(2026, 1, 2, 3, 4, 5),
    totalSamples: total,
    networkFingerprint: fp,
  );

  Map<FallbackCandidateRole, Map<String, Map<String, ChainReliabilityStats>>>
  byRole({
    required FallbackCandidateRole role,
    required String node,
    required Map<String, ChainReliabilityStats> byFp,
  }) => {
    role: {
      node: byFp,
    },
  };

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('fluxora_p21_');
    statsPath = p.join(tmp.path, 'chain_reliability_stats.json');
    ChainProxyManager.reliabilityStatsFilePathOverride = statsPath;
    ChainProxyManager.configFilePathOverride = p.join(
      tmp.path,
      'chain_proxies.json',
    );
    ChainProxyManager.fallbackPoolFilePathOverride = p.join(
      tmp.path,
      'chain_fallback_pool.json',
    );
    ChainProxyManager.chainProbeOverride = null;
    manager = ChainProxyManager();
    await manager.updateConfig(
      (_) => const ChainProxyConfig(
        enable: true,
        hop1Node: 'HK-01',
        hop2Node: 'US-01',
      ),
    );
    await manager.updateFallbackPool((_) => const ChainFallbackPool());
  });

  tearDown(() async {
    // Flush BEFORE dropping the override so a pending debounce can never write
    // to the real application data directory.
    await manager.flushReliabilityStats();
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.chainProbeOverride = null;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  // ── A–D. Model / service round-trip ───────────────────────────────────────
  group('P2.1 persistence service', () {
    const service = ChainReliabilityStatsPersistence();

    test('A. encode → decode round-trips the core counters', () {
      final encoded = service.encode(
        byRole(
          role: FallbackCandidateRole.exit,
          node: 'US-FB-01',
          byFp: {fp: stats()},
        ),
      );
      final json = jsonDecode(jsonEncode(encoded)) as Map<String, dynamic>;
      final decoded = service.decode(json);

      final restored = decoded[FallbackCandidateRole.exit]!['US-FB-01']![fp]!;
      expect(restored.weightedSuccess, 3.0);
      expect(restored.weightedFailure, 1.0);
      expect(restored.consecutiveFailures, 0);
      expect(restored.totalSamples, 4);
      expect(restored.networkFingerprint, fp);
      expect(restored.lastUpdated, DateTime(2026, 1, 2, 3, 4, 5));
    });

    test('B. empty stats encode/decode safely', () {
      final encoded = service.encode(const {});
      expect(encoded['version'], ChainReliabilityStatsPersistence.schemaVersion);
      expect(service.decode(encoded), isEmpty);
      expect(service.decode(null), isEmpty);
    });

    test('C. multiple fingerprints stay independent (never merged)', () {
      final decoded = service.decode(
        jsonDecode(
              jsonEncode(
                service.encode(
                  byRole(
                    role: FallbackCandidateRole.exit,
                    node: 'US-FB-01',
                    byFp: {
                      'wifi_default': stats(ws: 5, total: 5),
                      'cellular_default': stats(ws: 0, wf: 4, cf: 4, total: 4),
                    },
                  ),
                ),
              ),
            )
            as Map<String, dynamic>,
      );
      final byFp = decoded[FallbackCandidateRole.exit]!['US-FB-01']!;
      expect(byFp.length, 2);
      expect(byFp['wifi_default']!.weightedSuccess, 5.0);
      expect(byFp['cellular_default']!.consecutiveFailures, 4);
    });

    test('D. aggregated statistics survive save → load', () async {
      await service.save(
        statsPath,
        byRole(
          role: FallbackCandidateRole.exit,
          node: 'US-FB-01',
          byFp: {fp: stats(ws: 7, wf: 2, cf: 1, total: 9)},
        ),
      );
      final loaded = await service.load(statsPath);
      final restored = loaded[FallbackCandidateRole.exit]!['US-FB-01']![fp]!;
      expect(restored.weightedSuccess, 7.0);
      expect(restored.weightedFailure, 2.0);
      expect(restored.consecutiveFailures, 1);
      expect(restored.totalSamples, 9);
    });

    test('E. corrupt JSON → empty result, no crash, file untouched', () async {
      File(statsPath).writeAsStringSync('{ this is not json ');
      final loaded = await service.load(statsPath);
      expect(loaded, isEmpty);
      expect(File(statsPath).existsSync(), isTrue, reason: 'never delete data');
    });

    test('F. missing fields → safe defaults', () {
      final decoded = service.decode({
        'statsByContext': {
          'exit': {
            'US-FB-01': {
              'wifi_default': {'totalSamples': 3},
            },
          },
        },
      });
      final restored = decoded[FallbackCandidateRole.exit]!['US-FB-01']![fp]!;
      expect(restored.totalSamples, 3);
      expect(restored.weightedSuccess, 0.0);
      expect(restored.networkFingerprint, fp, reason: 'falls back to the key');
    });

    test('G. unknown fields / roles are ignored, no crash', () {
      // P2.5-C: this used to pass `'version': 99` (a FUTURE version) and expect
      // a successful decode. That is exactly the behaviour P2.5-C forbids — a
      // newer schema must never be decoded as v1. The "unknown fields/roles are
      // ignored" intent is preserved here with the CURRENT version; future /
      // invalid versions are pinned in `persistence_schema_version_test.dart`.
      final decoded = service.decode({
        'version': 1,
        'somethingNew': {'a': 1},
        'statsByContext': {
          'notARole': {
            'X': {'fp': {'totalSamples': 1}},
          },
          'exit': {
            'US-FB-01': {
              'wifi_default': {'totalSamples': 2, 'brandNewField': true},
            },
          },
        },
      });
      expect(decoded.containsKey(FallbackCandidateRole.exit), isTrue);
      expect(
        decoded[FallbackCandidateRole.exit]!['US-FB-01']![fp]!.totalSamples,
        2,
      );
    });

    test('H. save failure is reported but never throws', () async {
      // A directory where the file should be → write must fail.
      final asDir = p.join(tmp.path, 'blocked.json');
      Directory(asDir).createSync();
      final ok = await service.save(asDir, byRole(
        role: FallbackCandidateRole.exit,
        node: 'US-FB-01',
        byFp: {fp: stats()},
      ));
      expect(ok, isFalse);
    });
  });

  // ── I. Production path + restart E2E ──────────────────────────────────────
  group('P2.1 production path', () {
    test('I. real probe → debounced persist → load → restore', () async {
      await manager.updateFallbackPool(
        (_) => const ChainFallbackPool(
          exitCandidates: [
            ChainFallbackCandidate(
              nodeName: 'US-FB-01',
              role: FallbackCandidateRole.exit,
            ),
          ],
        ),
      );

      // REAL production write-back path (D1/F2) — only the network probe is
      // stubbed, via the existing seam.
      ChainProxyManager.chainProbeOverride = (cfg) async => ChainProbeReport(
        mode: cfg.hopMode,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.failed,
        failureHop: 2,
        hops: [
          HopProbeState(
            hopIndex: 2,
            role: HopRole.hop2Exit,
            nodeName: 'US-FB-01',
            nodeAddress: '127.0.0.1',
            status: HopProbeStatus.timeout,
            healthStatus: ChainHealthStatus.failed,
          ),
        ],
        timestamp: DateTime.now(),
      );
      await manager.probeCurrentChain();

      // A pending debounced write must exist (not yet flushed).
      expect(manager.hasPendingReliabilityPersist, isTrue);
      expect(File(statsPath).existsSync(), isFalse,
          reason: 'writes must be debounced, not immediate');

      await manager.flushReliabilityStats();
      expect(File(statsPath).existsSync(), isTrue);

      // Simulated restart: a fresh read of the file (what `init()` does).
      final loaded = await chainReliabilityStatsPersistence.load(statsPath);
      final restored =
          loaded[FallbackCandidateRole.exit]!['US-FB-01']!['unknown_default']!;
      expect(restored.totalSamples, 1);
      expect(restored.consecutiveFailures, 1);

      // And the ranking reads the restored values through the same model.
      manager.applyRestoredReliabilityStatsForTest(loaded);
      final live = manager
          .fallbackPool
          .exitCandidates
          .single
          .statsByContext['unknown_default'];
      expect(live!.totalSamples, restored.totalSamples);
      expect(live.weightedFailure, restored.weightedFailure);
    });
  });

  // ── P2.3-A (B-2): exit-path flush ─────────────────────────────────────────
  //
  // The manager persists reliability statistics behind a 2s debounce. The exit
  // path must therefore flush explicitly, otherwise any sample recorded inside
  // the last debounce window is lost on quit.
  group('P2.3-A (B-2) exit flush', () {
    ChainProbeReport failedExitProbe(ChainProxyConfig cfg) => ChainProbeReport(
      mode: cfg.hopMode,
      isOverallHealthy: false,
      healthStatus: ChainHealthStatus.failed,
      failureHop: 2,
      hops: [
        HopProbeState(
          hopIndex: 2,
          role: HopRole.hop2Exit,
          nodeName: 'US-FB-01',
          nodeAddress: '127.0.0.1',
          status: HopProbeStatus.timeout,
          healthStatus: ChainHealthStatus.failed,
        ),
      ],
      timestamp: DateTime.now(),
    );

    Future<void> seedPool() => manager.updateFallbackPool(
      (_) => const ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'US-FB-01',
            role: FallbackCandidateRole.exit,
          ),
        ],
      ),
    );

    test('J. exit path calls flushReliabilityStats() before core shutdown', () {
      final source = File('lib/controller.dart').readAsStringSync();
      final start = source.indexOf('Future<void> handleExit()');
      expect(start, greaterThanOrEqualTo(0), reason: 'handleExit must exist');

      // Scope to the handleExit body (up to the next top-level method).
      final rest = source.substring(start);
      final nextMethod = rest.indexOf('\n  Future ', 1);
      final body = nextMethod > 0 ? rest.substring(0, nextMethod) : rest;

      final flushIdx = body.indexOf('flushReliabilityStats()');
      final shutdownIdx = body.indexOf('clashCore.shutdown()');
      expect(
        flushIdx,
        greaterThanOrEqualTo(0),
        reason: 'handleExit must flush the debounced reliability stats',
      );
      expect(shutdownIdx, greaterThanOrEqualTo(0));
      expect(
        flushIdx,
        lessThan(shutdownIdx),
        reason: 'the flush must happen before the core is shut down',
      );
    });

    test('K. flush persists the LATEST sample (what the exit path relies on)',
        () async {
      await seedPool();
      ChainProxyManager.chainProbeOverride = (cfg) async =>
          failedExitProbe(cfg);

      await manager.probeCurrentChain(); // sample 1
      await manager.probeCurrentChain(); // sample 2

      expect(manager.hasPendingReliabilityPersist, isTrue);
      expect(
        File(statsPath).existsSync(),
        isFalse,
        reason: 'writes stay debounced until flushed',
      );

      await manager.flushReliabilityStats(); // ← the exit-path flush

      final loaded = await chainReliabilityStatsPersistence.load(statsPath);
      final restored =
          loaded[FallbackCandidateRole.exit]!['US-FB-01']!['unknown_default']!;
      expect(restored.totalSamples, 2, reason: 'both samples must survive');
      expect(restored.consecutiveFailures, 2);
    });

    test('L. flush never blocks or throws when the save target is unwritable',
        () async {
      // A directory where the stats file should be → every save fails.
      final asDir = p.join(tmp.path, 'blocked_stats.json');
      Directory(asDir).createSync();
      ChainProxyManager.reliabilityStatsFilePathOverride = asDir;

      await seedPool();
      ChainProxyManager.chainProbeOverride = (cfg) async =>
          failedExitProbe(cfg);
      await manager.probeCurrentChain();
      expect(manager.hasPendingReliabilityPersist, isTrue);

      // Mirrors the exit path's bounded await: must complete promptly and never
      // throw, so a persistence failure can never block shutdown.
      await manager
          .flushReliabilityStats()
          .timeout(const Duration(seconds: 3));
      expect(manager.hasPendingReliabilityPersist, isFalse);
    });
  });
}
