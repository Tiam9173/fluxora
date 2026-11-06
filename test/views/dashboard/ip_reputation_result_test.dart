import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/dashboard/widgets/ip_reputation_result.dart';
import 'package:fluxora/views/dashboard/widgets/network_detection.dart';
import 'package:fluxora/widgets/widgets.dart';

import '../../support/render_capture.dart';

class _RiskVisualBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

const _ip = '2001:db8:1234:5678:90ab:cdef:1234:5678';
const _info = IpInfo(
  ip: _ip,
  countryCode: 'DE',
  country: '德国',
  continent: '欧洲',
  province: '柏林',
  city: '柏林',
  isp: 'Example Network Services',
  asName: 'Example International Network',
  asn: 'AS64500',
  asDomain: 'network.example.test',
);

final _report = IpReputation(
  status: IpReputationStatus.ok,
  ip: _ip,
  source: 'cache',
  queriedAt: DateTime.utc(2026, 11, 6, 6, 30),
  stale: true,
  asn: 'AS64500',
  asnOrg: 'Example International Network',
  usageType: 'hosting',
  nativeType: 'native',
  abuseScore: 12,
  abuseReports: 3,
  blocklistsHit: const ['Example blocklist'],
  risk: const IpRiskScore(
    purity: 68,
    label: '需留意',
    verdict: '来源发现部分代理与共享网络特征',
    factors: [
      IpRiskFactor(id: 'proxy', label: '代理网络特征', points: 25),
      IpRiskFactor(id: 'shared', label: '共享基础设施', points: 12),
      IpRiskFactor(id: 'native', label: '原生地址记录', points: -5),
    ],
  ),
  scenarios: const [
    IpScenarioScore(id: 'ai', score: 72, levelLabel: '需留意'),
    IpScenarioScore(id: 'social', score: 64, levelLabel: '需留意'),
    IpScenarioScore(id: 'streaming', score: 86, levelLabel: '较适合'),
    IpScenarioScore(id: 'gaming', score: 80, levelLabel: '较适合'),
    IpScenarioScore(id: 'ecommerce', score: 58, levelLabel: '需留意'),
    IpScenarioScore(id: 'email', score: null),
  ],
  markers: const [
    IpRiskMarker(id: 'vpn', state: IpRiskMarkerState.unknown),
    IpRiskMarker(id: 'proxy', state: IpRiskMarkerState.flagged),
    IpRiskMarker(id: 'tor', state: IpRiskMarkerState.clear),
    IpRiskMarker(id: 'hosting', state: IpRiskMarkerState.flagged),
    IpRiskMarker(id: 'relay', state: IpRiskMarkerState.unknown),
    IpRiskMarker(id: 'mobile', state: IpRiskMarkerState.clear),
    IpRiskMarker(id: 'bogon', state: IpRiskMarkerState.clear),
    IpRiskMarker(id: 'searchEngineBot', state: IpRiskMarkerState.unknown),
  ],
  unknownNotes: const ['来源记录不能保证所有服务均可使用。'],
  reportUrl: 'https://example.test/report',
);

