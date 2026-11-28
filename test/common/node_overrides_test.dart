import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/node_overrides.dart';
import 'package:fluxora/common/provider_script.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  test(
    'rename-only edits retain groups, rules, chain links and TLS identity',
    () async {
      final store = NodeOverrideStore.instance;
      await store.setRename('provider-rename', 'entry', 'renamed');
      addTearDown(() => store.setRename('provider-rename', 'entry', ''));
      final source = <String, dynamic>{
        'proxy-providers': {
          'remote': {'type': 'inline'},
        },
        'proxy-groups': [
          {
            'name': 'Select',
            'type': 'select',
            'use': ['remote'],
          },
        ],
        'rules': ['MATCH,entry', 'IP-CIDR,192.0.2.0/24,entry,no-resolve'],
      };
      final output = await evaluateProviderScript(
        source,
        (input) async {
          if (input['proxies'] == null) throw StateError('no proxy nodes');
          return input;
        },
        (_) async => [
          {'name': 'entry', 'type': 'socks5'},
          {
            'name': 'exit',
            'type': 'trojan',
            'dialer-proxy': 'entry',
            'server': 'tls.example.test',
            'sni': 'tls.example.test',
            'skip-cert-verify': false,
          },
        ],
        applyNodeOverrides: (input) => store.apply('provider-rename', input),
      );
      final nodes = output['proxies'] as List;
      expect(nodes.first['name'], 'renamed');
      expect(nodes.last['dialer-proxy'], 'renamed');
      expect(nodes.last['server'], 'tls.example.test');
      expect(nodes.last['sni'], 'tls.example.test');
      expect(nodes.last['skip-cert-verify'], false);
      expect((output['proxy-groups'] as List).single['proxies'], [
        'renamed',
        'exit',
      ]);
      expect(output['rules'], [
        'MATCH,renamed',
        'IP-CIDR,192.0.2.0/24,renamed,no-resolve',
      ]);
      expect(source.containsKey('proxies'), false);
    },
  );
}
