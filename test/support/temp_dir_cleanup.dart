import 'dart:io';

import 'package:path/path.dart' as p;

/// P2.3-C — bounded, test-only temp-directory cleanup.
///
/// Deleting an isolated test directory can transiently fail on Windows with
/// `errno 32` (`ERROR_SHARING_VIOLATION` / "另一个程序正在使用此文件") while a
/// just-finished async write is still releasing its handle. Callers MUST first
/// stop/flush the async activity (e.g. `await manager.flushReliabilityStats()`)
/// and restore any path overrides — this helper is only the last-resort safety
/// net, never the primary fix.
///
/// Semantics:
///  * retries a **bounded** number of times with a **bounded** delay;
///  * only retries the transient sharing violation (`errno 32`);
///  * **rethrows** on the final attempt (and on any non-transient error) so a
///    genuinely leaked handle fails loudly instead of being swallowed.
///
/// Phase 06.7-A — path guard:
///
/// The helper used to trust its caller completely: whatever `Directory` arrived
/// got `delete(recursive: true)`. Every current caller passes a
/// `Directory.systemTemp` child, but nothing enforced it, and this file lives in
/// `test/support/` where future tests will reuse it. It now refuses anything it
/// cannot prove is a temporary directory **before** touching the disk:
///
///  1. empty path            → `ArgumentError`
///  2. relative path         → `ArgumentError`
///  3. `systemTemp` itself   → `ArgumentError`
///  4. outside `systemTemp`  → `ArgumentError` (both sides normalised)
///  5. resolves elsewhere    → `ArgumentError` (symlink / junction / reparse)
///
/// Steps 1–4 are pure string work. Step 5 resolves the real path, and a
/// resolution failure means "cannot prove it is safe" ⇒ refuse.
///
/// **This does not eliminate TOCTOU.** Between the resolution and the
/// `delete(recursive: true)` the target can still be swapped for a junction by
/// another process; Dart exposes no handle-based delete that would close that
/// window. The guard removes the *accidental* case — a caller passing a wrong
/// path — which is what this helper is for. It is not a sandbox.
/// P7-B3-B — test-only seam for the delete step itself.
///
/// Before this, the only way to make the delete fail with `errno 32` was to keep
/// a real file handle open, which is a timing race and made the retry policy
/// untestable. A caller can now substitute the delete step; production passes
/// nothing, so the default below is exactly the call that ran before.
typedef TempDirDeleter = Future<void> Function(Directory dir);

Future<void> deleteTempDirWithRetry(
  Directory dir, {
  int maxAttempts = 5,
  Duration retryDelay = const Duration(milliseconds: 100),
  TempDirDeleter? deleteForTest,
}) async {
  await assertSafeTempTarget(dir);

  final delete = deleteForTest ?? (Directory d) => d.delete(recursive: true);

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    if (!dir.existsSync()) return;
    try {
      await delete(dir);
      return;
    } on FileSystemException catch (e) {
      final errno = e.osError?.errorCode;
      // 32 = ERROR_SHARING_VIOLATION (Windows "file in use").
      final isTransientLock = errno == 32;
      if (!isTransientLock || attempt == maxAttempts) {
        rethrow; // fail loudly — never hide a real resource leak
      }
      await Future<void>.delayed(retryDelay);
    }
  }
}

/// Refuses any target that cannot be proven to be a child of `systemTemp`.
///
/// Fails closed: every uncertain case throws instead of falling back to the
/// string check alone. Public so the guard can be asserted directly, without
/// exercising the delete path.
Future<void> assertSafeTempTarget(Directory dir) async {
  final raw = dir.path;
  if (raw.trim().isEmpty) {
    throw ArgumentError.value(raw, 'dir', 'refusing an empty path');
  }
  if (!p.isAbsolute(raw)) {
    throw ArgumentError.value(raw, 'dir', 'refusing a relative path');
  }

  final root = p.normalize(p.absolute(Directory.systemTemp.path));
  final target = p.normalize(p.absolute(raw));

  if (target == root) {
    throw ArgumentError.value(
      raw,
      'dir',
      'refusing to delete the system temp root itself',
    );
  }
  if (!p.isWithin(root, target)) {
    throw ArgumentError.value(raw, 'dir', 'refusing a path outside systemTemp');
  }

  // A path that does not exist has nothing to delete; keep the silent no-op the
  // callers already rely on. Only an existing path must prove where it points.
  if (!dir.existsSync()) return;

  final String realRoot;
  final String realTarget;
  try {
    realRoot = p.normalize(await Directory(root).resolveSymbolicLinks());
    realTarget = p.normalize(await dir.resolveSymbolicLinks());
  } on FileSystemException catch (e) {
    throw ArgumentError.value(
      raw,
      'dir',
      'cannot resolve the real path (${e.message}); refusing to delete',
    );
  }

  if (realTarget == realRoot || !p.isWithin(realRoot, realTarget)) {
    throw ArgumentError.value(
      raw,
      'dir',
      'resolves outside systemTemp ($realTarget); refusing to delete',
    );
  }
}
