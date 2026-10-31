import 'dart:convert';

import 'sha256.dart';

/// Raised when a JSONL line violates the record contract.
class RecordFormatException implements Exception {
  RecordFormatException(this.message);

  final String message;

  @override
  String toString() => 'RecordFormatException: $message';
}

/// Result label. It is a **label**, never a replacement for the exit code.
enum ResultLabel {
  passed('passed'),
  noTests('no_tests'),
  failed('failed'),
  timeout('timeout'),
  crashed('crashed'),
  unknown('unknown');

  const ResultLabel(this.wireName);

  final String wireName;

  static ResultLabel fromWire(String value) {
    for (final ResultLabel label in ResultLabel.values) {
      if (label.wireName == value) {
        return label;
      }
    }
    throw RecordFormatException('unknown result_label "$value"');
  }
}

/// Maps a raw exit code to its label.
///
/// `79` means "no tests were found": it is neither a pass nor a failure and must
/// keep its raw value. Nothing in this library may turn 79 into 0.
ResultLabel labelForExitCode(int exitCode) {
  switch (exitCode) {
    case 0:
      return ResultLabel.passed;
    case 79:
      return ResultLabel.noTests;
    case 1:
      return ResultLabel.failed;
    case 124:
      return ResultLabel.timeout;
    default:
      return ResultLabel.crashed;
  }
}

/// `2026-10-30T19:50:16.123+08:00`
String isoWithOffset(DateTime time) {
  final Duration offset = time.timeZoneOffset;
  final String sign = offset.isNegative ? '-' : '+';
  final Duration absolute = offset.abs();
  final String hours = absolute.inHours.toString().padLeft(2, '0');
  final String minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  return '${time.toIso8601String()}$sign$hours:$minutes';
}

final RegExp _isoWithOffset = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?[+-]\d{2}:\d{2}$',
);

/// One append-only JSONL record. Every line is self-contained: it carries the
/// run id and manifest fingerprint, so a single line can be interpreted without
/// reading any other line.
class ExecutionRecord {
  const ExecutionRecord._({
    required this.runId,
    required this.batch,
    required this.batchSeq,
    required this.approvedQualification,
    required this.approvedBatch,
    required this.actualBatch,
    required this.filePath,
    required this.command,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.durationSeconds,
    required this.exitCode,
    required this.resultLabel,
    required this.testCount,
    required this.timeoutSeconds,
    required this.stdoutLog,
    required this.stderrLog,
    required this.manifestSha256,
    required this.runnerVersion,
  });

  final String runId;
  final int batch;
  final int batchSeq;

  /// `approved_qualification` — copied from the manifest, never inferred.
  final String approvedQualification;

  /// `approved_batch` — copied from the manifest.
  final int? approvedBatch;

  /// `actual_batch` — where the file really ran. Keeping both columns is what
  /// makes a batch mix-up visible after the fact.
  final int actualBatch;

  final String filePath;
  final List<String> command;
  final String startTimestamp;
  final String endTimestamp;
  final double durationSeconds;

  /// Raw exit code. Never normalised, never remapped.
  final int exitCode;

  final ResultLabel resultLabel;
  final int testCount;
  final int timeoutSeconds;
  final String? stdoutLog;
  final String? stderrLog;
  final String manifestSha256;
  final String runnerVersion;

  /// Builds a record from real timestamps and derives the label from [exitCode].
  factory ExecutionRecord.forRun({
    required String runId,
    required int batch,
    required int batchSeq,
    required String approvedQualification,
    required int? approvedBatch,
    required int actualBatch,
    required String filePath,
    required List<String> command,
    required DateTime start,
    required DateTime end,
    required int exitCode,
    required int testCount,
    required String manifestSha256,
    required String runnerVersion,
    int timeoutSeconds = 600,
    String? stdoutLog,
    String? stderrLog,
  }) {
    final Duration elapsed = end.difference(start);
    return ExecutionRecord._(
      runId: runId,
      batch: batch,
      batchSeq: batchSeq,
      approvedQualification: approvedQualification,
      approvedBatch: approvedBatch,
      actualBatch: actualBatch,
      filePath: filePath,
      command: List<String>.unmodifiable(command),
      startTimestamp: isoWithOffset(start),
      endTimestamp: isoWithOffset(end),
      durationSeconds: elapsed.inMilliseconds / 1000.0,
      exitCode: exitCode,
      resultLabel: labelForExitCode(exitCode),
      testCount: testCount,
      timeoutSeconds: timeoutSeconds,
      stdoutLog: stdoutLog,
      stderrLog: stderrLog,
      manifestSha256: manifestSha256,
      runnerVersion: runnerVersion,
    );
  }

