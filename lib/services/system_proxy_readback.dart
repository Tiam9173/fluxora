import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// P2.4-D (CF-3) — the OS's **actual** system-proxy state.
///
/// Deliberately separate from Fluxora's *desired* state
/// (`networkSettingProvider.systemProxy`): the readback only ever reports what
/// the operating system currently has, never what Fluxora asked for. When the
/// OS state cannot be determined the answer is [unknown] — never a guess.
enum SystemProxyActualState { enabled, disabled, unknown }

/// Result of one system-proxy readback.
@immutable
class SystemProxyReadback {
  final SystemProxyActualState actualState;
  final String platform;
  final DateTime checkedAt;
  final String? host;
  final int? port;

  /// Non-null only when the readback itself failed (⇒ [actualState] is
  /// [SystemProxyActualState.unknown]).
  final String? error;

  /// True when this platform has no system-proxy concept at all (Android).
  final bool unsupported;

  const SystemProxyReadback({
    required this.actualState,
    required this.platform,
    required this.checkedAt,
    this.host,
    this.port,
    this.error,
    this.unsupported = false,
  });

  factory SystemProxyReadback.unknown(
    String platform, {
    String? error,
    bool unsupported = false,
  }) => SystemProxyReadback(
    actualState: SystemProxyActualState.unknown,
    platform: platform,
    checkedAt: DateTime.now(),
    error: error,
    unsupported: unsupported,
  );

  /// Whether the observed OS state agrees with [desiredEnabled]/[desiredPort].
  ///
  /// An [SystemProxyActualState.unknown] result can never be "in sync" — it is
  /// unknown, not matching.
  bool matchesDesired({required bool desiredEnabled, int? desiredPort}) {
    if (actualState == SystemProxyActualState.unknown) return false;
    final osEnabled = actualState == SystemProxyActualState.enabled;
    if (osEnabled != desiredEnabled) return false;
    if (!desiredEnabled) return true;
    if (desiredPort == null) return true;
    return port == null || port == desiredPort;
  }

  @override
  String toString() =>
      'SystemProxyReadback($platform, $actualState, $host:$port'
      '${error == null ? '' : ', error: $error'})';
}

/// P2.5-B (CF-3): the single UI-facing interpretation of
/// (desired, observed) — so the settings page and the dashboard can never
/// disagree about what the OS actually has.
enum SystemProxyStatusKind {
  /// No observation has run yet.
  notChecked,

  /// An observation is in flight.
  checking,

  /// This platform has no system-proxy concept (Android).
  unsupported,

  /// The OS state could not be determined — never rendered as on/off.
  unknown,

  /// Desired ON, and the OS confirms it.
  on,

  /// Desired OFF, and the OS confirms it.
  off,

  /// Desired ON, but the OS is not proxying.
  mismatchOn,

  /// Desired OFF, but the OS is still proxying.
  mismatchOff,
}

/// P2.5-B (CF-3): pure mapping from (desired, in-flight, last observation) to a
/// single status.
///
/// [SystemProxyStatusKind.unknown] and [SystemProxyStatusKind.unsupported] are
/// first-class outcomes: they are **never** collapsed into `off`, and a desired
/// state alone can never produce [SystemProxyStatusKind.on].
SystemProxyStatusKind resolveSystemProxyStatus({
  required bool desiredEnabled,
  required bool checking,
  required SystemProxyReadback? readback,
}) {
  if (checking) return SystemProxyStatusKind.checking;
  if (readback == null) return SystemProxyStatusKind.notChecked;
  if (readback.unsupported) return SystemProxyStatusKind.unsupported;
  if (readback.actualState == SystemProxyActualState.unknown) {
    return SystemProxyStatusKind.unknown;
  }
  final osEnabled = readback.actualState == SystemProxyActualState.enabled;
  if (osEnabled == desiredEnabled) {
    return desiredEnabled
        ? SystemProxyStatusKind.on
        : SystemProxyStatusKind.off;
  }
  return desiredEnabled
      ? SystemProxyStatusKind.mismatchOn
      : SystemProxyStatusKind.mismatchOff;
}

