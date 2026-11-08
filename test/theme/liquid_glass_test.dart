import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/widgets/glass_surface.dart';
import 'package:fluxora/widgets/liquid_backdrop.dart';
import '../support/render_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('light floating glass keeps a white canvas clear', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [
            FluxoraMaterial(style: FluxoraSurfaceStyle.liquid),
          ],
        ),
        home: const RepaintBoundary(
          key: ValueKey('white-lens'),
          child: ColoredBox(
            color: Colors.white,
            child: Center(
              child: GlassSurface(
                floating: true,
                blur: true,
                child: SizedBox(width: 280, height: 74),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('white-lens')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final pixels = (await image.toByteData())!;
        final centre =
            (image.width * (image.height ~/ 2) + image.width ~/ 2) * 4;
        for (var channel = 0; channel < 3; channel++) {
          expect(
            pixels.getUint8(centre + channel),
            greaterThanOrEqualTo(235),
            reason: 'The floating shadow must not dirty the transparent centre',
          );
        }
      } finally {
        image.dispose();
      }
    });
  });
  test('clarity persists independently and older settings remain readable', () {
    const props = ThemeProps(
      surfaceStyle: FluxoraSurfaceStyle.liquid,
      glassIntensity: .4,
      glassClarity: .9,
    );
    expect(ThemeProps.fromJson(jsonDecode(jsonEncode(props))), props);
    expect(ThemeProps.fromJson({}).glassClarity, .5);
    expect(const FluxoraMaterial(glassClarity: double.nan).clarity, .5);
    expect(props.copyWith(glassClarity: .7).glassIntensity, .4);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'live glass stays bounded, interactive and reversible, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(360, 220);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var taps = 0;
        Widget scene(double strength, {bool reduced = false}) => MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            extensions: [
              FluxoraMaterial(
                style: reduced
                    ? FluxoraSurfaceStyle.reduced
                    : FluxoraSurfaceStyle.liquid,
                glassIntensity: strength,
              ),
            ],
          ),
          home: Center(
            child: RepaintBoundary(
              key: const ValueKey('scene'),
              child: SizedBox(
                width: 360,
                height: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (var index = 0; index < 30; index++)
                      Positioned(
                        left: index * 12,
                        top: 0,
                        bottom: 0,
                        width: 12,
                        child: ColoredBox(
                          color: index.isEven
                              ? const Color(0xFF4771B8)
                              : const Color(0xFF794BB8),
                        ),
                      ),
                    Center(
                      child: GlassSurface(
                        radius: 30,
                        floating: true,
                        blur: true,
                        child: SizedBox(
                          width: 280,
                          height: 74,
                          child: TextButton(
                            onPressed: () => taps++,
                            child: const Text('Select'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(scene(0));
        await tester.pumpAndSettle();
        expect(find.byType(LiquidBackdrop), findsOneWidget);
        final filter = tester.allRenderObjects
            .whereType<RenderBackdropFilter>()
            .single;
        expect(filter.size, const Size(280, 74));
        final initialFilter = filter.filterConfig.filter;
        final backend = LiquidBackdrop.supportsRefraction
            ? 'impeller'
            : 'compatible';
        await captureFlutterFrame(
          tester,
          find.byKey(const ValueKey('scene')),
          'build/liquid_glass/captures/strength-0-${dark ? 'dark' : 'light'}-$backend.png',
        );
        await tester.pumpWidget(scene(1));
        await tester.pumpAndSettle();
        expect(filter.filterConfig.filter, isNot(initialFilter));
        await captureFlutterFrame(
          tester,
          find.byKey(const ValueKey('scene')),
          'build/liquid_glass/captures/strength-1-${dark ? 'dark' : 'light'}-$backend.png',
        );
        final press = await tester.startGesture(
          tester.getCenter(find.text('Select')),
        );
        await tester.pump(const Duration(milliseconds: 90));
        await press.up();
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(
          tester.hasRunningAnimations,
          isFalse,
          reason: 'glass is idle after interaction',
        );
        await tester.pumpWidget(scene(1, reduced: true));
        await tester.pumpAndSettle();
        expect(find.byType(LiquidBackdrop), findsNothing);
        expect(
          tester.allRenderObjects.whereType<RenderBackdropFilter>(),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('shader bends actual image samples at its curved rim', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
      final inputRecorder = ui.PictureRecorder();
      final canvas = Canvas(inputRecorder);
      for (var x = 0; x < 240; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), 0, 1, 200),
          Paint()
            ..color = x % 16 < 8
                ? const Color(0xFF133979)
                : const Color(0xFF391B73),
        );
      }
      final inputPicture = inputRecorder.endRecording();
      final input = await inputPicture.toImage(240, 200);
      inputPicture.dispose();
      Future<ui.Image> render(double strength, {bool dark = true}) async {
        final shader = program.fragmentShader()
          ..setFloat(0, 240)
          ..setFloat(1, 200)
          ..setFloat(2, 240)
          ..setFloat(3, 100)
          ..setFloat(4, 40)
          ..setFloat(5, strength)
          ..setFloat(6, dark ? 1 : 0)
          ..setFloat(7, .1)
          ..setFloat(8, .1)
          ..setFloat(9, .15)
          ..setFloat(10, .5)
          ..setImageSampler(0, input);
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 240, 200),
          Paint()..shader = shader,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(240, 200);
        picture.dispose();
        shader.dispose();
        return image;
      }

      final before = await render(0),
          after = await render(1),
          light = await render(1, dark: false);
      final a = (await before.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final b = (await after.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var changed = 0;
      for (var y = 60; y < 140; y++) {
        for (var x = 10; x < 230; x++) {
          final offset = (y * 240 + x) * 4;
          if ((a.getUint8(offset) - b.getUint8(offset)).abs() > 5) changed++;
        }
      }
      expect(
        changed,
        greaterThan(1000),
        reason:
            'strength changes sampled background, not just a decorative border',
      );
      final lightData = (await light.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final center = (100 * 240 + 120) * 4;
      expect(lightData.getUint8(center), greaterThan(200));
      before.dispose();
      after.dispose();
      light.dispose();
      input.dispose();
    });
  });
}
