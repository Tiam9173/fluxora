import 'package:fluxora/common/aggregate_merge.dart';
import 'package:fluxora/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _member(String id, String label) {
  return Profile(
    id: id,
    label: label,
    autoUpdateDuration: Duration.zero,
  );
}

Future<AggregateMergeReport> _merge(
  Map<String, dynamic> raw,
  List<AggregateMemberConfig> members, {
  bool groups = true,
  bool rules = true,
  bool ruleProviders = true,
}) {
  return mergeAggregateMembers(
    raw,
    members,
    resolveRuleProviderPath: (_, _) async => null,
    mergeGroups: groups,
    mergeRules: rules,
    mergeRuleProviders: ruleProviders,
    log: (_) {},
  );
}

void main() {
  test('merges member groups and rules before the base MATCH rule', () async {
    final raw = <String, dynamic>{
      'proxies': [
        {'name': 'Base'},
      ],
      'proxy-groups': [
        {
          'name': 'Main',
          'type': 'select',
          'proxies': ['DIRECT'],
        },
      ],
      'rules': ['DOMAIN,base.example,DIRECT', 'MATCH,Main'],
    };
    final member = AggregateMemberConfig(
      profile: _member('m1', 'A'),
      alias: 'A',
      config: <String, dynamic>{
        'proxies': [
          {'name': 'HK 01'},
          {'name': 'US 01'},
        ],
        'proxy-groups': [
          {
            'name': 'Proxy',
            'type': 'select',
            'proxies': ['HK 01', 'US 01'],
          },
          {
            'name': 'Auto',
            'type': 'url-test',
            'proxies': ['HK 01', 'US 01'],
          },
        ],
        'rules': [
          'DOMAIN,example.com,Proxy',
          'DOMAIN,stale.example,Missing',
          'MATCH,Proxy',
        ],
      },
    );

    final report = await _merge(raw, [member]);

    final groups = raw['proxy-groups'] as List;
    final proxy = groups.firstWhere(
      (group) => group is Map && group['name'] == '[A] Proxy',
    ) as Map;
    expect(proxy['proxies'], ['[A] HK 01', '[A] US 01']);

    final rules = (raw['rules'] as List).cast<String>();
    expect(rules.first, 'DOMAIN,base.example,DIRECT');
    expect(rules, contains('DOMAIN,example.com,[A] Proxy'));
    expect(rules, isNot(contains('DOMAIN,stale.example,Missing')));
    expect(rules.last, 'MATCH,Main');
    expect(
      report.droppedRules,
      contains('DOMAIN,stale.example,Missing'),
    );
    expect(
      rules.where((rule) => rule.startsWith('MATCH,')).length,
      1,
    );
  });

  test('renames conflicting member groups and rewrites rule targets', () async {
    final raw = <String, dynamic>{
      'proxy-groups': [
        {
          'name': '[A] Proxy',
          'type': 'select',
          'proxies': ['DIRECT'],
        },
        {
          'name': 'Main',
          'type': 'select',
          'proxies': ['DIRECT'],
        },
      ],
      'rules': ['MATCH,Main'],
    };
    final member = AggregateMemberConfig(
      profile: _member('m1', 'A'),
      alias: 'A',
      config: <String, dynamic>{
        'proxies': [
          {'name': 'HK'},
        ],
        'proxy-groups': [
          {
            'name': 'Proxy',
            'type': 'select',
            'proxies': ['HK'],
          },
        ],
        'rules': ['DOMAIN,example.com,Proxy'],
      },
    );

    final report = await _merge(raw, [member]);

    final groups = raw['proxy-groups'] as List;
    expect(
      groups.any((group) => group is Map && group['name'] == '[A] Proxy (2)'),
      isTrue,
    );
    expect(report.groupRenames.single.from, '[A] Proxy');
    expect(report.groupRenames.single.to, '[A] Proxy (2)');
    expect(
      (raw['rules'] as List).cast<String>(),
      contains('DOMAIN,example.com,[A] Proxy (2)'),
    );
  });

  test('expands a member use group to direct nodes', () async {
    final raw = <String, dynamic>{
      'proxy-groups': [
        {'name': 'Main', 'type': 'select', 'proxies': ['DIRECT']},
      ],
      'rules': ['MATCH,Main'],
    };
    final member = AggregateMemberConfig(
      profile: _member('m1', 'A'),
      alias: 'A',
      config: <String, dynamic>{
        'proxies': [
          {'name': 'HK'},
          {'name': 'US'},
        ],
        'proxy-groups': [
          {
            'name': 'Provider group',
            'type': 'select',
            'use': ['member-provider'],
          },
        ],
      },
    );

    await _merge(raw, [member]);

    final group = (raw['proxy-groups'] as List).firstWhere(
      (item) => item is Map && item['name'] == '[A] Provider group',
    ) as Map;
    expect(group.containsKey('use'), isFalse);
    expect(group['proxies'], ['[A] HK', '[A] US']);
  });

  test('keeps use-group filters when expanding to direct nodes', () async {
    final raw = <String, dynamic>{
      'proxy-groups': [
        {'name': 'Main', 'type': 'select', 'proxies': ['DIRECT']},
      ],
      'rules': ['MATCH,Main'],
    };
    final member = AggregateMemberConfig(
      profile: _member('m1', 'A'),
      alias: 'A',
      config: <String, dynamic>{
        'proxies': [
          {'name': 'HK 01'},
          {'name': 'US 01'},
        ],
        'proxy-groups': [
          {
            'name': 'Filtered',
            'type': 'select',
            'use': ['member-provider'],
            'filter': 'HK',
            'exclude-filter': 'US',
          },
        ],
      },
    );

    await _merge(raw, [member]);

    final group = (raw['proxy-groups'] as List).firstWhere(
      (item) => item is Map && item['name'] == '[A] Filtered',
    ) as Map;
    expect(group['proxies'], ['[A] HK 01']);
  });

  test('rewrites SUB-RULE targets', () async {
    final raw = <String, dynamic>{
      'proxy-groups': [
        {'name': 'Main', 'type': 'select', 'proxies': ['DIRECT']},
      ],
      'rules': ['MATCH,Main'],
    };
    final member = AggregateMemberConfig(
      profile: _member('m1', 'A'),
      alias: 'A',
      config: <String, dynamic>{
        'proxies': [
          {'name': 'HK'},
        ],
        'proxy-groups': [
          {
            'name': 'Proxy',
            'type': 'select',
            'proxies': ['HK'],
          },
        ],
        'rules': ['SUB-RULE,(NETWORK,tcp),Proxy'],
      },
    );

    await _merge(raw, [member]);

    expect(
      (raw['rules'] as List).cast<String>(),
      contains('SUB-RULE,(NETWORK,tcp),[A] Proxy'),
    );
  });

  test('custom merge can skip groups and rules', () async {
    final raw = <String, dynamic>{
      'proxy-groups': [
        {'name': 'Main', 'type': 'select', 'proxies': ['DIRECT']},
      ],
      'rules': ['MATCH,Main'],
    };
    final member = AggregateMemberConfig(
      profile: _member('m1', 'A'),
      alias: 'A',
      config: <String, dynamic>{
        'proxies': [
          {'name': 'HK'},
        ],
        'proxy-groups': [
          {
            'name': 'Proxy',
            'type': 'select',
            'proxies': ['HK'],
          },
        ],
        'rules': ['DOMAIN,example.com,Proxy'],
      },
    );

    await _merge(raw, [member], groups: false, rules: false);

    expect(
      (raw['proxy-groups'] as List).any(
        (group) => group is Map && group['name'] == '[A] Proxy',
      ),
      isFalse,
    );
    expect((raw['rules'] as List).cast<String>(), ['MATCH,Main']);
  });

  test('merges inline rule providers and rewrites RULE-SET references', () async {
    final raw = <String, dynamic>{
      'proxy-groups': [
        {'name': 'Main', 'type': 'select', 'proxies': ['DIRECT']},
      ],
      'rules': ['MATCH,Main'],
    };
    final member = AggregateMemberConfig(
      profile: _member('m1', 'A'),
      alias: 'A',
      config: <String, dynamic>{
        'proxies': [
          {'name': 'HK'},
        ],
        'proxy-groups': [
          {
            'name': 'Proxy',
            'type': 'select',
            'proxies': ['HK'],
          },
        ],
        'rule-providers': {
          'ads': {
            'type': 'inline',
            'behavior': 'domain',
            'payload': ['DOMAIN,ads.example'],
          },
        },
        'rules': ['RULE-SET,ads,Proxy'],
      },
    );

    await _merge(raw, [member]);

    final providers = raw['rule-providers'] as Map;
    expect(providers.containsKey('agg_m1_ads'), isTrue);
    expect(
      (raw['rules'] as List).cast<String>(),
      contains('RULE-SET,agg_m1_ads,[A] Proxy'),
    );
  });
}
