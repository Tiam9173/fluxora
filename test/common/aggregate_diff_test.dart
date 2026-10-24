import 'package:fluxora/common/aggregate_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diff reports added and removed nodes, groups and rules', () {
    const previous = AggregateConfigSummary(
      nodes: {'A', 'B'},
      groups: {'Main', 'Old'},
      rules: {'DOMAIN,a.com,DIRECT', 'MATCH,Main'},
    );
    const current = AggregateConfigSummary(
      nodes: {'A', 'C'},
      groups: {'Main', 'New'},
      rules: {'DOMAIN,b.com,DIRECT', 'MATCH,Main'},
    );

    final diff = AggregateConfigDiff.between(previous, current);

    expect(diff.addedNodes, ['C']);
    expect(diff.removedNodes, ['B']);
    expect(diff.addedGroups, ['New']);
    expect(diff.removedGroups, ['Old']);
    expect(diff.addedRules, ['DOMAIN,b.com,DIRECT']);
    expect(diff.removedRules, ['DOMAIN,a.com,DIRECT']);
    expect(diff.isEmpty, isFalse);
  });

  test('identical summaries produce an empty diff', () {
    const summary = AggregateConfigSummary(
      nodes: {'A'},
      groups: {'Main'},
      rules: {'MATCH,Main'},
    );

    final diff = AggregateConfigDiff.between(summary, summary);

    expect(diff.isEmpty, isTrue);
  });
}
