/// Returns a display alias that is unique among [usedAliases].
///
/// Aggregate node names are prefixed with this alias. Two profiles with the
/// same alias would otherwise produce identical node names and make the
/// selection ambiguous, so the second one gets a numeric suffix.
String uniqueAggregateAlias(String preferred, Set<String> usedAliases) {
  final base = preferred.trim().isEmpty ? 'Profile' : preferred.trim();
  var candidate = base;
  var suffix = 2;
  while (usedAliases.contains(candidate.toLowerCase())) {
    candidate = '$base ($suffix)';
    suffix++;
  }
  usedAliases.add(candidate.toLowerCase());
  return candidate;
}

/// Makes a prefixed group name unique without touching the source name.
String uniqueAggregateGroupName(String candidate, Set<String> usedNames) {
  var name = candidate;
  var suffix = 2;
  while (usedNames.contains(name)) {
    name = '$candidate ($suffix)';
    suffix++;
  }
  return name;
}

bool isBuiltInAggregateTarget(String target) {
  return target == 'DIRECT' ||
      target == 'REJECT' ||
      target == 'REJECT-DROP' ||
      target == 'PASS' ||
      target == 'COMPATIBLE';
}

/// Remaps aggregate group/node selection entries when a member alias changes.
///
/// Selected entries use `[alias] name` for aggregate nodes and groups. Without
/// this, renaming the alias makes every previous selection point at a name that
/// no longer exists.
Map<String, String> remapAggregateSelection(
  Map<String, String> selected, {
  required String oldAlias,
  required String newAlias,
}) {
  if (oldAlias == newAlias) return selected;
  String remap(String value) {
    final prefix = '[$oldAlias] ';
    if (!value.startsWith(prefix)) return value;
    return '[$newAlias] ${value.substring(prefix.length)}';
  }

  return {
    for (final entry in selected.entries) remap(entry.key): remap(entry.value),
  };
}

/// Best-effort remap of aggregate selections after a script renames nodes.
///
/// Scripts often add a region flag or another prefix (`[A] HK` ->
/// `[A] 🇭🇰 HK`). When the old name is gone, a unique suffix match preserves
/// the selection instead of silently falling back to the first node.
Map<String, String> remapAggregateNodeSelections(
  Map<String, String> selected,
  Iterable<String> finalNames,
) {
  final names = finalNames.toSet();
  String? remap(String value) {
    if (!value.startsWith('[') || names.contains(value)) return value;
    final close = value.indexOf('] ');
    if (close == -1) return value;
    final original = value.substring(close + 2);
    if (original.isEmpty) return value;
    final matches = names
        .where((name) => name.endsWith(original) && name != value)
        .toList();
    return matches.length == 1 ? matches.single : value;
  }

  return {
    for (final entry in selected.entries)
      entry.key: remap(entry.value) ?? entry.value,
  };
}

/// Maps a member rule target to the merged namespace.
///
/// Returns null when the target belongs to a member group/node that was not
/// merged, so the caller can drop the rule instead of producing an invalid
/// config. Built-in targets and base groups are returned unchanged.
String? mapAggregateRuleTarget(
  String target, {
  required Map<String, String> nodeNames,
  required Map<String, String> groupNames,
  required Set<String> baseGroups,
}) {
  final mapped = nodeNames[target] ?? groupNames[target];
  if (mapped != null) return mapped;
  if (isBuiltInAggregateTarget(target) || baseGroups.contains(target)) {
    return target;
  }
  return null;
}
