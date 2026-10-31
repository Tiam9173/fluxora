// ignore_for_file: avoid_relative_lib_imports
//
// Why the ignore: the shared libraries live in `tool/test_runner/lib/`, which is
// not the package `lib/` directory, so a `package:fluxora/...` import cannot
// reach them. A relative import is the correct form for this layout.

import 'dart:convert';
import 'dart:io';

import '../lib/record.dart';

/// R7-4 self-check: serialise a record, parse it back, and prove that the
/// "79 must stay 79" invariant is enforced by the parser.
///
/// Usage:
///   dart run tool/test_runner/bin/record_sample.dart
///
/// This prints a sample JSONL line and performs static round-trip checks. It
/// does not run tests, build anything, or touch the repository.
///
/// Exit codes: 0 = all checks passed, 3 = a check failed.
void main() {
  final ExecutionRecord sample = ExecutionRecord.sample();
  final String line = sample.toJsonLine();
  stdout.writeln('SAMPLE $line');

  final ExecutionRecord parsed = ExecutionRecord.fromJsonLine(line);
  if (parsed.filePath != sample.filePath ||
      parsed.exitCode != sample.exitCode ||
      parsed.resultLabel != sample.resultLabel ||
      parsed.approvedBatch != sample.approvedBatch ||
      parsed.actualBatch != sample.actualBatch ||
      parsed.startTimestamp != sample.startTimestamp) {
    stderr.writeln('FAILED round-trip mismatch');
    exitCode = 3;
    return;
  }
  stdout.writeln('ROUNDTRIP_OK');

  final ExecutionRecord noTests = ExecutionRecord.forRun(
    runId: '20261030-215500-b214f85a',
    batch: 1,
    batchSeq: 2,
    approvedQualification: 'A2',
    approvedBatch: 2,
    actualBatch: 1,
    filePath: 'test/services/runtime_lifecycle_test.dart',
    command: const <String>[
      'flutter',
      'test',
      'test/services/runtime_lifecycle_test.dart',
    ],
    start: DateTime(2026, 10, 30, 20, 3, 40),
    end: DateTime(2026, 10, 30, 20, 3, 44),
    exitCode: 79,
    testCount: 0,
    manifestSha256: 'b214f85a84df6f09',
    runnerVersion: '0.1.0',
  );
  final String noTestsLine = noTests.toJsonLine();
  stdout.writeln('NO_TESTS_LINE $noTestsLine');

  // Rewriting 79 -> 0 while keeping the label must be rejected.
  final Map<String, Object?> tamperedExitCode =
      jsonDecode(noTestsLine) as Map<String, Object?>;
  tamperedExitCode['exit_code'] = 0;
  if (!_rejected(jsonEncode(tamperedExitCode))) {
    stderr.writeln('FAILED: exit_code 79 -> 0 was accepted');
    exitCode = 3;
    return;
  }
  stdout.writeln('REJECT_EXIT_CODE_REWRITE_OK');

  // Rewriting both the code and the label must be rejected as well.
  final Map<String, Object?> tamperedBoth =
      jsonDecode(noTestsLine) as Map<String, Object?>;
  tamperedBoth['exit_code'] = 0;
  tamperedBoth['result_label'] = 'passed';
  if (!_rejected(jsonEncode(tamperedBoth))) {
    stderr.writeln('FAILED: 79 relabelled as passed was accepted');
    exitCode = 3;
    return;
  }
  stdout.writeln('REJECT_LABEL_REWRITE_OK');

  stdout.writeln('SAMPLE_OK');
}

bool _rejected(String line) {
  try {
    ExecutionRecord.fromJsonLine(line);
    return false;
  } on RecordFormatException {
    return true;
  }
}
