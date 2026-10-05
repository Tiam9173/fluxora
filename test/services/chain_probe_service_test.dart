import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/public_ip_info.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChainProbeService 链式代理逐跳诊断与定界测试', () {
    test('1. 两跳全链路畅通 (Healthy) 且正确测得出口真实 IP', () async {
      final config = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'HK-Transit',
        hop2Node: 'JP-Landing',
      );

      final service = ChainProbeService(
        customDelayTester: (proxyName, testUrl) async {
          if (proxyName == 'HK-Transit') return 35;
          if (proxyName == 'JP-Landing') return 80;
          return null;
        },
        customExitIpDetector: () async {
          return PublicIpInfo(
            ip: '133.159.2.88',
            version: IpVersion.v4,
            country: 'Japan',
            countryCode: 'JP',
            city: 'Tokyo',
            isp: 'SoftBank Corp.',
            timestamp: DateTime.now(),
            source: 'test-mock',
          );
        },
      );

      final report = await service.probeChain(config: config);

      expect(report.isOverallHealthy, isTrue);
      expect(report.totalChainLatencyMs, 80);
      expect(report.hops.length, 2);

      // 第一跳验证
      final hop1 = report.hops[0];
      expect(hop1.nodeName, 'HK-Transit');
      expect(hop1.status, HopProbeStatus.healthy);
      expect(hop1.latencyMs, 35);
      // 严格验证：第一跳绝不能复制出口 IP
      expect(hop1.observedPublicIp, isNull);
      expect(hop1.ipStatus, IpObservationStatus.unavailable);

      // 第二跳验证
      final hop2 = report.hops[1];
      expect(hop2.nodeName, 'JP-Landing');
      expect(hop2.status, HopProbeStatus.healthy);
      expect(hop2.latencyMs, 80);
      expect(hop2.observedPublicIp, isNull);

      // 全链路出口验证
      expect(report.finalExit, isNotNull);
      expect(report.finalExit!.status, HopProbeStatus.healthy);
      expect(report.finalExit!.observedPublicIp, isNotNull);
      expect(report.finalExit!.observedPublicIp!.ip, '133.159.2.88');
      expect(report.finalExit!.ipStatus, IpObservationStatus.observed);
      expect(report.rootCauseAnalysis, isNull);
    });

    test('2. 三跳全链路畅通与逐跳状态', () async {
      final config = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'Entry-US',
        hop2Node: 'Relay-SG',
        hop3Node: 'Exit-JP',
      );

      final service = ChainProbeService(
        customDelayTester: (proxyName, testUrl) async {
          if (proxyName == 'Entry-US') return 120;
          if (proxyName == 'Relay-SG') return 190;
          if (proxyName == 'Exit-JP') return 240;
          return null;
        },
        customExitIpDetector: () async {
          return PublicIpInfo(
            ip: '150.95.1.1',
            version: IpVersion.v4,
            countryCode: 'JP',
            timestamp: DateTime.now(),
            source: 'test-mock',
          );
        },
      );

      final report = await service.probeChain(config: config);

      expect(report.isOverallHealthy, isTrue);
      expect(report.hops.length, 3);
      expect(report.hops[0].latencyMs, 120);
      expect(report.hops[1].latencyMs, 190);
      expect(report.hops[2].latencyMs, 240);
      expect(report.finalExit!.observedPublicIp!.ip, '150.95.1.1');
    });

    test('3. 第一跳即中断 (Failed & Root Cause Analysis)', () async {
      final config = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Dead-Hop1',
        hop2Node: 'JP-Landing',
      );

      final service = ChainProbeService(
        customDelayTester: (proxyName, testUrl) async {
          // 第一跳返回 0 或 -1 表示握手失败
          if (proxyName == 'Dead-Hop1') return -1;
          return null;
        },
      );

      final report = await service.probeChain(config: config);

      expect(report.isOverallHealthy, isFalse);
      expect(report.hops[0].status, HopProbeStatus.failed);
      expect(report.hops[1].status, HopProbeStatus.failed);
      expect(report.rootCauseAnalysis, contains('第一跳 [Dead-Hop1] 连通失败'));
      expect(report.finalExit!.status, HopProbeStatus.failed);
      expect(report.finalExit!.observedPublicIp, isNull);
    });

    test('4. 第一跳正常但第二跳超时 (Timeout)', () async {
      final config = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'OK-Hop1',
        hop2Node: 'Timeout-Hop2',
      );

      final service = ChainProbeService(
        customDelayTester: (proxyName, testUrl) async {
          if (proxyName == 'OK-Hop1') return 50;
          if (proxyName == 'Timeout-Hop2') return null; // null 表示超时无响应
          return null;
        },
      );

      final report = await service.probeChain(config: config);

      expect(report.isOverallHealthy, isFalse);
      expect(report.hops[0].status, HopProbeStatus.healthy);
      expect(report.hops[1].status, HopProbeStatus.timeout);
      expect(report.rootCauseAnalysis, contains('第二跳落地节点 [Timeout-Hop2] 握手失败'));
    });

    test('5. 拓扑非法时拒绝探测并直接输出诊断', () async {
      final invalidConfig = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Same-Node',
        hop2Node: 'Same-Node', // 自引用重复
      );

      final service = ChainProbeService();
      final report = await service.probeChain(config: invalidConfig);

      expect(report.isOverallHealthy, isFalse);
      expect(report.hops, isEmpty);
      expect(report.rootCauseAnalysis, contains('链路拓扑非法: 第一跳与第二跳不能使用同一个节点'));
    });
  });
}
