import 'dart:convert';
import 'dart:io';

import 'sha256.dart';

/// Raised for any structural problem in the approved manifest.
///
/// The parser is intentionally strict: R7-2 forbids "best effort" recovery, so
/// every ambiguity becomes an exception instead of a silent skip.
class ManifestException implements Exception {
  ManifestException(this.message, {this.lineNo});

  final String message;
  final int? lineNo;

  @override
  String toString() => lineNo == null
      ? 'ManifestException: $message'
      : 'ManifestException(line $lineNo): $message';
}

/// Qualifications that are allowed to reach an execution batch.
const List<String> kBatchQualifications = <String>['A1', 'A2', 'ASYNC-2S'];

/// Qualifications that must never reach an execution batch.
const List<String> kExcludedQualifications = <String>['EXCLUDE', 'EXCLUDE_B'];

/// Every qualification the manifest may contain.
const List<String> kAllQualifications = <String>[
  ...kBatchQualifications,
  ...kExcludedQualifications,
];

/// The only legal `qualification -> batch` mapping (null = never executed).
///
/// Batch assignment is derived from this table only. It is never derived from
/// the original class, from file order, or from any position in a list.
const Map<String, int?> kQualificationBatch = <String, int?>{
  'A1': 1,
  'A2': 2,
  'ASYNC-2S': 3,
  'EXCLUDE': null,
  'EXCLUDE_B': null,
};

/// One row of the `逐文件清单与执行资格` table.
class ManifestRow {
  const ManifestRow({
    required this.index,
    required this.rawPath,
    required this.path,
    required this.originalClass,
    required this.qualification,
    required this.timerRisk,
    required this.realIo,
    required this.batch,
    required this.lineNo,
  });

  final int index;

  /// Path exactly as written in the manifest (no `test/` prefix).
  final String rawPath;

  /// Canonical repository-relative path, always `test/<rawPath>`.
  final String path;

  final String originalClass;

  /// `approved_qualification` — the single source of truth for the batch.
  final String qualification;

  final String timerRisk;
  final String realIo;

  /// `approved_batch` — cross-checked against [qualification], never trusted alone.
  final int? batch;

  final int lineNo;

  Map<String, Object?> toJson() => <String, Object?>{
        'index': index,
        'raw_path': rawPath,
        'path': path,
        'original_class': originalClass,
        'qualification': qualification,
        'timer_risk': timerRisk,
        'real_io': realIo,
        'batch': batch,
        'line_no': lineNo,
      };
}

/// A parsed manifest plus the fingerprint of the bytes it was parsed from.
class ManifestDocument {
  ManifestDocument({
    required this.sourcePath,
    required this.sha256,
    required this.rows,
  });

  final String sourcePath;
  final String sha256;
  final List<ManifestRow> rows;

  List<ManifestRow> withQualification(String qualification) => rows
      .where((ManifestRow row) => row.qualification == qualification)
      .toList(growable: false);

  List<ManifestRow> withBatch(int batch) => rows
      .where((ManifestRow row) => row.batch == batch)
      .toList(growable: false);

  /// Rows allowed to run (A1 + A2 + ASYNC-2S).
  List<ManifestRow> get executable => rows
      .where((ManifestRow row) => kBatchQualifications.contains(row.qualification))
      .toList(growable: false);

  /// Rows that must never run (EXCLUDE + EXCLUDE_B).
  List<ManifestRow> get excluded => rows
      .where((ManifestRow row) => kExcludedQualifications.contains(row.qualification))
      .toList(growable: false);

  Map<String, ManifestRow> get byPath => <String, ManifestRow>{
        for (final ManifestRow row in rows) row.path: row,
      };
}

/// Reads [path] as UTF-8 and parses it. The fingerprint is taken over the raw
/// bytes so it matches `sha256sum` output for the same file.
ManifestDocument loadManifest(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw ManifestException('manifest not found: $path');
  }
  final List<int> bytes = file.readAsBytesSync();
  return parseManifestBytes(bytes, sourcePath: path);
}

/// Parses an in-memory manifest. Exposed for replay/self-check callers.
ManifestDocument parseManifestBytes(List<int> bytes, {required String sourcePath}) {
  String text = utf8.decode(bytes, allowMalformed: false);
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1);
  }
  return parseManifestText(
    text,
    sourcePath: sourcePath,
    sha256: Sha256.hexOfBytes(bytes),
  );
}

