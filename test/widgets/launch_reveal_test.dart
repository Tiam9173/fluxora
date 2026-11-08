import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/widgets/fluxora/fluxora_launch_reveal.dart';
import '../support/render_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('HarmonyOS_Sans')..addFont(
          rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'),
        ))
        .load();
  });
  for (final dark in [false, true]) {
    testWidgets(
      'brand reveal keeps the app mounted and tapping safely skips it, dark=$dark',
      (tester) async {
        var taps = 0;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final appKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              fontFamily: 'HarmonyOS_Sans',
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: RepaintBoundary(
              key: const ValueKey('launch-capture'),
              child: FluxoraLaunchReveal(
                child: Scaffold(
                  key: appKey,
                  body: Center(
                    child: TextButton(
                      onPressed: () => taps++,
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final state = appKey.currentState;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(
          taps,
          0,
          reason: 'covered controls must not receive keyboard input',
        );
        await tester.pump(const Duration(milliseconds: 440));
        if (const bool.fromEnvironment('MOTION_CAPTURE')) {
          await captureFlutterFrame(
            tester,
            find.byKey(const ValueKey('launch-capture')),
            'build/ux_feedback_v3/captures/launch-${dark ? 'dark' : 'light'}.png',
          );
        }
        await tester.tapAt(tester.getCenter(find.text('Open')));
        await tester.pumpAndSettle();
        expect(taps, 0);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(appKey.currentState, same(state));
        expect(find.byType(FluxoraLaunchScene), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('disabled launch and motion-off show the app immediately', (
    tester,
  ) async {
    for (final enabled in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [
              FluxoraMaterial(motionStyle: FluxoraMotionStyle.off),
            ],
          ),
          home: FluxoraLaunchReveal(
            enabled: enabled,
            child: const Text('Ready'),
          ),
        ),
      );
      expect(find.byType(FluxoraLaunchScene), findsNothing);
      expect(find.text('Ready'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    }
  });

  test('motion preferences round trip and intensity is bounded', () {
    const props = ThemeProps(
      motionStyle: FluxoraMotionStyle.depth,
      motionIntensity: .9,
      launchAnimation: false,
    );
    expect(ThemeProps.fromJson(jsonDecode(jsonEncode(props))), props);
    expect(const FluxoraMaterial(motionIntensity: double.nan).motionAmount, .5);
    expect(const FluxoraMaterial(motionIntensity: 3).motionAmount, 1);
    expect(
      const FluxoraMotionSet(reduceMotion: false, intensity: 1).base,
      greaterThan(
        const FluxoraMotionSet(reduceMotion: false, intensity: 0).base,
      ),
    );
  });
}
