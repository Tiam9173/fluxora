/// P1 — tell a rule-provider *warning* apart from a real config error.
///
/// The core returns one human-readable string from `setupConfig`. Any non-empty
/// string was fatal, so a single unreachable ruleset on a CDN rejected the whole
/// config — and since a rejected config rolls back, the user could not switch
/// subscriptions at all. This predicate is what lets an opt-in user keep the
/// config and lose only that ruleset.
///
/// The rules are deliberately narrow, because the cost of guessing wrong is
/// asymmetric:
///
/// * **false positive** (calling a real error tolerable) ⇒ the user runs a broken
///   config with no idea;
/// * **false negative** (calling a warning fatal) ⇒ the old behaviour, annoying
///   but safe.
///
/// So: every non-empty line must look like a rule-provider warning, and anything
/// unrecognised is fatal.
bool isRuleProviderOnlyWarning(String message) {
  if (message.trim().isEmpty) return false;

  final warning = RegExp(
    r'^initial\s+rule\s+provider\s+\S+\s+error\s*:',
    caseSensitive: false,
  );

  for (final line in message.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (!warning.hasMatch(trimmed)) return false;
  }
  return true;
}
