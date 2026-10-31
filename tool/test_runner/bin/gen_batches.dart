// ignore_for_file: avoid_relative_lib_imports
//
// Why the ignore: the shared libraries live in `tool/test_runner/lib/`, which is
// not the package `lib/` directory, so a `package:fluxora/...` import cannot
// reach them. A relative import is the correct form for this layout.

import 'dart:io';

import '../lib/batches.dart';
import '../lib/cli.dart';
import '../lib/manifest.dart';

/// R7-2 entry point: parse the approved manifest and publish the three batch
/// lists plus the excluded list.
///
/// Usage:
///   dart run tool/test_runner/bin/gen_batches.dart \
///       `--manifest <manifest.md> --out <plan-dir> [--repo <repo-root>]`
///
/// The command never decides a batch from file order, globbing, or list
/// position: it only maps `approved_qualification` through `kQualificationBatch`
/// and cross-checks it against the manifest's own batch column.
///
/// The plan is published atomically: it is written into a temporary directory
/// next to the target, verified, and then renamed into place. An existing
/// target is refused instead of overwritten, and the target must live outside
/// the repository.
void main(List<String> args) {
  final Map<String, String> options = parseOptions(args);
  final String? manifestPath = options['manifest'];
  final String? outDir = options['out'];
  if (manifestPath == null || outDir == null) {
    stderr.writeln('usage: gen_batches --manifest <file> --out <dir> [--repo <root>]');
    exitCode = 64;
    return;
  }
  final String repoRoot = options['repo'] ?? Directory.current.path;

  try {
    final ManifestDocument document = loadManifest(manifestPath);
    final BatchPlan plan = buildBatchPlan(document);
    final PlanPublishResult published = publishPlan(plan, outDir, repoRoot: repoRoot);
    final Map<String, int> counts =
        plan.summary()['batch_counts']! as Map<String, int>;

    stdout.writeln('MANIFEST ${document.sourcePath}');
    stdout.writeln('MANIFEST_SHA256 ${document.sha256}');
    stdout.writeln('ROWS ${document.rows.length}');
    stdout.writeln('BATCH1 ${counts['1']}');
    stdout.writeln('BATCH2 ${counts['2']}');
    stdout.writeln('BATCH3 ${counts['3']}');
    stdout.writeln('EXCLUDED ${plan.excludedPaths.length}');
    stdout.writeln('EXECUTABLE ${plan.executableCount}');
    stdout.writeln('OUT ${published.directory}');
    for (final String path in published.files) {
      stdout.writeln('WROTE $path');
    }
    stdout.writeln('GEN_OK');
  } on ManifestException catch (error) {
    stderr.writeln('GEN_FAILED $error');
    exitCode = 2;
  }
}
