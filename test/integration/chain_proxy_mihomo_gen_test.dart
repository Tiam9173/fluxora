import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_proxy.dart';

void main() {
  group('Chain Proxy 2.0 Mihomo 配置注入与影子节点生成集成测试', () {
    late Map<String, dynamic> sampleConfig;

    setUp(() {
      sampleConfig = {
        'proxies': [
          {
            'name': 'HK-01',
            'type': 'ss',
            'server': '1.1.1.1',
            'port': 8388,
            'cipher': 'aes-256-gcm',
            'password': 'pass',
          },
          {
            'name': 'SG-01',
            'type': 'trojan',
            'server': '2.2.2.2',
            'port': 443,
            'password': 'pass',
            'sni': 'sg.example.com',
          },
          {
            'name': 'US-01',
            'type': 'vmess',
            'server': '3.3.3.3',
            'port': 443,
            'uuid': 'uuid-us',
            'alterId': 0,
            'cipher': 'auto',
          },
        ],
        'proxy-groups': [
          {
            'name': 'GLOBAL',
            'type': 'select',
            'proxies': ['HK-01', 'SG-01', 'US-01', 'DIRECT'],
          },
          {
            'name': 'PROXY',
            'type': 'select',
            'proxies': ['HK-01', 'SG-01', 'US-01'],
          },
        ],
        'rules': ['MATCH,PROXY'],
      };
    });

    test('TC-GEN-01: 两跳模式影子出口节点生成与级联 dialer-proxy', () {
      const config = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'HK-01',
        hop2Node: 'SG-01',
        createDedicatedGroup: true,
        dedicatedGroupName: '🔗 链式代理',
      );

      config.applyToClashConfig(sampleConfig);

      final proxies = (sampleConfig['proxies'] as List)
          .cast<Map<String, dynamic>>();

      // 1. Original HK-01 and SG-01 must not have dialer-proxy modified in-place!
      final origHk = proxies.firstWhere((p) => p['name'] == 'HK-01');
      final origSg = proxies.firstWhere((p) => p['name'] == 'SG-01');
      expect(origHk.containsKey('dialer-proxy'), isFalse);
      expect(origSg.containsKey('dialer-proxy'), isFalse);

      // 2. Shadow exit node must be generated
      final shadowExit = proxies.firstWhere((p) => p['name'] == '🔗出口·SG-01');
      expect(shadowExit['type'], equals('trojan'));
      expect(shadowExit['server'], equals('2.2.2.2'));
      expect(shadowExit['dialer-proxy'], equals('HK-01'));

      // 3. Dedicated group contains shadow exit node
      final groups = (sampleConfig['proxy-groups'] as List)
          .cast<Map<String, dynamic>>();
      final chainGroup = groups.firstWhere((g) => g['name'] == '🔗 链式代理');
      expect(chainGroup['type'], equals('select'));
      final groupProxies = chainGroup['proxies'] as List;
      expect(groupProxies, contains('🔗出口·SG-01'));
      expect(groupProxies, contains('DIRECT'));
    });

    test('TC-GEN-02: 三跳模式双影子节点级联编排与策略组隔离', () {
      const config = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-01',
        hop2Node: 'SG-01',
        hop3Node: 'US-01',
        createDedicatedGroup: true,
        dedicatedGroupName: '🔗 链式代理',
      );

      config.applyToClashConfig(sampleConfig);

      final proxies = (sampleConfig['proxies'] as List)
          .cast<Map<String, dynamic>>();

      // 1. Original nodes remain untouched!
      final origHk = proxies.firstWhere((p) => p['name'] == 'HK-01');
      final origSg = proxies.firstWhere((p) => p['name'] == 'SG-01');
      final origUs = proxies.firstWhere((p) => p['name'] == 'US-01');
      expect(origHk.containsKey('dialer-proxy'), isFalse);
      expect(origSg.containsKey('dialer-proxy'), isFalse);
      expect(origUs.containsKey('dialer-proxy'), isFalse);

      // 2. Shadow transit node (Hop 2 dials Hop 1)
      final shadowTransit = proxies.firstWhere(
        (p) => p['name'] == '🔗中转·SG-01',
      );
      expect(shadowTransit['type'], equals('trojan'));
      expect(shadowTransit['dialer-proxy'], equals('HK-01'));

      // 3. Shadow exit node (Hop 3 dials Shadow Transit)
      final shadowExit = proxies.firstWhere((p) => p['name'] == '🔗出口·US-01');
      expect(shadowExit['type'], equals('vmess'));
      expect(shadowExit['dialer-proxy'], equals('🔗中转·SG-01'));

      // 4. Dedicated group contains only shadow exit node and DIRECT
      final groups = (sampleConfig['proxy-groups'] as List)
          .cast<Map<String, dynamic>>();
      final chainGroup = groups.firstWhere((g) => g['name'] == '🔗 链式代理');
      final groupProxies = chainGroup['proxies'] as List;
      expect(groupProxies, contains('🔗出口·US-01'));
      expect(
        groupProxies,
        isNot(contains('🔗中转·SG-01')),
      ); // Intermediate transit must not be an exit option
      expect(groupProxies, contains('DIRECT'));
    });

    test('TC-GEN-03: STUN/TURN WebRTC 防泄漏拦截规则置顶注入', () {
      const config = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'HK-01',
        hop2Node: 'SG-01',
        preventWebRtcLeak: true,
      );

      config.applyToClashConfig(sampleConfig);

      final rules = (sampleConfig['rules'] as List).cast<String>();
      expect(rules.first, equals('DOMAIN-KEYWORD,stun,REJECT'));
      expect(rules.contains('DST-PORT,3478,REJECT'), isTrue);
      expect(rules.contains('DST-PORT,19302,REJECT'), isTrue);
      expect(rules.last, equals('MATCH,PROXY'));
    });

    test('TC-CLEAN-01: 停用链式代理时彻底清除所有影子节点与专属组 (Zero Residue Teardown)', () {
      // First, apply 3-hop config
      const activeConfig = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.threeHop,
        hop1Node: 'HK-01',
        hop2Node: 'SG-01',
        hop3Node: 'US-01',
      );
      activeConfig.applyToClashConfig(sampleConfig);

      // Verify shadow nodes exist
      var proxies = (sampleConfig['proxies'] as List)
          .cast<Map<String, dynamic>>();
      expect(proxies.any((p) => p['name'] == '🔗中转·SG-01'), isTrue);
      expect(proxies.any((p) => p['name'] == '🔗出口·US-01'), isTrue);

      // Now, disable chain proxy
      const disabledConfig = ChainProxyConfig(enable: false);
      disabledConfig.applyToClashConfig(sampleConfig);

      proxies = (sampleConfig['proxies'] as List).cast<Map<String, dynamic>>();
      // Assert all shadow nodes are completely purged
      expect(
        proxies.any((p) => p['name'].toString().startsWith('🔗中转·')),
        isFalse,
      );
      expect(
        proxies.any((p) => p['name'].toString().startsWith('🔗出口·')),
        isFalse,
      );

      final groups = (sampleConfig['proxy-groups'] as List)
          .cast<Map<String, dynamic>>();
      expect(groups.any((g) => g['name'] == '🔗 链式代理'), isFalse);
      expect(groups.any((g) => g['name'] == '✈️ 链式跳板'), isFalse);
    });

    test('TC-DAG-GUARD: 环路拓扑在 applyToClashConfig 阶段自动拒绝生成', () {
      // Intentionally configure a cycle: Hop 1 = HK-01, Hop 2 = HK-01
      const cyclicConfig = ChainProxyConfig(
        enable: true,
        hopMode: ChainHopMode.twoHop,
        hop1Node: 'HK-01',
        hop2Node: 'HK-01',
      );

      cyclicConfig.applyToClashConfig(sampleConfig);

      final proxies = (sampleConfig['proxies'] as List)
          .cast<Map<String, dynamic>>();
      // Since it is cyclic, no shadow nodes should be injected
      expect(
        proxies.any((p) => p['name'].toString().startsWith('🔗出口·')),
        isFalse,
      );
    });
  });
}
