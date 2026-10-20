import 'dart:convert';

import 'package:fluxora/common/common.dart';

/// 本地节点覆盖层。
///
/// 订阅每次更新都会整份替换 `proxies`，所以直接改订阅节点等于白改——下次更新
/// 就被冲掉了。这里把用户的修改单独存一份，生成配置时再叠加上去：
///
/// ```
/// 订阅原始配置 → apply() → 写进运行配置 → 内核
/// ```
///
/// 键是 `profileId → 节点名 → 字段`。按订阅分开存，是因为不同订阅里出现同名
/// 节点是常态，混在一起会改错节点。
class NodeOverrideStore {
  NodeOverrideStore._();

  static final NodeOverrideStore instance = NodeOverrideStore._();

  static const String _prefsKey = 'node_overrides_v1';

  /// profileId → nodeName → (field → value)
  final Map<String, Map<String, Map<String, dynamic>>> _data = {};

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await Preferences().sharedPreferencesCompleter.future;
      final raw = prefs?.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = json.decode(raw);
      if (decoded is! Map) return;
      decoded.forEach((profileId, nodes) {
        if (nodes is! Map) return;
        final nodeMap = <String, Map<String, dynamic>>{};
        nodes.forEach((name, fields) {
          if (fields is Map) {
            nodeMap[name.toString()] = {
              for (final e in fields.entries) e.key.toString(): e.value,
            };
          }
        });
        _data[profileId.toString()] = nodeMap;
      });
    } catch (e) {
      commonPrint.log('NodeOverrideStore: load failed: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await Preferences().sharedPreferencesCompleter.future;
      await prefs?.setString(_prefsKey, json.encode(_data));
    } catch (e) {
      commonPrint.log('NodeOverrideStore: save failed: $e');
    }
  }

  Map<String, dynamic>? overridesFor(String profileId, String nodeName) =>
      _data[profileId]?[nodeName];

  bool hasOverride(String profileId, String nodeName) =>
      (_data[profileId]?[nodeName]?.isNotEmpty) ?? false;

  /// 写入一条覆盖；传空 Map 等于删除。
  Future<void> setOverride(
    String profileId,
    String nodeName,
    Map<String, dynamic> fields,
  ) async {
    await ensureLoaded();
    if (fields.isEmpty) {
      _data[profileId]?.remove(nodeName);
      if (_data[profileId]?.isEmpty ?? false) _data.remove(profileId);
    } else {
      (_data[profileId] ??= {})[nodeName] = Map<String, dynamic>.from(fields);
    }
    await _save();
  }

  Future<void> clear(String profileId, String nodeName) =>
      setOverride(profileId, nodeName, const {});

  /// 把覆盖叠进一份配置的 `proxies`。
  ///
  /// 只改已存在的节点：覆盖层不能凭空造节点，否则配置里会出现一个只有名字、
  /// 没有任何连接参数的代理，内核直接报错。
  void apply(String profileId, Map<String, dynamic> configMap) {
    final nodes = _data[profileId];
    if (nodes == null || nodes.isEmpty) return;
    final proxies = configMap['proxies'];
    if (proxies is! List) return;
    for (final item in proxies) {
      if (item is! Map) continue;
      final name = item['name']?.toString();
      if (name == null) continue;
      final fields = nodes[name];
      if (fields == null || fields.isEmpty) continue;
      for (final e in fields.entries) {
        item[e.key] = e.value;
      }
    }
  }
}
