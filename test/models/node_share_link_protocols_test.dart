import 'package:fluxora/models/manual_proxy_helper.dart';
import 'package:fluxora/models/node_share_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// 每个协议都要走同一条往返路径：节点 Map → 分享链接 → 解析回节点 Map。
///
/// 只断言"前缀是 `tuic://`"证明不了任何东西——字段名写错、query 参数名对不上
/// 解析器、密码里的特殊字符没转义，都能让链接看着正常、粘回导入框却失败。
/// 这个文件是 `node_share_link.dart` 那句"必须能被读回来"的验收。
void main() {
  Map<String, dynamic> roundTrip(Map<String, dynamic> proxy) {
    final link = NodeShareLink.fromProxy(proxy);
    expect(link, isNotNull, reason: '${proxy['type']} 应该能导出');
    expect(link, isNotEmpty, reason: '${proxy['type']} 导出了空串');
    final parsed = ManualProxyHelper.parseMultipleLinks(link!);
    expect(parsed, hasLength(1), reason: '${proxy['type']} 的链接没能解析回来');
    return parsed.first;
  }

  group('NodeShareLink 往返（新增协议）', () {
    test('ssr', () {
      final back = roundTrip(<String, dynamic>{
        'name': 'SSR 节点',
        'type': 'ssr',
        'server': 'ssr.example.net',
        'port': 8388,
        'cipher': 'aes-256-cfb',
        'password': 'p@ss/+word',
        'protocol': 'auth_sha1_v4',
        'obfs': 'tls1.2_ticket_auth',
        'obfs-param': 'obfs.example.net',
        'protocol-param': 'proto-param',
      });
      expect(back['type'], 'ssr');
      expect(back['cipher'], 'aes-256-cfb');
      // 内层 base64 里的 `+` 若没按 query 组件编码，读回来会变成空格。
      expect(back['password'], 'p@ss/+word');
      expect(back['protocol'], 'auth_sha1_v4');
      expect(back['obfs'], 'tls1.2_ticket_auth');
      expect(back['obfs-param'], 'obfs.example.net');
      expect(back['protocol-param'], 'proto-param');
      expect(back['name'], 'SSR 节点');
    });

    test('tuic', () {
      final back = roundTrip(<String, dynamic>{
        'name': 'TUIC 节点',
        'type': 'tuic',
        'server': 'tuic.example.net',
        'port': 8443,
        'uuid': 'd6c113f3-5304-4004-91df-b1426de5951f',
        'password': 'tuic-pass',
        'sni': 'tuic.example.net',
        'congestion-controller': 'cubic',
        'udp-relay-mode': 'quic',
      });
      expect(back['type'], 'tuic');
      expect(back['uuid'], 'd6c113f3-5304-4004-91df-b1426de5951f');
      expect(back['password'], 'tuic-pass');
      expect(back['congestion-controller'], 'cubic');
      expect(back['udp-relay-mode'], 'quic');
      expect(back['sni'], 'tuic.example.net');
    });

    test('hysteria v1（认证与带宽）', () {
      final back = roundTrip(<String, dynamic>{
        'name': 'HY1 节点',
        'type': 'hysteria',
        'server': 'hy.example.net',
        'port': 443,
        'auth-str': 'hy-auth',
        'up': '30 Mbps',
        'down': '100 Mbps',
        'sni': 'hy.example.net',
        'obfs': 'xplus',
      });
      expect(back['type'], 'hysteria');
      expect(back['auth_str'], 'hy-auth');
      expect(back['up'], '30 Mbps');
      expect(back['down'], '100 Mbps');
      expect(back['sni'], 'hy.example.net');
      expect(back['obfs'], 'xplus');
    });

    test('anytls', () {
      final back = roundTrip(<String, dynamic>{
        'name': 'AnyTLS 节点',
        'type': 'anytls',
        'server': 'at.example.net',
        'port': 443,
        'password': 'at-pass',
        'sni': 'at.example.net',
      });
      expect(back['type'], 'anytls');
      expect(back['password'], 'at-pass');
      expect(back['sni'], 'at.example.net');
    });

    test('snell（psk / 版本 / obfs）', () {
      final back = roundTrip(<String, dynamic>{
        'name': 'Snell 节点',
        'type': 'snell',
        'server': 'sn.example.net',
        'port': 443,
        'psk': 'snell-psk',
        'version': 4,
        'obfs-opts': {'mode': 'http', 'host': 'bing.com'},
      });
      expect(back['type'], 'snell');
      expect(back['psk'], 'snell-psk');
      expect(back['version'], 4);
      expect(back['obfs-opts'], {'mode': 'http', 'host': 'bing.com'});
    });

    test('ssh（用户名与密码）', () {
      final back = roundTrip(<String, dynamic>{
        'name': 'SSH 节点',
        'type': 'ssh',
        'server': 'ssh.example.net',
        'port': 22,
        'username': 'root',
        'password': 'ssh-pass',
      });
      expect(back['type'], 'ssh');
      expect(back['username'], 'root');
      expect(back['password'], 'ssh-pass');
    });

    test('shadow-tls', () {
      final back = roundTrip(<String, dynamic>{
        'name': 'ShadowTLS 节点',
        'type': 'shadow-tls',
        'server': 'st.example.net',
        'port': 443,
        'password': 'st-pass',
        'sni': 'st.example.net',
        'version': 3,
      });
      expect(back['type'], 'shadow-tls');
      expect(back['password'], 'st-pass');
      expect(back['sni'], 'st.example.net');
      expect(back['version'], 3);
    });

    test('wireguard（密钥与地址）', () {
      final back = roundTrip(<String, dynamic>{
        'name': 'WG 节点',
        'type': 'wireguard',
        'server': 'wg.example.net',
        'port': 51820,
        'private-key': 'priv-key',
        'public-key': 'pub-key',
        'ip': '10.0.0.2',
        'preshared-key': 'psk-key',
      });
      expect(back['type'], 'wireguard');
      expect(back['private-key'], 'priv-key');
      expect(back['public-key'], 'pub-key');
      expect(back['ip'], '10.0.0.2');
      expect(back['preshared-key'], 'psk-key');
    });

    test('direct', () {
      final back = roundTrip(<String, dynamic>{'name': '直连', 'type': 'direct'});
      expect(back['type'], 'direct');
      expect(back['name'], '直连');
    });

    test('带 tls 的 http 代理导出成 https，否则读回来会丢掉 TLS', () {
      final back = roundTrip(<String, dynamic>{
        'name': 'HTTPS 代理',
        'type': 'http',
        'server': 'proxy.example.net',
        'port': 443,
        'username': 'user',
        'password': 'pass',
        'tls': true,
      });
      expect(back['type'], 'http');
      expect(back['tls'], isTrue);
      expect(back['username'], 'user');
    });

    test('trojan 的 ws 传输导出后不会退化成裸 tcp', () {
      final back = roundTrip(<String, dynamic>{
        'name': 'Trojan WS',
        'type': 'trojan',
        'server': 'tj.example.net',
        'port': 443,
        'password': 'tj-pass',
        'network': 'ws',
        'ws-opts': {
          'path': '/ws',
          'headers': {'Host': 'cdn.example.net'},
        },
      });
      expect(back['type'], 'trojan');
      expect(back['network'], 'ws');
      expect(back['ws-opts'], {
        'path': '/ws',
        'headers': {'Host': 'cdn.example.net'},
      });
    });

  });
}
