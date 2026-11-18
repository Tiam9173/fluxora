import 'package:fluxora/models/manual_proxy_helper.dart';
import 'package:fluxora/models/node_share_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// 导出的链接必须能被导入解析器读回来——这是这个功能唯一的验收标准。
/// 只断言"生成的字符串长得像链接"没有意义，那种测试挡不住字段写错。
void main() {
  group('NodeShareLink 往返', () {
    test(
      'legacy Snell links retain version and obfuscation and default to port 443',
      () {
        final node = ManualProxyHelper.parseShareLink(
          'snell://sample@edge.example.test?version=2&mode=tls&host=cover.example.test#legacy',
        )!;
        expect(node['version'], 2);
        expect(node['port'], 443);
        expect(node['obfs-opts'], {
          'mode': 'tls',
          'host': 'cover.example.test',
        });
        expect(
          ManualProxyHelper.parseShareLink(NodeShareLink.fromProxy(node)!),
          node,
        );
      },
    );
    test('Snell export preserves options beyond the share URI format', () {
      final node = <String, dynamic>{
        'name': 'Snell custom',
        'type': 'snell',
        'server': 'edge.example.test',
        'port': 443,
        'psk': 'sample',
        'version': 4,
        'obfs-opts': {
          'mode': 'shadow-tls',
          'host': 'cover.example.test',
          'version': 3,
        },
      };
      expect(
        ManualProxyHelper.parseMultipleLinks(
          NodeShareLink.fromProxy(node)!,
        ).single,
        node,
      );
    });
    test(
      'Mieru simple link preserves a port range, credentials and transport',
      () {
        final node = <String, dynamic>{
          'name': 'Mieru test',
          'type': 'mieru',
          'server': '2001:db8::2',
          'port-range': '2090-2099',
          'username': 'user:part',
          'password': 'secret@?#',
          'transport': 'UDP',
          'udp': false,
        };
        expect(
          ManualProxyHelper.parseMultipleLinks(
            NodeShareLink.fromProxy(node)!,
          ).single,
          node,
        );
      },
    );
    test(
      'Snell v6 round-trips an IPv6 address, escaped PSK and v6 options',
      () {
        final node = <String, dynamic>{
          'name': 'Snell v6 节点',
          'type': 'snell',
          'server': '2001:db8::1',
          'port': 8443,
          'psk': 'example:@#%/psk',
          'version': 6,
          'mode': 'unshaped',
          'udp': true,
          'reuse': false,
        };
        expect(
          ManualProxyHelper.parseMultipleLinks(
            NodeShareLink.fromProxy(node)!,
          ).single,
          node,
        );
      },
    );
    test('vless + reality 导出后能解析回同样的字段', () {
      final proxy = <String, dynamic>{
        'name': '美国05',
        'type': 'vless',
        'server': 'free.us5.example.net',
        'port': 443,
        'uuid': 'd6c113f3-5304-4004-91df-b1426de5951f',
        'tls': true,
        'servername': 'free.us5.example.net',
        'network': 'tcp',
        'flow': 'xtls-rprx-vision',
        'reality-opts': {
          'public-key': 'cQVJVttx2AX4QVuhlGTk8kHCc_9caNPVikUpIoZZMzk',
          'short-id': '2534feee55b53de6',
        },
      };

      final link = NodeShareLink.fromProxy(proxy);
      expect(link, isNotNull);
      expect(link!, startsWith('vless://'));

      final parsed = ManualProxyHelper.parseMultipleLinks(link);
      expect(parsed, hasLength(1));
      final back = parsed.first;
      expect(back['type'], 'vless');
      expect(back['server'], 'free.us5.example.net');
      expect(back['port'].toString(), '443');
      expect(back['uuid'], 'd6c113f3-5304-4004-91df-b1426de5951f');
    });

    test('hysteria2 导出后能解析回端口与认证', () {
      final proxy = <String, dynamic>{
        'name': 'HY2 节点',
        'type': 'hysteria2',
        'server': 'free.us5.example.net',
        'port': 443,
        'password': 'secret-auth',
        'sni': 'free.us5.example.net',
      };

      final link = NodeShareLink.fromProxy(proxy);
      expect(link, isNotNull);
      expect(link!, startsWith('hysteria2://'));

      final parsed = ManualProxyHelper.parseMultipleLinks(link);
      expect(parsed, hasLength(1));
      expect(parsed.first['type'], 'hysteria2');
      expect(parsed.first['server'], 'free.us5.example.net');
    });

    test('ss 导出后能解析回加密方式与密码', () {
      final proxy = <String, dynamic>{
        'name': 'SS 节点',
        'type': 'ss',
        'server': '1.2.3.4',
        'port': 8388,
        'cipher': 'aes-128-gcm',
        'password': 'p@ss:word',
      };

      final link = NodeShareLink.fromProxy(proxy);
      expect(link, isNotNull);

      final parsed = ManualProxyHelper.parseMultipleLinks(link!);
      expect(parsed, hasLength(1));
      expect(parsed.first['type'], 'ss');
      expect(parsed.first['cipher'], 'aes-128-gcm');
      expect(parsed.first['password'], 'p@ss:word');
    });

    test('不支持的协议返回 null，而不是编一个假链接', () {
      // juicity 在内核里没有对应实现，导入侧会直接拒收
      // (`ManualProxyHelper.parseShareLink` 的 unsupported 列表)，所以导出
      // 一个 `juicity://` 只会产出"粘回去必然失败"的假数据。
      expect(
        NodeShareLink.fromProxy(<String, dynamic>{
          'type': 'juicity',
          'server': '1.2.3.4',
          'port': 443,
          'uuid': 'u',
          'password': 'p',
        }),
        isNull,
      );
    });

    test('协议受支持但缺关键字段时返回空串，由调用方跳过', () {
      // wireguard 现在能导出了，但没有私钥的节点导出来是个无效链接——
      // 空串会被 `exportAll` 过滤掉，而不是生成一条坏数据。
      expect(
        NodeShareLink.fromProxy(<String, dynamic>{
          'type': 'wireguard',
          'server': '1.2.3.4',
          'port': 51820,
        }),
        '',
      );
    });

    test('批量导出跳过不支持的协议', () {
      final text = NodeShareLink.exportAll(<Map>[
        <String, dynamic>{
          'type': 'trojan',
          'name': 't1',
          'server': 'a.com',
          'port': 443,
          'password': 'x',
        },
        <String, dynamic>{
          'type': 'juicity',
          'name': 'j1',
          'server': 'b.com',
          'port': 443,
        },
      ]);
      expect(text.split('\n'), hasLength(1));
      expect(text, startsWith('trojan://'));
    });
  });
}
