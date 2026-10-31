// ignore_for_file: avoid_relative_lib_imports
//
// Why the ignore: the shared libraries live in `tool/test_runner/lib/`, which is
// not the package `lib/` directory, so a `package:fluxora/...` import cannot
// reach them. A relative import is the correct form for this layout.

import 'dart:io';

import '../lib/batches.dart';
import '../lib/cli.dart';
import '../lib/manifest.dart';

/// R7-3 evidence replay: re-derive the E-2 batch diff from the historical
/// command lists, without touching them and without running any test.
///
/// Usage:
///   dart run tool/test_runner/bin/replay_e2.dart \
///       `--manifest <manifest.md>` \
///       `--b1 <b1.cmds> --b2 <b2.final.txt> --b3 <b3_files.txt>`
///
/// Expected historical outcome (PHASE 06.8-E-2):
///   batch 1: 32 extra (A2 files pulled forward) + 32 missing (A1 files pushed back)
///   batch 2: 32 extra + 32 missing, exactly mirrored against batch 1
///   batch 3: 0 extra + 0 missing
///
/// Exit codes: 0 = expectations reproduced, 3 = expectations not reproduced,
/// 2 = input error, 64 = usage.
void main(List<String> args) {
  final Map<String, String> options = parseOptions(args);
  final String? manifestPath = options['manifest'];
  final String? b1Path = options['b1'];
  final String? b2Path = options['b2'];
  final String? b3Path = options['b3'];
  if (manifestPath == null || b1Path == null || b2Path == null || b3Path == null) {
    stderr.writeln(
        'usage: replay_e2 --manifest <file> --b1 <cmds> --b2 <list> --b3 <list>');
    exitCode = 64;
    return;
  }

  try {
    final ManifestDocument document = loadManifest(manifestPath);
    final BatchPlan approved = buildBatchPlan(document);

    final Map<int, List<String>> actual = <int, List<String>>{
      1: _readPathList(b1Path),
      2: _readPathList(b2Path),
      3: _readPathList(b3Path),
    };

    stdout.writeln('MANIFEST_SHA256 ${document.sha256}');
    stdout.writeln('APPROVED ${approved.executableCount}');
    for (final int batch in <int>[1, 2, 3]) {
      stdout.writeln('APPROVED_BATCH$batch ${approved.pathsOf(batch).length}');
      stdout.writeln('ACTUAL_BATCH$batch ${actual[batch]!.length}');
    }

    final Map<int, List<String>> extra = <int, List<String>>{};
    final Map<int, List<String>> missing = <int, List<String>>{};
    for (final int batch in <int>[1, 2, 3]) {
      final Set<String> approvedSet = approved.pathsOf(batch).toSet();
      final Set<String> actualSet = actual[batch]!.toSet();
      extra[batch] = _sorted(actualSet.difference(approvedSet));
      missing[batch] = _sorted(approvedSet.difference(actualSet));
    }

    bool ok = true;
    const Map<int, int> expectedExtra = <int, int>{1: 32, 2: 32, 3: 0};
    const Map<int, int> expectedMissing = <int, int>{1: 32, 2: 32, 3: 0};

    for (final int batch in <int>[1, 2, 3]) {
      final List<String> batchExtra = extra[batch]!;
      final List<String> batchMissing = missing[batch]!;
      stdout.writeln('BATCH$batch EXTRA ${batchExtra.length} '
          'MISSING ${batchMissing.length}');
      for (final String path in batchExtra) {
        stdout.writeln('  EXTRA $path');
      }
      for (final String path in batchMissing) {
        stdout.writeln('  MISSING $path');
      }
      if (batchExtra.length != expectedExtra[batch] ||
          batchMissing.length != expectedMissing[batch]) {
        ok = false;
        stderr.writeln('EXPECTATION_FAILED batch $batch: expected '
            '${expectedExtra[batch]}/${expectedMissing[batch]}, '
            'observed ${batchExtra.length}/${batchMissing.length}');
      }
    }

    final bool mirrorForward = _sameList(extra[1]!, missing[2]!);
    final bool mirrorBackward = _sameList(missing[1]!, extra[2]!);
    stdout.writeln('MIRROR_EXTRA_B1_EQ_MISSING_B2 $mirrorForward');
    stdout.writeln('MIRROR_MISSING_B1_EQ_EXTRA_B2 $mirrorBackward');
    if (!mirrorForward || !mirrorBackward) {
      ok = false;
      stderr.writeln('EXPECTATION_FAILED: batch 1 and batch 2 are not mirrored');
    }

    if (!ok) {
      stdout.writeln('REPLAY_MISMATCH');
      exitCode = 3;
      return;
    }
    stdout.writeln('REPLAY_OK');
  } on ManifestException catch (error) {
    stderr.writeln('REPLAY_ERROR $error');
    exitCode = 2;
  }
}

/// Reads a historical list. `b1.cmds` stores full commands, so the last
/// whitespace-separated token is taken; plain path lists pass through unchanged.
List<String> _readPathList(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw ManifestException('historical list not found: $path');
  }
  final List<String> paths = <String>[];
  for (final String raw in file.readAsLinesSync()) {
    final String line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final List<String> tokens = line.split(RegExp(r'\s+'));
    paths.add(tokens.last);
  }
  return paths;
}

List<String> _sorted(Set<String> values) => values.toList()..sort();

bool _sameList(List<String> a, List<String> b) {
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
