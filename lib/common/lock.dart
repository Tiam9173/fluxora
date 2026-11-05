import 'dart:io';

import 'package:fluxora/common/common.dart';

/// The process-wide single-instance lock.
///
/// P9-B2 — exactly **one** non-blocking attempt per call.
///
/// The retry policy lives in `resolveSingleInstance`, which is the only place
/// that knows *why* the lock was busy: a cold start must not wait at all, while
/// a controlled restart has to outlast the outgoing process's teardown. The
/// hidden `15 x 1 s` loop that used to live here charged every caller that
/// budget, so a start that only needed "try once, it is free" still slept for
/// up to 14 s when the answer was no.
class SingleInstanceLock {
  static SingleInstanceLock? _instance;
  RandomAccessFile? _accessFile;

  SingleInstanceLock._internal();

  factory SingleInstanceLock() {
    _instance ??= SingleInstanceLock._internal();
    return _instance!;
  }

  /// True when **this** process owns the lock.
  ///
  /// Never blocks: `FileLock.exclusive` is the non-blocking variant, so a lock
  /// held by another process throws instead of waiting. Every failure path
  /// closes its own handle — a retry loop must not leak one open file per
  /// attempt, which is what the old loop did.
  ///
  /// A successful handle is kept for the rest of the process lifetime on
  /// purpose: the lock must stay held from start to exit, and the OS releases
  /// it when the process dies. Releasing it early would let a second instance
  /// start while this one still owns the profile.
  Future<bool> acquire() async {
    if (_accessFile != null) return true;

    RandomAccessFile? handle;
    try {
      final lockFilePath = await appPath.lockFilePath;
      commonPrint.log(
        'SingleInstanceLock acquire: dev=${AppIdentity.isDev}, lock=$lockFilePath',
      );
      final lockFile = File(lockFilePath);
      await lockFile.create(recursive: true);
      handle = await lockFile.open(mode: FileMode.write);
      await handle.lock();
      _accessFile = handle;
      return true;
    } catch (e) {
      // A refused lock is the normal "someone else is running" answer, not an
      // error worth a stack trace.
      commonPrint.log('SingleInstanceLock acquire failed: $e');
      try {
        await handle?.close();
      } catch (_) {}
      return false;
    }
  }
}

final singleInstanceLock = SingleInstanceLock();
