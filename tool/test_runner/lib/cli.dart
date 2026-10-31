/// Minimal `--key value` / `--flag` parser.
///
/// The runner deliberately avoids `package:args`: R7-1..R7-4 must not add
/// dependencies, and the surface is tiny.
Map<String, String> parseOptions(List<String> args) {
  final Map<String, String> options = <String, String>{};
  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    if (!arg.startsWith('--')) {
      continue;
    }
    final String key = arg.substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      options[key] = args[i + 1];
      i++;
    } else {
      options[key] = 'true';
    }
  }
  return options;
}

/// `true` when the flag is present and not explicitly `false`.
bool flag(Map<String, String> options, String key) {
  final String? value = options[key];
  return value != null && value != 'false';
}
