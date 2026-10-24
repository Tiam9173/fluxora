import 'package:fluxora/common/aggregate_plan.dart';
import 'package:fluxora/common/print.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';

class AggregateGroupRename {
  final String alias;
  final String from;
  final String to;

  const AggregateGroupRename({
    required this.alias,
    required this.from,
    required this.to,
  });
}

class AggregateMergeReport {
  final List<AggregateGroupRename> groupRenames = [];
  final List<String> droppedRules = [];
  final List<String> droppedGroupProxies = [];
  final List<String> skippedProviders = [];

  bool get isEmpty =>
      groupRenames.isEmpty &&
      droppedRules.isEmpty &&
      droppedGroupProxies.isEmpty &&
      skippedProviders.isEmpty;
}

class AggregateMemberConfig {
  final Profile profile;
  final Map<String, dynamic> config;
  final String alias;

  const AggregateMemberConfig({
    required this.profile,
    required this.config,
    required this.alias,
  });
}

typedef AggregateRuleProviderPathResolver =
    Future<String?> Function(
      String profileId,
      Map<String, dynamic> provider,
    );

/// Merges member groups/rules/rule-providers into [rawConfig].
///
/// This is deliberately independent of Flutter state so the merge semantics can
/// be covered by unit tests. The caller owns provider path resolution.
Future<AggregateMergeReport> mergeAggregateMembers(
  Map<String, dynamic> rawConfig,
  List<AggregateMemberConfig> members, {
  required AggregateRuleProviderPathResolver resolveRuleProviderPath,
  bool mergeGroups = true,
  bool mergeRules = true,
  bool mergeRuleProviders = true,
  void Function(String message)? log,
}) async {
  final report = AggregateMergeReport();
  if (members.isEmpty) return report;
  final writeLog = log ?? commonPrint.log;

  final groups = rawConfig['proxy-groups'] is List
      ? List<dynamic>.from(rawConfig['proxy-groups'] as List)
      : <dynamic>[];
  rawConfig['proxy-groups'] = groups;
  final usedGroupNames = <String>{
    for (final group in groups)
      if (group is Map && group['name'] is String) group['name'] as String,
  };
  final baseRules = rawConfig['rules'] is List
      ? (rawConfig['rules'] as List).whereType<String>().toList()
      : <String>[];
  final baseHasMatch = baseRules.any(
    (rule) => ParsedRule.parseString(rule).ruleAction == RuleAction.MATCH,
  );
  final mergedRules = <String>[];
  String? fallbackMatch;

  for (final member in members) {
    final memberGroups = member.config['proxy-groups'];
    final memberProxies = member.config['proxies'];
    final nodeMap = <String, String>{
      for (final node in (memberProxies is List ? memberProxies : const []))
        if (node is Map && node['name'] is String)
          node['name'] as String: '[${member.alias}] ${node['name']}',
    };
    final groupMap = <String, String>{};
    if (mergeGroups && memberGroups is List) {
      for (final group in memberGroups) {
        if (group is! Map || group['name'] is! String) continue;
        final original = group['name'] as String;
        if (member.profile.groupSwitches[original] == false) continue;
        final candidate = '[${member.alias}] $original';
        final unique = uniqueAggregateGroupName(candidate, usedGroupNames);
        if (unique != candidate) {
          report.groupRenames.add(
            AggregateGroupRename(
              alias: member.alias,
              from: candidate,
              to: unique,
            ),
          );
        }
        groupMap[original] = unique;
        usedGroupNames.add(unique);
      }
    }

    final ruleProviderMap = mergeRuleProviders
        ? await _mergeRuleProviders(
            rawConfig,
            member,
            resolveRuleProviderPath: resolveRuleProviderPath,
            report: report,
            log: writeLog,
          )
        : const <String, String>{};

    if (mergeGroups && memberGroups is List) {
      for (final group in memberGroups) {
        if (group is! Map || group['name'] is! String) continue;
        final mappedName = groupMap[group['name'] as String];
        if (mappedName == null) continue;
        final copy = Map<String, dynamic>.from(group);
        copy['name'] = mappedName;
        final proxies = copy['proxies'];
        if (proxies is List) {
          final mappedProxies = proxies
              .map<String?>((item) {
                if (item is! String) return null;
                final mapped = nodeMap[item] ?? groupMap[item];
                if (mapped != null) return mapped;
                if (isBuiltInAggregateTarget(item) ||
                    usedGroupNames.contains(item)) {
                  return item;
                }
                writeLog(
                  'aggregate: drop unknown proxy "$item" from group $mappedName',
                );
                report.droppedGroupProxies.add('$mappedName: $item');
                return null;
              })
              .whereType<String>()
              .toList();
          copy['proxies'] = mappedProxies.isEmpty &&
                  (copy['use'] is! List || (copy['use'] as List).isEmpty)
              ? ['DIRECT']
              : mappedProxies;
        }
        final use = copy['use'];
        if (use is List && use.isNotEmpty) {
          // Full merge has no member provider to point at. Expand the group to
          // the member's direct nodes instead of leaving a dangling provider.
          // Keep filter/exclude-filter semantics while expanding.
          copy.remove('use');
          final existing = copy['proxies'];
          if (existing is! List || existing.isEmpty) {
            copy['proxies'] = _filterUseNodes(nodeMap, copy);
          }
        }
        groups.add(copy);
      }
    }

    if (!mergeRules) continue;
    final memberRules = member.config['rules'];
    if (memberRules is! List) continue;
    final baseGroupNames = {
      for (final group in groups)
        if (group is Map && group['name'] is String) group['name'] as String,
    };
    for (final rule in memberRules) {
      if (rule is! String || rule.isEmpty) continue;
      final parsed = ParsedRule.parseString(rule);
      if (parsed.ruleAction == RuleAction.MATCH) {
        // The base profile owns the catch-all rule. If it has none, keep one
        // member fallback at the very end so later member rules stay reachable.
        if (baseHasMatch) continue;
        var target = parsed.ruleTarget;
        if (target != null) target = groupMap[target] ?? target;
        fallbackMatch ??= parsed.copyWith(ruleTarget: target).value;
        continue;
      }
      var target = parsed.ruleTarget;
      if (target != null) {
        final mapped = mapAggregateRuleTarget(
          target,
          nodeNames: nodeMap,
          groupNames: groupMap,
          baseGroups: baseGroupNames,
        );
        if (mapped == null) {
          writeLog(
            'aggregate: skip rule with unknown target "$target" from ${member.profile.id}',
          );
          report.droppedRules.add(rule);
          continue;
        }
        target = mapped;
      }
      var subRule = parsed.subRule;
      if (subRule != null) {
        final mapped = mapAggregateRuleTarget(
          subRule,
          nodeNames: nodeMap,
          groupNames: groupMap,
          baseGroups: baseGroupNames,
        );
        if (mapped == null) {
          writeLog(
            'aggregate: skip SUB-RULE with unknown target "$subRule" from ${member.profile.id}',
          );
          report.droppedRules.add(rule);
          continue;
        }
        subRule = mapped;
      }
      var provider = parsed.ruleProvider;
      if (provider != null) {
        final mapped = ruleProviderMap[provider];
        if (mapped == null) {
          writeLog(
            'aggregate: skip rule with unmerged provider "$provider" from ${member.profile.id}',
          );
          report.droppedRules.add(rule);
          continue;
        }
        provider = mapped;
      }
      final next = parsed.copyWith(
        ruleTarget: target,
        subRule: subRule,
        ruleProvider: provider,
      );
      if (!baseRules.contains(next.value) && !mergedRules.contains(next.value)) {
        mergedRules.add(next.value);
      }
    }
  }

  if (fallbackMatch != null && !baseHasMatch) {
    mergedRules.add(fallbackMatch);
  }
  if (mergedRules.isEmpty) return report;
  final matchIndex = baseRules.indexWhere(
    (rule) => ParsedRule.parseString(rule).ruleAction == RuleAction.MATCH,
  );
  final nextRules = List<String>.from(baseRules);
  if (matchIndex == -1) {
    nextRules.addAll(mergedRules);
  } else {
    nextRules.insertAll(matchIndex, mergedRules);
  }
  rawConfig['rules'] = nextRules;
  return report;
}

