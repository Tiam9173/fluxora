import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/models/chain_failover.dart';
import 'package:fluxora/models/chain_flap_dampening.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_failover_service.dart';
import 'package:fluxora/services/chain_fallback_service.dart';
import 'package:fluxora/services/chain_flap_dampener_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_retry_service.dart';

void main() {
  group('Chain Proxy 2.0 Phase 3.2-D — Flap Dampening 抖动抑制核心算法测试', () {
    late ChainFlapDampenerService dampener;

    setUp(() {
      dampener = ChainFlapDampenerService();
    });

    test('1. initial state: 初始状态无惩罚、无抑制、事件历史为空', () {
      final status = dampener.status;
      expect(status.isSuppressed, isFalse);
      expect(status.currentPenalty, equals(0.0));
      expect(status.flapCountInWindow, equals(0));
      expect(status.lastFlapTime, isNull);
      expect(status.suppressedUntil, isNull);
      expect(status.recentEvents, isEmpty);

      final verdict = dampener.evaluate();
      expect(verdict.canProceed, isTrue);
      expect(verdict.isDampened, isFalse);
      expect(verdict.penalty, equals(0.0));
    });

    test('2. single flap and min switch interval: 单次切流记录惩罚并在冷却期内阻断', () {
      final t0 = DateTime(2026, 9, 29, 10, 0, 0);
      const policy = ChainFlapDampeningPolicy(
        minSwitchInterval: Duration(seconds: 15),
        penaltyPerFlap: 1000.0,
        suppressThreshold: 2000.0,
      );

      dampener.recordFlap(
        role: FallbackCandidateRole.exit,
        fromNode: 'HK_Node_01',
        toNode: 'JP_Node_02',
        reason: 'Connection timed out',
        timestamp: t0,
        policy: policy,
      );

      expect(dampener.status.recentEvents.length, equals(1));
      final event = dampener.status.recentEvents.first;
      expect(event.fromNode, equals('HK_Node_01'));
      expect(event.toNode, equals('JP_Node_02'));
      expect(event.role, equals(FallbackCandidateRole.exit));

      // 5秒后评估：处于 15秒最小切换间隔内，应被阻断冷却
      final t5 = t0.add(const Duration(seconds: 5));
      final v5 = dampener.evaluate(now: t5, policy: policy);
      expect(v5.isDampened, isTrue);
      expect(v5.canProceed, isFalse);
      expect(v5.reason, contains('切流冷却中'));
      expect(v5.remainingCooldown?.inSeconds, equals(10));

      // 16秒后评估：超过最小冷却间隔，且未达到抑制阈值，允许切换
      final t16 = t0.add(const Duration(seconds: 16));
      final v16 = dampener.evaluate(now: t16, policy: policy);
      expect(v16.isDampened, isFalse);
      expect(v16.canProceed, isTrue);
    });

    test('3. exponential decay: 积分按半衰期指数自然衰减', () {
      final t0 = DateTime(2026, 9, 29, 10, 0, 0);
      const policy = ChainFlapDampeningPolicy(
        halfLife: Duration(seconds: 40),
        penaltyPerFlap: 1000.0,
      );

      dampener.recordFlap(
        role: FallbackCandidateRole.exit,
        fromNode: 'NodeA',
        toNode: 'NodeB',
        timestamp: t0,
        policy: policy,
      );

      // t0 时积分为 1000.0
      expect(
        dampener.evaluate(now: t0, policy: policy).penalty,
        equals(1000.0),
      );

      // 经过 1 个半衰期 (40s): 1000 * 0.5 = 500
      final t40 = t0.add(const Duration(seconds: 40));
      final v40 = dampener.evaluate(now: t40, policy: policy);
      expect(v40.penalty, closeTo(500.0, 1.0));

      // 经过 2 个半衰期 (80s): 1000 * 0.25 = 250
      final t80 = t0.add(const Duration(seconds: 80));
      final v80 = dampener.evaluate(now: t80, policy: policy);
      expect(v80.penalty, closeTo(250.0, 1.0));

      // 经过 10 个半衰期 (400s): 接近 0
      final t400 = t0.add(const Duration(seconds: 400));
      final v400 = dampener.evaluate(now: t400, policy: policy);
      expect(v400.penalty, closeTo(0.0, 1.0));
    });

    test('4. suppress threshold: 累加积分超过 suppressThreshold 时进入抑制状态', () {
      final t0 = DateTime(2026, 9, 29, 10, 0, 0);
      const policy = ChainFlapDampeningPolicy(
        suppressThreshold: 2000.0,
        reuseThreshold: 800.0,
        penaltyPerFlap: 1000.0,
        minSwitchInterval: Duration(seconds: 5),
        halfLife: Duration(seconds: 60),
      );

      // 第 1 次切换：分值 1000 (未超 2000)
      dampener.recordFlap(
        role: FallbackCandidateRole.exit,
        fromNode: 'N1',
        toNode: 'N2',
        timestamp: t0,
        policy: policy,
      );
      expect(dampener.getStatus(now: t0, policy: policy).isSuppressed, isFalse);

      // 第 2 次切换 (10秒后)：衰减后为 ~890，累加 1000 -> ~1890 (未超 2000)
      final t10 = t0.add(const Duration(seconds: 10));
      dampener.recordFlap(
        role: FallbackCandidateRole.exit,
        fromNode: 'N2',
        toNode: 'N3',
        timestamp: t10,
        policy: policy,
      );
      expect(
        dampener.getStatus(now: t10, policy: policy).isSuppressed,
        isFalse,
      );

      // 第 3 次切换 (20秒后)：累加后超过 2000 -> 触发抑制状态
      final t20 = t0.add(const Duration(seconds: 20));
      dampener.recordFlap(
        role: FallbackCandidateRole.exit,
        fromNode: 'N3',
        toNode: 'N4',
        timestamp: t20,
        policy: policy,
      );

      expect(dampener.getStatus(now: t20, policy: policy).isSuppressed, isTrue);
      expect(
        dampener.getStatus(now: t20, policy: policy).suppressedUntil,
        isNotNull,
      );

      // 此时 evaluate 应返回 isDampened: true
      final verdict = dampener.evaluate(now: t20, policy: policy);
      expect(verdict.isDampened, isTrue);
      expect(verdict.canProceed, isFalse);
      expect(verdict.reason, contains('抖动惩罚分超出阈值'));
    });

    test('5. sliding window limit: 窗口内切换频次达到上限触发抑制', () {
      final t0 = DateTime(2026, 9, 29, 10, 0, 0);
      // 故意设置很高的 suppressThreshold，只通过滑动窗口频次触发
      const policy = ChainFlapDampeningPolicy(
        windowDuration: Duration(seconds: 60),
        maxFlapsInWindow: 3,
        suppressThreshold: 99999.0,
        penaltyPerFlap: 100.0,
        minSwitchInterval: Duration(seconds: 2),
      );

      dampener.recordFlap(
        role: FallbackCandidateRole.entry,
        fromNode: 'E1',
        toNode: 'E2',
        timestamp: t0,
        policy: policy,
      );
      dampener.recordFlap(
        role: FallbackCandidateRole.entry,
        fromNode: 'E2',
        toNode: 'E3',
        timestamp: t0.add(const Duration(seconds: 5)),
        policy: policy,
      );
      expect(
        dampener
            .getStatus(now: t0.add(const Duration(seconds: 5)), policy: policy)
            .isSuppressed,
        isFalse,
      );

      // 第 3 次切换 (在 60s 内)：达到 maxFlapsInWindow (3次)
      final t15 = t0.add(const Duration(seconds: 15));
      dampener.recordFlap(
        role: FallbackCandidateRole.entry,
        fromNode: 'E3',
        toNode: 'E4',
        timestamp: t15,
        policy: policy,
      );

      final status15 = dampener.getStatus(now: t15, policy: policy);
      expect(status15.isSuppressed, isTrue);
      expect(status15.reason, contains('滑动窗口内切换过频'));
    });

    test('6. automatic unsuppress: 积分衰减至 reuseThreshold 以下时自动解除抑制', () {
      final t0 = DateTime(2026, 9, 29, 10, 0, 0);
      const policy = ChainFlapDampeningPolicy(
        suppressThreshold: 1500.0,
        reuseThreshold: 500.0,
        halfLife: Duration(seconds: 30),
        penaltyPerFlap: 1600.0,
        minSwitchInterval: Duration(seconds: 5),
      );

      dampener.recordFlap(
        role: FallbackCandidateRole.exit,
        fromNode: 'X1',
        toNode: 'X2',
        timestamp: t0,
        policy: policy,
      );
      expect(dampener.getStatus(now: t0, policy: policy).isSuppressed, isTrue);

      // 经过 60秒 (2个半衰期): 1600 / 4 = 400 <= reuseThreshold (500)
      final t65 = t0.add(const Duration(seconds: 65));
      final verdict = dampener.evaluate(now: t65, policy: policy);

      expect(verdict.isDampened, isFalse);
      expect(verdict.canProceed, isTrue);
      expect(
        dampener.getStatus(now: t65, policy: policy).isSuppressed,
        isFalse,
      );
    });

    test('7. max suppress duration cap: 抑制时长不超过 maxSuppressDuration 上限', () {
      final t0 = DateTime(2026, 9, 29, 10, 0, 0);
      const policy = ChainFlapDampeningPolicy(
        suppressThreshold: 1000.0,
        reuseThreshold: 100.0,
        halfLife: Duration(seconds: 300), // 超大半衰期
        penaltyPerFlap: 10000.0, // 超大惩罚分
        maxSuppressDuration: Duration(minutes: 5),
      );

      dampener.recordFlap(
        role: FallbackCandidateRole.exit,
        fromNode: 'X1',
        toNode: 'X2',
        timestamp: t0,
        policy: policy,
      );

      expect(dampener.getStatus(now: t0, policy: policy).isSuppressed, isTrue);
      final suppressedUntil = dampener
          .getStatus(now: t0, policy: policy)
          .suppressedUntil!;
      final maxExpectedUntil = t0.add(const Duration(minutes: 5));

      // 截止时间不得超出 t0 + 5分钟
      expect(suppressedUntil.isAfter(maxExpectedUntil), isFalse);

      // 超过 5 分钟后评估自动解禁
      final t305 = t0.add(const Duration(seconds: 305));
      final verdict = dampener.evaluate(now: t305, policy: policy);
      expect(verdict.canProceed, isTrue);
      expect(
        dampener.getStatus(now: t305, policy: policy).isSuppressed,
        isFalse,
      );
    });

    test('8. history bounded: 严格限制事件历史数量，防止内存泄漏', () {
      final t0 = DateTime(2026, 9, 29, 10, 0, 0);
      const policy = ChainFlapDampeningPolicy(maxHistoryEvents: 5);

      for (int i = 0; i < 12; i++) {
        dampener.recordFlap(
          role: FallbackCandidateRole.exit,
          fromNode: 'Node_$i',
          toNode: 'Node_${i + 1}',
          timestamp: t0.add(Duration(seconds: i)),
          policy: policy,
        );
      }

      expect(dampener.status.recentEvents.length, equals(5));
      // 最旧的历史已被剔除，保留最新的 5 条
      expect(dampener.status.recentEvents.first.fromNode, equals('Node_7'));
      expect(dampener.status.recentEvents.last.fromNode, equals('Node_11'));
    });

    test('9. manual reset: 手动一键重置清除所有积分与抑制状态', () {
      final t0 = DateTime(2026, 9, 29, 10, 0, 0);
      const policy = ChainFlapDampeningPolicy(
        suppressThreshold: 500.0,
        penaltyPerFlap: 1000.0,
      );

      dampener.recordFlap(
        role: FallbackCandidateRole.exit,
        fromNode: 'A',
        toNode: 'B',
        timestamp: t0,
        policy: policy,
      );
      expect(dampener.getStatus(now: t0, policy: policy).isSuppressed, isTrue);

      dampener.reset();

      final status = dampener.status;
      expect(status.isSuppressed, isFalse);
      expect(status.currentPenalty, equals(0.0));
      expect(status.recentEvents, isEmpty);
      expect(status.suppressedUntil, isNull);

      final verdict = dampener.evaluate(now: t0, policy: policy);
      expect(verdict.canProceed, isTrue);
      expect(verdict.isDampened, isFalse);
    });

    test('10. disabled policy: 策略禁用时不产生任何抑制', () {
      final t0 = DateTime(2026, 9, 29, 10, 0, 0);
      const policy = ChainFlapDampeningPolicy(enabled: false);

      dampener.recordFlap(
        role: FallbackCandidateRole.exit,
        fromNode: 'A',
        toNode: 'B',
        timestamp: t0,
        policy: policy,
      );

      expect(dampener.getStatus(now: t0, policy: policy).isSuppressed, isFalse);
      final verdict = dampener.evaluate(now: t0, policy: policy);
      expect(verdict.canProceed, isTrue);
      expect(verdict.penalty, equals(0.0));
    });
  });

  group('Chain Proxy 2.0 Phase 3.2-D — Failover 与 Flap Dampener 联动集成测试', () {
    late MockRetryService retryService;
    late MockFallbackService fallbackService;
    late ChainFlapDampenerService dampener;
    late ChainFailoverService failoverService;

    final baseConfig = const ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.twoHop,
      hop1Node: 'Entry_Node',
      defaultDialerProxy: 'Entry_Node',
      hop2Node: 'Exit_Node_Original',
    );

    final basePool = ChainFallbackPool(
      exitCandidates: [
        const ChainFallbackCandidate(
          nodeName: 'Exit_Backup_1',
          role: FallbackCandidateRole.exit,
          priority: 10,
        ),
      ],
    );

    setUp(() {
      retryService = MockRetryService();
      fallbackService = MockFallbackService();
      dampener = ChainFlapDampenerService();
      failoverService = ChainFailoverService(
        retryService: retryService,
        fallbackService: fallbackService,
        flapDampenerService: dampener,
      );
    });

    test(
      '11. dampened blocks failover: 处于抖动抑制时 executeFailover 立即返回 dampened 状态',
      () async {
        // 人工触发抑制
        dampener.recordFlap(
          role: FallbackCandidateRole.exit,
          fromNode: 'Prev1',
          toNode: 'Prev2',
          policy: const ChainFlapDampeningPolicy(
            suppressThreshold: 500.0,
            penaltyPerFlap: 1000.0,
          ),
        );
        expect(dampener.status.isSuppressed, isTrue);

        final failedReport = ChainProbeReport(
          mode: ChainHopMode.twoHop,
          isOverallHealthy: false,
          healthStatus: ChainHealthStatus.failed,
          failureHop: 2,
          errorCode: ChainProbeErrorCodes.exitTimeout,
          rootCauseAnalysis: 'Exit node unreachable',
          hops: const [],
          timestamp: DateTime.now(),
        );

        final progressList = <ChainFailoverProgress>[];

        final result = await failoverService.executeFailover(
          currentConfig: baseConfig,
          fallbackPool: basePool,
          initialFailureReport: failedReport,
          onProgress: (p) => progressList.add(p),
        );

        expect(result.isSuccess, isFalse);
        expect(result.state, equals(ChainFailoverState.dampened));
        expect(result.isDampened, isTrue);
        expect(result.rootCause, contains('抖动惩罚分超出阈值'));
        expect(
          progressList.any((p) => p.state == ChainFailoverState.dampened),
          isTrue,
        );
      },
    );

    test('12. bypass dampening: 显式开启 bypassDampening 时绕过抑制阻断', () async {
      // 人工触发抑制
      dampener.recordFlap(
        role: FallbackCandidateRole.exit,
        fromNode: 'Prev1',
        toNode: 'Prev2',
        policy: const ChainFlapDampeningPolicy(
          suppressThreshold: 500.0,
          penaltyPerFlap: 1000.0,
        ),
      );
      expect(dampener.status.isSuppressed, isTrue);

      final failedReport = ChainProbeReport(
        mode: ChainHopMode.twoHop,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.failed,
        failureHop: 2,
        errorCode: ChainProbeErrorCodes.exitTimeout,
        rootCauseAnalysis: 'Exit node unreachable',
        hops: const [],
        timestamp: DateTime.now(),
      );

      fallbackService.mockCandidates = [
        const ChainFallbackCandidate(
          nodeName: 'Exit_Backup_1',
          role: FallbackCandidateRole.exit,
        ),
      ];

      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, ct) async {},
        onProbe: (cfg, ct) async => ChainProbeReport(
          mode: ChainHopMode.twoHop,
          isOverallHealthy: true,
          healthStatus: ChainHealthStatus.healthy,
          hops: const [],
          timestamp: DateTime.now(),
        ),
        onRollback: (cfg, ct) async {},
        onCommit: (cfg) async {},
      );

      final result = await failoverService.executeFailover(
        currentConfig: baseConfig,
        fallbackPool: basePool,
        initialFailureReport: failedReport,
        executor: executor,
        policy: const ChainFailoverPolicy(bypassDampening: true),
      );

      // bypass 成功执行了切换
      expect(result.isSuccess, isTrue);
      expect(result.state, equals(ChainFailoverState.failoverSuccess));
      expect(result.switchedNodeName, equals('Exit_Backup_1'));
    });

    test('13. record flap on commit: 故障转移成功提交后自动向 dampener 记入切流事件', () async {
      final failedReport = ChainProbeReport(
        mode: ChainHopMode.twoHop,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.failed,
        failureHop: 2,
        errorCode: ChainProbeErrorCodes.exitTimeout,
        rootCauseAnalysis: 'Exit node unreachable',
        hops: const [],
        timestamp: DateTime.now(),
      );

      fallbackService.mockCandidates = [
        const ChainFallbackCandidate(
          nodeName: 'Exit_Backup_1',
          role: FallbackCandidateRole.exit,
        ),
      ];

      final executor = DelegateChainFailoverExecutor(
        onApply: (cfg, ct) async {},
        onProbe: (cfg, ct) async => ChainProbeReport(
          mode: ChainHopMode.twoHop,
          isOverallHealthy: true,
          healthStatus: ChainHealthStatus.healthy,
          hops: const [],
          timestamp: DateTime.now(),
        ),
        onRollback: (cfg, ct) async {},
        onCommit: (cfg) async {},
      );

      expect(dampener.status.recentEvents, isEmpty);

      final result = await failoverService.executeFailover(
        currentConfig: baseConfig,
        fallbackPool: basePool,
        initialFailureReport: failedReport,
        executor: executor,
      );

      expect(result.isSuccess, isTrue);
      // 验证切流事件已写入 dampener
      expect(dampener.status.recentEvents.length, equals(1));
      final recorded = dampener.status.recentEvents.first;
      expect(recorded.fromNode, equals('Exit_Node_Original'));
      expect(recorded.toNode, equals('Exit_Backup_1'));
      expect(recorded.role, equals(FallbackCandidateRole.exit));
      expect(recorded.isSuccess, isTrue);
    });
  });
}

