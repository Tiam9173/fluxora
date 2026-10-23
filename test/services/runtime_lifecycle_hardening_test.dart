// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_probe_service.dart';
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

    // ──────────────────────────────────────────────────────────────────────────
    // 2. Manager init after reset
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 3. Telemetry listener duplication protection
    // ──────────────────────────────────────────────────────────────────────────

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

    // ──────────────────────────────────────────────────────────────────────────
    // 20. Repeated manager initialization
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // 21. Section 14: Verification of "No Duplicate Events"
    // ──────────────────────────────────────────────────────────────────────────

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
      await manager.updateConfig(
        (c) => c.copyWith(enable: true, hop1Node: 'node1', hop2Node: 'node2'),
        reloadCore: false,
      );
    });

    tearDown(() {
      ChainProxyManager.chainProbeOverride = null;
      ChainProxyManager.coreRunningOverride = null;
      gates.clear();
    });




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
      await manager.updateConfig(
        (c) => c.copyWith(enable: true, hop1Node: 'node1', hop2Node: 'node2'),
        reloadCore: false,
      );
    });

    tearDown(() {
      ChainProxyManager.chainProbeOverride = null;
      ChainProxyManager.coreRunningOverride = null;
      gates.clear();
    });


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
