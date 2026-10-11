import 'package:intl/intl.dart';

import 'l10n.dart';

/// P2.5-B (CF-3) — system-proxy *actual state* strings.
///
/// Follows the same lightweight convention as `chain_proxy_l10n.dart`
/// (an `Intl.message` extension on [AppLocalizations]) rather than editing the
/// generated `l10n.dart` + 8 `messages_*.dart` catalogues, which would be a
/// large, unrelated change.
///
/// NOTE: like `chain_proxy_l10n.dart`, these carry a Chinese source string and
/// are therefore not translated per locale. This is reported as a known gap in
/// `P2.5-B_SYSTEM_PROXY_READBACK_UI_IMPLEMENTATION_REPORT.md` (§ Localization).
extension SystemProxyLocalizations on AppLocalizations {
  /// Label above the observed state, e.g. "Actual system state".
  String get systemProxyActualStatus => Intl.message(
    '系统实际状态',
    name: 'systemProxyActualStatus',
    desc: 'Label for the observed OS system-proxy state',
  );

  /// An observation is in flight.
  String get systemProxyChecking => Intl.message(
    '正在检测系统实际状态…',
    name: 'systemProxyChecking',
    desc: 'System proxy readback in flight',
  );

  /// Desired ON, OS confirms it.
  String get systemProxyActualOn => Intl.message(
    '系统实际代理已开启',
    name: 'systemProxyActualOn',
    desc: 'Desired and observed system proxy both enabled',
  );

  /// Desired OFF, OS confirms it.
  String get systemProxyActualOff => Intl.message(
    '系统实际代理已关闭',
    name: 'systemProxyActualOff',
    desc: 'Desired and observed system proxy both disabled',
  );

  /// Desired ON but the OS is not proxying.
  String get systemProxyMismatchOn => Intl.message(
    '设置已请求开启，但系统实际代理未开启',
    name: 'systemProxyMismatchOn',
    desc: 'Desired enabled but the OS system proxy is not enabled',
  );

  /// Desired OFF but the OS is still proxying.
  String get systemProxyMismatchOff => Intl.message(
    '系统代理仍处于开启状态',
    name: 'systemProxyMismatchOff',
    desc: 'Desired disabled but the OS system proxy is still enabled',
  );

  /// The OS state could not be determined.
  String get systemProxyUnknown => Intl.message(
    '无法确认系统代理状态',
    name: 'systemProxyUnknown',
    desc: 'System proxy readback returned unknown',
  );

  /// This platform has no system-proxy concept.
  String get systemProxyUnsupported => Intl.message(
    '当前平台不支持系统代理状态检测',
    name: 'systemProxyUnsupported',
    desc: 'System proxy readback is unsupported on this platform',
  );
}
