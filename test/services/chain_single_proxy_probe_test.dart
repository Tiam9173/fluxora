import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/network_fingerprint_provider.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P1.3-A / P1.3-B — the node card's 「体检」 entry
/// (`ChainProxyManager.testSingleProxy`) must run a REAL chain probe and let the
/// existing write-back (`_writeBackProbeResultsToCandidates`) attribute the real
/// hop results to the matching fallback-pool candidates — and to nothing else.
///
/// Tests 9–11 additionally pin the P1.3-B writer semantics: the probe write-back
/// classifies hops exactly like the failover writer (degraded = success, no
/// evidence = no sample) and both share one decay constant.
///
/// Only the network probe is stubbed (`chainProbeOverride`); the write-back,
/// the reliability model and the notification path all run for real.
void main() {
  late Directory tmp;
  late ChainProxyManager manager;
  late String fingerprint;

  const chainConfig = ChainProxyConfig(
    enable: true,
    hopMode: ChainHopMode.twoHop,
    hop1Node: 'ENTRY-1',
    hop2Node: 'EXIT-1',
    defaultDialerProxy: 'ENTRY-1',
  );

  HopProbeState hop(int index, HopRole role, String name, ChainHealthStatus h) =>
      HopProbeState(
        hopIndex: index,
        role: role,
        nodeName: name,
        nodeAddress: '127.0.0.1',
        status: h == ChainHealthStatus.healthy
            ? HopProbeStatus.healthy
            : HopProbeStatus.failed,
        healthStatus: h,
        latencyMs: h == ChainHealthStatus.healthy ? 40 : null,
        testedAt: DateTime.now(),
      );

  ChainProbeReport report({
    required ChainHopMode mode,
    required ChainHealthStatus entry,
    required ChainHealthStatus exit,
    bool cancelled = false,
  }) => ChainProbeReport(
    mode: mode,
    isOverallHealthy: entry == ChainHealthStatus.healthy &&
        exit == ChainHealthStatus.healthy,
    healthStatus: cancelled
        ? ChainHealthStatus.cancelled
        : (entry == ChainHealthStatus.healthy &&
                  exit == ChainHealthStatus.healthy
              ? ChainHealthStatus.healthy
              : ChainHealthStatus.failed),
    isCancelled: cancelled,
    failureHop: exit == ChainHealthStatus.healthy ? null : 2,
    hops: [
      hop(1, HopRole.hop1Entry, 'ENTRY-1', entry),
      hop(2, HopRole.hop2Exit, 'EXIT-1', exit),
    ],
    timestamp: DateTime.now(),
  );

  ChainFallbackPool poolWithUnrelatedCandidate() => ChainFallbackPool(
    entryCandidates: [
      const ChainFallbackCandidate(
        nodeName: 'ENTRY-1',
        role: FallbackCandidateRole.entry,
      ),
    ],
    exitCandidates: [
      const ChainFallbackCandidate(
        nodeName: 'EXIT-1',
        role: FallbackCandidateRole.exit,
      ),
      // Never probed by this chain — must never be credited.
      const ChainFallbackCandidate(
        nodeName: 'UNRELATED-9',
        role: FallbackCandidateRole.exit,
      ),
    ],
  );

  ChainReliabilityStats? statsOf(String nodeName) {
    final all = [
      ...manager.fallbackPool.entryCandidates,
      ...manager.fallbackPool.exitCandidates,
    ];
    return all.firstWhere((c) => c.nodeName == nodeName).statsByContext[fingerprint];
  }

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('fluxora_p13a_');
    ChainProxyManager.configFilePathOverride = p.join(
      tmp.path,
      'chain_proxies.json',
    );
    ChainProxyManager.fallbackPoolFilePathOverride = p.join(
      tmp.path,
      'chain_fallback_pool.json',
    );
    ChainProxyManager.coreRunningOverride = true;
    ChainProxyManager.chainProbeOverride = null;

    networkFingerprintProvider.setMockFingerprint('p13a_net_default');
    fingerprint = networkFingerprintProvider.getCurrentFingerprint();

    manager = ChainProxyManager();
    manager.stopChainHealthCheck();
    await manager.updateConfig((_) => chainConfig, reloadCore: false);
    await manager.setFallbackPool(poolWithUnrelatedCandidate());
  });

  tearDown(() async {
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    ChainProxyManager.chainProbeOverride = null;
    if (tmp.existsSync()) await deleteTempDirWithRetry(tmp);
  });

  test('1. runs the real probe entry for the node occupying the role', () async {
    var probeCalls = 0;
    ChainProxyManager.chainProbeOverride = (cfg) async {
      probeCalls++;
      return report(
        mode: cfg.hopMode,
        entry: ChainHealthStatus.healthy,
        exit: ChainHealthStatus.healthy,
      );
    };

    await manager.testSingleProxy(
      nodeName: 'EXIT-1',
      role: FallbackCandidateRole.exit,
    );

    expect(probeCalls, 1, reason: 'the entry must actually probe');
  });

  test('2. a healthy hop is recorded as a success on the matching candidate only',
      () async {
    ChainProxyManager.chainProbeOverride = (cfg) async => report(
      mode: cfg.hopMode,
      entry: ChainHealthStatus.healthy,
      exit: ChainHealthStatus.healthy,
    );

    await manager.testSingleProxy(
      nodeName: 'EXIT-1',
      role: FallbackCandidateRole.exit,
    );

    final exit = statsOf('EXIT-1')!;
    expect(exit.totalSamples, 1);
    expect(exit.weightedSuccess, 1.0);
    expect(exit.weightedFailure, 0.0);
    expect(exit.consecutiveFailures, 0);

    // The other hop of the same probe is credited to its own candidate.
    expect(statsOf('ENTRY-1')!.totalSamples, 1);
    // A pool candidate that is not part of the probed chain is never credited.
    expect(statsOf('UNRELATED-9'), isNull);
  });

  test('3. a failed hop is recorded as a failure, never as a success', () async {
    ChainProxyManager.chainProbeOverride = (cfg) async => report(
      mode: cfg.hopMode,
      entry: ChainHealthStatus.healthy,
      exit: ChainHealthStatus.failed,
    );

    await manager.testSingleProxy(
      nodeName: 'EXIT-1',
      role: FallbackCandidateRole.exit,
    );

    final exit = statsOf('EXIT-1')!;
    expect(exit.totalSamples, 1);
    expect(exit.weightedFailure, 1.0);
    expect(exit.weightedSuccess, 0.0);
    expect(exit.consecutiveFailures, 1);
  });

  test('4. a throwing probe is never recorded as a success', () async {
    ChainProxyManager.chainProbeOverride = (cfg) async =>
        throw StateError('probe boom');

    await expectLater(
      manager.testSingleProxy(
        nodeName: 'EXIT-1',
        role: FallbackCandidateRole.exit,
      ),
      throwsA(isA<StateError>()),
    );

    expect(statsOf('EXIT-1'), isNull, reason: 'nothing ran → nothing recorded');
  });

  test('5. a cancelled probe records no sample', () async {
    ChainProxyManager.chainProbeOverride = (cfg) async => report(
      mode: cfg.hopMode,
      entry: ChainHealthStatus.healthy,
      exit: ChainHealthStatus.healthy,
      cancelled: true,
    );

    await manager.testSingleProxy(
      nodeName: 'EXIT-1',
      role: FallbackCandidateRole.exit,
    );

    expect(statsOf('EXIT-1'), isNull);
    expect(statsOf('ENTRY-1'), isNull);
  });

  test('6. a repeated trigger does not record the same probe twice', () async {
    var probeCalls = 0;
    final gate = Completer<ChainProbeReport>();
    ChainProxyManager.chainProbeOverride = (cfg) {
      probeCalls++;
      return gate.future;
    };

    final first = manager.testSingleProxy(
      nodeName: 'EXIT-1',
      role: FallbackCandidateRole.exit,
    );
    // In flight → the second trigger must be a no-op, not a second session.
    final second = manager.testSingleProxy(
      nodeName: 'EXIT-1',
      role: FallbackCandidateRole.exit,
    );

    gate.complete(
      report(
        mode: ChainHopMode.twoHop,
        entry: ChainHealthStatus.healthy,
        exit: ChainHealthStatus.healthy,
      ),
    );
    await first;
    await second;

    expect(probeCalls, 1);
    expect(statsOf('EXIT-1')!.totalSamples, 1);
  });

  test('7. the result is published through the existing notification path',
      () async {
    ChainProxyManager.chainProbeOverride = (cfg) async => report(
      mode: cfg.hopMode,
      entry: ChainHealthStatus.healthy,
      exit: ChainHealthStatus.healthy,
    );

    final versionBefore = manager.stateVersion;
    await manager.testSingleProxy(
      nodeName: 'EXIT-1',
      role: FallbackCandidateRole.exit,
    );

    expect(
      manager.stateVersion,
      greaterThan(versionBefore),
      reason: 'the ranking provider rebuilds on stateVersion',
    );
  });

  test('8. a node that no longer occupies the role is not probed', () async {
    var probeCalls = 0;
    ChainProxyManager.chainProbeOverride = (cfg) async {
      probeCalls++;
      return report(
        mode: cfg.hopMode,
        entry: ChainHealthStatus.healthy,
        exit: ChainHealthStatus.healthy,
      );
    };

    await manager.testSingleProxy(
      nodeName: 'STALE-NODE',
      role: FallbackCandidateRole.exit,
    );

    expect(probeCalls, 0);
    expect(statsOf('EXIT-1'), isNull);
  });

  // ── P1.3-B: writer classification + shared decay semantics ────────────────

  test('9. a degraded hop counts as a success, not a failure', () async {
    ChainProxyManager.chainProbeOverride = (cfg) async => report(
      mode: cfg.hopMode,
      entry: ChainHealthStatus.degraded,
      exit: ChainHealthStatus.healthy,
    );

    await manager.testSingleProxy(
      nodeName: 'ENTRY-1',
      role: FallbackCandidateRole.entry,
    );

    final entry = statsOf('ENTRY-1')!;
    expect(entry.weightedSuccess, 1.0);
    expect(entry.weightedFailure, 0.0);
    expect(entry.consecutiveFailures, 0);
  });

  test('10. a hop with no evidence records nothing (never a failure)', () async {
    for (final status in const [
      ChainHealthStatus.unknown,
      ChainHealthStatus.checking,
    ]) {
      await manager.setFallbackPool(poolWithUnrelatedCandidate());
      ChainProxyManager.chainProbeOverride = (cfg) async => report(
        mode: cfg.hopMode,
        entry: status,
        exit: ChainHealthStatus.healthy,
      );

      await manager.testSingleProxy(
        nodeName: 'ENTRY-1',
        role: FallbackCandidateRole.entry,
      );

      expect(
        statsOf('ENTRY-1'),
        isNull,
        reason: '$status carries no evidence — neither outcome may be invented',
      );
    }
  });

  test('11. both reliability writers share one decay constant', () {
    // Structural guard: a behavioural parity test would need a full failover
    // session; this pins the *mechanism* so the two writers cannot drift back
    // into different decay semantics (the model's own tests pin `recordEvent`).
    final writerA = File(
      'lib/manager/chain_proxy_manager.dart',
    ).readAsStringSync();
    final writerB = File(
      'lib/services/chain_failover_service.dart',
    ).readAsStringSync();

    expect(writerA.contains('ChainReliabilityStats.decayLambda'), isTrue);
    expect(writerB.contains('ChainReliabilityStats.decayLambda'), isTrue);
    expect(writerA.contains('recordEvent('), isTrue);
    expect(
      writerA.contains('* 0.9'),
      isFalse,
      reason: 'the hand-rolled 0.9 update must stay replaced by recordEvent',
    );
  });
}
