import 'package:fluxora/models/manual_proxy_helper.dart';
import 'package:fluxora/models/node_share_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// 导出的链接必须能被导入解析器读回来——这是这个功能唯一的验收标准。
/// 只断言"生成的字符串长得像链接"没有意义，那种测试挡不住字段写错。
void main() {
  group('NodeShareLink 往返', () {
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
      expect(
        NodeShareLink.fromProxy(<String, dynamic>{
          'type': 'wireguard',
          'server': '1.2.3.4',
          'port': 51820,
        }),
        isNull,
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
          'type': 'wireguard',
          'name': 'w1',
          'server': 'b.com',
          'port': 51820,
        },
      ]);
      expect(text.split('\n'), hasLength(1));
      expect(text, startsWith('trojan://'));
    });
  });
}
