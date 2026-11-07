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
import 'package:fluxora/state.dart';
import 'package:fluxora/views/proxies/chain_hop_picker.dart';
import 'package:fluxora/views/proxies/notification_switch_card.dart';

import '../../support/recording_app_controller.dart';
import '../../support/render_capture.dart';

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
  }) async {
    selected = null;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    globalState.config = const Config(themeProps: ThemeProps());
    globalState.appState = AppState(
      viewSize: const Size(390, 844),
      brightness: brightness,
      groups: const [
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
          builder: (_, child) => RepaintBoundary(
            key: const ValueKey('hop-capture'),
            child: child!,
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
                          title: '前置跳板',
                          excludeNames: {'Excluded node'},
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
}
