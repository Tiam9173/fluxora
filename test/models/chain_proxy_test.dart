import 'dart:convert';
import 'package:bett_box/models/chain_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LandingProxyParser 智能解析测试', () {
    test('正确解析常见住宅IP格式 IP:Port:User:Pass', () {
      const input = '198.51.100.25:8000:user123:pass456';
      final list = LandingProxyParser.parseText(input);

      expect(list.length, 1);
      final item = list.first;
      expect(item.server, '198.51.100.25');
      expect(item.port, 8000);
      expect(item.username, 'user123');
      expect(item.password, 'pass456');
      expect(item.protocol, ChainProxyProtocol.socks5);
      expect(item.udp, isTrue);
    });

    test('正确解析 User:Pass@IP:Port 格式', () {
      const input = 'residential_user:secret_pwd@45.154.255.88:1080';
      final list = LandingProxyParser.parseText(input);

      expect(list.length, 1);
      final item = list.first;
      expect(item.server, '45.154.255.88');
      expect(item.port, 1080);
      expect(item.username, 'residential_user');
      expect(item.password, 'secret_pwd');
      expect(item.protocol, ChainProxyProtocol.socks5);
    });

    test('正确解析 URI 格式并提取标签', () {
      const input = 'socks5://admin:token123@142.250.190.1:9050#US-Residential-01';
      final list = LandingProxyParser.parseText(input);

      expect(list.length, 1);
      final item = list.first;
      expect(item.name, 'US-Residential-01');
      expect(item.server, '142.250.190.1');
      expect(item.port, 9050);
      expect(item.username, 'admin');
      expect(item.password, 'token123');
      expect(item.protocol, ChainProxyProtocol.socks5);
    });

    test('支持多行批量解析与过滤无效注释行', () {
      const input = '''
# 这是注释行
198.51.100.1:8000:user1:pass1
// 这也是注释
http://user2:pass2@198.51.100.2:8080#HTTP-Node

198.51.100.3:1080:user3:pass3
''';
      final list = LandingProxyParser.parseText(input);

      expect(list.length, 3);
      expect(list[0].server, '198.51.100.1');
      expect(list[0].protocol, ChainProxyProtocol.socks5);

      expect(list[1].server, '198.51.100.2');
      expect(list[1].protocol, ChainProxyProtocol.http);
      expect(list[1].name, 'HTTP-Node');

      expect(list[2].server, '198.51.100.3');
    });

    test('白名单免密 IP:Port 格式解析', () {
      const input = '168.1.1.1:5000';
      final list = LandingProxyParser.parseText(input);

      expect(list.length, 1);
      expect(list.first.server, '168.1.1.1');
      expect(list.first.port, 5000);
      expect(list.first.username, isEmpty);
      expect(list.first.password, isEmpty);
    });
  });

  group('LandingProxy 模型与 Mihomo 格式转换测试', () {
    test('toMihomoProxyMap 正确设置 dialer-proxy 跳板', () {
      final proxy = LandingProxy.create(
        name: '美国家庭宽带',
        server: '142.250.1.1',
        port: 1080,
        username: 'u1',
        password: 'p1',
      );

      final mihomoMap = proxy.toMihomoProxyMap('🇭🇰 香港 01');

      expect(mihomoMap['name'], '美国家庭宽带');
      expect(mihomoMap['type'], 'socks5');
      expect(mihomoMap['server'], '142.250.1.1');
      expect(mihomoMap['port'], 1080);
      expect(mihomoMap['username'], 'u1');
      expect(mihomoMap['password'], 'p1');
      expect(mihomoMap['udp'], isTrue);
      expect(mihomoMap['dialer-proxy'], '🇭🇰 香港 01');
    });

    test('当跳板为 DIRECT 时不写入 dialer-proxy 字段', () {
      final proxy = LandingProxy.create(
        name: '直连节点',
        server: '1.2.3.4',
        port: 1080,
      );

      final mihomoMap = proxy.toMihomoProxyMap('DIRECT');

      expect(mihomoMap.containsKey('dialer-proxy'), isFalse);
    });

    test('独立指定跳板优先于默认跳板', () {
      final proxy = LandingProxy.create(
        name: '日本落地',
        server: '1.2.3.4',
        port: 1080,
        dialerProxy: '🇯🇵 日本专线',
      );

      final mihomoMap = proxy.toMihomoProxyMap('🇭🇰 香港专线');

      expect(mihomoMap['dialer-proxy'], '🇯🇵 日本专线');
    });
  });

  group('ChainProxyConfig 序列化与反序列化测试', () {
    test('配置对象与 JSON 双向转换', () {
      final config = ChainProxyConfig(
        enable: true,
        defaultDialerProxy: '🔰 节点选择',
        autoInjectGroups: true,
        createDedicatedGroup: true,
        dedicatedGroupName: '🔗 链式代理',
        landingProxies: [
          LandingProxy.create(
            name: '测试住宅',
            server: '10.0.0.1',
            port: 1080,
            username: 'admin',
          ),
        ],
      );

      final jsonStr = jsonEncode(config.toJson());
      final restored = ChainProxyConfig.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );

      expect(restored.enable, isTrue);
      expect(restored.defaultDialerProxy, '🔰 节点选择');
      expect(restored.autoInjectGroups, isTrue);
      expect(restored.createDedicatedGroup, isTrue);
      expect(restored.dedicatedGroupName, '🔗 链式代理');
      expect(restored.landingProxies.length, 1);
      expect(restored.landingProxies.first.name, '测试住宅');
      expect(restored.landingProxies.first.server, '10.0.0.1');
    });
  });

  group('ChainProxyConfig.applyToClashConfig 核心注入逻辑测试', () {
    test('成功注入落地节点，生成无回环跳板池，并加入专属策略组与主策略组', () {
      final config = ChainProxyConfig(
        enable: true,
        defaultDialerProxy: '', // 跟随主选择组 / 默认自动
        createDedicatedGroup: true,
        autoInjectGroups: true,
        landingProxies: [
          LandingProxy.create(
            name: '美国住宅01',
            server: '100.1.1.1',
            port: 8000,
            enable: true,
          ),
        ],
      );

      final rawConfig = <String, dynamic>{
        'proxies': [
          {'name': '🇭🇰 香港 01', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388},
        ],
        'proxy-groups': [
          {
            'name': '🔰 节点选择',
            'type': 'select',
            'proxies': ['🇭🇰 香港 01', 'DIRECT'],
          },
        ],
      };

      config.applyToClashConfig(rawConfig);

      // 验证 proxies 注入
      final proxies = rawConfig['proxies'] as List;
      expect(proxies.length, 2);
      final injected = proxies.firstWhere((p) => p['name'] == '美国住宅01');
      // 验证自动生成独立跳板组，避免主选择组自引用死锁
      expect(injected['dialer-proxy'], '✈️ 链式跳板');

      // 验证跳板池创建且仅包含原始出站节点
      final groups = rawConfig['proxy-groups'] as List;
      final hopGroup = groups.firstWhere(
        (g) => g['name'] == '✈️ 链式跳板',
        orElse: () => null,
      );
      expect(hopGroup, isNotNull);
      expect(hopGroup['proxies'], contains('🇭🇰 香港 01'));
      expect(hopGroup['proxies'], isNot(contains('美国住宅01')));

      // 验证专属策略组创建
      final dedicatedGroup =
          groups.firstWhere((g) => g['name'] == '🔗 链式代理', orElse: () => null);
      expect(dedicatedGroup, isNotNull);
      expect(dedicatedGroup['proxies'], contains('美国住宅01'));

      // 验证主选择组自动追加落地节点与专属组
      final selectGroup = groups.firstWhere((g) => g['name'] == '🔰 节点选择');
      expect(selectGroup['proxies'], contains('美国住宅01'));
      expect(selectGroup['proxies'], contains('🔗 链式代理'));
    });

    test('当显式指定具体节点作为跳板时直接采用该节点', () {
      final config = ChainProxyConfig(
        enable: true,
        defaultDialerProxy: '🇭🇰 香港 01',
        createDedicatedGroup: true,
        autoInjectGroups: true,
        landingProxies: [
          LandingProxy.create(
            name: '美国住宅01',
            server: '100.1.1.1',
            port: 8000,
            enable: true,
          ),
        ],
      );

      final rawConfig = <String, dynamic>{
        'proxies': [
          {'name': '🇭🇰 香港 01', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388},
        ],
        'proxy-groups': [
          {
            'name': '🔰 节点选择',
            'type': 'select',
            'proxies': ['🇭🇰 香港 01', 'DIRECT'],
          },
        ],
      };

      config.applyToClashConfig(rawConfig);

      final proxies = rawConfig['proxies'] as List;
      final injected = proxies.firstWhere((p) => p['name'] == '美国住宅01');
      expect(injected['dialer-proxy'], '🇭🇰 香港 01');
    });

    test('当未启用或没有启用的落地代理时，不修改原始配置', () {
      final config = ChainProxyConfig(
        enable: false,
        landingProxies: [
          LandingProxy.create(
            name: '美国住宅01',
            server: '100.1.1.1',
            port: 8000,
            enable: false,
          ),
        ],
      );

      final rawConfig = <String, dynamic>{
        'proxies': [
          {'name': '🇭🇰 香港 01', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388},
        ],
      };

      config.applyToClashConfig(rawConfig);

      expect((rawConfig['proxies'] as List).length, 1);
      expect(rawConfig.containsKey('proxy-groups'), isFalse);
    });

    test('防自循环保护：当跳板指向自身时安全降级', () {
      final config = ChainProxyConfig(
        enable: true,
        defaultDialerProxy: '美国住宅01', // 默认跳板指向自身
        landingProxies: [
          LandingProxy.create(
            name: '美国住宅01',
            server: '100.1.1.1',
            port: 8000,
            enable: true,
          ),
        ],
      );

      final rawConfig = <String, dynamic>{
        'proxies': [],
        'proxy-groups': [],
      };

      config.applyToClashConfig(rawConfig);

      final proxies = rawConfig['proxies'] as List;
      final injected = proxies.firstWhere((p) => p['name'] == '美国住宅01');
      // 避免死循环，应不带自身 dialer-proxy
      expect(injected['dialer-proxy'] != '美国住宅01', isTrue);
    });

    test('✈️ 链式跳板自动过滤信息类非真实节点，并注入网络加速配置', () {
      final config = ChainProxyConfig(
        enable: true,
        landingProxies: [
          LandingProxy.create(
            name: '住宅落地01',
            server: '100.1.1.1',
            port: 8000,
            enable: true,
          ),
        ],
      );

      final rawConfig = <String, dynamic>{
        'proxies': [
          {'name': '剩余流量：250GB', 'type': 'ss', 'server': '0.0.0.0', 'port': 80},
          {'name': '到期时间：2026-12-31', 'type': 'ss', 'server': '0.0.0.0', 'port': 80},
          {'name': '官网：https://example.com', 'type': 'ss', 'server': '0.0.0.0', 'port': 80},
          {'name': '🇺🇸 美国 01', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388},
          {'name': '🇯🇵 日本 01', 'type': 'ss', 'server': '1.1.1.2', 'port': 8388},
        ],
        'proxy-groups': [
          {
            'name': '🚀 节点选择',
            'type': 'select',
            'proxies': ['剩余流量：250GB', '🇺🇸 美国 01', '🇯🇵 日本 01'],
          },
        ],
      };

      config.applyToClashConfig(rawConfig);

      // 验证网络加速性能参数已注入
      expect(rawConfig['tcp-concurrent'], isTrue);
      expect(rawConfig['unified-delay'], isTrue);
      expect(rawConfig['keep-alive-idle'], 600);
      expect(rawConfig['keep-alive-interval'], 15);

      // 验证 ✈️ 链式跳板 策略组已过滤死节点并首推真实节点
      final groups = rawConfig['proxy-groups'] as List;
      final hopGroup = groups.firstWhere((g) => g['name'] == '✈️ 链式跳板') as Map;
      final hopProxies = hopGroup['proxies'] as List;

      expect(hopProxies.contains('剩余流量：250GB'), isFalse);
      expect(hopProxies.contains('到期时间：2026-12-31'), isFalse);
      expect(hopProxies.contains('官网：https://example.com'), isFalse);
      expect(hopProxies.first, '🇺🇸 美国 01');
    });

    test('HTTP TLS 落地代理自动配置 ALPN [h2, http/1.1] 提升下载并发吞吐率', () {
      final landing = LandingProxy(
        id: 'test-http',
        name: 'HTTP-TLS-Node',
        protocol: ChainProxyProtocol.http,
        server: '100.2.2.2',
        port: 443,
        tls: true,
      );

      final map = landing.toMihomoProxyMap('✈️ 链式跳板');
      expect(map['type'], 'http');
      expect(map['tls'], isTrue);
      expect(map['alpn'], ['h2', 'http/1.1']);
      expect(map['udp'], isTrue);
    });
  });
}
