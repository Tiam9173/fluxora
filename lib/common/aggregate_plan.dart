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
