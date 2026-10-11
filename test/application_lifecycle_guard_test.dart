import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/application.dart';
import 'package:fluxora/controller.dart';

/// P2.6-D — `application.dart` lifecycle / async error handling.
///
/// Covers the four audited defects:
///
/// 1. `unawaited(autoUpdateProfiles())` — a fire-and-forget task whose failure
///    had no boundary to land in (`application.dart`, timer callback).
/// 2. loop-head `_ref.read(...)` outside a `try` (`controller.dart` × 3).
/// 3. duplicate `AppController` construction (`application.dart`).
///
/// The behavioural tests drive the real production functions. The structural
/// tests encode the invariants that a behavioural test cannot observe (a second
/// `AppController` construction, or a loop head that is not inside a boundary),
/// which is exactly how this class of defect hides.

const Key _outerKey = Key('p26d-outer');
const Key _innerKey = Key('p26d-inner');

void main() {
  // ── 1. fire-and-forget boundary (application.dart) ────────────────────────

  group('runDetachedTask — fire-and-forget boundary', () {
    test(
      'A. a throwing task is contained (not an unhandled async error) and stays diagnosable',
      () async {
        final errors = <Object>[];
        final stacks = <StackTrace>[];

        // If the boundary failed, this `await` would rethrow and fail the test.
        await runDetachedTask(
          () async {
            throw StateError('auto update boom');
          },
          label: 'profile auto-update',
          onError: (error, stackTrace) {
            errors.add(error);
            stacks.add(stackTrace);
          },
        );

        expect(errors, hasLength(1), reason: 'the error must not be swallowed');
        expect('${errors.single}', contains('auto update boom'));
        expect(stacks, hasLength(1));
      },
    );

    test(
      'A2. the timer call style never surfaces an unhandled async error',
      () async {
        // Mirrors application.dart's timer callback: the future is discarded on
        // purpose. An escaping error would be reported to the test zone as an
        // uncaught async error and fail this test.
        final errors = <Object>[];
        unawaited(
          runDetachedTask(
            () async {
              throw StateError('detached boom');
            },
            label: 'profile auto-update',
            onError: (error, stackTrace) => errors.add(error),
          ),
        );

        await Future<void>.delayed(Duration.zero);

        expect(errors, hasLength(1));
        expect('${errors.single}', contains('detached boom'));
      },
    );

    test(
      'E. a succeeding task completes normally and reports nothing',
      () async {
        var ran = false;
        final errors = <Object>[];

        await runDetachedTask(
          () async {
            ran = true;
          },
          label: 'profile auto-update',
          onError: (error, stackTrace) => errors.add(error),
        );

        expect(ran, isTrue, reason: 'the normal path must still run the task');
        expect(errors, isEmpty);
      },
    );
  });

  // ── 3. single AppController per application lifecycle ────────────────────

  group('AppController lifecycle', () {
    testWidgets(
      'D. rebindContext re-targets the SAME instance instead of building a second one',
      (tester) async {
        late WidgetRef capturedRef;
        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, child) {
                capturedRef = ref;
                return const Padding(
                  key: _outerKey,
                  padding: EdgeInsets.zero,
                  child: SizedBox.shrink(key: _innerKey),
                );
              },
            ),
          ),
        );

        final BuildContext outer = tester.element(find.byKey(_outerKey));
        final BuildContext inner = tester.element(find.byKey(_innerKey));

        final AppController controller = AppController(outer, capturedRef);
        controller.rebindContext(inner);

        expect(
          identical(controller.context, inner),
          isTrue,
          reason: 'the single controller must adopt the navigator context',
        );
        expect(identical(controller.context, outer), isFalse);
      },
    );

    test('D2. application.dart constructs exactly one AppController', () {
      final String app = File('lib/application.dart').readAsStringSync();

      expect(
        'AppController('.allMatches(app).length,
        1,
        reason: 'the application lifecycle must own exactly one controller',
      );
      expect(
        app.contains('rebindContext('),
        isTrue,
        reason: '_initApp must rebind, not rebuild',
      );
    });
  });

  // ── 1 + 2. structural invariants ─────────────────────────────────────────

  group('structural guards', () {
    test(
      'B. the profile timer routes through the boundary, not a bare unawaited',
      () {
        final String app = File('lib/application.dart').readAsStringSync();

        expect(
          app.contains(
            'unawaited(globalState.appController.autoUpdateProfiles())',
          ),
          isFalse,
          reason: 'the bare fire-and-forget call has no error boundary',
        );
        expect(
          app.contains('runDetachedTask('),
          isTrue,
          reason: 'the timer must use the shared boundary',
        );
      },
    );

    test(
      'C. every loop-head `_ref.read(profilesProvider)` sits inside a try',
      () {
        final List<String> lines = File(
          'lib/controller.dart',
        ).readAsLinesSync();
        final List<int> hits = <int>[];
        // Match the actual loop head, not a comment that merely mentions it.
        const String loopHead =
            'for (final profile in _ref.read(profilesProvider))';

        for (int i = 0; i < lines.length; i++) {
          if (!lines[i].contains(loopHead)) continue;
          hits.add(i + 1);
          final String previous = i == 0 ? '' : lines[i - 1].trim();
          expect(
            previous,
            'try {',
            reason:
                'loop-head read at controller.dart:${i + 1} escapes the error boundary',
          );
        }

        expect(
          hits,
          hasLength(3),
          reason: 'all three profile-update loops must still be present',
        );
      },
    );
  });
}
