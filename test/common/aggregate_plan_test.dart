import 'package:fluxora/common/aggregate_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aggregate aliases are unique and keep the first spelling', () {
    final used = <String>{};

    expect(uniqueAggregateAlias('Airport A', used), 'Airport A');
    expect(uniqueAggregateAlias('airport a', used), 'airport a (2)');
    expect(uniqueAggregateAlias('Airport A', used), 'Airport A (3)');
  });

  test('empty aggregate alias falls back to a stable label', () {
    final used = <String>{};

    expect(uniqueAggregateAlias('   ', used), 'Profile');
    expect(uniqueAggregateAlias('', used), 'Profile (2)');
  });

  test('merged group names stay unique', () {
    final used = <String>{'[A] Proxy'};

    expect(
      uniqueAggregateGroupName('[A] Proxy', used),
      '[A] Proxy (2)',
    );
    used.add('[A] Proxy (2)');
    expect(
      uniqueAggregateGroupName('[A] Proxy', used),
      '[A] Proxy (3)',
    );
  });

  test('rule targets map nodes, groups, built-ins and base groups', () {
    final nodeNames = {'HK 01': '[A] HK 01'};
    final groupNames = {'Proxy': '[A] Proxy'};
    final baseGroups = {'Main'};

    expect(
      mapAggregateRuleTarget(
        'HK 01',
        nodeNames: nodeNames,
        groupNames: groupNames,
        baseGroups: baseGroups,
      ),
      '[A] HK 01',
    );
    expect(
      mapAggregateRuleTarget(
        'Proxy',
        nodeNames: nodeNames,
        groupNames: groupNames,
        baseGroups: baseGroups,
      ),
      '[A] Proxy',
    );
    expect(
      mapAggregateRuleTarget(
        'DIRECT',
        nodeNames: nodeNames,
        groupNames: groupNames,
        baseGroups: baseGroups,
      ),
      'DIRECT',
    );
    expect(
      mapAggregateRuleTarget(
        'Main',
        nodeNames: nodeNames,
        groupNames: groupNames,
        baseGroups: baseGroups,
      ),
      'Main',
    );
    expect(
      mapAggregateRuleTarget(
        'Missing',
        nodeNames: nodeNames,
        groupNames: groupNames,
        baseGroups: baseGroups,
      ),
      isNull,
    );
  });
}
