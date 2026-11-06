import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/common/tokens/tokens.dart';
import 'package:fluxora/models/config.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/widgets/card.dart';
import 'package:fluxora/widgets/fluxora/fluxora_proxy_tile.dart';
import 'package:fluxora/widgets/glass_surface.dart';
import 'package:fluxora/widgets/popup.dart';
import 'package:fluxora/widgets/side_sheet.dart';

ThemeData glassTestTheme(Brightness brightness, FluxoraSurfaceStyle style) =>
    fluxoraMaterialTheme(
      ThemeData(
        fontFamily: 'HarmonyOS_Sans',
        colorScheme: fluxoraSchemeFromSeed(
          brightness: brightness,
          seed: FluxoraColors.fluxCyan,
          variant: DynamicSchemeVariant.tonalSpot,
        ),
      ),
      style,
    );

void main() {
  test(
    'material preference round trips without changing icon/theme settings',
    () {
      for (final style in FluxoraSurfaceStyle.values) {
        final original = Config(
          themeProps: ThemeProps(
            surfaceStyle: style,
            appIconStyle: 'sunset',
            useDarkIcon: false,
            themeMode: ThemeMode.dark,
          ),
        );
        expect(Config.fromJson(jsonDecode(jsonEncode(original))), original);
      }
      expect(ThemeProps.fromJson({}).surfaceStyle, FluxoraSurfaceStyle.hybrid);
      expect(
        ThemeProps.fromJson({'surfaceStyle': 'future-mode'}).surfaceStyle,
        FluxoraSurfaceStyle.classic,
      );
    },
  );

  test('Classic returns the original theme with custom component settings', () {
    final base = ThemeData(dialogTheme: const DialogThemeData(elevation: 17));
    expect(fluxoraMaterialTheme(base, FluxoraSurfaceStyle.classic), same(base));
  });

  test('pure black canvas is preserved', () {
    final base = ThemeData.dark().copyWith(
      colorScheme: ThemeData.dark().colorScheme.copyWith(surface: Colors.black),
    );
    for (final style in FluxoraSurfaceStyle.values) {
      expect(
        fluxoraMaterialTheme(base, style).colorScheme.surface,
        Colors.black,
      );
    }
    expect(
      fluxoraMaterialTheme(
        base,
        FluxoraSurfaceStyle.hybrid,
      ).scaffoldBackgroundColor,
      Colors.black,
    );
  });

  for (final brightness in Brightness.values) {
    for (final style in FluxoraSurfaceStyle.values) {
      test('$brightness $style keeps labels readable and semantic roles', () {
        final base = glassTestTheme(brightness, FluxoraSurfaceStyle.classic);
        final theme = glassTestTheme(brightness, style);
        final scheme = theme.colorScheme;
        expect(scheme.primary, base.colorScheme.primary);
        expect(scheme.error, base.colorScheme.error);
        for (final foreground in [scheme.onSurface, scheme.onSurfaceVariant]) {
          for (final background in [
            scheme.surface,
            scheme.surfaceContainer,
            scheme.surfaceContainerHigh,
            Color.alphaBlend(
              const FluxoraMaterial(
                style: FluxoraSurfaceStyle.hybrid,
              ).fill(scheme),
              scheme.surface,
            ),
          ]) {
            final a = foreground.computeLuminance();
            final b = background.computeLuminance();
            expect(
              (math.max(a, b) + .05) / (math.min(a, b) + .05),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
        if (style != FluxoraSurfaceStyle.classic) {
          expect(theme.dialogTheme.backgroundColor!.a, 1);
          expect(theme.popupMenuTheme.color!.a, 1);
        }
      });
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    FluxoraSurfaceStyle style = FluxoraSurfaceStyle.hybrid,
    MediaQueryData media = const MediaQueryData(),
  }) => tester.pumpWidget(
    MaterialApp(
      theme: glassTestTheme(Brightness.dark, style),
      home: MediaQuery(
        data: media,
        child: Scaffold(body: child),
      ),
    ),
  );

  testWidgets('blur is bounded, opt-in and never nested', (tester) async {
    await pump(tester, const GlassSurface(child: Text('no filter')));
    expect(find.byType(BackdropFilter), findsNothing);
    await pump(
      tester,
      const Center(
        child: SizedBox(
          width: 240,
          height: 120,
          child: GlassSurface(
            blur: true,
            child: GlassSurface(blur: true, child: Text('bounded')),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.getSize(find.byType(BackdropFilter)), const Size(240, 120));
    expect(
      find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.byType(ClipRRect),
      ),
      findsOneWidget,
    );
  });

  testWidgets('painted glass keeps its dark fill beneath the sheen', (
    tester,
  ) async {
    const key = ValueKey('painted-glass');
    await tester.pumpWidget(
      MaterialApp(
        theme: glassTestTheme(Brightness.dark, FluxoraSurfaceStyle.hybrid),
        home: const Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 100,
              height: 100,
              child: GlassSurface(child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      final pixel = (50 * 100 + 50) * 4;
      expect(data!.getUint8(pixel + 3), greaterThanOrEqualTo(210));
      expect(data.getUint8(pixel), lessThan(90));
      image.dispose();
    });
  });

  for (final media in [
    const MediaQueryData(disableAnimations: true),
    const MediaQueryData(highContrast: true),
    const MediaQueryData(accessibleNavigation: true),
  ]) {
    testWidgets('OS accessibility suppresses blur: $media', (tester) async {
      await pump(
        tester,
        const GlassSurface(blur: true, child: Text('accessible')),
        media: media,
      );
      expect(find.byType(BackdropFilter), findsNothing);
      final context = tester.element(find.text('accessible'));
      expect(
        FluxoraMaterial.of(context).fill(Theme.of(context).colorScheme).a,
        1,
      );
    });
  }

  for (final style in [
    FluxoraSurfaceStyle.classic,
    FluxoraSurfaceStyle.reduced,
  ]) {
    testWidgets('$style never creates blur', (tester) async {
      await pump(
        tester,
        const GlassSurface(blur: true, child: Text('fallback')),
        style: style,
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });
  }

  testWidgets('material preserves card activation and disabled semantics', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      Column(
        children: [
          CommonCard(onPressed: () => taps++, child: const Text('activate')),
          const CommonCard(child: Text('disabled')),
        ],
      ),
    );
    await tester.tap(find.text('activate'));
    await tester.tap(find.text('disabled'));
    expect(taps, 1);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('1000 dense node rows stay lazy, opaque and filter-free', (
    tester,
  ) async {
    var builds = 0;
    await pump(
      tester,
      ListView.builder(
        itemCount: 1000,
        itemExtent: 80,
        itemBuilder: (_, index) {
          builds++;
          return FluxoraProxyTile(name: 'Node $index', delay: 24, height: 80);
        },
      ),
    );
    expect(builds, lessThan(30));
    expect(find.byType(BackdropFilter), findsNothing);
    final context = tester.element(find.byType(OutlinedButton).first);
    final button = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton).first,
    );
    expect(
      button.style!.backgroundColor!.resolve({}),
      Theme.of(context).colorScheme.surfaceContainer,
    );
    expect(button.style!.backgroundColor!.resolve({})!.a, 1);
    await tester.fling(find.byType(ListView), const Offset(0, -2200), 3000);
    await tester.pumpAndSettle();
    expect(builds, lessThan(180));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'glass popup keeps keyboard activation and skips disabled items',
    (tester) async {
      var activated = false;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => Center(
                child: CommonPopupMenu(
                  items: [
                    const PopupMenuItemData(label: 'disabled', onPressed: null),
                    PopupMenuItemData(
                      label: 'enabled',
                      onPressed: () => activated = true,
                    ),
                  ],
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.getSize(find.byType(BackdropFilter)).height, lessThan(200));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(activated, isTrue);
      expect(find.byType(CommonPopupMenu), findsNothing);
    },
  );

  testWidgets('custom sheet background remains authoritative', (tester) async {
    await pump(
      tester,
      SideSheet(
        backgroundColor: Colors.transparent,
        onClosing: () {},
        builder: (_) => const Text('custom sheet'),
      ),
    );
    expect(find.byType(GlassSurface), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
