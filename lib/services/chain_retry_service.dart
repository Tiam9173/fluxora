import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';

/// 链式代理重试引擎状态
enum ChainRetryState {
  /// 空闲就绪
  idle,

  /// 正在执行单次探测 (Attempt N/M)
  attempting,

  /// 正在等待指数退避间隔 (Backoff delay)
  waiting,

  /// 链路探测完成且可用 (健康 Healthy 或降级就绪 Degraded)
  completed,

  /// 重试次数耗尽或遇到不可重试错误，最终失败
  failed,

  /// 用户或生命周期主动取消
  cancelled;

  bool get isIdle => this == ChainRetryState.idle;
  bool get isAttempting => this == ChainRetryState.attempting;
  bool get isWaiting => this == ChainRetryState.waiting;
  bool get isCompleted => this == ChainRetryState.completed;
  bool get isFailed => this == ChainRetryState.failed;
  bool get isCancelled => this == ChainRetryState.cancelled;
}

/// 链式代理重试策略配置
class ChainRetryPolicy {
  /// 最大尝试总次数（例如 3 代表：第 1 次初次探测 + 最多 2 次重试，总共最多执行 3 次尝试）
  final int maxAttempts;

  /// 基础退避时间间隔（默认 500ms）
  final Duration baseDelay;

  /// 最大退避时间上限（默认 4s，防止无限膨胀）
  final Duration maxDelay;

  /// 抖动比例因子 (0.0 ~ 0.5)，默认为 0.0（确定性）
  final double jitterFactor;

  /// 可重试的标准错误码集合
  final Set<String> retryableErrors;

  /// 随机数生成器（允许单元测试注入固定种子或 Mock）
  final math.Random? random;

  const ChainRetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 4),
    this.jitterFactor = 0.0,
    this.retryableErrors = const {
      ChainProbeErrorCodes.hop1Timeout,
      ChainProbeErrorCodes.hop1Failed,
      ChainProbeErrorCodes.hop2Timeout,
      ChainProbeErrorCodes.hop2Failed,
      ChainProbeErrorCodes.exitTimeout,
      ChainProbeErrorCodes.exitFailed,
      ChainProbeErrorCodes.upstreamFailed,
      ChainProbeErrorCodes.internetUnreachable,
    },
    this.random,
  });

  /// 计算已完成第 `completedAttempt` 次失败后的退避时长
  ///
  /// 指数退避算法：
  /// - completedAttempt = 1 (第 1 次失败): delay = baseDelay * 2^(1 - 1) = baseDelay * 1
  /// - completedAttempt = 2 (第 2 次失败): delay = baseDelay * 2^(2 - 1) = baseDelay * 2
  /// - completedAttempt = 3 (第 3 次失败): delay = baseDelay * 2^(3 - 1) = baseDelay * 4
  /// 最终受 maxDelay 上限约束。
  /// 若 jitterFactor > 0：在 [cappedMs, cappedMs + cappedMs * jitterFactor] 范围内添加随机抖动。
  Duration calculateDelay(int completedAttempt) {
    if (completedAttempt < 1) return Duration.zero;
    final exponent = completedAttempt - 1;
    // 保护位移防止 32 位溢出
    final power = exponent >= 30 ? 1073741824 : (1 << exponent);
    final baseMs = baseDelay.inMilliseconds;
    final calculatedMs = baseMs * power;
    final cappedMs = math.min(calculatedMs, maxDelay.inMilliseconds);

    if (jitterFactor > 0) {
      final rnd = random ?? math.Random();
      final maxJitter = (cappedMs * jitterFactor).round();
      final jitter = maxJitter > 0 ? rnd.nextInt(maxJitter + 1) : 0;
      return Duration(
        milliseconds: math.min(cappedMs + jitter, maxDelay.inMilliseconds),
      );
    }
    return Duration(milliseconds: cappedMs);
  }

  /// 判断指定探测报告是否属于可重试范畴
  bool isRetryable(ChainProbeReport report) {
    // 1. 用户主动取消 -> 严禁重试
    if (report.isCancelled ||
        report.healthStatus == ChainHealthStatus.cancelled) {
      return false;
    }
    // 2. 成功 (健康) 或降级 (传输层连通但公网 IP 服务受限) -> 传输可用，直接成功，严禁重试
    if (report.healthStatus == ChainHealthStatus.healthy ||
        report.healthStatus == ChainHealthStatus.degraded) {
      return false;
    }
    // 3. 静态拓扑错误或取消错误 -> 严禁重试
    if (report.errorCode == ChainProbeErrorCodes.topologyInvalid) {
      return false;
    }
    if (report.errorCode == ChainProbeErrorCodes.cancelled) {
      return false;
    }
    // 4. 依据白名单判断瞬态网络错误
    if (report.errorCode != null &&
        retryableErrors.contains(report.errorCode)) {
      return true;
    }
    return false;
  }
}

