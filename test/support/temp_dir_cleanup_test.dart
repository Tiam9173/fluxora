import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'temp_dir_cleanup.dart';

/// Phase 06.7-A — the path guard on `deleteTempDirWithRetry`.
///
/// Every case here creates its **own** directory and only ever asserts on that
/// one. Nothing touches the historical `fluxora_*` directories that already sit
/// in `%LOCALAPPDATA%\Temp`, and no case deletes anything it did not create.
void main() {
  final systemTemp = p.normalize(p.absolute(Directory.systemTemp.path));

  /// A directory this file owns, created fresh per test.
  Directory ownDir(String tag) {
    final dir = Directory.systemTemp.createTempSync('fluxora_067a_$tag');
    addTearDown(() {
      // Only this test's own directory — and only if the guard let it through.
      if (dir.existsSync()) {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {
          // Best effort in teardown; a failure here is not a test result.
        }
      }
    });
    return dir;
  }

  test('a systemTemp child is deleted', () async {
    final dir = ownDir('ok');
    File(p.join(dir.path, 'payload.json')).writeAsStringSync('{}');
    expect(dir.existsSync(), isTrue);

    await deleteTempDirWithRetry(dir);

    expect(dir.existsSync(), isFalse);
  });

  test('a missing systemTemp child is a silent no-op', () async {
    final dir = Directory(p.join(systemTemp, 'fluxora_067a_absent'));
    expect(dir.existsSync(), isFalse);

    await deleteTempDirWithRetry(dir);

    expect(dir.existsSync(), isFalse);
  });

  test('an empty path is refused', () async {
    await expectLater(
      deleteTempDirWithRetry(Directory('')),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('a relative path is refused', () async {
    await expectLater(
      deleteTempDirWithRetry(Directory('build')),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('the system temp root itself is refused', () async {
    // Must throw *before* deleting: the root still exists afterwards.
    await expectLater(
      deleteTempDirWithRetry(Directory(systemTemp)),
      throwsA(isA<ArgumentError>()),
    );
    expect(Directory(systemTemp).existsSync(), isTrue);
  });

  test('a path outside systemTemp is refused and left untouched', () async {
    // `test/` exists, is absolute, and is outside systemTemp.
    final outside = Directory(p.normalize(p.absolute('test')));
    expect(outside.existsSync(), isTrue, reason: 'precondition');

    await expectLater(
      deleteTempDirWithRetry(outside),
      throwsA(isA<ArgumentError>()),
    );

    expect(outside.existsSync(), isTrue, reason: 'nothing may be deleted');
  });

  test('a junction pointing outside systemTemp is refused', () async {
    final link = Directory(p.join(systemTemp, 'fluxora_067a_link'));
    if (link.existsSync()) link.deleteSync(recursive: true);

    var created = false;
    try {
      // Directory symlink/junction creation needs Developer Mode or an elevated
      // shell on Windows; when unavailable the test is skipped, not faked.
      await Link(link.path).create(p.normalize(p.absolute('test')));
      created = true;
    } on FileSystemException {
      created = false;
    }

    if (!created) {
      markTestSkipped(
        'cannot create a directory link without Developer Mode / elevation — '
        'the resolution guard is unverified on this host',
      );
      return;
    }

    try {
      await expectLater(
        deleteTempDirWithRetry(link),
        throwsA(isA<ArgumentError>()),
        reason: 'resolves outside systemTemp',
      );
      expect(
        Directory(p.normalize(p.absolute('test'))).existsSync(),
        isTrue,
        reason: 'the link target must not be deleted',
      );
    } finally {
      if (link.existsSync()) {
        try {
          Link(link.path).delete();
        } catch (_) {
          // ignore
        }
      }
    }
  });
}