/// Parses the manifest table. Only rows inside the `逐文件清单与执行资格`
/// section are considered; the command block later in the file is ignored on
/// purpose (it is alphabetically ordered and must never drive batch assignment).
ManifestDocument parseManifestText(
  String text, {
  required String sourcePath,
  required String sha256,
}) {
  final List<String> lines = text.split('\n');
  int sectionStart = -1;
  int sectionEnd = lines.length;

  for (int i = 0; i < lines.length; i++) {
    final String line = _stripCr(lines[i]);
    if (sectionStart < 0) {
      if (line.startsWith('## ') && line.contains('逐文件清单')) {
        sectionStart = i;
      }
    } else if (line.startsWith('## ')) {
      sectionEnd = i;
      break;
    }
  }

  if (sectionStart < 0) {
    throw ManifestException('missing section heading 逐文件清单与执行资格');
  }

  final List<ManifestRow> rows = <ManifestRow>[];
  final Set<int> seenIndex = <int>{};
  final Map<String, String> seenPath = <String, String>{};

  for (int i = sectionStart + 1; i < sectionEnd; i++) {
    final String line = _stripCr(lines[i]).trim();
    if (!line.startsWith('|')) {
      continue;
    }
    final List<String> parts = line.split('|');
    if (parts.length < 9) {
      throw ManifestException('expected 7 cells, found ${parts.length - 2}',
          lineNo: i + 1);
    }
    final List<String> cells = parts.sublist(1, parts.length - 1);
    if (cells.length != 7) {
      throw ManifestException('expected 7 cells, found ${cells.length}',
          lineNo: i + 1);
    }
    final String firstCell = cells[0].trim();
    final int? index = int.tryParse(firstCell);
    if (index == null) {
      // F-03: only the two shapes Markdown actually produces may be skipped.
      // Anything else is a damaged data row and must abort the parse.
      if (_isSeparatorRow(cells) || _isHeaderRow(cells)) {
        continue;
      }
      throw ManifestException(
        'row does not start with an integer index ("$firstCell"); '
        'refusing to treat it as a header or separator',
        lineNo: i + 1,
      );
    }

    final String rawPath = cells[1].trim();
    final String originalClass = cells[2].trim();
    final String qualification = cells[3].trim();
    final String timerRisk = cells[4].trim();
    final String realIo = cells[5].trim();
    final String batchCell = cells[6].trim();

    if (!kAllQualifications.contains(qualification)) {
      throw ManifestException('unknown qualification "$qualification"',
          lineNo: i + 1);
    }

    final int? batch;
    if (batchCell == '-') {
      batch = null;
    } else {
      final int? parsed = int.tryParse(batchCell);
      if (parsed == null) {
        throw ManifestException('unparsable batch cell "$batchCell"',
            lineNo: i + 1);
      }
      batch = parsed;
    }

    final int? expectedBatch = kQualificationBatch[qualification];
    if (batch != expectedBatch) {
      throw ManifestException(
        'qualification/batch mismatch for "$rawPath": '
        'qualification=$qualification implies batch=$expectedBatch, '
        'manifest says batch=${batch ?? '-'}',
        lineNo: i + 1,
      );
    }

    if (!seenIndex.add(index)) {
      throw ManifestException('duplicate row index $index', lineNo: i + 1);
    }

    final String path = normalizeManifestPath(rawPath, lineNo: i + 1);
    final String identity = pathIdentityKey(path, lineNo: i + 1);
    final String? conflict = seenPath[identity];
    if (conflict != null) {
      throw ManifestException(
        'duplicate path identity: "$path" collides with "$conflict" '
        '(Windows compares file names case-insensitively)',
        lineNo: i + 1,
      );
    }
    seenPath[identity] = path;

    rows.add(ManifestRow(
      index: index,
      rawPath: rawPath,
      path: path,
      originalClass: originalClass,
      qualification: qualification,
      timerRisk: timerRisk,
      realIo: realIo,
      batch: batch,
      lineNo: i + 1,
    ));
  }

  if (rows.isEmpty) {
    throw ManifestException('no data rows found in 逐文件清单与执行资格');
  }

  rows.sort((ManifestRow a, ManifestRow b) => a.index.compareTo(b.index));
  for (int i = 0; i < rows.length; i++) {
    if (rows[i].index != i + 1) {
      throw ManifestException(
          'row indexes are not consecutive: expected ${i + 1}, found ${rows[i].index}');
    }
  }

  return ManifestDocument(sourcePath: sourcePath, sha256: sha256, rows: rows);
}

