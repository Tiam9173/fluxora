import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_reliability_stats_persistence.dart';
import 'package:fluxora/services/persistence_schema.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P2.5-C (CF-2) — persistence schema version / migration contract.
///
/// The `version` key must genuinely gate decoding, not merely be read. A–F pin
/// the pure contract; G–N drive the REAL production load path
/// (`ChainReliabilityStatsPersistence.load` → `AtomicConfigStorage`); O drives
/// `ChainProxyManager.init()`.
///
/// There is no fabricated v1→v2 migration: the only migration is
/// `legacy (absent) → v1`, which is a no-op decode.
void main() {
  late Directory tmp;
  late String statsPath;
  late String configPath;
  late String poolPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_p25c_');
    statsPath = p.join(tmp.path, 'chain_reliability_stats.json');
    configPath = p.join(tmp.path, 'chain_proxies.json');
    poolPath = p.join(tmp.path, 'chain_fallback_pool.json');
    ChainProxyManager.configFilePathOverride = configPath;
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;
    ChainProxyManager.reliabilityStatsFilePathOverride = statsPath;
  });

  tearDown(() async {
    // P2.3-C ordering: flush → drop overrides → bounded delete.
    await ChainProxyManager().flushReliabilityStats();
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    await deleteTempDirWithRetry(tmp);
  });

  Future<void> writeJson(String path, Object? value) async {
    await File(path).writeAsString(jsonEncode(value), flush: true);
  }

  /// A structurally valid reliability payload (one exit node / one fingerprint).
  Map<String, dynamic> statsBody() => {
    'statsByContext': {
      'exit': {
        'EXIT-1': {'fp-1': <String, dynamic>{}},
      },
    },
  };

  ChainFallbackPool poolWith(String node) => ChainFallbackPool(
    exitCandidates: [
      ChainFallbackCandidate(
        nodeName: node,
        role: FallbackCandidateRole.exit,
      ),
    ],
  );

  ChainProxyConfig configWith(String hop1) =>
      const ChainProxyConfig().copyWith(enable: true, hop1Node: hop1);

  // ── A–F: the pure contract ───────────────────────────────────────────────
  group('A–F: PersistenceSchema contract', () {
    test('A. version == currentVersion → current', () {
      expect(
        PersistenceSchema.statusOf({'version': 1}),
        PersistenceSchemaStatus.current,
      );
    });

    test('B. missing version → legacy (implicit v1)', () {
      expect(
        PersistenceSchema.statusOf({'statsByContext': {}}),
        PersistenceSchemaStatus.legacy,
      );
    });

    test('C. a future version → unsupported', () {
      expect(
        PersistenceSchema.statusOf({'version': 999}),
        PersistenceSchemaStatus.unsupported,
      );
      expect(
        PersistenceSchema.statusOf({'version': 2}),
        PersistenceSchemaStatus.unsupported,
      );
    });

    test('D. version "1" (string) → invalid', () {
      expect(
        PersistenceSchema.statusOf({'version': '1'}),
        PersistenceSchemaStatus.invalid,
      );
    });

    test('E. version null (key present) → invalid', () {
      expect(
        PersistenceSchema.statusOf({'version': null}),
        PersistenceSchemaStatus.invalid,
      );
    });

    test('F. version 0 / negative / non-int → invalid', () {
      expect(
        PersistenceSchema.statusOf({'version': 0}),
        PersistenceSchemaStatus.invalid,
      );
      expect(
        PersistenceSchema.statusOf({'version': -3}),
        PersistenceSchemaStatus.invalid,
      );
      expect(
        PersistenceSchema.statusOf({'version': 1.0}),
        PersistenceSchemaStatus.invalid,
      );
      expect(
        PersistenceSchema.statusOf({'version': true}),
        PersistenceSchemaStatus.invalid,
      );
    });

    test('accepts() admits only current + legacy', () {
      expect(PersistenceSchema.accepts({'version': 1}), isTrue);
      expect(PersistenceSchema.accepts({'anything': 1}), isTrue);
      expect(PersistenceSchema.accepts({'version': 999}), isFalse);
      expect(PersistenceSchema.accepts({'version': '1'}), isFalse);
      expect(PersistenceSchema.accepts({'version': null}), isFalse);
    });

    test('stamp() adds the current version and preserves every key', () {
      final stamped = PersistenceSchema.stamp({
        'enable': true,
        'hop1Node': 'HK-01',
      });
      expect(stamped[PersistenceSchema.versionKey],
          PersistenceSchema.currentVersion);
      expect(stamped['enable'], isTrue);
      expect(stamped['hop1Node'], 'HK-01');
    });
  });

  // ── G–N: real production load path (reliability store) ───────────────────
  group('G–N: reliability store through the production load path', () {
    test('G. current version + valid data → decoded', () async {
      await writeJson(statsPath, {...statsBody(), 'version': 1});
      final loaded = await chainReliabilityStatsPersistence.load(statsPath);
      expect(loaded[FallbackCandidateRole.exit]?['EXIT-1'], isNotNull);
    });

    test('G2. legacy (no version key) + valid data → decoded as v1', () async {
      await writeJson(statsPath, statsBody());
      final loaded = await chainReliabilityStatsPersistence.load(statsPath);
      expect(loaded[FallbackCandidateRole.exit]?['EXIT-1'], isNotNull);
    });

    test('H. future version + otherwise valid data → NOT decoded', () async {
      await writeJson(statsPath, {...statsBody(), 'version': 999});
      expect(
        await chainReliabilityStatsPersistence.load(statsPath),
        isEmpty,
        reason: 'a newer schema must never be decoded as v1',
      );
    });

    test('H2. invalid version → NOT decoded', () async {
      await writeJson(statsPath, {...statsBody(), 'version': '1'});
      expect(await chainReliabilityStatsPersistence.load(statsPath), isEmpty);

      await writeJson(statsPath, {...statsBody(), 'version': null});
      expect(await chainReliabilityStatsPersistence.load(statsPath), isEmpty);

      await writeJson(statsPath, {...statsBody(), 'version': 0});
      expect(await chainReliabilityStatsPersistence.load(statsPath), isEmpty);
    });

    test('I. malformed JSON → empty, file untouched (unchanged behaviour)',
        () async {
      await File(statsPath).writeAsString('{ this is not json', flush: true);
      expect(await chainReliabilityStatsPersistence.load(statsPath), isEmpty);
      expect(File(statsPath).existsSync(), isTrue, reason: 'never delete data');
    });

    test('J. non-object JSON → empty, file untouched (unchanged behaviour)',
        () async {
      await File(statsPath).writeAsString('[1,2,3]', flush: true);
      expect(await chainReliabilityStatsPersistence.load(statsPath), isEmpty);
      expect(File(statsPath).existsSync(), isTrue);
    });

    test('K. unsupported primary + current .bak → recovered from .bak',
        () async {
      await writeJson(statsPath, {...statsBody(), 'version': 999});
      await writeJson('$statsPath.bak', {...statsBody(), 'version': 1});

      final loaded = await chainReliabilityStatsPersistence.load(statsPath);
      expect(
        loaded[FallbackCandidateRole.exit]?['EXIT-1'],
        isNotNull,
        reason: 'an unsupported primary must not block a valid .bak',
      );
    });

    test('L. unsupported primary + current orphan .tmp → recovered from .tmp',
        () async {
      await writeJson(statsPath, {...statsBody(), 'version': 999});
      await writeJson('$statsPath.100.0.tmp', {...statsBody(), 'version': 1});

      final loaded = await chainReliabilityStatsPersistence.load(statsPath);
      expect(loaded[FallbackCandidateRole.exit]?['EXIT-1'], isNotNull);
    });

    test('M. recovery neither overwrites the unsupported primary nor deletes .bak',
        () async {
      await writeJson(statsPath, {...statsBody(), 'version': 999});
      await writeJson('$statsPath.bak', {...statsBody(), 'version': 1});
      final primaryBefore = await File(statsPath).readAsString();

      await chainReliabilityStatsPersistence.load(statsPath);

      expect(File(statsPath).existsSync(), isTrue);
      expect(
        await File(statsPath).readAsString(),
        primaryBefore,
        reason: 'a newer-version primary must not be clobbered by recovery',
      );
      expect(File('$statsPath.bak').existsSync(), isTrue,
          reason: 'recovery must never delete data');
    });

    test('N. save still writes the current version', () async {
      await chainReliabilityStatsPersistence.save(statsPath, const {});
      final json =
          jsonDecode(await File(statsPath).readAsString())
              as Map<String, dynamic>;
      expect(json[PersistenceSchema.versionKey],
          PersistenceSchema.currentVersion);
    });
  });

  // ── O: chain config + fallback pool through ChainProxyManager.init() ─────
  //
  // `init()` is guarded by `_initialized` (process-wide singleton), so this is
  // the ONLY init() in this file.
  test('O. unsupported config/pool primaries fall back to their .bak via init()',
      () async {
    await writeJson(configPath, {
      ...configWith('FUTURE').toJson(),
      'version': 999,
    });
    await writeJson('$configPath.bak', {
      ...configWith('RECOVER-C').toJson(),
      'version': 1,
    });
    await writeJson(poolPath, {
      ...poolWith('FUTURE-EXIT').toJson(),
      'version': 999,
    });
    await writeJson('$poolPath.bak', {
      ...poolWith('RECOVER-EXIT').toJson(),
      'version': 1,
    });

    final manager = ChainProxyManager();
    await manager.init();

    expect(manager.config.hop1Node, 'RECOVER-C');
    final exitNames =
        manager.fallbackPool.exitCandidates.map((c) => c.nodeName).toList();
    expect(exitNames, contains('RECOVER-EXIT'));
    expect(exitNames, isNot(contains('FUTURE-EXIT')));

    // The unsupported primaries are preserved — recovery must not clobber a
    // newer version's data.
    final configRaw =
        jsonDecode(await File(configPath).readAsString()) as Map;
    final poolRaw = jsonDecode(await File(poolPath).readAsString()) as Map;
    expect(configRaw['version'], 999);
    expect(poolRaw['version'], 999);

    manager.stopChainHealthCheck();
  });
}
