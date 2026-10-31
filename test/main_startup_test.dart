import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/main.dart';

/// R7-15.3-B — the startup chain must never die before `runApp()`.
///
/// `main()` used to `await Future.wait([initApp, preload])` with no `catch`.
/// When `preload()` failed (a core that could not bind its socket), the throw
/// skipped `runApp()` entirely, so the window stayed blank with only a log line.
///
/// The fix is [runStartupTasks]: it returns the error instead of rethrowing, so
/// the statement after it — `_runApp(startupError: …)` — always runs. These
/// tests pin exactly that contract; the UI surfacing (a post-frame
/// `showNotifier`) is covered by review, since showing it needs a running app.
void main() {
  test('returns null when both startup tasks succeed', () async {
    var initAppRan = false;
    var preloadRan = false;

    final error = await runStartupTasks(
      initApp: () async => initAppRan = true,
      preload: () async {
        preloadRan = true;
        return true;
      },
    );

    expect(error, isNull);
    expect(initAppRan, isTrue, reason: 'both tasks must actually start');
    expect(preloadRan, isTrue);
  });

  test('returns the preload error instead of throwing', () async {
    final failure = const SocketException('bind blocked');

    final error = await runStartupTasks(
      initApp: () async {},
      preload: () async => throw failure,
    );

    expect(
      error,
      same(failure),
      reason: 'the original exception must reach the caller untouched',
    );
  });

  test('returns the initApp error instead of throwing', () async {
    final failure = StateError('preferences unavailable');

    final error = await runStartupTasks(
      initApp: () async => throw failure,
      preload: () async => true,
    );

    expect(error, same(failure));
  });

  test('a synchronous throw inside a task is captured too', () async {
    // `initApp()` is invoked inside the `try`, so even a throw raised before the
    // future is created must not escape.
    final failure = ArgumentError('boom');

    final error = await runStartupTasks(
      initApp: () => throw failure,
      preload: () async => true,
    );

    expect(error, same(failure));
  });

  test('waits for both tasks before returning', () async {
    final completed = <String>[];

    await runStartupTasks(
      initApp: () async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        completed.add('initApp');
      },
      preload: () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        completed.add('preload');
        return true;
      },
    );

    expect(
      completed,
      containsAll(<String>['initApp', 'preload']),
      reason: 'the caller must not proceed while a task is still running',
    );
  });

  test('a later failure still surfaces after the other task finished', () async {
    final completed = <String>[];
    final failure = const SocketException('late bind failure');

    final error = await runStartupTasks(
      initApp: () async => completed.add('initApp'),
      preload: () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        throw failure;
      },
    );

    expect(error, same(failure));
    expect(completed, contains('initApp'));
  });
}
