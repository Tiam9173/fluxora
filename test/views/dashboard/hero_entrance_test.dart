import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';

/// Two related items:
///
/// 1. the title-bar start switch now defaults on for Android **and** Android TV
///    (it used to be TV-only), so the rule is pinned across platforms;
/// 2. the dashboard Hero's one-shot entrance is built purely from
///    `FluxoraMotion` tokens and never scales its content (`D4_BRAND_PROPOSAL.md`
///    §10.4 / §10.5).
void main() {
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

    test('Android TV shows the switch even if the TV probe is still pending', () {
      System.platformOverride = 'android';
      addTearDown(() => System.platformOverride = null);

      // `_isAndroidTV` is resolved asynchronously, so `false` can simply mean
      // "not known yet" — `isAndroid` still has to carry it.
      expect(defaultShowStartSwitch(isAndroidTV: false), isTrue);
    });

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
    final src = File('lib/views/dashboard/widgets/start_button.dart')
        .readAsStringSync();
    final region = src.substring(
      src.indexOf('class _HeroEntrance extends StatefulWidget'),
      src.indexOf('class StartButton extends ConsumerStatefulWidget'),
    );

    test('uses FluxoraMotion tokens rather than inlined timings', () {
      expect(region.contains('FluxoraMotionSet.of('), isTrue);
      expect(region.contains('motion.base'), isTrue);
      expect(region.contains('motion.enterOffset'), isTrue);
      // No hand-written duration or offset may creep back in.
      expect(
        RegExp(r'Duration\(milliseconds:').hasMatch(region),
        isFalse,
        reason: 'the entrance must take its duration from FluxoraMotion',
      );
      expect(
        RegExp(r'Offset\(0, \d').hasMatch(region),
        isFalse,
        reason: 'the entrance must take its offset from FluxoraMotion',
      );
    });

    test('never scales or rotates the Hero (§10.4)', () {
      expect(region.contains('Transform.scale'), isFalse);
      expect(region.contains('AnimatedScale'), isFalse);
      expect(region.contains('Transform.rotate'), isFalse);
      // Only fade + translate.
      expect(region.contains('Opacity('), isTrue);
      expect(region.contains('Transform.translate('), isTrue);
    });

    test('collapses to a static card under reduced motion (§10.5)', () {
      expect(region.contains('disableAnimations'), isTrue);
      expect(region.contains('reduceMotion ? 1.0 : _controller.value'), isTrue);
    });
  });
}
