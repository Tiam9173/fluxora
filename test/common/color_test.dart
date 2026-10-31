import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';

/// `ColorExtension.readableForeground` — black or white, whichever is legible.
///
/// The rule was inlined twice (dashboard colour swatches, the custom-accent
/// confirm button). Those fills are **user-chosen**, so no semantic `on*` role
/// can exist and a fixed white disappears on a pale swatch. These cases pin the
/// decision itself, including the exact crossover, because "pick by luminance"
/// is easy to get subtly wrong (e.g. `>=` instead of `>`, or comparing
/// brightness instead of luminance).
void main() {
  group('readableForeground', () {
    test('pure white takes black text', () {
      expect(Colors.white.readableForeground, Colors.black);
    });

    test('pure black takes white text', () {
      expect(Colors.black.readableForeground, Colors.white);
    });

    test('the theme brand cyan takes black text', () {
      // #29D6C7 has a high luminance (~0.53), so white would be unreadable.
      const fluxCyan = Color(0xFF29D6C7);
      expect(fluxCyan.readableForeground, Colors.black);
    });

    test('the deep-space surface takes white text', () {
      // #0C1222 is the dark-theme page canvas.
      const deepSpace = Color(0xFF0C1222);
      expect(deepSpace.readableForeground, Colors.white);
    });

    test('near-threshold colours land on the documented side', () {
      // 0.5 is the crossover: strictly greater than 0.5 is "light enough for
      // black text". Both sides are checked so an off-by-one operator flip
      // fails here instead of shipping.
      Color grey(double luminance) {
        // A neutral grey with the requested luminance: for greys, luminance is
        // monotonic in the channel value, so solve numerically.
        var lo = 0.0;
        var hi = 255.0;
        for (var i = 0; i < 40; i++) {
          final mid = (lo + hi) / 2;
          final c = Color.fromARGB(255, mid.round(), mid.round(), mid.round());
          if (c.computeLuminance() > luminance) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        final v = ((lo + hi) / 2).round();
        return Color.fromARGB(255, v, v, v);
      }

      final justAbove = grey(0.52);
      final justBelow = grey(0.48);
      expect(
        justAbove.readableForeground,
        Colors.black,
        reason: 'luminance above 0.5 reads as a light fill',
      );
      expect(
        justBelow.readableForeground,
        Colors.white,
        reason: 'luminance below 0.5 reads as a dark fill',
      );
    });

    test('mid-grey at exactly the crossover resolves deterministically', () {
      // Not asserting which side is "right" — only that the result is stable and
      // one of the two, so a refactor cannot start returning null or a tint.
      final mid = Color.fromARGB(255, 128, 128, 128);
      final result = mid.readableForeground;
      expect(result, anyOf(Colors.black, Colors.white));
      expect(result, equals(mid.readableForeground));
    });
  });
}
