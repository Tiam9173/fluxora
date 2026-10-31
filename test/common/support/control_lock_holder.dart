import 'dart:io';

/// Test helper for `external_control_ownership_test.dart`.
///
/// Holds the control lock in a **separate OS process** so `ExternalControl`'s
/// cross-process ownership can be exercised for real. A second Dart object
/// inside the same VM would prove nothing: POSIX `fcntl` locks are per-process,
/// so an in-process "second instance" can succeed where a real second process
/// cannot.
///
/// Usage: `dart control_lock_holder.dart <lockFilePath> <holdMilliseconds>`
///
/// Prints `LOCKED` once the lock is held (or `BUSY` when someone else holds it),
/// then keeps it for the requested duration and prints `RELEASED`.
void main(List<String> args) {
  final lockPath = args[0];
  final holdMs = int.parse(args[1]);

  final file = File(lockPath);
  file.createSync(recursive: true);
  final handle = file.openSync(mode: FileMode.write);
  try {
    handle.lockSync(FileLock.exclusive);
  } catch (_) {
    stdout.writeln('BUSY');
    handle.closeSync();
    exit(2);
  }

  stdout.writeln('LOCKED');
  sleep(Duration(milliseconds: holdMs));
  handle.unlockSync();
  handle.closeSync();
  stdout.writeln('RELEASED');
}
