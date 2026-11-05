import 'dart:io';

import 'package:fluxora/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

/// P9B-D1 / P9B-D3 — the shared exit / restart chain.
///
/// Nothing here starts a GUI, a core, a helper or touches the system proxy:
/// every step is a closure supplied by the test.
void main() {
  late List<String> log;

  setUp(() => log = <String>[]);

  TeardownStep step(String name, {bool throws = false}) =>
      TeardownStep(name, () async {
        log.add(name);
        if (throws) throw StateError('$name exploded');
      });

  group('runTeardown', () {
    test('runs every step in order', () async {
      final result = await runTeardown([step('a'), step('b'), step('c')]);

      expect(log, ['a', 'b', 'c']);
      expect(result.clean, isTrue);
      expect(result.failures, isEmpty);
    });

    test('a throwing step does not stop the ones after it', () async {
      final result = await runTeardown([
        step('save-preferences', throws: true),
        step('proxy-release'),
        step('helper-stop'),
      ]);

      expect(log, [
        'save-preferences',
        'proxy-release',
        'helper-stop',
      ], reason: 'P9B-D1: a throwing save must not skip the proxy release');
      expect(result.clean, isFalse);
      expect(result.failures, hasLength(1));
      expect(result.failures.single, contains('save-preferences'));
    });

    test('several failures are all collected, none swallowed', () async {
      final result = await runTeardown([
        step('a', throws: true),
        step('b'),
        step('c', throws: true),
      ]);

      expect(log, ['a', 'b', 'c']);
      expect(result.failures, hasLength(2));
      expect(result.failures[0], contains('a'));
      expect(result.failures[1], contains('c'));
    });

    test('an empty chain is clean', () async {
      final result = await runTeardown([]);
      expect(result.clean, isTrue);
    });
  });

  group('LifecycleTeardown — exit', () {
    test('runs the chain, then the exit tail', () async {
      final teardown = LifecycleTeardown(
        steps: () => [step('a'), step('b')],
        onExit: () async => log.add('exit'),
        onRestart: () async => log.add('restart'),
      );

      final result = await teardown.run(restart: false);

      expect(log, ['a', 'b', 'exit']);
      expect(result.clean, isTrue);
    });

    test('still exits when a step failed', () async {
      final teardown = LifecycleTeardown(
        steps: () => [step('a', throws: true), step('b')],
        onExit: () async => log.add('exit'),
        onRestart: () async => log.add('restart'),
      );

      final result = await teardown.run(restart: false);

      expect(log, ['a', 'b', 'exit'], reason: 'a stuck process is worse');
      expect(result.clean, isFalse);
    });
  });

  group('LifecycleTeardown — restart', () {
    test('restart uses the same chain and runs after it', () async {
      final teardown = LifecycleTeardown(
        steps: () => [step('proxy-release'), step('helper-stop')],
        onExit: () async => log.add('exit'),
        onRestart: () async => log.add('restart'),
      );

      final result = await teardown.run(restart: true);

      expect(log, [
        'proxy-release',
        'helper-stop',
        'restart',
      ], reason: 'P9B-D3: cleanup must finish before the process is replaced');
      expect(log, isNot(contains('exit')));
      expect(result.clean, isTrue);
    });

    test(
      'a keepOnRestart step is skipped on restart and still runs on exit',
      () async {
        // N6 — the successor must inherit the helper service. A normal exit
        // still runs the step, so "kept" never means "never stopped".
        TeardownStep helperStop() => TeardownStep('helper-stop', () async {
          log.add('helper-stop');
        }, keepOnRestart: true);

        final restarting = LifecycleTeardown(
          steps: () => [helperStop()],
          onExit: () async => log.add('exit'),
          onRestart: () async => log.add('restart'),
        );
        await restarting.run(restart: true);
        expect(log, ['restart']);

        log.clear();
        final exiting = LifecycleTeardown(
          steps: () => [helperStop()],
          onExit: () async => log.add('exit'),
          onRestart: () async => log.add('restart'),
        );
        await exiting.run(restart: false);
        expect(log, ['helper-stop', 'exit']);
      },
    );

    test(
      'a failed cleanup is reported, not hidden as a clean restart',
      () async {
        final teardown = LifecycleTeardown(
          steps: () => [step('core-shutdown', throws: true)],
          onExit: () async => log.add('exit'),
          onRestart: () async => log.add('restart'),
        );

        final result = await teardown.run(restart: true);

        expect(log, ['core-shutdown', 'restart']);
        expect(result.clean, isFalse);
        expect(result.failures.single, contains('core-shutdown'));
      },
    );
  });

  group('LifecycleTeardown — single run', () {
    test(
      'a second call reuses the first run instead of tearing down twice',
      () async {
        var exits = 0;
        final teardown = LifecycleTeardown(
          steps: () => [step('a')],
          onExit: () async {
            exits++;
            log.add('exit');
          },
          onRestart: () async => log.add('restart'),
        );

        final first = teardown.run(restart: false);
        final second = teardown.run(restart: false);

        expect(identical(first, second), isTrue);
        await Future.wait([first, second]);
        await teardown.run(restart: false); // completed run, still no re-entry

        expect(log, ['a', 'exit']);
        expect(exits, 1, reason: 'no double exit, no second teardown');
      },
    );
  });

  group('the real chain keeps the B2 / B3 ownership gates', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('fluxora_teardown_gate');
      ProxyOwnership.settle = Duration.zero;
      ProxyOwnership.statePathForTest =
          '${tmp.path}${Platform.pathSeparator}proxy_ownership.json';
      ProxyOwnership.readForTest = () => null;
      Windows.resetHelperSessionForTest();
    });

    tearDown(() async {
      ProxyOwnership.stopForTest = null;
      ProxyOwnership.startForTest = null;
      ProxyOwnership.readForTest = null;
      ProxyOwnership.statePathForTest = null;
      ProxyOwnership.settle = const Duration(milliseconds: 400);
      Windows.helperStopIpcOverrideForTest = null;
      Windows.resetHelperSessionForTest();
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test(
      'nothing owned ⇒ zero proxy writes and zero helper IPC',
      () async {
        var proxyStops = 0;
        var ipcCalls = 0;
        ProxyOwnership.stopForTest = () async {
          proxyStops++;
          return true;
        };
        Windows.helperStopIpcOverrideForTest = () async {
          ipcCalls++;
          return true;
        };

        // The exact two calls the real exit chain makes, through the same runner.
        final result = await runTeardown([
          TeardownStep(
            'proxy-release',
            () => ProxyOwnership.release(reason: 'exit'),
          ),
          TeardownStep('helper-stop', () => Windows().stopHelperService()),
        ]);

        expect(result.clean, isTrue);
        expect(proxyStops, 0, reason: 'B3: an unowned proxy is never touched');
        expect(ipcCalls, 0, reason: 'B2: an unowned helper is never stopped');
      },
      skip: !Platform.isWindows,
    ); // helper-stop constructs `Windows()` → shell32.dll
  });
}
