import 'dart:convert';
import 'dart:io';

import 'manifest.dart';

/// The three execution batches plus the never-execute set, derived exclusively
/// from `approved_qualification` / `approved_batch`.
class BatchPlan {
  BatchPlan({
    required this.rows,
    required this.batches,
    required this.excluded,
    required this.manifestSha256,
    required this.sourceManifest,
  });

  /// All manifest rows, in manifest index order.
  final List<ManifestRow> rows;

  /// batch number -> rows, in manifest index order.
  final Map<int, List<ManifestRow>> batches;

  final List<ManifestRow> excluded;
  final String manifestSha256;
  final String sourceManifest;

  List<String> pathsOf(int batch) =>
      (batches[batch] ?? const <ManifestRow>[]).map((ManifestRow r) => r.path).toList(growable: false);

  List<String> get excludedPaths =>
      excluded.map((ManifestRow r) => r.path).toList(growable: false);

  /// All executable paths across the three batches (order: batch, then index).
  List<String> get allExecutablePaths => <String>[
        ...pathsOf(1),
        ...pathsOf(2),
        ...pathsOf(3),
      ];

  int get executableCount =>
      batches.values.fold(0, (int sum, List<ManifestRow> rows) => sum + rows.length);

  Map<String, Object?> summary() => <String, Object?>{
        'source_manifest': sourceManifest,
        'manifest_sha256': manifestSha256,
        'batch_counts': <String, int>{
          for (final int key in (batches.keys.toList()..sort())) '$key': batches[key]!.length,
        },
        'excluded_count': excluded.length,
        'executable_count': executableCount,
        'total_count': executableCount + excluded.length,
      };
}

/// Declarative ASYNC-2S constraints (remediation plan R3 §5.4).
///
/// R7-1..R7-4 do not implement a scheduler, so the constraints are recorded and
/// validated as data instead of being enforced at runtime.
///
/// Important distinction: validating this object proves **the plan declares**
/// the required policy. It does not prove that any run actually executed
/// serially — that still needs wall-clock evidence from a real executor.
class Batch3Policy {
  const Batch3Policy({
    required this.oneProcessPerFile,
    required this.serial,
    required this.gapSeconds,
    required this.concurrentWithOtherBatches,
  });

  /// The only policy allowed by the remediation plan.
  static const Batch3Policy required = Batch3Policy(
    oneProcessPerFile: true,
    serial: true,
    gapSeconds: 3,
    concurrentWithOtherBatches: false,
  );

  final bool oneProcessPerFile;
  final bool serial;
  final int gapSeconds;
  final bool concurrentWithOtherBatches;

  /// F-02 — strict parser for the `batch3_policy` object actually stored in the
  /// plan's `manifest.json`.
  ///
  /// Every field must be present with the exact type; unknown fields are
  /// rejected as well, so a damaged or hand-edited plan cannot be mistaken for
  /// a compliant one. There is deliberately **no** fallback to
  /// [Batch3Policy.required].
  factory Batch3Policy.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw ManifestException(
          'batch3_policy must be a JSON object, found ${json.runtimeType}');
    }
    const Set<String> expectedKeys = <String>{
      'one_process_per_file',
      'serial',
      'gap_seconds',
      'concurrent_with_other_batches',
    };
    for (final String key in expectedKeys) {
      if (!json.containsKey(key)) {
        throw ManifestException('batch3_policy is missing "$key"');
      }
    }
    for (final String key in json.keys) {
      if (!expectedKeys.contains(key)) {
        throw ManifestException('batch3_policy has unexpected key "$key"');
      }
    }

    bool readBool(String key) {
      final Object? value = json[key];
      if (value is! bool) {
        throw ManifestException(
            'batch3_policy."$key" must be a boolean, found ${value.runtimeType}');
      }
      return value;
    }

    final Object? gap = json['gap_seconds'];
    if (gap is! int) {
      throw ManifestException(
          'batch3_policy."gap_seconds" must be an integer, found ${gap.runtimeType}');
    }

    return Batch3Policy(
      oneProcessPerFile: readBool('one_process_per_file'),
      serial: readBool('serial'),
      gapSeconds: gap,
      concurrentWithOtherBatches: readBool('concurrent_with_other_batches'),
    );
  }

  List<String> violations() {
    final List<String> problems = <String>[];
    if (!oneProcessPerFile) {
      problems.add('oneProcessPerFile must be true');
    }
    if (!serial) {
      problems.add('serial must be true');
    }
    if (gapSeconds < 3) {
      problems.add('gapSeconds must be >= 3, found $gapSeconds');
    }
    if (concurrentWithOtherBatches) {
      problems.add('concurrentWithOtherBatches must be false');
    }
    return problems;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'one_process_per_file': oneProcessPerFile,
        'serial': serial,
        'gap_seconds': gapSeconds,
        'concurrent_with_other_batches': concurrentWithOtherBatches,
      };
}

