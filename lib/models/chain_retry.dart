// 链式重试的纯数据类型。
//
// 从 `services/chain_retry_service.dart` 剥离出来：`probeCurrentChain()` 的
// 参数里要用 [ChainRetryPolicy]，而探测是**在用的功能**，不能因为删掉故障转移
// 服务就把这些类型一起删掉。

import 'dart:math' as math;

import 'package:fluxora/services/chain_probe_service.dart';

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