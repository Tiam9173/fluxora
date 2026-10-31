import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/services/network_fingerprint_provider.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir_cleanup.dart';

/// P2.5-F — runtime lifecycle / resource cleanup.
///
/// The production gap this pins: every teardown primitive already existed
/// (`NetworkFingerprintProvider.stop()`, `ChainProxyManager.dispose()` /
/// `stopChainHealthCheck()`) but was **never invoked from the app lifecycle**,
/// so the health-check `Timer.periodic` and the connectivity
/// `StreamSubscription` outlived the app. `handleExit` now stops both.
///
/// R7-7-C restores A / B / A2 and drops the old C. What each one still buys,
/// given `network_fingerprint_lifecycle_test.dart` (P2.2) already covers the
/// provider's basic start/stop:
///   · **A** overlaps with P2.2's `F` ("stop() is safe when never started") but
///     additionally pins that a *second* `stop()` is a no-op, not a throw.
///   · **B** overlaps with P2.2's `E` (start idempotent, single stop clears) but
///     additionally pins a restart **after** a stop.
///   · **A2** is unique: it exercises the real `networkFingerprintProvider`
///     singleton that `main()` starts, which P2.2 never touches (it builds
///     fresh instances).
///
/// The old `C` (`startChainHealthCheck` / `stopChainHealthCheck` idempotency) is
/// **not** restored: both methods were deleted in `56973a35`, and the getter it
/// asserted on (`isAutoHealthCheckRunning`) read a `_chainHealthTimer` that
/// nothing ever assigned — permanently false. R7-9 then deleted both, so there
/// is no longer anything to assert on.
void main() {
  // `Connectivity().onConnectivityChanged` is an EventChannel stream; both
  // `listen()` and `cancel()` touch `ServicesBinding.instance`.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String configPath;
  late String poolPath;
  late String statsPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_p25f_');
    configPath = p.join(tmp.path, 'chain_proxies.json');
    poolPath = p.join(tmp.path, 'chain_fallback_pool.json');
    statsPath = p.join(tmp.path, 'chain_reliability_stats.json');
    ChainProxyManager.configFilePathOverride = configPath;
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;
    ChainProxyManager.reliabilityStatsFilePathOverride = statsPath;
    ChainProxyManager.chainProbeOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    ChainProxyManager.capabilityProbeSourceOverride = null;
  });

  tearDown(() async {
    await ChainProxyManager().flushReliabilityStats();
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    ChainProxyManager.chainProbeOverride = null;
    ChainProxyManager.coreRunningOverride = null;
    ChainProxyManager.capabilityProbeSourceOverride = null;
    await deleteTempDirWithRetry(tmp);
  });

  // ── A/B. fingerprint stop contract ───────────────────────────────────────
  group('A/B. fingerprint lifecycle', () {
    test('A. stop() is repeatable and never throws', () {
      final provider = NetworkFingerprintProvider();
      provider.stop();
      provider.stop();
      expect(provider.isStarted, isFalse);
    });

    test('B. start → stop → start → stop never throws', () {
      final provider = NetworkFingerprintProvider();
      provider.start();
      provider.stop();
      expect(provider.isStarted, isFalse);
      provider.start();
      provider.stop();
      expect(provider.isStarted, isFalse);
    });

    test('A2. the app-start singleton is safely stoppable (handleExit path)',
        () {
      // `main()` starts exactly this instance; P2.5-F makes `handleExit` stop
      // it. The call must be safe and idempotent on the real singleton.
      networkFingerprintProvider.stop();
      networkFingerprintProvider.stop();
      expect(networkFingerprintProvider.isStarted, isFalse);
    });
  });

  // ── D–G. dispose teardown ───────────────────────────────────────────────
  //
  // `ChainProxyManager.dispose()` permanently disposes the process-wide
  // singleton, so this MUST be the only dispose() and the LAST test here.
}
