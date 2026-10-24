import 'package:fluxora/models/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('named aggregates override global merge settings', () {
    final config = Config(
      themeProps: defaultThemeProps,
      aggregateMode: AggregateMode.full,
      aggregateScriptTiming: AggregateScriptTiming.before,
      aggregateMergeNodes: false,
      aggregateMergeRules: false,
      aggregates: const [
        AggregateProfile(
          id: 'work',
          name: 'Work',
          memberIds: ['p1'],
          mode: AggregateMode.custom,
          scriptTiming: AggregateScriptTiming.after,
          mergeNodes: true,
          mergeRules: true,
        ),
      ],
      currentAggregateId: 'work',
    );

    expect(config.effectiveAggregateMode, AggregateMode.custom);
    expect(config.effectiveScriptTiming, AggregateScriptTiming.after);
    expect(config.effectiveMergeNodes, isTrue);
    expect(config.effectiveMergeRules, isTrue);
  });

  test('default aggregate falls back to global merge settings', () {
    final config = Config(
      themeProps: defaultThemeProps,
      aggregateMode: AggregateMode.nodePool,
      aggregateScriptTiming: AggregateScriptTiming.before,
      aggregateMergeNodes: false,
      aggregateMergeRules: false,
    );

    expect(config.currentAggregate, isNull);
    expect(config.effectiveAggregateMode, AggregateMode.nodePool);
    expect(config.effectiveScriptTiming, AggregateScriptTiming.before);
    expect(config.effectiveMergeNodes, isFalse);
    expect(config.effectiveMergeRules, isFalse);
  });
}
