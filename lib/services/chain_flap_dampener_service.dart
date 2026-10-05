import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_flap_dampening.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';

/// 链式代理抖动抑制服务接口
abstract class IChainFlapDampenerService {
  /// 获取当前实时抖动状态快照 (纯内存)
  ChainFlapDampenerStatus get status;

  /// 获取指定时间与策略下的抖动状态快照 (便于单元测试确定性时间评估)
  ChainFlapDampenerStatus getStatus({
    DateTime? now,
    ChainFlapDampeningPolicy? policy,
  });

  /// 评估当前是否允许发起故障转移 (非侵入式判断，不记录事件)
  ChainFlapVerdict evaluate({DateTime? now, ChainFlapDampeningPolicy? policy});

  /// 记录一次链路切流事件并更新内部惩罚分与抑制状态
  void recordFlap({
    required FallbackCandidateRole role,
    required String fromNode,
    required String toNode,
    String? reason,
    bool isSuccess = true,
    DateTime? timestamp,
    ChainFlapDampeningPolicy? policy,
  });

  /// 手动重置所有抖动积分、历史与抑制状态
  void reset();

  /// 注册状态变化监听器
  void addListener(VoidCallback listener);

  /// 移除状态变化监听器
  void removeListener(VoidCallback listener);
}

/// 链式代理抖动抑制服务实现
class ChainFlapDampenerService implements IChainFlapDampenerService {
  final ObserverList<VoidCallback> _listeners = ObserverList<VoidCallback>();

