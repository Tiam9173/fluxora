import 'package:flutter/widgets.dart';

/// Fluxora motion tokens.
///
/// Source of truth: `D4_BRAND_PROPOSAL.md` §10.
///
/// Duration ladder (§10.1):
///
/// | token | duration | usage |
/// | --- | --- | --- |
/// | [fast] | 120 ms | micro-feedback: hover, ripple, toggle, icon swap |
/// | [base] | 200 ms | state change, fade, card expand |
/// | [slow] | 320 ms | page transition, panel slide-in, connection change |
///
/// Curves (§10.2): [standard] `easeOutCubic` is the default ("快出慢停, 符合
/// Flow"); [emphasis] `easeInOutCubic` for connection / node switches;
/// [enter] / [exit] add a small ±4 px vertical offset.
///
/// §10.4 forbids large scale changes (>1.1×), high-frequency flashing,
/// continuous rotation, large particle fields and decorative-only motion.
///
/// ── reduced-motion (§10.5, mandatory) ──────────────────────────────────────
///
/// This file defines the *design space* for reduced motion but never reads it
/// itself — the token layer takes no `BuildContext`. Instead, callers resolve a
/// [FluxoraMotionSet] from a plain `bool`:
///
/// ```dart
/// final reduce = MediaQuery.of(context).disableAnimations; // D4.9 wiring
/// final motion = FluxoraMotionSet.of(reduceMotion: reduce);
/// AnimatedContainer(duration: motion.base, ...);
/// ```
///
/// When reduced:
/// * one-shot durations collapse to [Duration.zero],
/// * [FluxoraMotionSet.enterOffset] / [exitOffset] collapse to [Offset.zero]
///   (no displacement or scale — §10.5),
/// * looping animations stop entirely ([FluxoraMotionSet.loopEnabled] is false),
///   so the connection indicator falls back to a static icon + text.
///
/// This is a **definition layer**: it declares values only. Applying motion to
/// widgets — including the 55 existing `AnimationController`s — is D4.9.
abstract final class FluxoraMotion {
  // ─────────────────────────────────────────────────────────────────────────
  // Durations (§10.1)
  // ─────────────────────────────────────────────────────────────────────────

  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);

  /// No animation — the reduced-motion target for one-shot transitions.
  static const instant = Duration.zero;

  // ─────────────────────────────────────────────────────────────────────────
  // Curves (§10.2)
  // ─────────────────────────────────────────────────────────────────────────

  /// Default curve for state colour / icon swaps.
  static const standard = Curves.easeOutCubic;

  /// Emphasis curve for connection establishment and node switching.
  static const emphasis = Curves.easeInOutCubic;

  /// Element entering.
  static const enter = Curves.easeOutCubic;

  /// Element leaving.
  static const exit = Curves.easeInCubic;

  /// Fallback curve under reduced motion.
  static const linear = Curves.linear;

  /// Vertical offset applied while an element enters (4 px up).
  static const enterOffset = Offset(0, 4);

  /// Vertical offset applied while an element leaves (4 px down).
  static const exitOffset = Offset(0, -4);

  // ─────────────────────────────────────────────────────────────────────────
  // Connection-state timings (§10.3 — "Flow" made literal)
  // ─────────────────────────────────────────────────────────────────────────

  /// Connected: the flow line drifts along its path, low amplitude, looping.
  static const connectedLoop = Duration(milliseconds: 2000);

  /// Connecting: two flow lines converge on the node, node pulses gently.
  static const connectingEnter = slow; // 320 ms
  static const connectingLoop = Duration(milliseconds: 800);

  /// Disconnected: flow lines freeze, node becomes hollow.
  static const disconnectedSwitch = fast; // 120 ms

  // ─────────────────────────────────────────────────────────────────────────
  // Pure resolvers (usable without a BuildContext)
  // ─────────────────────────────────────────────────────────────────────────

  /// Collapses a duration to zero under reduced motion.
  static Duration resolveDuration(Duration duration, {required bool reduceMotion}) =>
      reduceMotion ? Duration.zero : duration;

  /// Swaps a curve for [linear] under reduced motion.
  static Curve resolveCurve(Curve curve, {required bool reduceMotion}) =>
      reduceMotion ? Curves.linear : curve;

  /// Removes displacement under reduced motion.
  static Offset resolveOffset(Offset offset, {required bool reduceMotion}) =>
      reduceMotion ? Offset.zero : offset;

  /// Resolved set for a given preference — the ergonomic entry point.
  static FluxoraMotionSet of({required bool reduceMotion}) =>
      FluxoraMotionSet.of(reduceMotion: reduceMotion);
}

/// Motion tokens resolved for one reduced-motion preference.
///
/// [full] is the standard experience; [reduced] collapses every one-shot
/// duration and offset to zero and disables looping. Construct via
/// [FluxoraMotionSet.of] from `MediaQuery.disableAnimations` at the call site.
@immutable
class FluxoraMotionSet {
  /// Whether the OS-level "reduce motion" accessibility setting is on.
  final bool reduceMotion;

  const FluxoraMotionSet({required this.reduceMotion});

  /// Standard motion.
  static const full = FluxoraMotionSet(reduceMotion: false);

  /// Reduced motion (§10.5).
  static const reduced = FluxoraMotionSet(reduceMotion: true);

  static FluxoraMotionSet of({required bool reduceMotion}) =>
      reduceMotion ? reduced : full;

  // ── Durations ────────────────────────────────────────────────────────────

  Duration get fast => reduceMotion ? Duration.zero : FluxoraMotion.fast;
  Duration get base => reduceMotion ? Duration.zero : FluxoraMotion.base;
  Duration get slow => reduceMotion ? Duration.zero : FluxoraMotion.slow;

  // ── Curves ───────────────────────────────────────────────────────────────

  Curve get standard => reduceMotion ? Curves.linear : FluxoraMotion.standard;
  Curve get emphasis => reduceMotion ? Curves.linear : FluxoraMotion.emphasis;
  Curve get enter => reduceMotion ? Curves.linear : FluxoraMotion.enter;
  Curve get exit => reduceMotion ? Curves.linear : FluxoraMotion.exit;

  // ── Enter / exit displacement ────────────────────────────────────────────

  Offset get enterOffset =>
      reduceMotion ? Offset.zero : FluxoraMotion.enterOffset;
  Offset get exitOffset =>
      reduceMotion ? Offset.zero : FluxoraMotion.exitOffset;

  // ── Looping animations ───────────────────────────────────────────────────

  /// False under reduced motion — looping animations must stop entirely (§10.5).
  bool get loopEnabled => !reduceMotion;

  /// Duration of one connected-state flow cycle. Meaningful only when
  /// [loopEnabled] is true.
  Duration get connectedLoop => FluxoraMotion.connectedLoop;

  /// Duration of one connecting-state pulse cycle. Meaningful only when
  /// [loopEnabled] is true.
  Duration get connectingLoop => FluxoraMotion.connectingLoop;

  /// Transition when moving into the connecting state.
  Duration get connectingEnter =>
      reduceMotion ? Duration.zero : FluxoraMotion.connectingEnter;

  /// Transition when moving into the disconnected state.
  Duration get disconnectedSwitch =>
      reduceMotion ? Duration.zero : FluxoraMotion.disconnectedSwitch;
}
