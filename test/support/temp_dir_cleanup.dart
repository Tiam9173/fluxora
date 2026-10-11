import 'dart:io';

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
Future<void> deleteTempDirWithRetry(
  Directory dir, {
  int maxAttempts = 5,
  Duration retryDelay = const Duration(milliseconds: 100),
}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    if (!dir.existsSync()) return;
    try {
      await dir.delete(recursive: true);
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
