import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
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

}

