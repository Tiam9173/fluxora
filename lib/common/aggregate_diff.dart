class AggregateConfigSummary {
  final Set<String> nodes;
  final Set<String> groups;
  final Set<String> rules;

  const AggregateConfigSummary({
    required this.nodes,
    required this.groups,
    required this.rules,
  });

  factory AggregateConfigSummary.fromConfig(Map<String, dynamic> config) {
    final proxies = config['proxies'];
    final groups = config['proxy-groups'];
    final rules = config['rules'];
    return AggregateConfigSummary(
      nodes: proxies is List
          ? proxies
                .whereType<Map>()
                .map((node) => node['name'])
                .whereType<String>()
                .toSet()
          : <String>{},
      groups: groups is List
          ? groups
                .whereType<Map>()
                .map((group) => group['name'])
                .whereType<String>()
                .toSet()
          : <String>{},
      rules: rules is List ? rules.whereType<String>().toSet() : <String>{},
    );
  }
}

class AggregateConfigDiff {
  final List<String> addedNodes;
  final List<String> removedNodes;
  final List<String> addedGroups;
  final List<String> removedGroups;
  final List<String> addedRules;
  final List<String> removedRules;

  const AggregateConfigDiff({
    required this.addedNodes,
    required this.removedNodes,
    required this.addedGroups,
    required this.removedGroups,
    required this.addedRules,
    required this.removedRules,
  });

  bool get isEmpty =>
      addedNodes.isEmpty &&
      removedNodes.isEmpty &&
      addedGroups.isEmpty &&
      removedGroups.isEmpty &&
      addedRules.isEmpty &&
      removedRules.isEmpty;

  factory AggregateConfigDiff.between(
    AggregateConfigSummary previous,
    AggregateConfigSummary current,
  ) {
    List<String> added(Set<String> before, Set<String> after) =>
        after.difference(before).toList()..sort();
    List<String> removed(Set<String> before, Set<String> after) =>
        before.difference(after).toList()..sort();
    return AggregateConfigDiff(
      addedNodes: added(previous.nodes, current.nodes),
      removedNodes: removed(previous.nodes, current.nodes),
      addedGroups: added(previous.groups, current.groups),
      removedGroups: removed(previous.groups, current.groups),
      addedRules: added(previous.rules, current.rules),
      removedRules: removed(previous.rules, current.rules),
    );
  }
}