/// 链式代理重试进度详情
class ChainRetryProgress {
  final ChainRetryState state;
  final int currentAttempt;
  final int maxAttempts;
  final Duration? nextRetryDelay;
  final ChainProbeReport? lastReport;
  final String? message;

  const ChainRetryProgress({
    required this.state,
    required this.currentAttempt,
    required this.maxAttempts,
    this.nextRetryDelay,
    this.lastReport,
    this.message,
  });

  String get userDescription {
    return switch (state) {
      ChainRetryState.idle => '就绪',
      ChainRetryState.attempting => '正在检测 ($currentAttempt/$maxAttempts)...',
      ChainRetryState.waiting =>
        '网络波动，等待 ${(nextRetryDelay?.inMilliseconds ?? 0) / 1000}s 后重试 ($currentAttempt/$maxAttempts)...',
      ChainRetryState.completed => '检测完成',
      ChainRetryState.failed => '检测失败 (已尝试 $currentAttempt 次)',
      ChainRetryState.cancelled => '已取消检测',
    };
  }
}

/// 重试引擎服务接口
abstract class IChainRetryService {
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
  });
}

/// 链式代理重试引擎实现
class ChainRetryService implements IChainRetryService {
  final IChainProbeService _probeService;
  final Future<void> Function(Duration duration, CancelToken? cancelToken)?
  _delayOverride;

  ChainRetryService({
    IChainProbeService? probeService,
    Future<void> Function(Duration duration, CancelToken? cancelToken)?
    delayOverride,
  }) : _probeService = probeService ?? chainProbeService,
       _delayOverride = delayOverride;

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
    final mode = config.hopMode;
    final maxAttempts = math.max(1, policy.maxAttempts);

    // 1. 启动前先检查取消标记
    if (cancelToken?.isCancelled == true) {
      final cancelledReport = ChainProbeReport.cancelled(
        mode: mode,
        timestamp: DateTime.now(),
        attemptCount: 0,
      );
      onRetryProgress?.call(
        ChainRetryProgress(
          state: ChainRetryState.cancelled,
          currentAttempt: 0,
          maxAttempts: maxAttempts,
          lastReport: cancelledReport,
          message: '用户已取消检测',
        ),
      );
      return cancelledReport;
    }

    // 2. 拓扑合法性前置检查 (全局严格只验证一次，非法拓扑绝不进入重试循环)
    final hop1 = config.effectiveHop1;
    final hop2 = config.hop2Node;
    final hop3 = config.hop3Node;
    final validation = ChainTopologyValidator.validate(
      mode: mode,
      hop1: hop1,
      hop2: hop2,
      hop3: mode == ChainHopMode.threeHop ? hop3 : null,
      dedicatedGroupName: config.dedicatedGroupName,
    );

    if (!validation.isValid) {
      final invalidReport = ChainProbeReport(
        mode: mode,
        isOverallHealthy: false,
        healthStatus: ChainHealthStatus.failed,
        hops: const [],
        failureHop: validation.affectedHop,
        errorCode: ChainProbeErrorCodes.topologyInvalid,
        rootCauseAnalysis: '链路拓扑非法: ${validation.message}',
        attemptCount: 1,
        timestamp: DateTime.now(),
      );
      onProgress?.call(invalidReport);
      onRetryProgress?.call(
        ChainRetryProgress(
          state: ChainRetryState.failed,
          currentAttempt: 1,
          maxAttempts: maxAttempts,
          lastReport: invalidReport,
          message: '链路拓扑非法，不可重试',
        ),
      );
      return invalidReport;
    }

