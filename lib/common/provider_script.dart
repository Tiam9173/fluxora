import 'dart:convert';

/// 将 provider 的节点加入脚本输入；原订阅及 provider 定义保持独立。
Future<Map<String, dynamic>> materializeProviderNodes(
  Map<String, dynamic> config,
  Future<List<Map<String, dynamic>>> Function(Map) readNodes, {
  bool flattenGroups = false,
}) async {
  final providers = config['proxy-providers'];
  if (providers is! Map || providers.isEmpty) return config;
  final result = jsonDecode(jsonEncode(config)) as Map<String, dynamic>;
  final nodes = (result['proxies'] as List? ?? []).toList();
  final inlineNames = nodes
      .whereType<Map>()
      .map((node) => node['name'])
      .whereType<String>()
      .toList();
  final names = <String>{
    ...inlineNames,
    'DIRECT',
    'REJECT',
    'REJECT-DROP',
    'PASS',
    'COMPATIBLE',
    for (final group in result['proxy-groups'] as List? ?? [])
      if (group is Map && group['name'] is String) group['name'] as String,
  };
  final providerNames = <String, Map<String, String>>{};
  for (final entry in providers.entries) {
    if (entry.value is! Map) throw const FormatException('Invalid provider');
    final loaded = await readNodes(entry.value as Map);
    final renamed = <String, String>{};
    for (final node in loaded) {
      final name = node['name'];
      if (name is! String || name.isEmpty) {
        throw const FormatException('Unnamed provider node');
      }
      if (renamed.containsKey(name)) {
        throw const FormatException('Duplicate provider node name');
      }
      var unique = name;
      var suffix = 1;
      while (!names.add(unique)) {
        unique = '$name[${entry.key}]${suffix == 1 ? '' : ' $suffix'}';
        suffix++;
      }
      renamed[name] = unique;
    }
    providerNames[entry.key.toString()] = renamed;
    for (final node in loaded) {
      nodes.add({
        ...node,
        'name': renamed[node['name']],
        if (renamed.containsKey(node['dialer-proxy']))
          'dialer-proxy': renamed[node['dialer-proxy']],
      });
    }
  }
  result['proxies'] = nodes;
  if (flattenGroups) {
    for (final group in result['proxy-groups'] as List? ?? []) {
      if (group is! Map) continue;
      final allProxies =
          group['include-all'] == true || group['include-all-proxies'] == true;
      final allProviders =
          group['include-all'] == true ||
          group['include-all-providers'] == true;
      final use = allProviders
          ? providerNames.keys
          : (group['use'] as List? ?? []).cast<String>();
      final selected = <String>[
        ...(group['proxies'] as List? ?? []).cast<String>(),
      ];
      final include = _nameFilters(group['filter']);
      final exclude = _nameFilters(group['exclude-filter']);
      final originalNames = {
        for (final names in providerNames.values)
          for (final entry in names.entries) entry.value: entry.key,
      };
      bool matches(String name) =>
          include.isEmpty || include.any((re) => re.hasMatch(name));
      if (allProxies) selected.addAll(inlineNames.where(matches));
      for (final name in use) {
        final mapping = providerNames[name];
        if (mapping == null) {
          throw const FormatException('Unknown group provider');
        }
        selected.addAll(
          mapping.entries.where((e) => matches(e.key)).map((e) => e.value),
        );
      }
      selected.removeWhere(
        (name) => exclude.any((re) => re.hasMatch(originalNames[name] ?? name)),
      );
      if (selected.isEmpty) {
        selected.add(group['empty-fallback'] as String? ?? 'COMPATIBLE');
      }
      group['proxies'] = selected.toSet().toList();
      for (final key in [
        'use',
        'include-all',
        'include-all-proxies',
        'include-all-providers',
        'filter',
        'exclude-filter',
      ]) {
        group.remove(key);
      }
    }
    result.remove('proxy-providers');
  }
  return result;
}

List<RegExp> _nameFilters(Object? raw) {
  if (raw is! String || raw.isEmpty) return const [];
  return raw.split('`').map((pattern) {
    // Mihomo 订阅常用的前置匹配标志在 Dart 中由构造参数表达。
    final prefix = RegExp(r'^\(\?([ims]+)\)').firstMatch(pattern);
    final flags = prefix?.group(1) ?? '';
    return RegExp(
      prefix == null ? pattern : pattern.substring(prefix.end),
      caseSensitive: !flags.contains('i'),
      multiLine: flags.contains('m'),
      dotAll: flags.contains('s'),
    );
  }).toList();
}

/// 已支持 provider 的脚本直接执行；仅在无内联节点且执行失败时补齐输入。
Future<Map<String, dynamic>> evaluateProviderScript(
  Map<String, dynamic> config,
  Future<Map<String, dynamic>> Function(Map<String, dynamic>) evaluate,
  Future<List<Map<String, dynamic>>> Function(Map) readNodes, {
  void Function(Map<String, dynamic>)? applyNodeOverrides,
}) async {
  try {
    return await evaluate(config);
  } catch (error) {
    final message = error.toString().toLowerCase();
    final missingNodes =
        message.contains('未找到任何代理节点') ||
        message.contains('no proxy nodes') ||
        message.contains('no proxies');
    if ((config['proxies'] is List && (config['proxies'] as List).isNotEmpty) ||
        config['proxy-providers'] is! Map ||
        (config['proxy-providers'] as Map).isEmpty ||
        !missingNodes) {
      rethrow;
    }
    final input = await materializeProviderNodes(
      config,
      readNodes,
      flattenGroups: true,
    );
    applyNodeOverrides?.call(input);
    return evaluate(input);
  }
}
