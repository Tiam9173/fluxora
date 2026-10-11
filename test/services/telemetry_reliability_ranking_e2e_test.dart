import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:fluxora/services/chain_adaptive_score_service.dart';
import 'package:fluxora/services/chain_capability_service.dart';
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

    test('5. empty → unknown', () {
      expect(
        NetworkFingerprintProvider.fingerprintFor(const []),
        NetworkFingerprintProvider.unknown,
      );
    });

    test('6. setMockFingerprint pins the value (deterministic tests)', () {
      expect(networkFingerprintProvider.getCurrentFingerprint(), testFingerprint);
    });
  });

  // ── 7–9. Reliability aggregation ──────────────────────────────────────────
  group('P1.3 reliability aggregation', () {
    test('7. success updates weightedSuccess / totalSamples', () {
      final s0 = ChainReliabilityStats.initial(networkFingerprint: 'fp');
      final s1 = s0.recordEvent(isSuccess: true, now: DateTime.now());
      expect(s1.totalSamples, 1);
      expect(s1.weightedSuccess, greaterThan(0));
      expect(s1.consecutiveFailures, 0);
    });

    test('8. failure updates weightedFailure / consecutiveFailures', () {
      final s0 = ChainReliabilityStats.initial(networkFingerprint: 'fp');
      final s1 = s0.recordEvent(isSuccess: false, now: DateTime.now());
      expect(s1.totalSamples, 1);
      expect(s1.weightedFailure, greaterThan(0));
      expect(s1.consecutiveFailures, 1);
    });

    test('9. different fingerprints → separate statsByContext entries', () {
      final candidate = ChainFallbackCandidate(
        nodeName: 'N',
        role: FallbackCandidateRole.exit,
        statsByContext: {
          'fpA': ChainReliabilityStats.initial(networkFingerprint: 'fpA')
              .recordEvent(isSuccess: true, now: DateTime.now()),
          'fpB': ChainReliabilityStats.initial(networkFingerprint: 'fpB')
              .recordEvent(isSuccess: false, now: DateTime.now()),
        },
      );
      expect(candidate.statsByContext['fpA']!.totalSamples, 1);
      expect(candidate.statsByContext['fpB']!.consecutiveFailures, 1);
      expect(candidate.statsByContext.length, 2);
    });
  });

  // ── 10–12. Ranking reacts to reliability ──────────────────────────────────
  group('P1.3 ranking reacts to reliability', () {
    double scoreFor(ChainFallbackCandidate c) => ChainAdaptiveScoreService
        .calculateNodeScore(
          candidate: c,
          capabilityProfile: ChainCapabilityService.getBaselineCapability(
            'vless',
          ),
          globalTotalTrials: 20,
        )
        .totalScore;

    ChainFallbackCandidate candidateWith({
      required int successes,
      required int failures,
    }) {
      var stats = ChainReliabilityStats.initial(networkFingerprint: 'fp');
      for (var i = 0; i < successes; i++) {
        stats = stats.recordEvent(isSuccess: true, now: DateTime.now());
      }
      for (var i = 0; i < failures; i++) {
        stats = stats.recordEvent(isSuccess: false, now: DateTime.now());
      }
      return ChainFallbackCandidate(
        nodeName: 'N',
        role: FallbackCandidateRole.exit,
        // Must be keyed by the CURRENT fingerprint, otherwise the score service
        // falls back to the default prior and every candidate scores the same.
        statsByContext: {
          networkFingerprintProvider.getCurrentFingerprint(): stats,
        },
      );
    }

    test('10. better reliability → higher score', () {
      final good = scoreFor(candidateWith(successes: 10, failures: 0));
      final bad = scoreFor(candidateWith(successes: 0, failures: 5));
      expect(good, greaterThan(bad));
    });

    test('11. repeated failures → lower score than mixed', () {
      final mixed = scoreFor(candidateWith(successes: 5, failures: 1));
      final failing = scoreFor(candidateWith(successes: 1, failures: 5));
      expect(mixed, greaterThan(failing));
    });

    test('12. score changes after a new sample', () {
      final before = scoreFor(candidateWith(successes: 1, failures: 3));
      final after = scoreFor(candidateWith(successes: 6, failures: 3));
      expect(after, greaterThan(before));
    });
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
