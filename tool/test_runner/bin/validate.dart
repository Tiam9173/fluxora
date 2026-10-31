// ignore_for_file: avoid_relative_lib_imports
//
// Why the ignore: the shared libraries live in `tool/test_runner/lib/`, which is
// not the package `lib/` directory, so a `package:fluxora/...` import cannot
// reach them. A relative import is the correct form for this layout.

import 'dart:io';

import '../lib/batches.dart';
import '../lib/cli.dart';
import '../lib/manifest.dart';
import '../lib/validate.dart';

/// R7-3 entry point: run V1..V10 (plus the ASYNC-2S checks) over a generated
/// plan and fail closed.
///
/// Usage:
///   dart run tool/test_runner/bin/validate.dart \
///       `--manifest <manifest.md> --plan <plan-dir> [--repo <root>]` \
///       [--no-disk] [--no-baseline]
///
/// The ASYNC-2S policy is read from the plan's own `manifest.json` (F-02): the
/// validator never falls back to the in-code constant, so a damaged or edited
/// plan cannot pass by accident.
///
/// Exit codes: 0 = passed, 2 = failed/error, 64 = usage.
void main(List<String> args) {
  final Map<String, String> options = parseOptions(args);
  final String? manifestPath = options['manifest'];
  final String? planDir = options['plan'];
  if (manifestPath == null || planDir == null) {
    stderr.writeln(
        'usage: validate --manifest <file> --plan <dir> [--repo <root>] [--no-disk] [--no-baseline]');
    exitCode = 64;
    return;
  }

  try {
    final ManifestDocument document = loadManifest(manifestPath);
    final BatchPlan approved = buildBatchPlan(document);
    final Map<int, List<String>> actualBatches = readPlanBatches(planDir);
    final List<String> actualExcluded = readPlanExcluded(planDir);
    final String recordedFingerprint = readRecordedFingerprint(planDir);
    final Batch3Policy policy = readPlanPolicy(planDir);

    final ValidationReport report = validatePlan(ValidationInput(
      approved: approved,
      actualBatches: actualBatches,
      actualExcluded: actualExcluded,
      recordedFingerprint: recordedFingerprint,
      currentFingerprint: document.sha256,
      policy: policy,
      repoRoot: options['repo'] ?? '.',
      checkDisk: !flag(options, 'no-disk'),
      enforceBaseline: !flag(options, 'no-baseline'),
    ));

    for (final String line in report.format()) {
      stdout.writeln(line);
    }
    if (!report.passed) {
      exitCode = 2;
    }
  } on ManifestException catch (error) {
    stderr.writeln('VALIDATE_ERROR $error');
    exitCode = 2;
  }
}
