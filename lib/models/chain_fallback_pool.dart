import 'chain_reliability_stats.dart';
import 'latency_state.dart';
import '../services/network_fingerprint_provider.dart';
import 'package:fluxora/services/chain_probe_service.dart';

/// 备用候选节点在链式拓扑中的角色
enum FallbackCandidateRole {
  /// 入口节点（第一跳 / 前置跳板）
  entry('入口节点'),

  /// 中转节点（第二跳 / 三跳模式中转）
  relay('中转节点'),

  /// 落地出口（两跳模式第二跳 / 三跳模式第三跳）
  exit('落地出口');

  final String label;
  const FallbackCandidateRole(this.label);

  static FallbackCandidateRole fromString(String? val) {
    if (val == null) return FallbackCandidateRole.exit;
    final lower = val.toLowerCase().trim();
    return switch (lower) {
      'entry' || 'hop1' || 'dialer' => FallbackCandidateRole.entry,
      'relay' || 'hop2' || 'transit' => FallbackCandidateRole.relay,
      'exit' || 'hop3' || 'landing' => FallbackCandidateRole.exit,
      _ => FallbackCandidateRole.exit,
    };
  }
}

/// 备用候选节点定义
///
/// 仅保留节点名称引用 (nodeName) 与必要元数据，严禁在此处复制完整 Mihomo 节点配置。
class ChainFallbackCandidate {
  /// 引用的原始节点名称（例如订阅中的节点名称或自定义落地名称）
  final String nodeName;

  /// 该候选节点绑定的角色（entry / relay / exit）
  final FallbackCandidateRole role;

  /// 是否启用作为备用候选
  final bool enabled;

  /// 候选优先级（数值越小优先级越高，0 为最高优先级）
  final int priority;

  /// 候选节点最近健康状态 (复用 Phase 3.1 ChainHealthStatus)
  final ChainHealthStatus health;

  /// 最近探测延迟（毫秒，null 代表未测或不可用，严禁伪造）
  ///
  /// **P1.3-A2 — 写入边界（重要，勿误解为「已生效的通用延迟信号」）**：
  ///  * 该字段**仅**由 **failover 候选探测路径**写入
  ///    （`ChainFailoverService._updateCandidateStats` 与候选探测回写）；
  ///  * **健康检查路径不写它** —— `ChainProxyManager._writeBackProbeResultsToCandidates`
  ///    只累积 `statsByContext`（reliability 样本），**不刷新** `latencyMs` / `health`；
  ///  * **UI 主动测速不写它** —— UI 测速结果只进 `AppState.delayMap`
  ///    （供 proxies 列表展示 / 排序），**从不**进入本字段；
  ///  * 因此**在未触发过 failover 的会话中，本字段恒为 `null`**；
  ///  * 当它为 `null` 时，`ChainAdaptiveScoreService.calculateNodeScore` 取**默认
  ///    `latencyScore = 50.0`** ⇒ 0.3 的 latency 权重退化为常量贡献。
  ///
  /// 生命周期提示：本字段**无网络上下文（fingerprint）分桶、无时间戳、且不落盘**
  /// （对比 `statsByContext` 三者皆有）—— 它与 reliability 的**生命周期不同**。
  ///
  /// **P1.3-C2 — 生命周期（与 reliability 明确不同）**：**无 TTL / 无过期 / 无 decay**
  /// （latency 是某一时刻的观测值，不是可累积的统计量，对单值做指数衰减没有意义）；
  /// 且**使用前不校验年龄** —— `calculateNodeScore` 只判断 `latencyMs != null`，
  /// 故**任意久远**的值都会被当作当前值参与 0.3 权重。
  ///
  /// 延迟来源的统一 / 时效 / 写入面补齐属 **P1.3-C Score Model Evolution**
  /// （会**同时**影响 UI 排序与 failover 候选，需独立设计），**不在本阶段实施**。
  final int? latencyMs;

  /// 最近检测时间
  ///
  /// **P1.3-C2**：该字段目前**只写不读** —— 没有任何生产代码读取它来判断
  /// `latencyMs` / `health` 的时效（时间戳被采集后即闲置）。
  final DateTime? lastChecked;

  /// **P1.3-C4-Step3**：`node` scope 的延迟观测 —— 该候选**自身**的跳延迟
  /// （来源：探测报告中该节点对应的 hop；无对应 hop 时不写入，绝不猜测）。
  ///
  /// ⚠️ 当前**无消费者** —— Step3 只做数据归属；读取路径切换属 Step5。
  final LatencyState? nodeLatency;

  /// **P1.3-C4-Step3**：`chain` scope 的延迟观测 —— 该候选所在**整链**的总延迟。
  ///
  /// ⚠️ 当前**无消费者** —— failover 的实际排序仍读 `latencyMs`（兼容 shim）。
  final LatencyState? chainLatency;

  /// 连续失败次数计数
  final Map<String, ChainReliabilityStats> statsByContext;

  /// 累计探测成功次数计数

  /// 冷却截止时间（在此时间前不可被选举）
  final DateTime? cooldownUntil;

