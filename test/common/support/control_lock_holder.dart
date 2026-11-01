import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Test helper for `external_control_ownership_test.dart`.
///
/// Holds the control lock in a **separate OS process** so `ExternalControl`'s
/// cross-process ownership can be exercised for real. A second Dart object
/// inside the same VM would prove nothing: POSIX `fcntl` locks are per-process,
/// so an in-process "second instance" can succeed where a real second process
/// cannot.
///
/// Usage: `dart control_lock_holder.dart <lockFilePath> [watchdogMilliseconds]`
///
/// Prints `LOCKED` once the lock is held (or `BUSY` when someone else holds it),
/// then waits for an explicit **`RELEASE` line on stdin**. On release it unlocks,
/// closes the handle, prints `RELEASED` and exits 0.
///
/// P7-B3-A — why a protocol instead of a fixed hold:
///
/// The parent used to spawn this with a fixed `holdMilliseconds` and `kill()` it
/// afterwards. On Windows `Process.start(..., runInShell: true)` puts a **shell**
/// between the two, so `kill()` only killed the shell: this process kept holding
/// the lock for its full hold time, which made the sandbox undeletable at
/// `tearDownAll` and leaked one `fluxora_test_data_<pid>` per run.
///
/// [watchdogMilliseconds] is **not** the normal release path — it only stops a
/// crashed parent from wedging the lock forever. Closing stdin does the same.
void main(List<String> args) async {
  final lockPath = args[0];
  final watchdogMs = args.length > 1 ? int.parse(args[1]) : 120000;

  final file = File(lockPath);
  file.createSync(recursive: true);
  final handle = file.openSync(mode: FileMode.write);
  try {
    handle.lockSync(FileLock.exclusive);
  } catch (_) {
    stdout.writeln('BUSY');
    await stdout.flush();
    handle.closeSync();
    exit(2);
  }

  stdout.writeln('LOCKED');
  await stdout.flush();

  final release = Completer<void>();
  final sub = stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(
        (line) {
          if (line.trim() == 'RELEASE' && !release.isCompleted) {
            release.complete();
          }
        },
        onDone: () {
          // The parent went away without asking: release rather than leak.
          if (!release.isCompleted) release.complete();
        },
      );
  final watchdog = Timer(Duration(milliseconds: watchdogMs), () {
    if (!release.isCompleted) release.complete();
  });

  await release.future;
  watchdog.cancel();
  await sub.cancel();

  handle.unlockSync();
  handle.closeSync();
  stdout.writeln('RELEASED');
  await stdout.flush();
  exit(0);
}