  double _penalty = 0.0;
  DateTime? _lastPenaltyCalculationTime;
  DateTime? _lastFlapTime;
  bool _isSuppressed = false;
  DateTime? _suppressedUntil;
  String? _suppressReason;
  final List<ChainFlapEvent> _events = [];

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      try {
        listener();
      } catch (_) {}
    }
  }

  /// 纯内存读取当前状态快照
  @override
  ChainFlapDampenerStatus get status => getStatus();

  @override
  ChainFlapDampenerStatus getStatus({
    DateTime? now,
    ChainFlapDampeningPolicy? policy,
  }) {
    final t = now ?? DateTime.now();
    final p = policy ?? const ChainFlapDampeningPolicy();
    _decayPenalty(t, p);
    _checkUnsuppress(t, p);

    final wStart = t.subtract(p.windowDuration);
    final count = _events
        .where((e) => e.isSuccess && !e.timestamp.isBefore(wStart))
        .length;

    Duration? remaining;
    if (_isSuppressed && _suppressedUntil != null) {
      final diff = _suppressedUntil!.difference(t);
      remaining = diff.isNegative ? Duration.zero : diff;
    } else if (_lastFlapTime != null) {
      final sinceLast = t.difference(_lastFlapTime!);
      if (sinceLast < p.minSwitchInterval) {
        remaining = p.minSwitchInterval - sinceLast;
      }
    }

    return ChainFlapDampenerStatus(
      isSuppressed: _isSuppressed,
      currentPenalty: _penalty,
      flapCountInWindow: count,
      lastFlapTime: _lastFlapTime,
      suppressedUntil: _suppressedUntil,
      remainingCooldown: remaining,
      reason: _suppressReason,
      recentEvents: List.unmodifiable(_events),
    );
  }

  @override
  ChainFlapVerdict evaluate({DateTime? now, ChainFlapDampeningPolicy? policy}) {
    final t = now ?? DateTime.now();
    final p = policy ?? const ChainFlapDampeningPolicy();

    if (!p.enabled) {
      return ChainFlapVerdict.allowed(penalty: 0.0);
    }

    // 1. 指数衰减积分
    _decayPenalty(t, p);

    // 2. 检查抑制解除
    _checkUnsuppress(t, p);

    // 3. 处于抑制状态中
    if (_isSuppressed) {
      final remaining = _suppressedUntil != null
          ? _suppressedUntil!.difference(t)
          : Duration.zero;
      final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
      return ChainFlapVerdict.dampened(
        penalty: _penalty,
        remainingCooldown: safeRemaining,
        suppressedUntil: _suppressedUntil,
        reason:
            _suppressReason ??
            '抖动惩罚分超出阈值 (当前分值 ${_penalty.toStringAsFixed(0)} >= 抑制阈值 ${p.suppressThreshold.toStringAsFixed(0)})',
      );
    }

    // 4. 检查两次故障转移最小冷却时间
    if (_lastFlapTime != null) {
      final sinceLast = t.difference(_lastFlapTime!);
      if (sinceLast < p.minSwitchInterval) {
        final remaining = p.minSwitchInterval - sinceLast;
        final seconds = (remaining.inMilliseconds / 1000.0).toStringAsFixed(1);
        return ChainFlapVerdict.dampened(
          penalty: _penalty,
          remainingCooldown: remaining,
          reason: '切流冷却中 (需等待 $seconds 秒以防连接抖动)',
        );
      }
    }

    return ChainFlapVerdict.allowed(penalty: _penalty);
  }

  @override
  void recordFlap({
    required FallbackCandidateRole role,
    required String fromNode,
    required String toNode,
    String? reason,
    bool isSuccess = true,
    DateTime? timestamp,
    ChainFlapDampeningPolicy? policy,
  }) {
    final t = timestamp ?? DateTime.now();
    final p = policy ?? const ChainFlapDampeningPolicy();

    // 1. 记录切流事件
    final event = ChainFlapEvent(
      timestamp: t,
      role: role,
      fromNode: fromNode,
      toNode: toNode,
      reason: reason,
      isSuccess: isSuccess,
    );
    _events.add(event);

    // 限制历史数量，严格防止无界内存增长
    while (_events.length > p.maxHistoryEvents) {
      _events.removeAt(0);
    }

    _lastFlapTime = t;

    if (!p.enabled) {
      _notifyListeners();
      return;
    }

    // 2. 衰减历史积分并累加新惩罚分
    _decayPenalty(t, p);
    _penalty += p.penaltyPerFlap;
    _lastPenaltyCalculationTime = t;

    // 3. 统计滑动窗口内频次
    final wStart = t.subtract(p.windowDuration);
    final flapsInWindow = _events
        .where((e) => e.isSuccess && !e.timestamp.isBefore(wStart))
        .length;

    // 4. 判定是否触发抑制
    bool shouldSuppress = false;
    String? triggerReason;

    if (_penalty >= p.suppressThreshold) {
      shouldSuppress = true;
      triggerReason =
          '抖动惩罚分超出阈值 (当前 ${_penalty.toStringAsFixed(0)} >= 阈值 ${p.suppressThreshold.toStringAsFixed(0)})';
    } else if (flapsInWindow >= p.maxFlapsInWindow) {
      shouldSuppress = true;
      triggerReason =
          '滑动窗口内切换过频 (${p.windowDuration.inSeconds}秒内发生 $flapsInWindow 次切换 >= 上限 ${p.maxFlapsInWindow})';
    }

    if (shouldSuppress) {
      final wasSuppressed = _isSuppressed;
      _isSuppressed = true;
      _suppressReason = triggerReason;

      // 计算自然衰减至 reuseThreshold 所需的时间
      // T = H * ln(_penalty / reuseThreshold) / ln(2)
      double suppressSecs = 0.0;
      if (p.reuseThreshold > 0 && _penalty > p.reuseThreshold) {
        final ratio = _penalty / p.reuseThreshold;
        final halfLifeSecs = p.halfLife.inMilliseconds / 1000.0;
        suppressSecs = halfLifeSecs * (math.log(ratio) / math.ln2);
      } else {
        suppressSecs = p.minSwitchInterval.inSeconds.toDouble();
      }

      // 上限受限于 maxSuppressDuration，下限受限于 minSwitchInterval
      final maxSecs = p.maxSuppressDuration.inMilliseconds / 1000.0;
      final minSecs = p.minSwitchInterval.inMilliseconds / 1000.0;
      suppressSecs = math.min(suppressSecs, maxSecs);
      suppressSecs = math.max(suppressSecs, minSecs);

      final suppressDuration = Duration(
        milliseconds: (suppressSecs * 1000).round(),
      );
      final candidateUntil = t.add(suppressDuration);

      if (_suppressedUntil == null ||
          candidateUntil.isAfter(_suppressedUntil!)) {
        _suppressedUntil = candidateUntil;
      }

      if (!wasSuppressed) {
        chainTelemetryService.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.flapSuppressed,
            role: role.name,
            message: '触发抖动抑制保护: $triggerReason',
            metadata: {
              'penalty': double.parse(_penalty.toStringAsFixed(2)),
              'suppressedUntil': _suppressedUntil?.toIso8601String(),
            },
          ),
        );
      }
    }

    _notifyListeners();
  }

  @override
  void reset() {
    _penalty = 0.0;
    _lastPenaltyCalculationTime = null;
    _lastFlapTime = null;
    _isSuppressed = false;
    _suppressedUntil = null;
    _suppressReason = null;
    _events.clear();
    _notifyListeners();
  }

  /// 指数衰减积分计算公式: S(t) = S0 * (0.5) ^ ((t - t0) / HalfLife)
  void _decayPenalty(DateTime now, ChainFlapDampeningPolicy policy) {
    if (_lastPenaltyCalculationTime == null) {
      _lastPenaltyCalculationTime = now;
      return;
    }

    if (now.isBefore(_lastPenaltyCalculationTime!)) {
      // 时钟回拨保护
      return;
    }

    final deltaMs = now.difference(_lastPenaltyCalculationTime!).inMilliseconds;
    final halfLifeMs = policy.halfLife.inMilliseconds;

    if (halfLifeMs <= 0 || deltaMs <= 0) {
      _lastPenaltyCalculationTime = now;
      return;
    }

    final double factor = math.pow(0.5, deltaMs / halfLifeMs).toDouble();
    _penalty = _penalty * factor;

    if (_penalty < 0.001) {
      _penalty = 0.0;
    }

    _lastPenaltyCalculationTime = now;
  }

  /// 检查是否满足解禁条件 (超时解禁或分值衰减至解禁阈值以下)
  void _checkUnsuppress(DateTime now, ChainFlapDampeningPolicy policy) {
    if (!_isSuppressed) return;

    bool canRelease = false;
    if (_suppressedUntil != null && now.isAfter(_suppressedUntil!)) {
      canRelease = true;
    } else if (_penalty <= policy.reuseThreshold) {
      // 仅当滑动窗口内频次已下降至阈值以下时，才允许基于积分衰减提前解禁
      final wStart = now.subtract(policy.windowDuration);
      final count = _events
          .where((e) => e.isSuccess && !e.timestamp.isBefore(wStart))
          .length;
      if (count < policy.maxFlapsInWindow) {
        canRelease = true;
      }
    }

    if (canRelease) {
      final wasSuppressed = _isSuppressed;
      _isSuppressed = false;
      _suppressedUntil = null;
      _suppressReason = null;

      if (wasSuppressed) {
        chainTelemetryService.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.flapRecovered,
            role: 'system',
            message: '抖动抑制保护已自然解除，链路稳定性评估恢复',
            metadata: {'penalty': double.parse(_penalty.toStringAsFixed(2))},
          ),
        );
      }
    }
  }
}

final chainFlapDampenerService = ChainFlapDampenerService();
