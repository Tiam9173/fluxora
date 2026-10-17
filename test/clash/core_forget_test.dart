import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/core.dart';
import 'package:fluxora/clash/interface.dart';

/// item 6 ⑤ — the "core not ready" guard, ported from upstream v1.19.4
/// "Improve core stability" (23653235). The wrappers themselves are pure
/// Dart, so they are asserted directly: a rejected core call must reach the
/// log and never surface as an uncaught async error — that is the whole
/// point of the fix.
void main() {
  final logs = <String>[];
  DebugPrintCallback? originalDebugPrint;

  setUp(() {
    logs.clear();
    originalDebugPrint ??= debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
  });

  tearDown(() {
    debugPrint = originalDebugPrint ?? debugPrintThrottled;
  });

  /// Runs [body] inside a guarding zone and reports any error that escaped.
  Future<Object?> captureUncaught(Future<void> Function() body) async {
    Object? uncaught;
    await runZonedGuarded(body, (error, stack) => uncaught = error);
    return uncaught;
  }

  for (final description in ['clashCoreForget', 'clashInvokeAndForget']) {
    group(description, () {
      test('a rejected future is logged, not thrown', () async {
        final uncaught = await captureUncaught(() async {
          if (description == 'clashCoreForget') {
            clashCoreForget(
              Future.error(StateError('core not ready')),
              'clearLogs',
            );
          } else {
            clashInvokeAndForget(
              Future.error(StateError('core not ready')),
              'resetTraffic',
            );
          }
          await Future.delayed(const Duration(milliseconds: 10));
        });

        expect(uncaught, isNull);
        expect(logs, hasLength(1));
        expect(logs.single, contains('ignored:'));
        expect(logs.single, contains('core not ready'));
      });

      test('the operation name is in the log line', () async {
        await captureUncaught(() async {
          clashCoreForget(Future.error('boom'), 'closeConnection');
          await Future.delayed(const Duration(milliseconds: 10));
        });

        expect(logs.single, startsWith('[APP] closeConnection ignored:'));
      });

      test('a successful call logs nothing', () async {
        final uncaught = await captureUncaught(() async {
          clashCoreForget(Future.value(true), 'startLog');
          await Future.delayed(const Duration(milliseconds: 10));
        });

        expect(uncaught, isNull);
        expect(logs, isEmpty);
      });

      test('a synchronous value passes through silently', () async {
        final uncaught = await captureUncaught(() async {
          clashInvokeAndForget(null, 'stopLog');
          await Future.delayed(const Duration(milliseconds: 10));
        });

        expect(uncaught, isNull);
        expect(logs, isEmpty);
      });

      test('several failures in a row are each logged, none escape', () async {
        final uncaught = await captureUncaught(() async {
          for (final name in ['closeConnection', 'resetConnections']) {
            clashCoreForget(Future.error('nope'), name);
          }
          await Future.delayed(const Duration(milliseconds: 10));
        });

        expect(uncaught, isNull);
        expect(logs, hasLength(2));
      });
    });
  }
}
