// ignore_for_file: avoid_print, avoid_relative_lib_imports
import 'dart:convert';
import 'package:bett_box/models/chain_proxy.dart';

void assertTrue(bool condition, String message) {
  if (!condition) {
    throw Exception('FAILED: $message');
  }
  print('  ✓ $message');
}

Future<void> main() async {
  print('========================================');
  print('🚀 开始链式代理与住宅IP功能自检验证');
  print('========================================');

  // 1. 测试解析 IP:Port:User:Pass
  print('\n[测试 1] 常见住宅IP格式: IP:Port:User:Pass 解析');
  {
    const input = '198.51.100.25:8000:user123:pass456';
    final list = LandingProxyParser.parseText(input);
    assertTrue(list.length == 1, '解析出 1 个节点');
    final item = list.first;
    assertTrue(item.server == '198.51.100.25', '正确提取服务器 IP');
    assertTrue(item.port == 8000, '正确提取端口 8000');
    assertTrue(item.username == 'user123', '正确提取用户名');
    assertTrue(item.password == 'pass456', '正确提取密码');
    assertTrue(item.protocol == ChainProxyProtocol.socks5, '默认协议为 SOCKS5');
    assertTrue(item.udp == true, '默认开启 UDP');
  }

  // 2. 测试解析 User:Pass@IP:Port
  print('\n[测试 2] 常见住宅IP格式: User:Pass@IP:Port 解析');
  {
    const input = 'residential_user:secret_pwd@45.154.255.88:1080';
    final list = LandingProxyParser.parseText(input);
    assertTrue(list.length == 1, '解析出 1 个节点');
    final item = list.first;
    assertTrue(item.server == '45.154.255.88', '正确提取服务器 IP');
    assertTrue(item.port == 1080, '正确提取端口 1080');
    assertTrue(item.username == 'residential_user', '正确提取用户名');
    assertTrue(item.password == 'secret_pwd', '正确提取密码');
  }

  // 3. 测试 URI 格式与标签
  print('\n[测试 3] URI 格式解析与 Fragment 标签提取');
  {
    const input = 'socks5://admin:token123@142.250.190.1:9050#US-Residential-01';
    final list = LandingProxyParser.parseText(input);
    assertTrue(list.length == 1, '解析出 1 个节点');
    final item = list.first;
    assertTrue(item.name == 'US-Residential-01', '正确提取节点名称');
    assertTrue(item.server == '142.250.190.1', '正确提取服务器');
    assertTrue(item.port == 9050, '正确提取端口');
    assertTrue(item.username == 'admin', '正确提取用户名');
    assertTrue(item.password == 'token123', '正确提取密码');
  }

  // 4. 测试批量多行混贴与过滤注释
  print('\n[测试 4] 批量多行导入与混合格式解析');
  {
    const input = '''
# 供应商 A
198.51.100.1:8000:user1:pass1
// 供应商 B
http://user2:pass2@198.51.100.2:8080#HTTP-Node

198.51.100.3:1080:user3:pass3
168.1.1.1:5000
''';
    final list = LandingProxyParser.parseText(input);
    assertTrue(list.length == 4, '正确解析全部 4 个有效节点');
    assertTrue(list[0].protocol == ChainProxyProtocol.socks5, '第 1 个为 socks5');
    assertTrue(list[1].protocol == ChainProxyProtocol.http, '第 2 个为 http');
    assertTrue(list[2].server == '198.51.100.3', '第 3 个 IP 正确');
    assertTrue(list[3].username.isEmpty, '第 4 个免密白名单节点');
  }

  // 5. 测试 Mihomo dialer-proxy 字段映射
  print('\n[测试 5] Mihomo 代理配置字段与 dialer-proxy 映射');
  {
    final proxy = LandingProxy.create(
      name: '美国家庭宽带',
      server: '142.250.1.1',
      port: 1080,
      username: 'u1',
      password: 'p1',
    );

    final map1 = proxy.toMihomoProxyMap('🇭🇰 香港 01');
    assertTrue(map1['name'] == '美国家庭宽带', '名称正确');
    assertTrue(map1['type'] == 'socks5', '协议正确');
    assertTrue(map1['dialer-proxy'] == '🇭🇰 香港 01', '跳板指向香港01');

    final map2 = proxy.toMihomoProxyMap('DIRECT');
    assertTrue(!map2.containsKey('dialer-proxy'), 'DIRECT 时无 dialer-proxy');

    final proxyWithCustomHop = proxy.copyWith(dialerProxy: '🇯🇵 日本专线');
    final map3 = proxyWithCustomHop.toMihomoProxyMap('🇭🇰 香港 01');
    assertTrue(map3['dialer-proxy'] == '🇯🇵 日本专线', '单节点覆写跳板生效');
  }

  // 6. 测试 JSON 序列化与反序列化
  print('\n[测试 6] ChainProxyConfig JSON 序列化');
  {
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

    assertTrue(restored.enable == true, 'enable 正确');
    assertTrue(restored.defaultDialerProxy == '🔰 节点选择', 'defaultDialerProxy 正确');
    assertTrue(restored.createDedicatedGroup == true, 'createDedicatedGroup 正确');
    assertTrue(restored.landingProxies.length == 1, 'landingProxies 数量正确');
    assertTrue(restored.landingProxies.first.name == '测试住宅', '节点名称正确');
  }

  // 7. 测试 ChainProxyConfig.applyToClashConfig 热注入
  print('\n[测试 7] ChainProxyConfig.applyToClashConfig 配置热注入');
  {
    final config = ChainProxyConfig(
      enable: true,
      defaultDialerProxy: '🔰 节点选择',
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
        {
          'name': '🌍 国外流量',
          'type': 'select',
          'proxies': ['🔰 节点选择'],
        },
      ],
    };

    config.applyToClashConfig(rawConfig);

    final proxies = rawConfig['proxies'] as List;
    assertTrue(proxies.length == 2, '成功追加到 proxies 列表');
    final injected = proxies.firstWhere((p) => p['name'] == '美国住宅01');
    assertTrue(injected['dialer-proxy'] == '✈️ 链式跳板', '跳板指向专职跳板池');

    final groups = rawConfig['proxy-groups'] as List;
    final hopGroup = groups.firstWhere(
      (g) => g is Map && g['name'] == '✈️ 链式跳板',
      orElse: () => null,
    );
    assertTrue(hopGroup != null, '成功生成专职「✈️ 链式跳板」策略组');
    assertTrue(
      (hopGroup['proxies'] as List).contains('🇭🇰 香港 01'),
      '跳板组包含原始出站节点',
    );

    final dedicatedGroup = groups.firstWhere(
      (g) => g is Map && g['name'] == '🔗 链式代理',
      orElse: () => null,
    );
    assertTrue(dedicatedGroup != null, '成功生成专属「🔗 链式代理」策略组');
    assertTrue(
      (dedicatedGroup['proxies'] as List).contains('美国住宅01'),
      '专属组包含落地代理',
    );

    final selectGroup = groups.firstWhere((g) => g['name'] == '🔰 节点选择');
    assertTrue(
      (selectGroup['proxies'] as List).contains('美国住宅01'),
      '主选择组安全追加落地代理 (跳板已隔离，无回环死锁)',
    );
    assertTrue(
      (selectGroup['proxies'] as List).contains('🔗 链式代理'),
      '主选择组包含专属链式代理组',
    );

    final foreignGroup = groups.firstWhere((g) => g['name'] == '🌍 国外流量');
    assertTrue(
      (foreignGroup['proxies'] as List).contains('美国住宅01'),
      '常规业务组自动包含落地代理',
    );
  }

  // 8. 测试死循环安全防护
  print('\n[测试 8] 避免死循环自引用的安全防御');
  {
    final config = ChainProxyConfig(
      enable: true,
      defaultDialerProxy: '环路测试节点',
      landingProxies: [
        LandingProxy.create(
          name: '环路测试节点',
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
    final injected = proxies.firstWhere((p) => p['name'] == '环路测试节点');
    assertTrue(injected['dialer-proxy'] != '环路测试节点', '自引用时解除环路绑定');
  }

  // 9. 测试 TargetHealthResult 与 ProxyHealthReport 行为与序列化
  print('\n[测试 9] ProxyHealthReport 与多目标服务结果解析');
  {
    final targets = [
      const TargetHealthResult(
        service: TargetService.cloudflare,
        delay: 150,
        isSuccess: true,
      ),
      const TargetHealthResult(
        service: TargetService.openai,
        delay: 280,
        isSuccess: true,
      ),
      const TargetHealthResult(
        service: TargetService.tiktok,
        isSuccess: false,
        error: '超时',
      ),
    ];

    final report = ProxyHealthReport(
      proxyId: 'test-id-123',
      proxyName: '美国住宅测试01',
      status: HealthStatus.warning,
      targets: targets,
      diagnosticTips: '部分服务受限',
      testedAt: DateTime.now(),
      minDelay: 150,
      avgDelay: 215,
    );

    assertTrue(report.isTargetAvailable(TargetService.cloudflare) == true, 'Cloudflare 可用');
    assertTrue(report.isTargetAvailable(TargetService.openai) == true, 'OpenAI 可用');
    assertTrue(report.isTargetAvailable(TargetService.tiktok) == false, 'TikTok 状态为不可用');
    assertTrue(report.getTargetDelay(TargetService.cloudflare) == 150, '正确获取延迟 150ms');

    final jsonMap = report.toJson();
    final restored = ProxyHealthReport.fromJson(jsonMap);
    assertTrue(restored.proxyId == 'test-id-123', '恢复 proxyId 正确');
    assertTrue(restored.status == HealthStatus.warning, '恢复状态 warning 正确');
    assertTrue(restored.targets.length == 3, '恢复目标服务数量正确');
    assertTrue(restored.minDelay == 150, '恢复 minDelay 正确');
  }

  // 10. 测试 DirectSocketVerifier 的异常捕获与诊断封装
  print('\n[测试 10] DirectSocketVerifier 异常捕获与超时机制');
  {
    final res = await DirectSocketVerifier.verify(
      server: '127.0.0.1',
      port: 59999,
      protocol: ChainProxyProtocol.socks5,
      timeout: const Duration(milliseconds: 300),
    );

    assertTrue(res.isSuccess == false, '离线或未监听端口判定为失败');
    assertTrue(res.message.isNotEmpty, '生成明确错误提示');
  }

  // 11. 测试 WebRTC 真实 IP 泄露防护规则注入
  print('\n[测试 11] WebRTC 防泄露规则注入验证 (防止 STUN 泄露真实 IP)');
  {
    final configWithWebRtc = ChainProxyConfig(
      enable: true,
      preventWebRtcLeak: true,
      landingProxies: [
        LandingProxy.create(name: '静态住宅IP', server: '1.2.3.4', port: 1080, enable: true),
      ],
    );

    final rawConfig = <String, dynamic>{
      'proxies': [],
      'proxy-groups': [],
      'rules': ['GEOIP,CN,DIRECT', 'MATCH,🐟 漏网之鱼'],
    };

    configWithWebRtc.applyToClashConfig(rawConfig);
    final rules = rawConfig['rules'] as List;
    assertTrue(rules.isNotEmpty, 'rules 列表不为空');
    assertTrue(rules.any((r) => r.toString().contains('3478') && r.toString().contains('REJECT')), '包含 STUN 端口 3478 拦截规则');
    assertTrue(rules.any((r) => r.toString().contains('19302') && r.toString().contains('REJECT')), '包含 Google STUN 端口 19302 拦截规则');
    assertTrue(rules.any((r) => r.toString().contains('stun') && r.toString().contains('REJECT')), '包含 STUN 域名关键字拦截规则');
    assertTrue(rules.first.toString().contains('REJECT'), 'WebRTC 拦截规则置于最顶层优先匹配');

    // 关闭防泄露时，不注入拦截规则
    final configWithoutWebRtc = configWithWebRtc.copyWith(preventWebRtcLeak: false);
    final rawConfig2 = <String, dynamic>{
      'proxies': [],
      'proxy-groups': [],
      'rules': ['GEOIP,CN,DIRECT', 'MATCH,🐟 漏网之鱼'],
    };
    configWithoutWebRtc.applyToClashConfig(rawConfig2);
    final rules2 = rawConfig2['rules'] as List;
    assertTrue(!rules2.any((r) => r.toString().contains('3478')), '关闭时不出 STUN 拦截规则');
  }

  // 12. 测试跳板为策略组时的防死循环机制
  print('\n[测试 12] 跳板为策略组时的防死循环机制 (如 us6 san 节点崩溃修复)');
  {
    final config = ChainProxyConfig(
      enable: true,
      defaultDialerProxy: '🚀 节点选择',
      autoInjectGroups: true,
      landingProxies: [
        LandingProxy.create(
          name: 'US-Residential',
          server: '100.200.300.1',
          port: 1080,
          enable: true,
        ),
      ],
    );

    final rawConfig = <String, dynamic>{
      'proxies': [
        {'name': 'us6 san', 'type': 'vless', 'server': 'magic-9s0.pages.dev', 'port': 443},
      ],
      'proxy-groups': [
        {
          'name': '🚀 节点选择',
          'type': 'select',
          'proxies': ['us6 san'],
        },
        {
          'name': 'CloudFlareCDN',
          'type': 'select',
          'proxies': ['DIRECT', 'us6 san'],
        },
        {
          'name': '🐟 漏网之鱼',
          'type': 'select',
          'proxies': ['🚀 节点选择'],
        },
        {
          'name': '🌍 国外媒体',
          'type': 'select',
          'proxies': ['🚀 节点选择'],
        },
      ],
    };

    config.applyToClashConfig(rawConfig);

    final groups = rawConfig['proxy-groups'] as List;
    final nodeSelectGroup = groups.firstWhere((g) => g['name'] == '🚀 节点选择');
    final hopGroup = groups.firstWhere((g) => g['name'] == '✈️ 链式跳板');
    final cdnGroup = groups.firstWhere((g) => g['name'] == 'CloudFlareCDN');
    final mediaGroup = groups.firstWhere((g) => g['name'] == '🌍 国外媒体');

    // 独立跳板策略组自身绝不包含该落地代理，避免回环死循环
    assertTrue(
      !(hopGroup['proxies'] as List).contains('US-Residential'),
      '独立跳板策略组自身绝不包含该落地代理，避免回环死循环',
    );

    // 主选择组安全获得落地节点，用户可直接选择使用
    assertTrue(
      (nodeSelectGroup['proxies'] as List).contains('US-Residential'),
      '主选择组成功注入落地节点供用户选择',
    );

    // 落地代理决不注入到专有分流组（CloudFlareCDN, 漏网之鱼等）
    assertTrue(
      !(cdnGroup['proxies'] as List).contains('US-Residential'),
      '专有路由组 (CloudFlareCDN) 决不注入落地代理',
    );

    // 业务分组 (国外媒体) 正确追加了落地代理，且位于尾部未劫持默认首节点
    final mediaProxies = mediaGroup['proxies'] as List;
    assertTrue(mediaProxies.contains('US-Residential'), '常规业务分组成功追加落地代理');
    assertTrue(mediaProxies.first == '🚀 节点选择', '未篡改第0位默认节点');
  }

  print('\n========================================');
  print('🎉 全部自检测试通过！功能完整、健壮、安全！');
  print('========================================');
}
