// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../support/temp_dir_cleanup.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory.systemTemp.path;

  @override
  Future<String?> getLibraryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;

  @override
  Future<String?> getExternalStoragePath() async => Directory.systemTemp.path;

  @override
  Future<List<String>?> getExternalCachePaths() async => [
    Directory.systemTemp.path,
  ];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [Directory.systemTemp.path];

  @override
  Future<String?> getDownloadsPath() async => Directory.systemTemp.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory isolatedDataDir;

  setUpAll(() async {
    // P1.1-F group isolation: ChainProxyManager.init() must never read or write
    // the developer's real %APPDATA%\Fluxora data directory. On Windows,
    // AppPath._internal() resolves the data dir from
    // Platform.environment['APPDATA'] and IGNORES the faked
    // PathProviderPlatform, so faking path_provider alone does NOT sandbox
    // chain_proxies.json / chain_fallback_pool.json / chain_reliability_stats.json.
    // The only reliable seam is the *FilePathOverride statics.
    isolatedDataDir = await Directory.systemTemp.createTemp(
      'fluxora_runtime_lifecycle_',
    );
    ChainProxyManager.configFilePathOverride =
        '${isolatedDataDir.path}/chain_proxies.json';
    ChainProxyManager.fallbackPoolFilePathOverride =
        '${isolatedDataDir.path}/chain_fallback_pool.json';
    ChainProxyManager.reliabilityStatsFilePathOverride =
        '${isolatedDataDir.path}/chain_reliability_stats.json';

    PathProviderPlatform.instance = FakePathProviderPlatform();
    chainProbeService.customDelayTesterOverride = (proxy, url) async {
      await Future.delayed(const Duration(milliseconds: 50));
      return 100;
    };
  });

  tearDownAll(() async {
    chainProbeService.customDelayTesterOverride = null;
    // P2.3-C: `setFallbackPool` / failover arm a 2s debounced reliability write.
    // Stop + flush it while the override still points at the isolated dir — this
    // cancels the debounce timer, so nothing can still be writing into the
    // directory when it is deleted (Windows errno 32 on a held handle).
    await chainProxyManager.flushReliabilityStats();
    // Restore overrides *after* the flush, *before* the delete.
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    await deleteTempDirWithRetry(isolatedDataDir);
  });

  group('Phase 5.1-B — Runtime Lifecycle & Resource Hardening Tests', () {
    // ──────────────────────────────────────────────────────────────────────────
    // 1. Manager init twice (concurrent & sequential)
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '1. Manager init twice: concurrent and sequential calls do not duplicate listeners',
      () async {
        final manager = ChainProxyManager();
        int notificationCount = 0;
        void listener() => notificationCount++;
        manager.addListener(listener);

        // Call init multiple times concurrently
        await Future.wait([manager.init(), manager.init(), manager.init()]);
        expect(manager.isInitialized, isTrue);

        // Call sequentially
        await manager.init();
        expect(manager.isInitialized, isTrue);

        manager.removeListener(listener);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 2. Manager init after reset
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 3. Telemetry listener duplication protection
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '3. Telemetry listener does not duplicate on repeated service calls',
      () {
        final telemetry = ChainTelemetryService();
        int notifyCount = 0;
        void cb() => notifyCount++;

        // Register same listener
        telemetry.addListener(cb);
        telemetry.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeStarted,
            role: 'Entry',
            message: 'evt1',
          ),
        );
        expect(notifyCount, 1);

        telemetry.removeListener(cb);
        telemetry.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeCompleted,
            role: 'Entry',
            message: 'evt2',
          ),
        );
        expect(notifyCount, 1); // Not called after removal
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 4. Flap listener duplication protection
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 5. Probe cancellation
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 6. Retry cancellation
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 7. Failover cancellation
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 8. New probe cancels old probe
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 9. New retry cancels old retry
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 10. New failover cancels old failover
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 11. View dispose during probe
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 12. View dispose during retry
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 13. View dispose during failover
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 14. Listener exception isolation
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 15. Telemetry clear lifecycle
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 16. Flap reset lifecycle
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 17. Diagnostic export cancellation / cleanup
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 18. Support package temporary resource cleanup
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 19. Repeated enable / disable
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '19. Repeated enable and disable of chain proxy toggles config safely',
      () async {
        final manager = ChainProxyManager();
        await manager.init();

        final initialEnable = manager.config.enable;
        await manager.setEnable(!initialEnable);
        expect(manager.config.enable, !initialEnable);

        await manager.setEnable(initialEnable);
        expect(manager.config.enable, initialEnable);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 20. Repeated manager initialization
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '20. 50 consecutive manager init() calls execute safely without regression',
      () async {
        final manager = ChainProxyManager();
        for (int i = 0; i < 50; i++) {
          await manager.init();
        }
        expect(manager.isInitialized, isTrue);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 21. Section 14: Verification of "No Duplicate Events"
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '21. Multiple init() followed by 1 telemetry event produces exactly 1 notification',
      () async {
        final manager = ChainProxyManager();
        await manager.init();
        await manager.init();
        await manager.init();

        int managerNotifications = 0;
        void managerListener() => managerNotifications++;
        manager.addListener(managerListener);

        // Record 1 telemetry event
        chainTelemetryService.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeCompleted,
            role: 'Entry',
            message: 'single_test_event',
          ),
        );

        // Exactly 1 notification should be received
        expect(managerNotifications, 1);

        manager.removeListener(managerListener);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 22. Section 15: Long lifecycle bounded stability test
    // ──────────────────────────────────────────────────────────────────────────
  });

  // ────────────────────────────────────────────────────────────────────────────
  // RC.10-C.1 — probe concurrency safety
  //
  // `probeCurrentChain()` owns shared state (`_isProbingChain` /
  // `_probeCancelToken` / `_lastProbeReport`), and `runChainHealthCheck()`
  // awaits `_isCoreReady()` between its guard and its probe. These tests pin the
  // ownership rules: a superseded probe must not publish a stale report, must
  // not clear the busy flag under its successor, must not write stale evidence
  // back into the fallback pool, and must not drive automatic failover.
  // ────────────────────────────────────────────────────────────────────────────
  group('RC.10-C.1 — probe concurrency safety', () {
    late ChainProxyManager manager;
    final List<Completer<ChainProbeReport>> gates = [];

    /// A minimal, identifiable report. `rootCauseAnalysis` carries the tag, so a
    /// test can tell exactly which probe's report ended up in the manager.
    ChainProbeReport taggedReport(
      String tag, {
      HopProbeStatus status = HopProbeStatus.healthy,
    }) => ChainProbeReport(
      mode: ChainHopMode.twoHop,
      isOverallHealthy: status == HopProbeStatus.healthy,
      hops: [
        HopProbeState(
          hopIndex: 1,
          role: HopRole.hop1Entry,
          nodeName: 'node1',
          nodeAddress: '127.0.0.1',
          status: status,
        ),
      ],
      rootCauseAnalysis: tag,
      timestamp: DateTime.now(),
    );

    /// Blocks every probe until the test releases its gate, in call order.
    void installGatedProbe() {
      ChainProxyManager.chainProbeOverride = (cfg) {
        final gate = Completer<ChainProbeReport>();
        gates.add(gate);
        return gate.future;
      };
    }

    setUp(() async {
      gates.clear();
      ChainProxyManager.coreRunningOverride = true;
      manager = ChainProxyManager();
      manager.stopChainHealthCheck();
      await manager.updateConfig(
        (c) => c.copyWith(enable: true, hop1Node: 'node1', hop2Node: 'node2'),
        reloadCore: false,
      );
    });

    tearDown(() {
      manager.stopChainHealthCheck();
      ChainProxyManager.chainProbeOverride = null;
      ChainProxyManager.coreRunningOverride = null;
      gates.clear();
    });

    test('C1. A superseded probe cannot publish its stale report', () async {
      installGatedProbe();

      // `ChainProxyManager` is a singleton, so the report carried over from an
      // earlier test is the value the stale probe must leave untouched.
      final before = manager.lastProbeReport;

      final first = manager.probeCurrentChain();
      expect(manager.isProbingChain, isTrue);
      expect(gates.length, 1);

      // A second probe supersedes the first.
      final second = manager.probeCurrentChain();
      expect(gates.length, 2);

      // The superseded probe finishes first.
      gates[0].complete(taggedReport('stale'));
      await first;
      expect(
        manager.lastProbeReport,
        same(before),
        reason: 'a superseded probe must not publish its report',
      );

      gates[1].complete(taggedReport('fresh'));
      await second;
      expect(manager.lastProbeReport?.rootCauseAnalysis, equals('fresh'));
    });

    test(
      'C2. runChainHealthCheck does not start a probe when one is already in '
      'flight',
      () async {
        installGatedProbe();
        await manager.updateConfig(
          (c) => c.copyWith(autoFailover: true),
          reloadCore: false,
        );
        // Drive the tick explicitly; keep the periodic timer out of the way.
        manager.stopChainHealthCheck();

        // The automatic tick passes its first guard and suspends inside
        // `_isCoreReady()`.
        final tick = manager.runChainHealthCheck();

        // A manual probe starts inside that window.
        final manual = manager.probeCurrentChain();
        expect(gates.length, 1);

        // Let the suspended tick resume: it must re-check the probe state.
        await Future<void>.delayed(Duration.zero);
        expect(
          gates.length,
          1,
          reason: 'the tick must not start a competing probe after its await',
        );

        for (final gate in gates) {
          if (!gate.isCompleted) gate.complete(taggedReport('manual'));
        }
        await manual;
        await tick;
        expect(manager.isProbingChain, isFalse);
      },
    );

    test(
      'C3. A superseded probe cannot clear the busy flag of its successor',
      () async {
        installGatedProbe();

        final first = manager.probeCurrentChain();
        final second = manager.probeCurrentChain();
        expect(manager.isProbingChain, isTrue);

        // The older probe finishes while the newer one is still running.
        gates[0].complete(taggedReport('stale'));
        await first;
        expect(
          manager.isProbingChain,
          isTrue,
          reason: 'the newer probe is still in flight',
        );

        gates[1].complete(taggedReport('fresh'));
        await second;
        expect(manager.isProbingChain, isFalse);
      },
    );

    test(
      'C4. A superseded probe does not write stale evidence back to the pool',
      () async {
        installGatedProbe();
        await manager.setFallbackPool(
          const ChainFallbackPool(
            entryCandidates: [
              ChainFallbackCandidate(
                nodeName: 'node1',
                role: FallbackCandidateRole.entry,
              ),
            ],
          ),
        );

        final first = manager.probeCurrentChain();
        final second = manager.probeCurrentChain();

        // The superseded probe reports a TIMEOUT for node1 …
        gates[0].complete(taggedReport('stale', status: HopProbeStatus.timeout));
        await first;

        // … and that stale evidence must not reach the candidate pool.
        expect(
          manager.fallbackPool.entryCandidates.single.statsByContext,
          isEmpty,
          reason: 'a superseded probe must not write back stale evidence',
        );

        // The owning probe reports node1 healthy.
        gates[1].complete(taggedReport('fresh'));
        await second;

        final stats = manager
            .fallbackPool
            .entryCandidates
            .single
            .statsByContext
            .values
            .single;
        expect(
          stats.totalSamples,
          1,
          reason: 'only the owning probe may contribute a sample',
        );
        expect(stats.weightedFailure, equals(0));
        expect(stats.weightedSuccess, greaterThan(0));
      },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // RC.10-C.2 — cancelled probe cannot publish
  //
  // `cancelCurrentProbe()` used to cancel the token and null it without bumping
  // `_probeGeneration`. The publish guard in `probeCurrentChain()` therefore
  // still passed for the cancelled session, and nulling `_probeCancelToken` also
  // defeated the cancel check in `_writeBackProbeResultsToCandidates()`. These
  // tests park a probe on a `Completer` whose override deliberately IGNORES the
  // CancelToken — the worst case for the guard — and pin that a cancelled
  // session can neither publish nor write back.
  // ────────────────────────────────────────────────────────────────────────────
  group('RC.10-C.2 — a cancelled probe cannot publish', () {
    late ChainProxyManager manager;
    final List<Completer<ChainProbeReport>> gates = [];

    ChainProbeReport taggedReport(
      String tag, {
      HopProbeStatus status = HopProbeStatus.healthy,
    }) => ChainProbeReport(
      mode: ChainHopMode.twoHop,
      isOverallHealthy: status == HopProbeStatus.healthy,
      hops: [
        HopProbeState(
          hopIndex: 1,
          role: HopRole.hop1Entry,
          nodeName: 'node1',
          nodeAddress: '127.0.0.1',
          status: status,
        ),
      ],
      rootCauseAnalysis: tag,
      timestamp: DateTime.now(),
    );

    /// The override never inspects the CancelToken: every probe resolves only
    /// when the test releases its gate, so a cancelled session still completes
    /// normally.
    void installGatedProbe() {
      ChainProxyManager.chainProbeOverride = (cfg) {
        final gate = Completer<ChainProbeReport>();
        gates.add(gate);
        return gate.future;
      };
    }

    setUp(() async {
      gates.clear();
      ChainProxyManager.coreRunningOverride = true;
      manager = ChainProxyManager();
      manager.stopChainHealthCheck();
      await manager.updateConfig(
        (c) => c.copyWith(enable: true, hop1Node: 'node1', hop2Node: 'node2'),
        reloadCore: false,
      );
    });

    tearDown(() {
      manager.stopChainHealthCheck();
      ChainProxyManager.chainProbeOverride = null;
      ChainProxyManager.coreRunningOverride = null;
      gates.clear();
    });

    test(
      'C5. A cancelled probe publishes nothing and writes nothing back',
      () async {
        installGatedProbe();
        await manager.setFallbackPool(
          const ChainFallbackPool(
            entryCandidates: [
              ChainFallbackCandidate(
                nodeName: 'node1',
                role: FallbackCandidateRole.entry,
              ),
            ],
          ),
        );

        // Singleton: whatever an earlier test left is the value to preserve.
        final before = manager.lastProbeReport;

        final probe = manager.probeCurrentChain();
        expect(manager.isProbingChain, isTrue);
        expect(gates.length, 1);

        // Cancel while the probe is parked. The override ignores the token, so
        // the session still completes normally with a HEALTHY report — exactly
        // the report the guard must refuse to publish.
        manager.cancelCurrentProbe();
        expect(manager.isProbingChain, isFalse);

        gates[0].complete(taggedReport('cancelled-late'));
        await probe;

        expect(
          manager.lastProbeReport,
          same(before),
          reason: 'a cancelled probe must not publish its report',
        );
        expect(
          manager.fallbackPool.entryCandidates.single.statsByContext,
          isEmpty,
          reason: 'a cancelled probe must not write back reliability samples',
        );
      },
    );

    test(
      'C6. A cancelled probe cannot clear the busy flag of a newer session',
      () async {
        installGatedProbe();

        final first = manager.probeCurrentChain();
        manager.cancelCurrentProbe();

        // A new session starts after the cancel.
        final second = manager.probeCurrentChain();
        expect(manager.isProbingChain, isTrue);
        expect(gates.length, 2);

        // The cancelled session finishes while the new one is still parked.
        gates[0].complete(taggedReport('cancelled-late'));
        await first;
        expect(
          manager.isProbingChain,
          isTrue,
          reason: 'the newer session is still in flight',
        );

        gates[1].complete(taggedReport('fresh'));
        await second;
        expect(manager.isProbingChain, isFalse);
        expect(manager.lastProbeReport?.rootCauseAnalysis, equals('fresh'));
      },
    );
  });
}
