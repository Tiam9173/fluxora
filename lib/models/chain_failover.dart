import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_flap_dampening.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_retry_service.dart';
import 'package:fluxora/services/chain_fallback_service.dart';

/// 链式代理自动故障转移状态机状态
enum ChainFailoverState {
  /// 空闲就绪
  idle('空闲就绪'),

  /// 正在执行原链路有限重试 (Phase 3.2-A)
  retrying('链路重试中'),

  /// 重试耗尽，正在备用池中优选候选节点 (Phase 3.2-B)
  selectingCandidate('选择备用节点'),

  /// 正在构建候选链路配置
  buildingCandidate('构建备用拓扑'),

  /// 正在执行拓扑与冲突合法性校验
  validatingCandidate('校验备用拓扑'),

  /// 正在注入影子节点并向内核热应用配置
  applyingCandidate('切换备用节点'),

  /// 正在对应用后的新链路执行连通性探测
  probingCandidate('验证新链路'),

  /// 候选节点探测通过 (健康或降级准入)
  candidateHealthy('候选节点就绪'),

  /// 候选节点探测失败
  candidateFailed('候选节点不可用'),

  /// 候选节点失败，正在回滚至原链路配置
  rollingBack('回滚原链路'),

  /// 回滚过程遭遇异常，需进入严重告警状态
  rollbackFailed('回滚失败'),

  /// 故障转移成功完成并已提交
  failoverSuccess('故障转移成功'),

  /// 所有候选节点均尝试完毕且不可用，转移失败
  failoverFailed('故障转移失败'),

  /// 链路高频抖动触发抑制阻断 (Phase 3.2-D)
  dampened('抖动抑制'),

  /// 用户或生命周期主动取消
  cancelled('已取消');

  final String label;
  const ChainFailoverState(this.label);

  bool get isIdle => this == ChainFailoverState.idle;
  bool get isRetrying => this == ChainFailoverState.retrying;
  bool get isSelecting => this == ChainFailoverState.selectingCandidate;
  bool get isApplying => this == ChainFailoverState.applyingCandidate;
  bool get isProbing => this == ChainFailoverState.probingCandidate;
  bool get isRollingBack => this == ChainFailoverState.rollingBack;
  bool get isRollbackFailed => this == ChainFailoverState.rollbackFailed;
  bool get isSuccess => this == ChainFailoverState.failoverSuccess;
  bool get isFailed => this == ChainFailoverState.failoverFailed;
  bool get isDampened => this == ChainFailoverState.dampened;
  bool get isCancelled => this == ChainFailoverState.cancelled;
  bool get isTerminal =>
      this == ChainFailoverState.failoverSuccess ||
      this == ChainFailoverState.failoverFailed ||
      this == ChainFailoverState.rollbackFailed ||
      this == ChainFailoverState.cancelled ||
      this == ChainFailoverState.dampened;
}

/// 自动故障转移执行策略
class ChainFailoverPolicy {
  /// 本次 Failover Session 最大尝试的候选节点数量上限 (默认 3，有限尝试)
  final int maxCandidates;

  /// 是否允许在降级状态 (传输层畅通但公网 IP 服务不可达) 下提交 Failover (默认 true)
  final bool allowDegradedCommit;

  /// 单个候选节点探测超时时间 (默认 5 秒)
  final Duration probeTimeout;

  /// 原链路前置重试策略 (默认 3 次有限重试)
  final ChainRetryPolicy retryPolicy;

  /// 备用节点池优选策略
  final ChainFallbackPolicy fallbackPolicy;

  /// 抖动抑制控制策略 (Phase 3.2-D)
  final ChainFlapDampeningPolicy flapPolicy;

  /// 是否显式绕过抖动抑制 (如用户手动触发重试或强制切换)
  final bool bypassDampening;

  const ChainFailoverPolicy({
    this.maxCandidates = 3,
    this.allowDegradedCommit = true,
    this.probeTimeout = const Duration(seconds: 5),
    this.retryPolicy = const ChainRetryPolicy(maxAttempts: 3),
    this.fallbackPolicy = const ChainFallbackPolicy(),
    this.flapPolicy = const ChainFlapDampeningPolicy(),
    this.bypassDampening = false,
  });
}

/// 自动故障转移进度通知
class ChainFailoverProgress {
  final ChainFailoverState state;
  final FallbackCandidateRole? role;
  final String? candidateNodeName;
  final int candidateIndex; // 0-based
  final int totalCandidates;
  final String message;
  final ChainProbeReport? lastReport;
  final String? failureReason;
  final DateTime timestamp;

  const ChainFailoverProgress({
    required this.state,
    this.role,
    this.candidateNodeName,
    this.candidateIndex = 0,
    this.totalCandidates = 0,
    required this.message,
    this.lastReport,
    this.failureReason,
    required this.timestamp,
  });

  String get userDescription {
    if (state == ChainFailoverState.probingCandidate &&
        candidateNodeName != null) {
      final indexInfo = totalCandidates > 0
          ? ' (${candidateIndex + 1}/$totalCandidates)'
          : '';
      return '正在验证候选节点 [$candidateNodeName]$indexInfo...';
    }
    if (state == ChainFailoverState.applyingCandidate &&
        candidateNodeName != null) {
      return '正在切换至候选节点 [$candidateNodeName]...';
    }
    if (state == ChainFailoverState.rollingBack) {
      return '候选节点未通过检测，正在回滚原链路...';
    }
    if (state == ChainFailoverState.dampened) {
      return message;
    }
    return message;
  }
}

