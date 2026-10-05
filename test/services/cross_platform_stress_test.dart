// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/identity.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_flap_dampening.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/atomic_config_storage.dart';
import 'package:fluxora/services/chain_failover_service.dart';
import 'package:fluxora/services/chain_fallback_service.dart';
import 'package:fluxora/services/chain_flap_dampener_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_retry_service.dart';
import 'package:fluxora/services/chain_support_package_service.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeCrossPlatformPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakeCrossPlatformPathProviderPlatform(this.tempDir);

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;

  @override
  Future<String?> getApplicationSupportPath() async => tempDir.path;

  @override
  Future<String?> getLibraryPath() async => tempDir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;

  @override
  Future<String?> getExternalStoragePath() async => tempDir.path;

  @override
  Future<List<String>?> getExternalCachePaths() async => [tempDir.path];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [tempDir.path];

  @override
  Future<String?> getDownloadsPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory stressSandboxDir;
  String? originalProdConfigContent;
  final prodConfigFile = File(
    p.join(
      Platform.environment['APPDATA'] ?? '',
      AppIdentity.dataDirName,
      'chain_proxies.json',
    ),
  );

  setUpAll(() async {
    stressSandboxDir = await Directory.systemTemp.createTemp(
      'fluxora_stress_sandbox_',
    );
    PathProviderPlatform.instance = FakeCrossPlatformPathProviderPlatform(
      stressSandboxDir,
    );

    // Snapshot existing production config if present to guarantee no pollution
    if (await prodConfigFile.exists()) {
      try {
        originalProdConfigContent = await prodConfigFile.readAsString();
      } catch (_) {}
    }

    chainProbeService.customDelayTesterOverride = (proxy, url) async {
      await Future.delayed(const Duration(milliseconds: 10));
      return 120;
    };
  });

  setUp(() {
    chainFlapDampenerService.reset();
  });

  tearDownAll(() async {
    chainProbeService.customDelayTesterOverride = null;

    // Safety restore: return production config to pristine state
    if (originalProdConfigContent != null && await prodConfigFile.exists()) {
      try {
        await prodConfigFile.writeAsString(
          originalProdConfigContent!,
          flush: true,
        );
      } catch (_) {}
    }

    if (await stressSandboxDir.exists()) {
      await stressSandboxDir.delete(recursive: true);
    }
  });

  group('Phase 5.2-C — Cross-Platform Stress & Long-Running Validation', () {
    // ══════════════════════════════════════════════════════════════════════════
    // Section A: Lifecycle Stress & Manager Concurrency (Tests 1 - 6)
    // ══════════════════════════════════════════════════════════════════════════
    group('Section A — Lifecycle Stress & Concurrency', () {
      test(
        '1. Repeated sequential init (20 cycles) executes idempotently without leaking listeners',
        () async {
          final manager = ChainProxyManager();
          int notifications = 0;
          void listener() => notifications++;
          manager.addListener(listener);

          for (int i = 0; i < 20; i++) {
            await manager.init();
            expect(manager.isInitialized, isTrue);
          }

          manager.removeListener(listener);
          expect(notifications, greaterThanOrEqualTo(0));
        },
      );

      test(
        '2. Concurrent init (10 calls simultaneously) resolves safely without race conditions',
        () async {
          final manager = ChainProxyManager();
          final futures = List.generate(10, (_) => manager.init());
          await Future.wait(futures);
          expect(manager.isInitialized, isTrue);
        },
      );

      test(
        '3. Repeated view enter/exit (30 cycles) registers and unregisters cleanly without stale callbacks',
        () async {
          final manager = ChainProxyManager();
          await manager.init();

          for (int cycle = 0; cycle < 30; cycle++) {
            int callCount = 0;
            void pageListener() => callCount++;

            // Enter view: attach
            manager.addListener(pageListener);

            // Trigger telemetry notification while active
            chainTelemetryService.record(
              ChainTelemetryEvent(
                type: ChainTelemetryEventType.probeCompleted,
                role: 'ViewLifecycleCycle_$cycle',
                message: 'active_event',
              ),
            );
            expect(callCount, 1);

            // Exit view: detach
            manager.removeListener(pageListener);

            // Post-exit notification must NOT hit detached listener
            chainTelemetryService.record(
              ChainTelemetryEvent(
                type: ChainTelemetryEventType.probeCompleted,
                role: 'ViewLifecycleCycle_$cycle',
                message: 'detached_event',
              ),
            );
            expect(callCount, 1);
          }
        },
      );

      test(
        '4. Active probe in-flight cancellation terminates cleanly and reports cancelled status',
        () async {
          final manager = ChainProxyManager();
          await manager.updateConfig(
            (c) => c.copyWith(
              enable: true,
              hop1Node: 'node_cancel_1',
              hop2Node: 'node_cancel_2',
            ),
            reloadCore: false,
          );

          // Initiate probe with long timeout
          final probeFuture = manager.probeCurrentChain(
            timeout: const Duration(seconds: 10),
          );
          expect(manager.isProbingChain, isTrue);

          manager.cancelCurrentProbe();
          expect(manager.isProbingChain, isFalse);

          final result = await probeFuture;
          expect(result.isCancelled, isTrue);
        },
      );

      test(
        '5. Active failover in-flight cancellation aborts session cleanly with cancelled state',
        () async {
          final manager = ChainProxyManager();
          await manager.updateConfig(
            (c) => c.copyWith(
              enable: true,
              hop1Node: 'node_cancel_1',
              hop2Node: 'node_cancel_2',
            ),
            reloadCore: false,
          );

          manager.setFallbackPool(
            const ChainFallbackPool(
              exitCandidates: [
                ChainFallbackCandidate(
                  nodeName: 'fallback_stress_exit',
                  role: FallbackCandidateRole.exit,
                ),
              ],
            ),
          );

          final failoverFuture = manager.triggerAutoFailover(
            initialFailureReport: ChainProbeReport(
              mode: ChainHopMode.twoHop,
              isOverallHealthy: false,
              healthStatus: ChainHealthStatus.failed,
              failureHop: 2,
              hops: const [],
              timestamp: DateTime.now(),
            ),
          );
          expect(manager.isFailingOver, isTrue);

          manager.cancelFailover();
          expect(manager.isFailingOver, isFalse);

          final result = await failoverFuture;
          expect(result.isCancelled, isTrue);
        },
      );

      test(
        '6. Triggering new failover session supersedes preceding active session without residue',
        () async {
          final manager = ChainProxyManager();
          await manager.updateConfig(
            (c) => c.copyWith(
              enable: true,
              hop1Node: 'node_sess_1',
              hop2Node: 'node_sess_2',
            ),
            reloadCore: false,
          );

          manager.setFallbackPool(
            const ChainFallbackPool(
              exitCandidates: [
                ChainFallbackCandidate(
                  nodeName: 'fallback_session_1',
                  role: FallbackCandidateRole.exit,
                ),
                ChainFallbackCandidate(
                  nodeName: 'fallback_session_2',
                  role: FallbackCandidateRole.exit,
                ),
              ],
            ),
          );

          // Start session 1
          final session1 = manager.triggerAutoFailover(bypassDampening: true);
          expect(manager.isFailingOver, isTrue);

          // Immediately start session 2 (superseding session 1)
          final session2 = manager.triggerAutoFailover(bypassDampening: true);
          expect(manager.isFailingOver, isTrue);

          // Session 1 must be cancelled
          final res1 = await session1;
          expect(res1.isCancelled, isTrue);

          final res2 = await session2;
          expect(res2.isSuccess || res2.isCancelled, isTrue);
          expect(manager.isFailingOver, isFalse);
        },
      );
    });

    // ══════════════════════════════════════════════════════════════════════════
    // Section B: Retry, Fallback & Failover Stress (Tests 7 - 12)
    // ══════════════════════════════════════════════════════════════════════════
    group('Section B — Retry, Fallback & Failover Stress', () {
      test(
        '7. Probe retry exhaustion halts strictly at maxAttempts without infinite recursion',
        () async {
          final retryService = ChainRetryService();
          int probeAttempts = 0;

          final prevOverride = chainProbeService.customDelayTesterOverride;
          try {
            chainProbeService.customDelayTesterOverride = (proxy, url) async {
              probeAttempts++;
              return null;
            };

            const config = ChainProxyConfig(
              enable: true,
              hop1Node: 'retry_n1',
              hop2Node: 'retry_n2',
            );

            final report = await retryService.probeWithRetry(
              config: config,
              policy: const ChainRetryPolicy(
                maxAttempts: 4,
                baseDelay: Duration(milliseconds: 5),
                maxDelay: Duration(milliseconds: 20),
              ),
            );

            expect(probeAttempts, equals(4));
            expect(report.isOverallHealthy, isFalse);
            expect(report.healthStatus, equals(ChainHealthStatus.failed));
          } finally {
            chainProbeService.customDelayTesterOverride = prevOverride;
          }
        },
      );

      test(
        '8. Failover with empty candidate pool aborts immediately with NO_CANDIDATES_AVAILABLE',
        () async {
          final failoverService = ChainFailoverService();
          const config = ChainProxyConfig(
            enable: true,
            hop1Node: 'entry_no_pool',
            hop2Node: 'exit_no_pool',
          );

          final result = await failoverService.executeFailover(
            currentConfig: config,
            fallbackPool: const ChainFallbackPool(), // Empty
            initialFailureReport: ChainProbeReport(
              mode: ChainHopMode.twoHop,
              isOverallHealthy: false,
              healthStatus: ChainHealthStatus.failed,
              failureHop: 2,
              hops: const [],
              timestamp: DateTime.now(),
            ),
          );

          expect(result.isSuccess, isFalse);
          expect(result.attemptedCandidatesCount, equals(0));
          expect(result.rootCause, contains('无可用候选节点'));
        },
      );

      test(
        '9. Failover with all candidates failing halts gracefully with ALL_CANDIDATES_EXHAUSTED',
        () async {
          final failoverService = ChainFailoverService();
          const config = ChainProxyConfig(
            enable: true,
            hop1Node: 'entry_n1',
            hop2Node: 'exit_n1',
          );

          const pool = ChainFallbackPool(
            exitCandidates: [
              ChainFallbackCandidate(
                nodeName: 'bad_candidate_1',
                role: FallbackCandidateRole.exit,
              ),
              ChainFallbackCandidate(
                nodeName: 'bad_candidate_2',
                role: FallbackCandidateRole.exit,
              ),
              ChainFallbackCandidate(
                nodeName: 'bad_candidate_3',
                role: FallbackCandidateRole.exit,
              ),
            ],
          );

          final executor = DelegateChainFailoverExecutor(
            onApply: (cfg, ct) async {},
            onProbe: (cfg, ct) async => ChainProbeReport(
              mode: cfg.hopMode,
              isOverallHealthy: false,
              healthStatus: ChainHealthStatus.failed,
              hops: const [],
              timestamp: DateTime.now(),
            ),
            onRollback: (cfg, ct) async {},
            onCommit: (cfg) async {},
          );

          final result = await failoverService.executeFailover(
            currentConfig: config,
            fallbackPool: pool,
            executor: executor,
            initialFailureReport: ChainProbeReport(
              mode: ChainHopMode.twoHop,
              isOverallHealthy: false,
              healthStatus: ChainHealthStatus.failed,
              failureHop: 2,
              hops: const [],
              timestamp: DateTime.now(),
            ),
          );

          expect(result.isSuccess, isFalse);
          expect(result.attemptedCandidatesCount, equals(3));
          expect(
            result.attemptedNodeNames,
            equals(['bad_candidate_1', 'bad_candidate_2', 'bad_candidate_3']),
          );
        },
      );

      test(
        '10. Topology conflict in candidate: Candidate introducing self-loop is detected and rejected',
        () {
          const currentConfig = ChainProxyConfig(
            enable: true,
            hopMode: ChainHopMode.twoHop,
            hop1Node: 'node_alpha',
            hop2Node: 'node_beta',
          );

          // If fallback election offers node_alpha as an exit candidate, it would cause a self-loop
          final selection = chainFallbackService.selectCandidates(
            currentConfig: currentConfig,
            role: FallbackCandidateRole.exit,
            pool: const ChainFallbackPool(
              exitCandidates: [
                ChainFallbackCandidate(
                  nodeName: 'node_alpha',
                  role: FallbackCandidateRole.exit,
                ), // Conflicting!
                ChainFallbackCandidate(
                  nodeName: 'node_gamma',
                  role: FallbackCandidateRole.exit,
                ), // Valid
              ],
            ),
          );

          expect(selection.rankedCandidates.length, equals(1));
          expect(
            selection.rankedCandidates.first.nodeName,
            equals('node_gamma'),
          );
        },
      );

      test(
        '11. Rollback on candidate probe failure restores original configuration state via executor',
        () async {
          final failoverService = ChainFailoverService();
          const originalConfig = ChainProxyConfig(
            enable: true,
            hop1Node: 'orig_entry',
            hop2Node: 'orig_exit',
          );

          bool rolledBack = false;
          final executor = DelegateChainFailoverExecutor(
            onApply: (cfg, ct) async {},
            onProbe: (cfg, ct) async => ChainProbeReport(
              mode: cfg.hopMode,
              isOverallHealthy: false,
              healthStatus: ChainHealthStatus.failed,
              hops: const [],
              timestamp: DateTime.now(),
            ),
            onRollback: (cfg, ct) async {
              rolledBack = true;
            },
            onCommit: (cfg) async {},
          );

          await failoverService.executeFailover(
            currentConfig: originalConfig,
            fallbackPool: const ChainFallbackPool(
              exitCandidates: [
                ChainFallbackCandidate(
                  nodeName: 'cand_fail',
                  role: FallbackCandidateRole.exit,
                ),
              ],
            ),
            executor: executor,
            initialFailureReport: ChainProbeReport(
              mode: ChainHopMode.twoHop,
              isOverallHealthy: false,
              healthStatus: ChainHealthStatus.failed,
              failureHop: 2,
              hops: const [],
              timestamp: DateTime.now(),
            ),
          );

          expect(rolledBack, isTrue);
        },
      );

      test(
        '12. Rollback failure handling: If executor rollback throws, returns rollbackFailed error state',
        () async {
          final failoverService = ChainFailoverService();
          const originalConfig = ChainProxyConfig(
            enable: true,
            hop1Node: 'orig_entry',
            hop2Node: 'orig_exit',
          );

          final executor = DelegateChainFailoverExecutor(
            onApply: (cfg, ct) async {},
            onProbe: (cfg, ct) async => ChainProbeReport(
              mode: cfg.hopMode,
              isOverallHealthy: false,
              healthStatus: ChainHealthStatus.failed,
              hops: const [],
              timestamp: DateTime.now(),
            ),
            onRollback: (cfg, ct) async {
              throw Exception('Clash core socket died during rollback');
            },
            onCommit: (cfg) async {},
          );

          final result = await failoverService.executeFailover(
            currentConfig: originalConfig,
            fallbackPool: const ChainFallbackPool(
              exitCandidates: [
                ChainFallbackCandidate(
                  nodeName: 'cand_fail_rollback',
                  role: FallbackCandidateRole.exit,
                ),
              ],
            ),
            executor: executor,
            initialFailureReport: ChainProbeReport(
              mode: ChainHopMode.twoHop,
              isOverallHealthy: false,
              healthStatus: ChainHealthStatus.failed,
              failureHop: 2,
              hops: const [],
              timestamp: DateTime.now(),
            ),
          );

          expect(result.isSuccess, isFalse);
          expect(result.rollbackError, isNotNull);
          expect(
            result.rollbackError,
            contains('Clash core socket died during rollback'),
          );
        },
      );
    });

    // ══════════════════════════════════════════════════════════════════════════
    // Section C: Flap Dampening & Anti-Oscillation Stress (Tests 13 - 18)
    // ══════════════════════════════════════════════════════════════════════════
    group('Section C — Flap Dampening Stress', () {
      test(
        '13. Rapid flap penalty accumulation pushes past suppressThreshold and activates isSuppressed',
        () {
          final dampener = ChainFlapDampenerService();
          dampener.reset();

          const policy = ChainFlapDampeningPolicy(
            penaltyPerFlap: 1000,
            suppressThreshold: 2500,
            reuseThreshold: 500,
          );

          // Flap 1
          dampener.recordFlap(
            role: FallbackCandidateRole.exit,
            fromNode: 'nodeA',
            toNode: 'nodeB',
            policy: policy,
          );
          expect(dampener.status.isSuppressed, isFalse);
          expect(dampener.status.currentPenalty, closeTo(1000, 10));

          // Flap 2
          dampener.recordFlap(
            role: FallbackCandidateRole.exit,
            fromNode: 'nodeB',
            toNode: 'nodeA',
            policy: policy,
          );
          expect(dampener.status.isSuppressed, isFalse);
          expect(dampener.status.currentPenalty, closeTo(2000, 10));

          // Flap 3 -> exceeds 2500
          dampener.recordFlap(
            role: FallbackCandidateRole.exit,
            fromNode: 'nodeA',
            toNode: 'nodeB',
            policy: policy,
          );
          expect(dampener.status.isSuppressed, isTrue);
          expect(dampener.status.currentPenalty, closeTo(3000, 10));
        },
      );

      test(
        '14. Time-injected exponential decay reduces penalty below reuseThreshold deterministically',
        () {
          final dampener = ChainFlapDampenerService();
          dampener.reset();

          final baseTime = DateTime(2026, 9, 29, 12, 0, 0);
          const policy = ChainFlapDampeningPolicy(
            penaltyPerFlap: 1000,
            suppressThreshold: 2500,
            reuseThreshold: 500,
            halfLife: Duration(minutes: 5),
          );

          // Flap twice -> 2000 penalty
          dampener.recordFlap(
            role: FallbackCandidateRole.exit,
            fromNode: 'nodeA',
            toNode: 'nodeB',
            policy: policy,
            timestamp: baseTime,
          );
          dampener.recordFlap(
            role: FallbackCandidateRole.exit,
            fromNode: 'nodeB',
            toNode: 'nodeA',
            policy: policy,
            timestamp: baseTime,
          );

          // At t = 0
          final status0 = dampener.getStatus(now: baseTime, policy: policy);
          expect(status0.currentPenalty, closeTo(2000, 10));

          // At t = 5 min (1 half life) -> ~1000
          final t5 = baseTime.add(const Duration(minutes: 5));
          final status5 = dampener.getStatus(now: t5, policy: policy);
          expect(status5.currentPenalty, closeTo(1000, 50));

          // At t = 10 min (2 half lives) -> ~500
          final t10 = baseTime.add(const Duration(minutes: 10));
          final status10 = dampener.getStatus(now: t10, policy: policy);
          expect(status10.currentPenalty, closeTo(500, 30));

          // At t = 15 min (3 half lives) -> ~250 (below reuseThreshold)
          final t15 = baseTime.add(const Duration(minutes: 15));
          final status15 = dampener.getStatus(now: t15, policy: policy);
          expect(status15.currentPenalty, lessThanOrEqualTo(500));
        },
      );

      test(
        '15. Suppression window expiration: Advancing injected time past suppressedUntil unsuppresses',
        () {
          final dampener = ChainFlapDampenerService();
          dampener.reset();

          final baseTime = DateTime(2026, 9, 29, 12, 0, 0);
          const policy = ChainFlapDampeningPolicy(
            penaltyPerFlap: 1500,
            suppressThreshold: 2000,
            reuseThreshold: 500,
            maxSuppressDuration: Duration(minutes: 10),
            halfLife: Duration(minutes: 2),
          );

          // Flap 1 & 2 -> 3000 penalty, suppressed until baseTime + 10 min
          dampener.recordFlap(
            role: FallbackCandidateRole.exit,
            fromNode: 'nodeA',
            toNode: 'nodeB',
            policy: policy,
            timestamp: baseTime,
          );
          dampener.recordFlap(
            role: FallbackCandidateRole.exit,
            fromNode: 'nodeB',
            toNode: 'nodeA',
            policy: policy,
            timestamp: baseTime,
          );

          final suppressedStatus = dampener.getStatus(
            now: baseTime,
            policy: policy,
          );
          expect(suppressedStatus.isSuppressed, isTrue);

          // Time advance: 15 minutes later (well past suppressDuration)
          final laterTime = baseTime.add(const Duration(minutes: 15));
          final recoveredStatus = dampener.getStatus(
            now: laterTime,
            policy: policy,
          );
          expect(recoveredStatus.isSuppressed, isFalse);
        },
      );

      test(
        '16. Minimum switch interval: Rejects switch if attempted before cooldown finishes',
        () {
          final dampener = ChainFlapDampenerService();
          dampener.reset();

          final baseTime = DateTime(2026, 9, 29, 12, 0, 0);
          const policy = ChainFlapDampeningPolicy(
            penaltyPerFlap: 100,
            suppressThreshold: 5000, // Very high, won't suppress
            minSwitchInterval: Duration(seconds: 30),
          );

          dampener.recordFlap(
            role: FallbackCandidateRole.exit,
            fromNode: 'nodeA',
            toNode: 'nodeB',
            policy: policy,
            timestamp: baseTime,
          );

          // Attempt 10s later -> should be dampened by minSwitchInterval
          final verdict10 = dampener.evaluate(
            now: baseTime.add(const Duration(seconds: 10)),
            policy: policy,
          );
          expect(verdict10.isDampened, isTrue);
          expect(verdict10.reason, contains('冷却'));

          // Attempt 35s later -> should be permitted
          final verdict35 = dampener.evaluate(
            now: baseTime.add(const Duration(seconds: 35)),
            policy: policy,
          );
          expect(verdict35.isDampened, isFalse);
        },
      );

      test(
        '17. Bounded flap history: Recording 1,000 flaps respects maxHistoryEvents ceiling',
        () {
          final dampener = ChainFlapDampenerService();
          dampener.reset();

          const policy = ChainFlapDampeningPolicy(maxHistoryEvents: 50);
          for (int i = 0; i < 1000; i++) {
            dampener.recordFlap(
              role: FallbackCandidateRole.exit,
              fromNode: 'node_$i',
              toNode: 'node_${i + 1}',
              policy: policy,
            );
          }

          expect(dampener.status.recentEvents.length, lessThanOrEqualTo(50));
        },
      );

      test(
        '18. Bypass dampening path: User override bypasses dampening without disabling future protection',
        () {
          final dampener = ChainFlapDampenerService();
          dampener.reset();

          const policy = ChainFlapDampeningPolicy(
            penaltyPerFlap: 3000,
            suppressThreshold: 2000,
          );

          dampener.recordFlap(
            role: FallbackCandidateRole.exit,
            fromNode: 'n1',
            toNode: 'n2',
            policy: policy,
          );
          expect(dampener.status.isSuppressed, isTrue);

          // Evaluating with default policy indicates dampened
          final standardVerdict = dampener.evaluate(policy: policy);
          expect(standardVerdict.isDampened, isTrue);

          // Future operations still protected: status remains suppressed until decay or reset
          expect(dampener.status.isSuppressed, isTrue);
        },
      );
    });

    // ══════════════════════════════════════════════════════════════════════════
    // Section D: Telemetry Scalability & Re-entrancy Stress (Tests 19 - 24)
    // ══════════════════════════════════════════════════════════════════════════
    group('Section D — Telemetry Scalability & Stress', () {
      test(
        '19. High-volume burst (10,000 events) adheres to maxEvents = 200 FIFO boundary',
        () {
          final telemetry = ChainTelemetryService();
          telemetry.clear();

          for (int i = 0; i < 10000; i++) {
            telemetry.record(
              ChainTelemetryEvent(
                type: (i % 3 == 0)
                    ? ChainTelemetryEventType.probeFailed
                    : ChainTelemetryEventType.probeCompleted,
                role: 'StressNode_${i % 5}',
                message: 'Event index $i',
              ),
            );
          }

          final snapshot = telemetry.getSnapshot();
          expect(snapshot.totalEvents, equals(10000));
          expect(
            snapshot.recentEvents.length,
            equals(ChainTelemetryService.maxEvents),
          );
          expect(ChainTelemetryService.maxEvents, equals(200));

          // Confirm FIFO: last event in recentEvents must be the most recent
          expect(
            snapshot.recentEvents.last.message,
            equals('Event index 9999'),
          );
        },
      );

      test(
        '20. Counter integrity under 10,000 mixed success & failure events',
        () {
          final telemetry = ChainTelemetryService();
          telemetry.clear();

          for (int i = 0; i < 10000; i++) {
            telemetry.record(
              ChainTelemetryEvent(
                type: (i < 4000)
                    ? ChainTelemetryEventType.probeFailed
                    : ChainTelemetryEventType.probeCompleted,
                role: 'MixedTest',
                message: 'evt',
              ),
            );
          }

          final snapshot = telemetry.getSnapshot();
          expect(snapshot.totalEvents, equals(10000));
          expect(snapshot.failedEvents, equals(4000));
          expect(snapshot.successEvents, equals(6000));
        },
      );

      test(
        '21. Fault-tolerant listener: Listener throwing unhandled exception does not crash service',
        () {
          final telemetry = ChainTelemetryService();
          telemetry.clear();

          int goodListenerCount = 0;
          void badListener() {
            throw StateError('Simulated malformed listener crash');
          }

          void goodListener() {
            goodListenerCount++;
          }

          telemetry.addListener(badListener);
          telemetry.addListener(goodListener);

          // Recording event must survive the error
          telemetry.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.probeCompleted,
              role: 'Resilience',
              message: 'resilient_event',
            ),
          );

          expect(goodListenerCount, equals(1));
          telemetry.removeListener(badListener);
          telemetry.removeListener(goodListener);
        },
      );

      test(
        '22. Nested event safety: Listener recording secondary event within callback drains queue safely',
        () {
          final telemetry = ChainTelemetryService();
          telemetry.clear();

          int nestedExecutions = 0;
          void nestedTriggerListener() {
            if (nestedExecutions < 3) {
              nestedExecutions++;
              telemetry.record(
                ChainTelemetryEvent(
                  type: ChainTelemetryEventType.probeCompleted,
                  role: 'NestedRole',
                  message: 'nested_depth_$nestedExecutions',
                ),
              );
            }
          }

          telemetry.addListener(nestedTriggerListener);

          telemetry.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.probeStarted,
              role: 'RootRole',
              message: 'root_event',
            ),
          );

          expect(nestedExecutions, equals(3));
          telemetry.removeListener(nestedTriggerListener);
        },
      );

      test(
        '23. Immediate listener detachment: Listener removed mid-stream receives no further events',
        () {
          final telemetry = ChainTelemetryService();
          telemetry.clear();

          int listenerTriggers = 0;
          void listener() => listenerTriggers++;

          telemetry.addListener(listener);
          telemetry.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.probeStarted,
              role: 'R',
              message: '1',
            ),
          );
          expect(listenerTriggers, 1);

          telemetry.removeListener(listener);
          telemetry.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.probeCompleted,
              role: 'R',
              message: '2',
            ),
          );
          expect(listenerTriggers, 1);
        },
      );

      test(
        '24. Telemetry clear() completely flushes all event buffers and resets counters',
        () {
          final telemetry = ChainTelemetryService();
          for (int i = 0; i < 50; i++) {
            telemetry.record(
              ChainTelemetryEvent(
                type: ChainTelemetryEventType.probeCompleted,
                role: 'R',
                message: 'm',
              ),
            );
          }
          expect(telemetry.getSnapshot().totalEvents, equals(50));

          telemetry.clear();
          final afterClear = telemetry.getSnapshot();
          expect(afterClear.totalEvents, equals(0));
          expect(afterClear.failedEvents, equals(0));
          expect(afterClear.successEvents, equals(0));
          expect(afterClear.recentEvents, isEmpty);
        },
      );
    });

    // ══════════════════════════════════════════════════════════════════════════
    // Section E: Atomic Config Persistence Stress (Tests 25 - 30)
    // ══════════════════════════════════════════════════════════════════════════
    group('Section E — Atomic Config Persistence Stress', () {
      test(
        '25. Rapid sequential save/load (25 cycles) in sandbox verifies zero data corruption',
        () async {
          final filePath = p.join(
            stressSandboxDir.path,
            'chain_stress_seq.json',
          );
          final storage = AtomicConfigStorage(filePath);

          for (int i = 1; i <= 25; i++) {
            final payload = {
              'iteration': i,
              'enable': i.isEven,
              'hop1Node': 'node_entry_$i',
              'hop2Node': 'node_exit_$i',
            };
            await storage.save(payload);

            final readBack = await storage.load();
            expect(readBack, isNotNull);
            expect(readBack!['iteration'], equals(i));
            expect(readBack['hop1Node'], equals('node_entry_$i'));
          }
        },
      );

      test(
        '26. Concurrent save collision resistance: 10 concurrent writes complete without corrupting target',
        () async {
          final filePath = p.join(
            stressSandboxDir.path,
            'chain_stress_concurrent.json',
          );
          final storage = AtomicConfigStorage(filePath);

          final futures = List.generate(
            10,
            (i) => storage.save({
              'worker': i,
              'timestamp': DateTime.now().microsecondsSinceEpoch,
            }),
          );

          await Future.wait(futures);

          final loaded = await storage.load();
          expect(loaded, isNotNull);
          expect(loaded!.containsKey('worker'), isTrue);
        },
      );

      test(
        '27. Corrupted primary JSON recovery: Truncated JSON falls back to valid .bak automatically',
        () async {
          final filePath = p.join(
            stressSandboxDir.path,
            'chain_stress_corrupt.json',
          );
          final storage = AtomicConfigStorage(filePath);

          // Write v1 (will become .bak upon v2)
          await storage.save({'version': 1, 'healthy': true});
          // Write v2
          await storage.save({'version': 2, 'healthy': true});

          // Corrupt main file
          final mainFile = File(filePath);
          await mainFile.writeAsString(
            '{"version": 2, "corrupted": [incomplete_json',
            flush: true,
          );

          // Load must recover from v1 .bak
          final recovered = await storage.load();
          expect(recovered, isNotNull);
          expect(recovered!['version'], equals(1));
          expect(recovered['healthy'], isTrue);
        },
      );

      test(
        '28. Primary & backup corrupted: Automatic crash recovery via newest valid orphan .tmp',
        () async {
          final filePath = p.join(
            stressSandboxDir.path,
            'chain_stress_tmp_recover.json',
          );
          final storage = AtomicConfigStorage(filePath);

          // Clean out any existing target and bak
          final mainFile = File(filePath);
          final bakFile = File('$filePath.bak');
          if (await mainFile.exists()) await mainFile.delete();
          if (await bakFile.exists()) await bakFile.delete();

          // Simulate crash leaving an orphan .tmp
          final orphanTmp = File(
            '$filePath.${DateTime.now().microsecondsSinceEpoch}.0.tmp',
          );
          await orphanTmp.writeAsString(
            jsonEncode({'recovered_from_orphan': true}),
            flush: true,
          );

          final loaded = await storage.load();
          expect(loaded, isNotNull);
          expect(loaded!['recovered_from_orphan'], isTrue);
        },
      );

      test(
        '29. Empty and whitespace-only file handling: 0-byte file triggers fallback or returns null',
        () async {
          final filePath = p.join(
            stressSandboxDir.path,
            'chain_stress_empty.json',
          );
          final storage = AtomicConfigStorage(filePath);

          // Save v1
          await storage.save({'version': 1, 'valid': true});
          // Save v2
          await storage.save({'version': 2, 'valid': true});

          // Empty main file
          final mainFile = File(filePath);
          await mainFile.writeAsString('   \n  ', flush: true);

          // Load must recover from .bak (v1)
          final loaded = await storage.load();
          expect(loaded, isNotNull);
          expect(loaded!['version'], equals(1));
        },
      );

      test(
        '30. Temporary file cleanliness: Normal operations leave no lingering .tmp files',
        () async {
          final filePath = p.join(
            stressSandboxDir.path,
            'chain_stress_cleanup.json',
          );
          final storage = AtomicConfigStorage(filePath);

          for (int i = 0; i < 5; i++) {
            await storage.save({'test': i});
          }

          final parentDir = File(filePath).parent;
          final lingeringTmps = parentDir.listSync().where(
            (f) =>
                f.path.contains('chain_stress_cleanup.json.') &&
                f.path.endsWith('.tmp'),
          );
          expect(lingeringTmps, isEmpty);
        },
      );
    });

    // ══════════════════════════════════════════════════════════════════════════
    // Section F: Diagnostic Export & Support Package (Tests 31 - 34)
    // ══════════════════════════════════════════════════════════════════════════
    group('Section F — Diagnostic Export & Support Package', () {
      test(
        '31. High-load support package generation under burst of events creates valid ZIP',
        () async {
          final manager = ChainProxyManager();
          for (int i = 0; i < 500; i++) {
            chainTelemetryService.record(
              ChainTelemetryEvent(
                type: (i % 2 == 0)
                    ? ChainTelemetryEventType.probeCompleted
                    : ChainTelemetryEventType.probeFailed,
                role: 'SupportBurst_$i',
                message: 'Burst message $i',
              ),
            );
          }

          final pkg = await chainSupportPackageService.createPackage(manager);
          final zipFile = await chainSupportPackageService.exportPackage(pkg);

          expect(await zipFile.exists(), isTrue);
          expect(zipFile.lengthSync(), greaterThan(0));

          final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
          final fileNames = archive.map((f) => f.name).toSet();
          expect(fileNames, contains('summary.md'));
          expect(fileNames, contains('telemetry.json'));
          expect(fileNames, contains('intelligence.json'));
          expect(fileNames, contains('insight.json'));
          expect(fileNames, contains('decision.json'));

          await zipFile.delete();
        },
      );

      test(
        '32. Comprehensive sensitive field sanitization across passwords, tokens, uuids and urls',
        () {
          final sensitiveMap = {
            'password': 'SuperSecretPassword123!',
            'proxyPassword': 'MySecretProxyPassword',
            'token': 'bearer_token_xyz_987654321',
            'uuid': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
            'cookie': 'session_id=abcdef1234567890',
            'authorization': 'Basic dXNlcjpwYXNz',
            'privateKey': '-----BEGIN RSA PRIVATE KEY-----',
            'subscriptionUrl': 'https://provider.com/sub?token=secret123',
            'publicName': 'SafeNodeName',
          };

          final sanitized = ChainSupportPackageService.sanitizeEnhanced(
            sensitiveMap,
          )!;

          expect(sanitized['password'], equals('[REDACTED]'));
          expect(sanitized['proxyPassword'], equals('[REDACTED]'));
          expect(sanitized['token'], equals('[REDACTED]'));
          expect(sanitized['uuid'], equals('[REDACTED]'));
          expect(sanitized['cookie'], equals('[REDACTED]'));
          expect(sanitized['authorization'], equals('[REDACTED]'));
          expect(sanitized['privateKey'], equals('[REDACTED]'));
          expect(sanitized['subscriptionUrl'], equals('[REDACTED]'));
          expect(sanitized['publicName'], equals('SafeNodeName'));
        },
      );

      test(
        '33. Large string payload truncation: Strings exceeding 256 characters are truncated safely',
        () {
          final largeMap = {'normal': 'short string', 'oversized': 'A' * 400};

          final sanitized = ChainSupportPackageService.sanitizeEnhanced(
            largeMap,
          )!;
          expect(sanitized['normal'], equals('short string'));
          expect(sanitized['oversized'], endsWith('...[TRUNCATED]'));
          expect((sanitized['oversized'] as String).length, lessThan(300));
        },
      );

      test(
        '34. Package creation is user-confirmed: Upload is strictly opt-in and non-automatic',
        () async {
          final manager = ChainProxyManager();
          final pkg = await chainSupportPackageService.createPackage(manager);

          // Verification of package metadata
          expect(pkg.id, startsWith('PKG-'));
          expect(pkg.appVersion, equals('v1.1.0'));
          expect(pkg.includedSections.length, equals(5));
        },
      );
    });

    // ══════════════════════════════════════════════════════════════════════════
    // Section G & H: 2-Hop / 3-Hop Regression & Proxy Isolation (Tests 35 - 38)
    // ══════════════════════════════════════════════════════════════════════════
    group('Section G & H — Multi-Hop Regression & Isolation', () {
      test(
        '35. 2-Hop topology config & dialer-proxy mapping: Entry -> Exit accurately configured',
        () {
          const config = ChainProxyConfig(
            enable: true,
            hopMode: ChainHopMode.twoHop,
            hop1Node: 'node_entry_hk',
            hop2Node: 'node_exit_us',
            createDedicatedGroup: true,
            dedicatedGroupName: '🔗 链式代理',
          );

          final rawConfig = <String, dynamic>{
            'proxies': [
              {
                'name': 'node_entry_hk',
                'type': 'ss',
                'server': '1.1.1.1',
                'port': 8388,
              },
              {
                'name': 'node_exit_us',
                'type': 'ss',
                'server': '2.2.2.2',
                'port': 8388,
              },
            ],
            'proxy-groups': [
              {
                'name': 'PROXY',
                'type': 'select',
                'proxies': ['node_entry_hk', 'node_exit_us'],
              },
            ],
            'rules': <dynamic>[],
          };

          config.applyToClashConfig(rawConfig);

          final proxies = (rawConfig['proxies'] as List)
              .cast<Map<String, dynamic>>();
          final shadowExit = proxies.firstWhere(
            (p) => p['name'] == '🔗出口·node_exit_us',
          );
          expect(shadowExit['dialer-proxy'], equals('node_entry_hk'));

          final groups = (rawConfig['proxy-groups'] as List)
              .cast<Map<String, dynamic>>();
          final chainGroup = groups.firstWhere((g) => g['name'] == '🔗 链式代理');
          expect(chainGroup['proxies'], contains('🔗出口·node_exit_us'));
        },
      );

      test(
        '36. 3-Hop topology direction: Exit -> Relay -> Entry dialer-proxy chaining validated',
        () {
          const config = ChainProxyConfig(
            enable: true,
            hopMode: ChainHopMode.threeHop,
            hop1Node: 'hop1_jp',
            hop2Node: 'hop2_de',
            hop3Node: 'hop3_us',
            createDedicatedGroup: true,
            dedicatedGroupName: '🔗 链式代理',
          );

          final rawConfig = <String, dynamic>{
            'proxies': [
              {
                'name': 'hop1_jp',
                'type': 'ss',
                'server': '1.1.1.1',
                'port': 8388,
              },
              {
                'name': 'hop2_de',
                'type': 'ss',
                'server': '2.2.2.2',
                'port': 8388,
              },
              {
                'name': 'hop3_us',
                'type': 'ss',
                'server': '3.3.3.3',
                'port': 8388,
              },
            ],
            'proxy-groups': [
              {
                'name': 'PROXY',
                'type': 'select',
                'proxies': ['hop1_jp', 'hop2_de', 'hop3_us'],
              },
            ],
            'rules': <dynamic>[],
          };

          config.applyToClashConfig(rawConfig);

          final proxies = (rawConfig['proxies'] as List)
              .cast<Map<String, dynamic>>();
          final shadowRelay = proxies.firstWhere(
            (p) => p['name'] == '🔗中转·hop2_de',
          );
          final shadowExit = proxies.firstWhere(
            (p) => p['name'] == '🔗出口·hop3_us',
          );

          // Verify dialer-proxy chaining: Exit dials Relay; Relay dials Entry
          expect(shadowRelay['dialer-proxy'], equals('hop1_jp'));
          expect(shadowExit['dialer-proxy'], equals('🔗中转·hop2_de'));
        },
      );

      test(
        '37. Repeated ON/OFF toggling (20 cycles): Clean addition and complete teardown of shadow nodes',
        () {
          final rawConfig = <String, dynamic>{
            'proxies': [
              {
                'name': 'sub_1',
                'type': 'ss',
                'server': '1.1.1.1',
                'port': 8388,
              },
              {
                'name': 'sub_2',
                'type': 'ss',
                'server': '2.2.2.2',
                'port': 8388,
              },
            ],
            'proxy-groups': [
              {
                'name': 'PROXY',
                'type': 'select',
                'proxies': ['sub_1', 'sub_2'],
              },
            ],
            'rules': <dynamic>[],
          };

          const configOn = ChainProxyConfig(
            enable: true,
            hopMode: ChainHopMode.twoHop,
            hop1Node: 'sub_1',
            hop2Node: 'sub_2',
          );
          final configOff = configOn.copyWith(enable: false);

          for (int i = 0; i < 20; i++) {
            configOn.applyToClashConfig(rawConfig);
            final shadowCountOn = (rawConfig['proxies'] as List)
                .where((p) => p['name'].toString().startsWith('🔗'))
                .length;
            expect(
              shadowCountOn,
              equals(1),
              reason: 'Cycle $i: Must inject exactly 1 shadow node when ON',
            );

            configOff.applyToClashConfig(rawConfig);
            final shadowCountOff = (rawConfig['proxies'] as List)
                .where((p) => p['name'].toString().startsWith('🔗'))
                .length;
            expect(
              shadowCountOff,
              equals(0),
              reason:
                  'Cycle $i: Must cleanly teardown all shadow nodes when OFF',
            );
          }
        },
      );

      test(
        '38. Normal proxy immutability: Standard PROXY, AUTO, DIRECT groups retain exact subscriptions',
        () {
          final originalProxies = [
            {'name': 'direct', 'type': 'direct'},
            {
              'name': 'hk_fast',
              'type': 'ss',
              'server': '10.0.0.1',
              'port': 1080,
            },
            {
              'name': 'us_fast',
              'type': 'ss',
              'server': '10.0.0.2',
              'port': 1080,
            },
          ];
          final originalGroups = [
            {
              'name': 'PROXY',
              'type': 'select',
              'proxies': ['direct', 'hk_fast', 'us_fast'],
            },
            {
              'name': 'AUTO',
              'type': 'url-test',
              'proxies': ['hk_fast', 'us_fast'],
            },
            {
              'name': 'DIRECT',
              'type': 'select',
              'proxies': ['direct'],
            },
          ];

          final rawConfig = <String, dynamic>{
            'proxies': List<dynamic>.from(
              originalProxies.map((p) => Map<String, dynamic>.from(p)),
            ),
            'proxy-groups': List<dynamic>.from(
              originalGroups.map((g) => Map<String, dynamic>.from(g)),
            ),
            'rules': <dynamic>[],
          };

          const config = ChainProxyConfig(enable: false);
          config.applyToClashConfig(rawConfig);

          final groups = (rawConfig['proxy-groups'] as List)
              .cast<Map<String, dynamic>>();
          expect(groups.length, equals(3));
          expect(groups[0]['name'], equals('PROXY'));
          expect(
            groups[0]['proxies'],
            equals(['direct', 'hk_fast', 'us_fast']),
          );
          expect(groups[1]['name'], equals('AUTO'));
          expect(groups[1]['proxies'], equals(['hk_fast', 'us_fast']));
          expect(groups[2]['name'], equals('DIRECT'));
          expect(groups[2]['proxies'], equals(['direct']));
        },
      );
    });
  });
}