/// Groups manifest rows into batches. Throws instead of repairing.
///
/// Preconditions enforced here (fail closed):
///  * every row has a known qualification;
///  * `approved_batch` equals the batch implied by `approved_qualification`;
///  * no row ends up in two batches (compared by path identity, so case
///    variants collide exactly like they do on Windows).
BatchPlan buildBatchPlan(ManifestDocument document) {
  final Map<int, List<ManifestRow>> batches = <int, List<ManifestRow>>{
    1: <ManifestRow>[],
    2: <ManifestRow>[],
    3: <ManifestRow>[],
  };
  final List<ManifestRow> excluded = <ManifestRow>[];
  final Map<String, String> seen = <String, String>{};

  for (final ManifestRow row in document.rows) {
    if (!kAllQualifications.contains(row.qualification)) {
      throw ManifestException('unknown qualification "${row.qualification}" for ${row.path}');
    }
    final int? expected = kQualificationBatch[row.qualification];
    if (row.batch != expected) {
      throw ManifestException(
        'qualification/batch mismatch for ${row.path}: '
        'expected batch=${expected ?? '-'}, found batch=${row.batch ?? '-'}',
      );
    }

    final String identity = pathIdentityKey(row.path);
    final String? previous = seen[identity];
    if (previous != null) {
      throw ManifestException(
          '${row.path} and $previous share the same path identity');
    }
    seen[identity] = row.path;

    if (expected == null) {
      excluded.add(row);
    } else {
      batches[expected]!.add(row);
    }
  }

  return BatchPlan(
    rows: document.rows,
    batches: batches,
    excluded: excluded,
    manifestSha256: document.sha256,
    sourceManifest: document.sourcePath,
  );
}

/// Result of an atomic plan publish.
class PlanPublishResult {
  const PlanPublishResult({required this.directory, required this.files});

  final String directory;
  final List<String> files;
}

/// F-04 — writes the plan into a fresh directory and publishes it atomically.
///
/// Safety rules enforced before anything is written:
///  * `--out` must not contain `..`, `.` or a trailing slash;
///  * its parent must exist and is resolved through symlinks, so a junction or
///    symlink cannot redirect the write somewhere else;
///  * the resolved target must not be the repository or inside it;
///  * an existing target (file or directory) is refused, never overwritten.
///
/// Publication is: write everything into a uniquely named temp directory in the
/// same parent (same volume), verify the written content, then rename the temp
/// directory onto the target. `renameSync` is used **only** for this one
/// temp -> target step; there is no other rename in the tool.
PlanPublishResult publishPlan(BatchPlan plan, String outDir, {required String repoRoot}) {
  final String unified = _normalizeOutArgument(outDir);
  final int slash = unified.lastIndexOf('/');
  final String parentRaw = slash < 0 ? '.' : unified.substring(0, slash);
  final String leaf = slash < 0 ? unified : unified.substring(slash + 1);
  if (leaf.isEmpty || leaf == '.' || leaf == '..') {
    throw ManifestException('--out must name a directory, got "$outDir"');
  }

  final Directory parent = Directory(parentRaw);
  if (!parent.existsSync()) {
    throw ManifestException('parent directory does not exist: "$parentRaw"');
  }
  final String canonicalParent = _unify(parent.resolveSymbolicLinksSync());
  final String target = _join(canonicalParent, leaf);

  final Directory repoDirectory = Directory(repoRoot);
  if (!repoDirectory.existsSync()) {
    throw ManifestException('repository root does not exist: "$repoRoot"');
  }
  final String canonicalRepo = _unify(repoDirectory.resolveSymbolicLinksSync());
  if (_isInside(target, canonicalRepo)) {
    throw ManifestException(
      'refusing to write the plan inside the repository ("$canonicalRepo"); '
      'choose an output directory outside the worktree',
    );
  }

  final String tempPath = _join(canonicalParent, '.$leaf.tmp-${_uniqueSuffix()}');
  final Directory temp = Directory(tempPath);

  try {
    // The existence probes must be inside the guard: on Windows `existsSync()`
    // itself throws (errno 123/206) for an over-long or otherwise invalid name,
    // so leaving them outside would still leak a raw FileSystemException.
    if (File(target).existsSync() || Directory(target).existsSync()) {
      throw ManifestException(
          'output already exists: "$target" (overwriting is not supported)');
    }
    if (temp.existsSync()) {
      throw ManifestException('temporary path already exists: "$tempPath"');
    }

    // G-1: creating the temp directory belongs to the guarded sequence, so a
    // filesystem failure (permission, full disk, path too long) surfaces as the
    // same ManifestException / exit code 2 as every other publish failure.
    temp.createSync();
    _writePlanFiles(plan, tempPath);
    _verifyPlanFiles(plan, tempPath);
    temp.renameSync(target);
  } on ManifestException {
    // Already carries the precise reason and the leftover-path note; re-wrapping
    // it would bury the original message one level deeper.
    rethrow;
  } on FileSystemException catch (error) {
    throw ManifestException(_publishFailureMessage(error, tempPath));
  } catch (error, stackTrace) {
    // Not a filesystem problem: keep the real type, the message and the stack so
    // a genuine bug is never mistaken for a disk/permission failure.
    throw ManifestException(
      'unexpected ${error.runtimeType} during plan publish: $error\n'
      '${_tempDirNote(_directoryExistsSafe(tempPath), tempPath)}\n'
      'stack trace:\n$stackTrace',
    );
  }

  return PlanPublishResult(
    directory: target,
    files: _planFilePaths(target),
  );
}

