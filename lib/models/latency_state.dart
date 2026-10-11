import 'package:flutter/foundation.dart';

/// The semantic domain of a latency observation: does the value describe a
/// single **node**, or a whole **chain**?
///
/// P1.3-C3-B/C: `failover` compares candidates **within the same chain shape**
/// (the other hops are identical for every candidate of a role), so a
/// chain-total latency is a fair comparison there; the UI presents a **node**,
/// so it needs that node's own hop latency. Both are therefore stored
/// separately instead of overloading one field.
enum LatencyScope { node, chain }

/// Where a latency observation came from.
///
/// P1.3-C3-D (D-4): a **user-initiated** measurement is deliberately **not** a
/// member of this enum. It stays display-only (`AppState.delayMap`) and must
/// never enter the score — otherwise tapping "test" would reorder automatic
/// failover.
enum LatencySource { probe, failover }

/// A single latency observation (P1.3-C3-B / C3-C).
///
/// Deliberately **not** persisted: a latency is a transient observation of the
/// current network path, so storing it would present stale data as fresh (the
/// same reasoning G2 applied to capability evidence).
///
/// Deliberately **not** an accumulator: exponential decay / sample counting is
/// what `ChainReliabilityStats` is for. Here the freshness gate — not decay —
/// decides how much the value may still be trusted (see
/// `P1.3-C3-C_SCORE_FORMULA_DESIGN.md`).
@immutable
class LatencyState {
  /// Round-trip latency in milliseconds.
  final int latencyMs;

  /// Whether [latencyMs] describes a single node or a whole chain.
  final LatencyScope scope;

  /// Which producer observed it.
  final LatencySource source;

  /// When the observation was taken — the only input to the freshness gate.
  final DateTime testedAt;

  /// The network context this observation belongs to. A mismatch with the
  /// current fingerprint makes the value unusable (a Wi-Fi 80 ms reading must
  /// not be read as a 4G latency).
  final String fingerprint;

  const LatencyState({
    required this.latencyMs,
    required this.scope,
    required this.source,
    required this.testedAt,
    required this.fingerprint,
  });

  LatencyState copyWith({
    int? latencyMs,
    LatencyScope? scope,
    LatencySource? source,
    DateTime? testedAt,
    String? fingerprint,
  }) {
    return LatencyState(
      latencyMs: latencyMs ?? this.latencyMs,
      scope: scope ?? this.scope,
      source: source ?? this.source,
      testedAt: testedAt ?? this.testedAt,
      fingerprint: fingerprint ?? this.fingerprint,
    );
  }

  @override
  String toString() {
    return 'LatencyState(${latencyMs}ms, scope: ${scope.name}, '
        'source: ${source.name}, fingerprint: $fingerprint, testedAt: $testedAt)';
  }
}
