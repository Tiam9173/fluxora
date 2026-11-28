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
import '../../support/render_capture.dart';

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
  _ControllableController(BuildContext context, this.bindingRef)
    : super(context, bindingRef);
  final WidgetRef bindingRef;

  int updateStatusCalls = 0;
  int restartCoreCalls = 0;
  int refreshConnectionCheckCalls = 0;
  bool? lastConnectionCheckWasImmediate;
  int connectionRetries = 0;
  bool delegateHealthCheck = false;
  Completer<void>? pending;
  Object? failure;

  @override
  void refreshConnectionCheck({bool immediate = false}) {
    connectionRetries++;
    refreshConnectionCheckCalls++;
    lastConnectionCheckWasImmediate = immediate;
    bindingRef.read(connectionCheckProvider.notifier).state =
        ConnectionCheck.checking;
    if (delegateHealthCheck) {
      super.refreshConnectionCheck(immediate: immediate);
    }
  }

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
    await (FontLoader('HarmonyOS_Sans')..addFont(
          rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  setUp(() {
    globalState.config = globalState.config.copyWith(
      networkProps: const NetworkProps(systemProxy: true),
    );
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

  tearDown(() => System.platformOverride = null);

  /// Pumps the real hero and returns the controller it talks to.
  Future<_ControllableController> pumpHero(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
    Size size = const Size(400, 800),
    bool systemProxy = true,
  }) async {
    globalState.config = globalState.config.copyWith(
      networkProps: NetworkProps(systemProxy: systemProxy),
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    _ControllableController? controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startButtonSelectorStateProvider.overrideWith(
            (ref) =>
                const StartButtonSelectorState(isInit: true, hasProfile: true),
          ),
          isRestartingCoreProvider.overrideWith((ref) => false),
          systemProxyAppliedProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'HarmonyOS_Sans',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF29D6C7),
              brightness: brightness,
            ),
          ),
          home: Consumer(
            builder: (ctx, ref, _) {
              globalState.theme = CommonTheme.of(ctx, textScale);
              globalState.measure = Measure.of(ctx, textScale);
              controller ??= _ControllableController(ctx, ref);
              globalState.appController = controller!;
              return MediaQuery(
                data: MediaQuery.of(
                  ctx,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: Scaffold(
                  body: Center(
                    child: RepaintBoundary(
                      key: const ValueKey('start-capture'),
                      child: SizedBox(
                        width: size.width < 600 ? 320 : 520,
                        child: StartButton(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return controller!;
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

  testWidgets(
    'pending start and stop never claim success before runtime evidence',
    (tester) async {
      final controller = await pumpHero(tester);
      await tester.tap(find.byType(FluxoraCard));
      await tester.pump();
      expect(find.text(appLocalizations.startVpn), findsOneWidget);
      expect(find.text(appLocalizations.serviceRunning), findsNothing);
      controller.pending!.complete();
      await tester.pumpAndSettle();
      // Completing an operation alone does not prove the core is connected.
      expect(find.text(appLocalizations.serviceRunning), findsNothing);
      controller.bindingRef.read(runTimeProvider.notifier).value = 156000;
      await tester.pumpAndSettle();
      expect(find.text(appLocalizations.serviceRunning), findsOneWidget);
      expect(find.text(appLocalizations.healthHealthy), findsNothing);
      await tester.tap(find.byType(FluxoraCard));
      await tester.pump();
      expect(find.text(appLocalizations.stopVpn), findsOneWidget);
      expect(find.text(appLocalizations.serviceReady), findsNothing);
      controller.bindingRef.read(runTimeProvider.notifier).value = null;
      controller.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text(appLocalizations.serviceReady), findsOneWidget);
    },
  );

  Future<void> capture(WidgetTester tester, String name) async {
    const path = String.fromEnvironment('START_BUTTON_CAPTURE_DIR');
    if (path.isEmpty) return;
    await captureFlutterFrame(
      tester,
      find.byKey(const ValueKey('start-capture')),
      '$path/$name.png',
    );
  }

  testWidgets('a failed check offers a manual retry without restarting', (
    tester,
  ) async {
    final controller = await pumpHero(tester);
    final ref = controller.bindingRef;
    ref.read(runTimeProvider.notifier).value = 156000;
    ref.read(connectionCheckProvider.notifier).state = ConnectionCheck.limited;
    await tester.pump();
    expect(find.text(appLocalizations.checkError), findsOneWidget);
    expect(find.text(appLocalizations.retry), findsOneWidget);
    await tester.pumpAndSettle();
    await capture(tester, 'check-failed');
    await tester.tap(find.text(appLocalizations.retry));
    await tester.pump();
    expect(controller.refreshConnectionCheckCalls, 1);
    expect(controller.lastConnectionCheckWasImmediate, isTrue);
    expect(controller.restartCoreCalls, 0);
    expect(find.text(appLocalizations.checking), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 120));
    await capture(tester, 'check-retry');
  });

  testWidgets('a failed connection check recovers on its own', (tester) async {
    final controller = await pumpHero(tester);
    final ref = controller.bindingRef;
    var probes = 0;
    controller.connectionProbeForTest = () async => ++probes == 2;
    controller.delegateHealthCheck = true;
    ref.read(runTimeProvider.notifier).value = 156000;
    expect(controller.canCheckConnectionForTest, isTrue);
    controller.refreshConnectionCheck(immediate: true);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.connectionCheckAttemptsForTest, 1);
    expect(probes, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(appLocalizations.checkError), findsNothing);
    expect(find.text(appLocalizations.checking), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(probes, 2);
    expect(find.text(appLocalizations.healthHealthy), findsOneWidget);
    expect(controller.restartCoreCalls, 0);
  });

  testWidgets(
    'persistent probe failure remains visible after the first retry',
    (tester) async {
      final controller = await pumpHero(tester);
      controller.connectionProbeForTest = () async => false;
      controller.delegateHealthCheck = true;
      controller.bindingRef.read(runTimeProvider.notifier).value = 156000;
      controller.refreshConnectionCheck(immediate: true);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(appLocalizations.checkError), findsNothing);
      await tester.pump(const Duration(milliseconds: 601));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(appLocalizations.checkError), findsOneWidget);
      expect(controller.restartCoreCalls, 0);
      controller.bindingRef.read(connectionTargetProvider.notifier).state =
          false;
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets('a stop request disables the pending health-check retry', (
    tester,
  ) async {
    final controller = await pumpHero(tester);
    final ref = controller.bindingRef;
    ref.read(runTimeProvider.notifier).value = 156000;
    ref.read(connectionCheckProvider.notifier).state = ConnectionCheck.limited;
    ref.read(connectionTargetProvider.notifier).state = false;
    await tester.pump();
    final retry = tester.widget<TextButton>(
      find.widgetWithText(TextButton, appLocalizations.retry),
    );
    expect(retry.onPressed, isNull);
    expect(controller.refreshConnectionCheckCalls, 0);
  });

  testWidgets('a stop request cancels a scheduled health-check retry', (
    tester,
  ) async {
    final controller = await pumpHero(tester);
    final ref = controller.bindingRef;
    var probes = 0;
    controller.connectionProbeForTest = () async {
      probes++;
      return false;
    };
    controller.delegateHealthCheck = true;
    ref.read(runTimeProvider.notifier).value = 156000;
    controller.refreshConnectionCheck(immediate: true);
    await tester.pump(const Duration(milliseconds: 1));
    expect(probes, 1);
    ref.read(connectionTargetProvider.notifier).state = false;
    await tester.pump(const Duration(seconds: 3));
    expect(probes, 1);
  });

  testWidgets('desktop without system proxy or TUN reports local proxy', (
    tester,
  ) async {
    System.platformOverride = 'windows';
    final controller = await pumpHero(
      tester,
      brightness: Brightness.light,
      size: const Size(640, 500),
      systemProxy: false,
    );
    final ref = controller.bindingRef;
    ref.read(runTimeProvider.notifier).value = 156000;
    ref.read(connectionCheckProvider.notifier).state =
        ConnectionCheck.reachable;
    await tester.pumpAndSettle();

    expect(controller.desktopLocalProxyOnly, isTrue);
    expect(find.text(appLocalizations.localProxyOnly), findsOneWidget);
    expect(find.text(appLocalizations.healthHealthy), findsNothing);
    await capture(tester, 'local-proxy-only');

    controller.refreshConnectionCheck(immediate: true);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(seconds: 1));
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
      await pumpHero(tester, size: const Size(320, 640), textScale: 2.0);

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

    testWidgets('the primary connection panel has room for status and route', (
      tester,
    ) async {
      await pumpHero(tester);

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(StartButton)).height,
        getWidgetHeight(2),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'start-default');
    });
  });

  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 680), const Size(1280, 800)]) {
      testWidgets('network retry recovers without reconnecting $brightness $size', (
        tester,
      ) async {
        final controller = await pumpHero(
          tester,
          brightness: brightness,
          size: size,
          textScale: size.width < 600 ? 1.6 : 1,
        );
        controller.bindingRef.read(runTimeProvider.notifier).value = 156000;
        controller.bindingRef.read(connectionCheckProvider.notifier).state =
            ConnectionCheck.limited;
        await tester.pumpAndSettle();
        expect(find.text(appLocalizations.retry), findsOneWidget);
        expect(find.text(appLocalizations.checkError), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('FEEDBACK_CAPTURE')) {
          await captureFlutterFrame(
            tester,
            find.byKey(const ValueKey('start-capture')),
            'build/feedback_fixes/screenshots/start-retry-${brightness.name}-${size.width.toInt()}.png',
          );
        }
        await tester.tap(find.byKey(const ValueKey('connection-retry')));
        await tester.pump();
        expect(controller.connectionRetries, 1);
        expect(
          tester
              .widget<TextButton>(
                find.byKey(const ValueKey('connection-retry')),
              )
              .onPressed,
          isNull,
        );
        expect(find.text(appLocalizations.checking), findsOneWidget);
        expect(controller.updateStatusCalls, 0);
        expect(controller.restartCoreCalls, 0);
        controller.bindingRef.read(connectionCheckProvider.notifier).state =
            ConnectionCheck.reachable;
        await tester.pumpAndSettle();
        expect(find.text(appLocalizations.healthHealthy), findsOneWidget);
        expect(find.text(appLocalizations.checkError), findsNothing);
        expect(controller.bindingRef.read(runTimeProvider), 156000);
        if (const bool.fromEnvironment('FEEDBACK_CAPTURE')) {
          await captureFlutterFrame(
            tester,
            find.byKey(const ValueKey('start-capture')),
            'build/feedback_fixes/screenshots/start-recovered-${brightness.name}-${size.width.toInt()}.png',
          );
        }
      });
    }
  }
}