    // 3. 循环尝试 (Attempt 1 .. maxAttempts)
    ChainProbeReport? lastReport;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      // 3.1 尝试前检查取消
      if (cancelToken?.isCancelled == true) {
        final cancelledReport = ChainProbeReport.cancelled(
          mode: mode,
          timestamp: DateTime.now(),
          attemptCount: attempt,
        );
        onRetryProgress?.call(
          ChainRetryProgress(
            state: ChainRetryState.cancelled,
            currentAttempt: attempt,
            maxAttempts: maxAttempts,
            lastReport: cancelledReport,
            message: '用户已取消检测',
          ),
        );
        return cancelledReport;
      }

      // 3.2 发送 attempting 进度
      if (attempt > 1) {
        chainTelemetryService.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.retryStarted,
            nodeName: config.effectiveHop1,
            role: 'Entry',
            message: '正在进行第 $attempt/$maxAttempts 次重试...',
            metadata: {'currentAttempt': attempt, 'maxAttempts': maxAttempts},
          ),
        );
      }

      onRetryProgress?.call(
        ChainRetryProgress(
          state: ChainRetryState.attempting,
          currentAttempt: attempt,
          maxAttempts: maxAttempts,
          lastReport: lastReport,
          message: '正在进行第 $attempt/$maxAttempts 次链路健康检测...',
        ),
      );

      // 3.3 执行单次探测
      final report = await _probeService.probeChain(
        config: config,
        testUrl: testUrl,
        checkExitPublicIp: checkExitPublicIp,
        cancelToken: cancelToken,
        timeout: timeout,
        onHopUpdate: onHopUpdate,
        onProgress: (interim) {
          onProgress?.call(interim.copyWith(attemptCount: attempt));
        },
      );

      final enrichedReport = report.copyWith(attemptCount: attempt);
      lastReport = enrichedReport;

      // 3.4 检查探测中是否被取消
      if (cancelToken?.isCancelled == true || enrichedReport.isCancelled) {
        final cancelledReport = ChainProbeReport.cancelled(
          mode: mode,
          timestamp: DateTime.now(),
          attemptCount: attempt,
        );
        onRetryProgress?.call(
          ChainRetryProgress(
            state: ChainRetryState.cancelled,
            currentAttempt: attempt,
            maxAttempts: maxAttempts,
            lastReport: cancelledReport,
            message: '用户已取消检测',
          ),
        );
        return cancelledReport;
      }

      // 3.5 成功判断：healthy 或 degraded（传输层健康，仅公网IP源失败）直接成功，无需重试
      if (enrichedReport.healthStatus == ChainHealthStatus.healthy ||
          enrichedReport.healthStatus == ChainHealthStatus.degraded) {
        if (attempt > 1) {
          chainTelemetryService.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.retrySucceeded,
              nodeName: config.effectiveHop1,
              role: 'Entry',
              message: '重试成功 (第 $attempt 次尝试通过)',
              metadata: {'currentAttempt': attempt},
            ),
          );
        }
        onRetryProgress?.call(
          ChainRetryProgress(
            state: ChainRetryState.completed,
            currentAttempt: attempt,
            maxAttempts: maxAttempts,
            lastReport: enrichedReport,
            message: enrichedReport.healthStatus == ChainHealthStatus.healthy
                ? '链路检测成功 (第 $attempt 次尝试通过)'
                : '链路传输畅通但公网 IP 服务受限 (第 $attempt 次尝试)',
          ),
        );
        return enrichedReport;
      }

      // 3.6 失败判断：若已达到最大尝试次数，直接返回失败
      if (attempt >= maxAttempts) {
        if (attempt > 1) {
          chainTelemetryService.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.retryFailed,
              nodeName: config.effectiveHop1,
              role: 'Entry',
              message: '重试次数耗尽，已达到最大尝试次数 ($maxAttempts)',
              metadata: {'currentAttempt': attempt},
            ),
          );
        }
        onRetryProgress?.call(
          ChainRetryProgress(
            state: ChainRetryState.failed,
            currentAttempt: attempt,
            maxAttempts: maxAttempts,
            lastReport: enrichedReport,
            message: '已达到最大重试次数 ($maxAttempts 次)，链路检测失败',
          ),
        );
        return enrichedReport;
      }

      // 3.7 检查是否属于可重试错误
      if (!policy.isRetryable(enrichedReport)) {
        if (attempt > 1) {
          chainTelemetryService.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.retryFailed,
              nodeName: config.effectiveHop1,
              role: 'Entry',
              message: '遇到不可重试错误 (${enrichedReport.errorCode})，终止重试',
              metadata: {
                'currentAttempt': attempt,
                'errorCode': enrichedReport.errorCode,
              },
            ),
          );
        }
        onRetryProgress?.call(
          ChainRetryProgress(
            state: ChainRetryState.failed,
            currentAttempt: attempt,
            maxAttempts: maxAttempts,
            lastReport: enrichedReport,
            message: '遇到不可重试错误 (${enrichedReport.errorCode})，终止重试',
          ),
        );
        return enrichedReport;
      }

      // 3.8 可重试：计算指数退避时间并进入 waiting 状态
      final delay = policy.calculateDelay(attempt);
      chainTelemetryService.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.retryBackoff,
          nodeName: config.effectiveHop1,
          role: 'Entry',
          message: '触发退避等待 ${delay.inMilliseconds}ms',
          metadata: {
            'delayMs': delay.inMilliseconds,
            'currentAttempt': attempt,
          },
        ),
      );
      onRetryProgress?.call(
        ChainRetryProgress(
          state: ChainRetryState.waiting,
          currentAttempt: attempt,
          maxAttempts: maxAttempts,
          nextRetryDelay: delay,
          lastReport: enrichedReport,
          message:
              '第 $attempt 次检测失败 (${enrichedReport.errorCode})，等待 ${delay.inMilliseconds}ms 后重试...',
        ),
      );

      // 3.9 可取消等待
      await _cancellableSleep(delay, cancelToken);

      // 3.10 等待后再次检查取消
      if (cancelToken?.isCancelled == true) {
        final cancelledReport = ChainProbeReport.cancelled(
          mode: mode,
          timestamp: DateTime.now(),
          attemptCount: attempt,
        );
        onRetryProgress?.call(
          ChainRetryProgress(
            state: ChainRetryState.cancelled,
            currentAttempt: attempt,
            maxAttempts: maxAttempts,
            lastReport: cancelledReport,
            message: '用户已取消检测',
          ),
        );
        return cancelledReport;
      }
    }

    return lastReport ??
        ChainProbeReport(
          mode: mode,
          isOverallHealthy: false,
          healthStatus: ChainHealthStatus.failed,
          hops: const [],
          errorCode: ChainProbeErrorCodes.unknown,
          rootCauseAnalysis: '重试引擎异常退出',
          attemptCount: maxAttempts,
          timestamp: DateTime.now(),
        );
  }

  Future<void> _cancellableSleep(
    Duration duration,
    CancelToken? cancelToken,
  ) async {
    final delayOverride = _delayOverride;
    if (delayOverride != null) {
      return delayOverride(duration, cancelToken);
    }
    if (duration <= Duration.zero || cancelToken?.isCancelled == true) {
      return;
    }

    final completer = Completer<void>();
    Timer? timer;

    timer = Timer(duration, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    if (cancelToken != null) {
      cancelToken.whenCancel
          .then((_) {
            if (timer?.isActive == true) {
              timer?.cancel();
            }
            if (!completer.isCompleted) {
              completer.complete();
            }
          })
          .catchError((_) {});
    }

    await completer.future;
  }
}

final chainRetryService = ChainRetryService();
