import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/tokens/fluxora_motion.dart';

/// Phase 05.5 — the motion contract itself.
///
/// Phase 04 fixed the token values and Phase 04.1–04.4 wired every overlay,
/// transition and micro-interaction to them. The risk this file guards is the one
/// the phase rules call out explicitly: "do not flatten every animation to zero
/// just to make reduced-motion tests pass". A token that quietly became
/// `Duration.zero`, or an `enterOffset` that stopped being 4 px, would make every
/// downstream reduce test keep passing while the normal-mode design disappeared.
void main() {
  test('durations are the Phase 04 scale, not zero', () {
    expect(FluxoraMotion.fast, const Duration(milliseconds: 120));
    expect(FluxoraMotion.base, const Duration(milliseconds: 200));
    expect(FluxoraMotion.slow, const Duration(milliseconds: 320));
    expect(
      FluxoraMotion.instant,
      Duration.zero,
      reason: 'the reduced-motion target stays available, but only explicitly',
    );
    for (final d in [FluxoraMotion.fast, FluxoraMotion.base, FluxoraMotion.slow]) {
      expect(d, greaterThan(Duration.zero));
    }
  });

  test('the curve roles keep their meaning', () {
    expect(FluxoraMotion.enter, Curves.easeOutCubic);
    expect(FluxoraMotion.exit, Curves.easeInCubic);
    expect(FluxoraMotion.standard, Curves.easeOutCubic);
    expect(FluxoraMotion.emphasis, Curves.easeInOutCubic);
    expect(
      FluxoraMotion.linear,
      Curves.linear,
      reason: 'the reduced-motion fallback curve',
    );
    // Enter decelerates and exit accelerates: swapping them is a real design
    // regression that no other test would notice.
    expect(FluxoraMotion.enter, isNot(FluxoraMotion.exit));
  });

  test('the enter/exit offsets stay at the §10.2 4 px lift', () {
    expect(FluxoraMotion.enterOffset, const Offset(0, 4));
    expect(FluxoraMotion.exitOffset, const Offset(0, -4));
  });

  test('the reduced-motion set resolves every role to its collapsed value', () {
    final reduced = FluxoraMotionSet.of(reduceMotion: true);
    final normal = FluxoraMotionSet.of(reduceMotion: false);

    expect(reduced.slow, Duration.zero);
    expect(reduced.base, Duration.zero);
    expect(reduced.fast, Duration.zero);
    expect(reduced.enterOffset, Offset.zero);
    expect(reduced.exitOffset, Offset.zero);

    // …and the normal set is untouched, which is what "reduced motion only"
    // means.
    expect(normal.slow, FluxoraMotion.slow);
    expect(normal.base, FluxoraMotion.base);
    expect(normal.fast, FluxoraMotion.fast);
    expect(normal.enterOffset, FluxoraMotion.enterOffset);
  });
}
