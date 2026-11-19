import 'dart:convert';

import 'package:yaml/yaml.dart';

/// Parse off the UI isolate when reading an evaluated config or provider file.
Map<String, dynamic> decodeNodeConfig(String content) {
  final value = loadYaml(content);
  return value is Map
      ? Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map)
      : <String, dynamic>{};
}

Map<String, dynamic>? findNodeConfig(Map<String, dynamic> config, String name) {
  for (final key in ['proxies', 'proxy-groups']) {
    for (final item in (config[key] as List?) ?? const []) {
      if (item is Map && item['name'] == name) {
        return Map<String, dynamic>.from(item);
      }
    }
  }
  return null;
}

Map<String, dynamic>? findProviderNodeConfig(
  Map<String, dynamic> config,
  String name,
  Map? overrides,
) {
  if (overrides?['override-expr'] case final List expressions
      when expressions.isNotEmpty) {
    return null;
  }
  for (final item
      in ((config['proxies'] as List?) ?? const []).whereType<Map>()) {
    var effectiveName = item['name']?.toString() ?? '';
    for (final rename
        in ((overrides?['proxy-name'] as List?) ?? const []).whereType<Map>()) {
      effectiveName = effectiveName.replaceAllMapped(
        RegExp(rename['pattern'].toString()),
        (match) {
          var target = rename['target']?.toString() ?? '';
          for (var i = match.groupCount; i >= 1; i--) {
            target = target.replaceAll('\$$i', match.group(i) ?? '');
          }
          return target;
        },
      );
    }
    effectiveName =
        '${overrides?['additional-prefix'] ?? ''}$effectiveName${overrides?['additional-suffix'] ?? ''}';
    if (effectiveName == name) {
      return {
        ...Map<String, dynamic>.from(item),
        for (final entry in (overrides ?? const {}).entries)
          if (!const {
            'proxy-name',
            'additional-prefix',
            'additional-suffix',
            'override-expr',
          }.contains(entry.key))
            entry.key.toString(): entry.value,
        'name': name,
      };
    }
  }
  return null;
}
