// ignore_for_file: avoid_relative_lib_imports
//
// Why the ignore: the shared libraries live in `tool/test_runner/lib/`, which is
// not the package `lib/` directory, so a `package:fluxora/...` import cannot
// reach them. A relative import is the correct form for this layout.

import 'dart:io';

import '../lib/cli.dart';
import '../lib/side_effects.dart';

/// R7-5 entry point: capture a filesystem snapshot or diff two snapshots.
///
/// Usage:
///   `dart run tool/test_runner/bin/snapshot_side_effects.dart capture`
///       `--repo <repo-root> --out <snapshot.jsonl>`
///       `[--no-hash] [--max-hash-bytes N] [--timeout SECONDS] [--quiet]`
///
///   `dart run tool/test_runner/bin/snapshot_side_effects.dart compare`
///       `--before <a.jsonl> --after <b.jsonl> --out <diff.jsonl> [--repo <root>]`
///
/// The collector never runs an external process, never touches the network, and
/// never writes anywhere except the single `--out` file it validated first.
void main(List<String> args) {
  if (args.isEmpty) {
    _usage();
    exitCode = 2;
    return;
  }
  final String command = args.first;
  final Map<String, String> options = parseOptions(args.sublist(1));

  try {
    switch (command) {
      case 'capture':
        _capture(options);
        break;
      case 'compare':
        _compare(options);
        break;
      default:
        stderr.writeln('unknown command "$command"');
        _usage();
        exitCode = 2;
    }
  } on SideEffectException catch (error) {
    stderr.writeln('SIDE_EFFECT_ERROR $error');
    exitCode = 2;
  } on FileSystemException catch (error) {
    stderr.writeln('SIDE_EFFECT_IO_ERROR $error');
    exitCode = 2;
  }
}

void _usage() {
  stderr.writeln('usage:');
  stderr.writeln('  snapshot_side_effects capture --repo <root> --out <file> '
      '[--no-hash] [--max-hash-bytes N] [--timeout SECONDS] [--quiet]');
  stderr.writeln('  snapshot_side_effects compare --before <file> '
      '--after <file> --out <file> [--repo <root>]');
}

int _positiveInt(Map<String, String> options, String key, int fallback) {
  final String? raw = options[key];
  if (raw == null || raw == 'true') {
    return fallback;
  }
  final int? parsed = int.tryParse(raw);
  if (parsed == null || parsed <= 0) {
    throw SideEffectException('--$key must be a positive integer, got "$raw"');
  }
  return parsed;
}

String _required(Map<String, String> options, String key) {
  final String? value = options[key];
  if (value == null || value.isEmpty || value == 'true') {
    throw SideEffectException('--$key is required');
  }
  return value;
}

void _capture(Map<String, String> options) {
  final String repoRoot = options['repo'] ?? '.';
  if (!Directory(repoRoot).existsSync()) {
    throw SideEffectException('--repo is not a directory: "$repoRoot"');
  }
  final String outPath = _required(options, 'out');
  final int maxHashBytes =
      _positiveInt(options, 'max-hash-bytes', kDefaultMaxHashBytes);
  final int timeoutSeconds =
      _positiveInt(options, 'timeout', kDefaultScanTimeoutSeconds);
  final bool hashFiles = !flag(options, 'no-hash');
  final bool quiet = flag(options, 'quiet');

  final List<ScanRoot> roots = resolveScanRoots(repoRoot: repoRoot);

  // Validate the destination *before* spending time on the scan.
  final String target =
      validateOutputPath(outPath: outPath, roots: roots, repoRoot: repoRoot);

  final CaptureResult result = captureSideEffects(
    repoRoot: repoRoot,
    maxHashBytes: maxHashBytes,
    timeoutSeconds: timeoutSeconds,
    hashFiles: hashFiles,
    progress: quiet ? null : (String message) => stderr.writeln('PROGRESS $message'),
  );

  writeSnapshot(outPath: target, content: encodeCapture(result));

  stdout.writeln('SNAPSHOT $target');
  stdout.writeln('SCHEMA $kSideEffectSchemaVersion');
  stdout.writeln('SNAPSHOT_TIME ${result.snapshotTime.toIso8601String()}');
  stdout.writeln('ROOTS ${result.roots.length}');
  for (final ScanRoot root in result.roots) {
    final String aliases =
        root.aliases.isEmpty ? '' : ' aliases=${root.aliases.join(',')}';
    final String missing = root.exists ? '' : ' (missing)';
    stdout.writeln('ROOT ${root.label} ${root.realPath}$missing$aliases');
  }
  stdout.writeln('ENTRIES ${result.entries.length}');
  final Map<String, int> byType = result.countByType();
  for (final String key in byType.keys.toList()..sort()) {
    stdout.writeln('TYPE $key ${byType[key]}');
  }
  final Map<String, int> byHash = result.countByHashStatus();
  for (final String key in byHash.keys.toList()..sort()) {
    stdout.writeln('HASH $key ${byHash[key]}');
  }
  stdout.writeln('ISSUES ${result.issues.length}');
  stdout.writeln('TRUNCATED ${result.truncated}');
  if (result.truncated) {
    stdout.writeln('TRUNCATION_REASON ${result.truncationReason}');
    stdout.writeln('UNVISITED_DIRECTORIES ${result.unvisitedDirectories}');
  }
  stdout.writeln(
      'ELAPSED ${(result.elapsed.inMilliseconds / 1000).toStringAsFixed(2)}');
  stdout.writeln('CAPTURE_OK');
}

void _compare(Map<String, String> options) {
  final String beforePath = _required(options, 'before');
  final String afterPath = _required(options, 'after');
  final String outPath = _required(options, 'out');
  final String repoRoot = options['repo'] ?? '.';

  final SnapshotFile before = readSnapshot(beforePath);
  final SnapshotFile after = readSnapshot(afterPath);

  final List<ScanRoot> roots =
      after.roots.isNotEmpty ? after.roots : before.roots;
  final String target =
      validateOutputPath(outPath: outPath, roots: roots, repoRoot: repoRoot);

  final DiffResult result =
      compareSnapshots(before: before, after: after);
  writeSnapshot(outPath: target, content: encodeDiff(result));

  stdout.writeln('DIFF $target');
  stdout.writeln('BEFORE ${before.sourcePath} entries=${before.entries.length}');
  stdout.writeln('AFTER ${after.sourcePath} entries=${after.entries.length}');
  final Map<String, int> counts = result.counts();
  for (final String key in <String>[
    'new',
    'deleted',
    'modified',
    'unchanged',
    'unverifiable'
  ]) {
    stdout.writeln('STATUS $key ${counts[key] ?? 0}');
  }
  stdout.writeln('RECORDS ${result.records.length}');
  stdout.writeln('COMPARE_OK');
}