void main() {
  _RiskVisualBinding();
  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<void> open(
    WidgetTester tester, {
    required Widget child,
    Brightness brightness = Brightness.dark,
    Size size = const Size(375, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    globalState.config = const Config(themeProps: ThemeProps());
    globalState.appState = AppState(
      viewSize: size,
      brightness: brightness,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            return MaterialApp(
              navigatorKey: globalState.navigatorKey,
              locale: const Locale('zh', 'CN'),
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: fluxoraMaterialTheme(
                ThemeData(
                  fontFamily: 'HarmonyOS_Sans',
                  colorScheme: ref.watch(genColorSchemeProvider(brightness)),
                ),
                FluxoraSurfaceStyle.hybrid,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(textScale),
                ),
                child: RepaintBoundary(
                  key: const ValueKey('risk-capture'),
                  child: child!,
                ),
              ),
              home: Builder(
                builder: (context) {
                  globalState.theme = CommonTheme.of(context, textScale);
                  globalState.measure = Measure.of(context, textScale);
                  return Scaffold(
                    body: Center(
                      child: FilledButton(
                        onPressed: () =>
                            globalState.showCommonDialog(child: child),
                        child: const Text('打开'),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Widget result(
    IpReputation report, {
    Set<String>? fields,
    VoidCallback? onOpen,
  }) => CommonDialog(
    title: appLocalizations.ipRiskIntel,
    maxWidth: 600,
    actions: [
      TextButton(
        onPressed: () => globalState.navigatorKey.currentState!.pop(),
        child: Text(appLocalizations.confirm),
      ),
    ],
    child: IpReputationResult(
      report: report,
      fields: fields ?? IpReputationFieldIds.all.toSet(),
      onOpenReport: onOpen,
    ),
  );

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('NETWORK_UI_CAPTURE')) return;
    await captureFlutterFrame(
      tester,
      find.byKey(const ValueKey('risk-capture')),
      'build/ip_risk_ui/screenshots/$name.png',
    );
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  void aligned(WidgetTester tester) {
    final cards = tester.getRect(find.byType(FluxoraCard).first);
    for (final element in find.byType(FluxoraCard).evaluate()) {
      final other = tester.getRect(find.byWidget(element.widget));
      expect(other.left, closeTo(cards.left, .1));
      expect(other.right, closeTo(cards.right, .1));
    }
  }

  for (final brightness in Brightness.values) {
    for (final size in [const Size(375, 844), const Size(1080, 900)]) {
      final name = '${size.width.toInt()}-${brightness.name}';
      testWidgets('IP details align and stay opt-in $name', (tester) async {
        await open(
          tester,
          child: const NetworkIpInfoDialog(info: _info),
          brightness: brightness,
          size: size,
        );
        expect(find.text(_ip), findsOneWidget);
        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
        aligned(tester);
        await capture(tester, 'details-$name');
        await reveal(tester, find.text(appLocalizations.ipRiskPrivacyNote));
        await capture(tester, 'details-footer-$name');
        await tester.tap(find.text(appLocalizations.confirm));
        await tester.pumpAndSettle();
        expect(find.byType(NetworkIpInfoDialog), findsNothing);
      });

      testWidgets('source report remains readable and actionable $name', (
        tester,
      ) async {
        var opened = 0;
        await open(
          tester,
          child: result(_report, onOpen: () => opened++),
          brightness: brightness,
          size: size,
        );
        aligned(tester);
        expect(find.text('代理网络特征'), findsOneWidget);
        expect(find.text('Example blocklist'), findsOneWidget);
        expect(find.text('null'), findsNothing);
        await capture(tester, 'report-score-$name');
        await reveal(tester, find.text(appLocalizations.ipRiskScenarios));
        await capture(tester, 'report-scenarios-$name');
        await reveal(tester, find.text(appLocalizations.fieldMarkers));
        await capture(tester, 'report-markers-$name');
        await reveal(tester, find.text(appLocalizations.ipRiskOpenReport));
        expect(find.text(appLocalizations.ipRiskStale), findsOneWidget);
        await capture(tester, 'report-source-$name');
        await tester.tap(find.text(appLocalizations.ipRiskOpenReport));
        expect(opened, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'field selection hides optional data without hiding source limits',
    (tester) async {
      await open(
        tester,
        child: result(_report, fields: {IpReputationFieldIds.scenarios}),
      );
      expect(find.text(appLocalizations.ipRiskScore), findsNothing);
      expect(find.text('Example blocklist'), findsNothing);
      expect(find.text(appLocalizations.ipRiskScenarios), findsOneWidget);
      expect(find.text(_report.unknownNotes.single), findsOneWidget);
      expect(find.text(_report.source!), findsOneWidget);
    },
  );

  for (final size in [const Size(320, 844), const Size(844, 390)]) {
    testWidgets('long IPv6 and 200% text remain usable $size', (tester) async {
      await open(
        tester,
        child: const NetworkIpInfoDialog(info: _info),
        size: size,
        textScale: 2,
      );
      await capture(tester, 'large-text-${size.width.toInt()}');
      await reveal(tester, find.text(appLocalizations.ipRiskPrivacyNote));
      await tester.tap(find.text(appLocalizations.confirm));
      await tester.pumpAndSettle();
      expect(find.byType(NetworkIpInfoDialog), findsNothing);
    });
  }

  testWidgets('failure is not a clean score', (tester) async {
    await open(
      tester,
      child: result(IpReputation.unavailable(_ip, IpReputationFailure.timeout)),
    );
    expect(find.text(appLocalizations.ipRiskFailed), findsOneWidget);
    expect(find.text(appLocalizations.ipRiskScore), findsNothing);
    await capture(tester, 'report-failure');
  });

  testWidgets('missing score and unknown markers remain unknown at 200% text', (
    tester,
  ) async {
    await open(
      tester,
      textScale: 2,
      child: result(
        const IpReputation(
          status: IpReputationStatus.ok,
          ip: _ip,
          markers: [
            IpRiskMarker(
              id: 'searchEngineBot',
              state: IpRiskMarkerState.unknown,
            ),
          ],
          scenarios: [IpScenarioScore(id: 'email')],
        ),
      ),
    );
    expect(find.text(appLocalizations.ipRiskScore), findsNothing);
    expect(find.text(appLocalizations.unknown), findsNWidgets(3));
    expect(find.text('null'), findsNothing);
    await capture(tester, 'report-missing-large-text');
  });
}