/// Converts a manifest path cell into a canonical `test/...` path.
///
/// Rejects everything that could escape the workspace or create ambiguity:
/// absolute paths, drive letters, `..` traversal, backslashes, doubled slashes,
/// a second `test/` prefix, and characters that are illegal on Windows.
String normalizeManifestPath(String rawPath, {int? lineNo}) {
  final String value = rawPath.trim();
  if (value.isEmpty) {
    throw ManifestException('empty path', lineNo: lineNo);
  }
  _rejectControlCharacters(value, lineNo: lineNo);
  if (value.contains('\\')) {
    throw ManifestException('backslash in path "$value"', lineNo: lineNo);
  }
  if (value.startsWith('/')) {
    throw ManifestException('absolute path "$value"', lineNo: lineNo);
  }
  if (RegExp(r'^[A-Za-z]:').hasMatch(value)) {
    throw ManifestException('drive-letter path "$value"', lineNo: lineNo);
  }
  if (value.contains('..')) {
    throw ManifestException('path traversal in "$value"', lineNo: lineNo);
  }
  if (value.contains('//')) {
    throw ManifestException('doubled slash in "$value"', lineNo: lineNo);
  }
  if (value.endsWith('/')) {
    throw ManifestException('trailing slash in "$value"', lineNo: lineNo);
  }
  for (final String segment in value.split('/')) {
    if (segment == '.') {
      throw ManifestException('"." path segment in "$value"', lineNo: lineNo);
    }
  }
  if (RegExp(r'[*?<>"|:]').hasMatch(value)) {
    throw ManifestException('illegal character in "$value"', lineNo: lineNo);
  }
  if (value == 'test' || value.startsWith('test/')) {
    throw ManifestException('path already carries a test/ prefix: "$value"',
        lineNo: lineNo);
  }
  if (!value.endsWith('_test.dart')) {
    throw ManifestException('not a *_test.dart file: "$value"', lineNo: lineNo);
  }
  return 'test/$value';
}

String _stripCr(String line) =>
    line.endsWith('\r') ? line.substring(0, line.length - 1) : line;

/// `|---|---|` / `|:--|--:|` — every cell is a dash run with optional colons.
bool _isSeparatorRow(List<String> cells) {
  final RegExp pattern = RegExp(r'^:?-{3,}:?$');
  for (final String cell in cells) {
    if (!pattern.hasMatch(cell.trim())) {
      return false;
    }
  }
  return true;
}

/// The manifest header starts with the literal `#` index cell.
bool _isHeaderRow(List<String> cells) => cells[0].trim() == '#';

/// W1 — rejects C0 control characters (U+0000–U+001F) and DEL (U+007F).
///
/// Control characters are never valid in a repository path, and they are
/// invisible in logs and terminals, so they must be refused during **input
/// validation**. Leaving them to the downstream on-disk check (V9) would mean
/// a plan could be generated for a path nobody can read.
void _rejectControlCharacters(String value, {int? lineNo}) {
  for (final int unit in value.codeUnits) {
    if (unit < 0x20 || unit == 0x7F) {
      throw ManifestException(
        'control character ${_codeUnitLabel(unit)} in path '
        '"${_describePath(value)}"',
        lineNo: lineNo,
      );
    }
  }
}

/// `U+0007` — a readable label for a single UTF-16 code unit.
String _codeUnitLabel(int unit) =>
    'U+${unit.toRadixString(16).toUpperCase().padLeft(4, '0')}';

/// Renders control characters as `<U+0007>` so an error message never embeds
/// an invisible character that the reader (or a log viewer) cannot see.
String _describePath(String value) {
  final StringBuffer buffer = StringBuffer();
  for (final int unit in value.codeUnits) {
    if (unit < 0x20 || unit == 0x7F) {
      buffer.write('<${_codeUnitLabel(unit)}>');
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

/// F-01 — the comparison identity of a `test/...` path.
///
/// Windows resolves `Foo_test.dart` and `foo_test.dart` to the same file, so
/// duplicate detection, batch membership and set comparison all key on this
/// value instead of the raw string. The original spelling is never rewritten;
/// it is kept so every message can name the path exactly as the manifest wrote
/// it.
///
/// Case folding policy: **ASCII only**. Windows uses a Unicode-wide,
/// locale-independent uppercase table; Dart's `toLowerCase()` is not that table
/// and this tool may not add a dependency to emulate it. A path containing any
/// code unit above U+007F therefore aborts the run instead of being compared
/// byte-by-byte and silently treated as distinct. All 187 paths in the current
/// manifest are pure ASCII, so this is a guard rail, not a functional limit.
String pathIdentityKey(String path, {int? lineNo}) {
  final String value = path.trim();
  if (value.isEmpty) {
    throw ManifestException('empty path identity', lineNo: lineNo);
  }
  if (!_isAsciiOnly(value)) {
    throw ManifestException(
      'non-ASCII path "$value" cannot be case-folded safely without a Unicode '
      'folding table; refusing to compare it by raw bytes',
      lineNo: lineNo,
    );
  }
  for (final String segment in value.split('/')) {
    if (segment == '.') {
      throw ManifestException('"." path segment in "$value"', lineNo: lineNo);
    }
    if (segment.isEmpty) {
      throw ManifestException('empty path segment in "$value"', lineNo: lineNo);
    }
  }
  return _asciiLower(value);
}

bool _isAsciiOnly(String value) {
  for (final int unit in value.codeUnits) {
    if (unit > 0x7F) {
      return false;
    }
  }
  return true;
}

String _asciiLower(String value) {
  final StringBuffer buffer = StringBuffer();
  for (final int unit in value.codeUnits) {
    if (unit >= 0x41 && unit <= 0x5A) {
      buffer.writeCharCode(unit + 0x20);
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

