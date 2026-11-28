import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/profiles/profiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_capture.dart';

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
    if (const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
      await (FontLoader('HarmonyOS_Sans')..addFont(
            rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  for (final scenario in ['phone', 'desktop', 'missing']) {
    testWidgets('aggregate card selection and source details: $scenario', (
      tester,
    ) async {
      final missing = scenario == 'missing';
      final desktop = scenario == 'desktop';
      System.platformOverride = desktop ? 'windows' : 'android';
      addTearDown(() => System.platformOverride = null);
      tester.view.physicalSize = Size(
        desktop ? 1024 : (missing ? 300 : 390),
        844,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const a = Profile(
        id: 'source-a',
        label: '日常订阅',
        url: 'https://example.test/a',
        autoUpdateDuration: Duration(days: 1),
      );
      const b = Profile(
        id: 'source-b',
        label: '旅行订阅',
        url: 'https://example.test/b',
        autoUpdateDuration: Duration(days: 1),
      );
      globalState.config = Config(
        themeProps: defaultThemeProps,
        profiles: [a, b],
        currentProfileId: a.id,
        aggregates: [
          AggregateProfile(
            id: 'work',
            name: missing ? '办公与旅行使用的聚合订阅 · 长名称' : '办公与旅行',
            baseProfileId: a.id,
            memberIds: [b.id, if (missing) 'missing'],
          ),
        ],
      ).withAggregateProfiles();
      final aggregate = globalState.config.profiles.last;
      String? selected = a.id;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(
              fontFamily: 'HarmonyOS_Sans',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff4269d2),
                brightness: desktop ? Brightness.light : Brightness.dark,
              ),
            ),
            home: StatefulBuilder(
              builder: (context, setState) {
                return RepaintBoundary(
                  key: boundary,
                  child: Scaffold(
                    appBar: AppBar(title: const Text('配置')),
                    body: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(missing ? 1.3 : 1),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final profile in globalState.config.profiles)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ProfileItem(
                                profile: profile,
                                groupValue: selected,
                                onChanged: (id) =>
                                    setState(() => selected = id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
      expect(find.textContaining('日常订阅 · 旅行订阅'), findsOneWidget);
      if (missing) {
        expect(
          find.textContaining(appLocalizations.aggregateSourceMissing),
          findsOneWidget,
        );
      }
      await tester.tap(find.text(aggregate.label!));
      await tester.pumpAndSettle();
      expect(selected, aggregate.id);
      await tester.tap(find.text(a.label!));
      await tester.pumpAndSettle();
      expect(selected, a.id);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
        await captureFlutterFrame(
          tester,
          find.byKey(boundary),
          'build/feedback-20261127/aggregate-$scenario.png',
        );
      }
    });
  }
}