/// P2.4-D (CF-3) — read-only observation of the OS system-proxy state.
///
/// This never sets, starts, stops or mutates anything: it is pure observation,
/// bounded, async and best-effort. A failure to observe yields `unknown` — it
/// is **never** reported as `enabled` or `disabled`.
///
/// Platform coverage mirrors what the existing SET path can actually do:
///  * Windows — reads the WinINet "Internet Settings" registry values that
///    `InternetSetOption` writes (`reg query`);
///  * macOS — `networksetup -getwebproxy` (the counterpart of `-setwebproxy`);
///  * Linux — GNOME `gsettings get` / KDE `kreadconfig5`;
///  * anything else (incl. Android) — `unknown` + `unsupported`.
class SystemProxyReadbackService {
  SystemProxyReadbackService._();

  static final SystemProxyReadbackService instance =
      SystemProxyReadbackService._();

  /// Last observed OS state, for UI observation. `null` until the first read.
  final ValueNotifier<SystemProxyReadback?> lastReadback = ValueNotifier(null);

  /// P2.5-B: true while the newest observation is in flight, so the UI can show
  /// a "checking" state instead of a stale or fabricated one.
  final ValueNotifier<bool> isChecking = ValueNotifier(false);

  /// Monotonic token. Only the newest observation may publish its result, so a
  /// slower older readback can never overwrite a newer one (rapid ON→OFF
  /// toggling).
  int _generation = 0;

  /// Bounded timeout for one readback.
  static const Duration readTimeout = Duration(seconds: 3);

  /// Test-only seam replacing every `Process.run` used by the readback.
  /// Production never sets it.
  @visibleForTesting
  static Future<ProcessResult> Function(String exe, List<String> args)?
  processRunOverride;

  /// Test-only seam pinning the reported platform (production uses
  /// `Platform.operatingSystem`).
  @visibleForTesting
  static String? platformOverride;

  String get _platform => platformOverride ?? Platform.operatingSystem;

  Future<ProcessResult> _run(String exe, List<String> args) {
    final override = processRunOverride;
    if (override != null) return override(exe, args);
    return Process.run(exe, args);
  }

  /// Observes the OS system-proxy state. Never throws.
  ///
  /// Concurrent callers each run their own observation; only the **newest** one
  /// publishes to [lastReadback] / [isChecking] (generation guard).
  Future<SystemProxyReadback> read() async {
    final generation = ++_generation;
    isChecking.value = true;
    try {
      final platform = _platform;
      SystemProxyReadback result;
      try {
        result = switch (platform) {
          'windows' => await _readWindows(platform),
          'macos' => await _readMacos(platform),
          'linux' => await _readLinux(platform),
          _ => SystemProxyReadback.unknown(platform, unsupported: true),
        };
      } catch (e) {
        // Observation failure ⇒ unknown. Never enabled/disabled.
        result = SystemProxyReadback.unknown(platform, error: '$e');
      }
      // Publish only when no newer observation has started meanwhile.
      if (generation == _generation) lastReadback.value = result;
      return result;
    } finally {
      if (generation == _generation) isChecking.value = false;
    }
  }

  // ── Windows ──────────────────────────────────────────────────────────────
  // `InternetSetOption(INTERNET_OPTION_PER_CONNECTION_OPTION)` writes these
  // HKCU values, so reading them observes the same state the SET path set.
  static const String _winKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  Future<SystemProxyReadback> _readWindows(String platform) async {
    final enable = await _run('reg', [
      'query',
      _winKey,
      '/v',
      'ProxyEnable',
    ]).timeout(readTimeout);
    if (enable.exitCode != 0) {
      return SystemProxyReadback.unknown(
        platform,
        error: 'reg query ProxyEnable failed (${enable.exitCode})',
      );
    }
    final enabled = _winValue(enable.stdout.toString(), 'ProxyEnable') == '0x1';

    String? host;
    int? port;
    final server = await _run('reg', [
      'query',
      _winKey,
      '/v',
      'ProxyServer',
    ]).timeout(readTimeout);
    if (server.exitCode == 0) {
      final raw = _winValue(server.stdout.toString(), 'ProxyServer');
      final parsed = _parseHostPort(raw);
      host = parsed.$1;
      port = parsed.$2;
    }

    return SystemProxyReadback(
      actualState: enabled
          ? SystemProxyActualState.enabled
          : SystemProxyActualState.disabled,
      platform: platform,
      checkedAt: DateTime.now(),
      host: host,
      port: port,
    );
  }

