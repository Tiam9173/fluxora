import 'dart:convert';
import 'package:bett_box/models/warp_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WarpConfig 模型与序列化测试', () {
    test('WarpConfig 默认参数与 JSON 双向转换', () {
      final config = WarpConfig(
        enable: true,
        proxyName: '🛡️ Cloudflare WARP',
        privateKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        publicKey: 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
        server: '162.159.192.1',
        port: 2408,
        ip: '172.16.0.2/32',
        reserved: [1, 2, 3],
        mode: WarpMode.googleAndAi,
        licenseKey: 'test-license-key',
        defaultDialerProxy: '🇭🇰 香港 01',
      );

      final jsonStr = jsonEncode(config.toJson());
      final restored =
          WarpConfig.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(restored.enable, isTrue);
      expect(restored.proxyName, '🛡️ Cloudflare WARP');
      expect(restored.privateKey, 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=');
      expect(restored.publicKey, 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=');
      expect(restored.server, '162.159.192.1');
      expect(restored.port, 2408);
      expect(restored.reserved, [1, 2, 3]);
      expect(restored.mode, WarpMode.googleAndAi);
      expect(restored.licenseKey, 'test-license-key');
      expect(restored.defaultDialerProxy, '🇭🇰 香港 01');
    });

    test('WarpConfig.generateNew 自动生成合法密钥对', () {
      final config = WarpConfig.generateNew(enable: true);
      expect(config.enable, isTrue);
      expect(config.privateKey.isNotEmpty, isTrue);
      expect(config.publicKey.isNotEmpty, isTrue);
      expect(base64Decode(config.privateKey).length, 32);
      expect(base64Decode(config.publicKey).length, 32);
    });
  });

  group('toMihomoProxyMap 转换测试', () {
    test('生成标准 WireGuard 代理配置并包含 dialer-proxy 跳板', () {
      final config = WarpConfig(
        enable: true,
        proxyName: '🛡️ Cloudflare WARP',
        privateKey: 'priv_key_base64',
        publicKey: 'pub_key_base64',
        server: '162.159.192.1',
        port: 2408,
        reserved: [12, 34, 56],
        mtu: 1280,
      );

      final map = config.toMihomoProxyMap('🇭🇰 香港专线');

      expect(map['name'], '🛡️ Cloudflare WARP');
      expect(map['type'], 'wireguard');
      expect(map['server'], '162.159.192.1');
      expect(map['port'], 2408);
      expect(map['private-key'], 'priv_key_base64');
      expect(map['public-key'], WarpConfig.defaultPeerPublicKey);
      expect(map['reserved'], [12, 34, 56]);
      expect(map['mtu'], 1280);
      expect(map['udp'], isTrue);
      expect(map['remote-dns-resolve'], isTrue);
      expect(map['dialer-proxy'], '🇭🇰 香港专线');
    });

    test('当跳板为 DIRECT 时不注入 dialer-proxy', () {
      final config = WarpConfig(
        enable: true,
        privateKey: 'priv_key',
      );

      final map = config.toMihomoProxyMap('DIRECT');
      expect(map.containsKey('dialer-proxy'), isFalse);
    });
  });

  group('applyToClashConfig 核心注入测试', () {
    test('未启用时不改变任何配置', () {
      final config = WarpConfig(enable: false, privateKey: 'test_priv');
      final raw = <String, dynamic>{
        'proxies': [
          {'name': 'Node1', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388}
        ],
        'proxy-groups': [
          {
            'name': 'GLOBAL',
            'type': 'select',
            'proxies': ['Node1']
          }
        ],
        'rules': ['GEOIP,CN,DIRECT'],
      };

      config.applyToClashConfig(raw);

      final proxies = raw['proxies'] as List;
      expect(proxies.length, 1);
      expect(proxies.first['name'], 'Node1');
    });

    test('启用 googleAndAi 模式：注入 WireGuard 节点、跳板池、WARP策略组以及防送中与AI优先分流规则', () {
      final config = WarpConfig(
        enable: true,
        privateKey: 'test_priv_key',
        server: '162.159.192.1',
        port: 2408,
        mode: WarpMode.googleAndAi,
        defaultDialerProxy: '', // 跟随主选择
      );

      final raw = <String, dynamic>{
        'proxies': [
          {'name': '🇭🇰 香港 01', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388},
          {'name': '🇯🇵 日本 01', 'type': 'trojan', 'server': '2.2.2.2', 'port': 443},
          {'name': '剩余流量 100GB', 'type': 'ss', 'server': '0.0.0.0', 'port': 0},
        ],
        'proxy-groups': [
          {
            'name': '🔰 节点选择',
            'type': 'select',
            'proxies': ['🇭🇰 香港 01', '🇯🇵 日本 01']
          }
        ],
        'rules': [
          'GEOIP,CN,DIRECT',
          'MATCH,🔰 节点选择',
        ],
      };

      config.applyToClashConfig(raw);

      // 1. 验证 WireGuard 节点被注入
      final proxies = raw['proxies'] as List;
      final warpProxy = proxies.firstWhere(
        (p) => p is Map && p['name'] == '🛡️ Cloudflare WARP',
      ) as Map<String, dynamic>;
      expect(warpProxy['type'], 'wireguard');
      expect(warpProxy['dialer-proxy'], '✈️ WARP跳板');

      // 2. 验证 ✈️ WARP跳板 策略组已生成并自动过滤非节点信息行
      final groups = raw['proxy-groups'] as List;
      final hopGroup = groups.firstWhere(
        (g) => g is Map && g['name'] == '✈️ WARP跳板',
      ) as Map<String, dynamic>;
      final hopProxies = hopGroup['proxies'] as List;
      expect(hopProxies.contains('🇭🇰 香港 01'), isTrue);
      expect(hopProxies.contains('🇯🇵 日本 01'), isTrue);
      expect(hopProxies.contains('剩余流量 100GB'), isFalse);

      // 3. 验证 🛡️ WARP 出口 策略组已生成
      final warpGroup = groups.firstWhere(
        (g) => g is Map && g['name'] == '🛡️ WARP 出口',
      ) as Map<String, dynamic>;
      final warpGroupProxies = warpGroup['proxies'] as List;
      expect(warpGroupProxies.contains('🛡️ Cloudflare WARP'), isTrue);
      expect(warpGroupProxies.contains('DIRECT'), isTrue);

      // 4. 验证防送中与 AI 规则被插入到最顶部
      final rules = raw['rules'] as List;
      expect(rules.contains('DOMAIN-SUFFIX,google.com,🛡️ WARP 出口'), isTrue);
      expect(rules.contains('DOMAIN-SUFFIX,google.com.hk,🛡️ WARP 出口'), isTrue);
      expect(rules.contains('DOMAIN-SUFFIX,openai.com,🛡️ WARP 出口'), isTrue);
      expect(rules.contains('DOMAIN-SUFFIX,chatgpt.com,🛡️ WARP 出口'), isTrue);
      expect(rules.contains('DOMAIN-SUFFIX,anthropic.com,🛡️ WARP 出口'), isTrue);
      expect(rules.contains('DOMAIN-SUFFIX,claude.ai,🛡️ WARP 出口'), isTrue);
      expect(rules.contains('DOMAIN-SUFFIX,gemini.google.com,🛡️ WARP 出口'), isTrue);
      expect(rules.first, 'DOMAIN-SUFFIX,google.com,🛡️ WARP 出口');
    });

    test('显式指定机场节点作为跳板时直接采用该节点', () {
      final config = WarpConfig(
        enable: true,
        privateKey: 'test_priv_key',
        defaultDialerProxy: '🇯🇵 日本 01',
      );

      final raw = <String, dynamic>{
        'proxies': [
          {'name': '🇭🇰 香港 01', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388},
          {'name': '🇯🇵 日本 01', 'type': 'trojan', 'server': '2.2.2.2', 'port': 443},
        ],
        'proxy-groups': [],
        'rules': [],
      };

      config.applyToClashConfig(raw);

      final proxies = raw['proxies'] as List;
      final warpProxy = proxies.firstWhere(
        (p) => p is Map && p['name'] == '🛡️ Cloudflare WARP',
      ) as Map<String, dynamic>;
      expect(warpProxy['dialer-proxy'], '🇯🇵 日本 01');
    });
  });

  group('WarpStatusReport Trace 解析测试', () {
    test('正确解析官方 CDN-CGI Trace 响应 (warp=on, 香港 HKG)', () {
      const traceText = '''
fl=523f123
h=www.cloudflare.com
ip=104.28.192.88
ts=1726831200.123
visit_scheme=https
uag=Mozilla/5.0
colo=HKG
sliver=none
http=http/2
loc=HK
tls=TLSv1.3
sni=plaintext
warp=on
gateway=off
rbi=off
kex=X25519
''';

      final report = WarpStatusReport.fromTrace(
        traceText: traceText,
        latencyMs: 38,
        googleOk: true,
        googleDetail: '原生访问正常，无送中与验证码拦截',
      );

      expect(report.isSuccess, isTrue);
      expect(report.isWarpActive, isTrue);
      expect(report.warpType, 'on');
      expect(report.ip, '104.28.192.88');
      expect(report.colo, 'HKG');
      expect(report.coloCityName, '中国香港 (Hong Kong)');
      expect(report.loc, 'HK');
      expect(report.latencyMs, 38);
      expect(report.isGoogleAntiRedirect, isTrue);
      expect(report.googleStatus, contains('原生访问正常'));
    });

    test('正确解析 WARP+ 会员响应 (warp=plus, 圣何塞 SJC)', () {
      const traceText = '''
fl=100f200
h=www.cloudflare.com
ip=104.28.250.99
colo=SJC
loc=US
warp=plus
''';

      final report = WarpStatusReport.fromTrace(
        traceText: traceText,
        latencyMs: 145,
        googleOk: true,
        googleDetail: '原生访问正常',
      );

      expect(report.isWarpActive, isTrue);
      expect(report.warpType, 'plus');
      expect(report.colo, 'SJC');
      expect(report.coloCityName, contains('圣何塞'));
      expect(report.loc, 'US');
    });

    test('当 warp=off 时正确识别为普通直连/非 WARP 状态', () {
      const traceText = '''
ip=185.199.108.153
colo=NRT
loc=JP
warp=off
''';

      final report = WarpStatusReport.fromTrace(
        traceText: traceText,
        latencyMs: 70,
        googleOk: false,
        googleDetail: '存在送中风险 (重定向至 google.com.hk)',
      );

      expect(report.isSuccess, isTrue);
      expect(report.isWarpActive, isFalse);
      expect(report.warpType, 'off');
      expect(report.isGoogleAntiRedirect, isFalse);
    });
  });

  group('WARP 路由模式与优选 IP 测试', () {
    test('优选 IP 与端口有效值计算', () {
      const configAuto = WarpConfig(cleanIp: 'auto', port: 0);
      expect(configAuto.effectiveServer, WarpConfig.defaultEndpoint);
      expect(configAuto.effectivePort, WarpConfig.defaultPort);

      const configCustom = WarpConfig(cleanIp: '162.159.193.10', port: 4500);
      expect(configCustom.effectiveServer, '162.159.193.10');
      expect(configCustom.effectivePort, 4500);
    });

    test('proxyOverWarp 模式：所有机场代理节点自动注入 dialer-proxy 为 WARP', () {
      final config = WarpConfig(
        enable: true,
        privateKey: 'priv_key',
        routingMode: WarpRoutingMode.proxyOverWarp,
      );

      final raw = <String, dynamic>{
        'proxies': [
          {'name': '🇭🇰 香港 01', 'type': 'ss', 'server': '1.1.1.1', 'port': 8388},
          {'name': '🇯🇵 日本 01', 'type': 'trojan', 'server': '2.2.2.2', 'port': 443},
        ],
        'proxy-groups': [
          {
            'name': 'GLOBAL',
            'type': 'select',
            'proxies': ['🇭🇰 香港 01']
          }
        ],
        'rules': ['MATCH,GLOBAL'],
      };

      config.applyToClashConfig(raw);

      final proxies = raw['proxies'] as List;
      final warpNode = proxies.firstWhere((p) => p['name'] == config.proxyName);
      expect(warpNode.containsKey('dialer-proxy'), isFalse); // WARP 直连

      final hkNode = proxies.firstWhere((p) => p['name'] == '🇭🇰 香港 01');
      expect(hkNode['dialer-proxy'], config.proxyName); // 机场节点通过 WARP 级联

      final jpNode = proxies.firstWhere((p) => p['name'] == '🇯🇵 日本 01');
      expect(jpNode['dialer-proxy'], config.proxyName);
    });
  });
}
