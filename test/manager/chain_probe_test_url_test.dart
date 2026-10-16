import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/state.dart';
import 'package:path/path.dart' as p;

/// item 3-A — the chain probe must honour the user-configured test URL
/// (`appSetting.testUrl`, the same value the delay tests use) instead of
/// silently falling back to the hard-coded gstatic default.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_probe_url_');
    ChainProxyManager.configFilePathOverride =
        p.join(tmp.path, 'chain_proxies.json');
    ChainProxyManager.fallbackPoolFilePathOverride =
        p.join(tmp.path, 'chain_fallback_pool.json');
    ChainProxyManager.reliabilityStatsFilePathOverride =
        p.join(tmp.path, 'chain_reliability_stats.json');
  });

  tearDown(() {
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    chainProbeService.customDelayTesterOverride = null;
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('item 3-A: 链式探测使用 appSetting.testUrl 而非硬编码 gstatic 默认', () async {
    ChainProxyManager.coreRunningOverride = true;

    final previousConfig = globalState.config;
    globalState.config = previousConfig.copyWith(
      appSetting: previousConfig.appSetting.copyWith(
        testUrl: 'https://probe.example.com/custom',
      ),
    );
    addTearDown(() => globalState.config = previousConfig);

    String? capturedTestUrl;
    chainProbeService.customDelayTesterOverride = (proxyName, testUrl) async {
      capturedTestUrl = testUrl;
      // A null delay keeps the chain disconnected, so the exit-IP lookup (the
      // only network call left) is skipped and the test stays offline.
      return null;
    };

    final manager = ChainProxyManager();
    await manager.updateConfig(
      (c) => c.copyWith(enable: true, hop1Node: 'node1', hop2Node: 'node2'),
      reloadCore: false,
    );

    await manager.probeCurrentChain();

    expect(capturedTestUrl, 'https://probe.example.com/custom');
  });
}