  const ChainFallbackCandidate({
    required this.nodeName,
    required this.role,
    this.enabled = true,
    this.priority = 0,
    this.health = ChainHealthStatus.unknown,
    this.latencyMs,
    this.lastChecked,
    this.nodeLatency,
    this.chainLatency,
    this.statsByContext = const {},

    this.cooldownUntil,
  });

  /// 判断当前时间点是否仍处于冷却期

  ChainReliabilityStats get _currentStats {
    final fingerprint = networkFingerprintProvider.getCurrentFingerprint();
    return statsByContext[fingerprint] ??
        ChainReliabilityStats.initial(networkFingerprint: fingerprint);
  }

  int get failureCount => _currentStats.consecutiveFailures;
  int get successCount => _currentStats.weightedSuccess.toInt();

  bool isCoolingDown(DateTime now) {
    if (cooldownUntil == null) return false;
    return now.isBefore(cooldownUntil!);
  }

  ChainFallbackCandidate copyWith({
    String? nodeName,
    FallbackCandidateRole? role,
    bool? enabled,
    int? priority,
    ChainHealthStatus? health,
    int? latencyMs,
    DateTime? lastChecked,
    LatencyState? nodeLatency,
    LatencyState? chainLatency,
    Map<String, ChainReliabilityStats>? statsByContext,

    DateTime? cooldownUntil,
  }) {
    return ChainFallbackCandidate(
      nodeName: nodeName ?? this.nodeName,
      role: role ?? this.role,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      health: health ?? this.health,
      latencyMs: latencyMs ?? this.latencyMs,
      lastChecked: lastChecked ?? this.lastChecked,
      nodeLatency: nodeLatency ?? this.nodeLatency,
      chainLatency: chainLatency ?? this.chainLatency,
      statsByContext: statsByContext ?? this.statsByContext,

      cooldownUntil: cooldownUntil ?? this.cooldownUntil,
    );
  }

  /// 序列化为持久化 JSON
  ///
  /// 遵循设计规范：仅持久化静态配置 (nodeName, role, enabled, priority)，
  /// 运行时动态状态 (health, failureCount, cooldownUntil, lastChecked) 不写入配置文件。
  Map<String, dynamic> toJson({bool includeRuntimeState = false}) => {
    'nodeName': nodeName,
    'role': role.name,
    'enabled': enabled,
    'priority': priority,
    if (includeRuntimeState) ...{
      'health': health.name,
      if (latencyMs != null) 'latencyMs': latencyMs,
      if (lastChecked != null) 'lastChecked': lastChecked!.toIso8601String(),
      'statsByContext': statsByContext.map(
        (k, v) => MapEntry(k, {
          'weightedSuccess': v.weightedSuccess,
          'weightedFailure': v.weightedFailure,
          'consecutiveFailures': v.consecutiveFailures,
          'totalSamples': v.totalSamples,
          'lastUpdated': v.lastUpdated.toIso8601String(),
          'networkFingerprint': v.networkFingerprint,
        }),
      ),

      if (cooldownUntil != null)
        'cooldownUntil': cooldownUntil!.toIso8601String(),
    },
  };

  factory ChainFallbackCandidate.fromJson(Map<String, dynamic> json) {
    final roleName = json['role']?.toString();
    final role = FallbackCandidateRole.fromString(roleName);

    final healthName = json['health']?.toString();
    final health = ChainHealthStatus.values.firstWhere(
      (e) => e.name == healthName,
      orElse: () => ChainHealthStatus.unknown,
    );

    return ChainFallbackCandidate(
      nodeName: json['nodeName']?.toString() ?? '',
      role: role,
      enabled: json['enabled'] != false,
      priority: json['priority'] as int? ?? 0,
      health: health,
      latencyMs: json['latencyMs'] as int?,
      lastChecked: DateTime.tryParse(json['lastChecked']?.toString() ?? ''),
      statsByContext: () {
        final rawStats = json['statsByContext'] as Map?;
        if (rawStats == null) return <String, ChainReliabilityStats>{};
        return rawStats.map((k, v) {
          final map = v as Map;
          return MapEntry(
            k.toString(),
            ChainReliabilityStats(
              weightedSuccess:
                  (map['weightedSuccess'] as num?)?.toDouble() ?? 0.0,
              weightedFailure:
                  (map['weightedFailure'] as num?)?.toDouble() ?? 0.0,
              consecutiveFailures: map['consecutiveFailures'] as int? ?? 0,
              lastUpdated:
                  DateTime.tryParse(map['lastUpdated']?.toString() ?? '') ??
                  DateTime.now(),
              totalSamples: map['totalSamples'] as int? ?? 0,
              networkFingerprint:
                  map['networkFingerprint']?.toString() ?? k.toString(),
            ),
          );
        });
      }(),

      cooldownUntil: DateTime.tryParse(json['cooldownUntil']?.toString() ?? ''),
    );
  }
}

/// 备用节点池数据模型
class ChainFallbackPool {
  /// 入口备用候选列表
  final List<ChainFallbackCandidate> entryCandidates;

