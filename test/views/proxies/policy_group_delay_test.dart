import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/views/proxies/card.dart';
import 'package:fluxora/views/proxies/common.dart';
import '../../support/render_capture.dart';

class _Core extends Fake implements ClashHandlerInterface {
  final names = <String>[];
  Completer<void>? pending;
  String now = 'node';

  @override
  Future<String> getMode() async => 'rule';

  @override
  Future<Map> getProxies() async => {
    'GLOBAL': {
      'name': 'GLOBAL',
      'type': 'Selector',
      'now': 'Selector',
      'all': ['Selector'],
    },
    for (final type in GroupType.values)
      type.name: {
        'name': type.name,
        'type': type.name,
        'now': now,
        'all': ['node', 'another-node'],
      },
    'node': {'name': 'node', 'type': 'Vless'},
    'another-node': {'name': 'another-node', 'type': 'Vless'},
  };

  @override
  Future<String> asyncTestDelay(String url, String proxyName) async {
    names.add(proxyName);
    await pending?.future;
    return jsonEncode(
      Delay(name: proxyName, url: url, value: proxyName == 'node' ? 10 : 80),
    );
  }
}

void main() {
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
  late WidgetRef ref;
  late AppController controller;
  late _Core core;
  late ClashHandlerInterface previous;
  late String url;

  final members = [
    const Proxy(name: 'node', type: 'vless'),
    for (final type in GroupType.values)
      Proxy(name: type.name, type: type.name),
    const Proxy(name: 'DIRECT', type: 'Direct'),
    const Proxy(name: 'REJECT', type: 'Reject'),
  ];

  setUp(() {
    previous = clashCore.clashInterface;
    core = _Core();
    clashCore.clashInterface = core;
    globalState.config = const Config(
      themeProps: ThemeProps(),
      currentProfileId: 'fixture',
      profiles: [Profile(id: 'fixture', autoUpdateDuration: Duration(days: 1))],
    );
    globalState.appState = AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      version: 1,
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      groups: [
        Group(name: 'GLOBAL', type: GroupType.Selector, all: members),
        for (final type in GroupType.values)
          Group(
            name: type.name,
            type: type,
            hidden: type == GroupType.Selector,
            now: 'node',
            all: [members.first],
          ),
      ],
    );
  });
  tearDown(() => clashCore.clashInterface = previous);

  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    bool cards = false,
  }) async {
    var bound = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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
          home: Consumer(
            builder: (context, r, _) {
              ref = r;
              if (!bound) {
                controller = AppController(context, ref);
                globalState.appController = controller;
                bound = true;
              }
              globalState.measure = Measure.of(context, 1);
              globalState.theme = CommonTheme.of(context, 1);
              return Scaffold(
                body: RepaintBoundary(
                  key: const ValueKey('policy-capture'),
                  child: Center(
                    child: SizedBox(
                      width: 360,
                      child: cards
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final type in GroupType.values)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: SizedBox(
                                      height: 88,
                                      child: ProxyCard(
                                        groupName: 'GLOBAL',
                                        proxy: Proxy(
                                          name: type.name,
                                          type: type.name,
                                        ),
                                        groupType: GroupType.Selector,
                                        type: ProxyCardType.shrink,
                                        testUrl: null,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : const SizedBox(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    url = controller.getRealTestUrl(null);
  }

  for (final brightness in Brightness.values) {
    testWidgets('policy cards show own success and timeout results $brightness', (
      tester,
    ) async {
      await pump(tester, cards: true, brightness: brightness);
      await delayTest(members, groupName: 'GLOBAL');
      controller.setDelay(Delay(name: 'LoadBalance', url: url, value: -1));
      await tester.pumpAndSettle();
      expect(find.text('80 ms'), findsNWidgets(3));
      expect(find.text(appLocalizations.timeoutLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('FEEDBACK_CAPTURE')) {
        await captureFlutterFrame(
          tester,
          find.byKey(const ValueKey('policy-capture')),
          'build/feedback_fixes/screenshots/policy-delay-${brightness.name}.png',
        );
      }
      await tester.tap(find.text('80 ms').first);
      await tester.pumpAndSettle();
      expect(core.names.last, 'Selector');
    });
  }

  testWidgets(
    'GLOBAL probes groups by their own names and displays their results',
    (tester) async {
      await pump(tester);
      final selections = ref.read(selectedMapProvider);
      await delayTest(members, groupName: 'GLOBAL');
      expect(core.names.toSet(), {
        'node',
        ...GroupType.values.map((t) => t.name),
      });
      for (final type in GroupType.values) {
        expect(ref.read(getDelayProvider(proxyName: type.name)), 80);
      }
      expect(ref.read(getDelayProvider(proxyName: 'node')), 10);
      expect(ref.read(selectedMapProvider), selections);
    },
  );

  testWidgets(
    'native route changes invalidate group measurements but keep leaf measurements',
    (tester) async {
      await pump(tester);
      controller.setDelay(Delay(name: 'node', url: url, value: 10));
      controller.setDelay(Delay(name: 'Selector', url: url, value: 80));
      core.now = 'another-node';
      await tester.runAsync(
        () => controller.updateGroups(preloadedProviders: const []),
      );
      expect(
        ref.read(groupsProvider).firstWhere((g) => g.name == 'Selector').now,
        'another-node',
      );
      expect(ref.read(delayDataSourceProvider)[url]?['Selector'], isNull);
      expect(ref.read(delayDataSourceProvider)[url]?['node'], 10);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'changing the route drops old group results and separates in-flight requests',
    (tester) async {
      await pump(tester);
      controller.setDelay(Delay(name: 'node', url: url, value: 10));
      core.pending = Completer<void>();
      final old = delayTest(const [
        Proxy(name: 'Selector', type: 'Selector'),
      ], useExactTargets: true);
      expect(core.names, ['Selector']);
      controller.updateCurrentSelectedMap('Selector', 'another-node');
      expect(ref.read(delayDataSourceProvider)[url]?['Selector'], isNull);
      expect(ref.read(delayDataSourceProvider)[url]?['node'], 10);

      final pending = core.pending!;
      core.pending = null;
      await proxyDelayTest(const Proxy(name: 'Selector', type: 'Selector'));
      expect(core.names, ['Selector', 'Selector']);
      controller.setDelay(Delay(name: 'Selector', url: url, value: 33));
      pending.complete();
      await old;
      expect(ref.read(getDelayProvider(proxyName: 'Selector')), 33);
    },
  );
}