List<String> _filterUseNodes(
  Map<String, String> nodeMap,
  Map<String, dynamic> group,
) {
  RegExp? include;
  RegExp? exclude;
  try {
    final filter = group['filter'];
    if (filter is String && filter.isNotEmpty) include = RegExp(filter);
    final excludeFilter = group['exclude-filter'];
    if (excludeFilter is String && excludeFilter.isNotEmpty) {
      exclude = RegExp(excludeFilter);
    }
  } catch (_) {
    // Invalid regex: keep all member nodes instead of producing an empty group.
  }
  final names = nodeMap.entries
      .where((entry) {
        if (include != null && !include.hasMatch(entry.key)) return false;
        if (exclude != null && exclude.hasMatch(entry.key)) return false;
        return true;
      })
      .map((entry) => entry.value)
      .toList();
  return names.isEmpty ? ['DIRECT'] : names;
}

Future<Map<String, String>> _mergeRuleProviders(
  Map<String, dynamic> rawConfig,
  AggregateMemberConfig member, {
  required AggregateRuleProviderPathResolver resolveRuleProviderPath,
  required AggregateMergeReport report,
  required void Function(String message) log,
}) async {
  final source = member.config['rule-providers'];
  if (source is! Map) return const {};
  final target = rawConfig['rule-providers'] is Map
      ? Map<String, dynamic>.from(rawConfig['rule-providers'] as Map)
      : <String, dynamic>{};
  final mapping = <String, String>{};
  for (final entry in source.entries) {
    final key = 'agg_${member.profile.id}_${entry.key}';
    final value = entry.value;
    if (value is! Map) continue;
    final copy = Map<String, dynamic>.from(value);
    final resolvedPath = await resolveRuleProviderPath(
      member.profile.id,
      copy,
    );
    if (resolvedPath == null && copy['type'] == 'file') {
      log(
        'aggregate: skip file rule-provider "${entry.key}" from ${member.profile.id}, path not found',
      );
      report.skippedProviders.add('${member.alias}: ${entry.key}');
      continue;
    }
    if (resolvedPath != null) copy['path'] = resolvedPath;
    target[key] = copy;
    mapping[entry.key.toString()] = key;
  }
  if (target.isNotEmpty) rawConfig['rule-providers'] = target;
  return mapping;
}
