import 'dart:io';

import 'package:fluxora/common/external_control.dart';
import 'package:fluxora/common/identity.dart';
import 'package:fluxora/main.dart';
import 'package:flutter_test/flutter_test.dart';

/// R-MULTI — the single-instance decision, without the side effects.
///
/// `_enforceSingleInstance` calls `exit()`, which a test process cannot survive,
/// so the decision is separated into [resolveSingleInstance] and tested here.
/// Nothing here takes a real lock or opens a control channel.
void main() {
  group('resolveSingleInstance', () {
    // P9-B2 — the lock is asked first. Reading the control channel first is what
    // made every start with a stale port file pay 3 x 1 s of connect timeouts.
    Future<SingleInstanceDecision> resolve({
      required Future<bool> Function() probe,
      required Future<bool> Function() acquire,
    }) {
      return resolveSingleInstance(
        probe: probe,
        acquire: acquire,
        acquireDelay: Duration.zero,
        probeDelay: Duration.zero,
      );
    }

    test('a free lock starts without probing', () async {
      var probeCalls = 0;

      final decision = await resolve(
        probe: () async {
          probeCalls++;
          return true;
        },
        acquire: () async => true,
      );

      expect(decision, SingleInstanceDecision.start);
      expect(
        probeCalls,
        0,
        reason: 'owning the lock is proof; the channel must not be read',
      );
    });

    test('a held lock hands off to the instance that answered', () async {
      var acquireCalls = 0;

      final decision = await resolve(
        probe: () async => true,
        acquire: () async {
          acquireCalls++;
          return false;
        },
      );

      expect(decision, SingleInstanceDecision.surfacedExisting);
      expect(
        acquireCalls,
        kSingleInstanceAcquireAttempts,
        reason: 'bounded: the whole budget, then the probe decides',
      );
    });

    test('nothing answering + lock taken ⇒ refuses to start', () async {
      final decision = await resolve(
        probe: () async => false,
        acquire: () async => false,
      );

      expect(
        decision,
        SingleInstanceDecision.blocked,
        reason: 'fail closed: never start a second full instance unlocked',
      );
    });

    test('a lock that frees up mid-hand-off still starts', () async {
      // The restart case. The outgoing process holds the lock while it runs its
      // teardown, then releases it; the successor must wait briefly, not fail.
      var acquireCalls = 0;

      final decision = await resolve(
        probe: () async => false,
        acquire: () async {
          acquireCalls++;
          return acquireCalls > 3;
        },
      );

      expect(decision, SingleInstanceDecision.start);
      expect(acquireCalls, 4);
    });

    test(
      'a throwing probe counts as "not running", then the lock decides',
      () async {
        final blocked = await resolve(
          probe: () async => throw StateError('no channel'),
          acquire: () async => false,
        );
        expect(blocked, SingleInstanceDecision.blocked);

        final started = await resolve(
          probe: () async => throw StateError('no channel'),
          acquire: () async => true,
        );
        expect(started, SingleInstanceDecision.start);
      },
    );
  });

  /// N5 — a second launch must actually wake the first instance.
  ///
  /// Gate B retry: the second process exited with code 1 (`blocked`) while an
  /// instance was plainly running. `_probeRunningInstance()` probed once, and
  /// `sendCommand` collapsed "no channel" and "channel did not answer" into one
  /// failure. `--exit` never had the problem because `_sendControlCommand`
  /// retries 5 × 200 ms.
  ///
  /// The distinction that matters: a probe that **returns false** has a
  /// definitive answer ("nothing is running" — retrying only adds latency),
  /// while a probe that **throws** only says "could not tell".
  group('probe retry (N5)', () {
    Future<SingleInstanceDecision> resolve({
      required Future<bool> Function() probe,
      required Future<bool> Function() acquire,
    }) {
      return resolveSingleInstance(
        probe: probe,
        acquire: acquire,
        acquireDelay: Duration.zero,
        probeDelay: Duration.zero,
      );
    }

    test('a transient probe failure is retried until it answers', () async {
      var calls = 0;

      final decision = await resolve(
        probe: () async {
          calls++;
          if (calls < 2) {
            throw const ExternalControlException(
              ExternalControlFailure.unreachable,
            );
          }
          return true;
        },
        acquire: () async => false,
      );

      expect(
        decision,
        SingleInstanceDecision.surfacedExisting,
        reason: 'one refused connect is not evidence that nothing is running',
      );
      expect(calls, 2);
    });

    test('a definitive "nothing running" answer is not retried', () async {
      var calls = 0;

      final decision = await resolve(
        probe: () async {
          calls++;
          return false;
        },
        acquire: () async => false,
      );

      expect(decision, SingleInstanceDecision.blocked);
      expect(calls, 1, reason: 'a definitive answer must not be re-asked');
    });

    test('a free lock never reaches the probe at all', () async {
      var calls = 0;

      final decision = await resolve(
        probe: () async {
          calls++;
          return false;
        },
        acquire: () async => true,
      );

      expect(decision, SingleInstanceDecision.start);
      expect(calls, 0, reason: 'the lock answers this before a socket is opened');
    });

    test('retries are bounded and end fail-closed', () async {
      var calls = 0;

      final decision = await resolve(
        probe: () async {
          calls++;
          throw const ExternalControlException(
            ExternalControlFailure.unreachable,
          );
        },
        acquire: () async => false,
      );

      expect(decision, SingleInstanceDecision.blocked);
      expect(calls, 3, reason: 'bounded, never an unbounded wait');
    });

    test('a peer that answers and refuses still counts as running', () async {
      var calls = 0;

      final decision = await resolve(
        probe: () async {
          calls++;
          // `_probeRunningInstance` turns a refusal into `true`, because an
          // instance *is* there; the resolver never sees this failure.
          throw const ExternalControlException(
            ExternalControlFailure.rejected,
            'error window-unavailable',
          );
        },
        acquire: () async => false,
      );

      // Pins the resolver's contract: an unresolvable probe plus a held lock is
      // fail-closed, never a silent second instance.
      expect(decision, SingleInstanceDecision.blocked);
      expect(calls, 3);
    });
  });

  group('the OS primitive the guard relies on', () {
    test('a second exclusive lock on the same file is refused', () async {
      // `SingleInstanceLock` is only worth anything if the platform actually
      // rejects the second lock. This pins that, on this OS, with two real
      // handles — no subprocess needed.
      final dir = await Directory.systemTemp.createTemp('fluxora_lock_probe');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}probe.lock';

      final first = await File(path).open(mode: FileMode.write);
      addTearDown(first.close);
      await first.lock();

      final second = await File(path).open(mode: FileMode.write);
      addTearDown(second.close);

      // Windows-only expectation: `FileLock` is a mandatory range lock there, so
      // a second handle in the *same* process is refused. On POSIX it is an
      // advisory lock that the same process may re-take, so the guard is
      // enforced across processes rather than within one. The product behaviour
      // that matters — one instance per identity — is covered by the lock-path
      // tests below and by the real cross-process test.
      await expectLater(second.lock(), throwsA(isA<FileSystemException>()));
    }, skip: !Platform.isWindows);
  });

  group('lock path per identity', () {
    test('release and dev share one lock (they share one profile)', () {
      // `lockFilePath` is `<dataDir>/<dataDirName>.lock`, and both identities
      // use the same data directory — so they must not run at the same time,
      // otherwise two processes write the same config file.
      expect(
        specFor(HelperIdentityKind.dev).dataDirName,
        specFor(HelperIdentityKind.release).dataDirName,
      );
    });

    test('host test keeps its own lock', () {
      expect(
        specFor(HelperIdentityKind.hostTest).dataDirName,
        isNot(specFor(HelperIdentityKind.release).dataDirName),
      );
    });
  });
}
