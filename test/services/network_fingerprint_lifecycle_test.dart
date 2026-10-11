import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_reliability_stats_persistence.dart';
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

    test('B. transport → stable fingerprint mapping', () {
      expect(
        NetworkFingerprintProvider.fingerprintFor([ConnectivityResult.wifi]),
        NetworkFingerprintProvider.wifi,
      );
      expect(
        NetworkFingerprintProvider.fingerprintFor([ConnectivityResult.mobile]),
        NetworkFingerprintProvider.cellular,
      );
      expect(
        NetworkFingerprintProvider.fingerprintFor([
          ConnectivityResult.ethernet,
        ]),
        NetworkFingerprintProvider.ethernet,
      );
      expect(
        NetworkFingerprintProvider.fingerprintFor([ConnectivityResult.vpn]),
        NetworkFingerprintProvider.vpn,
      );
      expect(
        NetworkFingerprintProvider.fingerprintFor(const []),
        NetworkFingerprintProvider.unknown,
      );
    });

    test('C. the current context follows the transport', () {
      provider.setMockFingerprint(NetworkFingerprintProvider.wifi);
      expect(
        provider.getCurrentFingerprint(),
        NetworkFingerprintProvider.wifi,
      );

      provider.setMockFingerprint(NetworkFingerprintProvider.cellular);
      expect(
        provider.getCurrentFingerprint(),
        NetworkFingerprintProvider.cellular,
      );
    });

    test('G. connectivity failure falls back to unknown and never blocks', () {
      final fresh = NetworkFingerprintProvider();
      fresh.start(); // no plugin in the test env → swallowed internally
      expect(fresh.getCurrentFingerprint(), NetworkFingerprintProvider.unknown);
      fresh.stop();
    });
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

    test('D+H. a transport change routes later samples into a new context, '
        'and both contexts persist independently', () async {
      ChainProxyManager.chainProbeOverride = (cfg) async => failedReport(cfg);

      // Network A
      networkFingerprintProvider.setMockFingerprint(
        NetworkFingerprintProvider.wifi,
      );
      await manager.probeCurrentChain();

      // Network change → Network B
      networkFingerprintProvider.setMockFingerprint(
        NetworkFingerprintProvider.cellular,
      );
      await manager.probeCurrentChain();

      final byContext = manager
          .fallbackPool
          .exitCandidates
          .single
          .statsByContext;
      expect(
        byContext.keys,
        containsAll(<String>[
          NetworkFingerprintProvider.wifi,
          NetworkFingerprintProvider.cellular,
        ]),
        reason: 'the two network contexts must never be merged',
      );
      expect(byContext[NetworkFingerprintProvider.wifi]!.totalSamples, 1);
      expect(byContext[NetworkFingerprintProvider.cellular]!.totalSamples, 1);

      // H: P2.1 persistence keeps both buckets.
      await manager.flushReliabilityStats();
      final loaded = await chainReliabilityStatsPersistence.load(statsPath);
      final byFp = loaded[FallbackCandidateRole.exit]!['US-FB-01']!;
      expect(byFp.length, 2);
      expect(byFp[NetworkFingerprintProvider.wifi]!.totalSamples, 1);
      expect(byFp[NetworkFingerprintProvider.cellular]!.totalSamples, 1);
    });
  });
}
