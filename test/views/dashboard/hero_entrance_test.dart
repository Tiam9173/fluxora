import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/dashboard/widgets/start_button.dart';
import 'package:fluxora/widgets/fluxora/fluxora.dart';

/// Two related items:
///
/// 1. the title-bar start switch now defaults on for Android **and** Android TV
///    (it used to be TV-only), so the rule is pinned across platforms;
/// 2. the dashboard Hero's one-shot entrance is built purely from
///    `FluxoraMotion` tokens and never scales its content (`D4_BRAND_PROPOSAL.md`
///    §10.4 / §10.5).
///
/// Item 2 is asserted **behaviourally**: the entrance renders an `Opacity` and a
/// `Transform.translate` around the card, so the tests read those two widgets
/// out of the live tree instead of scraping the source text. `_HeroEntrance` is
/// library-private, so [StartButton] is the entry point; its four providers are
/// overridden to keep the pumped tree small.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  setUp(() {
    globalState.appState = AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
  });

  Widget seedGlobals(Widget child) {
    return Builder(
      builder: (ctx) {
        globalState.theme = CommonTheme.of(ctx, 1.0);
        globalState.measure = Measure.of(ctx, 1.0);
        return child;
      },
    );
  }

  Future<void> pumpHero(
    WidgetTester tester, {
    required bool reduce,
    bool lowEffects = false,
  }) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduce);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(
      ProviderScope(
        // riverpod 3.4.2 does not export `Override`, so the list has to be
        // inlined. Only the two providers that would otherwise read live
        // app state are pinned; `runTime` / `isSmartStopped` resolve from the
        // seeded `globalState.appState` the way they do in production.
        overrides: [
          startButtonSelectorStateProvider.overrideWith(
            (ref) =>
                const StartButtonSelectorState(isInit: true, hasProfile: true),
          ),
          isRestartingCoreProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          theme: ThemeData(
            extensions: [
              FluxoraMaterial(
                style: lowEffects
                    ? FluxoraSurfaceStyle.reduced
                    : FluxoraSurfaceStyle.classic,
              ),
            ],
          ),
          home: Scaffold(
            body: seedGlobals(
              const Center(child: SizedBox(width: 320, child: StartButton())),
            ),
          ),
        ),
      ),
    );
  }

  /// The entrance's two visible outputs, read off the widgets that actually
  /// paint them: the fade opacity and the vertical lift in logical pixels.
  ({double opacity, double dy, double scaleX, double scaleY}) heroEntrance(
    WidgetTester tester,
  ) {
    final card = find.byType(FluxoraCard);

    final opacity = tester
        .widget<Opacity>(
          find.ancestor(of: card, matching: find.byType(Opacity)).first,
        )
        .opacity;

    final matrix = tester
        .widget<Transform>(
          find.ancestor(of: card, matching: find.byType(Transform)).first,
        )
        .transform;

    return (
      opacity: opacity,
      dy: matrix.storage[13],
      scaleX: matrix.storage[0],
      scaleY: matrix.storage[5],
    );
  }

  group('defaultShowStartSwitch', () {
    test('Android shows the switch, TV or not', () {
      System.platformOverride = 'android';
      addTearDown(() => System.platformOverride = null);

      expect(defaultShowStartSwitch(isAndroidTV: true), isTrue);
      expect(
        defaultShowStartSwitch(isAndroidTV: false),
        isTrue,
        reason: 'a phone must show the switch too',
      );
    });

    test(
      'Android TV shows the switch even if the TV probe is still pending',
      () {
        System.platformOverride = 'android';
        addTearDown(() => System.platformOverride = null);

        // `_isAndroidTV` is resolved asynchronously, so `false` can simply mean
        // "not known yet" — `isAndroid` still has to carry it.
        expect(defaultShowStartSwitch(isAndroidTV: false), isTrue);
      },
    );

    test('desktop keeps the switch off', () {
      for (final platform in const ['windows', 'macos', 'linux']) {
        System.platformOverride = platform;
        addTearDown(() => System.platformOverride = null);
        expect(
          defaultShowStartSwitch(isAndroidTV: false),
          isFalse,
          reason: '$platform must not show the title-bar switch by default',
        );
      }
    });

    test('an Android TV that is not Android still shows it', () {
      // Defensive: if a future TV build is not `isAndroid`, the explicit TV flag
      // must keep the switch visible.
      System.platformOverride = 'linux';
      addTearDown(() => System.platformOverride = null);
      expect(defaultShowStartSwitch(isAndroidTV: true), isTrue);
    });
  });

  // §10.4 forbids scale changes over 1.1×, high-frequency flashing and
  // continuous rotation; §10.5 requires the reduced-motion path to remove the
  // motion entirely rather than speed it up.
  group('Hero entrance honours the motion tokens', () {
    testWidgets('low-effects material shows the card at rest immediately', (
      tester,
    ) async {
      await pumpHero(tester, reduce: false, lowEffects: true);
      final entrance = heroEntrance(tester);
      expect(entrance.opacity, 1.0);
      expect(entrance.dy, 0.0);
    });

    testWidgets('reduced motion shows the card at rest on the first frame', (
      tester,
    ) async {
      await pumpHero(tester, reduce: true);

      final entrance = heroEntrance(tester);
      expect(entrance.opacity, 1.0, reason: 'no fade-in may run');
      expect(entrance.dy, 0.0, reason: 'no lift may run');
    });

    testWidgets('without reduced motion the card fades and lifts in', (
      tester,
    ) async {
      await pumpHero(tester, reduce: false);

      final start = heroEntrance(tester);
      expect(
        start.opacity,
        0.0,
        reason: 'the entrance starts fully transparent',
      );
      expect(
        start.dy,
        FluxoraMotion.enterOffset.dy,
        reason: 'the entrance starts at the token offset',
      );

      await tester.pumpAndSettle();

      final settled = heroEntrance(tester);
      expect(settled.opacity, 1.0);
      expect(settled.dy, 0.0);
    });

    testWidgets('never scales the Hero (§10.4)', (tester) async {
      await pumpHero(tester, reduce: false);

      // Mid-entrance, so a scale animation would have left the identity matrix.
      await tester.pump(const Duration(milliseconds: 80));

      final entrance = heroEntrance(tester);
      expect(entrance.scaleX, 1.0);
      expect(entrance.scaleY, 1.0);
    });
  });
}
