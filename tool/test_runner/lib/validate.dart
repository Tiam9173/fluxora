import 'dart:io';

import 'batches.dart';
import 'manifest.dart';

/// Frozen baseline of the approved R6-F2 manifest.
///
/// A deliberate manifest change (for example deleting the six empty-shell test
/// files in R7-7) requires updating these constants in the same change, so the
/// deviation is always explicit and reviewable instead of silently accepted.
const int kBaselineTotal = 187;
const int kBaselineBatch1 = 141;
const int kBaselineBatch2 = 37;
const int kBaselineBatch3 = 3;
const int kBaselineExcluded = 6;

/// Stable identifiers for every check. Kept short so console output stays
/// greppable in evidence files.
enum IssueCode {
  v1Count('V1_COUNT'),
  v1Baseline('V1_BASELINE'),
  v2Duplicate('V2_DUPLICATE'),
  v3Missing('V3_MISSING_IN_BATCH'),
  v3Extra('V3_EXTRA_IN_BATCH'),
  v4Overlap('V4_BATCH_OVERLAP'),
  v5ExcludedExecuted('V5_EXCLUDED_EXECUTED'),
  v5ExcludedSet('V5_EXCLUDED_SET'),
  v6Union('V6_UNION_MISMATCH'),
  v7Extra('V7_EXTRA_BEYOND_APPROVED'),
  v8Missing('V8_MISSING_FROM_EXECUTION'),
  v9MissingOnDisk('V9_MISSING_ON_DISK'),
  v9NotTestFile('V9_NOT_A_TEST_FILE'),
  v10ManifestDrift('V10_MANIFEST_DRIFT'),
  v11AsyncSet('V11_ASYNC_SET'),
  v11AsyncPolicy('V11_ASYNC_POLICY');

  const IssueCode(this.label);

  final String label;
}

class ValidationIssue {
  ValidationIssue({
    required this.code,
    required this.message,
    this.paths = const <String>[],
  });

  final IssueCode code;
  final String message;
  final List<String> paths;

  @override
  String toString() => '${code.label}: $message';
}

class ValidationReport {
  ValidationReport(this.issues);

  final List<ValidationIssue> issues;

  bool get passed => issues.isEmpty;

  /// Human-readable report. Every issue is followed by its affected paths, so a
  /// failure never degrades into "counts differ" without naming the files.
  List<String> format() {
    final List<String> lines = <String>[];
    if (passed) {
      lines.add('VALIDATION PASSED');
      return lines;
    }
    lines.add('VALIDATION FAILED (${issues.length} issue(s))');
    for (final ValidationIssue issue in issues) {
      lines.add('- [${issue.code.label}] ${issue.message}');
      for (final String path in issue.paths) {
        lines.add('    $path');
      }
    }
    return lines;
  }
}

/// Everything the validator needs. Kept as an explicit object so the CLI cannot
/// accidentally skip an input.
class ValidationInput {
  ValidationInput({
    required this.approved,
    required this.actualBatches,
    required this.actualExcluded,
    required this.recordedFingerprint,
    required this.currentFingerprint,
    required this.policy,
    this.repoRoot = '.',
    this.checkDisk = true,
    this.enforceBaseline = true,
  });

  final BatchPlan approved;
  final Map<int, List<String>> actualBatches;
  final List<String> actualExcluded;
  final String recordedFingerprint;
  final String currentFingerprint;

  /// F-02 — the policy read from the plan's own `manifest.json`.
  ///
  /// Deliberately **required**: there is no default, so a caller cannot fall
  /// back to [Batch3Policy.required] and validate a constant against itself.
  final Batch3Policy policy;

  final String repoRoot;
  final bool checkDisk;
  final bool enforceBaseline;
}

