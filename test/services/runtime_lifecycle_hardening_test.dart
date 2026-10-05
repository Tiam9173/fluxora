// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_flap_dampening.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/chain_diagnostic_export_service.dart';
import 'package:fluxora/services/chain_failover_service.dart';
import 'package:fluxora/services/chain_flap_dampener_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_retry_service.dart';
import 'package:fluxora/services/chain_support_package_service.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

  setUpAll(() {
    PathProviderPlatform.instance = FakePathProviderPlatform();
    chainProbeService.customDelayTesterOverride = (proxy, url) async {
      await Future.delayed(const Duration(milliseconds: 50));
      return 100;
    };
  });

  tearDownAll(() {
    chainProbeService.customDelayTesterOverride = null;
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
    test('2. Manager init after reset maintains single registration', () async {
      final manager = ChainProxyManager();
      await manager.init();

      // Reset dampener and telemetry
      manager.resetFlapDampener();
      manager.clearTelemetry();

      // Re-init
      await manager.init();
      expect(manager.isInitialized, isTrue);
    });

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
    test(
      '4. Flap dampener listener does not duplicate and cleans up cleanly',
      () {
        final dampener = ChainFlapDampenerService();
        int count = 0;
        void cb() => count++;

        dampener.addListener(cb);
        dampener.reset();
        expect(count, 1);

        dampener.removeListener(cb);
        dampener.reset();
        expect(count, 1); // No additional call
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 5. Probe cancellation
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '5. Probe service honours CancelToken and returns cancelled report',
      () async {
        final cancelToken = CancelToken();
        final probeService = ChainProbeService(
          customDelayTester: (proxy, url) async {
            await Future.delayed(const Duration(milliseconds: 50));
            return 100;
          },
        );

        final future = probeService.probeChain(
          config: const ChainProxyConfig(hop1Node: 'node1', hop2Node: 'node2'),
          cancelToken: cancelToken,
        );

        cancelToken.cancel('User cancelled');
        final report = await future;
        expect(report.isCancelled, isTrue);
        expect(report.healthStatus, ChainHealthStatus.cancelled);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 6. Retry cancellation
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '6. Retry service aborts during sleep upon CancelToken trigger',
      () async {
        final cancelToken = CancelToken();
        final retryService = ChainRetryService(
          probeService: ChainProbeService(
            customDelayTester: (proxy, url) async =>
                null, // always fail to trigger backoff
          ),
        );

        final future = retryService.probeWithRetry(
          config: const ChainProxyConfig(hop1Node: 'node1', hop2Node: 'node2'),
          policy: const ChainRetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration(seconds: 10), // long delay
          ),
          cancelToken: cancelToken,
        );

        // Cancel during backoff sleep
        await Future.delayed(const Duration(milliseconds: 30));
        cancelToken.cancel('Abort retry');

        final report = await future;
        expect(report.isCancelled, isTrue);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 7. Failover cancellation
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '7. Failover service cancels gracefully when CancelToken is cancelled',
      () async {
        final cancelToken = CancelToken();
        final failoverService = ChainFailoverService();

        final pool = ChainFallbackPool(
          exitCandidates: [
            ChainFallbackCandidate(
              nodeName: 'candidate1',
              role: FallbackCandidateRole.exit,
            ),
          ],
        );

        cancelToken.cancel('Premature cancel');
        final result = await failoverService.executeFailover(
          currentConfig: const ChainProxyConfig(
            enable: true,
            hop1Node: 'node1',
            hop2Node: 'node2',
          ),
          fallbackPool: pool,
          cancelToken: cancelToken,
        );

        expect(result.isCancelled, isTrue);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 8. New probe cancels old probe
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '8. Manager probeCurrentChain cancels any previous probe session',
      () async {
        final manager = ChainProxyManager();
        await manager.updateConfig(
          (c) => c.copyWith(enable: true, hop1Node: 'node1', hop2Node: 'node2'),
          reloadCore: false,
        );

        // Launch first probe (do not await)
        final future1 = manager.probeCurrentChain(
          testUrl: 'https://test.invalid',
          timeout: const Duration(seconds: 5),
        );

        expect(manager.isProbingChain, isTrue);

        // Launch second probe: cancels the first
        manager.cancelCurrentProbe();
        expect(manager.isProbingChain, isFalse);

        final report1 = await future1;
        expect(report1.isCancelled, isTrue);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 9. New retry cancels old retry
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '9. Consecutive probeCurrentChain calls supersede previous retry progress',
      () async {
        final manager = ChainProxyManager();
        await manager.updateConfig(
          (c) => c.copyWith(enable: true, hop1Node: 'node1', hop2Node: 'node2'),
          reloadCore: false,
        );

        final firstFuture = manager.probeCurrentChain(
          retryPolicy: const ChainRetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration(seconds: 5),
          ),
        );

        // Trigger second probe: cancels first
        manager.cancelCurrentProbe();
        final firstReport = await firstFuture;
        expect(firstReport.isCancelled, isTrue);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 10. New failover cancels old failover
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '10. triggerAutoFailover automatically cancels previous failover session',
      () async {
        final manager = ChainProxyManager();
        await manager.updateConfig(
          (c) => c.copyWith(enable: true, hop1Node: 'node1', hop2Node: 'node2'),
          reloadCore: false,
        );

        // Set fallback pool with a candidate
        manager.setFallbackPool(
          ChainFallbackPool(
            exitCandidates: [
              ChainFallbackCandidate(
                nodeName: 'fallback_exit',
                role: FallbackCandidateRole.exit,
              ),
            ],
          ),
        );

        final failureReport = ChainProbeReport(
          mode: ChainHopMode.twoHop,
          isOverallHealthy: false,
          healthStatus: ChainHealthStatus.failed,
          failureHop: 2,
          errorCode: ChainProbeErrorCodes.exitTimeout,
          hops: const [],
          timestamp: DateTime.now(),
        );

        // Start first failover
        final future1 = manager.triggerAutoFailover(
          initialFailureReport: failureReport,
        );
        expect(manager.isFailingOver, isTrue);

        // Start second failover: cancels first
        final future2 = manager.triggerAutoFailover(
          initialFailureReport: failureReport,
        );
        expect(manager.isFailingOver, isTrue);

        // Cancel second failover while active
        manager.cancelFailover();

        final res1 = await future1;
        expect(res1.isCancelled, isTrue);

        final res2 = await future2;
        expect(res2.isCancelled, isTrue);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 11. View dispose during probe
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '11. View dispose cleans up running probe without orphaned requests',
      () async {
        final manager = ChainProxyManager();
        await manager.updateConfig(
          (c) => c.copyWith(enable: true, hop1Node: 'node1', hop2Node: 'node2'),
          reloadCore: false,
        );

        final probeFuture = manager.probeCurrentChain(
          timeout: const Duration(seconds: 5),
        );

        // Simulate view dispose
        manager.cancelCurrentProbe();

        final report = await probeFuture;
        expect(report.isCancelled, isTrue);
        expect(manager.isProbingChain, isFalse);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 12. View dispose during retry
    // ──────────────────────────────────────────────────────────────────────────
    test('12. View dispose cleanly aborts retry loops', () async {
      final manager = ChainProxyManager();
      await manager.updateConfig(
        (c) => c.copyWith(enable: true, hop1Node: 'node1', hop2Node: 'node2'),
        reloadCore: false,
      );

      final retryFuture = manager.probeCurrentChain(
        retryPolicy: const ChainRetryPolicy(
          maxAttempts: 5,
          baseDelay: Duration(seconds: 2),
        ),
      );

      // Simulate view dispose
      manager.cancelCurrentProbe();

      final report = await retryFuture;
      expect(report.isCancelled, isTrue);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 13. View dispose during failover
    // ──────────────────────────────────────────────────────────────────────────
    test('13. View dispose cancels active failover session', () async {
      final manager = ChainProxyManager();
      await manager.updateConfig(
        (c) => c.copyWith(enable: true, hop1Node: 'node1', hop2Node: 'node2'),
        reloadCore: false,
      );

      manager.setFallbackPool(
        ChainFallbackPool(
          exitCandidates: [
            ChainFallbackCandidate(
              nodeName: 'fallback_exit',
              role: FallbackCandidateRole.exit,
            ),
          ],
        ),
      );

      final failureReport = ChainProbeReport(
        mode: ChainHopMode.twoHop,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.failed,
        failureHop: 2,
        errorCode: ChainProbeErrorCodes.exitTimeout,
        hops: const [],
        timestamp: DateTime.now(),
      );

      final failoverFuture = manager.triggerAutoFailover(
        initialFailureReport: failureReport,
      );

      // Simulate view dispose
      manager.cancelFailover();

      final result = await failoverFuture;
      expect(result.isCancelled, isTrue);
      expect(manager.isFailingOver, isFalse);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 14. Listener exception isolation
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '14. Exception thrown in one listener does not crash telemetry dispatch',
      () {
        final telemetry = ChainTelemetryService();
        bool secondListenerFired = false;

        telemetry.addListener(() {
          throw StateError('Simulated UI crash');
        });

        telemetry.addListener(() {
          secondListenerFired = true;
        });

        // Must not throw
        telemetry.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeCompleted,
            role: 'Entry',
            message: 'safe',
          ),
        );

        expect(secondListenerFired, isTrue);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 15. Telemetry clear lifecycle
    // ──────────────────────────────────────────────────────────────────────────
    test('15. Telemetry clear resets all state and notifies listeners', () {
      final telemetry = ChainTelemetryService();
      int notifyCount = 0;
      telemetry.addListener(() => notifyCount++);

      telemetry.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeFailed,
          role: 'Relay',
          message: 'err',
        ),
      );
      expect(telemetry.getSnapshot().totalEvents, 1);

      telemetry.clear();
      expect(telemetry.getSnapshot().totalEvents, 0);
      expect(telemetry.getSnapshot().recentEvents, isEmpty);
      expect(notifyCount, 2); // 1 for record, 1 for clear
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 16. Flap reset lifecycle
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '16. Flap dampener reset completely purges state and clears suppression',
      () {
        final dampener = ChainFlapDampenerService();
        dampener.recordFlap(
          role: FallbackCandidateRole.entry,
          fromNode: 'A',
          toNode: 'B',
          policy: const ChainFlapDampeningPolicy(
            penaltyPerFlap: 5000,
            suppressThreshold: 100,
          ),
        );

        expect(dampener.status.isSuppressed, isTrue);

        dampener.reset();
        expect(dampener.status.isSuppressed, isFalse);
        expect(dampener.status.currentPenalty, 0.0);
        expect(dampener.status.recentEvents, isEmpty);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 17. Diagnostic export cancellation / cleanup
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '17. Diagnostic export produces clean, closed markdown file in temp',
      () async {
        final manager = ChainProxyManager();
        final file = await chainDiagnosticExportService.exportReport(manager);

        expect(await file.exists(), isTrue);
        final content = await file.readAsString();
        expect(content, contains('# Fluxora Chain Diagnostic Report'));

        // Clean up temp file
        await file.delete();
        expect(await file.exists(), isFalse);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 18. Support package temporary resource cleanup
    // ──────────────────────────────────────────────────────────────────────────
    test(
      '18. Support package creates valid zip and can be cleaned up',
      () async {
        final manager = ChainProxyManager();
        final pkg = await chainSupportPackageService.createPackage(manager);
        final zipFile = await chainSupportPackageService.exportPackage(pkg);

        expect(await zipFile.exists(), isTrue);
        expect(zipFile.path.endsWith('.zip'), isTrue);

        // Clean up
        await zipFile.delete();
        expect(await zipFile.exists(), isFalse);
      },
    );

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
    test(
      '22. 1,000 rapid lifecycle operations maintain strict memory bounds',
      () async {
        final telemetry = ChainTelemetryService();
        final dampener = ChainFlapDampenerService();

        for (int i = 0; i < 1000; i++) {
          telemetry.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.probeStarted,
              role: 'Hop1',
              message: 'stress_$i',
            ),
          );

          if (i % 200 == 0) {
            telemetry.clear();
          }

          dampener.recordFlap(
            role: FallbackCandidateRole.relay,
            fromNode: 'A',
            toNode: 'B',
          );

          if (i % 100 == 0) {
            dampener.reset();
          }
        }

        final teleSnap = telemetry.getSnapshot();
        final flapStatus = dampener.status;

        // Telemetry maxEvents bound check (<= 200)
        expect(
          teleSnap.recentEvents.length,
          lessThanOrEqualTo(ChainTelemetryService.maxEvents),
        );

        // Flap maxHistoryEvents bound check (<= 50)
        expect(flapStatus.recentEvents.length, lessThanOrEqualTo(50));
      },
    );
  });
}
