import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

abstract class INetworkFingerprintProvider {
  String getCurrentFingerprint();
}

/// P1.3 — real network-context fingerprint.
///
/// Deliberately simple (per the P1.3 spec): it maps the **transport type**
/// reported by `connectivity_plus` to a stable string so that
///
///   * the same network environment → the **same** fingerprint (stable), and
///   * a real transport change (wifi ↔ cellular ↔ ethernet ↔ vpn) → a
///     **different** fingerprint, so reliability samples land in a new
///     `statsByContext` entry.
///
/// It is explicitly NOT a network-profiling system: no SSID database, no
/// geo-IP lookup, no carrier profiling.
class NetworkFingerprintProvider implements INetworkFingerprintProvider {
  static const String wifi = 'wifi_default';
  static const String ethernet = 'ethernet_default';
  static const String cellular = 'cellular_default';
  static const String vpn = 'vpn_default';
  static const String bluetooth = 'bluetooth_default';
  static const String unknown = 'unknown_default';

  String _current = unknown;
  bool _mockLocked = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// RC.11-A (F-AR4): invoked whenever the fingerprint **actually changes**
  /// (never for a repeat of the same value).
  ///
  /// This provider exposes no notifier of its own, and the adaptive ranking
  /// provider reads the fingerprint imperatively — so a transport change
  /// (wifi ↔ cellular ↔ ethernet) used to leave the node picker showing the
  /// **previous** network's ranking until some unrelated notification happened
  /// to arrive. `ChainProxyManager` subscribes here and routes the change
  /// through its own `notifyListeners()`, which bumps `stateVersion` — a
  /// component of the ranking `stateFingerprint` — so the cache misses and the
  /// list re-ranks against the new network context.
  void Function(String fingerprint)? onChanged;

  /// Test-only: pins the fingerprint so tests stay deterministic. Once called,
  /// real connectivity updates are ignored.
  void setMockFingerprint(String fingerprint) {
    _mockLocked = true;
    _setCurrent(fingerprint);
  }

  /// The single mutation point: assign, then notify — but only on a real
  /// change, so a repeated report of the same transport is a no-op.
  void _setCurrent(String next) {
    if (next == _current) return;
    _current = next;
    onChanged?.call(next);
  }

  /// Starts observing real connectivity. Idempotent; safe to call at app start.
  /// While a mock fingerprint is pinned, real updates are ignored.
  void start() {
    if (_subscription != null || _mockLocked) return;
    try {
      _subscription = Connectivity().onConnectivityChanged.listen(
        _apply,
        onError: (_) {},
      );
      unawaited(_primeOnce());
    } catch (_) {
      // Connectivity unavailable (unsupported platform) → stay `unknown`.
    }
  }

  void stop() {
    final sub = _subscription;
    _subscription = null;
    if (sub != null) {
      // An EventChannel cancel can complete with an error when the plugin is
      // unavailable; swallow it so teardown never produces an unhandled async
      // error.
      unawaited(sub.cancel().catchError((_) {}));
    }
  }

  /// P2.2: whether a connectivity subscription is currently active. Lets the
  /// lifecycle test assert "no duplicate subscription" / "stopped" without
  /// reaching into private state.
  bool get isStarted => _subscription != null;

  Future<void> _primeOnce() async {
    try {
      _apply(await Connectivity().checkConnectivity());
    } catch (_) {
      // Ignore — keep the current fingerprint.
    }
  }

  void _apply(List<ConnectivityResult> results) {
    if (_mockLocked) return;
    _setCurrent(fingerprintFor(results));
  }

  /// Pure, order-independent mapping from a connectivity snapshot to a stable
  /// fingerprint. Prefers the most specific transport so the result does not
  /// depend on the order `connectivity_plus` reports.
  static String fingerprintFor(List<ConnectivityResult> results) {
    if (results.isEmpty) return unknown;
    if (results.contains(ConnectivityResult.ethernet)) return ethernet;
    if (results.contains(ConnectivityResult.wifi)) return wifi;
    if (results.contains(ConnectivityResult.mobile)) return cellular;
    if (results.contains(ConnectivityResult.vpn)) return vpn;
    if (results.contains(ConnectivityResult.bluetooth)) return bluetooth;
    return unknown;
  }

  @override
  String getCurrentFingerprint() => _current;
}

// Global instance for simple DI
final networkFingerprintProvider = NetworkFingerprintProvider();