  /// 中转备用候选列表
  final List<ChainFallbackCandidate> relayCandidates;

  /// 落地出口备用候选列表
  final List<ChainFallbackCandidate> exitCandidates;

  const ChainFallbackPool({
    this.entryCandidates = const [],
    this.relayCandidates = const [],
    this.exitCandidates = const [],
  });

  bool get isEmpty =>
      entryCandidates.isEmpty &&
      relayCandidates.isEmpty &&
      exitCandidates.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int get totalCandidateCount =>
      entryCandidates.length + relayCandidates.length + exitCandidates.length;

  /// 根据角色获取对应候选列表
  List<ChainFallbackCandidate> getCandidatesByRole(FallbackCandidateRole role) {
    return switch (role) {
      FallbackCandidateRole.entry => List.unmodifiable(entryCandidates),
      FallbackCandidateRole.relay => List.unmodifiable(relayCandidates),
      FallbackCandidateRole.exit => List.unmodifiable(exitCandidates),
    };
  }

  ChainFallbackPool copyWith({
    List<ChainFallbackCandidate>? entryCandidates,
    List<ChainFallbackCandidate>? relayCandidates,
    List<ChainFallbackCandidate>? exitCandidates,
  }) {
    return ChainFallbackPool(
      entryCandidates: entryCandidates ?? this.entryCandidates,
      relayCandidates: relayCandidates ?? this.relayCandidates,
      exitCandidates: exitCandidates ?? this.exitCandidates,
    );
  }

  Map<String, dynamic> toJson({bool includeRuntimeState = false}) => {
    'entryCandidates': entryCandidates
        .map((e) => e.toJson(includeRuntimeState: includeRuntimeState))
        .toList(),
    'relayCandidates': relayCandidates
        .map((e) => e.toJson(includeRuntimeState: includeRuntimeState))
        .toList(),
    'exitCandidates': exitCandidates
        .map((e) => e.toJson(includeRuntimeState: includeRuntimeState))
        .toList(),
  };

  factory ChainFallbackPool.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ChainFallbackPool();

    List<ChainFallbackCandidate> parseList(
      dynamic raw,
      FallbackCandidateRole defaultRole,
    ) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((item) => ChainFallbackCandidate.fromJson(item))
          .toList();
    }

    return ChainFallbackPool(
      entryCandidates: parseList(
        json['entryCandidates'],
        FallbackCandidateRole.entry,
      ),
      relayCandidates: parseList(
        json['relayCandidates'],
        FallbackCandidateRole.relay,
      ),
      exitCandidates: parseList(
        json['exitCandidates'],
        FallbackCandidateRole.exit,
      ),
    );
  }
}

/// 候选节点排除记录（诊断用）
class CandidateExclusionRecord {
  final ChainFallbackCandidate candidate;
  final String reasonCode;
  final String message;

  const CandidateExclusionRecord({
    required this.candidate,
    required this.reasonCode,
    required this.message,
  });

  @override
  String toString() => '${candidate.nodeName}: [$reasonCode] $message';
}

/// 候选节点选举与过滤结果
class CandidateSelectionResult {
  final FallbackCandidateRole role;
  final ChainFallbackCandidate? selected;
  final List<ChainFallbackCandidate> rankedCandidates;
  final List<CandidateExclusionRecord> excluded;
  final String explanation;

  const CandidateSelectionResult({
    required this.role,
    this.selected,
    this.rankedCandidates = const [],
    this.excluded = const [],
    required this.explanation,
  });

  bool get hasCandidate => selected != null;
  String? get selectedNodeName => selected?.nodeName;
}

/// 备用故障转移 Session 状态
enum FallbackSessionStatus {
  idle,
  selecting,
  candidateFound,
  noCandidateAvailable,
  aborted,
}

/// 备用故障转移轻量会话对象（为 Phase 3.2-C 对接预留）
class FallbackSession {
  final String sessionId;
  final FallbackCandidateRole role;
  final String currentNode;
  final int candidateIndex;
  final List<ChainFallbackCandidate> candidateList;
  final DateTime startedAt;
  final FallbackSessionStatus status;
  final String? note;

  const FallbackSession({
    required this.sessionId,
    required this.role,
    required this.currentNode,
    this.candidateIndex = 0,
    this.candidateList = const [],
    required this.startedAt,
    this.status = FallbackSessionStatus.idle,
    this.note,
  });

  ChainFallbackCandidate? get currentCandidate {
    if (candidateIndex >= 0 && candidateIndex < candidateList.length) {
      return candidateList[candidateIndex];
    }
    return null;
  }

  FallbackSession copyWith({
    String? sessionId,
    FallbackCandidateRole? role,
    String? currentNode,
    int? candidateIndex,
    List<ChainFallbackCandidate>? candidateList,
    DateTime? startedAt,
    FallbackSessionStatus? status,
    String? note,
  }) {
    return FallbackSession(
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      currentNode: currentNode ?? this.currentNode,
      candidateIndex: candidateIndex ?? this.candidateIndex,
      candidateList: candidateList ?? this.candidateList,
      startedAt: startedAt ?? this.startedAt,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}
