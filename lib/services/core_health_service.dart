import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fluxora/clash/service.dart';
import 'package:fluxora/state.dart';

/// P2.4-E (CF-5) — the real Core health state.
///
/// Replaces "is `appState.runTime != null`" as the definition of "the core is
/// running": that is *local* bookkeeping and cannot tell a healthy core from a
/// killed one, an unreachable API or a core that is still starting.
enum CoreHealthState {
  /// A stop/shutdown was performed (or the core is confirmed not running).
  stopped,

  /// A start was initiated but the core is not ready yet.
  starting,

  /// The core API is reachable and reports a healthy/initialised state.
  running,

  /// The core is expected to be up, but its API did not answer within the
  /// bounded timeout. (A timeout is **not** evidence of a crash.)
  unreachable,

  /// Reliable determination is impossible (no primitive on this platform).
  unknown,
}

/// Result of one core-health determination.
@immutable
class CoreHealthResult {
  final CoreHealthState state;
  final DateTime checkedAt;
  final int? latencyMs;
  final String? error;

  const CoreHealthResult({
    required this.state,
    required this.checkedAt,
    this.latencyMs,
    this.error,
  });

  factory CoreHealthResult.of(
    CoreHealthState state, {
    int? latencyMs,
    String? error,
  }) => CoreHealthResult(
    state: state,
    checkedAt: DateTime.now(),
    latencyMs: latencyMs,
    error: error,
  );

  bool get isRunning => state == CoreHealthState.running;

  @override
  String toString() => 'CoreHealthResult($state, ${latencyMs}ms'
      '${error == null ? '' : ', error: $error'})';
}

/// P2.4-E (CF-5) — determines whether the Mihomo core is actually healthy.
///
/// Read-only and bounded: it never starts, stops or reconfigures the core, and
/// it never touches the chain config, fallback pool, reliability stats, system
/// proxy or adaptive ranking. Concurrent callers share one in-flight probe
/// (single-flight).
///
/// P2.8-C: the determination is **returned to the caller only** — there is no
/// cached "last result" to read. Every real consumer (`ChainProxyManager
/// ._isCoreReady()`) awaits [check()] and uses that value, so a cached result
/// could only ever be read as *stale* runtime truth.
class CoreHealthService {
  CoreHealthService._();

  static final CoreHealthService instance = CoreHealthService._();

  /// Bounded probe timeout.
  static const Duration probeTimeout = Duration(seconds: 2);

  /// Test-only seam replacing the underlying core probe. Production never sets
  /// it — the default path always uses the real `clashService`.
  @visibleForTesting
  static Future<bool> Function(Duration timeout)? coreProbeOverride;

  /// Test-only seam pinning "this platform has no desktop core service".
  @visibleForTesting
  static bool? desktopOverride;

  Future<CoreHealthResult>? _inFlight;

  /// Single-flight health determination.
  Future<CoreHealthResult> check() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _determine();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<CoreHealthResult> _determine() async {
    final probe = coreProbeOverride;
    final isDesktop = desktopOverride ?? (clashService != null);
    if (!isDesktop) {
      // No desktop core service on this platform (e.g. Android, where the
      // existing VPN-status path in `_syncVpnState` stays authoritative).
      return CoreHealthResult.of(CoreHealthState.unknown);
    }

    // The global `clashService` is a lazily-constructed singleton; touching it
    // eagerly would construct (and start) the real core. It is therefore only
    // consulted when it is the actual source of truth — an injected probe
    // replaces it entirely and must not construct it.
    if (probe == null) {
      final service = clashService;
      // A start in progress is an explicit lifecycle signal.
      if (service != null && service.isStarting) {
        return CoreHealthResult.of(CoreHealthState.starting);
      }
    }

    final sw = Stopwatch()..start();
    try {
      final healthy = probe != null
          ? await probe(probeTimeout)
          : await clashService!.checkCoreHealth(timeout: probeTimeout);
      sw.stop();
      return CoreHealthResult.of(
        healthy ? CoreHealthState.running : _nonHealthyState(),
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      // A probe failure/timeout is *unreachable*, never "crashed" and never
      // "running".
      return CoreHealthResult.of(
        _nonHealthyState(),
        latencyMs: sw.elapsedMilliseconds,
        error: '$e',
      );
    }
  }

  /// Chooses between [CoreHealthState.stopped] and
  /// [CoreHealthState.unreachable] for a failed probe.
  ///
  /// Local state is used **only** to disambiguate between two non-running
  /// states — it can never produce `running`, and it never produces `unknown`
  /// (that is reserved for a platform with no desktop core service at all).
  CoreHealthState _nonHealthyState() {
    bool localRunning;
    try {
      localRunning = globalState.appState.runTime != null;
    } catch (_) {
      // The local bookkeeping is unavailable (e.g. the app is not booted).
      // There is no local "running" claim, so the honest answer is STOPPED.
      return CoreHealthState.stopped;
    }
    return localRunning
        ? CoreHealthState.unreachable
        : CoreHealthState.stopped;
  }
}
