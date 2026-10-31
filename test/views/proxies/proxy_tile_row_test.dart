import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/proxies/common.dart';
import 'package:fluxora/widgets/widgets.dart';

/// The proxy row at a **fixed** height.
///
/// The proxy list lays nodes out with `itemExtentBuilder`, so every tile gets
/// exactly `getItemHeight(cardType)` and nothing more. That budget is one name
/// block plus **one** secondary line, which is where the old tile broke: its
/// secondary row was a `Wrap`, so a long protocol label took a second line and
/// the row overflowed. Measured before the fix:
///
/// | case | height | result |
/// | --- | --- | --- |
/// | 320 px, 2.0×, `VLESS-Reality-Vision` | 140 | vertical overflow |
/// | 320 px, 3.0×, `Shadowsocks-2022` | 196 | vertical overflow |
/// | 320 px, 2.0×, `min` card, `Hysteria2-Obfs` | 100 | vertical overflow |
///
/// After pinning the secondary row to one line the overflow moved *inside*
/// `FluxoraStatus` (its label kept its intrinsic width: 340 px over to the
/// right), which is why the label is now `Flexible`.
///
/// These tests use the real tile, the real row height and the real text scale
/// (passed to `CommonTheme.of` / `Measure.of`, so the `.ap` damping is fed the
/// same value the widget sees — the mistake the dashboard harness made).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cases = <({String label, Size size, double scale, String protocol, int? delay, ProxyCardType type})>[
    (
      label: 'long protocol at 2.0x',
      size: const Size(320, 700),
      scale: 2.0,
      protocol: 'VLESS-Reality-Vision',
      delay: 4200,
      type: ProxyCardType.shrink,
    ),
    (
      label: 'long protocol at 3.0x',
      size: const Size(320, 700),
      scale: 3.0,
      protocol: 'Shadowsocks-2022',
      delay: -1,
      type: ProxyCardType.shrink,
    ),
    (
      label: 'min card at 2.0x',
      size: const Size(320, 700),
      scale: 2.0,
      protocol: 'Hysteria2-Obfs',
      delay: 42,
      type: ProxyCardType.min,
    ),
    (
      label: 'nominal phone row',
      size: const Size(390, 844),
      scale: 1.0,
      protocol: 'Trojan',
      delay: 42,
      type: ProxyCardType.shrink,
    ),
    (
      label: 'expand card with a hop description',
      size: const Size(390, 844),
      scale: 2.0,
      protocol: 'Trojan',
      delay: null,
      type: ProxyCardType.expand,
    ),
  ];

  Future<double> pumpRow(
    WidgetTester tester, {
    required Size size,
    required double scale,
    required String protocol,
    required int? delay,
    required ProxyCardType type,
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    globalState.appState = AppState(
      viewSize: size,
      brightness: brightness,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.proxies,
    );

    var itemHeight = 0.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF29D6C7),
            brightness: brightness,
          ),
        ),
        home: Builder(
          builder: (ctx) {
            // The same scale the widget tree will see.
            globalState.theme = CommonTheme.of(ctx, scale);
            globalState.measure = Measure.of(ctx, scale);
            itemHeight = getItemHeight(type);
            return MediaQuery(
              data: MediaQuery.of(ctx).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: ListView(
                  children: [
                    SizedBox(
                      height: itemHeight,
                      child: FluxoraProxyTile(
                        name: '一个非常长的节点名称 Very Long Node Name',
                        protocol: protocol,
                        status: FluxoraStatusKind.unknown,
                        delay: delay,
                        compact: true,
                        nameMaxLines: type == ProxyCardType.min ? 1 : 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: FluxoraSpacing.md,
                        ),
                        latencySlot: FluxoraLatencyBadge(
                          delay: delay,
                          dense: true,
                        ),
                        description: type == ProxyCardType.expand
                            ? const Text('auto → HK-01')
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    return itemHeight;
  }

  for (final c in cases) {
    testWidgets('the row fits its fixed extent — ${c.label}', (tester) async {
      final height = await pumpRow(
        tester,
        size: c.size,
        scale: c.scale,
        protocol: c.protocol,
        delay: c.delay,
        type: c.type,
      );

      expect(
        tester.takeException(),
        isNull,
        reason:
            'the tile must fit ${height.toStringAsFixed(0)} px at '
            '${c.scale}× with protocol "${c.protocol}"',
      );

      // The tile never grows past the row it was given.
      final tile = tester.getRect(find.byType(FluxoraProxyTile));
      expect(tile.height, height);

      // The latency affordance survives: it is the reason the row exists.
      expect(find.byType(FluxoraLatencyBadge), findsOneWidget);

      // The name ellipsises instead of wrapping.
      final name = tester.widget<Text>(
        find.text('一个非常长的节点名称 Very Long Node Name'),
      );
      expect(name.maxLines, c.type == ProxyCardType.min ? 1 : 2);
      expect(name.overflow, TextOverflow.ellipsis);
    });
  }

  testWidgets('the row holds in the light theme too', (tester) async {
    await pumpRow(
      tester,
      size: const Size(320, 700),
      scale: 2.0,
      protocol: 'VLESS-Reality-Vision',
      delay: 4200,
      type: ProxyCardType.shrink,
      brightness: Brightness.light,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(FluxoraLatencyBadge), findsOneWidget);
  });
}