String _normalizeOutArgument(String outDir) {
  final String raw = outDir.trim();
  if (raw.isEmpty) {
    throw ManifestException('empty --out path');
  }
  final String unified = _unify(raw);
  _rejectDriveRelativePath(unified, outDir);
  for (final String segment in unified.split('/')) {
    if (segment == '..') {
      throw ManifestException('".." is not allowed in --out: "$outDir"');
    }
    if (segment == '.') {
      throw ManifestException('"." segments are not allowed in --out: "$outDir"');
    }
  }
  if (unified.endsWith('/')) {
    throw ManifestException('trailing slash is not allowed in --out: "$outDir"');
  }
  return unified;
}

/// G-2 — rejects Windows **drive-relative** paths such as `C:` and `C:plan`.
///
/// `C:plan` means "plan inside the current directory of drive C", which depends
/// on per-drive process state that is invisible to the operator; the target
/// could be anywhere on that drive. Absolute forms (`C:/plan`, `C:\plan`) and
/// UNC paths are untouched.
///
/// The rule is gated on [Platform.isWindows] on purpose: on POSIX, `C:plan` is
/// an ordinary relative directory name and must not be reinterpreted.
void _rejectDriveRelativePath(String unified, String outDir) {
  if (!Platform.isWindows) {
    return;
  }
  if (!RegExp(r'^[A-Za-z]:').hasMatch(unified)) {
    return;
  }
  final bool hasSeparatorAfterDrive = unified.length > 2 && unified[2] == '/';
  if (hasSeparatorAfterDrive) {
    return;
  }
  throw ManifestException(
    'drive-relative --out path is not supported: "$outDir"; '
    'use an absolute path such as "C:/temp/plan"',
  );
}

/// Describes a publish failure without ever claiming a directory exists.
///
/// If the failure happened before `createSync()` completed there is nothing on
/// disk to point at, so the message says exactly that instead of telling the
/// operator to clean up a directory that was never created.
String _publishFailureMessage(Object error, String tempPath) {
  final bool created = _directoryExistsSafe(tempPath);
  final String headline = created
      ? 'plan publish failed: $error'
      : 'plan publish failed before any file was written: $error';
  return '$headline\n${_tempDirNote(created, tempPath)}';
}

/// `existsSync()` that answers `false` instead of throwing.
///
/// The probe is used inside failure handling, where an over-long or malformed
/// path can throw the very same `FileSystemException` we are reporting; letting
/// it escape would replace a clean exit code 2 with an unhandled 255.
bool _directoryExistsSafe(String path) {
  try {
    return Directory(path).existsSync();
  } on FileSystemException {
    return false;
  }
}

/// One line about what the temp directory currently is (or is not).
String _tempDirNote(bool created, String tempPath) => created
    ? 'partial output left at "$tempPath" — it is NOT deleted automatically; '
        'inspect it and remove it manually'
    : 'no temporary directory exists at "$tempPath"';

String _unify(String path) => path.replaceAll('\\', '/');

/// Joins without producing a doubled slash when [parent] is a drive root.
String _join(String parent, String child) =>
    parent.endsWith('/') ? '$parent$child' : '$parent/$child';

/// True when [target] is [root] or lives under it. The comparison is
/// case-insensitive on purpose: over-reporting containment is the safe side.
bool _isInside(String target, String root) {
  final String t = _unify(target).toLowerCase();
  final String r = _unify(root).toLowerCase();
  if (t == r) {
    return true;
  }
  return t.startsWith('$r/');
}

String _uniqueSuffix() => '${DateTime.now().microsecondsSinceEpoch}-$pid';

