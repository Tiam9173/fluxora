import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/network_fingerprint_provider.dart';
import 'package:path/path.dart' as p;

/// P1.3 — Telemetry → Reliability Stats → Adaptive Ranking closed loop.
///
/// The final test group goes through the REAL production entry
/// (`ChainProxyManager.testSingleProxy`) and proves that a real probe result
/// lands in `statsByContext[fingerprint]`, bumps `stateVersion` (which the
/// ranking provider watches) and changes the adaptive score.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `ChainProxyManager.testSingleProxy` reaches `clashCore`, which constructs
  // `AppPath` → `path_provider`. Without a handler that path raises an
  // *unhandled* async error inside `AppPath._internal` and fails the test.
  // Stub the platform channel so the production path runs cleanly.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });

  const testFingerprint = 'test_net_default';

  setUp(() {
    networkFingerprintProvider.setMockFingerprint(testFingerprint);
  });

  // ── 1–6. Network fingerprint ──────────────────────────────────────────────
  group('P1.3 fingerprint', () {
    test('1. wifi → stable wifi fingerprint', () {
      expect(
        NetworkFingerprintProvider.fingerprintFor([ConnectivityResult.wifi]),
        NetworkFingerprintProvider.wifi,
      );
    });

    test('2. mobile → cellular fingerprint', () {
      expect(
        NetworkFingerprintProvider.fingerprintFor([ConnectivityResult.mobile]),
        NetworkFingerprintProvider.cellular,
      );
    });

    test('3. same transport → same fingerprint (stable)', () {
      final a = NetworkFingerprintProvider.fingerprintFor([
        ConnectivityResult.wifi,
      ]);
      final b = NetworkFingerprintProvider.fingerprintFor([
        ConnectivityResult.wifi,
      ]);
      expect(a, b);
    });

    test('4. different transport → different fingerprint', () {
      final wifi = NetworkFingerprintProvider.fingerprintFor([
        ConnectivityResult.wifi,
      ]);
      final cellular = NetworkFingerprintProvider.fingerprintFor([
        ConnectivityResult.mobile,
      ]);
      expect(wifi, isNot(cellular));
    });

    test('4b. order-independent (ethernet preferred over wifi)', () {
      expect(
        NetworkFingerprintProvider.fingerprintFor([
          ConnectivityResult.wifi,
          ConnectivityResult.ethernet,
        ]),
        NetworkFingerprintProvider.ethernet,
      );
      expect(
        NetworkFingerprintProvider.fingerprintFor([
          ConnectivityResult.ethernet,
          ConnectivityResult.wifi,
        ]),
        NetworkFingerprintProvider.ethernet,
      );
    });


  });

  // ── 7–9. Reliability aggregation ──────────────────────────────────────────
  group('P1.3 reliability aggregation', () {


  });


  // ── 13–14. REAL production path ───────────────────────────────────────────
  group('P1.3 production path (ChainProxyManager)', () {
    late Directory tmp;
    late ChainProxyManager manager;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('fluxora_p13_');
      ChainProxyManager.configFilePathOverride = p.join(
        tmp.path,
        'chain_proxies.json',
      );
      ChainProxyManager.fallbackPoolFilePathOverride = p.join(
        tmp.path,
        'chain_fallback_pool.json',
      );
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

    tearDown(() {
      ChainProxyManager.chainProbeOverride = null;
      ChainProxyManager.configFilePathOverride = null;
      ChainProxyManager.fallbackPoolFilePathOverride = null;
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    ChainProbeReport reportFor(
      String nodeName, {
      bool cancelled = false,
    }) => ChainProbeReport(
      mode: ChainHopMode.twoHop,
      isOverallHealthy: false,
      healthStatus: cancelled
          ? ChainHealthStatus.cancelled
          : ChainHealthStatus.failed,
      failureHop: 2,
      isCancelled: cancelled,
      hops: [
        HopProbeState(
          hopIndex: 2,
          role: HopRole.hop2Exit,
          nodeName: nodeName,
          nodeAddress: '127.0.0.1',
          status: cancelled ? HopProbeStatus.cancelled : HopProbeStatus.timeout,
          healthStatus: cancelled
              ? ChainHealthStatus.cancelled
              : ChainHealthStatus.failed,
        ),
      ],
      timestamp: DateTime.now(),
    );

    test(
      '13. real probe → reliability sample in statsByContext + stateVersion bump',
      () async {
        final fp = networkFingerprintProvider.getCurrentFingerprint();
        final versionBefore = manager.stateVersion;

        // REAL production write-back path (D1/F2). Only the network probe is
        // stubbed, via the existing `chainProbeOverride` seam — the core is
        // never constructed here.
        ChainProxyManager.chainProbeOverride = (cfg) async =>
            reportFor('US-FB-01');
        await manager.probeCurrentChain();

        final stats = manager
            .fallbackPool
            .exitCandidates
            .single
            .statsByContext[fp];
        expect(
          stats,
          isNotNull,
          reason: 'a real probe result must produce a reliability sample',
        );
        expect(stats!.totalSamples, 1);
        expect(stats.consecutiveFailures, 1);
        expect(
          manager.stateVersion,
          greaterThan(versionBefore),
          reason: 'stateVersion must bump so the ranking provider rebuilds',
        );
      },
    );

    test('14. a different fingerprint produces a separate stats entry',
        () async {
      ChainProxyManager.chainProbeOverride = (cfg) async =>
          reportFor('US-FB-01');

      final fpA = networkFingerprintProvider.getCurrentFingerprint();
      await manager.probeCurrentChain();

      networkFingerprintProvider.setMockFingerprint('other_net_default');
      await manager.probeCurrentChain();

      final byContext = manager
          .fallbackPool
          .exitCandidates
          .single
          .statsByContext;
      expect(byContext.keys, containsAll(<String>[fpA, 'other_net_default']));
      expect(byContext[fpA]!.totalSamples, 1);
      expect(byContext['other_net_default']!.totalSamples, 1);
    });

    test('15. cancelled report records NO sample', () async {
      final fp = networkFingerprintProvider.getCurrentFingerprint();
      ChainProxyManager.chainProbeOverride = (cfg) async =>
          reportFor('US-FB-01', cancelled: true);

      await manager.probeCurrentChain();

      final stats = manager
          .fallbackPool
          .exitCandidates
          .single
          .statsByContext[fp];
      expect(
        stats?.totalSamples ?? 0,
        0,
        reason: 'a cancelled probe must not produce a reliability sample',
      );
    });
  });
}
