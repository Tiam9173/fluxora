import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/latency_freshness.dart';
import 'package:fluxora/models/latency_state.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/services/chain_capability_probe_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/network_fingerprint_provider.dart';

/// Phase 10 — probe write-back and freshness lifecycle.
///
/// The probe path is driven entirely through `chainProbeOverride`, so no core,
/// no network and no socket is involved. Every file lands in a `systemTemp`
/// sandbox through the production overrides.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late ChainProxyManager manager;

  String join(String dir, String name) => '$dir${Platform.pathSeparator}$name';

  HopProbeState hop({
    required String name,
    required ChainHealthStatus health,
    int? latencyMs,
    DateTime? testedAt,
  }) =>
      HopProbeState(
        hopIndex: 0,
        role: HopRole.hop1Entry,
        nodeName: name,
        nodeAddress: '10.0.0.1',
        healthStatus: health,
        latencyMs: latencyMs,
        testedAt: testedAt,
      );

  ChainProbeReport report(
    List<HopProbeState> hops, {
    bool cancelled = false,
  }) =>
      ChainProbeReport(
        mode: ChainHopMode.twoHop,
        isOverallHealthy: !cancelled,
        hops: hops,
        isCancelled: cancelled,
        timestamp: DateTime.now(),
      );

  ChainFallbackPool poolOf(List<String> names) => ChainFallbackPool(
        entryCandidates: [
          for (final n in names)
            ChainFallbackCandidate(
              nodeName: n,
              role: FallbackCandidateRole.entry,
            ),
        ],
      );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fluxora_cpm_probe_');
    ChainProxyManager.configFilePathOverride = join(tmp.path, 'chain_proxies.json');
    ChainProxyManager.fallbackPoolFilePathOverride =
        join(tmp.path, 'chain_fallback_pool.json');
    ChainProxyManager.reliabilityStatsFilePathOverride =
        join(tmp.path, 'chain_reliability_stats.json');
    ChainProxyManager.coreConfigReloadOverride = () async {};
    ChainProxyManager.coreRunningOverride = true;
    ChainProxyManager.capabilityProbeSourceOverride = const [];
    ChainCapabilityProbeService.delayProbeOverride =
        (url, name) async => Delay(name: name, url: url, value: 100);

    ChainProxyManager.resetInstanceForTest();
    manager = ChainProxyManager();
    await manager.init();
  });

  tearDown(() async {
    ChainProxyManager.resetInstanceForTest();
    ChainProxyManager.chainProbeOverride = null;
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    ChainProxyManager.coreConfigReloadOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    ChainProxyManager.capabilityProbeSourceOverride = null;
    ChainCapabilityProbeService.delayProbeOverride = null;
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  // ── A1 ────────────────────────────────────────────────────────────────────
  test('A1 — an empty pool arms no freshness timer', () async {
    expect(manager.fallbackPool.isEmpty, isTrue);
    expect(manager.nextFreshnessTransitionDelay(), isNull);
  });

  // ── A2 ────────────────────────────────────────────────────────────────────
  test('A2 — a successful probe gives the candidate a nodeLatency', () async {
    await manager.setFallbackPool(poolOf(['n1']));
    ChainProxyManager.chainProbeOverride = (_) async =>
        report([hop(name: 'n1', health: ChainHealthStatus.healthy, latencyMs: 42)]);

    await manager.probeCurrentChain();

    final c = manager.fallbackPool.entryCandidates.single;
    expect(c.nodeLatency, isNotNull);
    expect(c.nodeLatency!.latencyMs, 42);
    expect(c.nodeLatency!.scope, LatencyScope.node);
    expect(c.nodeLatency!.source, LatencySource.probe);
  });

  // ── A3 ────────────────────────────────────────────────────────────────────
  test('A3 — the freshness timer is armed by a probe and fires', () async {
    // A pool with no observation arms nothing; the probe is what creates one.
    await manager.setFallbackPool(poolOf(['n1']));
    expect(
      manager.nextFreshnessTransitionDelay(),
      isNull,
      reason: 'no observation yet',
    );

    // Age the sample to just inside `trustedMaxAge`, so the next transition is
    // ~1.3 s away: (5 min - age) + 1 s.
    final testedAt = DateTime.now()
        .subtract(LatencyFreshness.trustedMaxAge)
        .add(const Duration(milliseconds: 300));
    ChainProxyManager.chainProbeOverride = (_) async => report([
      hop(
        name: 'n1',
        health: ChainHealthStatus.healthy,
        latencyMs: 42,
        testedAt: testedAt,
      ),
    ]);

    await manager.probeCurrentChain();

    expect(
      manager.nextFreshnessTransitionDelay(),
      isNotNull,
      reason: 'a gated observation now exists',
    );

    final before = manager.stateVersion;
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    expect(
      manager.stateVersion,
      greaterThan(before),
      reason: 'the armed tick must advance stateVersion when the sample ages out',
    );
  });

  // ── A4 ────────────────────────────────────────────────────────────────────
  test('A4 — a cancelled probe does not touch the pool', () async {
    await manager.setFallbackPool(poolOf(['n1']));
    final before = manager.fallbackPool.entryCandidates.single;

    ChainProxyManager.chainProbeOverride = (_) async => report(
          [hop(name: 'n1', health: ChainHealthStatus.healthy, latencyMs: 42)],
          cancelled: true,
        );

    await manager.probeCurrentChain();

    final after = manager.fallbackPool.entryCandidates.single;
    expect(after.nodeLatency, isNull);
    expect(after.statsByContext, isEmpty);
    expect(identical(after, before), isTrue, reason: 'untouched candidate');
    expect(manager.nextFreshnessTransitionDelay(), isNull);
  });

  // ── A5 ────────────────────────────────────────────────────────────────────
  test('A5 — a disposed manager stops updating state', () async {
    await manager.setFallbackPool(poolOf(['n1']));
    final testedAt = DateTime.now()
        .subtract(LatencyFreshness.trustedMaxAge)
        .add(const Duration(milliseconds: 300));
    ChainProxyManager.chainProbeOverride = (_) async => report([
      hop(
        name: 'n1',
        health: ChainHealthStatus.healthy,
        latencyMs: 42,
        testedAt: testedAt,
      ),
    ]);
    await manager.probeCurrentChain();

    final before = manager.stateVersion;
    manager.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    expect(
      manager.stateVersion,
      before,
      reason: 'dispose cancels the freshness tick',
    );
  });

  // ── B1 / B3 ───────────────────────────────────────────────────────────────
  test('B1 — only the matching candidate is updated', () async {
    await manager.setFallbackPool(poolOf(['n1', 'n2']));
    ChainProxyManager.chainProbeOverride = (_) async =>
        report([hop(name: 'n1', health: ChainHealthStatus.healthy, latencyMs: 42)]);

    await manager.probeCurrentChain();

    final byName = {
      for (final c in manager.fallbackPool.entryCandidates) c.nodeName: c,
    };
    expect(byName['n1']!.nodeLatency?.latencyMs, 42);
    expect(byName['n1']!.statsByContext, isNotEmpty);
    expect(byName['n2']!.nodeLatency, isNull, reason: 'never probed');
    expect(byName['n2']!.statsByContext, isEmpty);
  });

  // ── B2 ────────────────────────────────────────────────────────────────────
  test('B2 — a failed probe records a failure sample', () async {
    await manager.setFallbackPool(poolOf(['n1']));
    ChainProxyManager.chainProbeOverride = (_) async =>
        report([hop(name: 'n1', health: ChainHealthStatus.failed)]);

    await manager.probeCurrentChain();

    final c = manager.fallbackPool.entryCandidates.single;
    final stats = c.statsByContext.values.single;
    expect(stats.totalSamples, 1);
    expect(stats.consecutiveFailures, 1);
    expect(stats.weightedFailure, greaterThan(0));
    expect(c.nodeLatency, isNull, reason: 'a failure carries no latency');
  });

  // ── B5 ────────────────────────────────────────────────────────────────────
  test('B5 — samples are bucketed by the current network fingerprint', () async {
    await manager.setFallbackPool(poolOf(['n1']));
    ChainProxyManager.chainProbeOverride = (_) async =>
        report([hop(name: 'n1', health: ChainHealthStatus.healthy, latencyMs: 42)]);

    await manager.probeCurrentChain();

    final c = manager.fallbackPool.entryCandidates.single;
    expect(c.statsByContext.keys.single, networkFingerprintProvider.getCurrentFingerprint());
  });

  // ── B6 ────────────────────────────────────────────────────────────────────
  test('B6 — reliability persistence is queued and confined to the sandbox',
      () async {
    expect(
      ChainProxyManager.reliabilityStatsFilePathOverride,
      startsWith(tmp.path),
      reason: 'the only path a persist could take',
    );

    await manager.setFallbackPool(poolOf(['n1']));
    ChainProxyManager.chainProbeOverride = (_) async =>
        report([hop(name: 'n1', health: ChainHealthStatus.healthy, latencyMs: 42)]);

    await manager.probeCurrentChain();

    expect(manager.hasPendingReliabilityPersist, isTrue);
  });
}
