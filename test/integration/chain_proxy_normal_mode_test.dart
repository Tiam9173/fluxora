import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_proxy.dart';

void main() {
  group('Chain Proxy 2.0 普通代理模式零回归保障测试 (Zero-Regression)', () {
    late Map<String, dynamic> rawConfig;
    late String originalConfigJson;

    setUp(() {
      rawConfig = {
        'proxies': [
          {
            'name': 'Node-A',
            'type': 'ss',
            'server': '10.0.0.1',
            'port': 1001,
            'cipher': 'aes-128-gcm',
            'password': 'pwd',
          },
          {
            'name': 'Node-B',
            'type': 'trojan',
            'server': '10.0.0.2',
            'port': 1002,
            'password': 'pwd',
          },
        ],
        'proxy-groups': [
          {
            'name': 'PROXY',
            'type': 'select',
            'proxies': ['Node-A', 'Node-B'],
          },
          {
            'name': 'AUTO',
            'type': 'url-test',
            'proxies': ['Node-A', 'Node-B'],
            'url': 'http://www.gstatic.com/generate_204',
            'interval': 300,
          },
        ],
        'rules': ['DOMAIN-SUFFIX,google.com,PROXY', 'MATCH,DIRECT'],
      };
      originalConfigJson = jsonEncode(rawConfig);
    });

    test('TC-REG-01: 全局关闭状态下 applyToClashConfig 不污染原始代理与策略组', () {
      const config = ChainProxyConfig(
        enable: false,
        preventWebRtcLeak: false, // Pure zero-modification check
      );

      config.applyToClashConfig(rawConfig);

      // JSON output should be completely identical to original
      expect(jsonEncode(rawConfig), equals(originalConfigJson));
    });

    test('TC-REG-02: 开启链式代理时，普通订阅节点的原有分流与参数不受影响', () {
      const config = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'Node-A',
        hop2Node: 'Node-B',
        preventWebRtcLeak: false,
        createDedicatedGroup: true,
      );

      config.applyToClashConfig(rawConfig);

      final proxies = (rawConfig['proxies'] as List)
          .cast<Map<String, dynamic>>();

      // Node-A and Node-B must still exist with exact original parameters
      final nodeA = proxies.firstWhere((p) => p['name'] == 'Node-A');
      final nodeB = proxies.firstWhere((p) => p['name'] == 'Node-B');

      expect(nodeA['server'], equals('10.0.0.1'));
      expect(nodeA['port'], equals(1001));
      expect(nodeA.containsKey('dialer-proxy'), isFalse);

      expect(nodeB['server'], equals('10.0.0.2'));
      expect(nodeB['port'], equals(1002));
      expect(nodeB.containsKey('dialer-proxy'), isFalse);

      // Existing AUTO group must still have Node-A and Node-B
      final groups = (rawConfig['proxy-groups'] as List)
          .cast<Map<String, dynamic>>();
      final autoGroup = groups.firstWhere((g) => g['name'] == 'AUTO');
      expect((autoGroup['proxies'] as List).contains('Node-A'), isTrue);
      expect((autoGroup['proxies'] as List).contains('Node-B'), isTrue);
    });
  });
}
