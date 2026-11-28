import 'dart:isolate';

import 'package:fluxora/common/task.dart';
import 'package:fluxora/models/models.dart';
import 'package:yaml/yaml.dart';

/// Validation retries only repair the legacy default selector. Other invalid
/// input stays unchanged so the original validation error is still reported.
Future<String> repairDefaultProxyYaml(String content) async {
  final repaired = await Isolate.run(() {
    try {
      final value = loadYaml(content);
      if (value is! Map) return null;
      final config = Map<String, dynamic>.from(value);
      return ensureDefaultProxyTarget(config) ? config : null;
    } catch (_) {
      return null;
    }
  });
  return repaired == null ? content : encodeYamlTask(repaired);
}

/// Repairs the default rule used by node imports, without discarding routing
/// rules or silently turning proxy traffic into direct traffic.
bool ensureDefaultProxyTarget(Map<String, dynamic> config) {
  final rules = config['rules'] ?? config['rule'];
  if (rules is! List ||
      !rules.whereType<String>().any(
        (rule) => ParsedRule.parseString(rule).ruleTarget == 'PROXY',
      )) {
    return false;
  }
  final groups = config['proxy-groups'] as List? ?? const [];
  final nodes = config['proxies'] as List? ?? const [];
  if ([
    ...groups,
    ...nodes,
  ].whereType<Map>().any((item) => item['name'] == 'PROXY')) {
    return false;
  }
  // A manually configured dialer referencing the missing group needs an
  // explicit repair; including that node would create a routing cycle.
  if (nodes.whereType<Map>().any((node) => node['dialer-proxy'] == 'PROXY')) {
    return false;
  }
  final names = {
    for (final node in nodes.whereType<Map>())
      if (node['name'] is String &&
          ChainProxyConfig.isSelectableProxy(
            name: node['name'] as String,
            type: node['type']?.toString() ?? '',
          ))
        node['name'] as String,
  }.toList();
  final providers = config['proxy-providers'] as Map? ?? const {};
  if (names.isEmpty && providers.isEmpty) return false;
  config['proxy-groups'] = [
    ...groups,
    {
      'name': 'PROXY',
      'type': 'select',
      if (names.isNotEmpty) 'proxies': names,
      if (providers.isNotEmpty) 'use': providers.keys.toList(),
    },
  ];
  return true;
}
