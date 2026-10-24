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

  /// profileId → 原名 → 新名。
  ///
  /// 改名不能只改 `proxies[i].name`：策略组的 `proxies` 列表和规则的最后一段
  /// 都在按名字引用它，只改一处会让引用指向一个不存在的节点，内核直接拒绝加载。
  final Map<String, Map<String, String>> _renames = {};

  bool _loaded = false;

  /// Bumped on every in-memory mutation so caches can invalidate node edits.
  int revision = 0;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await Preferences().sharedPreferencesCompleter.future;
      final raw = prefs?.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = json.decode(raw);
      if (decoded is! Map) return;
      final renames = decoded['renames'];
      if (renames is Map) {
        renames.forEach((profileId, map) {
          if (map is Map) {
            _renames[profileId.toString()] = {
              for (final e in map.entries) e.key.toString(): e.value.toString(),
            };
          }
        });
      }
      final nodes = decoded['nodes'];
      if (nodes is! Map) return;
      nodes.forEach((profileId, nodes) {
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
    revision++;
    try {
      final prefs = await Preferences().sharedPreferencesCompleter.future;
      await prefs?.setString(
        _prefsKey,
        json.encode({'nodes': _data, 'renames': _renames}),
      );
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

  String? renameFor(String profileId, String nodeName) =>
      _renames[profileId]?[nodeName];

  /// 改名。`newName` 传空等于恢复原名。
  Future<void> setRename(
    String profileId,
    String nodeName,
    String newName,
  ) async {
    await ensureLoaded();
    final map = _renames[profileId];
    if (newName.isEmpty || newName == nodeName) {
      map?.remove(nodeName);
      if (map?.isEmpty ?? false) _renames.remove(profileId);
    } else {
      (_renames[profileId] ??= {})[nodeName] = newName;
    }
    await _save();
  }

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
    _applyRenames(profileId, configMap);
  }

  /// 改名要连引用一起改，否则策略组和规则会指向一个不存在的节点。
  void _applyRenames(String profileId, Map<String, dynamic> configMap) {
    final renames = _renames[profileId];
    if (renames == null || renames.isEmpty) return;

    String? mapName(String name) => renames[name];

    final proxies = configMap['proxies'];
    if (proxies is List) {
      for (final item in proxies) {
        if (item is! Map) continue;
        final name = item['name']?.toString();
        final renamed = name == null ? null : mapName(name);
        if (renamed != null) item['name'] = renamed;
      }
    }

    final groups = configMap['proxy-groups'];
    if (groups is List) {
      for (final group in groups) {
        if (group is! Map) continue;
        final list = group['proxies'];
        if (list is! List) continue;
        for (var i = 0; i < list.length; i++) {
          final renamed = mapName(list[i]?.toString() ?? '');
          if (renamed != null) list[i] = renamed;
        }
      }
    }

    // 规则形如 `DOMAIN,x.com,节点名`，只有最后一段可能是节点名。
    final rules = configMap['rules'];
    if (rules is List) {
      for (var i = 0; i < rules.length; i++) {
        final rule = rules[i];
        if (rule is! String) continue;
        final parts = rule.split(',');
        if (parts.length < 3) continue;
        final renamed = mapName(parts.last.trim());
        if (renamed == null) continue;
        parts[parts.length - 1] = renamed;
        rules[i] = parts.join(',');
      }
    }
  }
}
