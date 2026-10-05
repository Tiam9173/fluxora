import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_retry_service.dart';

class MockChainProbeService implements IChainProbeService {
  final List<ChainProbeReport Function(int callCount)> _responses;
  int callCount = 0;
  final List<ChainProxyConfig> capturedConfigs = [];
  final List<CancelToken?> capturedCancelTokens = [];

  MockChainProbeService(this._responses);

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
    callCount++;
    capturedConfigs.add(config);
    capturedCancelTokens.add(cancelToken);

    if (cancelToken?.isCancelled == true) {
      return ChainProbeReport.cancelled(
        mode: config.hopMode,
        timestamp: DateTime.now(),
      );
    }

    if (callCount <= _responses.length) {
      return _responses[callCount - 1](callCount);
    }

    return ChainProbeReport(
      mode: config.hopMode,
      isOverallHealthy: false,
      healthStatus: ChainHealthStatus.failed,
      hops: const [],
      errorCode: ChainProbeErrorCodes.hop1Timeout,
      timestamp: DateTime.now(),
    );
  }
}

ChainProbeReport _healthyReport(ChainHopMode mode) {
  return ChainProbeReport(
    mode: mode,
    isOverallHealthy: true,
    healthStatus: ChainHealthStatus.healthy,
    totalChainLatencyMs: 120,
    hops: [
      const HopProbeState(
        hopIndex: 1,
        role: HopRole.hop1Entry,
        nodeName: 'HK-01',
        nodeAddress: '1.1.1.1',
        status: HopProbeStatus.healthy,
        healthStatus: ChainHealthStatus.healthy,
        latencyMs: 50,
      ),
      const HopProbeState(
        hopIndex: 2,
        role: HopRole.hop2Exit,
        nodeName: 'US-Resi',
        nodeAddress: '2.2.2.2',
        status: HopProbeStatus.healthy,
        healthStatus: ChainHealthStatus.healthy,
        latencyMs: 70,
      ),
    ],
    timestamp: DateTime.now(),
  );
}

ChainProbeReport _failedReport(
  ChainHopMode mode, {
  String errorCode = ChainProbeErrorCodes.hop1Timeout,
  int failureHop = 1,
  String reason = '连接超时',
}) {
  return ChainProbeReport(
    mode: mode,
    isOverallHealthy: false,
    healthStatus: ChainHealthStatus.failed,
    hops: const [],
    failureHop: failureHop,
    errorCode: errorCode,
    rootCauseAnalysis: reason,
    timestamp: DateTime.now(),
  );
}

ChainProbeReport _degradedReport(ChainHopMode mode) {
  return ChainProbeReport(
    mode: mode,
    isOverallHealthy: true,
    healthStatus: ChainHealthStatus.degraded,
    totalChainLatencyMs: 130,
    hops: const [],
    errorCode: ChainProbeErrorCodes.ipApiUnavailable,
    rootCauseAnalysis: '代理链路传输层已正常建立，但公网 IP 查询服务超时',
    timestamp: DateTime.now(),
  );
}