/// 自动故障转移最终执行结果
class ChainFailoverResult {
  final bool isSuccess;
  final ChainFailoverState state;
  final ChainProxyConfig finalConfig;
  final String? switchedNodeName;
  final FallbackCandidateRole? switchedRole;
  final int attemptedCandidatesCount;
  final List<String> attemptedNodeNames;
  final ChainProbeReport? probeReport;
  final String? rootCause;
  final String? rollbackError;
  final bool isRollbackFailed;
  final bool isCancelled;
  final bool isDampened;
  final double? dampeningPenalty;
  final DateTime? suppressedUntil;
  final DateTime completedAt;

  const ChainFailoverResult({
    required this.isSuccess,
    required this.state,
    required this.finalConfig,
    this.switchedNodeName,
    this.switchedRole,
    this.attemptedCandidatesCount = 0,
    this.attemptedNodeNames = const [],
    this.probeReport,
    this.rootCause,
    this.rollbackError,
    this.isRollbackFailed = false,
    this.isCancelled = false,
    this.isDampened = false,
    this.dampeningPenalty,
    this.suppressedUntil,
    required this.completedAt,
  });

  factory ChainFailoverResult.success({
    required ChainProxyConfig finalConfig,
    required String switchedNodeName,
    required FallbackCandidateRole switchedRole,
    required int attemptedCandidatesCount,
    required List<String> attemptedNodeNames,
    required ChainProbeReport probeReport,
  }) {
    return ChainFailoverResult(
      isSuccess: true,
      state: ChainFailoverState.failoverSuccess,
      finalConfig: finalConfig,
      switchedNodeName: switchedNodeName,
      switchedRole: switchedRole,
      attemptedCandidatesCount: attemptedCandidatesCount,
      attemptedNodeNames: attemptedNodeNames,
      probeReport: probeReport,
      completedAt: DateTime.now(),
    );
  }

  factory ChainFailoverResult.noFailoverNeeded({
    required ChainProxyConfig currentConfig,
    ChainProbeReport? probeReport,
  }) {
    return ChainFailoverResult(
      isSuccess: true,
      state: ChainFailoverState.failoverSuccess,
      finalConfig: currentConfig,
      attemptedCandidatesCount: 0,
      attemptedNodeNames: const [],
      probeReport: probeReport,
      rootCause: '原链路检测畅通，无需触发故障转移',
      completedAt: DateTime.now(),
    );
  }

  factory ChainFailoverResult.failed({
    required ChainProxyConfig originalConfig,
    required int attemptedCandidatesCount,
    required List<String> attemptedNodeNames,
    ChainProbeReport? lastProbeReport,
    required String rootCause,
  }) {
    return ChainFailoverResult(
      isSuccess: false,
      state: ChainFailoverState.failoverFailed,
      finalConfig: originalConfig,
      attemptedCandidatesCount: attemptedCandidatesCount,
      attemptedNodeNames: attemptedNodeNames,
      probeReport: lastProbeReport,
      rootCause: rootCause,
      completedAt: DateTime.now(),
    );
  }

  factory ChainFailoverResult.rollbackFailed({
    required ChainProxyConfig originalConfig,
    required int attemptedCandidatesCount,
    required List<String> attemptedNodeNames,
    required String rollbackError,
    ChainProbeReport? lastProbeReport,
    String? rootCause,
  }) {
    return ChainFailoverResult(
      isSuccess: false,
      state: ChainFailoverState.rollbackFailed,
      finalConfig: originalConfig,
      attemptedCandidatesCount: attemptedCandidatesCount,
      attemptedNodeNames: attemptedNodeNames,
      probeReport: lastProbeReport,
      rootCause: rootCause ?? '回滚原链路失败',
      rollbackError: rollbackError,
      isRollbackFailed: true,
      completedAt: DateTime.now(),
    );
  }

  factory ChainFailoverResult.dampened({
    required ChainProxyConfig currentConfig,
    required double penalty,
    DateTime? suppressedUntil,
    required String reason,
    ChainProbeReport? probeReport,
  }) {
    return ChainFailoverResult(
      isSuccess: false,
      state: ChainFailoverState.dampened,
      finalConfig: currentConfig,
      isDampened: true,
      dampeningPenalty: penalty,
      suppressedUntil: suppressedUntil,
      rootCause: reason,
      probeReport: probeReport,
      completedAt: DateTime.now(),
    );
  }

  factory ChainFailoverResult.cancelled({
    required ChainProxyConfig originalConfig,
    int attemptedCandidatesCount = 0,
    List<String> attemptedNodeNames = const [],
    String? reason,
  }) {
    return ChainFailoverResult(
      isSuccess: false,
      state: ChainFailoverState.cancelled,
      finalConfig: originalConfig,
      attemptedCandidatesCount: attemptedCandidatesCount,
      attemptedNodeNames: attemptedNodeNames,
      isCancelled: true,
      rootCause: reason ?? '故障转移已被用户或系统取消',
      completedAt: DateTime.now(),
    );
  }
}
