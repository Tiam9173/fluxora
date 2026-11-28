import 'dart:convert';

import 'package:fluxora/models/config.dart';
import 'package:fluxora/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('independent aggregates keep their settings when defaults change', () {
    final migrated = Config(
      themeProps: defaultThemeProps,
      aggregateMode: AggregateMode.full,
      aggregateMergeRules: false,
      profiles: [Profile.normal().copyWith(id: 'source')],
      currentProfileId: 'source',
      aggregates: const [
        AggregateProfile(id: 'work', name: 'Work', baseProfileId: 'source'),
        AggregateProfile(
          id: 'home',
          name: 'Home',
          baseProfileId: 'source',
          mode: AggregateMode.custom,
          mergeRules: true,
        ),
      ],
    ).withAggregateProfiles();
    final updated = migrated.copyWith(
      aggregateMode: AggregateMode.nodePool,
      aggregateMergeRules: true,
      currentProfileId: migrated.aggregates.first.profileId,
      currentAggregateId: 'work',
    );
    expect(updated.effectiveAggregateMode, AggregateMode.full);
    expect(updated.effectiveMergeRules, isFalse);
    final home = updated.copyWith(
      currentProfileId: migrated.aggregates.last.profileId,
    );
    expect(home.effectiveAggregateMode, AggregateMode.custom);
    expect(home.effectiveMergeRules, isTrue);
    expect(updated.withAggregateProfiles(), updated);
  });

  test('invalid aggregate references never claim a source subscription', () {
    const source = Profile(
      id: 'source',
      label: 'Source',
      url: 'https://example.test/sub',
      autoUpdateDuration: Duration(days: 1),
    );
    final config = Config(
      themeProps: defaultThemeProps,
      profiles: [source],
      currentProfileId: source.id,
      aggregates: const [
        AggregateProfile(
          id: 'a',
          name: 'A',
          profileId: 'source',
          baseProfileId: 'source',
        ),
        AggregateProfile(
          id: 'b',
          name: 'B',
          profileId: '../invalid',
          baseProfileId: 'missing',
        ),
      ],
    ).withAggregateProfiles();
    expect(config.profiles.first, source);
    expect(config.profiles, hasLength(3));
    expect(
      config.aggregates.map((a) => a.profileId),
      everyElement(isNot(anyOf('source', '../invalid'))),
    );
    expect(config.aggregates.last.baseProfileId, 'missing');
    expect(config.withAggregateProfiles(), config);
    expect(config.currentProfileId, source.id);
  });

  test(
    'a normal profile does not activate a persisted aggregate selection',
    () {
      final config = Config(
        themeProps: defaultThemeProps,
        currentProfileId: 'source',
        currentAggregateId: 'aggregate',
        aggregates: const [
          AggregateProfile(
            id: 'aggregate',
            name: 'Aggregate',
            profileId: 'generated',
            baseProfileId: 'source',
          ),
        ],
      );
      expect(config.currentAggregate, isNull);
    },
  );

  test(
    'migration creates independent selectable profiles and is idempotent',
    () {
      const base = Profile(
        id: 'base',
        label: 'Source',
        url: 'https://example.test/sub',
        autoUpdateDuration: Duration(days: 1),
        selectedMap: {'Select': 'node'},
      );
      final original = Config(
        themeProps: defaultThemeProps,
        profiles: [base],
        currentProfileId: 'base',
        currentAggregateId: 'work',
        aggregates: const [
          AggregateProfile(id: 'work', name: 'Work', baseProfileId: 'base'),
          AggregateProfile(id: 'home', name: 'Home', baseProfileId: 'base'),
        ],
      );
      final config = original.withAggregateProfiles();
      expect(config.profiles.first, base);
      expect(config.profiles, hasLength(3));
      expect(config.aggregates.map((a) => a.profileId).toSet(), hasLength(2));
      final work = config.profiles.getProfile(
        config.aggregates.first.profileId,
      )!;
      expect(work.label, 'Work');
      expect(work.url, isEmpty);
      expect(work.autoUpdate, isFalse);
      expect(config.currentProfileId, work.id);
      expect(config.withAggregateProfiles(), config);
      final restored = Config.fromJson(
        jsonDecode(jsonEncode(config)) as Map<String, dynamic>,
      ).withAggregateProfiles();
      expect(restored, config);
    },
  );

  test(
    'legacy global members become one independent aggregate without losing sources',
    () {
      const base = Profile(
        id: 'base',
        url: 'https://example.test/base',
        autoUpdateDuration: Duration(days: 1),
      );
      final member = base.copyWith(id: 'member', joinAggregate: true);
      final config = Config(
        themeProps: defaultThemeProps,
        profiles: [base, member],
        currentProfileId: base.id,
      ).withAggregateProfiles();
      expect(config.aggregates.single.baseProfileId, base.id);
      expect(config.aggregates.single.memberIds, [member.id]);
      expect(config.currentProfileId, config.aggregates.single.profileId);
      expect(config.profiles.getProfile(base.id), base);
      expect(
        config.profiles.getProfile(member.id),
        member.copyWith(joinAggregate: false),
      );
      expect(config.withAggregateProfiles(), config);
    },
  );

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

  test('aggregate keeps its own base subscription across app restarts', () {
    const aggregate = AggregateProfile(
      id: 'work',
      name: 'Work',
      baseProfileId: 'base',
      memberIds: ['member'],
    );

    final restored = AggregateProfile.fromJson(aggregate.toJson());

    expect(restored.baseProfileId, 'base');
    expect(restored.memberIds, ['member']);
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
