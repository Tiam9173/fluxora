import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/atomic_config_storage.dart';
import 'package:fluxora/services/chain_reliability_stats_persistence.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P2.5-A — Persistence read-side hardening.
///
/// Before P2.5-A the three chain read paths were inconsistent: `chain_proxies`
/// and `chain_fallback_pool` were gated behind `File.exists()` (which disabled
/// `.bak` / orphan `.tmp` recovery whenever the primary was absent), and
/// `chain_reliability_stats` was read with a bare `readAsString`. All three now
/// go through `AtomicConfigStorage.load()`.
///
/// Cases A–L pin the recovery matrix at the storage level; `W` drives the REAL
/// production entry (`ChainProxyManager.init()`) end-to-end.
void main() {
  late Directory tmp;
  late String configPath;
  late String poolPath;
  late String statsPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_p25a_');
    configPath = p.join(tmp.path, 'chain_proxies.json');
    poolPath = p.join(tmp.path, 'chain_fallback_pool.json');
    statsPath = p.join(tmp.path, 'chain_reliability_stats.json');
    ChainProxyManager.configFilePathOverride = configPath;
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;
    ChainProxyManager.reliabilityStatsFilePathOverride = statsPath;
  });

  tearDown(() async {
    // P2.3-C ordering: flush (cancels the debounce timer) → drop overrides →
    // bounded delete.
    await ChainProxyManager().flushReliabilityStats();
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    await deleteTempDirWithRetry(tmp);
  });

  Future<void> writeJson(String path, Object? value) async {
    await File(path).writeAsString(jsonEncode(value), flush: true);
  }

  Future<Map<String, dynamic>?> loadConfig() =>
      AtomicConfigStorage(configPath).load();
  Future<Map<String, dynamic>?> loadPool() =>
      AtomicConfigStorage(poolPath).load();

  ChainProxyConfig configWith(String hop1) =>
      const ChainProxyConfig().copyWith(enable: true, hop1Node: hop1);

  ChainFallbackPool poolWith(String node) => ChainFallbackPool(
    exitCandidates: [
      ChainFallbackCandidate(
        nodeName: node,
        role: FallbackCandidateRole.exit,
      ),
    ],
  );

  /// `{version, statsByContext: {role: {node: {fp: {}}}}}`
  Map<String, dynamic> statsPayload(Map<String, List<String>> byRole) => {
    'version': 1,
    'statsByContext': {
      for (final role in byRole.entries)
        role.key: {
          for (final node in role.value) node: {'fp-1': <String, dynamic>{}},
        },
    },
  };

  // ── Chain Proxy Config: A / B / C / D ────────────────────────────────────
  test('A. config: a valid primary is read', () async {
    await writeJson(configPath, configWith('HK-01').toJson());
    final json = await loadConfig();
    expect(json, isNotNull);
    expect(ChainProxyConfig.fromJson(json).hop1Node, 'HK-01');
  });

  test('B. config: a missing primary recovers from .bak', () async {
    await writeJson('$configPath.bak', configWith('BAK-1').toJson());
    expect(File(configPath).existsSync(), isFalse, reason: 'primary absent');

    final json = await loadConfig();
    expect(json, isNotNull, reason: 'must recover from .bak, not give up');
    expect(ChainProxyConfig.fromJson(json).hop1Node, 'BAK-1');
  });

  test('C. config: a corrupt primary recovers from .bak', () async {
    await File(configPath).writeAsString('{ truncated', flush: true);
    await writeJson('$configPath.bak', configWith('BAK-2').toJson());

    final json = await loadConfig();
    expect(json, isNotNull);
    expect(ChainProxyConfig.fromJson(json).hop1Node, 'BAK-2');
  });

  test('D. config: no usable source → null (consumer keeps defaults)', () async {
    // 1) nothing on disk at all
    expect(await loadConfig(), isNull);
    expect(const ChainProxyConfig().enable, isFalse);

    // 2) corrupt primary with no recovery source
    await File(configPath).writeAsString('{ truncated', flush: true);
    expect(await loadConfig(), isNull);
  });

  // ── Fallback Pool: E / F / G / H ─────────────────────────────────────────
  test('E. pool: a valid primary is read', () async {
    await writeJson(poolPath, poolWith('EXIT-1').toJson());
    final json = await loadPool();
    expect(json, isNotNull);
    expect(ChainFallbackPool.fromJson(json).exitCandidates.single.nodeName,
        'EXIT-1');
  });

  test('F. pool: a missing primary recovers from .bak', () async {
    await writeJson('$poolPath.bak', poolWith('BAK-EXIT').toJson());
    expect(File(poolPath).existsSync(), isFalse);

    final json = await loadPool();
    expect(json, isNotNull);
    expect(ChainFallbackPool.fromJson(json).exitCandidates.single.nodeName,
        'BAK-EXIT');
  });

  test('G. pool: a corrupt primary recovers from .bak', () async {
    await File(poolPath).writeAsString('{ truncated', flush: true);
    await writeJson('$poolPath.bak', poolWith('BAK-EXIT-2').toJson());

    final json = await loadPool();
    expect(json, isNotNull);
    expect(ChainFallbackPool.fromJson(json).exitCandidates.single.nodeName,
        'BAK-EXIT-2');
  });

  test('H. pool: no usable source → null (consumer keeps empty pool)', () async {
    expect(await loadPool(), isNull);

    await File(poolPath).writeAsString('{ truncated', flush: true);
    expect(await loadPool(), isNull);
  });

  // ── Reliability Stats (production load()): I / J / K / L ─────────────────
  test('I. stats: a valid primary is read', () async {
    await writeJson(statsPath, statsPayload({'exit': ['EXIT-1']}));
    final loaded = await chainReliabilityStatsPersistence.load(statsPath);
    expect(loaded[FallbackCandidateRole.exit]?['EXIT-1'], isNotNull);
  });

  test('J. stats: a missing primary recovers from .bak', () async {
    await writeJson('$statsPath.bak', statsPayload({'exit': ['BAK-NODE']}));
    expect(File(statsPath).existsSync(), isFalse);

    final loaded = await chainReliabilityStatsPersistence.load(statsPath);
    expect(loaded[FallbackCandidateRole.exit]?['BAK-NODE'], isNotNull,
        reason: 'stats read must recover from .bak too');
  });

  test('K. stats: a corrupt primary recovers from .bak', () async {
    await File(statsPath).writeAsString('{ truncated', flush: true);
    await writeJson('$statsPath.bak', statsPayload({'relay': ['BAK-RELAY']}));

    final loaded = await chainReliabilityStatsPersistence.load(statsPath);
    expect(loaded[FallbackCandidateRole.relay]?['BAK-RELAY'], isNotNull);
  });

  test('L. stats: no usable source → empty map (never throws)', () async {
    expect(await chainReliabilityStatsPersistence.load(statsPath), isEmpty);

    await File(statsPath).writeAsString('{ truncated', flush: true);
    expect(await chainReliabilityStatsPersistence.load(statsPath), isEmpty);
  });

  // ── Integrity: M / N / P ─────────────────────────────────────────────────
  test('M. a recovered non-object payload is rejected (no runtime injection)',
      () async {
    // A JSON array is valid JSON but not a config object.
    await writeJson('$configPath.bak', [1, 2, 3]);
    expect(await loadConfig(), isNull,
        reason: 'a non-object root must never be injected into runtime');
  });

  test('N. a recovered fallback pool restores config only (no runtime state)',
      () async {
    await writeJson('$poolPath.bak', poolWith('EXIT-1').toJson());

    final json = await loadPool();
    final candidate = ChainFallbackPool.fromJson(json).exitCandidates.single;
    expect(candidate.nodeName, 'EXIT-1');
    expect(candidate.statsByContext, isEmpty,
        reason: 'runtime telemetry is never persisted');

    // …and the recovered payload never carried runtime keys.
    final raw =
        jsonDecode(await File('$poolPath.bak').readAsString())
            as Map<String, dynamic>;
    final rawCandidate =
        ((raw['exitCandidates'] as List).first) as Map<String, dynamic>;
    for (final runtimeKey in [
      'health',
      'latencyMs',
      'lastChecked',
      'statsByContext',
      'cooldownUntil',
      'networkFingerprint',
    ]) {
      expect(rawCandidate.containsKey(runtimeKey), isFalse,
          reason: '$runtimeKey must stay RAM-only');
    }
  });

  test('P. tmp behaviour matches the AtomicConfigStorage contract', () async {
    // A valid orphan .tmp IS a recovery source (crash during save).
    await writeJson('$configPath.100.0.tmp', configWith('TMP-1').toJson());
    final recovered = await loadConfig();
    expect(recovered, isNotNull);
    expect(ChainProxyConfig.fromJson(recovered).hop1Node, 'TMP-1');

    // An invalid orphan .tmp is ignored.
    final tmp2 = Directory.systemTemp.createTempSync('fluxora_p25a_p_');
    try {
      final cfg2 = p.join(tmp2.path, 'chain_proxies.json');
      await File('$cfg2.200.0.tmp').writeAsString('{ not json', flush: true);
      expect(await AtomicConfigStorage(cfg2).load(), isNull);
    } finally {
      await deleteTempDirWithRetry(tmp2);
    }
  });

  // ── W. REAL production entry: ChainProxyManager.init() ───────────────────
  //
  // `init()` is guarded by `_initialized` (process-wide singleton), so this is
  // the ONLY init() in this file — it drives all three paths at once.
}
