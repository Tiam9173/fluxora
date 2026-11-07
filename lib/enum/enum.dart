// ignore_for_file: constant_identifier_names

import 'package:fluxora/common/system.dart';
// Token layer directly (not the `common/common.dart` barrel) so this file does
// not depend on the barrel that transitively imports it.
import 'package:fluxora/common/tokens/tokens.dart';
import 'package:fluxora/common/app_localizations.dart';
import 'package:fluxora/views/dashboard/widgets/widgets.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

enum SupportPlatform {
  Windows,
  MacOS,
  Linux,
  Android;

  static SupportPlatform get currentPlatform {
    if (system.isWindows) {
      return SupportPlatform.Windows;
    } else if (system.isMacOS) {
      return SupportPlatform.MacOS;
    } else if (system.isLinux) {
      return SupportPlatform.Linux;
    } else if (system.isAndroid) {
      return SupportPlatform.Android;
    }
    throw 'invalid platform';
  }
}

const desktopPlatforms = [
  SupportPlatform.Linux,
  SupportPlatform.MacOS,
  SupportPlatform.Windows,
];

enum GroupType {
  Selector,
  URLTest,
  Fallback,
  LoadBalance;

  static GroupType parseProfileType(String type) {
    return switch (type) {
      'url-test' => URLTest,
      'select' => Selector,
      'fallback' => Fallback,
      'load-balance' => LoadBalance,
      String() => throw UnimplementedError(),
    };
  }
}

enum GroupName { GLOBAL, Proxy, Auto, Fallback }

extension GroupTypeExtension on GroupType {
  static List<String> get valueList =>
      GroupType.values.map((e) => e.toString().split('.').last).toList();

  bool get isComputedSelected {
    return [GroupType.URLTest, GroupType.Fallback].contains(this);
  }

  static GroupType? getGroupType(String value) {
    final index = GroupTypeExtension.valueList.indexOf(value);
    if (index == -1) return null;
    return GroupType.values[index];
  }

  String get value => GroupTypeExtension.valueList[index];
}

enum UsedProxy { GLOBAL, DIRECT, REJECT }

extension UsedProxyExtension on UsedProxy {
  static List<String> get valueList =>
      UsedProxy.values.map((e) => e.toString().split('.').last).toList();

  String get value => UsedProxyExtension.valueList[index];
}

enum Mode { rule, global, direct }

enum IpClickBehavior { privacyProtection, manualRefresh, switchDomestic }

enum TrayClickBehavior { showPanel, showMenu }

enum ViewMode { mobile, laptop, desktop }

/// Log verbosity for the core.
///
/// [none] is the "produce no logs" setting. It is deliberately *not* a second
/// option alongside a `silent` value: the two would carry the same wire value,
/// which makes the enum's reverse lookup ambiguous and offers the user two
/// identical choices. The wire value stays `silent` because that is the name the
/// core understands.
enum LogLevel { debug, info, warning, error, silent }

extension LogLevelExt on LogLevel {
  /// The colour this level paints its payload with.
  ///
  /// Comes from [FluxoraColorSet] — the Aurora semantic roles — instead of the
  /// hardcoded `Colors.grey.shade700 / Colors.redAccent / ARGB(230, 255, 166, 0)`
  /// this used to return. Those three were fixed values: `Colors.redAccent` is
  /// tuned for a dark surface and turns muddy on the light theme, and the amber
  /// never matched the palette's `warning`.
  ///
  /// `null` means "inherit": `info` is the normal case and should read like body
  /// text rather than carry a colour of its own.
  Color? colorOf(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fluxora = FluxoraColorSet.of(scheme.brightness);
    return switch (this) {
      LogLevel.silent => scheme.outline,
      LogLevel.debug => scheme.onSurfaceVariant,
      LogLevel.info => null,
      LogLevel.warning => fluxora.warning,
      LogLevel.error => fluxora.error,
    };
  }
}

enum TransportProtocol { udp, tcp }

enum TrafficUnit { B, KB, MB, GB, TB }

enum NavigationItemMode { mobile, desktop, more }

enum Network { tcp, udp }

enum ProxiesSortType { none, delay, name }

enum TunStack { gvisor, system, mixed, mips }

enum AccessControlMode { acceptSelected, rejectSelected }

enum AccessSortType { none, installTime, updateTime }

enum ProfileType { file, url }

enum ConnectionsSortType {
  defaultSort,
  realTimeSpeed,
  totalTraffic,
  creationTime,
}

enum ResultType {
  @JsonValue(0)
  success,
  @JsonValue(-1)
  error,
}

enum AppMessageType { log, delay, request, loaded, speedTest }

enum InvokeMessageType { protect, process }

enum FindProcessMode { always, off }