void _writePlanFiles(BatchPlan plan, String dir) {
  for (final int batch in <int>[1, 2, 3]) {
    File('$dir/batch$batch.txt').writeAsStringSync(_lines(plan.pathsOf(batch)));
  }
  File('$dir/excluded.txt').writeAsStringSync(_lines(plan.excludedPaths));
  File('$dir/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'summary': plan.summary(),
    'batch3_policy': Batch3Policy.required.toJson(),
  }));
  File('$dir/manifest.sha256').writeAsStringSync('${plan.manifestSha256}\n');
}

List<String> _planFilePaths(String dir) => <String>[
      '$dir/batch1.txt',
      '$dir/batch2.txt',
      '$dir/batch3.txt',
      '$dir/excluded.txt',
      '$dir/manifest.json',
      '$dir/manifest.sha256',
    ];

/// Re-reads everything just written and compares it with the in-memory plan.
/// A mismatch aborts publication before the rename, so a half-written plan can
/// never become the target directory.
void _verifyPlanFiles(BatchPlan plan, String dir) {
  for (final int batch in <int>[1, 2, 3]) {
    final List<String> written = _readPathLines(File('$dir/batch$batch.txt'));
    if (!_sameOrderedList(written, plan.pathsOf(batch))) {
      throw ManifestException('batch$batch.txt does not match the plan after writing');
    }
  }
  final List<String> excluded = _readPathLines(File('$dir/excluded.txt'));
  if (!_sameOrderedList(excluded, plan.excludedPaths)) {
    throw ManifestException('excluded.txt does not match the plan after writing');
  }

  final String fingerprint = File('$dir/manifest.sha256').readAsStringSync().trim();
  if (fingerprint != plan.manifestSha256) {
    throw ManifestException('manifest.sha256 does not match the plan after writing');
  }

  final Object? decoded = jsonDecode(File('$dir/manifest.json').readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw ManifestException('manifest.json is not a JSON object after writing');
  }
  final Object? summary = decoded['summary'];
  if (summary is! Map<String, Object?>) {
    throw ManifestException('manifest.json has no summary object');
  }
  final Object? counts = summary['batch_counts'];
  if (counts is! Map<String, Object?>) {
    throw ManifestException('manifest.json has no batch_counts object');
  }
  for (final int batch in <int>[1, 2, 3]) {
    final Object? value = counts['$batch'];
    if (value is! int || value != plan.pathsOf(batch).length) {
      throw ManifestException('manifest.json batch_counts[$batch] is inconsistent');
    }
  }
  final Object? excludedCount = summary['excluded_count'];
  if (excludedCount is! int || excludedCount != plan.excludedPaths.length) {
    throw ManifestException('manifest.json excluded_count is inconsistent');
  }
  Batch3Policy.fromJson(decoded['batch3_policy']);
}

/// Reads the ASYNC-2S policy that the plan actually declares.
///
/// F-02: the validator must judge the file on disk, not the in-code constant.
/// A missing file, a missing section, or a malformed section all abort.
Batch3Policy readPlanPolicy(String planDir) {
  final File file = File('$planDir/manifest.json');
  if (!file.existsSync()) {
    throw ManifestException('missing plan file: ${file.path}');
  }
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw ManifestException('${file.path} is not a JSON object');
  }
  if (!decoded.containsKey('batch3_policy')) {
    throw ManifestException('${file.path} has no batch3_policy section');
  }
  return Batch3Policy.fromJson(decoded['batch3_policy']);
}

/// Reads back a written plan. Missing files are an error, not an empty set.
Map<int, List<String>> readPlanBatches(String planDir) {
  final Map<int, List<String>> result = <int, List<String>>{};
  for (final int batch in <int>[1, 2, 3]) {
    final File file = File('$planDir/batch$batch.txt');
    if (!file.existsSync()) {
      throw ManifestException('missing plan file: ${file.path}');
    }
    result[batch] = _readPathLines(file);
  }
  return result;
}

List<String> readPlanExcluded(String planDir) {
  final File file = File('$planDir/excluded.txt');
  if (!file.existsSync()) {
    throw ManifestException('missing plan file: ${file.path}');
  }
  return _readPathLines(file);
}

String readRecordedFingerprint(String planDir) {
  final File file = File('$planDir/manifest.sha256');
  if (!file.existsSync()) {
    throw ManifestException('missing fingerprint file: ${file.path}');
  }
  return file.readAsStringSync().trim();
}

List<String> _readPathLines(File file) {
  final List<String> paths = <String>[];
  for (final String raw in file.readAsLinesSync()) {
    final String line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    paths.add(line);
  }
  return paths;
}

bool _sameOrderedList(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

String _lines(List<String> values) =>
    values.isEmpty ? '' : '${values.join('\n')}\n';
