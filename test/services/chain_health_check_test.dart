import 'package:dio/dio.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/public_ip_info.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/public_ip_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chain Proxy 2.0 Phase 3.1 — 链路健康度检测与故障诊断 (25 项全场景测试)', () {
    // 1. initial state
    test('1. initial state: 初始状态验证 (无假延迟、无假IP、未检测状态)', () {
      final initial = ChainProbeReport.initial(ChainHopMode.twoHop);
      expect(initial.healthStatus, ChainHealthStatus.unknown);
      expect(initial.isOverallHealthy, isFalse);
      expect(initial.totalChainLatencyMs, isNull);
      expect(initial.hops, isEmpty);
      expect(initial.finalExit, isNull);
      expect(initial.rootCauseAnalysis, isNull);
      expect(initial.isCancelled, isFalse);
    });

    // 2. checking state
    test('2. checking state: 检测过程中实时进度回调包含 checking 状态', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Hop1',
        hop2Node: 'Hop2',
      );

      final progressReports = <ChainProbeReport>[];

      final service = ChainProbeService(
        customDelayTester: (node, url) async => 50,
        customExitIpDetector: () async => PublicIpInfo(
          ip: '1.2.3.4',
          version: IpVersion.v4,
          timestamp: DateTime.now(),
          source: 'mock',
        ),
      );

      final report = await service.probeChain(
        config: config,
        onProgress: (p) => progressReports.add(p),
      );

      expect(
        progressReports.any(
          (p) => p.healthStatus == ChainHealthStatus.checking,
        ),
        isTrue,
      );
      expect(report.healthStatus, ChainHealthStatus.healthy);
    });

    // 3. healthy state
    test('3. healthy state: 全跳正常且探测到出口IP，状态为 healthy', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Hop1',
        hop2Node: 'Hop2',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async => 30,
        customExitIpDetector: () async => PublicIpInfo(
          ip: '202.108.22.5',
          version: IpVersion.v4,
          country: 'China',
          countryCode: 'CN',
          timestamp: DateTime.now(),
          source: 'mock',
        ),
      );

      final report = await service.probeChain(config: config);

      expect(report.healthStatus, ChainHealthStatus.healthy);
      expect(report.isOverallHealthy, isTrue);
      expect(report.errorCode, ChainProbeErrorCodes.none);
      expect(report.finalExit?.observedPublicIp?.ip, '202.108.22.5');
      expect(report.finalExit?.ipStatus, IpObservationStatus.observed);
      expect(report.rootCauseAnalysis, isNull);
    });

    // 4. degraded state
    test(
      '4. degraded state: 传输层连通但公网 IP 服务失败，整体判定为 degraded 而非 failed',
      () async {
        final config = const ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.twoHop,
          hop1Node: 'Hop1',
          hop2Node: 'Hop2',
        );

        final mockIpService = PublicIpService(
          customFetcher: (url, {cancelToken, proxyPort = 0, timeout}) async {
            throw Exception('IP API Gateway Timeout');
          },
        );

        final service = ChainProbeService(
          ipService: mockIpService,
          customDelayTester: (node, url) async => 45,
        );

        final report = await service.probeChain(config: config);

        expect(report.healthStatus, ChainHealthStatus.degraded);
        expect(report.isOverallHealthy, isTrue); // 传输层畅通！
        expect(report.errorCode, ChainProbeErrorCodes.ipApiUnavailable);
        expect(report.finalExit?.ipStatus, IpObservationStatus.unavailable);
        expect(report.rootCauseAnalysis, contains('公网 IP 查询服务超时或不可用'));
      },
    );

    // 5. failed state
    test('5. failed state: 节点握手失败判定为 failed', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Dead-Node',
        hop2Node: 'Hop2',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async => -1,
      );

      final report = await service.probeChain(config: config);

      expect(report.healthStatus, ChainHealthStatus.failed);
      expect(report.isOverallHealthy, isFalse);
    });

    // 6. unavailable state
    test('6. unavailable state: 中间跳公网 IP 必须为 unavailable 且严禁伪造', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'Hop1',
        hop2Node: 'Hop2',
        hop3Node: 'Hop3',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async => 40,
        customExitIpDetector: () async => PublicIpInfo(
          ip: '8.8.8.8',
          version: IpVersion.v4,
          timestamp: DateTime.now(),
          source: 'mock',
        ),
      );

      final report = await service.probeChain(config: config);

      expect(report.hops[0].ipStatus, IpObservationStatus.unavailable);
      expect(report.hops[0].observedPublicIp, isNull);
      expect(report.hops[1].ipStatus, IpObservationStatus.unavailable);
      expect(report.hops[1].observedPublicIp, isNull);
      expect(report.finalExit?.observedPublicIp?.ip, '8.8.8.8');
    });

    // 7. Hop1 failure
    test(
      '7. Hop1 failure: 第一跳故障准确定位 failureHop=1 且后续跳标记为 UPSTREAM_FAILED',
      () async {
        final config = const ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.twoHop,
          hop1Node: 'Bad-Hop1',
          hop2Node: 'Good-Hop2',
        );

        final service = ChainProbeService(
          customDelayTester: (node, url) async {
            if (node == 'Bad-Hop1') return -1;
            return 50;
          },
        );

        final report = await service.probeChain(config: config);

        expect(report.failureHop, 1);
        expect(report.errorCode, ChainProbeErrorCodes.hop1Failed);
        expect(report.hops[0].healthStatus, ChainHealthStatus.failed);
        expect(report.hops[1].errorCode, ChainProbeErrorCodes.upstreamFailed);
        expect(report.rootCauseAnalysis, contains('第一跳 [Bad-Hop1] 连通失败'));
      },
    );

    // 8. Hop2 failure
    test('8. Hop2 failure: 第二跳故障准确定位 failureHop=2', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Good-Hop1',
        hop2Node: 'Bad-Hop2',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async {
          if (node == 'Good-Hop1') return 35;
          return -1;
        },
      );

      final report = await service.probeChain(config: config);

      expect(report.failureHop, 2);
      expect(report.errorCode, ChainProbeErrorCodes.exitFailed);
      expect(report.hops[0].healthStatus, ChainHealthStatus.healthy);
      expect(report.hops[1].healthStatus, ChainHealthStatus.failed);
    });

    // 9. Exit failure
    test('9. Exit failure: 三跳模式下最后一跳故障准确定位 failureHop=3', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'Hop1',
        hop2Node: 'Hop2',
        hop3Node: 'Bad-Exit',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async {
          if (node == 'Bad-Exit') return -1;
          return 40;
        },
      );

      final report = await service.probeChain(config: config);

      expect(report.failureHop, 3);
      expect(report.errorCode, ChainProbeErrorCodes.exitFailed);
      expect(report.hops[0].healthStatus, ChainHealthStatus.healthy);
      expect(report.hops[1].healthStatus, ChainHealthStatus.healthy);
      expect(report.hops[2].healthStatus, ChainHealthStatus.failed);
    });

    // 10. Internet probe failure
    test('10. Internet probe failure: 节点连通但出海探测超时', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Hop1',
        hop2Node: 'Hop2',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async {
          if (node == 'Hop2') return null; // Exit timeout to internet test URL
          return 50;
        },
      );

      final report = await service.probeChain(config: config);

      expect(report.healthStatus, ChainHealthStatus.failed);
      expect(report.errorCode, ChainProbeErrorCodes.exitTimeout);
    });

    // 11. IP API unavailable
    test('11. IP API unavailable: 公网 IP 源全部无法响应不导致整体判定为 FAILED', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Hop1',
        hop2Node: 'Hop2',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async => 50,
        customExitIpDetector: () async => null, // IP API returns null
      );

      final report = await service.probeChain(config: config);

      expect(report.healthStatus, ChainHealthStatus.degraded);
      expect(report.isOverallHealthy, isTrue);
      expect(report.finalExit?.observedPublicIp, isNull);
    });

    // 12. timeout
    test('12. timeout: 延迟测试返回 null 时正确映射为 TIMEOUT 错误码', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Timeout-Hop1',
        hop2Node: 'Hop2',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async => null,
      );

      final report = await service.probeChain(config: config);

      expect(report.errorCode, ChainProbeErrorCodes.hop1Timeout);
      expect(report.hops[0].status, HopProbeStatus.timeout);
      expect(report.hops[0].errorMessage, contains('连接超时'));
    });

    // 13. cancellation
    test(
      '13. cancellation: 使用 CancelToken 能够在检测中途安全取消并置为 cancelled 状态',
      () async {
        final config = const ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.twoHop,
          hop1Node: 'Hop1',
          hop2Node: 'Hop2',
        );

        final cancelToken = CancelToken();

        final service = ChainProbeService(
          customDelayTester: (node, url) async {
            cancelToken.cancel('User aborted');
            return 50;
          },
        );

        final report = await service.probeChain(
          config: config,
          cancelToken: cancelToken,
        );

        expect(report.isCancelled, isTrue);
        expect(report.healthStatus, ChainHealthStatus.cancelled);
        expect(report.errorCode, ChainProbeErrorCodes.cancelled);
      },
    );

    // 14. topology invalid
    test('14. topology invalid: 自环/重复跳等非法拓扑立即中断并返回 TOPOLOGY_INVALID', () async {
      final invalidConfig = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Same-Node',
        hop2Node: 'Same-Node',
      );

      final service = ChainProbeService();
      final report = await service.probeChain(config: invalidConfig);

      expect(report.healthStatus, ChainHealthStatus.failed);
      expect(report.errorCode, ChainProbeErrorCodes.topologyInvalid);
      expect(report.rootCauseAnalysis, contains('链路拓扑非法'));
      expect(report.hops, isEmpty);
    });

    // 15. twoHop health
    test('15. twoHop health: 两跳链路完整数据结构和模型解析', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Entry-HK',
        hop2Node: 'Exit-US',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async => 60,
        customExitIpDetector: () async => PublicIpInfo(
          ip: '104.28.1.1',
          version: IpVersion.v4,
          countryCode: 'US',
          timestamp: DateTime.now(),
          source: 'mock',
        ),
      );

      final report = await service.probeChain(config: config);

      expect(report.mode, ChainHopMode.twoHop);
      expect(report.hops.length, 2);
      expect(report.hops[0].role, HopRole.hop1Entry);
      expect(report.hops[1].role, HopRole.hop2Exit);
      expect(report.finalExit?.role, HopRole.finalExit);
      expect(report.healthStatus, ChainHealthStatus.healthy);
    });

    // 16. threeHop health
    test('16. threeHop health: 三跳链路完整数据结构和模型解析', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'Entry-HK',
        hop2Node: 'Relay-JP',
        hop3Node: 'Exit-SG',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async => 80,
        customExitIpDetector: () async => PublicIpInfo(
          ip: '118.27.1.1',
          version: IpVersion.v4,
          countryCode: 'SG',
          timestamp: DateTime.now(),
          source: 'mock',
        ),
      );

      final report = await service.probeChain(config: config);

      expect(report.mode, ChainHopMode.threeHop);
      expect(report.hops.length, 3);
      expect(report.hops[0].role, HopRole.hop1Entry);
      expect(report.hops[1].role, HopRole.hop2Relay);
      expect(report.hops[2].role, HopRole.hop3Exit);
      expect(report.healthStatus, ChainHealthStatus.healthy);
    });

    // 17. latency available
    test('17. latency available: 准确记录测量得到的真实延迟', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'HK',
        hop2Node: 'US',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async {
          if (node == 'HK') return 25;
          if (node == 'US') return 145;
          return null;
        },
      );

      final report = await service.probeChain(
        config: config,
        checkExitPublicIp: false,
      );

      expect(report.hops[0].latencyMs, 25);
      expect(report.hops[1].latencyMs, 145);
      expect(report.totalChainLatencyMs, 145);
    });

    // 18. latency unavailable
    test(
      '18. latency unavailable: 探测失败或超时时延迟必须为 null，绝不伪造 0 或 100ms',
      () async {
        final config = const ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.twoHop,
          hop1Node: 'Timeout-Node',
          hop2Node: 'Hop2',
        );

        final service = ChainProbeService(
          customDelayTester: (node, url) async => null,
        );

        final report = await service.probeChain(config: config);

        expect(report.hops[0].latencyMs, isNull);
        expect(report.totalChainLatencyMs, isNull);
      },
    );

    // 19. no fake IP
    test('19. no fake IP: 中间跳 observedPublicIp 始终为 null', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK',
        hop2Node: 'JP',
        hop3Node: 'US',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async => 50,
        customExitIpDetector: () async => PublicIpInfo(
          ip: '23.45.67.89',
          version: IpVersion.v4,
          timestamp: DateTime.now(),
          source: 'mock',
        ),
      );

      final report = await service.probeChain(config: config);

      expect(report.hops[0].observedPublicIp, isNull);
      expect(report.hops[1].observedPublicIp, isNull);
      expect(report.hops[2].observedPublicIp, isNull);
      expect(report.finalExit?.observedPublicIp?.ip, '23.45.67.89');
    });

    // 20. no fake latency
    test('20. no fake latency: 后续中断跳延迟为 null', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-Failed',
        hop2Node: 'JP',
        hop3Node: 'US',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async {
          if (node == 'HK-Failed') return -1;
          return 100;
        },
      );

      final report = await service.probeChain(config: config);

      expect(report.hops[1].latencyMs, isNull);
      expect(report.hops[2].latencyMs, isNull);
    });

    // 21. original node unchanged
    test('21. original node unchanged: 健康探测不会修改原始 ChainProxyConfig', () async {
      final config = const ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Original-Hop1',
        hop2Node: 'Original-Hop2',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async => 40,
      );

      await service.probeChain(config: config);

      expect(config.hop1Node, 'Original-Hop1');
      expect(config.hop2Node, 'Original-Hop2');
      expect(config.enable, isTrue);
    });

    // 22. normal proxy unaffected
    test('22. normal proxy unaffected: 独立探针不影响普通代理配置', () async {
      final service = ChainProbeService(
        customDelayTester: (node, url) async => 55,
      );

      final report = await service.probeChain(
        config: const ChainProxyConfig(hop1Node: 'NodeA', hop2Node: 'NodeB'),
      );

      expect(report.hops[0].nodeName, 'NodeA');
      expect(report.hops[1].nodeName, 'NodeB');
    });

    // 23. Chain Proxy disabled unaffected
    test('23. Chain Proxy disabled unaffected: 在未启用状态下探测不产生副作用', () async {
      final disabledConfig = const ChainProxyConfig(
        enable: false,
        hop1Node: 'Node1',
        hop2Node: 'Node2',
      );

      final service = ChainProbeService(
        customDelayTester: (node, url) async => 30,
      );

      final report = await service.probeChain(config: disabledConfig);

      expect(report.isOverallHealthy, isTrue);
      expect(disabledConfig.enable, isFalse);
    });

    // 24. repeated health checks do not accumulate state
    test(
      '24. repeated health checks do not accumulate state: 多次调用无状态累积或内存残留',
      () async {
        final config = const ChainProxyConfig(
          hop1Node: 'Hop1',
          hop2Node: 'Hop2',
        );

        final service = ChainProbeService(
          customDelayTester: (node, url) async => 40,
        );

        final report1 = await service.probeChain(
          config: config,
          checkExitPublicIp: false,
        );
        final report2 = await service.probeChain(
          config: config,
          checkExitPublicIp: false,
        );

        expect(report1.hops.length, 2);
        expect(report2.hops.length, 2);
        expect(identical(report1, report2), isFalse);
      },
    );

    // 25. dispose/cancel cleanup
    test('25. dispose/cancel cleanup: cancelled 工厂方法生成干净的取消报告', () {
      final cancelledReport = ChainProbeReport.cancelled(
        mode: ChainHopMode.twoHop,
        timestamp: DateTime.now(),
      );

      expect(cancelledReport.isCancelled, isTrue);
      expect(cancelledReport.healthStatus, ChainHealthStatus.cancelled);
      expect(cancelledReport.errorCode, ChainProbeErrorCodes.cancelled);
      expect(cancelledReport.rootCauseAnalysis, contains('取消'));
    });
  });
}