enum RecoveryOption { all, onlyProfiles }

enum ChipType { action, delete }

enum CommonCardType { plain, filled }
//
// extension CommonCardTypeExt on CommonCardType {
//   CommonCardType get variant => CommonCardType.plain;
// }

enum ProxiesType { tab, list }

enum ProxiesLayout { loose, standard, tight }

enum ProxyCardType { expand, shrink, min }

enum DnsMode {
  normal,
  @JsonValue('fake-ip')
  fakeIp,
  @JsonValue('redir-host')
  redirHost,
  hosts,
}

enum CacheAlgorithm { arc, lru }

enum FilterMode { blacklist, whitelist, rule }

enum ExternalControllerStatus {
  @JsonValue('')
  close(''),
  @JsonValue('127.0.0.1:9090')
  open('127.0.0.1:9090');

  final String value;

  const ExternalControllerStatus(this.value);
}

enum KeyboardModifier {
  alt([PhysicalKeyboardKey.altLeft, PhysicalKeyboardKey.altRight]),
  capsLock([PhysicalKeyboardKey.capsLock]),
  control([PhysicalKeyboardKey.controlLeft, PhysicalKeyboardKey.controlRight]),
  fn([PhysicalKeyboardKey.fn]),
  meta([PhysicalKeyboardKey.metaLeft, PhysicalKeyboardKey.metaRight]),
  shift([PhysicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftRight]);

  final List<PhysicalKeyboardKey> physicalKeys;

  const KeyboardModifier(this.physicalKeys);
}

extension KeyboardModifierExt on KeyboardModifier {
  HotKeyModifier toHotKeyModifier() {
    return switch (this) {
      KeyboardModifier.alt => HotKeyModifier.alt,
      KeyboardModifier.capsLock => HotKeyModifier.capsLock,
      KeyboardModifier.control => HotKeyModifier.control,
      KeyboardModifier.fn => HotKeyModifier.fn,
      KeyboardModifier.meta => HotKeyModifier.meta,
      KeyboardModifier.shift => HotKeyModifier.shift,
    };
  }
}

enum HotAction { start, view, mode, proxy, tun }

enum ProxiesIconStyle { standard, none, icon }

enum FontFamily {
  twEmoji('Twemoji'),
  jetBrainsMono('JetBrainsMono'),
  icon('Icons');

  final String value;

  const FontFamily(this.value);
}

/// Where the theme's seed colour comes from.
///
/// Fluxora brand-first by default: [fluxora] deliberately ignores Android's
/// Material You `corePalette` so the brand identity survives on Android.
/// Material You stays available as an explicit user opt-in via [system].
enum ColorSource {
  /// Fluxora brand palette. `ThemeProps.primaryColor` → Flux preset `#29D6C7`.
  /// **Ignores** `corePalette` / `accentColor` entirely.
  fluxora,

  /// Android Material You / system dynamic colour.
  /// `corePalette` → `accentColor` → Flux preset `#29D6C7`.
  system,

  /// User-picked colour. `ThemeProps.primaryColor` → Flux preset `#29D6C7`.
  custom,
}

enum RouteMode { bypassPrivate, config }

enum ActionMethod {
  message,
  initClash,
  getIsInit,
  forceGc,
  shutdown,
  validateConfig,
  updateConfig,
  getConfig,
  getProxies,
  changeProxy,
  getTraffic,
  getTotalTraffic,
  resetTraffic,
  asyncTestDelay,
  getConnections,
  closeConnections,
  resetConnections,
  closeConnection,
  getExternalProviders,
  getExternalProvider,
  updateGeoData,
  updateExternalProvider,
  sideLoadExternalProvider,
  startLog,
  stopLog,
  getLogs,
  clearLogs,
  startListener,
  stopListener,
  getCountryCode,
  getMemory,
  crash,
  setupConfig,
  flushFakeIP,
  flushDnsCache,
  generateAgeKeyPair,
  convertAgeSecretKeyToPublicKey,
  decryptAgeConfig,
  getMode,
  parseExternalProviderContent,
  getCoreStatus,
  speedTest,
  speedTestStatus,

  ///Android,
  setState,
  startTun,
  stopTun,
  getRunTime,
  updateDns,
  getAndroidVpnOptions,
  getCurrentProfileName,
}

enum AuthorizeCode { none, success, error }

enum WindowsHelperServiceStatus { none, presence, running }

enum FunctionTag {
  updateClashConfig,
  setupClashConfig,
  updateStatus,
  updateGroups,
  addCheckIpNum,
  applyProfile,
  savePreferences,
  changeProxy,
  checkIp,
  handleWill,
  updateDelay,
  vpnTip,
  autoLaunch,
  renderPause,
  updatePageIndex,
  pageChange,
  proxiesTabChange,
  logs,
  requests,
  autoScrollToEnd,
}

