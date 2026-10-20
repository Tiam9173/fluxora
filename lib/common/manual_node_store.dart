import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 手动添加的节点。
///
/// 单独存一份，不写进订阅文件：订阅每次更新都会整份覆盖，写进去必然被冲掉。
/// 生成配置时再合并进 `proxies`。
class ManualNodeStore {
  ManualNodeStore._();

  static final ManualNodeStore instance = ManualNodeStore._();

  static const _key = 'manual_nodes';

  List<Map<String, dynamic>>? _cache;

  Future<List<Map<String, dynamic>>> load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return _cache = [];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return _cache = [];
      return _cache = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return _cache = [];
    }
  }

  Future<void> add(Map<String, dynamic> node) async {
    final nodes = await load();
    nodes.add(node);
    await _save(nodes);
  }

  Future<void> removeAt(int index) async {
    final nodes = await load();
    if (index < 0 || index >= nodes.length) return;
    nodes.removeAt(index);
    await _save(nodes);
  }

  Future<void> _save(List<Map<String, dynamic>> nodes) async {
    _cache = nodes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(nodes));
  }
}
