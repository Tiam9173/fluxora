import 'package:fluxora/models/manual_proxy_helper.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「清理不可用配置」的可见行为取决于**真正删掉了几个节点**，而不是"传进来
/// 几个名字"。`deleteProxiesFromProfile` 有多条把原 profile 原样返回的早退
/// 路径（文件不存在 / YAML 解析失败 / `proxies` 不是列表），旧代码不看这些，
/// 删完照样报「已删除 N 个」——用户看到的就是"点了没反应，提示却说删了"。
///
/// 这里验证被抽出来的纯函数，它不需要文件系统。
void main() {
  Map<String, dynamic> configWith(List<String> names) => <String, dynamic>{
    'proxies': [
      for (final name in names) <String, dynamic>{'name': name, 'type': 'ss'},
    ],
    'proxy-groups': [
      <String, dynamic>{
        'name': 'PROXY',
        'type': 'select',
        'proxies': ['DIRECT', ...names],
      },
    ],
  };

  group('removeProxiesFromConfig', () {
    test('删掉存在的节点，并报告真实数量', () {
      final config = configWith(['a', 'b', 'c']);

      final removed = ManualProxyHelper.removeProxiesFromConfig(config, {
        'a',
        'c',
      });

      expect(removed, 2);
      final names = (config['proxies'] as List)
          .map((e) => (e as Map)['name'])
          .toList();
      expect(names, ['b']);
    });

    test('顺手摘掉组里对这些节点的引用，否则内核会拒绝整份配置', () {
      final config = configWith(['a', 'b']);

      ManualProxyHelper.removeProxiesFromConfig(config, {'a'});

      final group = (config['proxy-groups'] as List).first as Map;
      expect(group['proxies'], ['DIRECT', 'b']);
    });

    test('名字不存在时返回 0，不能假装删掉了', () {
      final config = configWith(['a', 'b']);

      final removed = ManualProxyHelper.removeProxiesFromConfig(config, {
        'ghost',
      });

      expect(removed, 0);
      expect((config['proxies'] as List), hasLength(2));
    });

    test('空集合返回 0', () {
      final config = configWith(['a']);
      expect(ManualProxyHelper.removeProxiesFromConfig(config, {}), 0);
    });

    test('proxies 不是列表时返回 0，不抛异常', () {
      final config = <String, dynamic>{'proxies': null, 'proxy-groups': []};
      expect(ManualProxyHelper.removeProxiesFromConfig(config, {'a'}), 0);
    });

    test('一个都没删掉时不碰组引用', () {
      final config = configWith(['a']);
      ManualProxyHelper.removeProxiesFromConfig(config, {'ghost'});

      final group = (config['proxy-groups'] as List).first as Map;
      expect(group['proxies'], ['DIRECT', 'a']);
    });
  });
}