  /// Parses one JSONL line and re-checks the invariants that matter for audit.
  factory ExecutionRecord.fromJsonLine(String line) {
    final Object? decoded = jsonDecode(line);
    if (decoded is! Map<String, Object?>) {
      throw RecordFormatException('line is not a JSON object');
    }
    final Map<String, Object?> json = decoded;

    int requireInt(String key) {
      final Object? value = json[key];
      if (value is int) {
        return value;
      }
      throw RecordFormatException('"$key" must be an integer, found $value');
    }

    String requireString(String key) {
      final Object? value = json[key];
      if (value is String) {
        return value;
      }
      throw RecordFormatException('"$key" must be a string, found $value');
    }

    final int exitCode = requireInt('exit_code');
    final ResultLabel label = ResultLabel.fromWire(requireString('result_label'));
    if (label != labelForExitCode(exitCode)) {
      throw RecordFormatException(
        'exit_code $exitCode contradicts result_label "${label.wireName}"; '
        'exit codes must never be rewritten or relabelled',
      );
    }

    final String start = requireString('start_timestamp');
    final String end = requireString('end_timestamp');
    for (final String stamp in <String>[start, end]) {
      if (!_isoWithOffset.hasMatch(stamp)) {
        throw RecordFormatException(
            'timestamp "$stamp" is not ISO-8601 with an explicit offset');
      }
    }

    final Object? command = json['command'];
    if (command is! List<Object?> || command.any((Object? e) => e is! String)) {
      throw RecordFormatException('"command" must be a list of strings');
    }

    final ExecutionRecord record = ExecutionRecord._(
      runId: requireString('run_id'),
      batch: requireInt('batch'),
      batchSeq: requireInt('batch_seq'),
      approvedQualification: requireString('approved_qualification'),
      approvedBatch: json['approved_batch'] is int ? json['approved_batch']! as int : null,
      actualBatch: requireInt('actual_batch'),
      filePath: requireString('file_path'),
      command: List<String>.unmodifiable(command.cast<String>()),
      startTimestamp: start,
      endTimestamp: end,
      durationSeconds: (json['duration_seconds'] as num).toDouble(),
      exitCode: exitCode,
      resultLabel: label,
      testCount: requireInt('test_count'),
      timeoutSeconds: requireInt('timeout_seconds'),
      stdoutLog: json['stdout_log'] as String?,
      stderrLog: json['stderr_log'] as String?,
      manifestSha256: requireString('manifest_sha256'),
      runnerVersion: requireString('runner_version'),
    );
    _verifyDigest(json, record);
    return record;
  }

  Map<String, Object?> toJson() {
    final Map<String, Object?> payload = <String, Object?>{
      'run_id': runId,
      'batch': batch,
      'batch_seq': batchSeq,
      'approved_qualification': approvedQualification,
      'approved_batch': approvedBatch,
      'actual_batch': actualBatch,
      'file_path': filePath,
      'command': command,
      'start_timestamp': startTimestamp,
      'end_timestamp': endTimestamp,
      'duration_seconds': durationSeconds,
      'exit_code': exitCode,
      'result_label': resultLabel.wireName,
      'test_count': testCount,
      'timeout_seconds': timeoutSeconds,
      'stdout_log': stdoutLog,
      'stderr_log': stderrLog,
      'manifest_sha256': manifestSha256,
      'runner_version': runnerVersion,
    };
    return <String, Object?>{
      ...payload,
      'record_sha256': _digestOf(payload),
    };
  }

  /// Single line, no trailing newline; callers append `\n` when writing.
  String toJsonLine() => jsonEncode(toJson());

  /// A record used to demonstrate the wire format. Values are synthetic; the
  /// file path and qualification mirror a real Batch 1 entry.
  static ExecutionRecord sample() => ExecutionRecord.forRun(        runId: '20261030-215500-b214f85a',
        batch: 1,
        batchSeq: 1,
        approvedQualification: 'A1',
        approvedBatch: 1,
        actualBatch: 1,
        filePath: 'test/application_lifecycle_guard_test.dart',
        command: const <String>[
          'flutter',
          'test',
          'test/application_lifecycle_guard_test.dart',
        ],
        start: DateTime(2026, 10, 30, 19, 50, 16, 123),
        end: DateTime(2026, 10, 30, 19, 50, 21, 456),
        exitCode: 0,
        testCount: 7,
        manifestSha256: 'b214f85a84df6f09',
        runnerVersion: '0.1.0',
        stdoutLog: 'results/batch1/001_application_lifecycle_guard_test.stdout.log',
        stderrLog: 'results/batch1/001_application_lifecycle_guard_test.stderr.log',
      );
}

/// SHA-256 over the canonical JSON of the record payload (every field except
/// `record_sha256`).
///
/// The digest makes a coherent rewrite detectable: changing `exit_code` from 79
/// to 0 *and* the label to `passed` keeps the semantic invariant intact, but it
/// no longer matches the digest, so [ExecutionRecord.fromJsonLine] rejects it.
String _digestOf(Map<String, Object?> payload) =>
    Sha256.hexOfBytes(utf8.encode(jsonEncode(payload)));

void _verifyDigest(Map<String, Object?> json, ExecutionRecord record) {
  final Object? recorded = json['record_sha256'];
  if (recorded is! String || recorded.isEmpty) {
    throw RecordFormatException('missing record_sha256');
  }
  final Map<String, Object?> payload = record.toJson()..remove('record_sha256');
  final String recomputed = _digestOf(payload);
  if (recomputed != recorded) {
    throw RecordFormatException(
      'record_sha256 mismatch: the record was modified after it was written '
      '(recorded $recorded, recomputed $recomputed)',
    );
  }
}
