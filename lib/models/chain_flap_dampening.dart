import 'package:fluxora/models/chain_fallback_pool.dart';

/// 单次链路切换抖动事件记录（纯内存轻量结构）
class ChainFlapEvent {
  final DateTime timestamp;
  final FallbackCandidateRole role;
  final String fromNode;
  final String toNode;
  final String? reason;
  final bool isSuccess;

  const ChainFlapEvent({
    required this.timestamp,
    required this.role,
    required this.fromNode,
    required this.toNode,
    this.reason,
    this.isSuccess = true,
  });

  @override
  String toString() =>
      'ChainFlapEvent($role: "$fromNode" -> "$toNode", time: $timestamp, success: $isSuccess)';
}

/// 链路抖动抑制控制策略配置
class ChainFlapDampeningPolicy {
  /// 是否启用抖动抑制 (默认 true)
  final bool enabled;

  /// 滑动窗口统计时长 (默认 60 秒)
  final Duration windowDuration;

  /// 滑动窗口内允许的最大切换频次 (默认 3 次)
  final int maxFlapsInWindow;

  /// 两次故障转移之间的最小冷却间隔 (默认 15 秒)
  final Duration minSwitchInterval;

  /// 单次切流产生的惩罚分 (默认 1000.0)
  final double penaltyPerFlap;

  /// 触发抑制阻断的惩罚分阈值 (默认 2000.0)
  final double suppressThreshold;

  /// 解除抑制恢复可切流的惩罚分阈值 (默认 800.0)
  final double reuseThreshold;

  /// 惩罚分指数衰减半衰期 (默认 45 秒)
  final Duration halfLife;

  /// 单次触发抑制的最长持续时间上限 (默认 5 分钟)
  final Duration maxSuppressDuration;

  /// 内存中最多保留的历史切流事件记录数 (默认 50 条，防止内存无界增长)
  final int maxHistoryEvents;

  const ChainFlapDampeningPolicy({
    this.enabled = true,
    this.windowDuration = const Duration(seconds: 60),
    this.maxFlapsInWindow = 3,
    this.minSwitchInterval = const Duration(seconds: 15),
    this.penaltyPerFlap = 1000.0,
    this.suppressThreshold = 2000.0,
    this.reuseThreshold = 800.0,
    this.halfLife = const Duration(seconds: 45),
    this.maxSuppressDuration = const Duration(minutes: 5),
    this.maxHistoryEvents = 50,
  });

  ChainFlapDampeningPolicy copyWith({
    bool? enabled,
    Duration? windowDuration,
    int? maxFlapsInWindow,
    Duration? minSwitchInterval,
    double? penaltyPerFlap,
    double? suppressThreshold,
    double? reuseThreshold,
    Duration? halfLife,
    Duration? maxSuppressDuration,
    int? maxHistoryEvents,
  }) {
    return ChainFlapDampeningPolicy(
      enabled: enabled ?? this.enabled,
      windowDuration: windowDuration ?? this.windowDuration,
      maxFlapsInWindow: maxFlapsInWindow ?? this.maxFlapsInWindow,
      minSwitchInterval: minSwitchInterval ?? this.minSwitchInterval,
      penaltyPerFlap: penaltyPerFlap ?? this.penaltyPerFlap,
      suppressThreshold: suppressThreshold ?? this.suppressThreshold,
      reuseThreshold: reuseThreshold ?? this.reuseThreshold,
      halfLife: halfLife ?? this.halfLife,
      maxSuppressDuration: maxSuppressDuration ?? this.maxSuppressDuration,
      maxHistoryEvents: maxHistoryEvents ?? this.maxHistoryEvents,
    );
  }
}

/// 抖动抑制判定评估结果
class ChainFlapVerdict {
  /// 是否允许继续执行故障转移
  final bool canProceed;

  /// 是否已被抑制阻断
  final bool isDampened;

  /// 评估时刻的衰减惩罚积分
  final double penalty;

  /// 剩余抑制/冷却时间
  final Duration? remainingCooldown;

  /// 抑制截止时间 (若已被抑制)
  final DateTime? suppressedUntil;

  /// 阻断原因说明
  final String? reason;

  const ChainFlapVerdict({
    required this.canProceed,
    required this.isDampened,
    required this.penalty,
    this.remainingCooldown,
    this.suppressedUntil,
    this.reason,
  });

  factory ChainFlapVerdict.allowed({double penalty = 0.0}) {
    return ChainFlapVerdict(
      canProceed: true,
      isDampened: false,
      penalty: penalty,
    );
  }

  factory ChainFlapVerdict.dampened({
    required double penalty,
    required Duration remainingCooldown,
    DateTime? suppressedUntil,
    required String reason,
  }) {
    return ChainFlapVerdict(
      canProceed: false,
      isDampened: true,
      penalty: penalty,
      remainingCooldown: remainingCooldown,
      suppressedUntil: suppressedUntil,
      reason: reason,
    );
  }
}

/// 抖动抑制器对外的实时状态快照 (纯内存，供 UI / Provider 观测)
class ChainFlapDampenerStatus {
  final bool isSuppressed;
  final double currentPenalty;
  final int flapCountInWindow;
  final DateTime? lastFlapTime;
  final DateTime? suppressedUntil;
  final Duration? remainingCooldown;
  final String? reason;
  final List<ChainFlapEvent> recentEvents;

  const ChainFlapDampenerStatus({
    required this.isSuppressed,
    required this.currentPenalty,
    required this.flapCountInWindow,
    this.lastFlapTime,
    this.suppressedUntil,
    this.remainingCooldown,
    this.reason,
    this.recentEvents = const [],
  });

  factory ChainFlapDampenerStatus.initial() {
    return const ChainFlapDampenerStatus(
      isSuppressed: false,
      currentPenalty: 0.0,
      flapCountInWindow: 0,
    );
  }

  String get summaryText {
    if (!isSuppressed) {
      if (currentPenalty > 0) {
        return '链路稳定 (抖动分: ${currentPenalty.toStringAsFixed(0)})';
      }
      return '链路稳定';
    }
    final secs = remainingCooldown?.inSeconds ?? 0;
    if (secs > 0) {
      return '频繁切换已抑制 (将在 ${secs}s 后解禁: ${reason ?? "防颠簸保护"})';
    }
    return '频繁切换已抑制 (${reason ?? "防颠簸保护"})';
  }
}
