import 'package:flutter/foundation.dart';

/// 链式代理遥测事件类型
enum ChainTelemetryEventType {
  // Probe events
  probeStarted,
  probeCompleted,
  probeFailed,

  // Retry events
  retryStarted,
  retryBackoff,
  retrySucceeded,
  retryFailed,

  // Fallback events
  fallbackEvaluationStarted,
  fallbackCandidateSelected,
  fallbackCandidateRejected,

  // Failover events
  failoverStarted,
  failoverCandidateApplied,
  failoverSuccess,
  failoverRollback,

  // Flap events
  flapSuppressed,
  flapRecovered,
}

/// 遥测事件类型属性扩展
extension ChainTelemetryEventTypeX on ChainTelemetryEventType {
  String get label {
    return switch (this) {
      ChainTelemetryEventType.probeStarted => '探测开始',
      ChainTelemetryEventType.probeCompleted => '探测完成',
      ChainTelemetryEventType.probeFailed => '探测失败',

      ChainTelemetryEventType.retryStarted => '重试开始',
      ChainTelemetryEventType.retryBackoff => '重试退避',
      ChainTelemetryEventType.retrySucceeded => '重试成功',
      ChainTelemetryEventType.retryFailed => '重试失败',

      ChainTelemetryEventType.fallbackEvaluationStarted => '候选评估开始',
      ChainTelemetryEventType.fallbackCandidateSelected => '候选优选',
      ChainTelemetryEventType.fallbackCandidateRejected => '候选拒绝',

      ChainTelemetryEventType.failoverStarted => '故障转移开始',
      ChainTelemetryEventType.failoverCandidateApplied => '候选应用',
      ChainTelemetryEventType.failoverSuccess => '故障转移成功',
      ChainTelemetryEventType.failoverRollback => '链路回滚',

      ChainTelemetryEventType.flapSuppressed => '抖动抑制触发',
      ChainTelemetryEventType.flapRecovered => '抖动抑制解除',
    };
  }

  /// 判定该事件是否代表故障或异常
  bool get isFailure {
    return this == ChainTelemetryEventType.probeFailed ||
        this == ChainTelemetryEventType.retryFailed ||
        this == ChainTelemetryEventType.fallbackCandidateRejected ||
        this == ChainTelemetryEventType.failoverRollback ||
        this == ChainTelemetryEventType.flapSuppressed;
  }

  /// 判定该事件是否代表成功
  bool get isSuccess {
    return this == ChainTelemetryEventType.probeCompleted ||
        this == ChainTelemetryEventType.retrySucceeded ||
        this == ChainTelemetryEventType.fallbackCandidateSelected ||
        this == ChainTelemetryEventType.failoverSuccess ||
        this == ChainTelemetryEventType.flapRecovered;
  }
}

/// 单条链式代理遥测事件 (纯内存轻量结构，严禁存储敏感隐私)
@immutable
class ChainTelemetryEvent {
  static int _idCounter = 0;

  static String _generateId() {
    _idCounter++;
    final timePart = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final countPart = _idCounter.toRadixString(36);
    return 'telem_${timePart}_$countPart';
  }

  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    if (lower == 'password' ||
        lower == 'pass' ||
        lower == 'pwd' ||
        lower == 'secret' ||
        lower == 'token' ||
        lower == 'uuid' ||
        lower == 'uid' ||
        lower == 'credential' ||
        lower == 'credentials' ||
        lower == 'auth' ||
        lower == 'key') {
      return true;
    }
    if (lower.contains('password') ||
        lower.contains('secret') ||
        lower.contains('token') ||
        lower.contains('uuid') ||
        lower.contains('credential') ||
        lower.contains('sub_url') ||
        lower.contains('subscribe_url') ||
        lower.contains('suburl') ||
        lower.contains('subscription_url') ||
        lower.contains('api_key') ||
        lower.contains('private_key') ||
        lower.contains('auth_key')) {
      return true;
    }
    return false;
  }

  static const int maxMetadataEntries = 20;
  static const int maxMetadataStringLength = 256;

  /// 安全清洗 metadata，剔除密码、Token、UUID、订阅地址等隐私，并限制条目与字段长度
  static Map<String, dynamic>? sanitizeMetadata(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return null;

    final sanitized = <String, dynamic>{};
    int count = 0;
    for (final entry in raw.entries) {
      if (count >= maxMetadataEntries) break;
      final key = entry.key.trim();
      if (_isSensitiveKey(key)) {
        continue;
      }
      dynamic val = entry.value;
      if (val is String) {
        if (val.length > maxMetadataStringLength) {
          val = val.substring(0, maxMetadataStringLength);
        }
        // 过滤疑似包含订阅链接或认证串的值
        final lower = val.toLowerCase();
        if ((lower.contains('http://') || lower.contains('https://')) &&
            (lower.contains('sub') ||
                lower.contains('token') ||
                lower.contains('uuid'))) {
          continue;
        }
      }
      sanitized[key] = val;
      count++;
    }

    if (sanitized.isEmpty) return null;
    return Map.unmodifiable(sanitized);
  }

  final String id;
  final DateTime timestamp;
  final ChainTelemetryEventType type;
  final String? nodeName;
  final String? role;
  final String? errorCode;
  final String? message;
  final Map<String, dynamic>? metadata;

  ChainTelemetryEvent({
    String? id,
    DateTime? timestamp,
    required this.type,
    this.nodeName,
    this.role,
    this.errorCode,
    this.message,
    Map<String, dynamic>? metadata,
  }) : id = id ?? _generateId(),
       timestamp = timestamp ?? DateTime.now(),
       metadata = sanitizeMetadata(metadata);

  /// 友好的展示标题
  String get displayTitle {
    if (message != null && message!.isNotEmpty) {
      return message!;
    }
    final target = nodeName != null && nodeName!.isNotEmpty
        ? ' [$nodeName]'
        : '';
    final roleStr = role != null && role!.isNotEmpty ? ' ($role)' : '';
    return '${type.label}$target$roleStr';
  }

  @override
  String toString() =>
      'ChainTelemetryEvent($id, $type, node: $nodeName, role: $role, msg: $message, time: $timestamp)';
}

/// 遥测快照 (纯内存，供 UI 与状态层只读观测)
@immutable
class ChainTelemetrySnapshot {
  final int totalEvents;
  final int failedEvents;
  final int successEvents;
  final DateTime? lastEventTime;
  final List<ChainTelemetryEvent> recentEvents;

  const ChainTelemetrySnapshot({
    required this.totalEvents,
    required this.failedEvents,
    required this.successEvents,
    this.lastEventTime,
    this.recentEvents = const [],
  });

  factory ChainTelemetrySnapshot.empty() => const ChainTelemetrySnapshot(
    totalEvents: 0,
    failedEvents: 0,
    successEvents: 0,
    lastEventTime: null,
    recentEvents: [],
  );

  bool get isEmpty => totalEvents == 0;
  bool get isNotEmpty => totalEvents > 0;
}
