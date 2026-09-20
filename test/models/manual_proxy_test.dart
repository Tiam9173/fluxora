import 'package:bett_box/manager/profile_chain_manager.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManualProxyHelper Share Link Parsing Tests', () {
    test('Parse VMess link', () {
      // vmess://eyJ2IjoiMiIsInBzIjoiVGVzdC1WTWVzcyIsImFkZCI6IjEuMi4zLjQiLCJwb3J0IjoiNDQzIiwiaWQiOiJiODNjZGEwNy1hMzA5LTQ3ODMtODAyNi1jMGY2ZGZmOTk0ODUiLCJhaWQiOiIwIiwic2N5IjoiYXV0byIsIm5ldCI6IndzIiwidHlwZSI6Im5vbmUiLCJob3N0IjoidGVzdC5jb20iLCJwYXRoIjoiL3dzIiwidGxzIjoidGxzIiwic25pIjoidGVzdC5jb20ifQ==
      const link =
          'vmess://eyJ2IjoiMiIsInBzIjoiVGVzdC1WTWVzcyIsImFkZCI6IjEuMi4zLjQiLCJwb3J0IjoiNDQzIiwiaWQiOiJiODNjZGEwNy1hMzA5LTQ3ODMtODAyNi1jMGY2ZGZmOTk0ODUiLCJhaWQiOiIwIiwic2N5IjoiYXV0byIsIm5ldCI6IndzIiwidHlwZSI6Im5vbmUiLCJob3N0IjoidGVzdC5jb20iLCJwYXRoIjoiL3dzIiwidGxzIjoidGxzIiwic25pIjoidGVzdC5jb20ifQ==';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-VMess');
      expect(proxy['type'], 'vmess');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 443);
      expect(proxy['uuid'], 'b83cda07-a309-4783-8026-c0f6dff99485');
      expect(proxy['network'], 'ws');
      expect(proxy['tls'], true);
      expect(proxy['servername'], 'test.com');
      expect(proxy['ws-opts']['path'], '/ws');
    });

    test('Parse VLESS REALITY link', () {
      const link =
          'vless://b83cda07-a309-4783-8026-c0f6dff99485@1.2.3.4:443?type=tcp&security=reality&pbk=112233445566778899aabbccddeeff00&sid=123456&sni=cloudflare.com&flow=xtls-rprx-vision&fp=chrome#Test-REALITY';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-REALITY');
      expect(proxy['type'], 'vless');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 443);
      expect(proxy['uuid'], 'b83cda07-a309-4783-8026-c0f6dff99485');
      expect(proxy['flow'], 'xtls-rprx-vision');
      expect(proxy['tls'], true);
      expect(proxy['servername'], 'cloudflare.com');
      expect(proxy['reality-opts']['public-key'], '112233445566778899aabbccddeeff00');
      expect(proxy['reality-opts']['short-id'], '123456');
    });

    test('Parse Shadowsocks link', () {
      // ss://YWVzLTI1Ni1nY206cGFzc3dvcmRAMS4yLjMuNDo4Mzg4#Test-SS (aes-256-gcm:password@1.2.3.4:8388)
      const link =
          'ss://YWVzLTI1Ni1nY206cGFzc3dvcmRAMS4yLjMuNDo4Mzg4#Test-SS';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-SS');
      expect(proxy['type'], 'ss');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 8388);
      expect(proxy['cipher'], 'aes-256-gcm');
      expect(proxy['password'], 'password');
    });

    test('Parse Trojan link', () {
      const link = 'trojan://password123@1.2.3.4:443?sni=trojan.com&type=ws&path=%2Ftrojan#Test-Trojan';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-Trojan');
      expect(proxy['type'], 'trojan');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 443);
      expect(proxy['password'], 'password123');
      expect(proxy['sni'], 'trojan.com');
      expect(proxy['network'], 'ws');
      expect(proxy['ws-opts']['path'], '/trojan');
    });

    test('Parse Hysteria2 link', () {
      const link = 'hysteria2://authPass@1.2.3.4:8443?sni=hy2.com&obfs=salamander&obfs-password=123456#Test-Hy2';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-Hy2');
      expect(proxy['type'], 'hysteria2');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 8443);
      expect(proxy['password'], 'authPass');
      expect(proxy['sni'], 'hy2.com');
      expect(proxy['obfs'], 'salamander');
      expect(proxy['obfs-password'], '123456');
    });

    test('Parse TUIC link', () {
      const link = 'tuic://uuid123:pass456@1.2.3.4:8443?congestion_control=bbr&alpn=h3&sni=tuic.com#Test-TUIC';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-TUIC');
      expect(proxy['type'], 'tuic');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 8443);
      expect(proxy['uuid'], 'uuid123');
      expect(proxy['password'], 'pass456');
      expect(proxy['congestion-controller'], 'bbr');
      expect(proxy['alpn'], ['h3']);
    });

    test('Parse WireGuard link', () {
      const link = 'wireguard://cGlm...private=@1.2.3.4:51820?public_key=cHVi...public=&ip=10.0.0.2&preshared_key=cHNr...#Test-WG';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-WG');
      expect(proxy['type'], 'wireguard');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 51820);
      expect(proxy['ip'], '10.0.0.2');
      expect(proxy['public-key'], 'cHVi...public=');
    });

    test('Parse SOCKS5 link', () {
      const link = 'socks5://user:pass@1.2.3.4:1080#Test-Socks';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-Socks');
      expect(proxy['type'], 'socks5');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 1080);
      expect(proxy['username'], 'user');
      expect(proxy['password'], 'pass');
    });

    test('Parse Snell link', () {
      const link = 'snell://mypsk123@1.2.3.4:443?version=4&obfs=tls&host=bing.com#Test-Snell';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-Snell');
      expect(proxy['type'], 'snell');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 443);
      expect(proxy['psk'], 'mypsk123');
      expect(proxy['version'], 4);
      expect(proxy['obfs-opts']['mode'], 'tls');
      expect(proxy['obfs-opts']['host'], 'bing.com');
    });

    test('Parse SSH link', () {
      const link = 'ssh://root:secretPass@1.2.3.4:22#Test-SSH';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-SSH');
      expect(proxy['type'], 'ssh');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 22);
      expect(proxy['username'], 'root');
      expect(proxy['password'], 'secretPass');
    });

    test('Parse ShadowTLS link', () {
      const link = 'shadow-tls://myTlsPass@1.2.3.4:443?sni=apple.com&version=3#Test-ShadowTLS';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-ShadowTLS');
      expect(proxy['type'], 'shadow-tls');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 443);
      expect(proxy['password'], 'myTlsPass');
      expect(proxy['sni'], 'apple.com');
      expect(proxy['version'], 3);
    });

    test('Parse Juicity link', () {
      const link = 'juicity://myuuid:mypass@1.2.3.4:443?sni=test.com&allow_insecure=1&congestion_control=bbr#Test-Juicity';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-Juicity');
      expect(proxy['type'], 'juicity');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 443);
      expect(proxy['uuid'], 'myuuid');
      expect(proxy['password'], 'mypass');
      expect(proxy['sni'], 'test.com');
      expect(proxy['allow-insecure'], true);
      expect(proxy['congestion-control'], 'bbr');
    });

    test('Parse Hysteria 1 link', () {
      const link = 'hysteria://1.2.3.4:443?auth=pass123&up=50&down=200&sni=hy1.com#Test-Hy1';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-Hy1');
      expect(proxy['type'], 'hysteria');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 443);
      expect(proxy['auth_str'], 'pass123');
      expect(proxy['up'], '50 Mbps');
      expect(proxy['down'], '200 Mbps');
      expect(proxy['sni'], 'hy1.com');
    });

    test('Parse AmneziaWG link', () {
      const link = 'awg://privatekey123@1.2.3.4:51820?public_key=pub123&ip=10.0.0.2&jc=5&jmin=50&jmax=80#Test-AWG';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Test-AWG');
      expect(proxy['type'], 'wireguard');
      expect(proxy['server'], '1.2.3.4');
      expect(proxy['port'], 51820);
      expect(proxy['private-key'], 'privatekey123');
      expect(proxy['public-key'], 'pub123');
      expect(proxy['jc'], 5);
      expect(proxy['jmin'], 50);
      expect(proxy['jmax'], 80);
    });

    test('Parse Direct link', () {
      const link = 'direct://#MyDirect';
      final proxy = ManualProxyHelper.parseShareLink(link);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'MyDirect');
      expect(proxy['type'], 'direct');
    });

    test('Parse Custom YAML snippet', () {
      const yamlStr = '''
name: Custom-Tailscale
type: tailscale
server: 1.2.3.4
port: 443
''';
      final proxy = ManualProxyHelper.parseShareLink(yamlStr);
      expect(proxy, isNotNull);
      expect(proxy!['name'], 'Custom-Tailscale');
      expect(proxy['type'], 'tailscale');
      expect(proxy['server'], '1.2.3.4');
    });

    test('Parse multiple batch links with mixed protocols', () {
      const text = '''
ss://YWVzLTI1Ni1nY206cGFzc3dvcmRAMS4yLjMuNDo4Mzg4#Node-1
snell://mypsk@1.2.3.4:443?version=4#Node-Snell
ssh://root:pwd@2.2.2.2:22#Node-SSH
direct://#Node-Direct
invalid://unsupported
vless://b83cda07-a309-4783-8026-c0f6dff99485@9.9.9.9:443#Node-VLESS
''';
      final list = ManualProxyHelper.parseMultipleLinks(text);
      expect(list.length, 5);
      expect(list[0]['name'], 'Node-1');
      expect(list[1]['name'], 'Node-Snell');
      expect(list[2]['name'], 'Node-SSH');
      expect(list[3]['name'], 'Node-Direct');
      expect(list[4]['name'], 'Node-VLESS');
    });
  });

  group('ProfileChainManager Chaining Tests', () {
    test('Pre-Proxy sets dialer-proxy on subscription proxies', () {
      final manager = ProfileChainManager();
      final rawConfig = <String, dynamic>{
        'proxies': [
          {'name': 'Pre-Node', 'type': 'ss', 'server': '1.1.1.1'},
          {'name': 'Sub-Node-1', 'type': 'vmess', 'server': '2.2.2.2'},
          {'name': 'Sub-Node-2', 'type': 'trojan', 'server': '3.3.3.3'},
        ],
        'proxy-groups': [
          {
            'name': 'PROXY',
            'type': 'select',
            'proxies': ['Sub-Node-1', 'Sub-Node-2'],
          }
        ],
      };

      // Set chain config with preProxy
      manager.updateChain('test-profile-1', (c) {
        return c.copyWith(
          enable: true,
          preProxy: 'Pre-Node',
        );
      }, reloadCore: false, save: false);

      manager.applyToClashConfig(rawConfig, 'test-profile-1');

      final proxies = rawConfig['proxies'] as List;
      final sub1 = proxies.firstWhere((p) => p['name'] == 'Sub-Node-1');
      final sub2 = proxies.firstWhere((p) => p['name'] == 'Sub-Node-2');
      final pre = proxies.firstWhere((p) => p['name'] == 'Pre-Node');

      expect(sub1['dialer-proxy'], 'Pre-Node');
      expect(sub2['dialer-proxy'], 'Pre-Node');
      expect(pre['dialer-proxy'], isNull); // Pre-node should not dial through itself
    });

    test('Landing-Proxy creates chained exit proxies', () {
      final manager = ProfileChainManager();
      final rawConfig = <String, dynamic>{
        'proxies': [
          {'name': 'Landing-Node', 'type': 'socks5', 'server': '4.4.4.4', 'port': 1080},
          {'name': 'Sub-Node-A', 'type': 'ss', 'server': '5.5.5.5', 'port': 8388},
        ],
        'proxy-groups': [
          {
            'name': 'PROXY',
            'type': 'select',
            'proxies': ['Sub-Node-A'],
          }
        ],
      };

      manager.updateChain('test-profile-2', (c) {
        return c.copyWith(
          enable: true,
          landingProxy: 'Landing-Node',
        );
      }, reloadCore: false, save: false);

      manager.applyToClashConfig(rawConfig, 'test-profile-2');

      final proxies = rawConfig['proxies'] as List;
      final chained = proxies.firstWhere(
        (p) => p['name'] == 'Sub-Node-A ➜ Landing-Node',
        orElse: () => null,
      );

      expect(chained, isNotNull);
      expect(chained['dialer-proxy'], 'Sub-Node-A');
      expect(chained['server'], '4.4.4.4');

      final groups = rawConfig['proxy-groups'] as List;
      final proxyGroup = groups.firstWhere((g) => g['name'] == 'PROXY');
      expect(proxyGroup['proxies'], contains('Sub-Node-A ➜ Landing-Node'));
    });
  });
}