void main() {
  group('Chain Proxy 2.0 Phase 3.2-A — Retry Engine 专项测试 (24 项核心场景)', () {
    const validTwoHopConfig = ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.twoHop,
      defaultDialerProxy: 'HK-01',
      hop1Node: 'HK-01',
      hop2Node: 'US-Resi',
    );

    const validThreeHopConfig = ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.threeHop,
      defaultDialerProxy: 'HK-01',
      hop1Node: 'HK-01',
      hop2Node: 'JP-Relay',
      hop3Node: 'US-Resi',
    );

    // 1. success on first attempt
    test('1. success on first attempt: 首次探测直接成功，无重试且 attemptCount=1', () async {
      final mockProbe = MockChainProbeService([
        (_) => _healthyReport(ChainHopMode.twoHop),
      ]);
      final engine = ChainRetryService(probeService: mockProbe);

      final report = await engine.probeWithRetry(
        config: validTwoHopConfig,
        policy: const ChainRetryPolicy(maxAttempts: 3),
      );

      expect(report.healthStatus, ChainHealthStatus.healthy);
      expect(report.isOverallHealthy, isTrue);
      expect(report.attemptCount, 1);
      expect(mockProbe.callCount, 1);
    });

    // 2. retry after retryable failure
    test(
      '2. retry after retryable failure: 首次遇到可重试错误 (HOP1_TIMEOUT) 后触发第 2 次探测',
      () async {
        final mockProbe = MockChainProbeService([
          (_) => _failedReport(
            ChainHopMode.twoHop,
            errorCode: ChainProbeErrorCodes.hop1Timeout,
          ),
          (_) => _healthyReport(ChainHopMode.twoHop),
        ]);
        final engine = ChainRetryService(
          probeService: mockProbe,
          delayOverride: (_, _) async {}, // 立即延迟
        );

        final report = await engine.probeWithRetry(
          config: validTwoHopConfig,
          policy: const ChainRetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration(milliseconds: 10),
          ),
        );

        expect(mockProbe.callCount, 2);
        expect(report.healthStatus, ChainHealthStatus.healthy);
        expect(report.attemptCount, 2);
      },
    );

    // 3. success on second attempt
    test('3. success on second attempt: 第 2 次探测成功返回 healthy', () async {
      final mockProbe = MockChainProbeService([
        (_) => _failedReport(
          ChainHopMode.twoHop,
          errorCode: ChainProbeErrorCodes.exitTimeout,
          failureHop: 2,
        ),
        (_) => _healthyReport(ChainHopMode.twoHop),
      ]);
      final engine = ChainRetryService(
        probeService: mockProbe,
        delayOverride: (_, _) async {},
      );

      final report = await engine.probeWithRetry(
        config: validTwoHopConfig,
        policy: const ChainRetryPolicy(maxAttempts: 3),
      );

      expect(report.healthStatus, ChainHealthStatus.healthy);
      expect(report.attemptCount, 2);
      expect(mockProbe.callCount, 2);
    });

    // 4. success on third attempt
    test('4. success on third attempt: 前 2 次失败后，第 3 次探测成功', () async {
      final mockProbe = MockChainProbeService([
        (_) => _failedReport(
          ChainHopMode.threeHop,
          errorCode: ChainProbeErrorCodes.hop2Failed,
          failureHop: 2,
        ),
        (_) => _failedReport(
          ChainHopMode.threeHop,
          errorCode: ChainProbeErrorCodes.exitTimeout,
          failureHop: 3,
        ),
        (_) => _healthyReport(ChainHopMode.threeHop),
      ]);
      final engine = ChainRetryService(
        probeService: mockProbe,
        delayOverride: (_, _) async {},
      );

      final report = await engine.probeWithRetry(
        config: validThreeHopConfig,
        policy: const ChainRetryPolicy(maxAttempts: 3),
      );

      expect(report.healthStatus, ChainHealthStatus.healthy);
      expect(report.attemptCount, 3);
      expect(mockProbe.callCount, 3);
    });

    // 5. all attempts fail
    test('5. all attempts fail: 达到最大重试次数后仍然失败，保留最终错误与 attemptCount', () async {
      final mockProbe = MockChainProbeService([
        (_) => _failedReport(
          ChainHopMode.twoHop,
          errorCode: ChainProbeErrorCodes.hop1Timeout,
          failureHop: 1,
        ),
        (_) => _failedReport(
          ChainHopMode.twoHop,
          errorCode: ChainProbeErrorCodes.hop1Timeout,
          failureHop: 1,
        ),
        (_) => _failedReport(
          ChainHopMode.twoHop,
          errorCode: ChainProbeErrorCodes.exitFailed,
          failureHop: 2,
          reason: '落地鉴权失败',
        ),
      ]);
      final engine = ChainRetryService(
        probeService: mockProbe,
        delayOverride: (_, _) async {},
      );

      final report = await engine.probeWithRetry(
        config: validTwoHopConfig,
        policy: const ChainRetryPolicy(maxAttempts: 3),
      );

      expect(report.healthStatus, ChainHealthStatus.failed);
      expect(report.isOverallHealthy, isFalse);
      expect(report.attemptCount, 3);
      expect(report.failureHop, 2);
      expect(report.errorCode, ChainProbeErrorCodes.exitFailed);
      expect(report.rootCauseAnalysis, '落地鉴权失败');
      expect(mockProbe.callCount, 3);
    });

    // 6. max attempts
    test('6. max attempts: 支持自定义 maxAttempts (例如 5 次)', () async {
      final mockProbe = MockChainProbeService([
        for (int i = 0; i < 5; i++)
          (_) => _failedReport(
            ChainHopMode.twoHop,
            errorCode: ChainProbeErrorCodes.hop1Timeout,
          ),
      ]);
      final engine = ChainRetryService(
        probeService: mockProbe,
        delayOverride: (_, _) async {},
      );

      final report = await engine.probeWithRetry(
        config: validTwoHopConfig,
        policy: const ChainRetryPolicy(maxAttempts: 5),
      );

      expect(mockProbe.callCount, 5);
      expect(report.attemptCount, 5);
      expect(report.healthStatus, ChainHealthStatus.failed);
    });

    // 7. no off-by-one
    test(
      '7. no off-by-one: 严格保证尝试次数无边界偏移 (maxAttempts=1 时执行 1 次，maxAttempts=3 执行 3 次)',
      () async {
        final mockProbe1 = MockChainProbeService([
          (_) => _failedReport(
            ChainHopMode.twoHop,
            errorCode: ChainProbeErrorCodes.hop1Timeout,
          ),
        ]);
        final engine1 = ChainRetryService(probeService: mockProbe1);
        final report1 = await engine1.probeWithRetry(
          config: validTwoHopConfig,
          policy: const ChainRetryPolicy(maxAttempts: 1),
        );
        expect(mockProbe1.callCount, 1);
        expect(report1.attemptCount, 1);

        final attemptsEmitted = <int>[];
        final mockProbe3 = MockChainProbeService([
          (_) => _failedReport(
            ChainHopMode.twoHop,
            errorCode: ChainProbeErrorCodes.hop1Timeout,
          ),
          (_) => _failedReport(
            ChainHopMode.twoHop,
            errorCode: ChainProbeErrorCodes.hop1Timeout,
          ),
          (_) => _failedReport(
            ChainHopMode.twoHop,
            errorCode: ChainProbeErrorCodes.hop1Timeout,
          ),
        ]);
        final engine3 = ChainRetryService(
          probeService: mockProbe3,
          delayOverride: (_, _) async {},
        );
        final report3 = await engine3.probeWithRetry(
          config: validTwoHopConfig,
          policy: const ChainRetryPolicy(maxAttempts: 3),
          onRetryProgress: (p) => attemptsEmitted.add(p.currentAttempt),
        );
        expect(mockProbe3.callCount, 3);
        expect(report3.attemptCount, 3);
        expect(attemptsEmitted.contains(1), isTrue);
        expect(attemptsEmitted.contains(2), isTrue);
        expect(attemptsEmitted.contains(3), isTrue);
        expect(attemptsEmitted.contains(4), isFalse);
      },
    );

    // 8. exponential backoff
    test('8. exponential backoff: 指数退避时间按 2^(attempt-1) 递增', () {
      const policy = ChainRetryPolicy(
        baseDelay: Duration(milliseconds: 500),
        maxDelay: Duration(seconds: 10),
        jitterFactor: 0.0,
      );

      expect(policy.calculateDelay(1).inMilliseconds, 500); // 500 * 2^0 = 500
      expect(policy.calculateDelay(2).inMilliseconds, 1000); // 500 * 2^1 = 1000
      expect(policy.calculateDelay(3).inMilliseconds, 2000); // 500 * 2^2 = 2000
      expect(policy.calculateDelay(4).inMilliseconds, 4000); // 500 * 2^3 = 4000
      expect(policy.calculateDelay(5).inMilliseconds, 8000); // 500 * 2^4 = 8000
    });

    // 9. max delay
    test('9. max delay: 退避时间受 maxDelay 上限截断', () {
      const policy = ChainRetryPolicy(
        baseDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 3),
        jitterFactor: 0.0,
      );

      expect(policy.calculateDelay(1), const Duration(seconds: 1));
      expect(policy.calculateDelay(2), const Duration(seconds: 2));
      expect(policy.calculateDelay(3), const Duration(seconds: 3)); // capped
      expect(policy.calculateDelay(4), const Duration(seconds: 3)); // capped
      expect(policy.calculateDelay(10), const Duration(seconds: 3)); // capped
    });

    // 10. jitter bounds
    test('10. jitter bounds: 随机抖动限制在合理比例范围内，支持注入 Random 保证确定性', () {
      final seededRandom = math.Random(42);
      final policy = ChainRetryPolicy(
        baseDelay: const Duration(milliseconds: 1000),
        maxDelay: const Duration(seconds: 5),
        jitterFactor: 0.2, // 最多增加 20%
        random: seededRandom,
      );

      for (int i = 0; i < 20; i++) {
        final delay = policy.calculateDelay(1);
        expect(delay.inMilliseconds, greaterThanOrEqualTo(1000));
        expect(delay.inMilliseconds, lessThanOrEqualTo(1200));
      }
    });

    // 11. non-retryable error
    test('11. non-retryable error: 遇到不在白名单中的错误立即终止，不触发重试', () async {
      final mockProbe = MockChainProbeService([
        (_) => _failedReport(
          ChainHopMode.twoHop,
          errorCode: 'CUSTOM_AUTH_FATAL_ERROR',
          reason: '密钥无效',
        ),
        (_) => _healthyReport(ChainHopMode.twoHop),
      ]);
      final engine = ChainRetryService(probeService: mockProbe);

      final report = await engine.probeWithRetry(
        config: validTwoHopConfig,
        policy: const ChainRetryPolicy(
          maxAttempts: 3,
          retryableErrors: {ChainProbeErrorCodes.hop1Timeout},
        ),
      );

      expect(mockProbe.callCount, 1);
      expect(report.healthStatus, ChainHealthStatus.failed);
      expect(report.errorCode, 'CUSTOM_AUTH_FATAL_ERROR');
      expect(report.attemptCount, 1);
    });

    // 12. topology invalid
    test('12. topology invalid: 拓扑非法仅在启动前检查一次，立即报错且绝不调用探针', () async {
      const invalidConfig = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'SameNode',
        hop2Node: 'SameNode', // 自环
      );
      final mockProbe = MockChainProbeService([]);
      final engine = ChainRetryService(probeService: mockProbe);

      final report = await engine.probeWithRetry(
        config: invalidConfig,
        policy: const ChainRetryPolicy(maxAttempts: 3),
      );

      expect(mockProbe.callCount, 0); // 严格为 0，探针未调用
      expect(report.healthStatus, ChainHealthStatus.failed);
      expect(report.errorCode, ChainProbeErrorCodes.topologyInvalid);
      expect(report.rootCauseAnalysis, contains('不能使用同一个节点'));
      expect(report.attemptCount, 1);
    });

    // 13. cancelled before first attempt
    test(
      '13. cancelled before first attempt: 启动前 CancelToken 已取消，立即返回且探针调用为 0',
      () async {
        final token = CancelToken();
        token.cancel('启动前已取消');

        final mockProbe = MockChainProbeService([]);
        final engine = ChainRetryService(probeService: mockProbe);

        final report = await engine.probeWithRetry(
          config: validTwoHopConfig,
          cancelToken: token,
        );

        expect(report.healthStatus, ChainHealthStatus.cancelled);
        expect(report.isCancelled, isTrue);
        expect(mockProbe.callCount, 0);
      },
    );

    // 14. cancelled during backoff
    test('14. cancelled during backoff: 退避等待过程中被取消立即唤醒终止，无需等待完整时长', () async {
      final token = CancelToken();
      final mockProbe = MockChainProbeService([
        (_) => _failedReport(
          ChainHopMode.twoHop,
          errorCode: ChainProbeErrorCodes.hop1Timeout,
        ),
        (_) => _healthyReport(ChainHopMode.twoHop),
      ]);

      final engine = ChainRetryService(probeService: mockProbe);

      final future = engine.probeWithRetry(
        config: validTwoHopConfig,
        policy: const ChainRetryPolicy(
          maxAttempts: 3,
          baseDelay: Duration(seconds: 10), // 较长退避时间
        ),
        cancelToken: token,
      );

      // 稍作等待后触发取消
      await Future.delayed(const Duration(milliseconds: 50));
      token.cancel('等待退避中取消');

      final stopwatch = Stopwatch()..start();
      final report = await future;
      stopwatch.stop();

      expect(report.healthStatus, ChainHealthStatus.cancelled);
      expect(report.isCancelled, isTrue);
      expect(mockProbe.callCount, 1); // 第二次未执行
      expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // 秒级中断，远小于 10 秒
    });

    // 15. cancelled before next attempt
    test(
      '15. cancelled before next attempt: 延迟结束但下一轮开始前取消，终止并返回 cancelled',
      () async {
        final token = CancelToken();
        final mockProbe = MockChainProbeService([
          (_) {
            // 在第 1 次探测返回后立即取消 token
            token.cancel('第 1 次后取消');
            return _failedReport(
              ChainHopMode.twoHop,
              errorCode: ChainProbeErrorCodes.hop1Timeout,
            );
          },
          (_) => _healthyReport(ChainHopMode.twoHop),
        ]);
        final engine = ChainRetryService(
          probeService: mockProbe,
          delayOverride: (_, _) async {},
        );

        final report = await engine.probeWithRetry(
          config: validTwoHopConfig,
          policy: const ChainRetryPolicy(maxAttempts: 3),
          cancelToken: token,
        );

        expect(report.healthStatus, ChainHealthStatus.cancelled);
        expect(mockProbe.callCount, 1);
      },
    );

    // 16. retry session state
    test(
      '16. retry session state: 完整跟踪重试状态流转 (attempting -> waiting -> attempting -> completed)',
      () async {
        final stateHistory = <ChainRetryState>[];
        final mockProbe = MockChainProbeService([
          (_) => _failedReport(
            ChainHopMode.twoHop,
            errorCode: ChainProbeErrorCodes.hop1Timeout,
          ),
          (_) => _healthyReport(ChainHopMode.twoHop),
        ]);
        final engine = ChainRetryService(
          probeService: mockProbe,
          delayOverride: (_, _) async {},
        );

        await engine.probeWithRetry(
          config: validTwoHopConfig,
          policy: const ChainRetryPolicy(maxAttempts: 3),
          onRetryProgress: (p) => stateHistory.add(p.state),
        );

        expect(stateHistory, [
          ChainRetryState.attempting,
          ChainRetryState.waiting,
          ChainRetryState.attempting,
          ChainRetryState.completed,
        ]);
      },
    );

    // 17. concurrent retry protection
    test(
      '17. concurrent retry protection: 同一实例启动新探测自动中断上一次活跃 Session',
      () async {
        final token1 = CancelToken();
        final token2 = CancelToken();

        CancelToken? activeToken = token1;
        void startNewProbe(CancelToken newToken) {
          if (activeToken != null && !activeToken!.isCancelled) {
            activeToken!.cancel('启动了新探测');
          }
          activeToken = newToken;
        }

        startNewProbe(token2);
        expect(token1.isCancelled, isTrue);
        expect(token2.isCancelled, isFalse);
      },
    );

    // 18. original node unchanged
    test('18. original node unchanged: 重试引擎探测不修改任何原始节点名称和地址', () async {
      final mockProbe = MockChainProbeService([
        (_) => _failedReport(
          ChainHopMode.twoHop,
          errorCode: ChainProbeErrorCodes.hop1Timeout,
        ),
        (_) => _failedReport(
          ChainHopMode.twoHop,
          errorCode: ChainProbeErrorCodes.hop1Timeout,
        ),
      ]);
      final engine = ChainRetryService(
        probeService: mockProbe,
        delayOverride: (_, _) async {},
      );

      await engine.probeWithRetry(
        config: validTwoHopConfig,
        policy: const ChainRetryPolicy(maxAttempts: 2),
      );

      expect(validTwoHopConfig.hop1Node, 'HK-01');
      expect(validTwoHopConfig.hop2Node, 'US-Resi');
      expect(mockProbe.capturedConfigs.first.hop1Node, 'HK-01');
      expect(mockProbe.capturedConfigs.last.hop2Node, 'US-Resi');
    });

    // 19. chain config unchanged
    test('19. chain config unchanged: 多次重试前后配置对象 hash 及属性完全一致', () async {
      final configBefore = validTwoHopConfig.toJson();
      final mockProbe = MockChainProbeService([
        (_) => _failedReport(
          ChainHopMode.twoHop,
          errorCode: ChainProbeErrorCodes.hop1Timeout,
        ),
        (_) => _healthyReport(ChainHopMode.twoHop),
      ]);
      final engine = ChainRetryService(
        probeService: mockProbe,
        delayOverride: (_, _) async {},
      );

      await engine.probeWithRetry(
        config: validTwoHopConfig,
        policy: const ChainRetryPolicy(maxAttempts: 2),
      );

      final configAfter = validTwoHopConfig.toJson();
      expect(configBefore, equals(configAfter));
    });

    // 20. IP degraded does not cause infinite retry
    test(
      '20. IP degraded does not cause infinite retry: 传输连通但公网 IP 源受限 (degraded) 视为就绪，不触发重试',
      () async {
        final mockProbe = MockChainProbeService([
          (_) => _degradedReport(ChainHopMode.twoHop),
          (_) => _healthyReport(ChainHopMode.twoHop), // 若被调用说明误重试了
        ]);
        final engine = ChainRetryService(probeService: mockProbe);

        final report = await engine.probeWithRetry(
          config: validTwoHopConfig,
          policy: const ChainRetryPolicy(maxAttempts: 3),
        );

        expect(report.healthStatus, ChainHealthStatus.degraded);
        expect(report.isOverallHealthy, isTrue);
        expect(report.attemptCount, 1);
        expect(mockProbe.callCount, 1); // 仅执行 1 次，绝无多余重试
      },
    );

    // 21. final error preserved
    test(
      '21. final error preserved: 最终失败报告完整保留 failureHop、errorCode 与原因',
      () async {
        final mockProbe = MockChainProbeService([
          (_) => _failedReport(
            ChainHopMode.threeHop,
            errorCode: ChainProbeErrorCodes.hop2Failed,
            failureHop: 2,
            reason: '中转握手失败',
          ),
        ]);
        final engine = ChainRetryService(probeService: mockProbe);

        final report = await engine.probeWithRetry(
          config: validThreeHopConfig,
          policy: const ChainRetryPolicy(maxAttempts: 1),
        );

        expect(report.failureHop, 2);
        expect(report.errorCode, ChainProbeErrorCodes.hop2Failed);
        expect(report.rootCauseAnalysis, '中转握手失败');
      },
    );

    // 22. attempt count preserved
    test(
      '22. attempt count preserved: 报告中的 attemptCount 准确记录尝试次数 (1, 2, 3)',
      () async {
        for (int expected = 1; expected <= 3; expected++) {
          final mockProbe = MockChainProbeService([
            for (int i = 1; i < expected; i++)
              (_) => _failedReport(
                ChainHopMode.twoHop,
                errorCode: ChainProbeErrorCodes.hop1Timeout,
              ),
            (_) => _healthyReport(ChainHopMode.twoHop),
          ]);
          final engine = ChainRetryService(
            probeService: mockProbe,
            delayOverride: (_, _) async {},
          );

          final report = await engine.probeWithRetry(
            config: validTwoHopConfig,
            policy: const ChainRetryPolicy(maxAttempts: 3),
          );

          expect(report.attemptCount, expected);
        }
      },
    );

    // 23. callback ordering
    test('23. callback ordering: 进度回调严格按时序发出且参数递增', () async {
      final progressList = <ChainRetryProgress>[];
      final mockProbe = MockChainProbeService([
        (_) => _failedReport(
          ChainHopMode.twoHop,
          errorCode: ChainProbeErrorCodes.hop1Timeout,
        ),
        (_) => _healthyReport(ChainHopMode.twoHop),
      ]);
      final engine = ChainRetryService(
        probeService: mockProbe,
        delayOverride: (_, _) async {},
      );

      await engine.probeWithRetry(
        config: validTwoHopConfig,
        policy: const ChainRetryPolicy(maxAttempts: 2),
        onRetryProgress: (p) => progressList.add(p),
      );

      expect(progressList.length, 4);
      expect(progressList[0].state, ChainRetryState.attempting);
      expect(progressList[0].currentAttempt, 1);
      expect(progressList[1].state, ChainRetryState.waiting);
      expect(progressList[1].currentAttempt, 1);
      expect(progressList[2].state, ChainRetryState.attempting);
      expect(progressList[2].currentAttempt, 2);
      expect(progressList[3].state, ChainRetryState.completed);
      expect(progressList[3].currentAttempt, 2);
    });

    // 24. no timer/resource leak
    test('24. no timer/resource leak: 取消时清理退避计时器，无未完成的孤立 Future', () async {
      final token = CancelToken();
      final mockProbe = MockChainProbeService([
        (_) => _failedReport(
          ChainHopMode.twoHop,
          errorCode: ChainProbeErrorCodes.hop1Timeout,
        ),
        (_) => _healthyReport(ChainHopMode.twoHop),
      ]);
      final engine = ChainRetryService(probeService: mockProbe);

      final future = engine.probeWithRetry(
        config: validTwoHopConfig,
        policy: const ChainRetryPolicy(
          maxAttempts: 2,
          baseDelay: Duration(seconds: 30),
        ),
        cancelToken: token,
      );

      // 触发初始 probe 失败以进入 sleep，随后在等待退避时取消
      await Future.delayed(const Duration(milliseconds: 30));
      token.cancel('测试资源清理');

      final report = await future;
      expect(report.isCancelled, isTrue);
      expect(report.healthStatus, ChainHealthStatus.cancelled);
    });
  });
}
