import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fluxora/common/identity.dart';

/// P2.6-F — the OS's **actual** TUN state.
///
/// Deliberately separate from Fluxora's *desired* state
/// (`patchClashConfigProvider.tun.enable`) and from the crash-recovery marker
/// (`prefs['is_tun_running']`): the readback only ever reports what the
/// operating system currently has, never what Fluxora asked for. When the OS
/// state cannot be determined the answer is [unknown] — never a guess.
enum TunActualState { enabled, disabled, unknown }

/// Result of one TUN readback.
@immutable
class TunReadback {
  final TunActualState actualState;
  final String platform;
  final DateTime checkedAt;

  /// The OS interface name the observation was based on (`null` when the
  /// interface was not present).
  final String? interfaceName;

  /// Non-null only when the readback itself failed or could not be attributed
  /// (⇒ [actualState] is [TunActualState.unknown]).
  final String? error;

  /// True when this platform has no desktop-TUN concept here (Android — it
  /// reports its real state through the `VpnService` status instead).
  final bool unsupported;

  const TunReadback({
    required this.actualState,
    required this.platform,
    required this.checkedAt,
    this.interfaceName,
    this.error,
    this.unsupported = false,
  });

  factory TunReadback.unknown(
    String platform, {
    String? error,
    bool unsupported = false,
    String? interfaceName,
  }) => TunReadback(
    actualState: TunActualState.unknown,
    platform: platform,
    checkedAt: DateTime.now(),
    interfaceName: interfaceName,
    error: error,
    unsupported: unsupported,
  );

  /// Whether the observed OS state agrees with [desiredEnabled].
  ///
  /// An [TunActualState.unknown] result can never be "in sync" — it is unknown,
  /// not matching.
  bool matchesDesired({required bool desiredEnabled}) {
    if (actualState == TunActualState.unknown) return false;
    return (actualState == TunActualState.enabled) == desiredEnabled;
  }

  @override
  String toString() =>
      'TunReadback($platform, $actualState, iface: $interfaceName'
      '${error == null ? '' : ', error: $error'})';
}

/// P2.6-F: the single UI-facing interpretation of (desired, observed) — so the
/// settings page can never disagree with itself about what the OS actually has.
enum TunStatusKind {
  /// No observation has run yet.
  notChecked,

  /// An observation is in flight.
  checking,

  /// This platform reports TUN state elsewhere (Android).
  unsupported,

  /// The OS state could not be determined — never rendered as on/off.
  unknown,

  /// Desired ON, and the OS confirms the interface is up.
  on,

  /// Desired OFF, and the OS confirms the interface is absent.
  off,

  /// Desired ON, but the OS has no such interface.
  mismatchOn,

  /// Desired OFF, but the OS still has the interface up.
  mismatchOff,
}

/// P2.6-F: pure mapping from (desired, in-flight, last observation) to a single
/// status.
///
/// [TunStatusKind.unknown] and [TunStatusKind.unsupported] are first-class
/// outcomes: they are **never** collapsed into `off`, and a desired state alone
/// can never produce [TunStatusKind.on].
TunStatusKind resolveTunStatus({
  required bool desiredEnabled,
  required bool checking,
  required TunReadback? readback,
}) {
  if (checking) return TunStatusKind.checking;
  if (readback == null) return TunStatusKind.notChecked;
  if (readback.unsupported) return TunStatusKind.unsupported;
  if (readback.actualState == TunActualState.unknown) {
    return TunStatusKind.unknown;
  }
  final actualEnabled = readback.actualState == TunActualState.enabled;
  if (actualEnabled == desiredEnabled) {
    return desiredEnabled ? TunStatusKind.on : TunStatusKind.off;
  }
  return desiredEnabled ? TunStatusKind.mismatchOn : TunStatusKind.mismatchOff;
}

/// P2.6-F — read-only observation of the OS's actual TUN state.
///
/// This never sets, starts, stops or mutates anything: it is pure observation,
/// bounded, async and best-effort. A failure to observe yields `unknown` — it
/// is **never** reported as `enabled` or `disabled`.
///
/// ## Why the interface name, and why not the core's config
///
/// The core's in-memory `general.Tun.Enable` (`core/common.go:261`) is the value
/// Fluxora *pushed* into it, i.e. the desired state — reading it back would
/// fabricate "actual". The observable OS fact instead is whether the TUN
/// network interface exists, and that name is deterministic per platform
/// (vendored core, `Clash.Meta/listener/sing_tun/server.go`
/// `CalculateInterfaceName`):
///
///  * **Windows / Linux** — the configured `device` (`AppIdentity.tunDeviceName`
///    = `Fluxora`) is honoured, so a present interface ⇒ running and an absent
///    interface ⇒ not running. Both directions are conclusive.
///  * **macOS** — `runtime.GOOS == "darwin"` forces the name to `utun<N>` and
///    **ignores** the configured name, and any `utunN` cannot be attributed to
///    Fluxora (other VPNs use it too). A present `Fluxora` interface would still
///    be conclusive, but an absent one is ambiguous ⇒ `unknown`, never
///    `disabled`.
///  * **Android** — reports its real state through the existing `VpnService`
///    status (`state.dart` `getStatus()`), which this phase leaves untouched ⇒
///    `unsupported` here.
class TunReadbackService {
  TunReadbackService._();

