import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/core_health_service.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// F-B2 — health-check tick teardown.
///
/// `runChainHealthCheck()` awaits `_isCoreReady()` between its entry guard and
/// its probe, so that guard is stale once it resumes. `dispose()` may have run
/// during the await, and a probe started afterwards would take a fresh,
/// un-cancelled token and write back into a disposed manager — `_disposed` must
/// therefore be part of the post-await re-check.
///
/// `ChainProxyManager` is a process-wide singleton and `dispose()` is
/// permanent, so this file holds exactly ONE test and disposes once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_fb2_tick_');
    ChainProxyManager.configFilePathOverride =
        p.join(tmp.path, 'chain_proxies.json');
    ChainProxyManager.fallbackPoolFilePathOverride =
        p.join(tmp.path, 'chain_fallback_pool.json');
    ChainProxyManager.reliabilityStatsFilePathOverride =
        p.join(tmp.path, 'chain_reliability_stats.json');
  });

  tearDown(() async {
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    ChainProxyManager.chainProbeOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    CoreHealthService.coreProbeOverride = null;
    CoreHealthService.desktopOverride = null;
    await deleteTempDirWithRetry(tmp);
  });

  test('F-B2: a tick resuming after dispose does not start a probe', () async {
    final coreGate = Completer<bool>();
    final probeCalls = <Completer<ChainProbeReport>>[];

    // Route `_isCoreReady()` through a gate so the tick parks mid-await.
    ChainProxyManager.coreRunningOverride = null;
    CoreHealthService.desktopOverride = true;
    CoreHealthService.coreProbeOverride = (_) => coreGate.future;
    ChainProxyManager.chainProbeOverride = (cfg) {
      final gate = Completer<ChainProbeReport>();
      probeCalls.add(gate);
      return gate.future;
    };

    final manager = ChainProxyManager();
    manager.stopChainHealthCheck();
    await manager.updateConfig(
      (c) => c.copyWith(
        enable: true,
        autoFailover: true,
        hop1Node: 'node1',
        hop2Node: 'node2',
      ),
      reloadCore: false,
    );

    // The tick passes its entry guard and parks inside `_isCoreReady()`.
    final tick = manager.runChainHealthCheck();

    manager.dispose();
    coreGate.complete(true);

    // Let the resumed tick run. If it (incorrectly) starts a probe it parks on
    // the chain gate, so release any probe it started and let the tick finish —
    // the assertion below then fails fast instead of hitting the test timeout.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    for (final gate in probeCalls) {
      if (!gate.isCompleted) gate.complete(_report('post-dispose'));
    }
    await tick;

    expect(
      probeCalls,
      isEmpty,
      reason: 'a tick that resumes after dispose() must not start a probe',
    );
  });
}

ChainProbeReport _report(String tag) => ChainProbeReport(
  mode: ChainHopMode.twoHop,
  isOverallHealthy: true,
  hops: [
    HopProbeState(
      hopIndex: 1,
      role: HopRole.hop1Entry,
      nodeName: 'node1',
      nodeAddress: '127.0.0.1',
      status: HopProbeStatus.healthy,
    ),
  ],
  rootCauseAnalysis: tag,
  timestamp: DateTime.now(),
);
