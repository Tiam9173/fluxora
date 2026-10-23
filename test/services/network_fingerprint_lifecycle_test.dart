import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/network_fingerprint_provider.dart';
import 'package:path/path.dart' as p;

/// P2.2 — Network fingerprint lifecycle & startup integration.
///
/// The provider itself is exercised directly (start / stop / idempotency /
/// mapping). The "network change → reliability context" case goes through the
/// REAL production write-back path (`ChainProxyManager.probeCurrentChain`) —
/// `statsByContext` is never populated by hand.
void main() {
  // `Connectivity().onConnectivityChanged` is an EventChannel stream: both
  // `listen()` and `cancel()` touch `ServicesBinding.instance`. Without a
  // binding they raise an *asynchronous* error that the provider's synchronous
  // try/catch cannot swallow. With the binding present, `listen()` succeeds and
  // the "no plugin" failure is delivered to the stream's `onError`.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2.2 provider lifecycle', () {
    late NetworkFingerprintProvider provider;

    setUp(() => provider = NetworkFingerprintProvider());
    tearDown(() => provider.stop());

    test('A. start() never throws when no connectivity plugin is available',
        () {
      expect(provider.start, returnsNormally);
    });

    test('E. start() is idempotent; a single stop() clears it', () {
      provider.start();
      provider.start();
      provider.stop();
      expect(
        provider.isStarted,
        isFalse,
        reason: 'duplicate start() must not leak a second subscription',
      );
    });

    test('F. stop() is safe when never started', () {
      provider.stop();
      expect(provider.isStarted, isFalse);
    });




    // ── RC.11-A (F-AR4) ──────────────────────────────────────────────────────

  });

  group('P2.2 network change → reliability context', () {
    late Directory tmp;
    late String statsPath;
    late ChainProxyManager manager;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('fluxora_p22_');
      statsPath = p.join(tmp.path, 'chain_reliability_stats.json');
      ChainProxyManager.configFilePathOverride = p.join(
        tmp.path,
        'chain_proxies.json',
      );
      ChainProxyManager.fallbackPoolFilePathOverride = p.join(
        tmp.path,
        'chain_fallback_pool.json',
      );
      ChainProxyManager.reliabilityStatsFilePathOverride = statsPath;
      ChainProxyManager.chainProbeOverride = null;

      manager = ChainProxyManager();
      await manager.updateConfig(
        (_) => const ChainProxyConfig(
          enable: true,
          hop1Node: 'HK-01',
          hop2Node: 'US-01',
        ),
      );
      await manager.updateFallbackPool(
        (_) => const ChainFallbackPool(
          exitCandidates: [
            ChainFallbackCandidate(
              nodeName: 'US-FB-01',
              role: FallbackCandidateRole.exit,
            ),
          ],
        ),
      );
    });

    tearDown(() async {
      await manager.flushReliabilityStats();
      ChainProxyManager.configFilePathOverride = null;
      ChainProxyManager.fallbackPoolFilePathOverride = null;
      ChainProxyManager.reliabilityStatsFilePathOverride = null;
      ChainProxyManager.chainProbeOverride = null;
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    ChainProbeReport failedReport(ChainProxyConfig cfg) => ChainProbeReport(
      mode: cfg.hopMode,
      isOverallHealthy: false,
      healthStatus: ChainHealthStatus.failed,
      failureHop: 2,
      hops: [
        HopProbeState(
          hopIndex: 2,
          role: HopRole.hop2Exit,
          nodeName: 'US-FB-01',
          nodeAddress: '127.0.0.1',
          status: HopProbeStatus.timeout,
          healthStatus: ChainHealthStatus.failed,
        ),
      ],
      timestamp: DateTime.now(),
    );

  });

  // ────────────────────────────────────────────────────────────────────────────
  // RC.11-A (F-AR4) — a transport change must reach the manager.
  //
  // The fingerprint provider has no notifier, and the adaptive ranking provider
  // reads it imperatively — so a transport change alone used to leave the node
  // picker on the PREVIOUS network's ranking. `ChainProxyManager.init()` is the
  // production registration point; this pins that the hook is installed and that
  // a real change bumps `stateVersion` (a component of the ranking
  // `stateFingerprint`, which is what forces the cache miss).
  //
  // NOTE: `init()` is a one-shot per isolate (`_initialized`), so it is driven
  // exactly once here — after the groups above have finished.
  // ────────────────────────────────────────────────────────────────────────────
  group('RC.11-A (F-AR4) — a transport change reaches the manager', () {
    late Directory tmp;
    late ChainProxyManager manager;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('fluxora_rc11a_');
      ChainProxyManager.configFilePathOverride = p.join(
        tmp.path,
        'chain_proxies.json',
      );
      ChainProxyManager.fallbackPoolFilePathOverride = p.join(
        tmp.path,
        'chain_fallback_pool.json',
      );
      ChainProxyManager.reliabilityStatsFilePathOverride = p.join(
        tmp.path,
        'chain_reliability_stats.json',
      );
      ChainProxyManager.chainProbeOverride = null;

      manager = ChainProxyManager();
      await manager.init();
    });

    tearDown(() async {
      await manager.flushReliabilityStats();
      networkFingerprintProvider.onChanged = null;
      ChainProxyManager.configFilePathOverride = null;
      ChainProxyManager.fallbackPoolFilePathOverride = null;
      ChainProxyManager.reliabilityStatsFilePathOverride = null;
      ChainProxyManager.chainProbeOverride = null;
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('J. init() installs the hook; a real change bumps stateVersion', () {
      expect(
        networkFingerprintProvider.onChanged,
        isNotNull,
        reason: 'init() must register the transport hook',
      );

      // Pin a known baseline first — the fingerprint is process-global, so the
      // value left by an earlier test is unknown here.
      networkFingerprintProvider.setMockFingerprint(
        NetworkFingerprintProvider.bluetooth,
      );
      final before = manager.stateVersion;

      networkFingerprintProvider.setMockFingerprint(
        NetworkFingerprintProvider.wifi,
      );
      expect(
        manager.stateVersion,
        greaterThan(before),
        reason:
            'a transport change must notify the manager so the ranking '
            'stateFingerprint changes and the cache misses',
      );

      // A repeat of the SAME transport is a no-op.
      final afterChange = manager.stateVersion;
      networkFingerprintProvider.setMockFingerprint(
        NetworkFingerprintProvider.wifi,
      );
      expect(manager.stateVersion, afterChange);
    });
  });
}
