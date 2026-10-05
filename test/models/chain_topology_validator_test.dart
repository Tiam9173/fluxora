import 'dart:convert';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChainTopologyValidator 节点拓扑与防环校验测试', () {
    const availableNodes = [
      'HK-01',
      'HK-02',
      'JP-01',
      'JP-02',
      'US-01',
      'SG-01',
    ];

    test('1. 两跳正常配置通过校验', () {
      final res = ChainTopologyValidator.validate(
        mode: ChainHopMode.twoHop,
        hop1: 'HK-01',
        hop2: 'JP-01',
        availableProxyNames: availableNodes,
      );

      expect(res.isValid, isTrue);
      expect(res.errorCode, 'NONE');
      expect(res.affectedHop, isNull);
    });

    test('2. 三跳正常配置通过校验', () {
      final res = ChainTopologyValidator.validate(
        mode: ChainHopMode.threeHop,
        hop1: 'HK-01',
        hop2: 'SG-01',
        hop3: 'US-01',
        availableProxyNames: availableNodes,
      );

      expect(res.isValid, isTrue);
      expect(res.errorCode, 'NONE');
    });

    test('3. Hop1 == Hop2 拒绝并返回 DUPLICATE_HOP', () {
      final res = ChainTopologyValidator.validate(
        mode: ChainHopMode.twoHop,
        hop1: 'HK-01',
        hop2: 'HK-01',
        availableProxyNames: availableNodes,
      );

      expect(res.isValid, isFalse);
      expect(res.errorCode, 'DUPLICATE_HOP');
      expect(res.affectedHop, 2);
      expect(res.message, contains('第一跳与第二跳不能使用同一个节点'));
    });

    test('4. Hop1 == Hop3 拒绝并返回 DUPLICATE_HOP', () {
      final res = ChainTopologyValidator.validate(
        mode: ChainHopMode.threeHop,
        hop1: 'HK-01',
        hop2: 'SG-01',
        hop3: 'HK-01',
        availableProxyNames: availableNodes,
      );

      expect(res.isValid, isFalse);
      expect(res.errorCode, 'DUPLICATE_HOP');
      expect(res.affectedHop, 3);
      expect(res.message, contains('第一跳与第三跳不能使用同一个节点'));
    });

    test('5. Hop2 == Hop3 拒绝并返回 DUPLICATE_HOP', () {
      final res = ChainTopologyValidator.validate(
        mode: ChainHopMode.threeHop,
        hop1: 'HK-01',
        hop2: 'JP-01',
        hop3: 'JP-01',
        availableProxyNames: availableNodes,
      );

      expect(res.isValid, isFalse);
      expect(res.errorCode, 'DUPLICATE_HOP');
      expect(res.affectedHop, 3);
      expect(res.message, contains('第二跳与第三跳不能使用同一个节点'));
    });

    test('6. 空节点拒绝并指示相应 Hop', () {
      final resHop1 = ChainTopologyValidator.validate(
        mode: ChainHopMode.twoHop,
        hop1: '',
        hop2: 'JP-01',
      );
      expect(resHop1.isValid, isFalse);
      expect(resHop1.errorCode, 'EMPTY_HOP');
      expect(resHop1.affectedHop, 1);

      final resHop2 = ChainTopologyValidator.validate(
        mode: ChainHopMode.twoHop,
        hop1: 'HK-01',
        hop2: '   ',
      );
      expect(resHop2.isValid, isFalse);
      expect(resHop2.errorCode, 'EMPTY_HOP');
      expect(resHop2.affectedHop, 2);

      final resHop3 = ChainTopologyValidator.validate(
        mode: ChainHopMode.threeHop,
        hop1: 'HK-01',
        hop2: 'JP-01',
        hop3: null,
      );
      expect(resHop3.isValid, isFalse);
      expect(resHop3.errorCode, 'EMPTY_HOP');
      expect(resHop3.affectedHop, 3);
    });

    test('7. 不存在节点检测', () {
      final res = ChainTopologyValidator.validate(
        mode: ChainHopMode.twoHop,
        hop1: 'NON_EXISTENT_NODE',
        hop2: 'JP-01',
        availableProxyNames: availableNodes,
      );

      expect(res.isValid, isFalse);
      expect(res.errorCode, 'NODE_NOT_FOUND');
      expect(res.affectedHop, 1);
      expect(res.message, contains('不存在于当前可用代理列表'));
    });

    test('8. 引用自身链式组或系统保留组 (Self-Reference)', () {
      final resDedicated = ChainTopologyValidator.validate(
        mode: ChainHopMode.twoHop,
        hop1: '🔗 链式代理',
        hop2: 'JP-01',
      );
      expect(resDedicated.isValid, isFalse);
      expect(resDedicated.errorCode, 'SELF_REFERENCE');
      expect(resDedicated.affectedHop, 1);

      final resGlobal = ChainTopologyValidator.validate(
        mode: ChainHopMode.twoHop,
        hop1: 'HK-01',
        hop2: 'GLOBAL',
      );
      expect(resGlobal.isValid, isFalse);
      expect(resGlobal.errorCode, 'SELF_REFERENCE');
      expect(resGlobal.affectedHop, 2);
    });

    test('9. 复杂环路与循环引用检测 (DAG DFS Cycle Detection)', () {
      // 场景：Hop 2 指向 Hop 1，同时外部 dialerProxyMap 中 Hop 1 又回指 Hop 2
      final dialers = {
        'HK-01': 'JP-01', // HK-01 尝试通过 JP-01 拨号
      };

      final res = ChainTopologyValidator.validate(
        mode: ChainHopMode.twoHop,
        hop1: 'HK-01',
        hop2: 'JP-01', // JP-01 尝试通过 HK-01 拨号
        dialerProxyMap: dialers,
      );

      expect(res.isValid, isFalse);
      expect(res.errorCode, 'CIRCULAR_DEPENDENCY');
      expect(res.message, contains('检测到循环代理依赖'));
    });

    test('10. 旧配置兼容性测试 (Legacy Config Compatibility)', () {
      // 旧版仅有 defaultDialerProxy 和 landingProxies
      const legacyJson = '''
      {
        "enable": true,
        "defaultDialerProxy": "HK-Legacy",
        "landingProxies": [
          {
            "id": "landing-1",
            "name": "JP-Landing",
            "server": "1.2.3.4",
            "port": 1080
          }
        ]
      }
      ''';

      final config = ChainProxyConfig.fromJson(
        json.decode(legacyJson) as Map<String, dynamic>,
      );

      expect(config.enable, isTrue);
      expect(config.hopMode, ChainHopMode.twoHop);
      expect(config.defaultDialerProxy, 'HK-Legacy');
      expect(config.effectiveHop1, 'HK-Legacy');
      expect(config.landingProxies.length, 1);
      expect(config.landingProxies.first.name, 'JP-Landing');
      expect(config.effectiveExitNode, 'JP-Landing');

      // 验证拓扑校验器能平滑校验旧配置映射
      final val = ChainTopologyValidator.validate(
        mode: config.hopMode,
        hop1: config.effectiveHop1,
        hop2: config.effectiveExitNode,
      );
      expect(val.isValid, isTrue);
    });
  });
}
