import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/dashboard/widgets/speed_test_card.dart';
import 'package:fluxora/widgets/widgets.dart';

import '../../support/recording_app_controller.dart';
import '../../support/render_capture.dart';

class _Core implements ClashHandlerInterface {
  Map<String, Object> frame = {'phase': 'idle'};
  Completer<String>? pending;
  int reads = 0;
  int starts = 0;
  bool live = true;
  @override
  bool get hasLiveProcess => live;
  @override
  Future<T> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
    FutureOr<T> Function()? onTimeout,
    T? defaultValue,
  }) async {
    if (method == ActionMethod.speedTestStatus) {
      reads++;
      return (pending == null ? jsonEncode(frame) : await pending!.future) as T;
    }
    if (method == ActionMethod.speedTest) {
      starts++;
      expect(jsonDecode(data as String)['outbound'], 'test-group');
      frame = {'phase': 'latency'};
      return 'started' as T;
    }
    throw StateError('Unexpected native action: $method');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected core call: ${invocation.memberName}');
}

class _Controller extends RecordingAppController {
  _Controller(super.context, super.ref);
  @override
  Future<void> speedTest() => clashCore.speedTest(outbound: 'test-group');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ClashHandlerInterface original;
  late _Core core;
  setUpAll(() async {
    original = clashCore.clashInterface;
    await AppLocalizations.load(const Locale('zh', 'CN'));
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    core = _Core();
    clashCore.clashInterface = core;
  });
  tearDown(() => clashCore.clashInterface = original);

  Future<void> show(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    Brightness brightness = Brightness.dark,
    FluxoraVisualStyle visualStyle = FluxoraVisualStyle.fluxora,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            theme: fluxoraMaterialTheme(
              ThemeData(
                fontFamily: 'HarmonyOS_Sans',
                colorScheme: fluxoraSchemeFromSeed(
                  brightness: brightness,
                  seed: FluxoraColors.flowViolet,
                  variant: DynamicSchemeVariant.tonalSpot,
                ),
              ),
              FluxoraSurfaceStyle.hybrid,
              visualStyle: visualStyle,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: RepaintBoundary(
                key: const ValueKey('speed-capture'),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  globalState.appController = _Controller(context, ref);
                  return TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const SpeedTestCard(),
                    ),
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('AURORA_CAPTURE')) return;
    await captureFlutterFrame(
      tester,
      find.byKey(const ValueKey('speed-capture')),
      'build/ux_feedback_v2/captures/speed-$name.png',
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'speed panel idle, real progress, error and retry $brightness',
      (tester) async {
        await show(tester, brightness: brightness);
        expect(core.reads, 1);
        expect(core.starts, 0);
        await capture(tester, '${brightness.name}-idle');
        await tester.tap(find.byKey(const ValueKey('speed-test-start')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('speed-test-start')));
        expect(core.starts, 1);
        core.frame = {
          'phase': 'download',
          'downMbps': 86.4,
          'latencyMs': 42,
          'serverName': 'Offline fixture',
        };
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('86.4'), findsWidgets);
        await capture(tester, '${brightness.name}-running');
        core.frame = {'phase': 'failed', 'error': '离线测试：服务器未响应'};
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('离线测试：服务器未响应'), findsOneWidget);
        await capture(tester, '${brightness.name}-error');
        final reads = core.reads;
        await tester.pump(const Duration(seconds: 2));
        expect(core.reads, reads);
        await tester.tap(find.byKey(const ValueKey('speed-test-start')));
        await tester.pump();
        expect(core.starts, 2);
        await tester.tap(find.byKey(const ValueKey('speed-test-close')));
        await tester.pumpAndSettle();
        final afterClose = core.reads;
        await tester.pump(const Duration(seconds: 15));
        expect(core.reads, afterClose);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Obsidian speed panel clips button sheen and only offers real results',
    (tester) async {
      await show(tester, visualStyle: FluxoraVisualStyle.obsidian);
      final start = find.byKey(const ValueKey('speed-test-start'));
      final sheen = find.descendant(
        of: start,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is ShapeDecoration &&
              (widget.decoration as ShapeDecoration).shape is StadiumBorder,
        ),
      );
      expect(sheen, findsOneWidget);
      expect(find.text(appLocalizations.stCopy), findsNothing);
      await capture(tester, 'obsidian-idle');
      await tester.tap(start);
      await tester.pump();
      core.frame = {'phase': 'done', 'downMbps': 86.4, 'latencyMs': 42};
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text(appLocalizations.stCopy), findsOneWidget);
      await capture(tester, 'obsidian-results');
    },
  );

  testWidgets(
    'reopened running test polls serially and rolling chart keeps increasing',
    (tester) async {
      core.frame = {'phase': 'download', 'downMbps': 12.0};
      await show(tester);
      core.pending = Completer<String>();
      await tester.pump(const Duration(milliseconds: 300));
      final reads = core.reads;
      await tester.pump(const Duration(seconds: 2));
      expect(core.reads, reads);
      core.pending!.complete(jsonEncode(core.frame));
      core.pending = null;
      await tester.pump();
      for (var i = 0; i < 46; i++) {
        core.frame = {'phase': 'download', 'downMbps': 10.0 + i};
        await tester.pump(const Duration(milliseconds: 300));
      }
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.points, hasLength(40));
      expect(chart.points.last.x, greaterThan(40));
      expect(chart.points.last.y, 55);
      await tester.tap(find.byKey(const ValueKey('speed-test-close')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 740), const Size(740, 320)]) {
    testWidgets('speed results remain reachable with double text at $size', (
      tester,
    ) async {
      core.frame = {
        'phase': 'done',
        'latencyMs': 123,
        'downMbps': 1428.5,
        'upMbps': 128.4,
        'serverName': 'Long offline fixture server name',
      };
      await show(tester, size: size, textScale: 2);
      expect(tester.takeException(), isNull);
      await capture(tester, 'large-${size.width.toInt()}');
      await tester.ensureVisible(
        find.byKey(const ValueKey('speed-test-start')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, 'large-${size.width.toInt()}-actions');
    });
  }
}
