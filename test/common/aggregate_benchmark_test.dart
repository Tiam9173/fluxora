import 'package:fluxora/common/aggregate_merge.dart';
import 'package:fluxora/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merges a 1000-node member without dropping groups or rules', () async {
    final nodes = List.generate(
      1000,
      (index) => <String, dynamic>{'name': 'Node $index', 'type': 'ss'},
    );
    final groups = List.generate(
      50,
      (index) => <String, dynamic>{
        'name': 'Group $index',
        'type': 'select',
        'proxies': [
          for (var node = index * 20; node < (index + 1) * 20; node++)
            'Node $node',
        ],
      },
    );
    final rules = [
      for (var index = 0; index < 50; index++)
        'DOMAIN,group$index.example,Group $index',
    ];
    final raw = <String, dynamic>{
      'proxies': <dynamic>[],
      'proxy-groups': [
        {'name': 'Main', 'type': 'select', 'proxies': ['DIRECT']},
      ],
      'rules': ['MATCH,Main'],
    };
    final member = AggregateMemberConfig(
      profile: Profile(
        id: 'large',
        label: 'Large',
        autoUpdateDuration: Duration.zero,
      ),
      alias: 'Large',
      config: <String, dynamic>{
        'proxies': nodes,
        'proxy-groups': groups,
        'rules': rules,
      },
    );

    final watch = Stopwatch()..start();
    final report = await mergeAggregateMembers(
      raw,
      [member],
      resolveRuleProviderPath: (_, _) async => null,
      log: (_) {},
    );
    watch.stop();

    final mergedGroups = raw['proxy-groups'] as List;
    final mergedRules = (raw['rules'] as List).cast<String>();
    expect(mergedGroups.length, 51); // Main + 50 member groups
    expect(mergedRules.length, 51); // 50 member rules + MATCH
    expect(mergedRules.last, 'MATCH,Main');
    expect(report.isEmpty, isTrue);
    expect(
      mergedGroups.any(
        (group) => group is Map && group['name'] == '[Large] Group 0',
      ),
      isTrue,
    );
    // Keep the duration visible in test output without a brittle hard limit.
    // ignore: avoid_print
    print('1000-node aggregate merge: ${watch.elapsedMilliseconds} ms');
  });
}
