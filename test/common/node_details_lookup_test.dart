import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/node_details.dart';

void main() {
  test('provider name prefix and replacement find the underlying config', () {
    final raw = {
      'proxies': [
        {
          'name': 'Tokyo 01',
          'type': 'ss',
          'server': 'provider.example',
          'port': 443,
        },
      ],
    };
    final node = findProviderNodeConfig(raw, '[Office] Japan 01 ★', {
      'proxy-name': [
        {'pattern': r'^Tokyo (.*)$', 'target': r'Japan $1'},
      ],
      'additional-prefix': '[Office] ',
      'additional-suffix': ' ★',
      'udp': true,
    });
    expect(node?['server'], 'provider.example');
    expect(node?['udp'], isTrue);
    expect(node?['name'], '[Office] Japan 01 ★');
  });
  test(
    'evaluated names and generated nodes resolve exactly, without fuzzy matches',
    () {
      final raw = decodeNodeConfig('''
proxies:
  - {name: "🇯🇵 Tokyo · renamed", type: vless, server: scripted.example, port: 443}
  - {name: "🔗出口·Tokyo", type: socks5, server: exit.example, port: 1080}
proxy-groups:
  - {name: Auto, type: url-test, proxies: ["🇯🇵 Tokyo · renamed"]}
''');
      expect(
        findNodeConfig(raw, '🇯🇵 Tokyo · renamed')?['server'],
        'scripted.example',
      );
      expect(findNodeConfig(raw, '🔗出口·Tokyo')?['server'], 'exit.example');
      expect(findNodeConfig(raw, 'Auto')?['proxies'], ['🇯🇵 Tokyo · renamed']);
      expect(findNodeConfig(raw, 'Tokyo'), isNull);
    },
  );
}
