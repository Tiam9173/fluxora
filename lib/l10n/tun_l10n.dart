import 'package:intl/intl.dart';

import 'l10n.dart';

/// P2.6-F — TUN *actual state* strings.
///
/// Follows the same lightweight convention as `system_proxy_l10n.dart` /
/// `chain_proxy_l10n.dart` (an `Intl.message` extension on [AppLocalizations])
/// rather than editing the generated `l10n.dart` + 8 `messages_*.dart`
/// catalogues, which would be a large, unrelated change.
///
/// NOTE: like `system_proxy_l10n.dart`, these carry a Chinese source string and
/// are therefore not translated per locale. This is reported as a known gap in
/// `P2.6-F_TUN_READBACK_IMPLEMENTATION_REPORT.md` (§ Localization).
extension TunLocalizations on AppLocalizations {
  /// Label above the observed state, e.g. "Actual system state".
  String get tunActualStatus => Intl.message(
    'TUN 实际状态',
    name: 'tunActualStatus',
    desc: 'Label for the observed OS TUN state',
  );

  /// An observation is in flight.
  String get tunChecking => Intl.message(
    '正在检测 TUN 实际状态…',
    name: 'tunChecking',
    desc: 'TUN readback in flight',
  );

  /// Desired ON, OS confirms the interface is up.
  String get tunActualOn => Intl.message(
    '系统实际 TUN 已启用',
    name: 'tunActualOn',
    desc: 'Desired and observed TUN both enabled',
  );

  /// Desired OFF, OS confirms the interface is absent.
  String get tunActualOff => Intl.message(
    '系统实际 TUN 未启用',
    name: 'tunActualOff',
    desc: 'Desired and observed TUN both disabled',
  );

  /// Desired ON but the OS has no such interface.
  String get tunMismatchOn => Intl.message(
    '设置已请求开启，但系统实际 TUN 未启用',
    name: 'tunMismatchOn',
    desc: 'Desired enabled but the OS TUN interface is not present',
  );

  /// Desired OFF but the OS still has the interface up.
  String get tunMismatchOff => Intl.message(
    'TUN 仍处于启用状态',
    name: 'tunMismatchOff',
    desc: 'Desired disabled but the OS TUN interface is still present',
  );

  /// The OS state could not be determined.
  String get tunUnknown => Intl.message(
    '无法确认 TUN 实际状态',
    name: 'tunUnknown',
    desc: 'TUN readback returned unknown',
  );

  /// This platform reports TUN state elsewhere.
  String get tunUnsupported => Intl.message(
    '当前平台不提供 TUN 实际状态检测',
    name: 'tunUnsupported',
    desc: 'TUN readback is unsupported on this platform',
  );
}
