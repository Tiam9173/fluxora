import 'package:fluxora/common/lifecycle_teardown.dart';
import 'package:flutter_test/flutter_test.dart';

/// N6 — a restart must not stop the helper service.
///
/// Gate B retry showed the real failure: `--restart` ran the full exit chain,
/// the `helper-stop` step stopped `FluxoraHostTestHelperService`, and the new
/// process could not start it again (a standard user's `sc start` is refused
/// with error 5). The restarted instance therefore fell back to spawning the
/// core itself — `FluxoraCore.exe`'s parent was `Fluxora.exe`, not the helper.
///
/// The fix is *not* "delete every service stop". Normal exit keeps stopping the
/// helper it owns; only the restart hand-off keeps it alive so the successor
/// can reuse it. The ownership gate in `stopHelperService` is untouched.
void main() {
  List<String> makeLog() => <String>[];

  group('restart keeps the helper service alive', () {
    test('a restarting teardown skips the step marked keepOnRestart', () async {
      final log = makeLog();
      final teardown = LifecycleTeardown(
        steps: () => [
          TeardownStep('proxy', () async => log.add('proxy')),
          TeardownStep(
            'helper-stop',
            () async => log.add('helper-stop'),
            keepOnRestart: true,
          ),
          TeardownStep('core-shutdown', () async => log.add('core')),
        ],
        onExit: () async => log.add('exit'),
        onRestart: () async => log.add('restart'),
      );

      final result = await teardown.run(restart: true);

      expect(
        log,
        ['proxy', 'core', 'restart'],
        reason: 'the helper must outlive the restart so the successor reuses it',
      );
      expect(result.clean, isTrue);
    });

    test('a normal exit still stops the helper', () async {
      final log = makeLog();
      final teardown = LifecycleTeardown(
        steps: () => [
          TeardownStep('proxy', () async => log.add('proxy')),
          TeardownStep(
            'helper-stop',
            () async => log.add('helper-stop'),
            keepOnRestart: true,
          ),
        ],
        onExit: () async => log.add('exit'),
        onRestart: () async => log.add('restart'),
      );

      await teardown.run(restart: false);

      expect(
        log,
        ['proxy', 'helper-stop', 'exit'],
        reason: 'a plain exit owns its helper and must still stop it',
      );
    });

    test('a skipped step never runs its body, so a failing stop cannot hide',
        () async {
      final log = makeLog();
      var ran = 0;
      final teardown = LifecycleTeardown(
        steps: () => [
          TeardownStep(
            'helper-stop',
            () async {
              ran++;
              throw StateError('must not be called on restart');
            },
            keepOnRestart: true,
          ),
        ],
        onExit: () async => log.add('exit'),
        onRestart: () async => log.add('restart'),
      );

      final result = await teardown.run(restart: true);

      expect(ran, 0);
      expect(result.clean, isTrue, reason: 'no failure to report for a skipped step');
      expect(log, ['restart']);
    });
  });
}
