import 'package:fluxora/models/chain_failover.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/chain_failover_service.dart';
import 'package:fluxora/services/chain_fallback_service.dart';
import 'package:fluxora/services/chain_flap_dampener_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_retry_service.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';

class MockChainProbeService implements IChainProbeService {
  final Future<ChainProbeReport> Function(ChainProxyConfig config, int attempt)
  onProbe;
  int _attemptCount = 0;

  MockChainProbeService({required this.onProbe});

  @override
  Future<ChainProbeReport> probeChain({
    required ChainProxyConfig config,
    String? testUrl,
    bool checkExitPublicIp = true,
    CancelToken? cancelToken,
    Duration? timeout,
    void Function(HopProbeState updatedHop)? onHopUpdate,
    void Function(ChainProbeReport interimReport)? onProgress,
  }) async {
    _attemptCount++;
    chainTelemetryService.record(
      ChainTelemetryEvent(
        type: ChainTelemetryEventType.probeStarted,
        role: 'Entry',
        message: 'Probe $_attemptCount Started',
      ),
    );
    final report = await onProbe(config, _attemptCount);
    if (report.healthStatus == ChainHealthStatus.failed) {
      chainTelemetryService.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeFailed,
          role: 'Entry',
          message: 'Probe $_attemptCount Failed',
        ),
      );
    } else {
      chainTelemetryService.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          role: 'Entry',
          message: 'Probe $_attemptCount Completed',
        ),
      );
    }
    return report;
  }
}

class MockFailoverExecutor implements IChainFailoverExecutor {
  @override
  Future<void> applyCandidate(
    ChainProxyConfig candidateConfig,
    CancelToken? cancelToken,
  ) async {}

  @override
  Future<ChainProbeReport> probeCandidate(
    ChainProxyConfig candidateConfig,
    CancelToken? cancelToken,
  ) async {
    return ChainProbeReport(
      mode: candidateConfig.hopMode,
      isOverallHealthy: true,
      healthStatus: ChainHealthStatus.healthy,
      hops: const [],
      attemptCount: 1,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> rollbackToOriginal(
    ChainProxyConfig originalConfig,
    CancelToken? cancelToken,
  ) async {}

  @override
  Future<void> commitSuccess(ChainProxyConfig finalConfig) async {}
}

void main() {
  setUp(() {
    chainTelemetryService.clear();
  });

  test(
    'Telemetry integration test for Probe, Retry, Fallback, Failover',
    () async {
      final mockProbe = MockChainProbeService(
        onProbe: (config, attempt) async {
          return ChainProbeReport(
            mode: config.hopMode,
            isOverallHealthy: false,
            healthStatus: ChainHealthStatus.failed,
            failureHop: 1,
            errorCode: ChainProbeErrorCodes.hop1Failed,
            hops: const [],
            attemptCount: attempt,
            timestamp: DateTime.now(),
          );
        },
      );

      final retryService = ChainRetryService(
        probeService: mockProbe,
        delayOverride: (delay, cancelToken) async {},
      );

      final failoverService = ChainFailoverService(
        retryService: retryService,
        fallbackService: const ChainFallbackService(),
        flapDampenerService: ChainFlapDampenerService(),
      );

      final pool = ChainFallbackPool(
        entryCandidates: [
          ChainFallbackCandidate(
            role: FallbackCandidateRole.entry,
            nodeName: 'MockEntry1',
            enabled: true,
            health: ChainHealthStatus.healthy,
          ),
        ],
        relayCandidates: [],
        exitCandidates: [],
      );

      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        defaultDialerProxy: 'OriginalEntry',
        hop2Node: 'OriginalExit',
      );

      await failoverService.executeFailover(
        currentConfig: config,
        fallbackPool: pool,
        policy: const ChainFailoverPolicy(
          retryPolicy: ChainRetryPolicy(maxAttempts: 2),
        ),
        executor: MockFailoverExecutor(),
      );

      final snapshot = chainTelemetryService.getSnapshot();
      final events = snapshot.recentEvents;
      final types = events.map((e) => e.type).toSet();

      expect(types.contains(ChainTelemetryEventType.probeStarted), isTrue);
      expect(types.contains(ChainTelemetryEventType.probeFailed), isTrue);
      expect(types.contains(ChainTelemetryEventType.retryBackoff), isTrue);
      expect(types.contains(ChainTelemetryEventType.retryStarted), isTrue);
      expect(types.contains(ChainTelemetryEventType.retryFailed), isTrue);
      expect(types.contains(ChainTelemetryEventType.failoverStarted), isTrue);
      expect(
        types.contains(ChainTelemetryEventType.fallbackEvaluationStarted),
        isTrue,
      );
      expect(
        types.contains(ChainTelemetryEventType.fallbackCandidateSelected),
        isTrue,
      );
      expect(
        types.contains(ChainTelemetryEventType.failoverCandidateApplied),
        isTrue,
      );
      expect(types.contains(ChainTelemetryEventType.failoverSuccess), isTrue);
    },
  );
}
