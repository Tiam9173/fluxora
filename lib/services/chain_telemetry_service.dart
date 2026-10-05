import 'package:flutter/foundation.dart';
import 'package:fluxora/models/chain_telemetry.dart';

/// 链式代理遥测服务接口
abstract class IChainTelemetryService {
  /// 记录一条遥测事件
  void record(ChainTelemetryEvent event);

  /// 获取当前遥测统计与近期事件快照 (纯内存，只读)
  ChainTelemetrySnapshot getSnapshot();

  /// 清空所有内存中的遥测统计与事件记录
  void clear();

  /// 注册状态变化监听器
  void addListener(VoidCallback listener);

  /// 移除状态变化监听器
  void removeListener(VoidCallback listener);
}

/// 链式代理遥测服务实现 (纯内存，严格容量控制与防重入设计)
class ChainTelemetryService implements IChainTelemetryService {
  /// 最大保留的历史事件条数 (FIFO 淘汰)
  static const int maxEvents = 200;

  final ObserverList<VoidCallback> _listeners = ObserverList<VoidCallback>();
  final List<ChainTelemetryEvent> _events = [];
  final List<ChainTelemetryEvent> _pendingQueue = [];

  int _totalEvents = 0;
  int _failedEvents = 0;
  int _successEvents = 0;
  DateTime? _lastEventTime;

  bool _isProcessing = false;
  bool _isNotifying = false;

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  bool _hasPendingNotifications = false;

  void _notifyListeners() {
    if (_isNotifying) {
      _hasPendingNotifications = true;
      return;
    }
    _isNotifying = true;
    try {
      do {
        _hasPendingNotifications = false;
        final listenersCopy = List<VoidCallback>.from(_listeners);
        for (final listener in listenersCopy) {
          try {
            listener();
          } catch (_) {}
        }
      } while (_hasPendingNotifications);
    } finally {
      _isNotifying = false;
    }
  }

  @override
  void record(ChainTelemetryEvent event) {
    // 线程/重入安全保护：如果正在处理事件，入队等待批量排空，防止递归死锁或列表并发修改
    if (_isProcessing) {
      _pendingQueue.add(event);
      return;
    }

    _isProcessing = true;
    try {
      _processEvent(event);
      while (_pendingQueue.isNotEmpty) {
        final next = _pendingQueue.removeAt(0);
        _processEvent(next);
      }
    } finally {
      _isProcessing = false;
    }

    _notifyListeners();
  }

  void _processEvent(ChainTelemetryEvent event) {
    _events.add(event);
    _totalEvents++;
    if (event.type.isFailure) {
      _failedEvents++;
    } else if (event.type.isSuccess) {
      _successEvents++;
    }
    _lastEventTime = event.timestamp;

    // 严格限制事件历史容量，防止内存无限制增长
    while (_events.length > maxEvents) {
      _events.removeAt(0);
    }
  }

  @override
  ChainTelemetrySnapshot getSnapshot() {
    return ChainTelemetrySnapshot(
      totalEvents: _totalEvents,
      failedEvents: _failedEvents,
      successEvents: _successEvents,
      lastEventTime: _lastEventTime,
      recentEvents: List.unmodifiable(_events),
    );
  }

  @override
  void clear() {
    _events.clear();
    _pendingQueue.clear();
    _totalEvents = 0;
    _failedEvents = 0;
    _successEvents = 0;
    _lastEventTime = null;
    _notifyListeners();
  }
}

/// 全局单例遥测服务
final chainTelemetryService = ChainTelemetryService();
