import 'package:fluxora/common/profile_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> config() => {
    'proxies': [
      {'name': 'node', 'type': 'trojan', 'server': 'edge.example'},
    ],
    'proxy-groups': [
      {
        'name': 'Select',
        'type': 'select',
        'proxies': ['node'],
      },
    ],
    'rules': ['DOMAIN,blocked.example,REJECT', 'MATCH,PROXY'],
  };

  test(
    'repairs a missing import target without dropping rules or TLS names',
    () {
      final raw = config();
      expect(ensureDefaultProxyTarget(raw), isTrue);
      expect(raw['proxy-groups'], [
        {
          'name': 'Select',
          'type': 'select',
          'proxies': ['node'],
        },
        {
          'name': 'PROXY',
          'type': 'select',
          'proxies': ['node'],
        },
      ]);
      expect(raw['rules'], ['DOMAIN,blocked.example,REJECT', 'MATCH,PROXY']);
      expect(raw['proxies'].single['server'], 'edge.example');
      expect(ensureDefaultProxyTarget(raw), isFalse);
    },
  );

  test('supports provider-only subscriptions and legacy rule keys', () {
    final raw = <String, dynamic>{
      'proxy-providers': {
        'remote': {'type': 'file', 'path': 'nodes.yaml'},
      },
      'rule': ['MATCH,PROXY'],
    };
    expect(ensureDefaultProxyTarget(raw), isTrue);
    expect(raw['proxy-groups'], [
      {
        'name': 'PROXY',
        'type': 'select',
        'use': ['remote'],
      },
    ]);
  });

  test('retains an existing PROXY node or group', () {
    for (final key in ['proxies', 'proxy-groups']) {
      final raw = config();
      (raw[key] as List).add({'name': 'PROXY'});
      expect(ensureDefaultProxyTarget(raw), isFalse);
    }
  });

  test(
    'does not invent direct routes, repair other targets or create cycles',
    () {
      final raw = config();
      raw['rules'] = ['MATCH,Missing'];
      expect(ensureDefaultProxyTarget(raw), isFalse);
      raw['rules'] = ['MATCH,PROXY'];
      raw['proxies'].single['dialer-proxy'] = 'PROXY';
      expect(ensureDefaultProxyTarget(raw), isFalse);
      raw['proxies'] = [
        {'name': 'DIRECT', 'type': 'direct'},
      ];
      expect(ensureDefaultProxyTarget(raw), isFalse);
      expect(raw['rules'], ['MATCH,PROXY']);
    },
  );
}