class MockRetryService implements IChainRetryService {
  @override
  Future<ChainProbeReport> probeWithRetry({
    required ChainProxyConfig config,
    ChainRetryPolicy policy = const ChainRetryPolicy(),
    String? testUrl,
    bool checkExitPublicIp = true,
    CancelToken? cancelToken,
    Duration? timeout,
    void Function(HopProbeState updatedHop)? onHopUpdate,
    void Function(ChainProbeReport interimReport)? onProgress,
    void Function(ChainRetryProgress retryProgress)? onRetryProgress,
  }) async {
    return ChainProbeReport(
      mode: config.hopMode,
      isOverallHealthy: true,
      healthStatus: ChainHealthStatus.healthy,
      hops: const [],
      timestamp: DateTime.now(),
    );
  }
}

class MockFallbackService implements IChainFallbackService {
  List<ChainFallbackCandidate> mockCandidates = [];

  @override
  CandidateSelectionResult selectCandidates({
    required ChainProxyConfig currentConfig,
    required FallbackCandidateRole role,
    required ChainFallbackPool pool,
    ChainFallbackPolicy policy = const ChainFallbackPolicy(),
    List<String>? availableProxyNames,
    Map<String, ProtocolCapabilityProfile>? availableProxyProfiles,
  }) {
    return CandidateSelectionResult(
      role: role,
      rankedCandidates: mockCandidates,
      explanation: 'mock selection',
    );
  }

  @override
  FallbackSession createSession({
    required ChainProxyConfig currentConfig,
    required FallbackCandidateRole role,
    required ChainFallbackPool pool,
    ChainFallbackPolicy policy = const ChainFallbackPolicy(),
    List<String>? availableProxyNames,
    Map<String, ProtocolCapabilityProfile>? availableProxyProfiles,
  }) {
    throw UnimplementedError();
  }
}