/// Runs V1..V10 plus the ASYNC-2S specific checks. Fail closed: any issue means
/// the caller must stop, and nothing is repaired or re-assigned here.
///
/// Path identity: every membership / duplicate / set comparison uses
/// [pathIdentityKey] (ASCII case-folded), because Windows treats `Foo_test.dart`
/// and `foo_test.dart` as the same file. Reported paths keep their original
/// spelling.
ValidationReport validatePlan(ValidationInput input) {
  final List<ValidationIssue> issues = <ValidationIssue>[];

  final Map<int, List<String>> approvedBatches = <int, List<String>>{
    1: input.approved.pathsOf(1),
    2: input.approved.pathsOf(2),
    3: input.approved.pathsOf(3),
  };
  final Map<int, List<String>> actualLists = <int, List<String>>{
    1: input.actualBatches[1] ?? const <String>[],
    2: input.actualBatches[2] ?? const <String>[],
    3: input.actualBatches[3] ?? const <String>[],
  };
  final List<String> approvedExcluded = input.approved.excludedPaths;

  final Map<int, Map<String, String>> approvedByIdentity = <int, Map<String, String>>{
    for (final int batch in <int>[1, 2, 3]) batch: _identityMap(approvedBatches[batch]!),
  };
  final Map<int, Map<String, String>> actualByIdentity = <int, Map<String, String>>{
    for (final int batch in <int>[1, 2, 3]) batch: _identityMap(actualLists[batch] ?? const <String>[]),
  };

  final Set<String> approvedExecutableKeys = <String>{
    ...approvedByIdentity[1]!.keys,
    ...approvedByIdentity[2]!.keys,
    ...approvedByIdentity[3]!.keys,
  };
  final Set<String> actualUnionKeys = <String>{
    ...actualByIdentity[1]!.keys,
    ...actualByIdentity[2]!.keys,
    ...actualByIdentity[3]!.keys,
  };
  final Map<String, String> actualPathByKey = <String, String>{
    ...actualByIdentity[1]!,
    ...actualByIdentity[2]!,
    ...actualByIdentity[3]!,
  };
  final Map<String, String> approvedPathByKey = <String, String>{
    ...approvedByIdentity[1]!,
    ...approvedByIdentity[2]!,
    ...approvedByIdentity[3]!,
  };
  final Map<String, String> excludedPathByKey = _identityMap(approvedExcluded);
  final Map<String, String> actualExcludedPathByKey = _identityMap(input.actualExcluded);
  final Set<String> actualExcludedKeys = actualExcludedPathByKey.keys.toSet();

  // V1 — counts. Compared against the approved plan, never used alone.
  for (final int batch in <int>[1, 2, 3]) {
    final int actualCount = (actualLists[batch] ?? const <String>[]).length;
    final int approvedCount = approvedBatches[batch]!.length;
    if (actualCount != approvedCount) {
      issues.add(ValidationIssue(
        code: IssueCode.v1Count,
        message: 'batch $batch has $actualCount file(s), approved $approvedCount',
      ));
    }
  }
  if (input.actualExcluded.length != approvedExcluded.length) {
    issues.add(ValidationIssue(
      code: IssueCode.v1Count,
      message: 'excluded has ${input.actualExcluded.length} file(s), '
          'approved ${approvedExcluded.length}',
    ));
  }

  // V1b — frozen baseline. Guards against a manifest that drifted as a whole.
  if (input.enforceBaseline) {
    final int total = input.approved.rows.length;
    final int b1 = approvedBatches[1]!.length;
    final int b2 = approvedBatches[2]!.length;
    final int b3 = approvedBatches[3]!.length;
    final int ex = approvedExcluded.length;
    if (total != kBaselineTotal ||
        b1 != kBaselineBatch1 ||
        b2 != kBaselineBatch2 ||
        b3 != kBaselineBatch3 ||
        ex != kBaselineExcluded) {
      issues.add(ValidationIssue(
        code: IssueCode.v1Baseline,
        message: 'manifest no longer matches the frozen baseline: '
            'total=$total (expected $kBaselineTotal), '
            'A1=$b1 ($kBaselineBatch1), A2=$b2 ($kBaselineBatch2), '
            'ASYNC-2S=$b3 ($kBaselineBatch3), excluded=$ex ($kBaselineExcluded)',
      ));
    }
  }

  // V2 — no duplicates inside a batch, compared by path identity.
  for (final int batch in <int>[1, 2, 3]) {
    final Map<String, String> seen = <String, String>{};
    final List<String> duplicates = <String>[];
    for (final String path in actualLists[batch] ?? const <String>[]) {
      final String identity = pathIdentityKey(path);
      final String? first = seen[identity];
      if (first == null) {
        seen[identity] = path;
      } else {
        duplicates.add('$path (same file as $first)');
      }
    }
    if (duplicates.isNotEmpty) {
      issues.add(ValidationIssue(
        code: IssueCode.v2Duplicate,
        message: 'batch $batch contains ${duplicates.length} duplicated entr(ies)',
        paths: duplicates,
      ));
    }
  }

  // V3 — exact per-batch set equality, both directions, by path identity.
  for (final int batch in <int>[1, 2, 3]) {
    final Set<String> approvedKeys = approvedByIdentity[batch]!.keys.toSet();
    final Set<String> actualKeys = actualByIdentity[batch]!.keys.toSet();
    final List<String> missing =
        _display(approvedKeys.difference(actualKeys), approvedByIdentity[batch]!);
    final List<String> extra =
        _display(actualKeys.difference(approvedKeys), actualByIdentity[batch]!);
    if (missing.isNotEmpty) {
      issues.add(ValidationIssue(
        code: IssueCode.v3Missing,
        message: 'batch $batch is missing ${missing.length} approved file(s)',
        paths: missing,
      ));
    }
    if (extra.isNotEmpty) {
      issues.add(ValidationIssue(
        code: IssueCode.v3Extra,
        message: 'batch $batch contains ${extra.length} unapproved file(s)',
        paths: extra,
      ));
    }
  }

  // V4 — pairwise disjoint, by path identity (case variants overlap).
  const List<List<int>> pairs = <List<int>>[
    <int>[1, 2],
    <int>[1, 3],
    <int>[2, 3],
  ];
  for (final List<int> pair in pairs) {
    final Set<String> overlap = actualByIdentity[pair[0]]!
        .keys
        .toSet()
        .intersection(actualByIdentity[pair[1]]!.keys.toSet());
    if (overlap.isNotEmpty) {
      issues.add(ValidationIssue(
        code: IssueCode.v4Overlap,
        message: 'batch ${pair[0]} and batch ${pair[1]} overlap on '
            '${overlap.length} file(s)',
        paths: _display(overlap, actualPathByKey),
      ));
    }
  }

  // V5 — excluded files never execute, and the excluded set matches.
  final Set<String> excludedExecuted = actualUnionKeys.intersection(actualExcludedKeys);
  if (excludedExecuted.isNotEmpty) {
    issues.add(ValidationIssue(
      code: IssueCode.v5ExcludedExecuted,
      message: '${excludedExecuted.length} excluded file(s) appear in an execution batch',
      paths: _display(excludedExecuted, actualExcludedPathByKey),
    ));
  }
  final List<String> excludedMissing =
      _display(excludedPathByKey.keys.toSet().difference(actualExcludedKeys), excludedPathByKey);
  final List<String> excludedExtra =
      _display(actualExcludedKeys.difference(excludedPathByKey.keys.toSet()), actualExcludedPathByKey);
  if (excludedMissing.isNotEmpty || excludedExtra.isNotEmpty) {
    issues.add(ValidationIssue(
      code: IssueCode.v5ExcludedSet,
      message: 'excluded set differs: missing ${excludedMissing.length}, '
          'extra ${excludedExtra.length}',
      paths: <String>[...excludedMissing, ...excludedExtra],
    ));
  }

  // V6 — the union equals the approved executable set.
  if (!_sameSet(actualUnionKeys, approvedExecutableKeys)) {
    issues.add(ValidationIssue(
      code: IssueCode.v6Union,
      message: 'union mismatch: ${actualUnionKeys.length} actual vs '
          '${approvedExecutableKeys.length} approved',
    ));
  }

  // V7 — nothing beyond the approved set.
  final List<String> beyond =
      _display(actualUnionKeys.difference(approvedExecutableKeys), actualPathByKey);
  if (beyond.isNotEmpty) {
    issues.add(ValidationIssue(
      code: IssueCode.v7Extra,
      message: '${beyond.length} executed file(s) are not in the approved set',
      paths: beyond,
    ));
  }

  // V8 — nothing missing from the approved set.
  final List<String> missing =
      _display(approvedExecutableKeys.difference(actualUnionKeys), approvedPathByKey);
  if (missing.isNotEmpty) {
    issues.add(ValidationIssue(
      code: IssueCode.v8Missing,
      message: '${missing.length} approved file(s) were not executed',
      paths: missing,
    ));
  }

  // V9 — every path exists on disk and looks like a test file.
  if (input.checkDisk) {
    final String root = input.repoRoot.replaceAll('\\', '/');
    final String prefix = root.endsWith('/') ? root : '$root/';
    final List<String> notOnDisk = <String>[];
    final List<String> notTests = <String>[];
    for (final String path in _display(actualUnionKeys, actualPathByKey)) {
      if (!path.endsWith('_test.dart')) {
        notTests.add(path);
      }
      if (!File('$prefix$path').existsSync()) {
        notOnDisk.add(path);
      }
    }
    if (notOnDisk.isNotEmpty) {
      issues.add(ValidationIssue(
        code: IssueCode.v9MissingOnDisk,
        message: '${notOnDisk.length} path(s) do not exist under $root',
        paths: notOnDisk,
      ));
    }
    if (notTests.isNotEmpty) {
      issues.add(ValidationIssue(
        code: IssueCode.v9NotTestFile,
        message: '${notTests.length} path(s) are not *_test.dart',
        paths: notTests,
      ));
    }
  }

  // V10 — the manifest did not change since the plan was generated.
  if (input.recordedFingerprint != input.currentFingerprint) {
    issues.add(ValidationIssue(
      code: IssueCode.v10ManifestDrift,
      message: 'manifest changed: recorded ${input.recordedFingerprint}, '
          'current ${input.currentFingerprint}',
    ));
  }

  // V11 — ASYNC-2S: qualification set (by identity) and the policy the plan
  // actually declares. This proves the *plan* is compliant; it does not prove
  // any run executed serially.
  final Set<String> asyncApprovedKeys = _identityMap(input.approved
          .rows
          .where((ManifestRow row) => row.qualification == 'ASYNC-2S')
          .map((ManifestRow row) => row.path)
          .toList(growable: false))
      .keys
      .toSet();
  final Set<String> actualBatch3Keys = actualByIdentity[3]!.keys.toSet();
  if (!_sameSet(actualBatch3Keys, asyncApprovedKeys)) {
    issues.add(ValidationIssue(
      code: IssueCode.v11AsyncSet,
      message: 'batch 3 must contain exactly the ASYNC-2S set '
          '(${asyncApprovedKeys.length} file(s))',
      paths: _display(actualBatch3Keys.difference(asyncApprovedKeys), actualPathByKey),
    ));
  }
  final List<String> policyViolations = input.policy.violations();
  if (policyViolations.isNotEmpty) {
    issues.add(ValidationIssue(
      code: IssueCode.v11AsyncPolicy,
      message: 'ASYNC-2S policy violated: ${policyViolations.join('; ')}',
    ));
  }

  return ValidationReport(issues);
}

/// identity key -> original spelling (last one wins; duplicates are V2's job).
Map<String, String> _identityMap(List<String> paths) {
  final Map<String, String> map = <String, String>{};
  for (final String path in paths) {
    map[pathIdentityKey(path)] = path;
  }
  return map;
}

List<String> _display(Set<String> keys, Map<String, String> byKey) {
  final List<String> values =
      keys.map((String key) => byKey[key] ?? key).toList(growable: false);
  values.sort();
  return values;
}

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
