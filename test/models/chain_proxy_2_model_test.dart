import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_proxy.dart';

void main() {
  group('Chain Proxy 2.0 数据模型与序列化测试', () {
    test('TC-MOD-01: 兼容反序列化 v1.0.2 旧版配置 (默认回退至两跳模式)', () {
      final legacyJson = {
        'enable': true,
        'defaultDialerProxy': 'HK-BGP-01',
        'autoInjectGroups': true,
        'createDedicatedGroup': true,
        'dedicatedGroupName': '🔗 链式代理',
        'preventWebRtcLeak': true,
        'landingProxies': [
          {
            'id': 'uuid-1',
            'name': '住宅IP-1.2.3.4:1080',
            'protocol': 'socks5',
            'server': '1.2.3.4',
            'port': 1080,
            'username': 'user1',
            'password': 'pass1',
            'enable': true,
          },
        ],
      };

      final config = ChainProxyConfig.fromJson(legacyJson);

      expect(config.enable, isTrue);
      expect(config.hopMode, equals(ChainHopMode.twoHop));
      expect(config.defaultDialerProxy, equals('HK-BGP-01'));
      expect(config.hop1Node, equals('HK-BGP-01'));
      expect(config.effectiveHop1, equals('HK-BGP-01'));
      expect(config.hop2Node, isEmpty);
      expect(config.effectiveExitNode, equals('住宅IP-1.2.3.4:1080'));
      expect(config.landingProxies.length, equals(1));
    });

    test('TC-MOD-02: 三跳模式完整模型序列化与反序列化 (Round-trip Fidelity)', () {
      const config = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'Entry-HK-01',
        hop2Node: 'Transit-SG-01',
        hop3Node: 'Exit-US-01',
        createDedicatedGroup: true,
        dedicatedGroupName: '🔗 极速三跳链',
        preventWebRtcLeak: true,
      );

      expect(config.effectiveHop1, equals('Entry-HK-01'));
      expect(config.effectiveExitNode, equals('Exit-US-01'));

      final json = config.toJson();
      expect(json['hopMode'], equals('threeHop'));
      expect(json['hop1Node'], equals('Entry-HK-01'));
      expect(json['hop2Node'], equals('Transit-SG-01'));
      expect(json['hop3Node'], equals('Exit-US-01'));
      expect(json['dedicatedGroupName'], equals('🔗 极速三跳链'));

      final restored = ChainProxyConfig.fromJson(json);
      expect(restored.hopMode, equals(ChainHopMode.threeHop));
      expect(restored.hop1Node, equals('Entry-HK-01'));
      expect(restored.hop2Node, equals('Transit-SG-01'));
      expect(restored.hop3Node, equals('Exit-US-01'));
      expect(restored.dedicatedGroupName, equals('🔗 极速三跳链'));
      expect(restored.effectiveHop1, equals('Entry-HK-01'));
      expect(restored.effectiveExitNode, equals('Exit-US-01'));
    });

    test('TC-MOD-03: copyWith 保持不可变性与正确赋值', () {
      const initial = ChainProxyConfig(
        enable: false,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'NodeA',
        hop2Node: 'NodeB',
      );

      final updated = initial.copyWith(
        enable: true,
        hopMode: ChainHopMode.threeHop,
        hop3Node: 'NodeC',
      );

      expect(initial.enable, isFalse);
      expect(initial.hopMode, equals(ChainHopMode.twoHop));
      expect(initial.hop3Node, isEmpty);

      expect(updated.enable, isTrue);
      expect(updated.hopMode, equals(ChainHopMode.threeHop));
      expect(updated.hop1Node, equals('NodeA'));
      expect(updated.hop2Node, equals('NodeB'));
      expect(updated.hop3Node, equals('NodeC'));
      expect(updated.effectiveExitNode, equals('NodeC'));
    });

    test('TC-MOD-04: 影子节点名称辅助方法测试', () {
      expect(ChainProxyConfig.transitShadowName('SG-01'), equals('🔗中转·SG-01'));
      expect(ChainProxyConfig.exitShadowName('US-01'), equals('🔗出口·US-01'));
      expect(ChainProxyConfig.isShadowNodeName('🔗中转·SG-01'), isTrue);
      expect(ChainProxyConfig.isShadowNodeName('🔗出口·US-01'), isTrue);
      expect(ChainProxyConfig.isShadowNodeName('HK-BGP-01'), isFalse);
      expect(ChainProxyConfig.isShadowNodeName('DIRECT'), isFalse);
    });
  });
}
