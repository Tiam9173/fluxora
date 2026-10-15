import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// F-B2 — probe teardown.
///
/// `dispose()` cancels the probe token but must ALSO invalidate the session's
/// generation: a probe that ignores the CancelToken and completes after
/// teardown must not publish `_lastProbeReport`. The token is deliberately left
/// cancelled rather than nulled — the write-back guard
/// (`_probeCancelToken?.isCancelled == true`) depends on it staying cancelled.
///
/// `ChainProxyManager` is a process-wide singleton and `dispose()` is
/// permanent, so this file holds exactly ONE test and disposes once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_fb2_probe_');
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
    await deleteTempDirWithRetry(tmp);
  });

  test('F-B2: a probe completing after dispose does not publish its report',
      () async {
    final gates = <Completer<ChainProbeReport>>[];
    ChainProxyManager.coreRunningOverride = true;
    ChainProxyManager.chainProbeOverride = (cfg) {
      final gate = Completer<ChainProbeReport>();
      gates.add(gate);
      return gate.future;
    };

    final manager = ChainProxyManager();
    manager.stopChainHealthCheck();
    await manager.updateConfig(
      (c) => c.copyWith(enable: true, hop1Node: 'node1', hop2Node: 'node2'),
      reloadCore: false,
    );

    // The singleton may carry a report from an earlier test in this isolate;
    // that value is what the post-dispose probe must leave untouched.
    final before = manager.lastProbeReport;

    final probe = manager.probeCurrentChain();
    expect(manager.isProbingChain, isTrue);
    expect(gates.length, 1);

    // Tear down while the probe is parked, then let it complete normally —
    // exactly the "ignores the CancelToken" case the guard must survive.
    manager.dispose();
    gates[0].complete(_report('post-dispose'));
    await probe;

    expect(
      manager.lastProbeReport,
      same(before),
      reason: 'a probe that outlives dispose() must not publish its report',
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
