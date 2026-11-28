import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/aggregate_merge.dart';
import 'package:fluxora/common/provider_script.dart';
import 'package:fluxora/models/models.dart';

void main() {
  test(
    'provider groups retain their source scope during aggregate merge',
    () async {
      final source = <String, dynamic>{
        'proxies': [
          {'name': 'Local', 'type': 'direct'},
        ],
        'proxy-providers': {
          'first': {
            'type': 'inline',
            'payload': [
              {'name': 'HK', 'type': 'trojan'},
              {'name': 'US', 'type': 'ss'},
            ],
          },
          'second': {
            'type': 'inline',
            'payload': [
              {'name': 'HK', 'type': 'ss'},
            ],
          },
        },
        'proxy-groups': [
          {
            'name': 'One',
            'type': 'select',
            'use': ['first'],
            'filter': r'(?i)^hk$',
          },
          {
            'name': 'Two',
            'type': 'select',
            'use': ['second'],
            'proxies': ['DIRECT'],
          },
          {
            'name': 'All',
            'type': 'url-test',
            'include-all-providers': true,
            'exclude-filter': r'^US$',
          },
          {'name': 'Inline', 'type': 'select', 'include-all-proxies': true},
        ],
        'rules': ['MATCH,One'],
      };
      final output = await materializeProviderNodes(
        source,
        (definition) async =>
            (definition['payload'] as List).cast<Map<String, dynamic>>(),
        flattenGroups: true,
      );
      final groups = output['proxy-groups'] as List;
      expect(groups[0]['proxies'], ['HK']);
      expect(groups[1]['proxies'], ['DIRECT', 'HK[second]']);
      expect(groups[2]['proxies'], ['HK', 'HK[second]']);
      expect(groups[3]['proxies'], ['Local']);
      expect(output.containsKey('proxy-providers'), false);
      expect((source['proxy-groups'] as List).first['use'], ['first']);
      final aggregate = <String, dynamic>{'proxy-groups': [], 'rules': []};
      await mergeAggregateMembers(aggregate, [
        AggregateMemberConfig(
          profile: const Profile(
            id: 'provider-member',
            autoUpdateDuration: Duration.zero,
          ),
          config: output,
          alias: 'Member',
        ),
      ], resolveRuleProviderPath: (_, _) async => null);
      final merged = aggregate['proxy-groups'] as List;
      expect(merged[0]['proxies'], ['[Member] HK']);
      expect(merged[1]['proxies'], ['DIRECT', '[Member] HK[second]']);
      expect(merged[2]['proxies'], ['[Member] HK', '[Member] HK[second]']);
      expect(aggregate['rules'], ['MATCH,[Member] One']);
      expect(
        merged.any(
          (g) => g.containsKey('use') || g.containsKey('include-all-providers'),
        ),
        false,
      );
    },
  );

  test(
    'snapshot refresh preserves the source and does not reuse old nodes',
    () async {
      final source = <String, dynamic>{
        'proxy-providers': {
          'remote': {'type': 'http'},
        },
      };
      var version = 0;
      Future<List<Map<String, dynamic>>> load(Map _) async => [
        {'name': 'node-${++version}'},
      ];
      final first = await materializeProviderNodes(
        source,
        load,
        flattenGroups: true,
      );
      final second = await materializeProviderNodes(
        source,
        load,
        flattenGroups: true,
      );
      expect((first['proxies'] as List).single['name'], 'node-1');
      expect((second['proxies'] as List).single['name'], 'node-2');
      expect(source.containsKey('proxies'), false);
    },
  );

  test(
    'provider input preserves source, TLS identity and chain references',
    () async {
      final source = <String, dynamic>{
        'proxies': [
          {'name': 'entry', 'type': 'direct'},
        ],
        'proxy-providers': {
          'source': {'type': 'inline'},
        },
      };
      final output = await materializeProviderNodes(
        source,
        (_) async => [
          {'name': 'entry', 'type': 'socks5', 'server': 'entry.example.test'},
          {
            'name': 'exit',
            'type': 'trojan',
            'server': 'tls.example.test',
            'sni': 'tls.example.test',
            'dialer-proxy': 'entry',
            'skip-cert-verify': false,
          },
        ],
      );
      final nodes = output['proxies'] as List;
      expect(nodes.map((node) => node['name']), [
        'entry',
        'entry[source]',
        'exit',
      ]);
      expect(nodes.last['dialer-proxy'], 'entry[source]');
      expect(nodes.last['server'], 'tls.example.test');
      expect(nodes.last['sni'], 'tls.example.test');
      expect(nodes.last['skip-cert-verify'], false);
      expect(source['proxies'], hasLength(1));
      expect(output['proxy-providers'], source['proxy-providers']);
    },
  );

  test('provider-aware scripts run once without downloading', () async {
    var calls = 0;
    final source = <String, dynamic>{
      'proxy-providers': {
        'source': {'type': 'http'},
      },
    };
    final output = await evaluateProviderScript(source, (input) async {
      calls++;
      return input;
    }, (_) async => throw StateError('unexpected download'));
    expect(output, source);
    expect(calls, 1);
  });

  test(
    'missing-inline-node scripts can use provider-only subscriptions',
    () async {
      var calls = 0;
      final output = await evaluateProviderScript(
        {
          'proxy-providers': {
            'source': {'type': 'http'},
          },
        },
        (input) async {
          calls++;
          if (input['proxies'] == null) throw StateError('配置文件中未找到任何代理节点');
          return {
            'proxies': input['proxies'],
            'rules': ['MATCH,PROXY'],
          };
        },
        (_) async => [
          {'name': 'node', 'type': 'socks5', 'server': 'fixture.invalid'},
        ],
      );
      expect(calls, 2);
      expect(output['proxies'], hasLength(1));
    },
  );

  test('syntax errors do not trigger downloads or execute twice', () async {
    await expectLater(
      evaluateProviderScript(
        {
          'proxy-providers': {
            'source': {'type': 'http'},
          },
        },
        (_) async => throw const FormatException('unexpected token'),
        (_) async => throw StateError('unexpected download'),
      ),
      throwsFormatException,
    );
  });

  test(
    'duplicate renamed provider nodes fail before corrupting references',
    () async {
      await expectLater(
        materializeProviderNodes(
          {
            'proxy-providers': {
              'source': {'type': 'inline'},
            },
          },
          (_) async => [
            {'name': 'same'},
            {'name': 'same'},
          ],
        ),
        throwsFormatException,
      );
    },
  );

  test('a failed provider does not publish a partial snapshot', () async {
    final source = <String, dynamic>{
      'proxy-providers': {
        'first': {'type': 'inline'},
        'second': {'type': 'http'},
      },
    };
    var calls = 0;
    await expectLater(
      materializeProviderNodes(source, (_) async {
        if (++calls == 2) throw StateError('offline');
        return [
          {'name': 'first'},
        ];
      }),
      throwsStateError,
    );
    expect(source.containsKey('proxies'), false);
  });
}