enum DashboardWidget {
  networkSpeed(GridItem(crossAxisCellCount: 8, child: NetworkSpeed())),
  networkSpeedSmall(
    GridItem(crossAxisCellCount: 4, child: NetworkSpeedSmall()),
  ),
  outboundModeV2(GridItem(crossAxisCellCount: 8, child: OutboundModeV2())),
  outboundMode(GridItem(crossAxisCellCount: 4, child: OutboundMode())),
  trafficUsage(GridItem(crossAxisCellCount: 4, child: TrafficUsage())),
  networkDetection(GridItem(crossAxisCellCount: 4, child: NetworkDetection())),
  tunButton(
    GridItem(crossAxisCellCount: 4, child: TUNButton()),
    platforms: desktopPlatforms,
  ),
  vpnButton(
    GridItem(crossAxisCellCount: 4, child: VpnButton()),
    platforms: [SupportPlatform.Android],
  ),
  systemProxyButton(
    GridItem(crossAxisCellCount: 4, child: SystemProxyButton()),
    platforms: desktopPlatforms,
  ),
  intranetIp(GridItem(crossAxisCellCount: 4, child: IntranetIP())),
  memoryInfo(GridItem(crossAxisCellCount: 4, child: MemoryInfo())),
  connectionsCount(GridItem(crossAxisCellCount: 4, child: ConnectionsCount())),
  ipv6Switch(GridItem(crossAxisCellCount: 4, child: Ipv6Switch())),
  wakelockSwitch(
    GridItem(crossAxisCellCount: 4, child: WakelockSwitch()),
    platforms: desktopPlatforms,
  ),
  dnsOverride(GridItem(crossAxisCellCount: 4, child: DnsOverride())),
  snifferOverride(GridItem(crossAxisCellCount: 4, child: SnifferOverride())),
  ntpOverride(GridItem(crossAxisCellCount: 4, child: NtpOverride())),
  providersInfo(GridItem(crossAxisCellCount: 4, child: ProvidersInfo())),
  fcmStatus(GridItem(crossAxisCellCount: 4, child: FcmStatus())),
  onlinePanel(GridItem(crossAxisCellCount: 4, child: OnlinePanel())),
  mediaUnlock(GridItem(crossAxisCellCount: 8, child: MediaUnlock())),
  mediaUnlockSmall(GridItem(crossAxisCellCount: 4, child: MediaUnlockSmall())),
  startButton(
    // Full width (8 columns) — the Dashboard's connection Hero (D4.6).
    GridItem(crossAxisCellCount: 8, isDeletable: false, child: StartButton()),
  );

  final GridItem widget;
  final List<SupportPlatform> platforms;

  const DashboardWidget(this.widget, {this.platforms = SupportPlatform.values});

  String get title => switch (this) {
    networkSpeed || networkSpeedSmall => appLocalizations.networkSpeed,
    outboundMode || outboundModeV2 => appLocalizations.outboundMode,
    trafficUsage => appLocalizations.trafficUsage,
    networkDetection => appLocalizations.networkDetection,
    tunButton => 'TUN',
    vpnButton => 'VPN',
    systemProxyButton => appLocalizations.systemProxy,
    intranetIp => appLocalizations.intranetIP,
    memoryInfo => appLocalizations.memoryInfo,
    connectionsCount => appLocalizations.connections,
    ipv6Switch => 'IPv6',
    wakelockSwitch => appLocalizations.wakelock,
    dnsOverride => 'DNS',
    snifferOverride => appLocalizations.sniffer,
    ntpOverride => 'NTP',
    providersInfo => appLocalizations.providers,
    fcmStatus => appLocalizations.fcmOptimization,
    onlinePanel => appLocalizations.onlinePanel,
    mediaUnlock || mediaUnlockSmall => appLocalizations.mediaUnlock,
    startButton => appLocalizations.powerSwitch,
  };

  IconData get icon => switch (this) {
    networkSpeed || networkSpeedSmall => Icons.speed_outlined,
    outboundMode || outboundModeV2 => Icons.call_split_rounded,
    trafficUsage => Icons.data_usage_rounded,
    networkDetection => Icons.travel_explore_rounded,
    tunButton || vpnButton => Icons.vpn_key_outlined,
    systemProxyButton => Icons.swap_calls_rounded,
    intranetIp || ipv6Switch => Icons.lan_outlined,
    memoryInfo => Icons.memory_rounded,
    connectionsCount => Icons.swap_vert_rounded,
    wakelockSwitch => Icons.wb_sunny_outlined,
    dnsOverride => Icons.dns_outlined,
    snifferOverride => Icons.radar_rounded,
    ntpOverride => Icons.schedule_rounded,
    providersInfo => Icons.cloud_download_outlined,
    fcmStatus => Icons.notifications_outlined,
    onlinePanel => Icons.open_in_browser_rounded,
    mediaUnlock || mediaUnlockSmall => Icons.play_circle_outline,
    startButton => Icons.power_settings_new_rounded,
  };

