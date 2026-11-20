import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/proxies/chain_hop_picker.dart';
import 'package:fluxora/views/proxies/notification_switch_card.dart';
import 'dart:convert';
import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/clash/interface.dart';

import '../../support/recording_app_controller.dart';
import '../../support/render_capture.dart';

class _DelayCore implements ClashHandlerInterface {
  final names = <String>[];
  @override
  bool get hasLiveProcess => true;
  @override
  Future<String> asyncTestDelay(String url, String proxyName) async {
    names.add(proxyName);
    return jsonEncode(Delay(name: proxyName, url: url, value: 62));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('${invocation.memberName}');
}

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  String? selected;
  Future<void> open(
    WidgetTester tester, {
    bool picking = true,
    Brightness brightness = Brightness.dark,
    String? sourceProfileId,
    List<Group>? candidateGroups,
    List<Group>? runtimeGroups,
    String title = '默认前置跳板',
    String? selectedName,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool allowPolicyGroups = false,
  }) async {
    selected = null;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    globalState.config = const Config(themeProps: ThemeProps());
    globalState.appState = AppState(
      viewSize: size,
      brightness: brightness,
      groups:
          runtimeGroups ??
          const [
            Group(
              name: '自动测速组',
              type: GroupType.URLTest,
              all: [
                Proxy(name: 'Tokyo node', type: 'vless'),
                Proxy(name: 'DIRECT', type: 'Direct'),
                Proxy(name: 'REJECT', type: 'Reject'),
                Proxy(name: 'Nested group', type: 'Selector'),
                Proxy(name: 'Excluded node', type: 'trojan'),
              ],
            ),
          ],
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    var bound = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: globalState.navigatorKey,
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppLocalizationDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN')],
          theme: fluxoraMaterialTheme(
            ThemeData(
              fontFamily: 'HarmonyOS_Sans',
              colorScheme: ColorScheme.fromSeed(
                seedColor: FluxoraColors.brandSeed,
                brightness: brightness,
              ),
            ),
            FluxoraSurfaceStyle.hybrid,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: RepaintBoundary(
              key: const ValueKey('hop-capture'),
              child: child!,
            ),
          ),
          home: Consumer(
            builder: (context, ref, _) {
              globalState.measure = Measure.of(context, 1);
              globalState.theme = CommonTheme.of(context, 1);
              if (!bound) {
                globalState.appController = RecordingAppController(
                  context,
                  ref,
                );
                bound = true;
              }
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      if (picking) {
                        showChainHopPicker(
                          context: context,
                          title: title,
                          allowPolicyGroups: allowPolicyGroups,
                          selectedName: selectedName,
                          excludeNames: {'Excluded node'},
                          sourceProfileId: sourceProfileId,
                          candidateGroups: candidateGroups,
                          onSelect: (value) => selected = value,
                        );
                      } else {
                        globalState.showCommonDialog(child: const SwitchCard());
                      }
                    },
                    child: const Text('选择'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'hop selection accepts ordinary nodes from an automatic group $brightness',
      (tester) async {
        await open(tester, brightness: brightness);
        expect(find.text('DIRECT'), findsNothing);
        expect(find.text('REJECT'), findsNothing);
        expect(find.text('Nested group'), findsNothing);
        expect(find.text('Excluded node'), findsNothing);
        if (const bool.fromEnvironment('FEEDBACK_CAPTURE')) {
          await captureFlutterFrame(
            tester,
            find.byKey(const ValueKey('hop-capture')),
            'build/feedback_fixes/screenshots/hop-${brightness.name}.png',
          );
        }
        expect(
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.text('Tokyo node'),
                      matching: find.byType(InkWell),
                    )
                    .first,
              )
              .height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.text('Tokyo node'));
        await tester.pumpAndSettle();
        expect(selected, 'Tokyo node');
        expect(find.byType(SwitchCard), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('live automatic groups expose manual node selection', (
    tester,
  ) async {
    await open(tester, picking: false);
    final row = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('Tokyo node'), matching: find.byType(InkWell))
          .first,
    );
    expect(row.onTap, isNotNull);
  });

  testWidgets(
    'an inactive profile keeps its own nodes and a visible disabled test action',
    (tester) async {
      await open(
        tester,
        sourceProfileId: 'inactive',
        candidateGroups: const [
          Group(
            name: 'Inactive profile',
            type: GroupType.Selector,
            all: [Proxy(name: 'Inactive node', type: 'vless')],
          ),
        ],
      );
      expect(find.text('Tokyo node'), findsNothing);
      expect(find.text('Inactive node'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('hop-delay-test')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Inactive node'));
      await tester.pumpAndSettle();
      expect(selected, 'Inactive node');
      expect(globalState.config.currentProfileId, isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('compact hop toolbar and long nodes $brightness', (
      tester,
    ) async {
      const chosen = '美国 05 | 公益线路 · 很长的节点名称';
      await open(
        tester,
        brightness: brightness,
        selectedName: chosen,
        runtimeGroups: const [
          Group(
            name: 'GLOBAL',
            type: GroupType.Selector,
            all: [
              Proxy(name: chosen, type: 'vless'),
              Proxy(name: '新加坡 02 | 流媒体', type: 'trojan'),
              Proxy(name: '香港 03 | 故障节点', type: 'ss'),
            ],
          ),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SwitchCard)),
      );
      final url = container.read(getRealTestUrlProvider());
      container.read(delayDataSourceProvider.notifier).value = {
        url: {chosen: 62, '新加坡 02 | 流媒体': 138, '香港 03 | 故障节点': -1},
      };
      await tester.pump();
      final locate = find.byKey(const ValueKey('switch-card-locate'));
      final speed = find.byKey(const ValueKey('hop-delay-test'));
      expect(
        tester.getCenter(locate).dy,
        closeTo(tester.getCenter(speed).dy, 1),
      );
      expect(tester.getSize(speed).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(speed).height, greaterThanOrEqualTo(48));
      expect(find.text(appLocalizations.chainSpeedTest), findsNothing);
      expect(find.textContaining('62'), findsOneWidget);
      if (const bool.fromEnvironment('FEEDBACK_CAPTURE')) {
        await captureFlutterFrame(
          tester,
          find.byKey(const ValueKey('hop-capture')),
          'build/feedback_fixes/screenshots/picker-compact-${brightness.name}.png',
        );
      }
      await tester.tap(find.text(chosen));
      await tester.pumpAndSettle();
      expect(selected, chosen);
      expect(tester.takeException(), isNull);
    });
  }

  for (final title in ['默认前置跳板', '后置代理节点', '选择 WARP 跳板', '默认后置跳板']) {
    testWidgets('narrow large text picker keeps toolbar usable: $title', (
      tester,
    ) async {
      await open(
        tester,
        title: title,
        size: const Size(320, 680),
        textScale: 1.6,
      );
      final speed = find.byKey(const ValueKey('hop-delay-test'));
      final locate = find.byKey(const ValueKey('switch-card-locate'));
      expect(
        tester.getCenter(locate).dy,
        closeTo(tester.getCenter(speed).dy, 1),
      );
      expect(tester.getRect(speed).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
      if (title == '默认前置跳板' && const bool.fromEnvironment('FEEDBACK_CAPTURE')) {
        await captureFlutterFrame(
          tester,
          find.byKey(const ValueKey('hop-capture')),
          'build/feedback_fixes/screenshots/picker-narrow-large-text.png',
        );
      }
      await tester.tap(find.text('Tokyo node'));
      await tester.pumpAndSettle();
      expect(selected, 'Tokyo node');
    });
  }

  testWidgets('desktop picker stays compact and selects a node', (
    tester,
  ) async {
    await open(tester, title: '选择 WARP 跳板', size: const Size(1280, 800));
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('Tokyo node'),
                  matching: find.byType(Material),
                )
                .first,
          )
          .width,
      lessThanOrEqualTo(560),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('hop-delay-test'))).dy,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('switch-card-locate'))).dy,
        1,
      ),
    );
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('FEEDBACK_CAPTURE')) {
      await captureFlutterFrame(
        tester,
        find.byKey(const ValueKey('hop-capture')),
        'build/feedback_fixes/screenshots/picker-desktop.png',
      );
    }
    await tester.tap(find.text('Tokyo node'));
    await tester.pumpAndSettle();
    expect(selected, 'Tokyo node');
  });

  for (final title in ['链式中转', '选择 WARP 跳板', '前置代理', '后置代理', '通知切换']) {
    testWidgets(
      '$title long press tests exactly one node without selecting it',
      (tester) async {
        final previous = clashCore.clashInterface;
        final core = _DelayCore();
        clashCore.clashInterface = core;
        addTearDown(() => clashCore.clashInterface = previous);
        await open(tester, title: title, picking: title != '通知切换');
        await tester.longPress(find.text('Tokyo node'));
        await tester.pumpAndSettle();
        expect(core.names, ['Tokyo node']);
        expect(selected, isNull);
        expect(find.byType(SwitchCard), findsOneWidget);
        expect(find.text('62 ms'), findsOneWidget);
      },
    );
  }

  testWidgets('GLOBAL retains builtin, generated and hidden policy members', (
    tester,
  ) async {
    const members = [
      Proxy(name: 'DIRECT', type: 'Direct'),
      Proxy(name: 'REJECT', type: 'Reject'),
      Proxy(name: '🔗出口·Tokyo', type: 'socks5'),
      Proxy(name: 'Hidden policy', type: 'Selector'),
    ];
    await open(
      tester,
      allowPolicyGroups: true,
      runtimeGroups: const [
        Group(name: 'GLOBAL', type: GroupType.Selector, all: members),
        Group(
          name: 'Hidden policy',
          type: GroupType.Selector,
          hidden: true,
          all: [Proxy(name: 'Tokyo node', type: 'vless')],
        ),
      ],
    );
    for (final item in members) {
      expect(find.text(item.name), findsOneWidget);
    }
    await tester.tap(find.text('Hidden policy'));
    await tester.pumpAndSettle();
    expect(selected, 'Hidden policy');
  });

  testWidgets(
    'hop bulk tests include GLOBAL policy groups and show their results',
    (tester) async {
      final previous = clashCore.clashInterface;
      final core = _DelayCore();
      clashCore.clashInterface = core;
      addTearDown(() => clashCore.clashInterface = previous);
      await open(
        tester,
        allowPolicyGroups: true,
        runtimeGroups: [
          Group(
            name: 'GLOBAL',
            type: GroupType.Selector,
            all: [
              for (final type in GroupType.values)
                Proxy(name: type.name, type: type.name),
            ],
          ),
          for (final type in GroupType.values)
            Group(
              name: type.name,
              type: type,
              now: 'node',
              all: const [Proxy(name: 'node', type: 'vless')],
            ),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('hop-delay-test')));
      await tester.pumpAndSettle();
      expect(core.names.toSet(), GroupType.values.map((t) => t.name).toSet());
      expect(find.text('62 ms'), findsNWidgets(4));
      expect(selected, isNull);
    },
  );
}
