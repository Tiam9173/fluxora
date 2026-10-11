import 'latency_state.dart';

/// P1.3-C4-Step4 — how much a stored latency observation may still be trusted.
///
/// The gate is deliberately **time + context** based only (P1.3-C3-C): a value
/// that is old, or that was measured on a different network path, must not keep
/// silently steering the score.
///
/// Frozen constants:
///   D-1  trusted ≤ 5 min ｜ degraded 5–30 min ｜ unknown > 30 min / mismatch / missing
///   D-3  degraded converges toward the neutral score by half
///   F-2  unknown ⇒ 50.0
///
/// Pure: no I/O, no state, no persistence, no UI. All three helpers are directly
/// unit-testable.
enum LatencyFreshness {
  /// Fresh enough to be used at face value.
  trusted,

  /// Still directionally useful, but half-converged toward neutral.
  degraded,

  /// Not usable: contributes the neutral score only.
  unknown;

  /// D-1: at most this old ⇒ [trusted].
  static const Duration trustedMaxAge = Duration(minutes: 5);

  /// D-1: at most this old ⇒ [degraded]; beyond it ⇒ [unknown].
  static const Duration degradedMaxAge = Duration(minutes: 30);

  /// F-2: the score a latency contributes when it cannot be trusted.
  static const double neutralScore = 50.0;

  /// D-3: how much of the distance from neutral survives when degraded.
  static const double degradedRetention = 0.5;

  /// Evaluates [state] against [now] and [currentFingerprint].
  ///
  /// A `null` state, a fingerprint mismatch, or an age beyond [degradedMaxAge]
  /// all yield [unknown]. An age that is **negative** (clock skew / a future
  /// timestamp) satisfies `age <= trustedMaxAge` and is therefore treated as
  /// [trusted] — no extra branch, no crash.
  ///
  /// [expectedScope] (P1.3-C4-Step5) is an **optional** guard: the gate itself is
  /// scope-agnostic (it only reads `testedAt` / `fingerprint`), and both
  /// `nodeLatency` and `chainLatency` are `LatencyState?` — so passing the wrong
  /// one would otherwise compile silently and read a chain total as a node value.
  /// When supplied, a scope mismatch yields [unknown]. Defaults to `null`, which
  /// keeps the pre-Step5 behaviour byte-for-byte.
  static LatencyFreshness evaluate({
    required LatencyState? state,
    required DateTime now,
    required String currentFingerprint,
    LatencyScope? expectedScope,
  }) {
    if (state == null) return LatencyFreshness.unknown;
    if (expectedScope != null && state.scope != expectedScope) {
      return LatencyFreshness.unknown;
    }
    if (state.fingerprint != currentFingerprint) {
      return LatencyFreshness.unknown;
    }
    final age = now.difference(state.testedAt);
    if (age <= trustedMaxAge) return LatencyFreshness.trusted;
    if (age <= degradedMaxAge) return LatencyFreshness.degraded;
    return LatencyFreshness.unknown;
  }

  /// The UI-facing **node** latency (P1.3-C4-Step5, decision Q3).
  ///
  /// A `trusted` **or** `degraded` observation is shown at its **raw** value —
  /// [degrade]'s down-weighting applies to *scoring* only, never to the number
  /// the user reads. Anything unusable (missing / stale / foreign network /
  /// unexpected scope) returns `null` so the UI reports "unknown" instead of
  /// fabricating one.
  ///
  /// Deliberately does **not** fall back to `chainLatency`: a chain total is a
  /// different measurement (and, per `chain_probe_service.dart:979`, actually the
  /// *last hop's* latency), so back-filling it here would mislabel another node's
  /// value as this node's.
  static int? visibleLatencyMs({
    required LatencyState? state,
    required DateTime now,
    required String currentFingerprint,
    LatencyScope? expectedScope,
  }) {
    final freshness = evaluate(
      state: state,
      now: now,
      currentFingerprint: currentFingerprint,
      expectedScope: expectedScope,
    );
    return freshness == LatencyFreshness.unknown ? null : state!.latencyMs;
  }

  /// The **unchanged** legacy formula (previously inlined in
  /// `chain_adaptive_score_service.dart`), extracted so the β compat path and the
  /// gated path provably share one implementation.
  ///
  /// Callers must reject negative values before calling this — see the guard in
  /// `ChainAdaptiveScoreService.calculateNodeScore`.
  static double rawScore(int latencyMs) =>
      (100.0 - (latencyMs / 10.0)).clamp(0.0, 100.0);

  /// D-3: `50 + (raw − 50) × 0.5`.
  static double degrade(double raw) =>
      neutralScore + (raw - neutralScore) * degradedRetention;
}
