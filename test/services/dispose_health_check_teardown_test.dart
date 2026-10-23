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
