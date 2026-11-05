import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/core.dart';
import 'package:fluxora/services/atomic_config_storage.dart';
import 'package:fluxora/services/chain_capability_probe_service.dart';

/// Phase 10 — `ChainProxyManager.init()` coverage.
///
/// Before this file the whole `init()` path was untested: the manager is a
/// singleton and `init()` is one-shot, so a test file could only ever
/// initialise once — and the existing test file only exercises capability
/// probes.
///
/// Isolation is entirely through seams that already exist in production code:
///
/// | concern | seam |
/// |---|---|
/// | config file | `configFilePathOverride` |
/// | fallback pool file | `fallbackPoolFilePathOverride` |
/// | reliability stats file | `reliabilityStatsFilePathOverride` |
/// | core config reload | `coreConfigReloadOverride` |
/// | capability probe source | `capabilityProbeSourceOverride` (empty ⇒ no probe) |
/// | singleton lifetime | `resetInstanceForTest` (the one added seam) |
///
/// Every file operation therefore lands in a `systemTemp` sandbox; no real user
/// config is read, no core is started, no socket is opened.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String configPath;
  late String poolPath;
  late String statsPath;
  late ChainProxyManager manager;

  String join(String dir, String name) => '$dir${Platform.pathSeparator}$name';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fluxora_cpm_init_');
    configPath = join(tmp.path, 'chain_proxies.json');
    poolPath = join(tmp.path, 'chain_fallback_pool.json');
    statsPath = join(tmp.path, 'chain_reliability_stats.json');

    ChainProxyManager.configFilePathOverride = configPath;
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;
    ChainProxyManager.reliabilityStatsFilePathOverride = statsPath;
    // Never touch the core: the reload hook is the only path `init()` could
    // take into it (three-hop normalisation).
    ChainProxyManager.coreConfigReloadOverride = () async {};
    ChainProxyManager.coreRunningOverride = true;
    // An empty source makes `refreshCapabilityProfiles` return before it reads
    // the active profile through the core.
    ChainProxyManager.capabilityProbeSourceOverride = const [];
    ChainCapabilityProbeService.delayProbeOverride =
        (url, name) async => Delay(name: name, url: url, value: 100);

    ChainProxyManager.resetInstanceForTest();
    manager = ChainProxyManager();
  });

  tearDown(() async {
    ChainProxyManager.resetInstanceForTest();
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    ChainProxyManager.coreConfigReloadOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    ChainProxyManager.capabilityProbeSourceOverride = null;
    ChainCapabilityProbeService.delayProbeOverride = null;
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  // ── T1 ────────────────────────────────────────────────────────────────────
  test('T1 — init restores a valid persisted config', () async {
    await AtomicConfigStorage(configPath).save(
      const ChainProxyConfig(
        enable: true,
        hop1Node: 'hop-a',
        hop2Node: 'exit-b',
      ).toJson(),
    );

    await manager.init();

    expect(manager.isInitialized, isTrue);
    expect(manager.config.enable, isTrue);
    expect(manager.config.hop1Node, 'hop-a');
    expect(manager.config.hop2Node, 'exit-b');
  });

  // ── T2 ────────────────────────────────────────────────────────────────────
  test('T2 — a missing config initialises safely and writes nothing', () async {
    await manager.init();

    expect(manager.isInitialized, isTrue);
    expect(manager.config.enable, isFalse, reason: 'defaults, not a crash');
    expect(
      File(configPath).existsSync(),
      isFalse,
      reason: 'init() is a read path; it must not create the file',
    );
  });

  // ── T3 ────────────────────────────────────────────────────────────────────
  test('T3 — a corrupt config is not destroyed', () async {
    final file = File(configPath)..writeAsStringSync('{ this is not json');
    final before = file.readAsBytesSync();

    await manager.init();

    expect(manager.isInitialized, isTrue, reason: 'init must survive garbage');
    expect(manager.config.enable, isFalse);
    expect(
      file.readAsBytesSync(),
      before,
      reason: 'unreadable data is evidence; init must not rewrite it',
    );
  });

  // ── T4 ────────────────────────────────────────────────────────────────────
  test('T4 — a persisted update survives a restart', () async {
    await manager.init();

    await manager.updateConfig(
      (current) => current.copyWith(enable: true, hop1Node: 'persisted'),
      reloadCore: false,
    );
    expect(File(configPath).existsSync(), isTrue, reason: 'update persists');

    ChainProxyManager.resetInstanceForTest();
    manager = ChainProxyManager();
    await manager.init();

    expect(manager.config.enable, isTrue);
    expect(manager.config.hop1Node, 'persisted');
  });

  // ── T5 ────────────────────────────────────────────────────────────────────
  test('T5 — the fallback pool is restored, unknown nodes are not invented',
      () async {
    final pool = ChainFallbackPool(
      entryCandidates: [
        const ChainFallbackCandidate(
          nodeName: 'entry-1',
          role: FallbackCandidateRole.entry,
        ),
      ],
      exitCandidates: [
        const ChainFallbackCandidate(
          nodeName: 'exit-1',
          role: FallbackCandidateRole.exit,
        ),
      ],
    );
    await AtomicConfigStorage(poolPath).save(pool.toJson());

    await manager.init();

    expect(
      manager.fallbackPool.entryCandidates.map((c) => c.nodeName),
      ['entry-1'],
    );
    expect(
      manager.fallbackPool.exitCandidates.map((c) => c.nodeName),
      ['exit-1'],
    );
    expect(manager.fallbackPool.totalCandidateCount, 2);
    expect(
      manager.fallbackPool.relayCandidates,
      isEmpty,
      reason: 'nothing may materialise a role that was never stored',
    );
  });

  // ── T6 ────────────────────────────────────────────────────────────────────
  test('T6 — a stored hop2Node outside the landing list is kept, not rewritten',
      () async {
    // RC.10-A.4.5: init() surfaces a stale exit reference but must not delete
    // it — a name missing from the landing list cannot be proven dead.
    await AtomicConfigStorage(configPath).save(
      const ChainProxyConfig(
        enable: true,
        hop1Node: 'hop-a',
        hop2Node: 'ghost-node',
      ).toJson(),
    );

    await manager.init();

    expect(
      manager.config.hop2Node,
      'ghost-node',
      reason: 'the user\'s stored value must survive init()',
    );
  });

  // ── T9 ────────────────────────────────────────────────────────────────────
  test('T9 — no freshness transition is armed without gated observations',
      () async {
    await manager.init();

    expect(
      manager.nextFreshnessTransitionDelay(),
      isNull,
      reason: 'an empty pool has no gated latency to expire',
    );
  });

  // ── T10 ───────────────────────────────────────────────────────────────────
  test('T10 — repeated init and repeated reset are resource-safe', () async {
    await manager.init();
    await manager.init(); // `if (_initialized) return;`

    expect(manager.isInitialized, isTrue);

    ChainProxyManager.resetInstanceForTest();
    ChainProxyManager.resetInstanceForTest(); // idempotent by design

    final again = ChainProxyManager();
    await again.init();
    expect(again.isInitialized, isTrue);
    expect(again.config.enable, isFalse);
  });

  // ── T11 ───────────────────────────────────────────────────────────────────
  // Must stay last: it disposes whatever the process-wide variable holds.
  test('T11 — reset cannot rebind the top-level chainProxyManager', () async {
    // `chainProxyManager` is a top-level `final`, so reading it caches the
    // instance for the rest of the isolate. `resetInstanceForTest()` can null
    // `_instance` and dispose the object, but it cannot reach into that
    // already-initialised variable — the global keeps pointing at a disposed
    // manager.
    //
    // This is a constraint of the test seam, not a production defect: nothing
    // outside tests calls reset, so production never disposes the global. It is
    // pinned here so a future test file does not reset and then keep using
    // `chainProxyManager`.
    final global = chainProxyManager;
    await global.init();

    ChainProxyManager.resetInstanceForTest();

    expect(
      identical(chainProxyManager, global),
      isTrue,
      reason: 'the top-level final still references the disposed instance',
    );
    expect(
      identical(chainProxyManager, ChainProxyManager()),
      isFalse,
      reason: 'a fresh instance is NOT what the global returns',
    );
  });
}
