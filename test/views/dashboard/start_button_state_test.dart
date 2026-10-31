import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/dashboard/widgets/start_button.dart';
import 'package:fluxora/widgets/fluxora/fluxora.dart';

/// The connection control's operation contract.
///
/// `StartButton` is the only place a user starts or stops the connection, so its
/// three operational states have to be legible without a live core:
///
/// | state | contract |
/// | --- | --- |
/// | idle | the card is tappable |
/// | in flight | the card is **not** tappable — a second tap cannot start a second `updateStatus` |
/// | failed | the failure reaches the user (snackbar), not just the log |
///
/// `updateStatus` is driven through a real `AppController` subclass so the test
/// controls exactly when the future completes. The four providers are pinned the
/// way `hero_entrance_test.dart` pins them; nothing here fakes a connection.
class _ControllableController extends AppController {
  _ControllableController(super.context, super.ref);

  int updateStatusCalls = 0;
  int restartCoreCalls = 0;
  Completer<void>? pending;
  Object? failure;

  @override
  Future<void> updateStatus(bool isStart) {
    updateStatusCalls++;
    if (failure != null) return Future<void>.error(failure!);
    final completer = Completer<void>();
    pending = completer;
    return completer.future;
  }

  @override
  Future<void> restartCore() {
    restartCoreCalls++;
    if (failure != null) return Future<void>.error(failure!);
    return Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  setUp(() {
    globalState.appState = AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
  });

  /// Pumps the real hero and returns the controller it talks to.
  Future<_ControllableController> pumpHero(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late _ControllableController controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startButtonSelectorStateProvider.overrideWith(
            (ref) => const StartButtonSelectorState(
              isInit: true,
              hasProfile: true,
            ),
          ),
          isRestartingCoreProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF29D6C7),
              brightness: brightness,
            ),
          ),
          home: Consumer(
            builder: (ctx, ref, _) {
              globalState.theme = CommonTheme.of(ctx, textScale);
              globalState.measure = Measure.of(ctx, textScale);
              controller = _ControllableController(ctx, ref);
              globalState.appController = controller;
              return MediaQuery(
                data: MediaQuery.of(
                  ctx,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(width: 320, child: StartButton()),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  group('the control is not re-entrant while a toggle is in flight', () {
    testWidgets('a second tap cannot start a second updateStatus', (
      tester,
    ) async {
      final controller = await pumpHero(tester);

      await tester.tap(find.byType(FluxoraCard));
      await tester.pump();
      expect(controller.updateStatusCalls, 1);

      // Still in flight: the card must have dropped its tap target.
      expect(
        tester.widget<FluxoraCard>(find.byType(FluxoraCard)).onTap,
        isNull,
        reason: 'a busy control must not look — or behave — pressable',
      );

      await tester.tap(find.byType(FluxoraCard), warnIfMissed: false);
      await tester.pump();
      expect(
        controller.updateStatusCalls,
        1,
        reason: 'the second tap must not reach updateStatus',
      );

      controller.pending!.complete();
      await tester.pumpAndSettle();

      expect(
        tester.widget<FluxoraCard>(find.byType(FluxoraCard)).onTap,
        isNotNull,
        reason: 'the control comes back once the operation finishes',
      );
    });
  });

  group('failures reach the user', () {
    testWidgets('a failed toggle surfaces a snackbar', (tester) async {
      final controller = await pumpHero(tester);
      controller.failure = Exception('core refused to start');

      await tester.tap(find.byType(FluxoraCard));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('core refused to start'),
        findsOneWidget,
        reason:
            'the primary action used to fail silently — the card just snapped '
            'back with no explanation',
      );
    });

    testWidgets('a successful toggle shows no error', (tester) async {
      final controller = await pumpHero(tester);

      await tester.tap(find.byType(FluxoraCard));
      await tester.pump();
      controller.pending!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('layout holds at the edges', () {
    testWidgets('narrow window at 2.0x renders without overflow', (
      tester,
    ) async {
      await pumpHero(
        tester,
        size: const Size(320, 640),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FluxoraCard), findsOneWidget);
      // The status row and the read-out are still present, not clipped away.
      expect(find.byType(FluxoraStatus), findsOneWidget);
    });

    testWidgets('light theme keeps the same structure', (tester) async {
      await pumpHero(tester, brightness: Brightness.light);

      expect(tester.takeException(), isNull);
      expect(find.byType(FluxoraStatus), findsOneWidget);
    });
  });
}
