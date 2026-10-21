/// 给导入的脚本起一个能认出来的名字。
///
/// 之前所有导入的脚本都叫「未命名 1」「未命名 2」，列表里一排看不出区别，
/// 只能逐个打开确认。名字来源按可靠性排序：
///
/// 1. 脚本头部注释里的 `@name` / `@title`（作者自己写的，最准）
/// 2. URL 或文件名的最后一段（`Advertising.js` → `Advertising`）
/// 3. 最后一段是 `main` / `index` 这类通用名时，退回上一级目录名
///
/// 全部取不到就返回 null，调用方沿用「未命名 + 序号」。
library;

const _maxLabelLength = 24;

const _genericFileNames = {'main', 'index', 'script', 'init', 'entry', 'default'};

const _scriptExtensions = {'.js', '.mjs', '.cjs', '.conf', '.plugin', '.txt'};

/// 返回建议的脚本名；无可用信息时返回 null。
String? suggestScriptLabel({required String content, String? url, String? fileName}) {
  final fromContent = _nameFromContent(content);
  if (fromContent != null) return _clip(fromContent);

  final path = fileName ?? _pathOf(url);
  if (path == null) return null;

  final fromPath = _nameFromPath(path);
  if (fromPath != null) return _clip(fromPath);

  return null;
}

/// 扫前 20 行找 `// @name xxx`、`/* @title xxx */` 这类声明。
String? _nameFromContent(String content) {
  final lines = content.split('\n');
  final limit = lines.length < 20 ? lines.length : 20;
  final pattern = RegExp(
    // `@name 广告拦截`、`@name: 广告拦截`、`@title = x` 都算；冒号可以省。
    r'''^[\s/*#;-]*@?(?:name|title)\s*[:=]?\s*(.+?)[\s*]*$''',
    caseSensitive: false,
  );
  for (var i = 0; i < limit; i++) {
    final match = pattern.firstMatch(lines[i].trim());
    if (match == null) continue;
    final value = match.group(1)?.trim();
    if (value == null || value.isEmpty) continue;
    // 去掉包裹的引号
    final unquoted = value.replaceAll(RegExp(r'''^["']|["']$'''), '').trim();
    if (unquoted.isNotEmpty) return unquoted;
  }
  return null;
}

String? _pathOf(String? url) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.pathSegments.isEmpty) return null;
  return uri.pathSegments.join('/');
}

/// 从路径里取一个像名字的段。
String? _nameFromPath(String path) {
  final segments = path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isEmpty) return null;

  var index = segments.length - 1;
  var last = _decode(segments[index]);
  last = _stripExtension(last);

  // `.../Advertising/main.js` → 用上一级的目录名
  if (_genericFileNames.contains(last.toLowerCase()) && index > 0) {
    index -= 1;
    last = _stripExtension(_decode(segments[index]));
  }

  return last.isEmpty ? null : last;
}

String _decode(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

String _stripExtension(String name) {
  final lower = name.toLowerCase();
  for (final extension in _scriptExtensions) {
    if (lower.endsWith(extension)) {
      return name.substring(0, name.length - extension.length);
    }
  }
  return name;
}

String _clip(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= _maxLabelLength) return trimmed;
  return trimmed.substring(0, _maxLabelLength).trim();
}