  /// Extracts the value of a `reg query` line: `    ProxyEnable    REG_DWORD    0x1`.
  static String? _winValue(String stdout, String name) {
    for (final line in stdout.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith(name)) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 3) return parts.last;
    }
    return null;
  }

  // ── macOS ────────────────────────────────────────────────────────────────
  Future<SystemProxyReadback> _readMacos(String platform) async {
    final services = await _run('networksetup', [
      '-listallnetworkservices',
    ]).timeout(readTimeout);
    if (services.exitCode != 0) {
      return SystemProxyReadback.unknown(
        platform,
        error: 'listallnetworkservices failed (${services.exitCode})',
      );
    }
    final service = services.stdout
        .toString()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('An asterisk'))
        .firstOrNull;
    if (service == null) {
      return SystemProxyReadback.unknown(platform, error: 'no network service');
    }

    final res = await _run('networksetup', [
      '-getwebproxy',
      service,
    ]).timeout(readTimeout);
    if (res.exitCode != 0) {
      return SystemProxyReadback.unknown(
        platform,
        error: 'getwebproxy failed (${res.exitCode})',
      );
    }
    final out = res.stdout.toString();
    final enabled = _macField(out, 'Enabled')?.toLowerCase() == 'yes';
    final host = _macField(out, 'Server');
    final port = int.tryParse(_macField(out, 'Port') ?? '');
    if (_macField(out, 'Enabled') == null) {
      return SystemProxyReadback.unknown(platform, error: 'unparsable output');
    }
    return SystemProxyReadback(
      actualState: enabled
          ? SystemProxyActualState.enabled
          : SystemProxyActualState.disabled,
      platform: platform,
      checkedAt: DateTime.now(),
      host: (host == null || host.isEmpty) ? null : host,
      port: port,
    );
  }

  static String? _macField(String output, String name) {
    for (final line in output.split('\n')) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      if (line.substring(0, idx).trim() == name) {
        return line.substring(idx + 1).trim();
      }
    }
    return null;
  }

  // ── Linux ────────────────────────────────────────────────────────────────
  Future<SystemProxyReadback> _readLinux(String platform) async {
    // GNOME first (the desktop the SET path prefers), then KDE.
    final gnome = await _run('gsettings', [
      'get',
      'org.gnome.system.proxy',
      'mode',
    ]).timeout(readTimeout);
    if (gnome.exitCode == 0) {
      final mode = gnome.stdout.toString().trim().replaceAll("'", '');
      final enabled = mode == 'manual' || mode == 'auto';
      String? host;
      int? port;
      if (enabled) {
        final h = await _run('gsettings', [
          'get',
          'org.gnome.system.proxy.http',
          'host',
        ]).timeout(readTimeout);
        final p = await _run('gsettings', [
          'get',
          'org.gnome.system.proxy.http',
          'port',
        ]).timeout(readTimeout);
        if (h.exitCode == 0) {
          final v = h.stdout.toString().trim().replaceAll("'", '');
          if (v.isNotEmpty) host = v;
        }
        if (p.exitCode == 0) port = int.tryParse(p.stdout.toString().trim());
      }
      return SystemProxyReadback(
        actualState: enabled
            ? SystemProxyActualState.enabled
            : SystemProxyActualState.disabled,
        platform: platform,
        checkedAt: DateTime.now(),
        host: host,
        port: port,
      );
    }

    // KDE: `kreadconfig5/6 --group ... --key ...`
    final kde = await _run('kreadconfig5', [
      '--group',
      'Proxy',
      '--key',
      'ProxyType',
    ]).timeout(readTimeout);
    if (kde.exitCode == 0) {
      final type = kde.stdout.toString().trim();
      if (type.isEmpty) {
        return SystemProxyReadback.unknown(platform, error: 'empty ProxyType');
      }
      final enabled = type != '0' && type.toLowerCase() != 'none';
      return SystemProxyReadback(
        actualState: enabled
            ? SystemProxyActualState.enabled
            : SystemProxyActualState.disabled,
        platform: platform,
        checkedAt: DateTime.now(),
      );
    }

    // Unknown desktop environment ⇒ unknown, never a guess.
    return SystemProxyReadback.unknown(
      platform,
      error: 'no supported desktop proxy backend (gsettings/kreadconfig5)',
    );
  }

  /// Parses `host:port` / `http=host:port;https=...` into (host, port).
  static (String?, int?) _parseHostPort(String? raw) {
    if (raw == null || raw.isEmpty) return (null, null);
    final first = raw.split(';').first;
    final value = first.contains('=') ? first.split('=').last : first;
    final idx = value.lastIndexOf(':');
    if (idx <= 0) return (value.isEmpty ? null : value, null);
    return (value.substring(0, idx), int.tryParse(value.substring(idx + 1)));
  }
}
