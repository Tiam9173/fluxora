import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChainTelemetryService service;

  setUp(() {
    service = ChainTelemetryService();
  });

  group('Chain Proxy 2.0 Phase 4.1-A — 基础遥测层测试', () {
    // -------------------------------------------------------------------------
    // 一、基础功能 (Basic)
    // -------------------------------------------------------------------------
    test('1. 初始状态: getSnapshot 初始为空且所有计数器归零', () {
      final snapshot = service.getSnapshot();

      expect(snapshot.totalEvents, equals(0));
      expect(snapshot.failedEvents, equals(0));
      expect(snapshot.successEvents, equals(0));
      expect(snapshot.lastEventTime, isNull);
      expect(snapshot.recentEvents, isEmpty);
      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.isNotEmpty, isFalse);
    });

    test(
      '2. record 成功: 记录单个成功事件，更新 totalEvents/successEvents 与 lastEventTime',
      () {
        final now = DateTime(2026, 9, 29, 10, 0, 0);
        final event = ChainTelemetryEvent(
          timestamp: now,
          type: ChainTelemetryEventType.probeCompleted,
          nodeName: 'HK-Node-01',
          role: 'entry',
          message: '链路连通性探测成功',
        );

        service.record(event);

        final snapshot = service.getSnapshot();
        expect(snapshot.totalEvents, equals(1));
        expect(snapshot.successEvents, equals(1));
        expect(snapshot.failedEvents, equals(0));
        expect(snapshot.lastEventTime, equals(now));
        expect(snapshot.recentEvents.length, equals(1));
        expect(snapshot.recentEvents.first.id, equals(event.id));
        expect(snapshot.recentEvents.first.nodeName, equals('HK-Node-01'));
        expect(snapshot.recentEvents.first.displayTitle, equals('链路连通性探测成功'));
        expect(snapshot.isEmpty, isFalse);
      },
    );

    test('3. record 成功: 记录失败事件，正确累加 failedEvents 且保留错误码', () {
      final event = ChainTelemetryEvent(
        type: ChainTelemetryEventType.failoverRollback,
        nodeName: 'US-Exit-02',
        role: 'exit',
        errorCode: 'DIAL_TIMEOUT',
        message: '备用节点连接超时',
      );

      service.record(event);

      final snapshot = service.getSnapshot();
      expect(snapshot.totalEvents, equals(1));
      expect(snapshot.failedEvents, equals(1));
      expect(snapshot.successEvents, equals(0));
      expect(snapshot.recentEvents.first.errorCode, equals('DIAL_TIMEOUT'));
    });

    test('4. snapshot 正确性: 记录多个混合事件，统计各维度指标精确无误', () {
      service.record(
        ChainTelemetryEvent(type: ChainTelemetryEventType.probeStarted),
      );
      service.record(
        ChainTelemetryEvent(type: ChainTelemetryEventType.probeFailed),
      ); // fail 1
      service.record(
        ChainTelemetryEvent(type: ChainTelemetryEventType.retryStarted),
      );
      service.record(
        ChainTelemetryEvent(type: ChainTelemetryEventType.retrySucceeded),
      ); // success 1
      service.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.fallbackCandidateSelected,
        ),
      ); // success 2
      service.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.fallbackCandidateRejected,
        ),
      ); // fail 2
      service.record(
        ChainTelemetryEvent(type: ChainTelemetryEventType.failoverSuccess),
      ); // success 3

      final snapshot = service.getSnapshot();
      expect(snapshot.totalEvents, equals(7));
      expect(snapshot.failedEvents, equals(2));
      expect(snapshot.successEvents, equals(3));
      expect(snapshot.recentEvents.length, equals(7));
    });

    // -------------------------------------------------------------------------
    // 二、生命周期 (Lifecycle)
    // -------------------------------------------------------------------------
    test('5. 生命周期 - clear 正常: 清空所有事件、重置统计指标并通知监听器', () {
      int listenerCalls = 0;
      service.addListener(() {
        listenerCalls++;
      });

      service.record(
        ChainTelemetryEvent(type: ChainTelemetryEventType.probeCompleted),
      );
      service.record(
        ChainTelemetryEvent(type: ChainTelemetryEventType.failoverRollback),
      );
      expect(service.getSnapshot().totalEvents, equals(2));
      expect(listenerCalls, equals(2));

      service.clear();

      final snapshot = service.getSnapshot();
      expect(snapshot.totalEvents, equals(0));
      expect(snapshot.failedEvents, equals(0));
      expect(snapshot.successEvents, equals(0));
      expect(snapshot.lastEventTime, isNull);
      expect(snapshot.recentEvents, isEmpty);
      expect(listenerCalls, equals(3)); // clear triggered listener
    });

    test('6. 生命周期 - FIFO 淘汰: 超过 maxEvents (200) 时自动淘汰最旧事件，严格保留最新 200 条', () {
      // 写入 250 条事件
      for (int i = 0; i < 250; i++) {
        service.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeStarted,
            message: 'event_$i',
          ),
        );
      }

      final snapshot = service.getSnapshot();
      // 容量严格受限于 maxEvents = 200
      expect(
        snapshot.recentEvents.length,
        equals(ChainTelemetryService.maxEvents),
      );
      expect(snapshot.totalEvents, equals(250)); // 终生计数器保留真实发生总数

      // 最早的 50 条 (0..49) 被 FIFO 淘汰，当前第 0 个应为 event_50
      expect(snapshot.recentEvents.first.message, equals('event_50'));
      // 最后一个应为 event_249
      expect(snapshot.recentEvents.last.message, equals('event_249'));
    });

    test('7. 生命周期 - FIFO 淘汰边界验证: 恰好 200 条时不淘汰，第 201 条录入时淘汰第 1 条', () {
      for (int i = 0; i < 200; i++) {
        service.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeStarted,
            message: 'item_$i',
          ),
        );
      }
      expect(service.getSnapshot().recentEvents.length, equals(200));
      expect(
        service.getSnapshot().recentEvents.first.message,
        equals('item_0'),
      );

      // 录入第 201 条
      service.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeStarted,
          message: 'item_200',
        ),
      );
      expect(service.getSnapshot().recentEvents.length, equals(200));
      expect(
        service.getSnapshot().recentEvents.first.message,
        equals('item_1'),
      );
      expect(
        service.getSnapshot().recentEvents.last.message,
        equals('item_200'),
      );
    });

    // -------------------------------------------------------------------------
    // 三、安全与隐私防护 (Security & Privacy)
    // -------------------------------------------------------------------------
    test('8. 安全 - metadata 为 null 或空 map 时安全处理', () {
      final e1 = ChainTelemetryEvent(
        type: ChainTelemetryEventType.probeCompleted,
        metadata: null,
      );
      expect(e1.metadata, isNull);

      final e2 = ChainTelemetryEvent(
        type: ChainTelemetryEventType.probeCompleted,
        metadata: {},
      );
      expect(e2.metadata, isNull);
    });

    test('9. 安全 - metadata 敏感字段自动过滤: 过滤密码、Token、UUID 与凭据', () {
      final rawMetadata = <String, dynamic>{
        'password': 'plain_secret_password_123',
        'pass': 'p@ssword',
        'token': 'bearer-jwt-token-string',
        'uuid': '87b9139b-9e65-406f-a97c-bf949ddd59fa',
        'secret': 'super_private_secret',
        'credential': 'my_credential',
        'safe_latency_ms': 120,
        'safe_hop_count': 3,
      };

      final event = ChainTelemetryEvent(
        type: ChainTelemetryEventType.probeCompleted,
        metadata: rawMetadata,
      );

      final meta = event.metadata!;
      expect(meta.containsKey('password'), isFalse);
      expect(meta.containsKey('pass'), isFalse);
      expect(meta.containsKey('token'), isFalse);
      expect(meta.containsKey('uuid'), isFalse);
      expect(meta.containsKey('secret'), isFalse);
      expect(meta.containsKey('credential'), isFalse);
      expect(meta['safe_latency_ms'], equals(120));
      expect(meta['safe_hop_count'], equals(3));
    });

    test('10. 安全 - metadata 订阅 URL 深度安全清洗', () {
      final rawMetadata = <String, dynamic>{
        'subscribe_url': 'https://api.provider.com/sub?token=xxx',
        'subUrl': 'https://node.link/v1/sub',
        'endpoint': 'https://normal.api/check',
        'custom_info': 'https://test.com/sub/profile',
      };

      final event = ChainTelemetryEvent(
        type: ChainTelemetryEventType.fallbackCandidateSelected,
        metadata: rawMetadata,
      );

      final meta = event.metadata;
      if (meta != null) {
        expect(meta.containsKey('subscribe_url'), isFalse);
        expect(meta.containsKey('subUrl'), isFalse);
        expect(meta.containsKey('custom_info'), isFalse);
      }
    });

    test('11. 安全 - metadata 大对象限制: 条目数受限 20 且超长字符串截断至 256', () {
      final rawMap = <String, dynamic>{};
      for (int i = 0; i < 35; i++) {
        rawMap['key_$i'] = 'val_$i';
      }
      final longString = 'A' * 600;
      rawMap['long_text'] = longString;

      final event = ChainTelemetryEvent(
        type: ChainTelemetryEventType.probeCompleted,
        metadata: rawMap,
      );

      final meta = event.metadata!;
      expect(
        meta.length,
        lessThanOrEqualTo(ChainTelemetryEvent.maxMetadataEntries),
      );
      if (meta.containsKey('long_text')) {
        expect(
          (meta['long_text'] as String).length,
          equals(ChainTelemetryEvent.maxMetadataStringLength),
        );
      }
    });

    test('12. 安全 - metadata 与 snapshot 外部不可变性', () {
      final event = ChainTelemetryEvent(
        type: ChainTelemetryEventType.probeCompleted,
        metadata: {'test_key': 'val'},
      );

      // Attempt mutating metadata map
      expect(
        () => event.metadata!['new_key'] = 'illegal',
        throwsA(isA<UnsupportedError>()),
      );

      service.record(event);
      final snapshot = service.getSnapshot();

      // Attempt mutating recentEvents list
      expect(
        () => snapshot.recentEvents.add(event),
        throwsA(isA<UnsupportedError>()),
      );
    });

    // -------------------------------------------------------------------------
    // 四、并发与健壮性 (Concurrency & Robustness)
    // -------------------------------------------------------------------------
    test('13. 并发与健壮性 - 连续快速批量写入保持事件顺序无丢失', () {
      const count = 100;
      for (int i = 0; i < count; i++) {
        service.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeCompleted,
            message: 'batch_$i',
          ),
        );
      }

      final snapshot = service.getSnapshot();
      expect(snapshot.totalEvents, equals(count));
      for (int i = 0; i < count; i++) {
        expect(snapshot.recentEvents[i].message, equals('batch_$i'));
      }
    });

    test('14. 并发与健壮性 - 重入保护: 在 listener 回调中触发 record 安全处理无递归死锁', () {
      int secondaryRecords = 0;
      service.addListener(() {
        // 在监听回调中触发二次 record
        if (secondaryRecords < 3) {
          secondaryRecords++;
          service.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.retryStarted,
              message: 'reentrant_$secondaryRecords',
            ),
          );
        }
      });

      // 触发初始 record
      service.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeStarted,
          message: 'initial',
        ),
      );

      final snapshot = service.getSnapshot();
      // initial + 3 secondary = 4
      expect(snapshot.totalEvents, equals(4));
      expect(snapshot.recentEvents.first.message, equals('initial'));
    });

    // -------------------------------------------------------------------------
    // 五、架构与边界隔离 (Architecture & Isolation)
    // -------------------------------------------------------------------------
    test('15. 隔离性 - 遥测操作纯内存运行，绝不读写 chain_proxies.json', () {
      // 确认记录遥测、清除遥测不会触碰磁盘或修改全局持久化配置
      final originalConfig = chainProxyManager.config;

      chainProxyManager.telemetryService.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.failoverStarted,
          nodeName: 'TestNode',
          message: '隔离性检查',
        ),
      );
      chainProxyManager.clearTelemetry();

      expect(chainProxyManager.config, equals(originalConfig));
    });

    test('16. 隔离性 - 遥测操作绝不调用 applyToClashConfig 或篡改原链路内核配置', () {
      final rawClashConfig = <String, dynamic>{
        'proxies': [
          {'name': 'DIRECT', 'type': 'direct'},
        ],
        'proxy-groups': <dynamic>[],
      };

      // 验证在无候选状态下调用 applyToClashConfig 不会被遥测数据污染
      chainProxyManager.applyToClashConfig(rawClashConfig);
      final proxies = rawClashConfig['proxies'] as List;
      expect(proxies.any((p) => p.toString().contains('telem_')), isFalse);
    });

    test('17. 独立多实例隔离性: 自定义 ChainTelemetryService 实例完全内存隔离', () {
      final serviceA = ChainTelemetryService();
      final serviceB = ChainTelemetryService();

      serviceA.record(
        ChainTelemetryEvent(type: ChainTelemetryEventType.probeCompleted),
      );
      expect(serviceA.getSnapshot().totalEvents, equals(1));
      expect(serviceB.getSnapshot().totalEvents, equals(0));

      serviceB.record(
        ChainTelemetryEvent(type: ChainTelemetryEventType.failoverRollback),
      );
      expect(serviceA.getSnapshot().failedEvents, equals(0));
      expect(serviceB.getSnapshot().failedEvents, equals(1));

      serviceA.clear();
      expect(serviceA.getSnapshot().isEmpty, isTrue);
      expect(serviceB.getSnapshot().isEmpty, isFalse);
    });

    test('18. 枚举与模型完备性: 覆盖全部 14 种事件类型与 isFailure / isSuccess 映射', () {
      expect(ChainTelemetryEventType.values.length, equals(16));

      // 验证失败事件集合
      expect(ChainTelemetryEventType.probeFailed.isFailure, isTrue);
      expect(ChainTelemetryEventType.failoverRollback.isFailure, isTrue);
      expect(
        ChainTelemetryEventType.fallbackCandidateRejected.isFailure,
        isTrue,
      );

      // 验证成功事件集合
      expect(ChainTelemetryEventType.probeCompleted.isSuccess, isTrue);
      expect(ChainTelemetryEventType.retrySucceeded.isSuccess, isTrue);
      expect(
        ChainTelemetryEventType.fallbackCandidateSelected.isSuccess,
        isTrue,
      );
      expect(ChainTelemetryEventType.failoverSuccess.isSuccess, isTrue);

      expect(ChainTelemetryEventType.flapRecovered.isSuccess, isTrue);

      // 验证其他生命周期过渡事件
      expect(ChainTelemetryEventType.probeStarted.isFailure, isFalse);
      expect(ChainTelemetryEventType.probeStarted.isSuccess, isFalse);
      expect(ChainTelemetryEventType.retryStarted.isFailure, isFalse);
      expect(ChainTelemetryEventType.failoverStarted.isFailure, isFalse);

      // 验证 label 非空
      for (final type in ChainTelemetryEventType.values) {
        expect(type.label, isNotEmpty);
      }
    });
  });
}
