import 'package:flutter/foundation.dart';

const _spaces = [
  '',
  ' ',
  '  ',
  '   ',
  '    ',
  '     ',
  '      ',
  '       ',
  '        ',
  '         ',
  '          ',
  '           ',
  '            ',
];

const _yamlKeywords = {
  'true',
  'false',
  'yes',
  'no',
  'y',
  'n',
  'on',
  'off',
  'null',
  'nil',
  '~',
  'nan',
  'inf',
  '+inf',
  '-inf',
  'infinity',
  '+infinity',
  '-infinity',
};

const _unsafeLeadingChars = '-?:,[]{}#&*!|>\'"%@`~0123456789+./';

Future<String> encodeYamlTask<T>(T data) async {
  return await compute<T, String>(_encodeYaml, data);
}

Future<String> encodeCompactYamlTask<T>(T data) async {
  return await compute<T, String>(_encodeYaml, data);
}

dynamic _resolveValue(dynamic value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is Map || value is List) {
    return value;
  }
  if (value is Iterable) {
    return value.toList();
  }
  try {
    final dynamic json = (value as dynamic).toJson();
    return _resolveValue(json);
  } catch (_) {
    if (value is Enum) {
      return value.name;
    }
    return value;
  }
}

String _encodeYaml<T>(T content) {
  final resolved = _resolveValue(content);
  if (resolved is Map) {
    if (resolved.isEmpty) return '{}\n';
    final sb = StringBuffer();
    _writeMap(sb, resolved, 0);
    return sb.toString();
  }
  if (resolved is List) {
    if (resolved.isEmpty) return '[]\n';
    final sb = StringBuffer();
    _writeList(sb, resolved, 0);
    return sb.toString();
  }
  return '${_formatScalar(resolved)}\n';
}

bool _needsQuotesForKey(String key) {
  if (key.isEmpty) return true;
  for (int i = 0; i < key.length; i++) {
    final code = key.codeUnitAt(i);
    final isAlphaNumeric = (code >= 97 && code <= 122) ||
        (code >= 65 && code <= 90) ||
        (code >= 48 && code <= 57) ||
        code == 95 ||
        code == 45;
    if (!isAlphaNumeric) return true;
  }
  final first = key.codeUnitAt(0);
  if ((first >= 48 && first <= 57) || first == 45) return true;
  if (_yamlKeywords.contains(key.toLowerCase())) return true;
  return false;
}

bool _needsQuotes(String s) {
  if (s.isEmpty) return true;
  if (s.startsWith(' ') ||
      s.startsWith('\t') ||
      s.endsWith(' ') ||
      s.endsWith('\t')) {
    return true;
  }
  if (_unsafeLeadingChars.contains(s[0])) return true;
  if (_yamlKeywords.contains(s.toLowerCase())) return true;
  if (s.contains(': ') || s.contains(':\t') || s.endsWith(':')) return true;
  if (s.contains(' #') || s.contains('\t#') || s.contains('#')) return true;
  if (s.contains('"') || s.contains("'") || s.contains('\\')) return true;
  if (s.contains('[') ||
      s.contains(']') ||
      s.contains('{') ||
      s.contains('}')) {
    return true;
  }
  for (int i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c < 0x20 ||
        c == 0x7F ||
        (c >= 0x80 && c <= 0x9F && c != 0x85) ||
        (c >= 0xD800 && c <= 0xDFFF) ||
        c == 0xFFFE ||
        c == 0xFFFF) {
      return true;
    }
  }
  return false;
}