  /// Maps a grid item back to its enum value, or `null` when it is unknown.
  ///
  /// Matched by **child identity** first. The dashboard re-wraps the Hero into
  /// a full-width `GridItem` (`dashboardGridItemFor`), so the instance the grid
  /// hands back is not the one stored in [widget]; value equality then fails,
  /// `indexWhere` returns -1, and the old `values[-1]` threw a `RangeError`
  /// inside a post-frame callback — which is why "add or reorder the dashboard
  /// widgets, save, and nothing changes".
  static DashboardWidget? getDashboardWidget(GridItem gridItem) {
    for (final item in DashboardWidget.values) {
      if (identical(item.widget.child, gridItem.child)) return item;
    }
    for (final item in DashboardWidget.values) {
      if (item.widget == gridItem) return item;
    }
    return null;
  }
}

enum GeodataLoader { standard, memconservative }

enum PageLabel {
  dashboard,
  proxies,
  profiles,
  tools,
  logs,
  requests,
  resources,
  script,
  connections,
}

extension PageLabelExtension on PageLabel {
  String get localizedName {
    switch (this) {
      case PageLabel.dashboard:
        return appLocalizations.dashboard;
      case PageLabel.proxies:
        return appLocalizations.proxies;
      case PageLabel.profiles:
        return appLocalizations.profiles;
      case PageLabel.tools:
        return appLocalizations.navTools;
      case PageLabel.logs:
        return appLocalizations.logs;
      case PageLabel.requests:
        return appLocalizations.requests;
      case PageLabel.resources:
        return appLocalizations.resources;
      case PageLabel.script:
        return appLocalizations.script;
      case PageLabel.connections:
        return appLocalizations.navConnections;
    }
  }
}

enum RuleAction {
  DOMAIN('DOMAIN'),
  DOMAIN_SUFFIX('DOMAIN-SUFFIX'),
  DOMAIN_KEYWORD('DOMAIN-KEYWORD'),
  DOMAIN_REGEX('DOMAIN-REGEX'),
  GEOSITE('GEOSITE'),
  IP_CIDR('IP-CIDR'),
  IP_CIDR6('IP-CIDR6'),
  IP_SUFFIX('IP-SUFFIX'),
  IP_ASN('IP-ASN'),
  GEOIP('GEOIP'),
  SRC_GEOIP('SRC-GEOIP'),
  SRC_IP_ASN('SRC-IP-ASN'),
  SRC_IP_CIDR('SRC-IP-CIDR'),
  SRC_IP_SUFFIX('SRC-IP-SUFFIX'),
  DST_PORT('DST-PORT'),
  SRC_PORT('SRC-PORT'),
  IN_PORT('IN-PORT'),
  IN_TYPE('IN-TYPE'),
  IN_USER('IN-USER'),
  IN_NAME('IN-NAME'),
  PROCESS_PATH('PROCESS-PATH'),
  PROCESS_PATH_REGEX('PROCESS-PATH-REGEX'),
  PROCESS_NAME('PROCESS-NAME'),
  PROCESS_NAME_REGEX('PROCESS-NAME-REGEX'),
  UID('UID'),
  NETWORK('NETWORK'),
  DSCP('DSCP'),
  RULE_SET('RULE-SET'),
  AND('AND'),
  OR('OR'),
  NOT('NOT'),
  SUB_RULE('SUB-RULE'),
  MATCH('MATCH');

  final String value;

  const RuleAction(this.value);
}

extension RuleActionExt on RuleAction {
  bool get hasParams => [
    RuleAction.GEOIP,
    RuleAction.IP_ASN,
    RuleAction.SRC_IP_ASN,
    RuleAction.IP_CIDR,
    RuleAction.IP_CIDR6,
    RuleAction.IP_SUFFIX,
    RuleAction.RULE_SET,
  ].contains(this);
}

enum OverrideRuleType { override, added }

enum RuleTarget { DIRECT, REJECT }

enum RecoveryStrategy { compatible, override }

enum CacheTag { logs, rules, requests, proxiesList }

enum Language { yaml, javaScript }

enum ImportOption { code, url, file }

enum ScrollPositionCacheKeys { tools, profiles, proxiesList, proxiesTabList }

enum DelayAnimationType {
  none,
  rotatingCircle,
  pulse,
  spinningLines,
  threeInOut,
  threeBounce,
  circle,
  fadingCircle,
  fadingFour,
  wave,
  doubleBounce,
}