  static final TunReadbackService instance = TunReadbackService._();

  /// Last observed OS state, for UI observation. `null` until the first read.
  final ValueNotifier<TunReadback?> lastReadback = ValueNotifier(null);

  /// True while the newest observation is in flight, so the UI can show a
  /// "checking" state instead of a stale or fabricated one.
  final ValueNotifier<bool> isChecking = ValueNotifier(false);

  /// Monotonic token. Only the newest observation may publish its result, so a
  /// slower older readback can never overwrite a newer one.
  int _generation = 0;

  /// Bounded timeout for one readback.
  static const Duration readTimeout = Duration(seconds: 3);

  /// Test-only seam replacing the OS interface enumeration. Production uses
  /// `NetworkInterface.list` and projects it to names. Never set in production.
  @visibleForTesting
  static Future<List<String>> Function()? listInterfaceNamesOverride;

  /// Test-only seam pinning the reported platform (production uses
  /// `Platform.operatingSystem`).
  @visibleForTesting
  static String? platformOverride;

  /// Test-only seam overriding the interface name to look for.
  @visibleForTesting
  static String? interfaceNameOverride;

  String get _platform => platformOverride ?? Platform.operatingSystem;

  /// The interface name the core is configured to create (`Fluxora`).
  String get _interfaceName =>
      interfaceNameOverride ?? AppIdentity.tunDeviceName;

  Future<List<String>> _listInterfaceNames() async {
    final override = listInterfaceNamesOverride;
    if (override != null) return override();
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: true,
      type: InternetAddressType.any,
    );
    return interfaces.map((i) => i.name).toList(growable: false);
  }

  /// Observes the OS TUN state. Never throws.
  ///
  /// Concurrent callers each run their own observation; only the **newest** one
  /// publishes to [lastReadback] / [isChecking] (generation guard).
  Future<TunReadback> read() async {
    final generation = ++_generation;
    isChecking.value = true;
    try {
      final platform = _platform;
      TunReadback result;
      try {
        result = switch (platform) {
          'windows' => await _readDesktop(platform),
          'linux' => await _readDesktop(platform),
          'macos' => await _readDesktop(platform),
          _ => TunReadback.unknown(platform, unsupported: true),
        };
      } catch (e) {
        // Observation failure (incl. the bounded timeout) ⇒ unknown. Never
        // enabled/disabled.
        result = TunReadback.unknown(platform, error: '$e');
      }
      if (generation == _generation) lastReadback.value = result;
      return result;
    } finally {
      if (generation == _generation) isChecking.value = false;
    }
  }

  /// Windows / Linux / macOS: the OS fact is "does the TUN interface exist".
  Future<TunReadback> _readDesktop(String platform) async {
    final expected = _interfaceName;
    final names = await _listInterfaceNames().timeout(readTimeout);

    // An empty interface list means the enumeration itself did not work (every
    // OS reports at least one non-loopback interface). Reporting `disabled`
    // here would fabricate a state, so stay `unknown`.
    if (names.isEmpty) {
      return TunReadback.unknown(
        platform,
        error: 'no network interfaces reported',
        interfaceName: expected,
      );
    }

    final match = names
        .where((n) => n.toLowerCase() == expected.toLowerCase())
        .firstOrNull;
    if (match != null) {
      return TunReadback(
        actualState: TunActualState.enabled,
        platform: platform,
        checkedAt: DateTime.now(),
        interfaceName: match,
      );
    }

    // macOS never uses the configured name (see the class doc): an absent
    // `Fluxora` interface cannot be distinguished from "running as utunN".
    if (platform == 'macos') {
      return TunReadback.unknown(
        platform,
        error:
            'macOS assigns the TUN interface an OS-generated name (utunN); '
            'absence of "$expected" is not conclusive',
        interfaceName: null,
      );
    }

    // Windows / Linux honour the configured name ⇒ absent means not running.
    return TunReadback(
      actualState: TunActualState.disabled,
      platform: platform,
      checkedAt: DateTime.now(),
      interfaceName: null,
    );
  }
}