String _escapeString(String s) {
  final sb = StringBuffer('"');
  for (int i = 0; i < s.length; i++) {
    final code = s.codeUnitAt(i);
    switch (code) {
      case 0x5C:
        sb.write(r'\\');
        break;
      case 0x22:
        sb.write(r'\"');
        break;
      case 0x00:
        sb.write(r'\0');
        break;
      case 0x07:
        sb.write(r'\a');
        break;
      case 0x08:
        sb.write(r'\b');
        break;
      case 0x09:
        sb.write(r'\t');
        break;
      case 0x0A:
        sb.write(r'\n');
        break;
      case 0x0B:
        sb.write(r'\v');
        break;
      case 0x0C:
        sb.write(r'\f');
        break;
      case 0x0D:
        sb.write(r'\r');
        break;
      case 0x1B:
        sb.write(r'\e');
        break;
      default:
        if (code < 0x20 || code == 0x7F) {
          sb.write(r'\x');
          sb.write(code.toRadixString(16).padLeft(2, '0'));
        } else if (code >= 0x80 && code <= 0x9F && code != 0x85) {
          sb.write(r'\u');
          sb.write(code.toRadixString(16).padLeft(4, '0'));
        } else if (code >= 0xD800 && code <= 0xDBFF) {
          if (i + 1 < s.length &&
              s.codeUnitAt(i + 1) >= 0xDC00 &&
              s.codeUnitAt(i + 1) <= 0xDFFF) {
            sb.writeCharCode(code);
            i++;
            sb.writeCharCode(s.codeUnitAt(i));
          } else {
            sb.write(r'\uFFFD');
          }
        } else if (code >= 0xDC00 && code <= 0xDFFF) {
          sb.write(r'\uFFFD');
        } else if (code == 0xFFFE || code == 0xFFFF) {
          sb.write(r'\uFFFD');
        } else {
          sb.writeCharCode(code);
        }
    }
  }
  sb.write('"');
  return sb.toString();
}

String _formatKey(dynamic key) {
  final str = key is Enum ? key.name : key.toString();
  if (_needsQuotesForKey(str)) {
    return _escapeString(str);
  }
  return str;
}

String _formatScalar(dynamic value) {
  if (value == null) return 'null';
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return value.toString();
  if (value is Enum) return value.name;
  final str = value.toString();
  if (_needsQuotes(str)) {
    return _escapeString(str);
  }
  return str;
}

void _writeIndent(StringBuffer sb, int indent) {
  if (indent < _spaces.length) {
    sb.write(_spaces[indent]);
  } else {
    sb.write(' ' * indent);
  }
}

void _writeMap(StringBuffer sb, Map map, int indent) {
  for (final entry in map.entries) {
    final key = _formatKey(entry.key);
    final val = _resolveValue(entry.value);
    _writeIndent(sb, indent);
    sb.write(key);
    if (val is Map) {
      if (val.isEmpty) {
        sb.write(': {}\n');
      } else {
        sb.write(':\n');
        _writeMap(sb, val, indent + 2);
      }
    } else if (val is List) {
      if (val.isEmpty) {
        sb.write(': []\n');
      } else {
        sb.write(':\n');
        _writeList(sb, val, indent + 2);
      }
    } else {
      sb.write(': ');
      sb.write(_formatScalar(val));
      sb.write('\n');
    }
  }
}

void _writeList(StringBuffer sb, List list, int indent) {
  for (final rawItem in list) {
    final item = _resolveValue(rawItem);
    if (item is Map) {
      if (item.isEmpty) {
        _writeIndent(sb, indent);
        sb.write('- {}\n');
      } else {
        var isFirst = true;
        for (final entry in item.entries) {
          final key = _formatKey(entry.key);
          final val = _resolveValue(entry.value);
          _writeIndent(sb, isFirst ? indent : indent + 2);
          if (isFirst) {
            sb.write('- ');
            isFirst = false;
          }
          sb.write(key);
          if (val is Map) {
            if (val.isEmpty) {
              sb.write(': {}\n');
            } else {
              sb.write(':\n');
              _writeMap(sb, val, indent + 4);
            }
          } else if (val is List) {
            if (val.isEmpty) {
              sb.write(': []\n');
            } else {
              sb.write(':\n');
              _writeList(sb, val, indent + 4);
            }
          } else {
            sb.write(': ');
            sb.write(_formatScalar(val));
            sb.write('\n');
          }
        }
      }
    } else if (item is List) {
      if (item.isEmpty) {
        _writeIndent(sb, indent);
        sb.write('- []\n');
      } else {
        _writeIndent(sb, indent);
        sb.write('-\n');
        _writeList(sb, item, indent + 2);
      }
    } else {
      _writeIndent(sb, indent);
      sb.write('- ');
      sb.write(_formatScalar(item));
      sb.write('\n');
    }
  }
}
