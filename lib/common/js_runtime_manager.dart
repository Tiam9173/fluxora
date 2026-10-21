import 'dart:async';
import 'dart:convert';

import 'package:code_forge/code_forge.dart' as rust_script;
import 'package:fluxora/common/common.dart';

class _ScriptOptionsCache {
  static final _entries = <String, Map<String, dynamic>>{};
  static const _maxEntries = 16;

  static Map<String, dynamic>? get(String content) {
    final key = _key(content);
    final v = _entries[key];
    if (v != null) {
      // Move to end (most recently used)
      _entries.remove(key);
      _entries[key] = v;
    }
    return v;
  }

  static void put(String content, Map<String, dynamic> value) {
    final key = _key(content);
    _entries[key] = value;
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  static void remove(String content) {
    _entries.remove(_key(content));
  }

  static String _key(String content) {
    final bytes = utf8.encode(content);
    return '${bytes.length}_${bytes.fold<int>(0, (p, b) => (p * 31 + b) & 0x7fffffff)}';
  }
}

/// 用 code_forge 里的 rquickjs 执行订阅脚本。
///
/// 之前是 `flutter_qjs`（QuickJS 的 Dart 绑定）。换引擎的直接原因不是性能，
/// 而是**原来的实现不等 Promise**：`evaluate('main(cfg)')` 拿到的是 Promise
/// 对象本身，回到 Dart 之后 `is Map` 为假，脚本等于没跑——同一个脚本在
/// 上游能用、在这里不能用，就是这个原因。
///
/// rquickjs 这套实现还会等 Promise settle，并且带超时/内存/栈限制，
/// 脚本写坏不会把整个 App 拖死。
class JavaScriptRuntimeManager {
  static int _nextToken = 1;

  /// 跑一次脚本，返回脚本产出的配置。
  ///
  /// 失败时抛 `JS Script Error: ...`，与旧实现的调用方约定保持一致。
  static Future<Map<String, dynamic>> evaluateScript(
    String scriptContent,
    Map<String, dynamic> config, {
    Map<String, bool>? customOptions,
  }) async {
    final token = _nextToken++;
    try {
      final run = await rust_script.evaluateScript(
        script: scriptContent,
        configJson: json.encode(config),
        customOptions: customOptions == null || customOptions.isEmpty
            ? null
            : json.encode(customOptions),
        token: token,
      );
      _logScriptLines(run.logs);
      final decoded = json.decode(run.config);
      if (decoded is Map) {
        return _deepCastMap(decoded);
      }
      // 脚本返回了非对象：保持旧行为，原样交回输入配置。
      return config;
    } on rust_script.ScriptError catch (error) {
      _logScriptLines(error.logs);
      // 带上脚本开头：语法错误只说"某个 token 不对"，不给出上下文的话，
      // 用户只能反复截图猜是哪个脚本、哪一段。
      throw 'JS Script Error: ${error.message}'
          '${_snippetFor(scriptContent)}';
    } catch (error) {
      throw 'JS Script Error: $error';
    }
  }

  /// 读出脚本声明的选项（`ruleOptionsEnable` / `serviceConfigs`），用于设置页。
  static Future<Map<String, dynamic>> extractScriptOptions(
    String scriptContent,
  ) async {
    final cached = _ScriptOptionsCache.get(scriptContent);
    if (cached != null) return cached;

    try {
      final raw = await rust_script.extractScriptOptions(
        script: scriptContent,
      );
      final decoded = json.decode(raw);
      final result = <String, dynamic>{};
      if (decoded is Map) {
        result.addAll(_deepCastMap(decoded));
      }
      _ScriptOptionsCache.put(scriptContent, result);
      return result;
    } on rust_script.ScriptError catch (error) {
      _logScriptLines(error.logs);
      commonPrint.log(
        'extractScriptOptions error: ${error.kind} ${error.message}',
      );
      return <String, dynamic>{};
    } catch (error) {
      commonPrint.log('extractScriptOptions error: $error');
      return <String, dynamic>{};
    }
  }

  static void invalidateCachedOptions(String scriptContent) {
    _ScriptOptionsCache.remove(scriptContent);
  }

  static bool hasCachedOptions(String scriptContent) {
    return _ScriptOptionsCache.get(scriptContent) != null;
  }

  static Map<String, dynamic>? getCachedOptions(String scriptContent) {
    return _ScriptOptionsCache.get(scriptContent);
  }

  /// 下载回来的内容到底是不是一段脚本。
  ///
  /// 最常见的错误来源是把 GitHub 的**页面**地址当成 raw 地址：服务器照样返回
  /// 200，正文是一整页 HTML。存下来只会在执行时报 `unexpected token '<'`，
  /// 用户完全看不出是链接贴错了。
  static bool looksLikeScript(String content) {
    final trimmed = content.trimLeft();
    if (trimmed.isEmpty) return false;
    // HTML / XML 页面
    if (trimmed.startsWith('<')) return false;
    return true;
  }

  /// 出错时附上脚本开头，让错误信息能直接指认是哪个文件、哪一段。
  static String _snippetFor(String scriptContent) {
    final flat = scriptContent.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) return '';
    final head = flat.length > 80 ? flat.substring(0, 80) : flat;
    return ' | 脚本开头: $head';
  }

  /// 把脚本里的 `console.*` 输出转到 App 日志，方便用户排查自己的脚本。
  static void _logScriptLines(List<rust_script.ScriptLog> lines) {
    for (final line in lines) {
      commonPrint.log('[script] ${line.level}: ${line.text}');
    }
  }

  static Map<String, dynamic> _deepCastMap(Map dynamicMap) {
    return dynamicMap.map<String, dynamic>((key, value) {
      return MapEntry(key.toString(), _deepCastValue(value));
    });
  }

  static dynamic _deepCastValue(dynamic value) {
    if (value is Map) {
      return _deepCastMap(value);
    } else if (value is List) {
      return value.map((e) => _deepCastValue(e)).toList();
    }
    return value;
  }
}
