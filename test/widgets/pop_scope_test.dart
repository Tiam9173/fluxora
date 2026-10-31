import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/pop_scope.dart';

import '../support/recording_app_controller.dart';

/// `SystemBackBlock` — mount / unmount pairing.
///
/// The widget exists to tell the shell "a system back press is currently
/// handled by a sub-screen", so search and edit mode can swallow it. It does
/// that by toggling `backBlockProvider` once on mount and once on unmount, each
/// from a post-frame callback.
///
/// ## On the "dispose reads a stale ref" concern
///
/// It is **not** a production defect. `SystemBackBlock` is a plain `State`; it
/// holds no `WidgetRef` of its own. It calls `globalState.appController`, and
/// that controller is bound in `ApplicationState.initState`
/// (`lib/application.dart:103`) — `Application` is the widget handed to
/// `runApp`, so its `ref` lives as long as the process does. The riverpod
/// assertion only appears when a *test* binds the controller to a short-lived
/// `Consumer`, which is a harness artifact.
///
/// These tests therefore drive a [RecordingAppController]: they pin the
/// lifecycle contract (one block per mount, one unblock per unmount, none on
/// rebuild) without depending on a ref that outlives the tree.
void main() {
  late RecordingAppController controller;
  var bound = false;

  setUp(() => bound = false);

  Future<void> pumpBlock(
    WidgetTester tester, {
    Widget child = const Text('inner'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (ctx, ref, _) {
              // Bind once per test: the Consumer rebuilds on every pump, and
              // reassigning here would hand each assertion a fresh recorder with
              // an empty call list.
              if (!bound) {
                bound = true;
                controller = RecordingAppController(ctx, ref);
                globalState.appController = controller;
              }
              return SystemBackBlock(child: child);
            },
          ),
        ),
      ),
    );
    // Run the post-frame callback scheduled by initState.
    await tester.pump();
  }

  group('SystemBackBlock lifecycle', () {
    testWidgets('mounting registers the block exactly once', (tester) async {
      await pumpBlock(tester);

      expect(controller.calls, ['block']);
    });

    testWidgets('unmounting registers the unblock exactly once', (
      tester,
    ) async {
      await pumpBlock(tester);
      controller.calls.clear();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(controller.calls, ['unblock']);
    });

    testWidgets('a rebuild does not register a second block', (tester) async {
      // `didUpdateWidget` is not overridden, so a rebuild must not re-run the
      // initState callback — otherwise the provider would be toggled on every
      // frame the parent rebuilds.
      await pumpBlock(tester);
      expect(controller.calls, ['block']);

      await pumpBlock(tester, child: const Text('inner-v2'));
      await tester.pump();

      expect(controller.calls, ['block']);
      expect(find.text('inner-v2'), findsOneWidget);
    });

    testWidgets('remounting pairs block with unblock', (tester) async {
      await pumpBlock(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpBlock(tester);

      expect(controller.calls, ['block', 'unblock', 'block']);
    });

    testWidgets('the child is rendered untouched', (tester) async {
      await pumpBlock(tester, child: const Text('inner'));

      // It is a pure pass-through: no wrapper, no extra layout.
      expect(find.text('inner'), findsOneWidget);
      expect(find.byType(SystemBackBlock), findsOneWidget);
    });
  });

  group('CommonPopScope', () {
    testWidgets('without onPop and off TV the route may pop freely', (
      tester,
    ) async {
      // `canPop: !intercept` — with no callback and no TV, back is not swallowed.
      await tester.pumpWidget(
        const MaterialApp(
          home: CommonPopScope(child: Text('inner')),
        ),
      );

      final popScope = tester.widget(
        find.byWidgetPredicate((w) => w is PopScope),
      ) as dynamic;
      expect(popScope.canPop, isTrue);
    });

    testWidgets('with onPop the route is intercepted', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommonPopScope(onPop: () async => false, child: const Text('in')),
        ),
      );

      final popScope = tester.widget(
        find.byWidgetPredicate((w) => w is PopScope),
      ) as dynamic;
      expect(popScope.canPop, isFalse);
    });
  });
}
