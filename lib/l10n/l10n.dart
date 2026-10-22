// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class AppLocalizations {
  AppLocalizations();

  static AppLocalizations? _current;

  static AppLocalizations get current {
    assert(
      _current != null,
      'No instance of AppLocalizations was loaded. Try to initialize the AppLocalizations delegate before accessing AppLocalizations.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<AppLocalizations> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = AppLocalizations();
      AppLocalizations._current = instance;

      return instance;
    });
  }

  static AppLocalizations of(BuildContext context) {
    final instance = AppLocalizations.maybeOf(context);
    assert(
      instance != null,
      'No instance of AppLocalizations present in the widget tree. Did you add AppLocalizations.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// `Rule`
  String get rule {
    return Intl.message('Rule', name: 'rule', desc: '', args: []);
  }

  /// `Global`
  String get global {
    return Intl.message('Global', name: 'global', desc: '', args: []);
  }

  /// `Direct`
  String get direct {
    return Intl.message('Direct', name: 'direct', desc: '', args: []);
  }

  /// `Home`
  String get dashboard {
    return Intl.message('Home', name: 'dashboard', desc: '', args: []);
  }

  /// `Custom Dashboard Title`
  String get customDashboardTitle {
    return Intl.message(
      'Custom Dashboard Title',
      name: 'customDashboardTitle',
      desc: '',
      args: [],
    );
  }

  /// `Title is too long, maximum 20 characters supported`
  String get titleTooLong {
    return Intl.message(
      'Title is too long, maximum 20 characters supported',
      name: 'titleTooLong',
      desc: '',
      args: [],
    );
  }

  /// `Proxies`
  String get proxies {
    return Intl.message('Proxies', name: 'proxies', desc: '', args: []);
  }

  /// `Profile`
  String get profile {
    return Intl.message('Profile', name: 'profile', desc: '', args: []);
  }

  /// `Profiles`
  String get profiles {
    return Intl.message('Profiles', name: 'profiles', desc: '', args: []);
  }

  /// `Tools`
  String get tools {
    return Intl.message('Tools', name: 'tools', desc: '', args: []);
  }

  /// `Logs`
  String get logs {
    return Intl.message('Logs', name: 'logs', desc: '', args: []);
  }

  /// `View captured logs`
  String get logsDesc {
    return Intl.message(
      'View captured logs',
      name: 'logsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Resources`
  String get resources {
    return Intl.message('Resources', name: 'resources', desc: '', args: []);
  }

  /// `Sync All`
  String get syncAll {
    return Intl.message('Sync All', name: 'syncAll', desc: '', args: []);
  }

  /// `Sync Failed`
  String get syncFailed {
    return Intl.message('Sync Failed', name: 'syncFailed', desc: '', args: []);
  }

  /// `External resource info`
  String get resourcesDesc {
    return Intl.message(
      'External resource info',
      name: 'resourcesDesc',
      desc: '',
      args: [],
    );
  }

  /// `Global override script config`
  String get scriptDesc {
    return Intl.message(
      'Global override script config',
      name: 'scriptDesc',
      desc: '',
      args: [],
    );
  }

  /// `Traffic Usage`
  String get trafficUsage {
    return Intl.message(
      'Traffic Usage',
      name: 'trafficUsage',
      desc: '',
      args: [],
    );
  }

  /// `Core Info`
  String get coreInfo {
    return Intl.message('Core Info', name: 'coreInfo', desc: '', args: []);
  }

  /// `Network Speed`
  String get networkSpeed {
    return Intl.message(
      'Network Speed',
      name: 'networkSpeed',
      desc: '',
      args: [],
    );
  }

  /// `Real-time Speed`
  String get realTimeSpeed {
    return Intl.message(
      'Real-time Speed',
      name: 'realTimeSpeed',
      desc: '',
      args: [],
    );
  }

  /// `Connections Sort`
  String get connectionsSort {
    return Intl.message(
      'Connections Sort',
      name: 'connectionsSort',
      desc: '',
      args: [],
    );
  }

  /// `Total Traffic`
  String get totalTraffic {
    return Intl.message(
      'Total Traffic',
      name: 'totalTraffic',
      desc: '',
      args: [],
    );
  }

  /// `Since this session started`
  String get trafficSinceStart {
    return Intl.message(
      'Since this session started',
      name: 'trafficSinceStart',
      desc: '',
      args: [],
    );
  }

  /// `Restart App`
  String get restartApp {
    return Intl.message('Restart App', name: 'restartApp', desc: '', args: []);
  }

  /// `Outbound Mode`
  String get outboundMode {
    return Intl.message(
      'Outbound Mode',
      name: 'outboundMode',
      desc: '',
      args: [],
    );
  }

  /// `Network`
  String get networkDetection {
    return Intl.message(
      'Network',
      name: 'networkDetection',
      desc: '',
      args: [],
    );
  }

  /// `Upload`
  String get upload {
    return Intl.message('Upload', name: 'upload', desc: '', args: []);
  }

  /// `Download`
  String get download {
    return Intl.message('Download', name: 'download', desc: '', args: []);
  }

  /// `No Proxy`
  String get noProxy {
    return Intl.message('No Proxy', name: 'noProxy', desc: '', args: []);
  }

  /// `Please create or add a valid profile`
  String get noProxyDesc {
    return Intl.message(
      'Please create or add a valid profile',
      name: 'noProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `No profile. Please add one.`
  String get nullProfileDesc {
    return Intl.message(
      'No profile. Please add one.',
      name: 'nullProfileDesc',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '', args: []);
  }

  /// `Language`
  String get language {
    return Intl.message('Language', name: 'language', desc: '', args: []);
  }

  /// `Default`
  String get defaultText {
    return Intl.message('Default', name: 'defaultText', desc: '', args: []);
  }

  /// `More`
  String get more {
    return Intl.message('More', name: 'more', desc: '', args: []);
  }

  /// `Other`
  String get other {
    return Intl.message('Other', name: 'other', desc: '', args: []);
  }

  /// `Enhanced Tools`
  String get otherSettings {
    return Intl.message(
      'Enhanced Tools',
      name: 'otherSettings',
      desc: '',
      args: [],
    );
  }

  /// `Modify enhanced tool settings`
  String get otherSettingsDesc {
    return Intl.message(
      'Modify enhanced tool settings',
      name: 'otherSettingsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Smart Auto-Stop`
  String get smartAutoStop {
    return Intl.message(
      'Smart Auto-Stop',
      name: 'smartAutoStop',
      desc: '',
      args: [],
    );
  }

  /// `Stop VPN on specific networks`
  String get smartAutoStopDesc {
    return Intl.message(
      'Stop VPN on specific networks',
      name: 'smartAutoStopDesc',
      desc: '',
      args: [],
    );
  }

  /// `Network Match`
  String get networkMatch {
    return Intl.message(
      'Network Match',
      name: 'networkMatch',
      desc: '',
      args: [],
    );
  }

  /// `Enter IP, CIDR or Gateway:IP/CIDR`
  String get networkMatchHint {
    return Intl.message(
      'Enter IP, CIDR or Gateway:IP/CIDR',
      name: 'networkMatchHint',
      desc: '',
      args: [],
    );
  }

  /// `Smart Auto-Stop running`
  String get smartAutoStopServiceRunning {
    return Intl.message(
      'Smart Auto-Stop running',
      name: 'smartAutoStopServiceRunning',
      desc: '',
      args: [],
    );
  }

  /// `Service Running`
  String get serviceRunning {
    return Intl.message(
      'Service Running',
      name: 'serviceRunning',
      desc: '',
      args: [],
    );
  }

  /// `Connected`
  String get coreConnected {
    return Intl.message('Connected', name: 'coreConnected', desc: '', args: []);
  }

  /// `Suspended`
  String get coreSuspended {
    return Intl.message('Suspended', name: 'coreSuspended', desc: '', args: []);
  }

  /// `Invalid IP or CIDR format`
  String get invalidIpFormat {
    return Intl.message(
      'Invalid IP or CIDR format',
      name: 'invalidIpFormat',
      desc: '',
      args: [],
    );
  }

  /// `Max 5 rules allowed`
  String get tooManyRules {
    return Intl.message(
      'Max 5 rules allowed',
      name: 'tooManyRules',
      desc: '',
      args: [],
    );
  }

  /// `Doze Support`
  String get dozeSuspend {
    return Intl.message(
      'Doze Support',
      name: 'dozeSuspend',
      desc: '',
      args: [],
    );
  }

  /// `Sync with system Doze mode`
  String get dozeSuspendDesc {
    return Intl.message(
      'Sync with system Doze mode',
      name: 'dozeSuspendDesc',
      desc: '',
      args: [],
    );
  }

  /// `Store Fix`
  String get storeFix {
    return Intl.message('Store Fix', name: 'storeFix', desc: '', args: []);
  }

  /// `Fix Play Store download issues`
  String get storeFixDesc {
    return Intl.message(
      'Fix Play Store download issues',
      name: 'storeFixDesc',
      desc: '',
      args: [],
    );
  }

  /// `Disable QUIC`
  String get disableQuic {
    return Intl.message(
      'Disable QUIC',
      name: 'disableQuic',
      desc: '',
      args: [],
    );
  }

  /// `Disable QUIC to resolve specific network issues`
  String get disableQuicDesc {
    return Intl.message(
      'Disable QUIC to resolve specific network issues',
      name: 'disableQuicDesc',
      desc: '',
      args: [],
    );
  }

  /// `High Priority`
  String get notificationHighPriority {
    return Intl.message(
      'High Priority',
      name: 'notificationHighPriority',
      desc: '',
      args: [],
    );
  }

  /// `Adjust current notification bar to foreground high priority`
  String get notificationHighPriorityDesc {
    return Intl.message(
      'Adjust current notification bar to foreground high priority',
      name: 'notificationHighPriorityDesc',
      desc: '',
      args: [],
    );
  }

  /// `High-priority notifications can alleviate background core keep-alive issues on some customized systems. If your VPN service is currently running normally, it is recommended to keep this option disabled. Are you sure you want to enable it?`
  String get notificationHighPriorityTip {
    return Intl.message(
      'High-priority notifications can alleviate background core keep-alive issues on some customized systems. If your VPN service is currently running normally, it is recommended to keep this option disabled. Are you sure you want to enable it?',
      name: 'notificationHighPriorityTip',
      desc: '',
      args: [],
    );
  }

  /// `Speed in Notification`
  String get networkSpeedNotification {
    return Intl.message(
      'Speed in Notification',
      name: 'networkSpeedNotification',
      desc: '',
      args: [],
    );
  }

  /// `Show speed and subscription info in notification bar`
  String get networkSpeedNotificationDesc {
    return Intl.message(
      'Show speed and subscription info in notification bar',
      name: 'networkSpeedNotificationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Title Buttons`
  String get alwaysShowTitleBar {
    return Intl.message(
      'Title Buttons',
      name: 'alwaysShowTitleBar',
      desc: '',
      args: [],
    );
  }

  /// `Always show the title bar buttons in the top-right corner`
  String get alwaysShowTitleBarDesc {
    return Intl.message(
      'Always show the title bar buttons in the top-right corner',
      name: 'alwaysShowTitleBarDesc',
      desc: '',
      args: [],
    );
  }

  /// `Tray Enhancement`
  String get trayEnhancement {
    return Intl.message(
      'Tray Enhancement',
      name: 'trayEnhancement',
      desc: '',
      args: [],
    );
  }

  /// `Control proxy groups in system tray menu`
  String get trayEnhancementDesc {
    return Intl.message(
      'Control proxy groups in system tray menu',
      name: 'trayEnhancementDesc',
      desc: '',
      args: [],
    );
  }

  /// `Tray Click Behavior`
  String get trayClickBehavior {
    return Intl.message(
      'Tray Click Behavior',
      name: 'trayClickBehavior',
      desc: '',
      args: [],
    );
  }

  /// `Left Click`
  String get leftClickBehavior {
    return Intl.message(
      'Left Click',
      name: 'leftClickBehavior',
      desc: '',
      args: [],
    );
  }

  /// `Right Click`
  String get rightClickBehavior {
    return Intl.message(
      'Right Click',
      name: 'rightClickBehavior',
      desc: '',
      args: [],
    );
  }

  /// `Show Window`
  String get showPanel {
    return Intl.message('Show Window', name: 'showPanel', desc: '', args: []);
  }

  /// `Open Menu`
  String get showMenu {
    return Intl.message('Open Menu', name: 'showMenu', desc: '', args: []);
  }

  /// `Tray Speed`
  String get enableTraySpeed {
    return Intl.message(
      'Tray Speed',
      name: 'enableTraySpeed',
      desc: '',
      args: [],
    );
  }

  /// `Display upload and download rates in the menu bar`
  String get enableTraySpeedDesc {
    return Intl.message(
      'Display upload and download rates in the menu bar',
      name: 'enableTraySpeedDesc',
      desc: '',
      args: [],
    );
  }

  /// `Exclude China`
  String get excludeChina {
    return Intl.message(
      'Exclude China',
      name: 'excludeChina',
      desc: '',
      args: [],
    );
  }

  /// `Allow China QUIC traffic instead of blocking all`
  String get excludeChinaDesc {
    return Intl.message(
      'Allow China QUIC traffic instead of blocking all',
      name: 'excludeChinaDesc',
      desc: '',
      args: [],
    );
  }

  /// `Loopback Protection`
  String get loopbackProtection {
    return Intl.message(
      'Loopback Protection',
      name: 'loopbackProtection',
      desc: '',
      args: [],
    );
  }

  /// `Block loopback traffic from network errors`
  String get loopbackProtectionDesc {
    return Intl.message(
      'Block loopback traffic from network errors',
      name: 'loopbackProtectionDesc',
      desc: '',
      args: [],
    );
  }

  /// `Port Fallback`
  String get portFallback {
    return Intl.message(
      'Port Fallback',
      name: 'portFallback',
      desc: '',
      args: [],
    );
  }

  /// `Use another port when the configured one is already taken`
  String get portFallbackDesc {
    return Intl.message(
      'Use another port when the configured one is already taken',
      name: 'portFallbackDesc',
      desc: '',
      args: [],
    );
  }

  /// `FCM Optimization`
  String get fcmOptimization {
    return Intl.message(
      'FCM Optimization',
      name: 'fcmOptimization',
      desc: '',
      args: [],
    );
  }

  /// `Enhance FCM connection stability`
  String get fcmOptimizationDesc {
    return Intl.message(
      'Enhance FCM connection stability',
      name: 'fcmOptimizationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Quick Response`
  String get quickResponse {
    return Intl.message(
      'Quick Response',
      name: 'quickResponse',
      desc: '',
      args: [],
    );
  }

  /// `Disconnect on network change (WiFi/Mobile)`
  String get quickResponseDesc {
    return Intl.message(
      'Disconnect on network change (WiFi/Mobile)',
      name: 'quickResponseDesc',
      desc: '',
      args: [],
    );
  }

  /// `Network Fix`
  String get networkFix {
    return Intl.message('Network Fix', name: 'networkFix', desc: '', args: []);
  }

  /// `Fix system network globe icon issue`
  String get networkFixDesc {
    return Intl.message(
      'Fix system network globe icon issue',
      name: 'networkFixDesc',
      desc: '',
      args: [],
    );
  }

  /// `High Priority`
  String get highPriority {
    return Intl.message(
      'High Priority',
      name: 'highPriority',
      desc: '',
      args: [],
    );
  }

  /// `Increase priority of main process and core process`
  String get highPriorityDesc {
    return Intl.message(
      'Increase priority of main process and core process',
      name: 'highPriorityDesc',
      desc: '',
      args: [],
    );
  }

  /// `Battery Optimization`
  String get batteryOptimization {
    return Intl.message(
      'Battery Optimization',
      name: 'batteryOptimization',
      desc: '',
      args: [],
    );
  }

  /// `Request battery optimization whitelist`
  String get batteryOptimizationDesc {
    return Intl.message(
      'Request battery optimization whitelist',
      name: 'batteryOptimizationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Already in whitelist`
  String get alreadyInWhitelist {
    return Intl.message(
      'Already in whitelist',
      name: 'alreadyInWhitelist',
      desc: '',
      args: [],
    );
  }

  /// `About`
  String get about {
    return Intl.message('About', name: 'about', desc: '', args: []);
  }

  /// `Theme`
  String get theme {
    return Intl.message('Theme', name: 'theme', desc: '', args: []);
  }

  /// `Set theme color and icon`
  String get themeDesc {
    return Intl.message(
      'Set theme color and icon',
      name: 'themeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Override`
  String get override {
    return Intl.message('Override', name: 'override', desc: '', args: []);
  }

  /// `Override proxy configurations`
  String get overrideDesc {
    return Intl.message(
      'Override proxy configurations',
      name: 'overrideDesc',
      desc: '',
      args: [],
    );
  }

  /// `Allow LAN`
  String get allowLan {
    return Intl.message('Allow LAN', name: 'allowLan', desc: '', args: []);
  }

  /// `Allow LAN access to proxy`
  String get allowLanDesc {
    return Intl.message(
      'Allow LAN access to proxy',
      name: 'allowLanDesc',
      desc: '',
      args: [],
    );
  }

  /// `User Authentication`
  String get userAuth {
    return Intl.message(
      'User Authentication',
      name: 'userAuth',
      desc: '',
      args: [],
    );
  }

  /// `Skip Local Authentication`
  String get skipLocalAuth {
    return Intl.message(
      'Skip Local Authentication',
      name: 'skipLocalAuth',
      desc: '',
      args: [],
    );
  }

  /// `Allow local machine to access proxy without credentials`
  String get skipLocalAuthDesc {
    return Intl.message(
      'Allow local machine to access proxy without credentials',
      name: 'skipLocalAuthDesc',
      desc: '',
      args: [],
    );
  }

  /// `Add User`
  String get addUser {
    return Intl.message('Add User', name: 'addUser', desc: '', args: []);
  }

  /// `Username cannot contain colons`
  String get usernameCannotContainColon {
    return Intl.message(
      'Username cannot contain colons',
      name: 'usernameCannotContainColon',
      desc: '',
      args: [],
    );
  }

  /// `TUN`
  String get tun {
    return Intl.message('TUN', name: 'tun', desc: '', args: []);
  }

  /// `Use TUN to take over device traffic`
  String get tunDesc {
    return Intl.message(
      'Use TUN to take over device traffic',
      name: 'tunDesc',
      desc: '',
      args: [],
    );
  }

  /// `Minimize on Exit`
  String get minimizeOnExit {
    return Intl.message(
      'Minimize on Exit',
      name: 'minimizeOnExit',
      desc: '',
      args: [],
    );
  }

  /// `Override default exit behavior`
  String get minimizeOnExitDesc {
    return Intl.message(
      'Override default exit behavior',
      name: 'minimizeOnExitDesc',
      desc: '',
      args: [],
    );
  }

  /// `Auto Launch`
  String get autoLaunch {
    return Intl.message('Auto Launch', name: 'autoLaunch', desc: '', args: []);
  }

  /// `Launch on system startup`
  String get autoLaunchDesc {
    return Intl.message(
      'Launch on system startup',
      name: 'autoLaunchDesc',
      desc: '',
      args: [],
    );
  }

  /// `Smart Delay`
  String get smartDelayLaunch {
    return Intl.message(
      'Smart Delay',
      name: 'smartDelayLaunch',
      desc: '',
      args: [],
    );
  }

  /// `Launch after network connected`
  String get smartDelayLaunchDesc {
    return Intl.message(
      'Launch after network connected',
      name: 'smartDelayLaunchDesc',
      desc: '',
      args: [],
    );
  }

  /// `Silent Launch`
  String get silentLaunch {
    return Intl.message(
      'Silent Launch',
      name: 'silentLaunch',
      desc: '',
      args: [],
    );
  }

  /// `Start in the background`
  String get silentLaunchDesc {
    return Intl.message(
      'Start in the background',
      name: 'silentLaunchDesc',
      desc: '',
      args: [],
    );
  }

  /// `Auto Run`
  String get autoRun {
    return Intl.message('Auto Run', name: 'autoRun', desc: '', args: []);
  }

  /// `Connect on app launch`
  String get autoRunDesc {
    return Intl.message(
      'Connect on app launch',
      name: 'autoRunDesc',
      desc: '',
      args: [],
    );
  }

  /// `Log Capture`
  String get logcat {
    return Intl.message('Log Capture', name: 'logcat', desc: '', args: []);
  }

  /// `Show log capture entry`
  String get logcatDesc {
    return Intl.message(
      'Show log capture entry',
      name: 'logcatDesc',
      desc: '',
      args: [],
    );
  }

  /// `Crash Analytics`
  String get enableCrashReport {
    return Intl.message(
      'Crash Analytics',
      name: 'enableCrashReport',
      desc: '',
      args: [],
    );
  }

  /// `Upload crash logs when needed`
  String get enableCrashReportDesc {
    return Intl.message(
      'Upload crash logs when needed',
      name: 'enableCrashReportDesc',
      desc: '',
      args: [],
    );
  }

  /// `Auto Check Updates`
  String get autoCheckUpdate {
    return Intl.message(
      'Auto Check Updates',
      name: 'autoCheckUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Check updates on app launch`
  String get autoCheckUpdateDesc {
    return Intl.message(
      'Check updates on app launch',
      name: 'autoCheckUpdateDesc',
      desc: '',
      args: [],
    );
  }

  /// `Access Control`
  String get accessControl {
    return Intl.message(
      'Access Control',
      name: 'accessControl',
      desc: '',
      args: [],
    );
  }

  /// `Configure per-app access allowlist/blocklist`
  String get accessControlDesc {
    return Intl.message(
      'Configure per-app access allowlist/blocklist',
      name: 'accessControlDesc',
      desc: '',
      args: [],
    );
  }

  /// `Clear Cache`
  String get clearCacheTitle {
    return Intl.message(
      'Clear Cache',
      name: 'clearCacheTitle',
      desc: '',
      args: [],
    );
  }

  /// `Clear FakeIP and DNS cache?`
  String get clearCacheDesc {
    return Intl.message(
      'Clear FakeIP and DNS cache?',
      name: 'clearCacheDesc',
      desc: '',
      args: [],
    );
  }

  /// `Force Garbage Collection`
  String get forceGCTitle {
    return Intl.message(
      'Force Garbage Collection',
      name: 'forceGCTitle',
      desc: '',
      args: [],
    );
  }

  /// `Force kernel garbage collection? Experimental, use with caution.`
  String get forceGCDesc {
    return Intl.message(
      'Force kernel garbage collection? Experimental, use with caution.',
      name: 'forceGCDesc',
      desc: '',
      args: [],
    );
  }

  /// `FCM connection and support depend on the device itself, the results are for reference only. Due to system permission reasons, you need to disable "Allow bypass VPN" in settings to get accurate results`
  String get fcmTip {
    return Intl.message(
      'FCM connection and support depend on the device itself, the results are for reference only. Due to system permission reasons, you need to disable "Allow bypass VPN" in settings to get accurate results',
      name: 'fcmTip',
      desc: '',
      args: [],
    );
  }

  /// `Application`
  String get application {
    return Intl.message('Application', name: 'application', desc: '', args: []);
  }

  /// `Modify application settings`
  String get applicationDesc {
    return Intl.message(
      'Modify application settings',
      name: 'applicationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Edit`
  String get edit {
    return Intl.message('Edit', name: 'edit', desc: '', args: []);
  }

  /// `Confirm`
  String get confirm {
    return Intl.message('Confirm', name: 'confirm', desc: '', args: []);
  }

  /// `Update`
  String get update {
    return Intl.message('Update', name: 'update', desc: '', args: []);
  }

  /// `Add`
  String get add {
    return Intl.message('Add', name: 'add', desc: '', args: []);
  }

  /// `Save`
  String get save {
    return Intl.message('Save', name: 'save', desc: '', args: []);
  }

  /// `Delete`
  String get delete {
    return Intl.message('Delete', name: 'delete', desc: '', args: []);
  }

  /// `{count, plural, one{year} other{years}}`
  String years(num count) {
    return Intl.plural(
      count,
      one: 'year',
      other: 'years',
      name: 'years',
      desc: '',
      args: [count],
    );
  }

  /// `{count, plural, one{month} other{months}}`
  String months(num count) {
    return Intl.plural(
      count,
      one: 'month',
      other: 'months',
      name: 'months',
      desc: '',
      args: [count],
    );
  }

  /// `{count, plural, one{hour} other{hours}}`
  String hours(num count) {
    return Intl.plural(
      count,
      one: 'hour',
      other: 'hours',
      name: 'hours',
      desc: '',
      args: [count],
    );
  }

  /// `{count, plural, one{day} other{days}}`
  String days(num count) {
    return Intl.plural(
      count,
      one: 'day',
      other: 'days',
      name: 'days',
      desc: '',
      args: [count],
    );
  }

  /// `{count, plural, one{minute} other{minutes}}`
  String minutes(num count) {
    return Intl.plural(
      count,
      one: 'minute',
      other: 'minutes',
      name: 'minutes',
      desc: '',
      args: [count],
    );
  }

  /// `Seconds`
  String get seconds {
    return Intl.message('Seconds', name: 'seconds', desc: '', args: []);
  }

  /// ` ago`
  String get ago {
    return Intl.message(' ago', name: 'ago', desc: '', args: []);
  }

  /// `Please close TUN first`
  String get pleaseCloseTunFirst {
    return Intl.message(
      'Please close TUN first',
      name: 'pleaseCloseTunFirst',
      desc: '',
      args: [],
    );
  }

  /// `Please close System Proxy first`
  String get pleaseCloseSystemProxyFirst {
    return Intl.message(
      'Please close System Proxy first',
      name: 'pleaseCloseSystemProxyFirst',
      desc: '',
      args: [],
    );
  }

  /// `Just now`
  String get just {
    return Intl.message('Just now', name: 'just', desc: '', args: []);
  }

  /// `QR Code`
  String get qrcode {
    return Intl.message('QR Code', name: 'qrcode', desc: '', args: []);
  }

  /// `Scan QR code to get profile`
  String get qrcodeDesc {
    return Intl.message(
      'Scan QR code to get profile',
      name: 'qrcodeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Clipboard`
  String get clipboard {
    return Intl.message('Clipboard', name: 'clipboard', desc: '', args: []);
  }

  /// `Get profile link from clipboard`
  String get clipboardDesc {
    return Intl.message(
      'Get profile link from clipboard',
      name: 'clipboardDesc',
      desc: '',
      args: [],
    );
  }

  /// `URL`
  String get url {
    return Intl.message('URL', name: 'url', desc: '', args: []);
  }

  /// `Get profile via URL`
  String get urlDesc {
    return Intl.message(
      'Get profile via URL',
      name: 'urlDesc',
      desc: '',
      args: [],
    );
  }

  /// `File`
  String get file {
    return Intl.message('File', name: 'file', desc: '', args: []);
  }

  /// `Upload profile file`
  String get fileDesc {
    return Intl.message(
      'Upload profile file',
      name: 'fileDesc',
      desc: '',
      args: [],
    );
  }

  /// `Name`
  String get name {
    return Intl.message('Name', name: 'name', desc: '', args: []);
  }

  /// `Please enter a profile name`
  String get profileNameNullValidationDesc {
    return Intl.message(
      'Please enter a profile name',
      name: 'profileNameNullValidationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a profile URL`
  String get profileUrlNullValidationDesc {
    return Intl.message(
      'Please enter a profile URL',
      name: 'profileUrlNullValidationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid URL`
  String get profileUrlInvalidValidationDesc {
    return Intl.message(
      'Please enter a valid URL',
      name: 'profileUrlInvalidValidationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Auto Update`
  String get autoUpdate {
    return Intl.message('Auto Update', name: 'autoUpdate', desc: '', args: []);
  }

  /// `Auto update interval (min)`
  String get autoUpdateInterval {
    return Intl.message(
      'Auto update interval (min)',
      name: 'autoUpdateInterval',
      desc: '',
      args: [],
    );
  }

  /// `Please enter update interval`
  String get profileAutoUpdateIntervalNullValidationDesc {
    return Intl.message(
      'Please enter update interval',
      name: 'profileAutoUpdateIntervalNullValidationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid interval`
  String get profileAutoUpdateIntervalInvalidValidationDesc {
    return Intl.message(
      'Please enter a valid interval',
      name: 'profileAutoUpdateIntervalInvalidValidationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Theme Mode`
  String get themeMode {
    return Intl.message('Theme Mode', name: 'themeMode', desc: '', args: []);
  }

  /// `Theme Color`
  String get themeColor {
    return Intl.message('Theme Color', name: 'themeColor', desc: '', args: []);
  }

  /// `Preview`
  String get preview {
    return Intl.message('Preview', name: 'preview', desc: '', args: []);
  }

  /// `Runtime Config`
  String get runtimeConfig {
    return Intl.message(
      'Runtime Config',
      name: 'runtimeConfig',
      desc: '',
      args: [],
    );
  }

  /// `Camera Permission Denied`
  String get cameraPermissionDenied {
    return Intl.message(
      'Camera Permission Denied',
      name: 'cameraPermissionDenied',
      desc: '',
      args: [],
    );
  }

  /// `Camera permission is required to scan QR codes. Please grant it in settings.`
  String get cameraPermissionDesc {
    return Intl.message(
      'Camera permission is required to scan QR codes. Please grant it in settings.',
      name: 'cameraPermissionDesc',
      desc: '',
      args: [],
    );
  }

  /// `Open Settings`
  String get openSettings {
    return Intl.message(
      'Open Settings',
      name: 'openSettings',
      desc: '',
      args: [],
    );
  }

  /// `Retry`
  String get retry {
    return Intl.message('Retry', name: 'retry', desc: '', args: []);
  }

  /// `Permission to access installed apps is required. Grant now?`
  String get packageListPermissionRequired {
    return Intl.message(
      'Permission to access installed apps is required. Grant now?',
      name: 'packageListPermissionRequired',
      desc: '',
      args: [],
    );
  }

  /// `Permission denied. Cannot access app list.`
  String get packageListPermissionDenied {
    return Intl.message(
      'Permission denied. Cannot access app list.',
      name: 'packageListPermissionDenied',
      desc: '',
      args: [],
    );
  }

  /// `Auto`
  String get auto {
    return Intl.message('Auto', name: 'auto', desc: '', args: []);
  }

  /// `Light`
  String get light {
    return Intl.message('Light', name: 'light', desc: '', args: []);
  }

  /// `Dark`
  String get dark {
    return Intl.message('Dark', name: 'dark', desc: '', args: []);
  }

  /// `Import from URL`
  String get importFromURL {
    return Intl.message(
      'Import from URL',
      name: 'importFromURL',
      desc: '',
      args: [],
    );
  }

  /// `Submit`
  String get submit {
    return Intl.message('Submit', name: 'submit', desc: '', args: []);
  }

  /// `Do you want to pass`
  String get doYouWantToPass {
    return Intl.message(
      'Do you want to pass',
      name: 'doYouWantToPass',
      desc: '',
      args: [],
    );
  }

  /// `Create`
  String get create {
    return Intl.message('Create', name: 'create', desc: '', args: []);
  }

  /// `Default Sort`
  String get defaultSort {
    return Intl.message(
      'Default Sort',
      name: 'defaultSort',
      desc: '',
      args: [],
    );
  }

  /// `Sort by Delay`
  String get delaySort {
    return Intl.message('Sort by Delay', name: 'delaySort', desc: '', args: []);
  }

  /// `Sort by Name`
  String get nameSort {
    return Intl.message('Sort by Name', name: 'nameSort', desc: '', args: []);
  }

  /// `Please upload a file`
  String get pleaseUploadFile {
    return Intl.message(
      'Please upload a file',
      name: 'pleaseUploadFile',
      desc: '',
      args: [],
    );
  }

  /// `Please upload a valid QR code`
  String get pleaseUploadValidQrcode {
    return Intl.message(
      'Please upload a valid QR code',
      name: 'pleaseUploadValidQrcode',
      desc: '',
      args: [],
    );
  }

  /// `Blacklist Mode`
  String get blacklistMode {
    return Intl.message(
      'Blacklist Mode',
      name: 'blacklistMode',
      desc: '',
      args: [],
    );
  }

  /// `Whitelist Mode`
  String get whitelistMode {
    return Intl.message(
      'Whitelist Mode',
      name: 'whitelistMode',
      desc: '',
      args: [],
    );
  }

  /// `Filter System Apps`
  String get filterSystemApp {
    return Intl.message(
      'Filter System Apps',
      name: 'filterSystemApp',
      desc: '',
      args: [],
    );
  }

  /// `Show System Apps`
  String get cancelFilterSystemApp {
    return Intl.message(
      'Show System Apps',
      name: 'cancelFilterSystemApp',
      desc: '',
      args: [],
    );
  }

  /// `Select All`
  String get selectAll {
    return Intl.message('Select All', name: 'selectAll', desc: '', args: []);
  }

  /// `Deselect All`
  String get cancelSelectAll {
    return Intl.message(
      'Deselect All',
      name: 'cancelSelectAll',
      desc: '',
      args: [],
    );
  }

  /// `App Access Control`
  String get appAccessControl {
    return Intl.message(
      'App Access Control',
      name: 'appAccessControl',
      desc: '',
      args: [],
    );
  }

  /// `Only route selected apps through VPN`
  String get accessControlAllowDesc {
    return Intl.message(
      'Only route selected apps through VPN',
      name: 'accessControlAllowDesc',
      desc: '',
      args: [],
    );
  }

  /// `Exclude selected apps from VPN`
  String get accessControlNotAllowDesc {
    return Intl.message(
      'Exclude selected apps from VPN',
      name: 'accessControlNotAllowDesc',
      desc: '',
      args: [],
    );
  }

  /// `Selected`
  String get selected {
    return Intl.message('Selected', name: 'selected', desc: '', args: []);
  }

  /// `Unable to update current profile`
  String get unableToUpdateCurrentProfileDesc {
    return Intl.message(
      'Unable to update current profile',
      name: 'unableToUpdateCurrentProfileDesc',
      desc: '',
      args: [],
    );
  }

  /// `No more info`
  String get noMoreInfoDesc {
    return Intl.message(
      'No more info',
      name: 'noMoreInfoDesc',
      desc: '',
      args: [],
    );
  }

  /// `Profile parse error`
  String get profileParseErrorDesc {
    return Intl.message(
      'Profile parse error',
      name: 'profileParseErrorDesc',
      desc: '',
      args: [],
    );
  }

  /// `Proxy Port`
  String get proxyPort {
    return Intl.message('Proxy Port', name: 'proxyPort', desc: '', args: []);
  }

  /// `Set the Clash listening port`
  String get proxyPortDesc {
    return Intl.message(
      'Set the Clash listening port',
      name: 'proxyPortDesc',
      desc: '',
      args: [],
    );
  }

  /// `Port`
  String get port {
    return Intl.message('Port', name: 'port', desc: '', args: []);
  }

  /// `Log Level`
  String get logLevel {
    return Intl.message('Log Level', name: 'logLevel', desc: '', args: []);
  }

  /// `Show`
  String get show {
    return Intl.message('Show', name: 'show', desc: '', args: []);
  }

  /// `Exit`
  String get exit {
    return Intl.message('Exit', name: 'exit', desc: '', args: []);
  }

  /// `System Proxy`
  String get systemProxy {
    return Intl.message(
      'System Proxy',
      name: 'systemProxy',
      desc: '',
      args: [],
    );
  }

  /// `Project`
  String get project {
    return Intl.message('Project', name: 'project', desc: '', args: []);
  }

  /// `Core`
  String get core {
    return Intl.message('Core', name: 'core', desc: '', args: []);
  }

  /// `Linkage Switch`
  String get showStartSwitch {
    return Intl.message(
      'Linkage Switch',
      name: 'showStartSwitch',
      desc: '',
      args: [],
    );
  }

  /// `Display independent switch button on the homepage`
  String get showStartSwitchDesc {
    return Intl.message(
      'Display independent switch button on the homepage',
      name: 'showStartSwitchDesc',
      desc: '',
      args: [],
    );
  }

  /// `Fluxora is based on the powerful and flexible Mihomo (Clash.Meta) proxy kernel, dedicated to a superior user experience. Our vision: Clear routes, calm control`
  String get desc {
    return Intl.message(
      'Fluxora is based on the powerful and flexible Mihomo (Clash.Meta) proxy kernel, dedicated to a superior user experience. Our vision: Clear routes, calm control',
      name: 'desc',
      desc: '',
      args: [],
    );
  }

  /// `Starting...`
  String get startVpn {
    return Intl.message('Starting...', name: 'startVpn', desc: '', args: []);
  }

  /// `Stopping...`
  String get stopVpn {
    return Intl.message('Stopping...', name: 'stopVpn', desc: '', args: []);
  }

  /// `New Version Found`
  String get discovery {
    return Intl.message(
      'New Version Found',
      name: 'discovery',
      desc: '',
      args: [],
    );
  }

  /// `Compatible Mode`
  String get compatible {
    return Intl.message(
      'Compatible Mode',
      name: 'compatible',
      desc: '',
      args: [],
    );
  }

  /// `Enabling this mode may limit some features, but provides full Clash support`
  String get compatibleDesc {
    return Intl.message(
      'Enabling this mode may limit some features, but provides full Clash support',
      name: 'compatibleDesc',
      desc: '',
      args: [],
    );
  }

  /// `Current proxy group cannot be selected.`
  String get notSelectedTip {
    return Intl.message(
      'Current proxy group cannot be selected.',
      name: 'notSelectedTip',
      desc: '',
      args: [],
    );
  }

  /// `Tip`
  String get tip {
    return Intl.message('Tip', name: 'tip', desc: '', args: []);
  }

  /// `Backup & Restore`
  String get backupAndRecovery {
    return Intl.message(
      'Backup & Restore',
      name: 'backupAndRecovery',
      desc: '',
      args: [],
    );
  }

  /// `Sync data via WebDAV or locally`
  String get backupAndRecoveryDesc {
    return Intl.message(
      'Sync data via WebDAV or locally',
      name: 'backupAndRecoveryDesc',
      desc: '',
      args: [],
    );
  }

  /// `Account`
  String get account {
    return Intl.message('Account', name: 'account', desc: '', args: []);
  }

  /// `Backup`
  String get backup {
    return Intl.message('Backup', name: 'backup', desc: '', args: []);
  }

  /// `Restore`
  String get recovery {
    return Intl.message('Restore', name: 'recovery', desc: '', args: []);
  }

  /// `Restore Profiles Only`
  String get recoveryProfiles {
    return Intl.message(
      'Restore Profiles Only',
      name: 'recoveryProfiles',
      desc: '',
      args: [],
    );
  }

  /// `Restore All Data`
  String get recoveryAll {
    return Intl.message(
      'Restore All Data',
      name: 'recoveryAll',
      desc: '',
      args: [],
    );
  }

  /// `Restore Successful`
  String get recoverySuccess {
    return Intl.message(
      'Restore Successful',
      name: 'recoverySuccess',
      desc: '',
      args: [],
    );
  }

  /// `Select Backup Version`
  String get selectBackupVersion {
    return Intl.message(
      'Select Backup Version',
      name: 'selectBackupVersion',
      desc: '',
      args: [],
    );
  }

  /// `No backup file found`
  String get noBackupFileFound {
    return Intl.message(
      'No backup file found',
      name: 'noBackupFileFound',
      desc: '',
      args: [],
    );
  }

  /// `Legacy backup`
  String get legacyBackup {
    return Intl.message(
      'Legacy backup',
      name: 'legacyBackup',
      desc: '',
      args: [],
    );
  }

  /// `Backup Successful`
  String get backupSuccess {
    return Intl.message(
      'Backup Successful',
      name: 'backupSuccess',
      desc: '',
      args: [],
    );
  }

  /// `No Info`
  String get noInfo {
    return Intl.message('No Info', name: 'noInfo', desc: '', args: []);
  }

  /// `Please bind WebDAV`
  String get pleaseBindWebDAV {
    return Intl.message(
      'Please bind WebDAV',
      name: 'pleaseBindWebDAV',
      desc: '',
      args: [],
    );
  }

  /// `Bind`
  String get bind {
    return Intl.message('Bind', name: 'bind', desc: '', args: []);
  }

  /// `Connectivity:`
  String get connectivity {
    return Intl.message(
      'Connectivity:',
      name: 'connectivity',
      desc: '',
      args: [],
    );
  }

  /// `WebDAV Configuration`
  String get webDAVConfiguration {
    return Intl.message(
      'WebDAV Configuration',
      name: 'webDAVConfiguration',
      desc: '',
      args: [],
    );
  }

  /// `Address`
  String get address {
    return Intl.message('Address', name: 'address', desc: '', args: []);
  }

  /// `WebDAV server address`
  String get addressHelp {
    return Intl.message(
      'WebDAV server address',
      name: 'addressHelp',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid WebDAV address`
  String get addressTip {
    return Intl.message(
      'Please enter a valid WebDAV address',
      name: 'addressTip',
      desc: '',
      args: [],
    );
  }

  /// `Password`
  String get password {
    return Intl.message('Password', name: 'password', desc: '', args: []);
  }

  /// `Check for Updates`
  String get checkUpdate {
    return Intl.message(
      'Check for Updates',
      name: 'checkUpdate',
      desc: '',
      args: [],
    );
  }

  /// `New Version Available`
  String get discoverNewVersion {
    return Intl.message(
      'New Version Available',
      name: 'discoverNewVersion',
      desc: '',
      args: [],
    );
  }

  /// `Already on the latest version`
  String get checkUpdateError {
    return Intl.message(
      'Already on the latest version',
      name: 'checkUpdateError',
      desc: '',
      args: [],
    );
  }

  /// `Download Now`
  String get goDownload {
    return Intl.message('Download Now', name: 'goDownload', desc: '', args: []);
  }

  /// `Unknown`
  String get unknown {
    return Intl.message('Unknown', name: 'unknown', desc: '', args: []);
  }

  /// `GeoData`
  String get geoData {
    return Intl.message('GeoData', name: 'geoData', desc: '', args: []);
  }

  /// `External Resources`
  String get externalResources {
    return Intl.message(
      'External Resources',
      name: 'externalResources',
      desc: '',
      args: [],
    );
  }

  /// `Checking...`
  String get checking {
    return Intl.message('Checking...', name: 'checking', desc: '', args: []);
  }

  /// `Country`
  String get country {
    return Intl.message('Country', name: 'country', desc: '', args: []);
  }

  /// `Probe chain`
  String get chainProbeNow {
    return Intl.message(
      'Probe chain',
      name: 'chainProbeNow',
      desc: '',
      args: [],
    );
  }

  /// `Check Failed`
  String get checkError {
    return Intl.message('Check Failed', name: 'checkError', desc: '', args: []);
  }

  /// `Search`
  String get search {
    return Intl.message('Search', name: 'search', desc: '', args: []);
  }

  /// `Replace`
  String get replace {
    return Intl.message('Replace', name: 'replace', desc: '', args: []);
  }

  /// `Replace All`
  String get replaceAll {
    return Intl.message('Replace All', name: 'replaceAll', desc: '', args: []);
  }

  /// `Allow Bypassing VPN`
  String get allowBypass {
    return Intl.message(
      'Allow Bypassing VPN',
      name: 'allowBypass',
      desc: '',
      args: [],
    );
  }

  /// `Allow specific apps to bypass VPN`
  String get allowBypassDesc {
    return Intl.message(
      'Allow specific apps to bypass VPN',
      name: 'allowBypassDesc',
      desc: '',
      args: [],
    );
  }

  /// `External Controller`
  String get externalController {
    return Intl.message(
      'External Controller',
      name: 'externalController',
      desc: '',
      args: [],
    );
  }

  /// `Control core via online port`
  String get externalControllerDesc {
    return Intl.message(
      'Control core via online port',
      name: 'externalControllerDesc',
      desc: '',
      args: [],
    );
  }

  /// `Control Secret`
  String get controlSecret {
    return Intl.message(
      'Control Secret',
      name: 'controlSecret',
      desc: '',
      args: [],
    );
  }

  /// `RESTful API access password`
  String get controlSecretDesc {
    return Intl.message(
      'RESTful API access password',
      name: 'controlSecretDesc',
      desc: '',
      args: [],
    );
  }

  /// `Generate`
  String get generateSecret {
    return Intl.message('Generate', name: 'generateSecret', desc: '', args: []);
  }

  /// `Secret copied to clipboard`
  String get secretCopied {
    return Intl.message(
      'Secret copied to clipboard',
      name: 'secretCopied',
      desc: '',
      args: [],
    );
  }

  /// `Enable IPv6 traffic routing`
  String get ipv6Desc {
    return Intl.message(
      'Enable IPv6 traffic routing',
      name: 'ipv6Desc',
      desc: '',
      args: [],
    );
  }

  /// `App`
  String get app {
    return Intl.message('App', name: 'app', desc: '', args: []);
  }

  /// `General`
  String get general {
    return Intl.message('General', name: 'general', desc: '', args: []);
  }

  /// `Attach HTTP proxy to VpnService`
  String get vpnSystemProxyDesc {
    return Intl.message(
      'Attach HTTP proxy to VpnService',
      name: 'vpnSystemProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `HTTP proxy is generally not recommended on non-desktop platforms. Only enable this feature when necessary and you fully understand the implications.`
  String get vpnSystemProxyConfirmDesc {
    return Intl.message(
      'HTTP proxy is generally not recommended on non-desktop platforms. Only enable this feature when necessary and you fully understand the implications.',
      name: 'vpnSystemProxyConfirmDesc',
      desc: '',
      args: [],
    );
  }

  /// `Set system proxy`
  String get systemProxyDesc {
    return Intl.message(
      'Set system proxy',
      name: 'systemProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Unified Delay`
  String get unifiedDelay {
    return Intl.message(
      'Unified Delay',
      name: 'unifiedDelay',
      desc: '',
      args: [],
    );
  }

  /// `Exclude handshake delays from testing`
  String get unifiedDelayDesc {
    return Intl.message(
      'Exclude handshake delays from testing',
      name: 'unifiedDelayDesc',
      desc: '',
      args: [],
    );
  }

  /// `TCP Concurrent`
  String get tcpConcurrent {
    return Intl.message(
      'TCP Concurrent',
      name: 'tcpConcurrent',
      desc: '',
      args: [],
    );
  }

  /// `Allow concurrent TCP connections`
  String get tcpConcurrentDesc {
    return Intl.message(
      'Allow concurrent TCP connections',
      name: 'tcpConcurrentDesc',
      desc: '',
      args: [],
    );
  }

  /// `GEO Low Memory`
  String get geodataLoader {
    return Intl.message(
      'GEO Low Memory',
      name: 'geodataLoader',
      desc: '',
      args: [],
    );
  }

  /// `Use GEO low memory loader`
  String get geodataLoaderDesc {
    return Intl.message(
      'Use GEO low memory loader',
      name: 'geodataLoaderDesc',
      desc: '',
      args: [],
    );
  }

  /// `Requests`
  String get requests {
    return Intl.message('Requests', name: 'requests', desc: '', args: []);
  }

  /// `View recent request logs`
  String get requestsDesc {
    return Intl.message(
      'View recent request logs',
      name: 'requestsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Find Process`
  String get findProcessMode {
    return Intl.message(
      'Find Process',
      name: 'findProcessMode',
      desc: '',
      args: [],
    );
  }

  /// `Init`
  String get init {
    return Intl.message('Init', name: 'init', desc: '', args: []);
  }

  /// `Never Expires`
  String get infiniteTime {
    return Intl.message(
      'Never Expires',
      name: 'infiniteTime',
      desc: '',
      args: [],
    );
  }

  /// `Expiration Time`
  String get expirationTime {
    return Intl.message(
      'Expiration Time',
      name: 'expirationTime',
      desc: '',
      args: [],
    );
  }

  /// `Connections`
  String get connections {
    return Intl.message('Connections', name: 'connections', desc: '', args: []);
  }

  /// `View active connections`
  String get connectionsDesc {
    return Intl.message(
      'View active connections',
      name: 'connectionsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Local IP`
  String get intranetIP {
    return Intl.message('Local IP', name: 'intranetIP', desc: '', args: []);
  }

  /// `View`
  String get view {
    return Intl.message('View', name: 'view', desc: '', args: []);
  }

  /// `Cut`
  String get cut {
    return Intl.message('Cut', name: 'cut', desc: '', args: []);
  }

  /// `Copy`
  String get copy {
    return Intl.message('Copy', name: 'copy', desc: '', args: []);
  }

  /// `Paste`
  String get paste {
    return Intl.message('Paste', name: 'paste', desc: '', args: []);
  }

  /// `Test URL`
  String get testUrl {
    return Intl.message('Test URL', name: 'testUrl', desc: '', args: []);
  }

  /// `Delay Test`
  String get startTest {
    return Intl.message('Delay Test', name: 'startTest', desc: '', args: []);
  }

  /// `Add Profile`
  String get addProfile {
    return Intl.message('Add Profile', name: 'addProfile', desc: '', args: []);
  }

  /// `Custom URL`
  String get customUrl {
    return Intl.message('Custom URL', name: 'customUrl', desc: '', args: []);
  }

  /// `Sync`
  String get sync {
    return Intl.message('Sync', name: 'sync', desc: '', args: []);
  }

  /// `Hide from Recents`
  String get exclude {
    return Intl.message(
      'Hide from Recents',
      name: 'exclude',
      desc: '',
      args: [],
    );
  }

  /// `Hide app from recent tasks list`
  String get excludeDesc {
    return Intl.message(
      'Hide app from recent tasks list',
      name: 'excludeDesc',
      desc: '',
      args: [],
    );
  }

  /// `1 Column`
  String get oneColumn {
    return Intl.message('1 Column', name: 'oneColumn', desc: '', args: []);
  }

  /// `2 Columns`
  String get twoColumns {
    return Intl.message('2 Columns', name: 'twoColumns', desc: '', args: []);
  }

  /// `3 Columns`
  String get threeColumns {
    return Intl.message('3 Columns', name: 'threeColumns', desc: '', args: []);
  }

  /// `4 Columns`
  String get fourColumns {
    return Intl.message('4 Columns', name: 'fourColumns', desc: '', args: []);
  }

  /// `Standard`
  String get expand {
    return Intl.message('Standard', name: 'expand', desc: '', args: []);
  }

  /// `Compact`
  String get shrink {
    return Intl.message('Compact', name: 'shrink', desc: '', args: []);
  }

  /// `Min`
  String get min {
    return Intl.message('Min', name: 'min', desc: '', args: []);
  }

  /// `Tab`
  String get tab {
    return Intl.message('Tab', name: 'tab', desc: '', args: []);
  }

  /// `List`
  String get list {
    return Intl.message('List', name: 'list', desc: '', args: []);
  }

  /// `Delay`
  String get delay {
    return Intl.message('Delay', name: 'delay', desc: '', args: []);
  }

  /// `Style`
  String get style {
    return Intl.message('Style', name: 'style', desc: '', args: []);
  }

  /// `Size`
  String get size {
    return Intl.message('Size', name: 'size', desc: '', args: []);
  }

  /// `Delay Animation`
  String get delayAnimation {
    return Intl.message(
      'Delay Animation',
      name: 'delayAnimation',
      desc: '',
      args: [],
    );
  }

  /// `Sync animation to other pages`
  String get syncDelayAnimation {
    return Intl.message(
      'Sync animation to other pages',
      name: 'syncDelayAnimation',
      desc: '',
      args: [],
    );
  }

  /// `Customize animation during delay testing`
  String get delayAnimationDesc {
    return Intl.message(
      'Customize animation during delay testing',
      name: 'delayAnimationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Default`
  String get noAnimation {
    return Intl.message('Default', name: 'noAnimation', desc: '', args: []);
  }

  /// `Rotating Circle`
  String get rotatingCircle {
    return Intl.message(
      'Rotating Circle',
      name: 'rotatingCircle',
      desc: '',
      args: [],
    );
  }

  /// `Pulse`
  String get pulse {
    return Intl.message('Pulse', name: 'pulse', desc: '', args: []);
  }

  /// `Spinning Lines`
  String get spinningLines {
    return Intl.message(
      'Spinning Lines',
      name: 'spinningLines',
      desc: '',
      args: [],
    );
  }

  /// `Three In Out`
  String get threeInOut {
    return Intl.message('Three In Out', name: 'threeInOut', desc: '', args: []);
  }

  /// `Three Bounce`
  String get threeBounce {
    return Intl.message(
      'Three Bounce',
      name: 'threeBounce',
      desc: '',
      args: [],
    );
  }

  /// `Circle`
  String get circle {
    return Intl.message('Circle', name: 'circle', desc: '', args: []);
  }

  /// `Fading Circle`
  String get fadingCircle {
    return Intl.message(
      'Fading Circle',
      name: 'fadingCircle',
      desc: '',
      args: [],
    );
  }

  /// `Fading Four`
  String get fadingFour {
    return Intl.message('Fading Four', name: 'fadingFour', desc: '', args: []);
  }

  /// `Wave`
  String get wave {
    return Intl.message('Wave', name: 'wave', desc: '', args: []);
  }

  /// `Double Bounce`
  String get doubleBounce {
    return Intl.message(
      'Double Bounce',
      name: 'doubleBounce',
      desc: '',
      args: [],
    );
  }

  /// `Sort`
  String get sort {
    return Intl.message('Sort', name: 'sort', desc: '', args: []);
  }

  /// `Columns`
  String get columns {
    return Intl.message('Columns', name: 'columns', desc: '', args: []);
  }

  /// `Proxy Settings`
  String get proxiesSetting {
    return Intl.message(
      'Proxy Settings',
      name: 'proxiesSetting',
      desc: '',
      args: [],
    );
  }

  /// `Proxy Group`
  String get proxyGroup {
    return Intl.message('Proxy Group', name: 'proxyGroup', desc: '', args: []);
  }

  /// `Go`
  String get go {
    return Intl.message('Go', name: 'go', desc: '', args: []);
  }

  /// `External Link`
  String get externalLink {
    return Intl.message(
      'External Link',
      name: 'externalLink',
      desc: '',
      args: [],
    );
  }

  /// `Other Contributors (Random Order)`
  String get otherContributors {
    return Intl.message(
      'Other Contributors (Random Order)',
      name: 'otherContributors',
      desc: '',
      args: [],
    );
  }

  /// `Auto-Close Connections`
  String get autoCloseConnections {
    return Intl.message(
      'Auto-Close Connections',
      name: 'autoCloseConnections',
      desc: '',
      args: [],
    );
  }

  /// `Close connections when switching nodes`
  String get autoCloseConnectionsDesc {
    return Intl.message(
      'Close connections when switching nodes',
      name: 'autoCloseConnectionsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Proxy Traffic Only`
  String get onlyStatisticsProxy {
    return Intl.message(
      'Proxy Traffic Only',
      name: 'onlyStatisticsProxy',
      desc: '',
      args: [],
    );
  }

  /// `Only record proxy traffic`
  String get onlyStatisticsProxyDesc {
    return Intl.message(
      'Only record proxy traffic',
      name: 'onlyStatisticsProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Pure Black Mode`
  String get pureBlackMode {
    return Intl.message(
      'Pure Black Mode',
      name: 'pureBlackMode',
      desc: '',
      args: [],
    );
  }

  /// `TCP keep-alive interval`
  String get keepAliveIntervalDesc {
    return Intl.message(
      'TCP keep-alive interval',
      name: 'keepAliveIntervalDesc',
      desc: '',
      args: [],
    );
  }

  /// ` entries`
  String get entries {
    return Intl.message(' entries', name: 'entries', desc: '', args: []);
  }

  /// `Local`
  String get local {
    return Intl.message('Local', name: 'local', desc: '', args: []);
  }

  /// `Remote`
  String get remote {
    return Intl.message('Remote', name: 'remote', desc: '', args: []);
  }

  /// `Backup data to WebDAV`
  String get remoteBackupDesc {
    return Intl.message(
      'Backup data to WebDAV',
      name: 'remoteBackupDesc',
      desc: '',
      args: [],
    );
  }

  /// `Restore data from WebDAV`
  String get remoteRecoveryDesc {
    return Intl.message(
      'Restore data from WebDAV',
      name: 'remoteRecoveryDesc',
      desc: '',
      args: [],
    );
  }

  /// `Backup data locally`
  String get localBackupDesc {
    return Intl.message(
      'Backup data locally',
      name: 'localBackupDesc',
      desc: '',
      args: [],
    );
  }

  /// `Restore data from file`
  String get localRecoveryDesc {
    return Intl.message(
      'Restore data from file',
      name: 'localRecoveryDesc',
      desc: '',
      args: [],
    );
  }

  /// `Mode`
  String get mode {
    return Intl.message('Mode', name: 'mode', desc: '', args: []);
  }

  /// `Time`
  String get time {
    return Intl.message('Time', name: 'time', desc: '', args: []);
  }

  /// `Source`
  String get source {
    return Intl.message('Source', name: 'source', desc: '', args: []);
  }

  /// `All Apps`
  String get allApps {
    return Intl.message('All Apps', name: 'allApps', desc: '', args: []);
  }

  /// `Third-Party Apps Only`
  String get onlyOtherApps {
    return Intl.message(
      'Third-Party Apps Only',
      name: 'onlyOtherApps',
      desc: '',
      args: [],
    );
  }

  /// `Action`
  String get action {
    return Intl.message('Action', name: 'action', desc: '', args: []);
  }

  /// `Smart Select`
  String get intelligentSelected {
    return Intl.message(
      'Smart Select',
      name: 'intelligentSelected',
      desc: '',
      args: [],
    );
  }

  /// `Import from Clipboard`
  String get clipboardImport {
    return Intl.message(
      'Import from Clipboard',
      name: 'clipboardImport',
      desc: '',
      args: [],
    );
  }

  /// `Export to Clipboard`
  String get clipboardExport {
    return Intl.message(
      'Export to Clipboard',
      name: 'clipboardExport',
      desc: '',
      args: [],
    );
  }

  /// `Layout`
  String get layout {
    return Intl.message('Layout', name: 'layout', desc: '', args: []);
  }

  /// `Compact`
  String get tight {
    return Intl.message('Compact', name: 'tight', desc: '', args: []);
  }

  /// `Standard`
  String get standard {
    return Intl.message('Standard', name: 'standard', desc: '', args: []);
  }

  /// `Loose`
  String get loose {
    return Intl.message('Loose', name: 'loose', desc: '', args: []);
  }

  /// `Profile Sorting`
  String get profilesSort {
    return Intl.message(
      'Profile Sorting',
      name: 'profilesSort',
      desc: '',
      args: [],
    );
  }

  /// `Start`
  String get start {
    return Intl.message('Start', name: 'start', desc: '', args: []);
  }

  /// `No usage data`
  String get noUsageData {
    return Intl.message(
      'No usage data',
      name: 'noUsageData',
      desc: '',
      args: [],
    );
  }

  /// `Local File`
  String get localFile {
    return Intl.message('Local File', name: 'localFile', desc: '', args: []);
  }

  /// `Expired`
  String get expired {
    return Intl.message('Expired', name: 'expired', desc: '', args: []);
  }

  /// `Last edited`
  String get lastEdit {
    return Intl.message('Last edited', name: 'lastEdit', desc: '', args: []);
  }

  /// `Stop`
  String get stop {
    return Intl.message('Stop', name: 'stop', desc: '', args: []);
  }

  /// `Power`
  String get powerSwitch {
    return Intl.message('Power', name: 'powerSwitch', desc: '', args: []);
  }

  /// `Uptime`
  String get runTime {
    return Intl.message('Uptime', name: 'runTime', desc: '', args: []);
  }

  /// `Please add a profile first`
  String get checkOrAddProfile {
    return Intl.message(
      'Please add a profile first',
      name: 'checkOrAddProfile',
      desc: '',
      args: [],
    );
  }

  /// `Service Ready`
  String get serviceReady {
    return Intl.message(
      'Service Ready',
      name: 'serviceReady',
      desc: '',
      args: [],
    );
  }

  /// `App-related settings`
  String get appDesc {
    return Intl.message(
      'App-related settings',
      name: 'appDesc',
      desc: '',
      args: [],
    );
  }

  /// `VPN-related settings`
  String get vpnDesc {
    return Intl.message(
      'VPN-related settings',
      name: 'vpnDesc',
      desc: '',
      args: [],
    );
  }

  /// `DNS-related settings`
  String get dnsDesc {
    return Intl.message(
      'DNS-related settings',
      name: 'dnsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Key`
  String get key {
    return Intl.message('Key', name: 'key', desc: '', args: []);
  }

  /// `Value`
  String get value {
    return Intl.message('Value', name: 'value', desc: '', args: []);
  }

  /// `Append hosts to current config`
  String get hostsDesc {
    return Intl.message(
      'Append hosts to current config',
      name: 'hostsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Restart VPN to apply changes`
  String get vpnTip {
    return Intl.message(
      'Restart VPN to apply changes',
      name: 'vpnTip',
      desc: '',
      args: [],
    );
  }

  /// `Route system traffic via VpnService`
  String get vpnEnableDesc {
    return Intl.message(
      'Route system traffic via VpnService',
      name: 'vpnEnableDesc',
      desc: '',
      args: [],
    );
  }

  /// `Options`
  String get options {
    return Intl.message('Options', name: 'options', desc: '', args: []);
  }

  /// `Loopback Unlock`
  String get loopback {
    return Intl.message(
      'Loopback Unlock',
      name: 'loopback',
      desc: '',
      args: [],
    );
  }

  /// `UWP loopback unlocking tool`
  String get loopbackDesc {
    return Intl.message(
      'UWP loopback unlocking tool',
      name: 'loopbackDesc',
      desc: '',
      args: [],
    );
  }

  /// `Providers`
  String get providers {
    return Intl.message('Providers', name: 'providers', desc: '', args: []);
  }

  /// `Proxy Providers`
  String get proxyProviders {
    return Intl.message(
      'Proxy Providers',
      name: 'proxyProviders',
      desc: '',
      args: [],
    );
  }

  /// `Rule Providers`
  String get ruleProviders {
    return Intl.message(
      'Rule Providers',
      name: 'ruleProviders',
      desc: '',
      args: [],
    );
  }

  /// `Advanced Settings`
  String get advancedSettings {
    return Intl.message(
      'Advanced Settings',
      name: 'advancedSettings',
      desc: '',
      args: [],
    );
  }

  /// `Node Exclusion`
  String get nodeExclusion {
    return Intl.message(
      'Node Exclusion',
      name: 'nodeExclusion',
      desc: '',
      args: [],
    );
  }

  /// `Exclude all matched nodes`
  String get nodeExclusionDesc {
    return Intl.message(
      'Exclude all matched nodes',
      name: 'nodeExclusionDesc',
      desc: '',
      args: [],
    );
  }

  /// `HK|Hong Kong|🇭🇰`
  String get nodeExclusionPlaceholder {
    return Intl.message(
      'HK|Hong Kong|🇭🇰',
      name: 'nodeExclusionPlaceholder',
      desc: '',
      args: [],
    );
  }

  /// `Please check the format`
  String get formatError {
    return Intl.message(
      'Please check the format',
      name: 'formatError',
      desc: '',
      args: [],
    );
  }

  /// `Timeout`
  String get healthCheckTimeout {
    return Intl.message(
      'Timeout',
      name: 'healthCheckTimeout',
      desc: '',
      args: [],
    );
  }

  /// `Node health check timeout`
  String get healthCheckTimeoutDesc {
    return Intl.message(
      'Node health check timeout',
      name: 'healthCheckTimeoutDesc',
      desc: '',
      args: [],
    );
  }

  /// `Hide timed-out nodes`
  String get hideTimeoutProxies {
    return Intl.message(
      'Hide timed-out nodes',
      name: 'hideTimeoutProxies',
      desc: '',
      args: [],
    );
  }

  /// `Leave out nodes whose last delay test timed out`
  String get hideTimeoutProxiesDesc {
    return Intl.message(
      'Leave out nodes whose last delay test timed out',
      name: 'hideTimeoutProxiesDesc',
      desc: '',
      args: [],
    );
  }

  /// `Concurrency Limit`
  String get concurrencyLimit {
    return Intl.message(
      'Concurrency Limit',
      name: 'concurrencyLimit',
      desc: '',
      args: [],
    );
  }

  /// `Maximum concurrent delay tests`
  String get concurrencyLimitDesc {
    return Intl.message(
      'Maximum concurrent delay tests',
      name: 'concurrencyLimitDesc',
      desc: '',
      args: [],
    );
  }

  /// `Not Recommended`
  String get notRecommended {
    return Intl.message(
      'Not Recommended',
      name: 'notRecommended',
      desc: '',
      args: [],
    );
  }

  /// `Override DNS`
  String get overrideDns {
    return Intl.message(
      'Override DNS',
      name: 'overrideDns',
      desc: '',
      args: [],
    );
  }

  /// `Override profile's DNS settings`
  String get overrideDnsDesc {
    return Intl.message(
      'Override profile\'s DNS settings',
      name: 'overrideDnsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Override Config`
  String get overrideTestUrl {
    return Intl.message(
      'Override Config',
      name: 'overrideTestUrl',
      desc: '',
      args: [],
    );
  }

  /// `NTP`
  String get ntp {
    return Intl.message('NTP', name: 'ntp', desc: '', args: []);
  }

  /// `Use NTP time service`
  String get ntpDesc {
    return Intl.message(
      'Use NTP time service',
      name: 'ntpDesc',
      desc: '',
      args: [],
    );
  }

  /// `Override NTP`
  String get overrideNtp {
    return Intl.message(
      'Override NTP',
      name: 'overrideNtp',
      desc: '',
      args: [],
    );
  }

  /// `Override profile's NTP settings`
  String get overrideNtpDesc {
    return Intl.message(
      'Override profile\'s NTP settings',
      name: 'overrideNtpDesc',
      desc: '',
      args: [],
    );
  }

  /// `Status`
  String get ntpStatus {
    return Intl.message('Status', name: 'ntpStatus', desc: '', args: []);
  }

  /// `Enable NTP time service`
  String get ntpStatusDesc {
    return Intl.message(
      'Enable NTP time service',
      name: 'ntpStatusDesc',
      desc: '',
      args: [],
    );
  }

  /// `Write to System`
  String get writeToSystem {
    return Intl.message(
      'Write to System',
      name: 'writeToSystem',
      desc: '',
      args: [],
    );
  }

  /// `Requires administrator privileges`
  String get writeToSystemDesc {
    return Intl.message(
      'Requires administrator privileges',
      name: 'writeToSystemDesc',
      desc: '',
      args: [],
    );
  }

  /// `Server`
  String get ntpServer {
    return Intl.message('Server', name: 'ntpServer', desc: '', args: []);
  }

  /// `Port`
  String get ntpPort {
    return Intl.message('Port', name: 'ntpPort', desc: '', args: []);
  }

  /// `Update Interval`
  String get ntpInterval {
    return Intl.message(
      'Update Interval',
      name: 'ntpInterval',
      desc: '',
      args: [],
    );
  }

  /// `Sniffer`
  String get sniffer {
    return Intl.message('Sniffer', name: 'sniffer', desc: '', args: []);
  }

  /// `Modify domain sniffer config`
  String get snifferDesc {
    return Intl.message(
      'Modify domain sniffer config',
      name: 'snifferDesc',
      desc: '',
      args: [],
    );
  }

  /// `Override Sniffer`
  String get overrideSniffer {
    return Intl.message(
      'Override Sniffer',
      name: 'overrideSniffer',
      desc: '',
      args: [],
    );
  }

  /// `Override profile's Sniffer settings`
  String get overrideSnifferDesc {
    return Intl.message(
      'Override profile\'s Sniffer settings',
      name: 'overrideSnifferDesc',
      desc: '',
      args: [],
    );
  }

  /// `Status`
  String get snifferStatus {
    return Intl.message('Status', name: 'snifferStatus', desc: '', args: []);
  }

  /// `Enable Sniffer service`
  String get snifferStatusDesc {
    return Intl.message(
      'Enable Sniffer service',
      name: 'snifferStatusDesc',
      desc: '',
      args: [],
    );
  }

  /// `Force DNS Mapping`
  String get forceDnsMapping {
    return Intl.message(
      'Force DNS Mapping',
      name: 'forceDnsMapping',
      desc: '',
      args: [],
    );
  }

  /// `Force mapping DNS results to connections`
  String get forceDnsMappingDesc {
    return Intl.message(
      'Force mapping DNS results to connections',
      name: 'forceDnsMappingDesc',
      desc: '',
      args: [],
    );
  }

  /// `Parse Pure IP`
  String get parsePureIp {
    return Intl.message(
      'Parse Pure IP',
      name: 'parsePureIp',
      desc: '',
      args: [],
    );
  }

  /// `Parse pure IP connections`
  String get parsePureIpDesc {
    return Intl.message(
      'Parse pure IP connections',
      name: 'parsePureIpDesc',
      desc: '',
      args: [],
    );
  }

  /// `Override Destination`
  String get overrideDestination {
    return Intl.message(
      'Override Destination',
      name: 'overrideDestination',
      desc: '',
      args: [],
    );
  }

  /// `Override destination with sniffed result`
  String get overrideDestinationDesc {
    return Intl.message(
      'Override destination with sniffed result',
      name: 'overrideDestinationDesc',
      desc: '',
      args: [],
    );
  }

  /// `HTTP Port Sniffing`
  String get httpPortSniffer {
    return Intl.message(
      'HTTP Port Sniffing',
      name: 'httpPortSniffer',
      desc: '',
      args: [],
    );
  }

  /// `TLS Port Sniffing`
  String get tlsPortSniffer {
    return Intl.message(
      'TLS Port Sniffing',
      name: 'tlsPortSniffer',
      desc: '',
      args: [],
    );
  }

  /// `QUIC Port Sniffing`
  String get quicPortSniffer {
    return Intl.message(
      'QUIC Port Sniffing',
      name: 'quicPortSniffer',
      desc: '',
      args: [],
    );
  }

  /// `Force Sniff Domain`
  String get forceDomain {
    return Intl.message(
      'Force Sniff Domain',
      name: 'forceDomain',
      desc: '',
      args: [],
    );
  }

  /// `Skip Domain`
  String get skipDomain {
    return Intl.message('Skip Domain', name: 'skipDomain', desc: '', args: []);
  }

  /// `Skip Source IP`
  String get skipSrcAddress {
    return Intl.message(
      'Skip Source IP',
      name: 'skipSrcAddress',
      desc: '',
      args: [],
    );
  }

  /// `Skip Destination IP`
  String get skipDstAddress {
    return Intl.message(
      'Skip Destination IP',
      name: 'skipDstAddress',
      desc: '',
      args: [],
    );
  }

  /// `Ports`
  String get snifferPorts {
    return Intl.message('Ports', name: 'snifferPorts', desc: '', args: []);
  }

  /// `e.g.: 80, 8080-8880`
  String get snifferPortsHint {
    return Intl.message(
      'e.g.: 80, 8080-8880',
      name: 'snifferPortsHint',
      desc: '',
      args: [],
    );
  }

  /// `One domain per line`
  String get snifferDomainHint {
    return Intl.message(
      'One domain per line',
      name: 'snifferDomainHint',
      desc: '',
      args: [],
    );
  }

  /// `One address per line`
  String get snifferAddressHint {
    return Intl.message(
      'One address per line',
      name: 'snifferAddressHint',
      desc: '',
      args: [],
    );
  }

  /// `Tunnel`
  String get tunnel {
    return Intl.message('Tunnel', name: 'tunnel', desc: '', args: []);
  }

  /// `Use traffic forwarding tunnel`
  String get tunnelDesc {
    return Intl.message(
      'Use traffic forwarding tunnel',
      name: 'tunnelDesc',
      desc: '',
      args: [],
    );
  }

  /// `Override Tunnel`
  String get overrideTunnel {
    return Intl.message(
      'Override Tunnel',
      name: 'overrideTunnel',
      desc: '',
      args: [],
    );
  }

  /// `Override profile's Tunnel settings`
  String get overrideTunnelDesc {
    return Intl.message(
      'Override profile\'s Tunnel settings',
      name: 'overrideTunnelDesc',
      desc: '',
      args: [],
    );
  }

  /// `Forwarding List`
  String get tunnelList {
    return Intl.message(
      'Forwarding List',
      name: 'tunnelList',
      desc: '',
      args: [],
    );
  }

  /// `Add Forwarding`
  String get addTunnel {
    return Intl.message(
      'Add Forwarding',
      name: 'addTunnel',
      desc: '',
      args: [],
    );
  }

  /// `Edit Forwarding`
  String get editTunnel {
    return Intl.message(
      'Edit Forwarding',
      name: 'editTunnel',
      desc: '',
      args: [],
    );
  }

  /// `Delete Forwarding`
  String get deleteTunnel {
    return Intl.message(
      'Delete Forwarding',
      name: 'deleteTunnel',
      desc: '',
      args: [],
    );
  }

  /// `Network Protocol`
  String get tunnelNetwork {
    return Intl.message(
      'Network Protocol',
      name: 'tunnelNetwork',
      desc: '',
      args: [],
    );
  }

  /// `e.g.: tcp, udp`
  String get tunnelNetworkHint {
    return Intl.message(
      'e.g.: tcp, udp',
      name: 'tunnelNetworkHint',
      desc: '',
      args: [],
    );
  }

  /// `Listen Address`
  String get tunnelAddress {
    return Intl.message(
      'Listen Address',
      name: 'tunnelAddress',
      desc: '',
      args: [],
    );
  }

  /// `e.g.: 127.0.0.1:6553`
  String get tunnelAddressHint {
    return Intl.message(
      'e.g.: 127.0.0.1:6553',
      name: 'tunnelAddressHint',
      desc: '',
      args: [],
    );
  }

  /// `Target Address`
  String get tunnelTarget {
    return Intl.message(
      'Target Address',
      name: 'tunnelTarget',
      desc: '',
      args: [],
    );
  }

  /// `e.g.: 114.114.114.114:53`
  String get tunnelTargetHint {
    return Intl.message(
      'e.g.: 114.114.114.114:53',
      name: 'tunnelTargetHint',
      desc: '',
      args: [],
    );
  }

  /// `Proxy Name`
  String get tunnelProxy {
    return Intl.message('Proxy Name', name: 'tunnelProxy', desc: '', args: []);
  }

  /// `e.g.: proxy (optional)`
  String get tunnelProxyHint {
    return Intl.message(
      'e.g.: proxy (optional)',
      name: 'tunnelProxyHint',
      desc: '',
      args: [],
    );
  }

  /// `Experimental`
  String get experimental {
    return Intl.message(
      'Experimental',
      name: 'experimental',
      desc: '',
      args: [],
    );
  }

  /// `Use with caution`
  String get experimentalDesc {
    return Intl.message(
      'Use with caution',
      name: 'experimentalDesc',
      desc: '',
      args: [],
    );
  }

  /// `Override Experimental`
  String get overrideExperimental {
    return Intl.message(
      'Override Experimental',
      name: 'overrideExperimental',
      desc: '',
      args: [],
    );
  }

  /// `Override profile's Experimental settings`
  String get overrideExperimentalDesc {
    return Intl.message(
      'Override profile\'s Experimental settings',
      name: 'overrideExperimentalDesc',
      desc: '',
      args: [],
    );
  }

  /// `Disable QUIC GSO`
  String get quicGoDisableGso {
    return Intl.message(
      'Disable QUIC GSO',
      name: 'quicGoDisableGso',
      desc: '',
      args: [],
    );
  }

  /// `Disable QUIC Generic Segmentation Offload`
  String get quicGoDisableGsoDesc {
    return Intl.message(
      'Disable QUIC Generic Segmentation Offload',
      name: 'quicGoDisableGsoDesc',
      desc: '',
      args: [],
    );
  }

  /// `Disable QUIC ECN`
  String get quicGoDisableEcn {
    return Intl.message(
      'Disable QUIC ECN',
      name: 'quicGoDisableEcn',
      desc: '',
      args: [],
    );
  }

  /// `Disable QUIC Explicit Congestion Notification`
  String get quicGoDisableEcnDesc {
    return Intl.message(
      'Disable QUIC Explicit Congestion Notification',
      name: 'quicGoDisableEcnDesc',
      desc: '',
      args: [],
    );
  }

  /// `Enable Dialer IP4P Conversion`
  String get dialerIp4pConvert {
    return Intl.message(
      'Enable Dialer IP4P Conversion',
      name: 'dialerIp4pConvert',
      desc: '',
      args: [],
    );
  }

  /// `Enable dialer IP4P address conversion feature`
  String get dialerIp4pConvertDesc {
    return Intl.message(
      'Enable dialer IP4P address conversion feature',
      name: 'dialerIp4pConvertDesc',
      desc: '',
      args: [],
    );
  }

  /// `Status`
  String get status {
    return Intl.message('Status', name: 'status', desc: '', args: []);
  }

  /// `Uses system DNS when disabled`
  String get statusDesc {
    return Intl.message(
      'Uses system DNS when disabled',
      name: 'statusDesc',
      desc: '',
      args: [],
    );
  }

  /// `Prioritize DoH HTTP/3`
  String get preferH3Desc {
    return Intl.message(
      'Prioritize DoH HTTP/3',
      name: 'preferH3Desc',
      desc: '',
      args: [],
    );
  }

  /// `Cache Algorithm`
  String get cacheAlgorithm {
    return Intl.message(
      'Cache Algorithm',
      name: 'cacheAlgorithm',
      desc: '',
      args: [],
    );
  }

  /// `Respect Rules`
  String get respectRules {
    return Intl.message(
      'Respect Rules',
      name: 'respectRules',
      desc: '',
      args: [],
    );
  }

  /// `DNS connections follow Rules`
  String get respectRulesDesc {
    return Intl.message(
      'DNS connections follow Rules',
      name: 'respectRulesDesc',
      desc: '',
      args: [],
    );
  }

  /// `DNS Mode`
  String get dnsMode {
    return Intl.message('DNS Mode', name: 'dnsMode', desc: '', args: []);
  }

  /// `FakeIP Range`
  String get fakeipRange {
    return Intl.message(
      'FakeIP Range',
      name: 'fakeipRange',
      desc: '',
      args: [],
    );
  }

  /// `FakeIPv6 Range`
  String get fakeipRangeV6 {
    return Intl.message(
      'FakeIPv6 Range',
      name: 'fakeipRangeV6',
      desc: '',
      args: [],
    );
  }

  /// `FakeIP Filter Mode`
  String get fakeIpFilterMode {
    return Intl.message(
      'FakeIP Filter Mode',
      name: 'fakeIpFilterMode',
      desc: '',
      args: [],
    );
  }

  /// `Specify FakeIP filter mode`
  String get fakeIpFilterModeDesc {
    return Intl.message(
      'Specify FakeIP filter mode',
      name: 'fakeIpFilterModeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Blacklist`
  String get blacklist {
    return Intl.message('Blacklist', name: 'blacklist', desc: '', args: []);
  }

  /// `Whitelist`
  String get whitelist {
    return Intl.message('Whitelist', name: 'whitelist', desc: '', args: []);
  }

  /// `FakeIP Filter`
  String get fakeipFilter {
    return Intl.message(
      'FakeIP Filter',
      name: 'fakeipFilter',
      desc: '',
      args: [],
    );
  }

  /// `FakeIP TTL`
  String get fakeipTtl {
    return Intl.message('FakeIP TTL', name: 'fakeipTtl', desc: '', args: []);
  }

  /// `Default Nameserver`
  String get defaultNameserver {
    return Intl.message(
      'Default Nameserver',
      name: 'defaultNameserver',
      desc: '',
      args: [],
    );
  }

  /// `Used to resolve DNS servers`
  String get defaultNameserverDesc {
    return Intl.message(
      'Used to resolve DNS servers',
      name: 'defaultNameserverDesc',
      desc: '',
      args: [],
    );
  }

  /// `Nameserver`
  String get nameserver {
    return Intl.message('Nameserver', name: 'nameserver', desc: '', args: []);
  }

  /// `Used to resolve domains`
  String get nameserverDesc {
    return Intl.message(
      'Used to resolve domains',
      name: 'nameserverDesc',
      desc: '',
      args: [],
    );
  }

  /// `Use Hosts`
  String get useHosts {
    return Intl.message('Use Hosts', name: 'useHosts', desc: '', args: []);
  }

  /// `Use System Hosts`
  String get useSystemHosts {
    return Intl.message(
      'Use System Hosts',
      name: 'useSystemHosts',
      desc: '',
      args: [],
    );
  }

  /// `Nameserver Policy`
  String get nameserverPolicy {
    return Intl.message(
      'Nameserver Policy',
      name: 'nameserverPolicy',
      desc: '',
      args: [],
    );
  }

  /// `Specify domain-specific nameservers`
  String get nameserverPolicyDesc {
    return Intl.message(
      'Specify domain-specific nameservers',
      name: 'nameserverPolicyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Proxy Nameserver`
  String get proxyNameserver {
    return Intl.message(
      'Proxy Nameserver',
      name: 'proxyNameserver',
      desc: '',
      args: [],
    );
  }

  /// `Used to resolve proxy nodes`
  String get proxyNameserverDesc {
    return Intl.message(
      'Used to resolve proxy nodes',
      name: 'proxyNameserverDesc',
      desc: '',
      args: [],
    );
  }

  /// `Direct Nameserver`
  String get directNameserver {
    return Intl.message(
      'Direct Nameserver',
      name: 'directNameserver',
      desc: '',
      args: [],
    );
  }

  /// `Used to resolve direct domains`
  String get directNameserverDesc {
    return Intl.message(
      'Used to resolve direct domains',
      name: 'directNameserverDesc',
      desc: '',
      args: [],
    );
  }

  /// `Direct DNS Follows Policy`
  String get directNameserverFollowPolicy {
    return Intl.message(
      'Direct DNS Follows Policy',
      name: 'directNameserverFollowPolicy',
      desc: '',
      args: [],
    );
  }

  /// `Fallback`
  String get fallback {
    return Intl.message('Fallback', name: 'fallback', desc: '', args: []);
  }

  /// `Usually offshore DNS`
  String get fallbackDesc {
    return Intl.message(
      'Usually offshore DNS',
      name: 'fallbackDesc',
      desc: '',
      args: [],
    );
  }

  /// `Fallback Filter`
  String get fallbackFilter {
    return Intl.message(
      'Fallback Filter',
      name: 'fallbackFilter',
      desc: '',
      args: [],
    );
  }

  /// `Fallback Concurrent`
  String get fallbackConcurrent {
    return Intl.message(
      'Fallback Concurrent',
      name: 'fallbackConcurrent',
      desc: '',
      args: [],
    );
  }

  /// `Query default DNS and Fallback synchronously`
  String get fallbackConcurrentDesc {
    return Intl.message(
      'Query default DNS and Fallback synchronously',
      name: 'fallbackConcurrentDesc',
      desc: '',
      args: [],
    );
  }

  /// `GeoIP Code`
  String get geoipCode {
    return Intl.message('GeoIP Code', name: 'geoipCode', desc: '', args: []);
  }

  /// `IP/CIDR`
  String get ipcidr {
    return Intl.message('IP/CIDR', name: 'ipcidr', desc: '', args: []);
  }

  /// `Domain`
  String get domainName {
    return Intl.message('Domain', name: 'domainName', desc: '', args: []);
  }

  /// `Reset`
  String get reset {
    return Intl.message('Reset', name: 'reset', desc: '', args: []);
  }

  /// `Show/Hide`
  String get action_view {
    return Intl.message('Show/Hide', name: 'action_view', desc: '', args: []);
  }

  /// `Start/Stop`
  String get action_start {
    return Intl.message('Start/Stop', name: 'action_start', desc: '', args: []);
  }

  /// `Switch Mode`
  String get action_mode {
    return Intl.message('Switch Mode', name: 'action_mode', desc: '', args: []);
  }

  /// `System Proxy`
  String get action_proxy {
    return Intl.message(
      'System Proxy',
      name: 'action_proxy',
      desc: '',
      args: [],
    );
  }

  /// `TUN`
  String get action_tun {
    return Intl.message('TUN', name: 'action_tun', desc: '', args: []);
  }

  /// `Disclaimer`
  String get disclaimer {
    return Intl.message('Disclaimer', name: 'disclaimer', desc: '', args: []);
  }

  /// `This free open-source software is for non-commercial learning and personal use only. Proxy services are independent of this software. By agreeing, you acknowledge this; otherwise, please exit.`
  String get disclaimerDesc {
    return Intl.message(
      'This free open-source software is for non-commercial learning and personal use only. Proxy services are independent of this software. By agreeing, you acknowledge this; otherwise, please exit.',
      name: 'disclaimerDesc',
      desc: '',
      args: [],
    );
  }

  /// `Agree`
  String get agree {
    return Intl.message('Agree', name: 'agree', desc: '', args: []);
  }

  /// `Hotkey Management`
  String get hotkeyManagement {
    return Intl.message(
      'Hotkey Management',
      name: 'hotkeyManagement',
      desc: '',
      args: [],
    );
  }

  /// `Control app via keyboard`
  String get hotkeyManagementDesc {
    return Intl.message(
      'Control app via keyboard',
      name: 'hotkeyManagementDesc',
      desc: '',
      args: [],
    );
  }

  /// `Press a key`
  String get pressKeyboard {
    return Intl.message(
      'Press a key',
      name: 'pressKeyboard',
      desc: '',
      args: [],
    );
  }

  /// `Enter a valid hotkey`
  String get inputCorrectHotkey {
    return Intl.message(
      'Enter a valid hotkey',
      name: 'inputCorrectHotkey',
      desc: '',
      args: [],
    );
  }

  /// `Hotkey Conflict`
  String get hotkeyConflict {
    return Intl.message(
      'Hotkey Conflict',
      name: 'hotkeyConflict',
      desc: '',
      args: [],
    );
  }

  /// `Remove`
  String get remove {
    return Intl.message('Remove', name: 'remove', desc: '', args: []);
  }

  /// `No Hotkeys`
  String get noHotKey {
    return Intl.message('No Hotkeys', name: 'noHotKey', desc: '', args: []);
  }

  /// `No Network`
  String get noNetwork {
    return Intl.message('No Network', name: 'noNetwork', desc: '', args: []);
  }

  /// `Allow IPv6 inbound`
  String get ipv6InboundDesc {
    return Intl.message(
      'Allow IPv6 inbound',
      name: 'ipv6InboundDesc',
      desc: '',
      args: [],
    );
  }

  /// `Export Logs`
  String get exportLogs {
    return Intl.message('Export Logs', name: 'exportLogs', desc: '', args: []);
  }

  /// `Export Successful`
  String get exportSuccess {
    return Intl.message(
      'Export Successful',
      name: 'exportSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Icon Style`
  String get iconStyle {
    return Intl.message('Icon Style', name: 'iconStyle', desc: '', args: []);
  }

  /// `Icon Only`
  String get onlyIcon {
    return Intl.message('Icon Only', name: 'onlyIcon', desc: '', args: []);
  }

  /// `No Icon`
  String get noIcon {
    return Intl.message('No Icon', name: 'noIcon', desc: '', args: []);
  }

  /// `Stack Mode`
  String get stackMode {
    return Intl.message('Stack Mode', name: 'stackMode', desc: '', args: []);
  }

  /// `Strict Route`
  String get strictRoute {
    return Intl.message(
      'Strict Route',
      name: 'strictRoute',
      desc: '',
      args: [],
    );
  }

  /// `Use TUN strict routing mode`
  String get strictRouteDesc {
    return Intl.message(
      'Use TUN strict routing mode',
      name: 'strictRouteDesc',
      desc: '',
      args: [],
    );
  }

  /// `ICMP Forwarding`
  String get icmpForwarding {
    return Intl.message(
      'ICMP Forwarding',
      name: 'icmpForwarding',
      desc: '',
      args: [],
    );
  }

  /// `Enable ICMP Ping`
  String get icmpForwardingDesc {
    return Intl.message(
      'Enable ICMP Ping',
      name: 'icmpForwardingDesc',
      desc: '',
      args: [],
    );
  }

  /// `DNS Hijack`
  String get dnsHijack {
    return Intl.message('DNS Hijack', name: 'dnsHijack', desc: '', args: []);
  }

  /// `Redirect DNS queries to internal DNS module`
  String get dnsHijackDesc {
    return Intl.message(
      'Redirect DNS queries to internal DNS module',
      name: 'dnsHijackDesc',
      desc: '',
      args: [],
    );
  }

  /// `NAT Enhancement`
  String get endpointIndependentNat {
    return Intl.message(
      'NAT Enhancement',
      name: 'endpointIndependentNat',
      desc: '',
      args: [],
    );
  }

  /// `Optimize UDP/P2P application experience`
  String get endpointIndependentNatDesc {
    return Intl.message(
      'Optimize UDP/P2P application experience',
      name: 'endpointIndependentNatDesc',
      desc: '',
      args: [],
    );
  }

  /// `Enabling Endpoint-Independent NAT feature may slightly degrade performance. It is recommended to enable it only if necessary and you are familiar with it.`
  String get endpointIndependentNatConfirmDesc {
    return Intl.message(
      'Enabling Endpoint-Independent NAT feature may slightly degrade performance. It is recommended to enable it only if necessary and you are familiar with it.',
      name: 'endpointIndependentNatConfirmDesc',
      desc: '',
      args: [],
    );
  }

  /// `Network`
  String get network {
    return Intl.message('Network', name: 'network', desc: '', args: []);
  }

  /// `Modify network-related settings`
  String get networkDesc {
    return Intl.message(
      'Modify network-related settings',
      name: 'networkDesc',
      desc: '',
      args: [],
    );
  }

  /// `Bypass Domain`
  String get bypassDomain {
    return Intl.message(
      'Bypass Domain',
      name: 'bypassDomain',
      desc: '',
      args: [],
    );
  }

  /// `Active only when System Proxy is on`
  String get bypassDomainDesc {
    return Intl.message(
      'Active only when System Proxy is on',
      name: 'bypassDomainDesc',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to reset?`
  String get resetTip {
    return Intl.message(
      'Are you sure you want to reset?',
      name: 'resetTip',
      desc: '',
      args: [],
    );
  }

  /// `Restart core`
  String get restartCore {
    return Intl.message(
      'Restart core',
      name: 'restartCore',
      desc: '',
      args: [],
    );
  }

  /// `Stable`
  String get checkUpdateStable {
    return Intl.message(
      'Stable',
      name: 'checkUpdateStable',
      desc: '',
      args: [],
    );
  }

  /// `Preview`
  String get checkUpdatePrerelease {
    return Intl.message(
      'Preview',
      name: 'checkUpdatePrerelease',
      desc: '',
      args: [],
    );
  }

  /// `Telegram channel`
  String get telegramChannel {
    return Intl.message(
      'Telegram channel',
      name: 'telegramChannel',
      desc: '',
      args: [],
    );
  }

  /// `Official community`
  String get officialCommunity {
    return Intl.message(
      'Official community',
      name: 'officialCommunity',
      desc: '',
      args: [],
    );
  }

  /// `Switch`
  String get switchProxy {
    return Intl.message('Switch', name: 'switchProxy', desc: '', args: []);
  }

  /// `Timeout`
  String get timeoutLabel {
    return Intl.message('Timeout', name: 'timeoutLabel', desc: '', args: []);
  }

  /// `Telegram group`
  String get telegramGroup {
    return Intl.message(
      'Telegram group',
      name: 'telegramGroup',
      desc: '',
      args: [],
    );
  }

  /// `Port {from} is in use; using {to} for this session`
  String portFallbackNotice(Object from, Object to) {
    return Intl.message(
      'Port $from is in use; using $to for this session',
      name: 'portFallbackNotice',
      desc: '',
      args: [from, to],
    );
  }

  /// `Manually restart the core?`
  String get restartCoreDesc {
    return Intl.message(
      'Manually restart the core?',
      name: 'restartCoreDesc',
      desc: '',
      args: [],
    );
  }

  /// `Restart the core? Active connections will briefly drop.`
  String get restartCoreTip {
    return Intl.message(
      'Restart the core? Active connections will briefly drop.',
      name: 'restartCoreTip',
      desc: '',
      args: [],
    );
  }

  /// `Title colour`
  String get titleColor {
    return Intl.message('Title colour', name: 'titleColor', desc: '', args: []);
  }

  /// `Clear all rules and scripts`
  String get clearAllRulesAndScripts {
    return Intl.message(
      'Clear all rules and scripts',
      name: 'clearAllRulesAndScripts',
      desc: '',
      args: [],
    );
  }

  /// `This removes every profile's override rules and all global scripts. It cannot be undone.`
  String get clearAllRulesAndScriptsTip {
    return Intl.message(
      'This removes every profile\'s override rules and all global scripts. It cannot be undone.',
      name: 'clearAllRulesAndScriptsTip',
      desc: '',
      args: [],
    );
  }

  /// `RegExp`
  String get regExp {
    return Intl.message('RegExp', name: 'regExp', desc: '', args: []);
  }

  /// `Icon`
  String get icon {
    return Intl.message('Icon', name: 'icon', desc: '', args: []);
  }

  /// `Icon Configuration`
  String get iconConfiguration {
    return Intl.message(
      'Icon Configuration',
      name: 'iconConfiguration',
      desc: '',
      args: [],
    );
  }

  /// `Reset Icon Cache`
  String get resetIconCache {
    return Intl.message(
      'Reset Icon Cache',
      name: 'resetIconCache',
      desc: '',
      args: [],
    );
  }

  /// `Reset the local icon cache? This is safe, the app will fetch icons from their remote links again automatically.`
  String get resetIconCacheDesc {
    return Intl.message(
      'Reset the local icon cache? This is safe, the app will fetch icons from their remote links again automatically.',
      name: 'resetIconCacheDesc',
      desc: '',
      args: [],
    );
  }

  /// `No Data`
  String get noData {
    return Intl.message('No Data', name: 'noData', desc: '', args: []);
  }

  /// `Admin Auto-Launch`
  String get adminAutoLaunch {
    return Intl.message(
      'Admin Auto-Launch',
      name: 'adminAutoLaunch',
      desc: '',
      args: [],
    );
  }

  /// `Auto-start with admin privileges`
  String get adminAutoLaunchDesc {
    return Intl.message(
      'Auto-start with admin privileges',
      name: 'adminAutoLaunchDesc',
      desc: '',
      args: [],
    );
  }

  /// `Font`
  String get fontFamily {
    return Intl.message('Font', name: 'fontFamily', desc: '', args: []);
  }

  /// `System Font`
  String get systemFont {
    return Intl.message('System Font', name: 'systemFont', desc: '', args: []);
  }

  /// `Toggle`
  String get toggle {
    return Intl.message('Toggle', name: 'toggle', desc: '', args: []);
  }

  /// `System`
  String get system {
    return Intl.message('System', name: 'system', desc: '', args: []);
  }

  /// `Bypass Private Network`
  String get bypassPrivateRoute {
    return Intl.message(
      'Bypass Private Network',
      name: 'bypassPrivateRoute',
      desc: '',
      args: [],
    );
  }

  /// `Automatically bypass private network IP addresses`
  String get bypassPrivateRouteDesc {
    return Intl.message(
      'Automatically bypass private network IP addresses',
      name: 'bypassPrivateRouteDesc',
      desc: '',
      args: [],
    );
  }

  /// `Please enter the admin password`
  String get pleaseInputAdminPassword {
    return Intl.message(
      'Please enter the admin password',
      name: 'pleaseInputAdminPassword',
      desc: '',
      args: [],
    );
  }

  /// `Copy Environment Variable`
  String get copyEnvVar {
    return Intl.message(
      'Copy Environment Variable',
      name: 'copyEnvVar',
      desc: '',
      args: [],
    );
  }

  /// `Memory`
  String get memoryInfo {
    return Intl.message('Memory', name: 'memoryInfo', desc: '', args: []);
  }

  /// `The current memory information value displayed is the dynamic stack memory usage of the core during runtime, not the complete APP memory statistics, for reference only.`
  String get memoryInfoDesc {
    return Intl.message(
      'The current memory information value displayed is the dynamic stack memory usage of the core during runtime, not the complete APP memory statistics, for reference only.',
      name: 'memoryInfoDesc',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `File modified. Save changes?`
  String get fileIsUpdate {
    return Intl.message(
      'File modified. Save changes?',
      name: 'fileIsUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Profile modified. Disable auto-update?`
  String get profileHasUpdate {
    return Intl.message(
      'Profile modified. Disable auto-update?',
      name: 'profileHasUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Cache modifications?`
  String get hasCacheChange {
    return Intl.message(
      'Cache modifications?',
      name: 'hasCacheChange',
      desc: '',
      args: [],
    );
  }

  /// `Active`
  String get navConnections {
    return Intl.message('Active', name: 'navConnections', desc: '', args: []);
  }

  /// `More`
  String get navTools {
    return Intl.message('More', name: 'navTools', desc: '', args: []);
  }

  /// `Copy Successful`
  String get copySuccess {
    return Intl.message(
      'Copy Successful',
      name: 'copySuccess',
      desc: '',
      args: [],
    );
  }

  /// `Copied package name`
  String get copiedPackageName {
    return Intl.message(
      'Copied package name',
      name: 'copiedPackageName',
      desc: '',
      args: [],
    );
  }

  /// `Success`
  String get success {
    return Intl.message('Success', name: 'success', desc: '', args: []);
  }

  /// `Copy Link`
  String get copyLink {
    return Intl.message('Copy Link', name: 'copyLink', desc: '', args: []);
  }

  /// `Export File`
  String get exportFile {
    return Intl.message('Export File', name: 'exportFile', desc: '', args: []);
  }

  /// `Cache corrupted. Clear it?`
  String get cacheCorrupt {
    return Intl.message(
      'Cache corrupted. Clear it?',
      name: 'cacheCorrupt',
      desc: '',
      args: [],
    );
  }

  /// `Third-party API result (for reference only)`
  String get detectionTip {
    return Intl.message(
      'Third-party API result (for reference only)',
      name: 'detectionTip',
      desc: '',
      args: [],
    );
  }

  /// `Toggle Display`
  String get ipClickBehavior {
    return Intl.message(
      'Toggle Display',
      name: 'ipClickBehavior',
      desc: '',
      args: [],
    );
  }

  /// `Hide IP Display`
  String get ipPrivacyProtection {
    return Intl.message(
      'Hide IP Display',
      name: 'ipPrivacyProtection',
      desc: '',
      args: [],
    );
  }

  /// `Refresh IP`
  String get manualRefreshIp {
    return Intl.message(
      'Refresh IP',
      name: 'manualRefreshIp',
      desc: '',
      args: [],
    );
  }

  /// `Please try manual refresh`
  String get tryManualRefresh {
    return Intl.message(
      'Please try manual refresh',
      name: 'tryManualRefresh',
      desc: '',
      args: [],
    );
  }

  /// `Refresh App List`
  String get refreshAppList {
    return Intl.message(
      'Refresh App List',
      name: 'refreshAppList',
      desc: '',
      args: [],
    );
  }

  /// `Refresh the app list?`
  String get refreshAppListConfirm {
    return Intl.message(
      'Refresh the app list?',
      name: 'refreshAppListConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Get Domestic IP`
  String get switchToDomesticIp {
    return Intl.message(
      'Get Domestic IP',
      name: 'switchToDomesticIp',
      desc: '',
      args: [],
    );
  }

  /// `Listen`
  String get listen {
    return Intl.message('Listen', name: 'listen', desc: '', args: []);
  }

  /// `Undo`
  String get undo {
    return Intl.message('Undo', name: 'undo', desc: '', args: []);
  }

  /// `Redo`
  String get redo {
    return Intl.message('Redo', name: 'redo', desc: '', args: []);
  }

  /// `None`
  String get none {
    return Intl.message('None', name: 'none', desc: '', args: []);
  }

  /// `Core Configuration`
  String get basicConfig {
    return Intl.message(
      'Core Configuration',
      name: 'basicConfig',
      desc: '',
      args: [],
    );
  }

  /// `Global core settings`
  String get basicConfigDesc {
    return Intl.message(
      'Global core settings',
      name: 'basicConfigDesc',
      desc: '',
      args: [],
    );
  }

  /// `{count} items selected`
  String selectedCountTitle(Object count) {
    return Intl.message(
      '$count items selected',
      name: 'selectedCountTitle',
      desc: '',
      args: [count],
    );
  }

  /// `Add Rule`
  String get addRule {
    return Intl.message('Add Rule', name: 'addRule', desc: '', args: []);
  }

  /// `Rule Name`
  String get ruleName {
    return Intl.message('Rule Name', name: 'ruleName', desc: '', args: []);
  }

  /// `Content`
  String get content {
    return Intl.message('Content', name: 'content', desc: '', args: []);
  }

  /// `Sub Rule`
  String get subRule {
    return Intl.message('Sub Rule', name: 'subRule', desc: '', args: []);
  }

  /// `Rule Target`
  String get ruleTarget {
    return Intl.message('Rule Target', name: 'ruleTarget', desc: '', args: []);
  }

  /// `Source IP`
  String get sourceIp {
    return Intl.message('Source IP', name: 'sourceIp', desc: '', args: []);
  }

  /// `No Resolve`
  String get noResolve {
    return Intl.message('No Resolve', name: 'noResolve', desc: '', args: []);
  }

  /// `Original Rules`
  String get getOriginRules {
    return Intl.message(
      'Original Rules',
      name: 'getOriginRules',
      desc: '',
      args: [],
    );
  }

  /// `Override Original Rules`
  String get overrideOriginRules {
    return Intl.message(
      'Override Original Rules',
      name: 'overrideOriginRules',
      desc: '',
      args: [],
    );
  }

  /// `Append to Original Rules`
  String get addedOriginRules {
    return Intl.message(
      'Append to Original Rules',
      name: 'addedOriginRules',
      desc: '',
      args: [],
    );
  }

  /// `Enable Override`
  String get enableOverride {
    return Intl.message(
      'Enable Override',
      name: 'enableOverride',
      desc: '',
      args: [],
    );
  }

  /// `Save changes?`
  String get saveChanges {
    return Intl.message(
      'Save changes?',
      name: 'saveChanges',
      desc: '',
      args: [],
    );
  }

  /// `Modify global settings`
  String get generalDesc {
    return Intl.message(
      'Modify global settings',
      name: 'generalDesc',
      desc: '',
      args: [],
    );
  }

  /// `Enable process matching`
  String get findProcessModeDesc {
    return Intl.message(
      'Enable process matching',
      name: 'findProcessModeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Haptic Feedback`
  String get navBarHapticFeedback {
    return Intl.message(
      'Haptic Feedback',
      name: 'navBarHapticFeedback',
      desc: '',
      args: [],
    );
  }

  /// `Vibrate on navigation tab switch`
  String get navBarHapticFeedbackDesc {
    return Intl.message(
      'Vibrate on navigation tab switch',
      name: 'navBarHapticFeedbackDesc',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to save?`
  String get saveTip {
    return Intl.message(
      'Are you sure you want to save?',
      name: 'saveTip',
      desc: '',
      args: [],
    );
  }

  /// `Color Schemes`
  String get colorSchemes {
    return Intl.message(
      'Color Schemes',
      name: 'colorSchemes',
      desc: '',
      args: [],
    );
  }

  /// `Palette`
  String get palette {
    return Intl.message('Palette', name: 'palette', desc: '', args: []);
  }

  /// `Tonal Spot`
  String get tonalSpotScheme {
    return Intl.message(
      'Tonal Spot',
      name: 'tonalSpotScheme',
      desc: '',
      args: [],
    );
  }

  /// `Fidelity`
  String get fidelityScheme {
    return Intl.message('Fidelity', name: 'fidelityScheme', desc: '', args: []);
  }

  /// `Monochrome`
  String get monochromeScheme {
    return Intl.message(
      'Monochrome',
      name: 'monochromeScheme',
      desc: '',
      args: [],
    );
  }

  /// `Neutral`
  String get neutralScheme {
    return Intl.message('Neutral', name: 'neutralScheme', desc: '', args: []);
  }

  /// `Vibrant`
  String get vibrantScheme {
    return Intl.message('Vibrant', name: 'vibrantScheme', desc: '', args: []);
  }

  /// `Expressive`
  String get expressiveScheme {
    return Intl.message(
      'Expressive',
      name: 'expressiveScheme',
      desc: '',
      args: [],
    );
  }

  /// `Content`
  String get contentScheme {
    return Intl.message('Content', name: 'contentScheme', desc: '', args: []);
  }

  /// `Rainbow`
  String get rainbowScheme {
    return Intl.message('Rainbow', name: 'rainbowScheme', desc: '', args: []);
  }

  /// `Fruit Salad`
  String get fruitSaladScheme {
    return Intl.message(
      'Fruit Salad',
      name: 'fruitSaladScheme',
      desc: '',
      args: [],
    );
  }

  /// `Developer Mode`
  String get developerMode {
    return Intl.message(
      'Developer Mode',
      name: 'developerMode',
      desc: '',
      args: [],
    );
  }

  /// `Developer mode is enabled.`
  String get developerModeEnableTip {
    return Intl.message(
      'Developer mode is enabled.',
      name: 'developerModeEnableTip',
      desc: '',
      args: [],
    );
  }

  /// `Message Test`
  String get messageTest {
    return Intl.message(
      'Message Test',
      name: 'messageTest',
      desc: '',
      args: [],
    );
  }

  /// `This is a message.`
  String get messageTestTip {
    return Intl.message(
      'This is a message.',
      name: 'messageTestTip',
      desc: '',
      args: [],
    );
  }

  /// `Crash Test`
  String get crashTest {
    return Intl.message('Crash Test', name: 'crashTest', desc: '', args: []);
  }

  /// `Clear Data`
  String get clearData {
    return Intl.message('Clear Data', name: 'clearData', desc: '', args: []);
  }

  /// `Dangerous Operation`
  String get clearDataTipTitle {
    return Intl.message(
      'Dangerous Operation',
      name: 'clearDataTipTitle',
      desc: '',
      args: [],
    );
  }

  /// `This operation will reset the application. Please make backups. Are you sure you want to continue?`
  String get clearDataTipDesc {
    return Intl.message(
      'This operation will reset the application. Please make backups. Are you sure you want to continue?',
      name: 'clearDataTipDesc',
      desc: '',
      args: [],
    );
  }

  /// `Text Scaling`
  String get textScale {
    return Intl.message('Text Scaling', name: 'textScale', desc: '', args: []);
  }

  /// `Invert Tray Icon`
  String get trayIconInvert {
    return Intl.message(
      'Invert Tray Icon',
      name: 'trayIconInvert',
      desc: '',
      args: [],
    );
  }

  /// `Invert the current tray icon color`
  String get trayIconInvertDesc {
    return Intl.message(
      'Invert the current tray icon color',
      name: 'trayIconInvertDesc',
      desc: '',
      args: [],
    );
  }

  /// `Dark Icon`
  String get darkIcon {
    return Intl.message('Dark Icon', name: 'darkIcon', desc: '', args: []);
  }

  /// `Manually switch dark app icon`
  String get darkIconDesc {
    return Intl.message(
      'Manually switch dark app icon',
      name: 'darkIconDesc',
      desc: '',
      args: [],
    );
  }

  /// `Font Fix`
  String get harmonyFont {
    return Intl.message('Font Fix', name: 'harmonyFont', desc: '', args: []);
  }

  /// `Use built-in font to fix display issues`
  String get harmonyFontDesc {
    return Intl.message(
      'Use built-in font to fix display issues',
      name: 'harmonyFontDesc',
      desc: '',
      args: [],
    );
  }

  /// `Internet`
  String get internet {
    return Intl.message('Internet', name: 'internet', desc: '', args: []);
  }

  /// `System App`
  String get systemApp {
    return Intl.message('System App', name: 'systemApp', desc: '', args: []);
  }

  /// `No Network App`
  String get noNetworkApp {
    return Intl.message(
      'No Network App',
      name: 'noNetworkApp',
      desc: '',
      args: [],
    );
  }

  /// `Contact Me`
  String get contactMe {
    return Intl.message('Contact Me', name: 'contactMe', desc: '', args: []);
  }

  /// `Recovery Strategy`
  String get recoveryStrategy {
    return Intl.message(
      'Recovery Strategy',
      name: 'recoveryStrategy',
      desc: '',
      args: [],
    );
  }

  /// `Override`
  String get recoveryStrategy_override {
    return Intl.message(
      'Override',
      name: 'recoveryStrategy_override',
      desc: '',
      args: [],
    );
  }

  /// `Compatible`
  String get recoveryStrategy_compatible {
    return Intl.message(
      'Compatible',
      name: 'recoveryStrategy_compatible',
      desc: '',
      args: [],
    );
  }

  /// `Logs Test`
  String get logsTest {
    return Intl.message('Logs Test', name: 'logsTest', desc: '', args: []);
  }

  /// `{label} cannot be empty`
  String emptyTip(Object label) {
    return Intl.message(
      '$label cannot be empty',
      name: 'emptyTip',
      desc: '',
      args: [label],
    );
  }

  /// `{label} must be a URL`
  String urlTip(Object label) {
    return Intl.message(
      '$label must be a URL',
      name: 'urlTip',
      desc: '',
      args: [label],
    );
  }

  /// `{label} must be a number`
  String numberTip(Object label) {
    return Intl.message(
      '$label must be a number',
      name: 'numberTip',
      desc: '',
      args: [label],
    );
  }

  /// `Interval`
  String get interval {
    return Intl.message('Interval', name: 'interval', desc: '', args: []);
  }

  /// `{label} already exists`
  String existsTip(Object label) {
    return Intl.message(
      '$label already exists',
      name: 'existsTip',
      desc: '',
      args: [label],
    );
  }

  /// `Delete current {label}?`
  String deleteTip(Object label) {
    return Intl.message(
      'Delete current $label?',
      name: 'deleteTip',
      desc: '',
      args: [label],
    );
  }

  /// `Delete selected {label}?`
  String deleteMultipTip(Object label) {
    return Intl.message(
      'Delete selected $label?',
      name: 'deleteMultipTip',
      desc: '',
      args: [label],
    );
  }

  /// `No {label}`
  String nullTip(Object label) {
    return Intl.message('No $label', name: 'nullTip', desc: '', args: [label]);
  }

  /// `Script`
  String get script {
    return Intl.message('Script', name: 'script', desc: '', args: []);
  }

  /// `Color`
  String get color {
    return Intl.message('Color', name: 'color', desc: '', args: []);
  }

  /// `Rename`
  String get rename {
    return Intl.message('Rename', name: 'rename', desc: '', args: []);
  }

  /// `Unnamed`
  String get unnamed {
    return Intl.message('Unnamed', name: 'unnamed', desc: '', args: []);
  }

  /// `Please enter a script name`
  String get pleaseEnterScriptName {
    return Intl.message(
      'Please enter a script name',
      name: 'pleaseEnterScriptName',
      desc: '',
      args: [],
    );
  }

  /// `Inactive in script mode`
  String get overrideInvalidTip {
    return Intl.message(
      'Inactive in script mode',
      name: 'overrideInvalidTip',
      desc: '',
      args: [],
    );
  }

  /// `Mixed Port`
  String get mixedPort {
    return Intl.message('Mixed Port', name: 'mixedPort', desc: '', args: []);
  }

  /// `Socks Port`
  String get socksPort {
    return Intl.message('Socks Port', name: 'socksPort', desc: '', args: []);
  }

  /// `Redir Port`
  String get redirPort {
    return Intl.message('Redir Port', name: 'redirPort', desc: '', args: []);
  }

  /// `Tproxy Port`
  String get tproxyPort {
    return Intl.message('Tproxy Port', name: 'tproxyPort', desc: '', args: []);
  }

  /// `{label} must be between 1024 and 49151, 0 to disable`
  String portTip(Object label) {
    return Intl.message(
      '$label must be between 1024 and 49151, 0 to disable',
      name: 'portTip',
      desc: '',
      args: [label],
    );
  }

  /// `Please enter a different port`
  String get portConflictTip {
    return Intl.message(
      'Please enter a different port',
      name: 'portConflictTip',
      desc: '',
      args: [],
    );
  }

  /// `Import`
  String get import {
    return Intl.message('Import', name: 'import', desc: '', args: []);
  }

  /// `Import from Code`
  String get importFromCode {
    return Intl.message(
      'Import from Code',
      name: 'importFromCode',
      desc: '',
      args: [],
    );
  }

  /// `Import failed`
  String get importFailed {
    return Intl.message(
      'Import failed',
      name: 'importFailed',
      desc: '',
      args: [],
    );
  }

  /// `Import from File`
  String get importFile {
    return Intl.message(
      'Import from File',
      name: 'importFile',
      desc: '',
      args: [],
    );
  }

  /// `Import from URL`
  String get importUrl {
    return Intl.message(
      'Import from URL',
      name: 'importUrl',
      desc: '',
      args: [],
    );
  }

  /// `Auto Set System DNS`
  String get autoSetSystemDns {
    return Intl.message(
      'Auto Set System DNS',
      name: 'autoSetSystemDns',
      desc: '',
      args: [],
    );
  }

  /// `Details`
  String get details {
    return Intl.message('Details', name: 'details', desc: '', args: []);
  }

  /// `Creation Time`
  String get creationTime {
    return Intl.message(
      'Creation Time',
      name: 'creationTime',
      desc: '',
      args: [],
    );
  }

  /// `Progress`
  String get progress {
    return Intl.message('Progress', name: 'progress', desc: '', args: []);
  }

  /// `Host`
  String get host {
    return Intl.message('Host', name: 'host', desc: '', args: []);
  }

  /// `Destination`
  String get destination {
    return Intl.message('Destination', name: 'destination', desc: '', args: []);
  }

  /// `Destination GeoIP`
  String get destinationGeoIP {
    return Intl.message(
      'Destination GeoIP',
      name: 'destinationGeoIP',
      desc: '',
      args: [],
    );
  }

  /// `Destination IP ASN`
  String get destinationIPASN {
    return Intl.message(
      'Destination IP ASN',
      name: 'destinationIPASN',
      desc: '',
      args: [],
    );
  }

  /// `Special Proxy`
  String get specialProxy {
    return Intl.message(
      'Special Proxy',
      name: 'specialProxy',
      desc: '',
      args: [],
    );
  }

  /// `Special Rules`
  String get specialRules {
    return Intl.message(
      'Special Rules',
      name: 'specialRules',
      desc: '',
      args: [],
    );
  }

  /// `Remote Destination`
  String get remoteDestination {
    return Intl.message(
      'Remote Destination',
      name: 'remoteDestination',
      desc: '',
      args: [],
    );
  }

  /// `Proxy Chains`
  String get proxyChains {
    return Intl.message(
      'Proxy Chains',
      name: 'proxyChains',
      desc: '',
      args: [],
    );
  }

  /// `Log`
  String get log {
    return Intl.message('Log', name: 'log', desc: '', args: []);
  }

  /// `Active`
  String get connection {
    return Intl.message('Active', name: 'connection', desc: '', args: []);
  }

  /// `Request`
  String get request {
    return Intl.message('Request', name: 'request', desc: '', args: []);
  }

  /// `Switch`
  String get switchLabel {
    return Intl.message('Switch', name: 'switchLabel', desc: '', args: []);
  }

  /// `No Status`
  String get noStatusAvailable {
    return Intl.message(
      'No Status',
      name: 'noStatusAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Online Panel`
  String get onlinePanel {
    return Intl.message(
      'Online Panel',
      name: 'onlinePanel',
      desc: '',
      args: [],
    );
  }

  /// `Open Zashboard`
  String get openDashboard {
    return Intl.message(
      'Open Zashboard',
      name: 'openDashboard',
      desc: '',
      args: [],
    );
  }

  /// `Custom`
  String get custom {
    return Intl.message('Custom', name: 'custom', desc: '', args: []);
  }

  /// `Custom Rule Switch`
  String get customScriptOptions {
    return Intl.message(
      'Custom Rule Switch',
      name: 'customScriptOptions',
      desc: '',
      args: [],
    );
  }

  /// `Wakelock`
  String get wakelock {
    return Intl.message('Wakelock', name: 'wakelock', desc: '', args: []);
  }

  /// `Keeps the screen on and app active in the background without requiring special CPU wakelock permissions.`
  String get wakelockDescription {
    return Intl.message(
      'Keeps the screen on and app active in the background without requiring special CPU wakelock permissions.',
      name: 'wakelockDescription',
      desc: '',
      args: [],
    );
  }

  /// `Enabling the TUN virtual network adapter requires Administrator or ROOT privileges.`
  String get tunEnableRequireAdmin {
    return Intl.message(
      'Enabling the TUN virtual network adapter requires Administrator or ROOT privileges.',
      name: 'tunEnableRequireAdmin',
      desc: '',
      args: [],
    );
  }

  /// `Restart TUN for changes to take effect`
  String get restartTip {
    return Intl.message(
      'Restart TUN for changes to take effect',
      name: 'restartTip',
      desc: '',
      args: [],
    );
  }

  /// `Restart`
  String get restart {
    return Intl.message('Restart', name: 'restart', desc: '', args: []);
  }

  /// `Restart Core`
  String get restartCoreTitle {
    return Intl.message(
      'Restart Core',
      name: 'restartCoreTitle',
      desc: '',
      args: [],
    );
  }

  /// `Switch Subscription Failed`
  String get switchProfileFailed {
    return Intl.message(
      'Switch Subscription Failed',
      name: 'switchProfileFailed',
      desc: '',
      args: [],
    );
  }

  /// `Still using: {name}`
  String stillUsingProfile(Object name) {
    return Intl.message(
      'Still using: $name',
      name: 'stillUsingProfile',
      desc: '',
      args: [name],
    );
  }

  /// `No config in effect`
  String get noProfileInEffect {
    return Intl.message(
      'No config in effect',
      name: 'noProfileInEffect',
      desc: '',
      args: [],
    );
  }

  /// `The previous config could not be restored either`
  String get profileFallbackFailed {
    return Intl.message(
      'The previous config could not be restored either',
      name: 'profileFallbackFailed',
      desc: '',
      args: [],
    );
  }

  /// `Ignore rule-set load failures`
  String get tolerateRuleProviderErrors {
    return Intl.message(
      'Ignore rule-set load failures',
      name: 'tolerateRuleProviderErrors',
      desc: '',
      args: [],
    );
  }

  /// `Apply the config even if some rule-sets failed to download. When off, any rule-set failure rejects the whole config`
  String get tolerateRuleProviderErrorsDesc {
    return Intl.message(
      'Apply the config even if some rule-sets failed to download. When off, any rule-set failure rejects the whole config',
      name: 'tolerateRuleProviderErrorsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Some rule-sets were not loaded`
  String get ruleProviderWarningsTitle {
    return Intl.message(
      'Some rule-sets were not loaded',
      name: 'ruleProviderWarningsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Encrypt backup`
  String get encryptBackup {
    return Intl.message(
      'Encrypt backup',
      name: 'encryptBackup',
      desc: '',
      args: [],
    );
  }

  /// `Encrypt the backup content with AES-256-GCM. The password is not stored; if lost, the backup cannot be restored`
  String get encryptBackupDesc {
    return Intl.message(
      'Encrypt the backup content with AES-256-GCM. The password is not stored; if lost, the backup cannot be restored',
      name: 'encryptBackupDesc',
      desc: '',
      args: [],
    );
  }

  /// `Backup password`
  String get backupPassword {
    return Intl.message(
      'Backup password',
      name: 'backupPassword',
      desc: '',
      args: [],
    );
  }

  /// `Confirm password`
  String get confirmPassword {
    return Intl.message(
      'Confirm password',
      name: 'confirmPassword',
      desc: '',
      args: [],
    );
  }

  /// `Passwords do not match`
  String get passwordMismatch {
    return Intl.message(
      'Passwords do not match',
      name: 'passwordMismatch',
      desc: '',
      args: [],
    );
  }

  /// `Wrong password or the backup was tampered with`
  String get wrongBackupPassword {
    return Intl.message(
      'Wrong password or the backup was tampered with',
      name: 'wrongBackupPassword',
      desc: '',
      args: [],
    );
  }

  /// `Ensure phone and TV are on the same Wi-Fi network`
  String get tvScanStep1 {
    return Intl.message(
      'Ensure phone and TV are on the same Wi-Fi network',
      name: 'tvScanStep1',
      desc: '',
      args: [],
    );
  }

  /// `Scan the QR code with a supported camera or browser`
  String get tvScanStep2 {
    return Intl.message(
      'Scan the QR code with a supported camera or browser',
      name: 'tvScanStep2',
      desc: '',
      args: [],
    );
  }

  /// `Paste subscription URL or upload profile on the webpage and push`
  String get tvScanStep3 {
    return Intl.message(
      'Paste subscription URL or upload profile on the webpage and push',
      name: 'tvScanStep3',
      desc: '',
      args: [],
    );
  }

  /// `Or enter directly in phone browser:`
  String get tvScanManualUrl {
    return Intl.message(
      'Or enter directly in phone browser:',
      name: 'tvScanManualUrl',
      desc: '',
      args: [],
    );
  }

  /// `Waiting for profile from phone...`
  String get tvScanWaiting {
    return Intl.message(
      'Waiting for profile from phone...',
      name: 'tvScanWaiting',
      desc: '',
      args: [],
    );
  }

  /// `Profile received, importing...`
  String get tvScanSuccess {
    return Intl.message(
      'Profile received, importing...',
      name: 'tvScanSuccess',
      desc: '',
      args: [],
    );
  }

  /// `No available LAN detected, please check Wi-Fi`
  String get tvScanNoNetwork {
    return Intl.message(
      'No available LAN detected, please check Wi-Fi',
      name: 'tvScanNoNetwork',
      desc: '',
      args: [],
    );
  }

  /// `High Refresh Rate`
  String get highRefreshRate {
    return Intl.message(
      'High Refresh Rate',
      name: 'highRefreshRate',
      desc: '',
      args: [],
    );
  }

  /// `Enable highest refresh rate support`
  String get highRefreshRateDesc {
    return Intl.message(
      'Enable highest refresh rate support',
      name: 'highRefreshRateDesc',
      desc: '',
      args: [],
    );
  }

  /// `Use Global Script Override`
  String get useGlobalScriptOverride {
    return Intl.message(
      'Use Global Script Override',
      name: 'useGlobalScriptOverride',
      desc: '',
      args: [],
    );
  }

  /// `Failed to import profile. Please check your network status or try resetting the subscription link ( HTTP error code: {statusCode} )`
  String profileImportFailed(Object statusCode) {
    return Intl.message(
      'Failed to import profile. Please check your network status or try resetting the subscription link ( HTTP error code: $statusCode )',
      name: 'profileImportFailed',
      desc: '',
      args: [statusCode],
    );
  }

  /// `Authorized`
  String get authorized {
    return Intl.message('Authorized', name: 'authorized', desc: '', args: []);
  }

  /// `Unauthorized`
  String get unauthorized {
    return Intl.message(
      'Unauthorized',
      name: 'unauthorized',
      desc: '',
      args: [],
    );
  }

  /// `Age Secret Key (Optional)`
  String get ageSecretKeyOptional {
    return Intl.message(
      'Age Secret Key (Optional)',
      name: 'ageSecretKeyOptional',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid Age secret key (must start with AGE-SECRET-KEY-)`
  String get ageSecretKeyInvalidValidationDesc {
    return Intl.message(
      'Please enter a valid Age secret key (must start with AGE-SECRET-KEY-)',
      name: 'ageSecretKeyInvalidValidationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Age Key Generation`
  String get ageKeyGenerateTitle {
    return Intl.message(
      'Age Key Generation',
      name: 'ageKeyGenerateTitle',
      desc: '',
      args: [],
    );
  }

  /// `Age Private Key`
  String get agePrivateKeyLabel {
    return Intl.message(
      'Age Private Key',
      name: 'agePrivateKeyLabel',
      desc: '',
      args: [],
    );
  }

  /// `Age Public Key`
  String get agePublicKeyLabel {
    return Intl.message(
      'Age Public Key',
      name: 'agePublicKeyLabel',
      desc: '',
      args: [],
    );
  }

  /// `Generate from Age private key`
  String get generateFromPrivateKey {
    return Intl.message(
      'Generate from Age private key',
      name: 'generateFromPrivateKey',
      desc: '',
      args: [],
    );
  }

  /// `X25519 Key pair generated, please keep it safe`
  String get ageKeyPairGeneratedSuccess {
    return Intl.message(
      'X25519 Key pair generated, please keep it safe',
      name: 'ageKeyPairGeneratedSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a correct Age private key first`
  String get agePrivateKeyRequired {
    return Intl.message(
      'Please enter a correct Age private key first',
      name: 'agePrivateKeyRequired',
      desc: '',
      args: [],
    );
  }

  /// `Wrap Lines`
  String get lineWrap {
    return Intl.message('Wrap Lines', name: 'lineWrap', desc: '', args: []);
  }

  /// `Show Hidden Items`
  String get showHiddenItems {
    return Intl.message(
      'Show Hidden Items',
      name: 'showHiddenItems',
      desc: '',
      args: [],
    );
  }

  /// `Comment`
  String get blockComment {
    return Intl.message('Comment', name: 'blockComment', desc: '', args: []);
  }

  /// `Locate`
  String get locate {
    return Intl.message('Locate', name: 'locate', desc: '', args: []);
  }

  /// `Minimize`
  String get minimize {
    return Intl.message('Minimize', name: 'minimize', desc: '', args: []);
  }

  /// `Maximize`
  String get maximize {
    return Intl.message('Maximize', name: 'maximize', desc: '', args: []);
  }

  /// `Restore`
  String get restore {
    return Intl.message('Restore', name: 'restore', desc: '', args: []);
  }

  /// `Pin`
  String get pin {
    return Intl.message('Pin', name: 'pin', desc: '', args: []);
  }

  /// `Unpin`
  String get unpin {
    return Intl.message('Unpin', name: 'unpin', desc: '', args: []);
  }

  /// `Close`
  String get close {
    return Intl.message('Close', name: 'close', desc: '', args: []);
  }

  /// `Auto Scroll`
  String get autoScroll {
    return Intl.message('Auto Scroll', name: 'autoScroll', desc: '', args: []);
  }

  /// `Export`
  String get export {
    return Intl.message('Export', name: 'export', desc: '', args: []);
  }

  /// `Clear`
  String get clear {
    return Intl.message('Clear', name: 'clear', desc: '', args: []);
  }

  /// `Back`
  String get back {
    return Intl.message('Back', name: 'back', desc: '', args: []);
  }

  /// `Close All`
  String get closeAll {
    return Intl.message('Close All', name: 'closeAll', desc: '', args: []);
  }

  /// `More IP Information`
  String get moreIpInfo {
    return Intl.message(
      'More IP Information',
      name: 'moreIpInfo',
      desc: '',
      args: [],
    );
  }

  /// `View Detailed IP Data`
  String get viewDetailedIpData {
    return Intl.message(
      'View Detailed IP Data',
      name: 'viewDetailedIpData',
      desc: '',
      args: [],
    );
  }

  /// `IP Address`
  String get ipAddress {
    return Intl.message('IP Address', name: 'ipAddress', desc: '', args: []);
  }

  /// `Country / Region`
  String get countryOrRegion {
    return Intl.message(
      'Country / Region',
      name: 'countryOrRegion',
      desc: '',
      args: [],
    );
  }

  /// `Province / City`
  String get provinceAndCity {
    return Intl.message(
      'Province / City',
      name: 'provinceAndCity',
      desc: '',
      args: [],
    );
  }

  /// `Organization / ASN`
  String get operatorOrAsn {
    return Intl.message(
      'Organization / ASN',
      name: 'operatorOrAsn',
      desc: '',
      args: [],
    );
  }

  /// `Continent`
  String get continent {
    return Intl.message('Continent', name: 'continent', desc: '', args: []);
  }

  /// `Organization / Domain`
  String get domain {
    return Intl.message(
      'Organization / Domain',
      name: 'domain',
      desc: '',
      args: [],
    );
  }

  /// `Copied to clipboard`
  String get copiedToClipboard {
    return Intl.message(
      'Copied to clipboard',
      name: 'copiedToClipboard',
      desc: '',
      args: [],
    );
  }

  /// `Private / LAN IP Address`
  String get privateIp {
    return Intl.message(
      'Private / LAN IP Address',
      name: 'privateIp',
      desc: '',
      args: [],
    );
  }

  /// `ISP`
  String get isp {
    return Intl.message('ISP', name: 'isp', desc: '', args: []);
  }

  /// `Network error, please try again later`
  String get networkErrorRetryLater {
    return Intl.message(
      'Network error, please try again later',
      name: 'networkErrorRetryLater',
      desc: '',
      args: [],
    );
  }

  /// `TUN Virtual Network Adapter`
  String get tunVirtualAddress {
    return Intl.message(
      'TUN Virtual Network Adapter',
      name: 'tunVirtualAddress',
      desc: '',
      args: [],
    );
  }

  /// `Install Time`
  String get installTime {
    return Intl.message(
      'Install Time',
      name: 'installTime',
      desc: '',
      args: [],
    );
  }

  /// `Update Time`
  String get updateTime {
    return Intl.message('Update Time', name: 'updateTime', desc: '', args: []);
  }

  /// `Core Status`
  String get coreStatus {
    return Intl.message('Core Status', name: 'coreStatus', desc: '', args: []);
  }

  /// `Memory & Runtime`
  String get memoryAndRuntime {
    return Intl.message(
      'Memory & Runtime',
      name: 'memoryAndRuntime',
      desc: '',
      args: [],
    );
  }

  /// `Allocated`
  String get allocatedMemory {
    return Intl.message(
      'Allocated',
      name: 'allocatedMemory',
      desc: '',
      args: [],
    );
  }

  /// `Reclaimable`
  String get reclaimableMemory {
    return Intl.message(
      'Reclaimable',
      name: 'reclaimableMemory',
      desc: '',
      args: [],
    );
  }

  /// `Goroutines`
  String get activeGoroutines {
    return Intl.message(
      'Goroutines',
      name: 'activeGoroutines',
      desc: '',
      args: [],
    );
  }

  /// `Objects`
  String get heapObjects {
    return Intl.message('Objects', name: 'heapObjects', desc: '', args: []);
  }

  /// `Profile & Rules`
  String get profileAndRules {
    return Intl.message(
      'Profile & Rules',
      name: 'profileAndRules',
      desc: '',
      args: [],
    );
  }

  /// `Rules`
  String get rulesCount {
    return Intl.message('Rules', name: 'rulesCount', desc: '', args: []);
  }

  /// `Proxies`
  String get proxiesCount {
    return Intl.message('Proxies', name: 'proxiesCount', desc: '', args: []);
  }

  /// `Proxy Groups`
  String get proxyGroupsCount {
    return Intl.message(
      'Proxy Groups',
      name: 'proxyGroupsCount',
      desc: '',
      args: [],
    );
  }

  /// `Rule Providers`
  String get ruleProvidersCount {
    return Intl.message(
      'Rule Providers',
      name: 'ruleProvidersCount',
      desc: '',
      args: [],
    );
  }

  /// `Proxy Providers`
  String get proxyProvidersCount {
    return Intl.message(
      'Proxy Providers',
      name: 'proxyProvidersCount',
      desc: '',
      args: [],
    );
  }

  /// `GEO Load`
  String get geodataUse {
    return Intl.message('GEO Load', name: 'geodataUse', desc: '', args: []);
  }

  /// `{count}`
  String itemsCount(Object count) {
    return Intl.message('$count', name: 'itemsCount', desc: '', args: [count]);
  }

  /// `Connectivity Test`
  String get mediaUnlock {
    return Intl.message(
      'Connectivity Test',
      name: 'mediaUnlock',
      desc: '',
      args: [],
    );
  }

  /// `Connectivity Test Details`
  String get mediaUnlockDetails {
    return Intl.message(
      'Connectivity Test Details',
      name: 'mediaUnlockDetails',
      desc: '',
      args: [],
    );
  }

  /// `Display Settings`
  String get mediaUnlockDisplaySettings {
    return Intl.message(
      'Display Settings',
      name: 'mediaUnlockDisplaySettings',
      desc: '',
      args: [],
    );
  }

  /// `Misc Settings`
  String get mediaUnlockMiscSettings {
    return Intl.message(
      'Misc Settings',
      name: 'mediaUnlockMiscSettings',
      desc: '',
      args: [],
    );
  }

  /// `Show more IP details`
  String get mediaUnlockExtraDetails {
    return Intl.message(
      'Show more IP details',
      name: 'mediaUnlockExtraDetails',
      desc: '',
      args: [],
    );
  }

  /// `Auto refresh on node change`
  String get mediaUnlockRefreshOnNodeChange {
    return Intl.message(
      'Auto refresh on node change',
      name: 'mediaUnlockRefreshOnNodeChange',
      desc: '',
      args: [],
    );
  }

  /// `Show colored icons by default`
  String get mediaUnlockColorfulIcons {
    return Intl.message(
      'Show colored icons by default',
      name: 'mediaUnlockColorfulIcons',
      desc: '',
      args: [],
    );
  }

  /// `Select up to 4 items to pin on the widget`
  String get mediaUnlockPinnedSettingsDesc {
    return Intl.message(
      'Select up to 4 items to pin on the widget',
      name: 'mediaUnlockPinnedSettingsDesc',
      desc: '',
      args: [],
    );
  }

  /// `You can select up to 4 items`
  String get mediaUnlockSelectLimit {
    return Intl.message(
      'You can select up to 4 items',
      name: 'mediaUnlockSelectLimit',
      desc: '',
      args: [],
    );
  }

  /// `All`
  String get categoryAll {
    return Intl.message('All', name: 'categoryAll', desc: '', args: []);
  }

  /// `AI`
  String get categoryAi {
    return Intl.message('AI', name: 'categoryAi', desc: '', args: []);
  }

  /// `Streaming`
  String get categoryStreaming {
    return Intl.message(
      'Streaming',
      name: 'categoryStreaming',
      desc: '',
      args: [],
    );
  }

  /// `China Direct`
  String get categoryChina {
    return Intl.message(
      'China Direct',
      name: 'categoryChina',
      desc: '',
      args: [],
    );
  }

  /// `Social Platforms`
  String get categorySocial {
    return Intl.message(
      'Social Platforms',
      name: 'categorySocial',
      desc: '',
      args: [],
    );
  }

  /// `Developer`
  String get categoryDeveloper {
    return Intl.message(
      'Developer',
      name: 'categoryDeveloper',
      desc: '',
      args: [],
    );
  }

  /// `Gaming Center`
  String get categoryGaming {
    return Intl.message(
      'Gaming Center',
      name: 'categoryGaming',
      desc: '',
      args: [],
    );
  }

  /// `Crypto`
  String get categoryCrypto {
    return Intl.message('Crypto', name: 'categoryCrypto', desc: '', args: []);
  }

  /// `Completed`
  String get unlocked {
    return Intl.message('Completed', name: 'unlocked', desc: '', args: []);
  }

  /// `Unlocked`
  String get mediaUnlocked {
    return Intl.message('Unlocked', name: 'mediaUnlocked', desc: '', args: []);
  }

  /// `Originals Only`
  String get limitedUnlock {
    return Intl.message(
      'Originals Only',
      name: 'limitedUnlock',
      desc: '',
      args: [],
    );
  }

  /// `Not Unlocked`
  String get notUnlocked {
    return Intl.message(
      'Not Unlocked',
      name: 'notUnlocked',
      desc: '',
      args: [],
    );
  }

  /// `Timeout`
  String get checkFailed {
    return Intl.message('Timeout', name: 'checkFailed', desc: '', args: []);
  }

  /// `Testing`
  String get testing {
    return Intl.message('Testing', name: 'testing', desc: '', args: []);
  }

  /// `Flagged`
  String get flagged {
    return Intl.message('Flagged', name: 'flagged', desc: '', args: []);
  }

  /// `Add Landing Proxy`
  String get addLandingProxy {
    return Intl.message(
      'Add Landing Proxy',
      name: 'addLandingProxy',
      desc: '',
      args: [],
    );
  }

  /// `Add {role} candidate`
  String addRoleCandidate(Object role) {
    return Intl.message(
      'Add $role candidate',
      name: 'addRoleCandidate',
      desc: '',
      args: [role],
    );
  }

  /// `Add {role} backup candidate`
  String addRoleFallbackCandidate(Object role) {
    return Intl.message(
      'Add $role backup candidate',
      name: 'addRoleFallbackCandidate',
      desc: '',
      args: [role],
    );
  }

  /// `Ascending`
  String get ascending {
    return Intl.message('Ascending', name: 'ascending', desc: '', args: []);
  }

  /// `Automatic failover`
  String get autoFailover {
    return Intl.message(
      'Automatic failover',
      name: 'autoFailover',
      desc: '',
      args: [],
    );
  }

  /// `Off: only the button below can switch manually`
  String get autoFailoverOffDesc {
    return Intl.message(
      'Off: only the button below can switch manually',
      name: 'autoFailoverOffDesc',
      desc: '',
      args: [],
    );
  }

  /// `Switches to a backup candidate when the chain keeps failing`
  String get autoFailoverOnDesc {
    return Intl.message(
      'Switches to a backup candidate when the chain keeps failing',
      name: 'autoFailoverOnDesc',
      desc: '',
      args: [],
    );
  }

  /// `Auto-inject into the main selector group`
  String get autoInjectGroups {
    return Intl.message(
      'Auto-inject into the main selector group',
      name: 'autoInjectGroups',
      desc: '',
      args: [],
    );
  }

  /// `Automatically adds enabled landing proxies to main routing groups such as 「节点选择」`
  String get autoInjectGroupsDesc {
    return Intl.message(
      'Automatically adds enabled landing proxies to main routing groups such as 「节点选择」',
      name: 'autoInjectGroupsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Checking ({completed}/{total})…`
  String batchCheckingProgress(Object completed, Object total) {
    return Intl.message(
      'Checking ($completed/$total)…',
      name: 'batchCheckingProgress',
      desc: '',
      args: [completed, total],
    );
  }

  /// `Hop 3 (exit node)`
  String get chainHopExitNode {
    return Intl.message(
      'Hop 3 (exit node)',
      name: 'chainHopExitNode',
      desc: '',
      args: [],
    );
  }

  /// `Incomplete three-hop chain: select a relay node and an exit node`
  String get chainHopIncomplete {
    return Intl.message(
      'Incomplete three-hop chain: select a relay node and an exit node',
      name: 'chainHopIncomplete',
      desc: '',
      args: [],
    );
  }

  /// `Chain Hops`
  String get chainHopMode {
    return Intl.message('Chain Hops', name: 'chainHopMode', desc: '', args: []);
  }

  /// `Two hops: entry hop → landing exit. Three hops inserts an additional relay node.`
  String get chainHopModeDesc {
    return Intl.message(
      'Two hops: entry hop → landing exit. Three hops inserts an additional relay node.',
      name: 'chainHopModeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Not selected`
  String get chainHopNotSelected {
    return Intl.message(
      'Not selected',
      name: 'chainHopNotSelected',
      desc: '',
      args: [],
    );
  }

  /// `Hop 2 (relay node)`
  String get chainHopRelayNode {
    return Intl.message(
      'Hop 2 (relay node)',
      name: 'chainHopRelayNode',
      desc: '',
      args: [],
    );
  }

  /// `Could not read the list of available nodes, so node availability could not be verified`
  String get chainHopUnavailable {
    return Intl.message(
      'Could not read the list of available nodes, so node availability could not be verified',
      name: 'chainHopUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Chain Proxy`
  String get chainProxy {
    return Intl.message('Chain Proxy', name: 'chainProxy', desc: '', args: []);
  }

  /// `Configure an entry hop and a static residential landing IP`
  String get chainProxyDesc {
    return Intl.message(
      'Configure an entry hop and a static residential landing IP',
      name: 'chainProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Cipher`
  String get cipher {
    return Intl.message('Cipher', name: 'cipher', desc: '', args: []);
  }

  /// `Remove unavailable nodes`
  String get clearInvalidProxies {
    return Intl.message(
      'Remove unavailable nodes',
      name: 'clearInvalidProxies',
      desc: '',
      args: [],
    );
  }

  /// `Cleared {count} invalid nodes`
  String clearedInvalidCount(Object count) {
    return Intl.message(
      'Cleared $count invalid nodes',
      name: 'clearedInvalidCount',
      desc: '',
      args: [count],
    );
  }

  /// `Remove every residential IP that failed the check?`
  String get confirmClearInvalid {
    return Intl.message(
      'Remove every residential IP that failed the check?',
      name: 'confirmClearInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Create a dedicated chain proxy group`
  String get dedicatedGroup {
    return Intl.message(
      'Create a dedicated chain proxy group',
      name: 'dedicatedGroup',
      desc: '',
      args: [],
    );
  }

  /// `Adds a standalone 「🔗 链式代理」 policy group card on the proxies page`
  String get dedicatedGroupDesc {
    return Intl.message(
      'Adds a standalone 「🔗 链式代理」 policy group card on the proxies page',
      name: 'dedicatedGroupDesc',
      desc: '',
      args: [],
    );
  }

  /// `Default Entry Hop`
  String get defaultDialerProxy {
    return Intl.message(
      'Default Entry Hop',
      name: 'defaultDialerProxy',
      desc: '',
      args: [],
    );
  }

  /// `Entry node or policy group that landing proxies use by default (a selector group is recommended)`
  String get defaultDialerProxyDesc {
    return Intl.message(
      'Entry node or policy group that landing proxies use by default (a selector group is recommended)',
      name: 'defaultDialerProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Descending`
  String get descending {
    return Intl.message('Descending', name: 'descending', desc: '', args: []);
  }

  /// `Diagnostic advice`
  String get diagnosticAdvice {
    return Intl.message(
      'Diagnostic advice',
      name: 'diagnosticAdvice',
      desc: '',
      args: [],
    );
  }

  /// `DIRECT (no hop)`
  String get directConnection {
    return Intl.message(
      'DIRECT (no hop)',
      name: 'directConnection',
      desc: '',
      args: [],
    );
  }

  /// `No residential landing nodes yet. Paste in the common formats used by major residential IP providers (IPRoyal, LunaProxy, Oxylabs and others) to import them in one click.`
  String get emptyLandingTip {
    return Intl.message(
      'No residential landing nodes yet. Paste in the common formats used by major residential IP providers (IPRoyal, LunaProxy, Oxylabs and others) to import them in one click.',
      name: 'emptyLandingTip',
      desc: '',
      args: [],
    );
  }

  /// `Enable Chain Proxy`
  String get enableChainProxy {
    return Intl.message(
      'Enable Chain Proxy',
      name: 'enableChainProxy',
      desc: '',
      args: [],
    );
  }

  /// `Relay through an entry node to reach the landing proxy, bypassing network restrictions while keeping a real residential exit`
  String get enableChainProxyDesc {
    return Intl.message(
      'Relay through an entry node to reach the landing proxy, bypassing network restrictions while keeping a real residential exit',
      name: 'enableChainProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Failover`
  String get failover {
    return Intl.message('Failover', name: 'failover', desc: '', args: []);
  }

  /// `Enable chain proxy first`
  String get failoverEnableFirst {
    return Intl.message(
      'Enable chain proxy first',
      name: 'failoverEnableFirst',
      desc: '',
      args: [],
    );
  }

  /// `Failover failed: {reason}`
  String failoverFailed(Object reason) {
    return Intl.message(
      'Failover failed: $reason',
      name: 'failoverFailed',
      desc: '',
      args: [reason],
    );
  }

  /// `Failing over…`
  String get failoverInProgress {
    return Intl.message(
      'Failing over…',
      name: 'failoverInProgress',
      desc: '',
      args: [],
    );
  }

  /// `Switch to a backup candidate manually when the chain fails`
  String get failoverManualHint {
    return Intl.message(
      'Switch to a backup candidate manually when the chain fails',
      name: 'failoverManualHint',
      desc: '',
      args: [],
    );
  }

  /// `No backup candidates configured yet`
  String get failoverNoCandidates {
    return Intl.message(
      'No backup candidates configured yet',
      name: 'failoverNoCandidates',
      desc: '',
      args: [],
    );
  }

  /// `Add a backup candidate for at least one role above, then try again`
  String get failoverNoCandidatesAdvice {
    return Intl.message(
      'Add a backup candidate for at least one role above, then try again',
      name: 'failoverNoCandidatesAdvice',
      desc: '',
      args: [],
    );
  }

  /// `Failover succeeded, switched to [{node}]`
  String failoverSuccess(Object node) {
    return Intl.message(
      'Failover succeeded, switched to [$node]',
      name: 'failoverSuccess',
      desc: '',
      args: [node],
    );
  }

  /// `Fail over now`
  String get failoverTrigger {
    return Intl.message(
      'Fail over now',
      name: 'failoverTrigger',
      desc: '',
      args: [],
    );
  }

  /// `User triggered failover manually`
  String get failoverTriggerReason {
    return Intl.message(
      'User triggered failover manually',
      name: 'failoverTriggerReason',
      desc: '',
      args: [],
    );
  }

  /// `All`
  String get filterAll {
    return Intl.message('All', name: 'filterAll', desc: '', args: []);
  }

  /// `Unavailable / not checked`
  String get filterError {
    return Intl.message(
      'Unavailable / not checked',
      name: 'filterError',
      desc: '',
      args: [],
    );
  }

  /// `Working only`
  String get filterHealthy {
    return Intl.message(
      'Working only',
      name: 'filterHealthy',
      desc: '',
      args: [],
    );
  }

  /// `Follow the current selector group (recommended)`
  String get followMainSelector {
    return Intl.message(
      'Follow the current selector group (recommended)',
      name: 'followMainSelector',
      desc: '',
      args: [],
    );
  }

  /// `Connectivity Check`
  String get healthCheck {
    return Intl.message(
      'Connectivity Check',
      name: 'healthCheck',
      desc: '',
      args: [],
    );
  }

  /// `Full Check`
  String get healthCheckAll {
    return Intl.message(
      'Full Check',
      name: 'healthCheckAll',
      desc: '',
      args: [],
    );
  }

  /// `Unavailable`
  String get healthError {
    return Intl.message('Unavailable', name: 'healthError', desc: '', args: []);
  }

  /// `Working`
  String get healthHealthy {
    return Intl.message('Working', name: 'healthHealthy', desc: '', args: []);
  }

  /// `Residential IP Connectivity Report`
  String get healthReport {
    return Intl.message(
      'Residential IP Connectivity Report',
      name: 'healthReport',
      desc: '',
      args: [],
    );
  }

  /// `Not checked`
  String get healthUntested {
    return Intl.message(
      'Not checked',
      name: 'healthUntested',
      desc: '',
      args: [],
    );
  }

  /// `Partially limited`
  String get healthWarning {
    return Intl.message(
      'Partially limited',
      name: 'healthWarning',
      desc: '',
      args: [],
    );
  }

  /// `Hop`
  String get hop {
    return Intl.message('Hop', name: 'hop', desc: '', args: []);
  }

  /// `Imported {count} landing proxy nodes`
  String importSuccessCount(Object count) {
    return Intl.message(
      'Imported $count landing proxy nodes',
      name: 'importSuccessCount',
      desc: '',
      args: [count],
    );
  }

  /// `Skipped duplicate node names (landing proxies must be unique)`
  String get duplicateNodeSkipped {
    return Intl.message(
      'Skipped duplicate node names (landing proxies must be unique)',
      name: 'duplicateNodeSkipped',
      desc: '',
      args: [],
    );
  }

  /// `Inherit the global default hop`
  String get inheritDefaultDialer {
    return Intl.message(
      'Inherit the global default hop',
      name: 'inheritDefaultDialer',
      desc: '',
      args: [],
    );
  }

  /// `Paste residential IP details, e.g.\n198.51.100.1:8000:username:password\nor socks5://user:pass@198.51.100.1:8000\nSupports pasting multiple lines at once.`
  String get inputProxyTextHint {
    return Intl.message(
      'Paste residential IP details, e.g.\n198.51.100.1:8000:username:password\nor socks5://user:pass@198.51.100.1:8000\nSupports pasting multiple lines at once.',
      name: 'inputProxyTextHint',
      desc: '',
      args: [],
    );
  }

  /// `Residential Landing Nodes`
  String get landingProxies {
    return Intl.message(
      'Residential Landing Nodes',
      name: 'landingProxies',
      desc: '',
      args: [],
    );
  }

  /// `There are no unavailable nodes right now`
  String get noInvalidProxies {
    return Intl.message(
      'There are no unavailable nodes right now',
      name: 'noInvalidProxies',
      desc: '',
      args: [],
    );
  }

  /// `Node Name`
  String get nodeName {
    return Intl.message('Node Name', name: 'nodeName', desc: '', args: []);
  }

  /// `No valid proxy information found. Please check the format.`
  String get parseNoValidNode {
    return Intl.message(
      'No valid proxy information found. Please check the format.',
      name: 'parseNoValidNode',
      desc: '',
      args: [],
    );
  }

  /// `Paste from Clipboard`
  String get pasteFromClipboard {
    return Intl.message(
      'Paste from Clipboard',
      name: 'pasteFromClipboard',
      desc: '',
      args: [],
    );
  }

  /// `Prevent WebRTC real IP leaks`
  String get preventWebRtcLeak {
    return Intl.message(
      'Prevent WebRTC real IP leaks',
      name: 'preventWebRtcLeak',
      desc: '',
      args: [],
    );
  }

  /// `Blocks STUN/TURN probes to stop real public IP exposure, keeping overseas accounts and cross-border e-commerce safe`
  String get preventWebRtcLeakDesc {
    return Intl.message(
      'Blocks STUN/TURN probes to stop real public IP exposure, keeping overseas accounts and cross-border e-commerce safe',
      name: 'preventWebRtcLeakDesc',
      desc: '',
      args: [],
    );
  }

  /// `Proxy Protocol`
  String get protocol {
    return Intl.message('Proxy Protocol', name: 'protocol', desc: '', args: []);
  }

  /// `Smart Quick Import`
  String get quickImport {
    return Intl.message(
      'Smart Quick Import',
      name: 'quickImport',
      desc: '',
      args: [],
    );
  }

  /// `One-click import from IP:port:user:password, links and other common formats`
  String get quickImportDesc {
    return Intl.message(
      'One-click import from IP:port:user:password, links and other common formats',
      name: 'quickImportDesc',
      desc: '',
      args: [],
    );
  }

  /// `Check again`
  String get retest {
    return Intl.message('Check again', name: 'retest', desc: '', args: []);
  }

  /// `Entry node`
  String get roleEntry {
    return Intl.message('Entry node', name: 'roleEntry', desc: '', args: []);
  }

  /// `Landing exit`
  String get roleExit {
    return Intl.message('Landing exit', name: 'roleExit', desc: '', args: []);
  }

  /// `Relay node`
  String get roleRelay {
    return Intl.message('Relay node', name: 'roleRelay', desc: '', args: []);
  }

  /// `Server Address`
  String get serverAddress {
    return Intl.message(
      'Server Address',
      name: 'serverAddress',
      desc: '',
      args: [],
    );
  }

  /// `Specify a dedicated hop`
  String get specificDialerProxy {
    return Intl.message(
      'Specify a dedicated hop',
      name: 'specificDialerProxy',
      desc: '',
      args: [],
    );
  }

  /// `The system proxy is actually off`
  String get systemProxyActualOff {
    return Intl.message(
      'The system proxy is actually off',
      name: 'systemProxyActualOff',
      desc: '',
      args: [],
    );
  }

  /// `The system proxy is actually on`
  String get systemProxyActualOn {
    return Intl.message(
      'The system proxy is actually on',
      name: 'systemProxyActualOn',
      desc: '',
      args: [],
    );
  }

  /// `Actual system status`
  String get systemProxyActualStatus {
    return Intl.message(
      'Actual system status',
      name: 'systemProxyActualStatus',
      desc: '',
      args: [],
    );
  }

  /// `Checking the actual system status…`
  String get systemProxyChecking {
    return Intl.message(
      'Checking the actual system status…',
      name: 'systemProxyChecking',
      desc: '',
      args: [],
    );
  }

  /// `The system proxy is still on`
  String get systemProxyMismatchOff {
    return Intl.message(
      'The system proxy is still on',
      name: 'systemProxyMismatchOff',
      desc: '',
      args: [],
    );
  }

  /// `The setting requests the proxy on, but the system proxy is not actually on`
  String get systemProxyMismatchOn {
    return Intl.message(
      'The setting requests the proxy on, but the system proxy is not actually on',
      name: 'systemProxyMismatchOn',
      desc: '',
      args: [],
    );
  }

  /// `Cannot determine the system proxy status`
  String get systemProxyUnknown {
    return Intl.message(
      'Cannot determine the system proxy status',
      name: 'systemProxyUnknown',
      desc: '',
      args: [],
    );
  }

  /// `This platform does not support system proxy status detection`
  String get systemProxyUnsupported {
    return Intl.message(
      'This platform does not support system proxy status detection',
      name: 'systemProxyUnsupported',
      desc: '',
      args: [],
    );
  }

  /// `Test All`
  String get testAll {
    return Intl.message('Test All', name: 'testAll', desc: '', args: []);
  }

  /// `Test connectivity`
  String get testCurrentProxy {
    return Intl.message(
      'Test connectivity',
      name: 'testCurrentProxy',
      desc: '',
      args: [],
    );
  }

  /// `Checking…`
  String get testingHealth {
    return Intl.message('Checking…', name: 'testingHealth', desc: '', args: []);
  }

  /// `This device`
  String get topologyClient {
    return Intl.message(
      'This device',
      name: 'topologyClient',
      desc: '',
      args: [],
    );
  }

  /// `Entry hop`
  String get topologyHop {
    return Intl.message('Entry hop', name: 'topologyHop', desc: '', args: []);
  }

  /// `Residential landing`
  String get topologyLanding {
    return Intl.message(
      'Residential landing',
      name: 'topologyLanding',
      desc: '',
      args: [],
    );
  }

  /// `Relay node`
  String get topologyRelay {
    return Intl.message(
      'Relay node',
      name: 'topologyRelay',
      desc: '',
      args: [],
    );
  }

  /// `Target service`
  String get topologyTarget {
    return Intl.message(
      'Target service',
      name: 'topologyTarget',
      desc: '',
      args: [],
    );
  }

  /// `The system TUN is actually disabled`
  String get tunActualOff {
    return Intl.message(
      'The system TUN is actually disabled',
      name: 'tunActualOff',
      desc: '',
      args: [],
    );
  }

  /// `The system TUN is actually enabled`
  String get tunActualOn {
    return Intl.message(
      'The system TUN is actually enabled',
      name: 'tunActualOn',
      desc: '',
      args: [],
    );
  }

  /// `Actual TUN status`
  String get tunActualStatus {
    return Intl.message(
      'Actual TUN status',
      name: 'tunActualStatus',
      desc: '',
      args: [],
    );
  }

  /// `Checking the actual TUN status…`
  String get tunChecking {
    return Intl.message(
      'Checking the actual TUN status…',
      name: 'tunChecking',
      desc: '',
      args: [],
    );
  }

  /// `TUN is still enabled`
  String get tunMismatchOff {
    return Intl.message(
      'TUN is still enabled',
      name: 'tunMismatchOff',
      desc: '',
      args: [],
    );
  }

  /// `The setting requests TUN on, but the system TUN is not actually enabled`
  String get tunMismatchOn {
    return Intl.message(
      'The setting requests TUN on, but the system TUN is not actually enabled',
      name: 'tunMismatchOn',
      desc: '',
      args: [],
    );
  }

  /// `Cannot determine the actual TUN status`
  String get tunUnknown {
    return Intl.message(
      'Cannot determine the actual TUN status',
      name: 'tunUnknown',
      desc: '',
      args: [],
    );
  }

  /// `This platform does not report the actual TUN status`
  String get tunUnsupported {
    return Intl.message(
      'This platform does not report the actual TUN status',
      name: 'tunUnsupported',
      desc: '',
      args: [],
    );
  }

  /// `UDP Forwarding`
  String get udpForwarding {
    return Intl.message(
      'UDP Forwarding',
      name: 'udpForwarding',
      desc: '',
      args: [],
    );
  }

  /// `Turn this off if the residential IP does not support UDP and causes errors`
  String get udpForwardingDesc {
    return Intl.message(
      'Turn this off if the residential IP does not support UDP and causes errors',
      name: 'udpForwardingDesc',
      desc: '',
      args: [],
    );
  }

  /// `Username`
  String get username {
    return Intl.message('Username', name: 'username', desc: '', args: []);
  }

  /// `Create Empty Group`
  String get createEmptyGroup {
    return Intl.message(
      'Create Empty Group',
      name: 'createEmptyGroup',
      desc: '',
      args: [],
    );
  }

  /// `Create a new blank configuration, supporting manual entry and management of self-hosted nodes across all protocols`
  String get createEmptyGroupDesc {
    return Intl.message(
      'Create a new blank configuration, supporting manual entry and management of self-hosted nodes across all protocols',
      name: 'createEmptyGroupDesc',
      desc: '',
      args: [],
    );
  }

  /// `Custom Nodes`
  String get customNodesDefaultName {
    return Intl.message(
      'Custom Nodes',
      name: 'customNodesDefaultName',
      desc: '',
      args: [],
    );
  }

  /// `After creating a blank group, you can manually add nodes for each protocol or import share links in bulk with one click.`
  String get createEmptyGroupHint {
    return Intl.message(
      'After creating a blank group, you can manually add nodes for each protocol or import share links in bulk with one click.',
      name: 'createEmptyGroupHint',
      desc: '',
      args: [],
    );
  }

  /// `Group Name`
  String get groupName {
    return Intl.message('Group Name', name: 'groupName', desc: '', args: []);
  }

  /// `Blank group "{name}" created, please add nodes`
  String createGroupSuccess(Object name) {
    return Intl.message(
      'Blank group "$name" created, please add nodes',
      name: 'createGroupSuccess',
      desc: '',
      args: [name],
    );
  }

  /// `Failed to create group: {error}`
  String createGroupFailed(Object error) {
    return Intl.message(
      'Failed to create group: $error',
      name: 'createGroupFailed',
      desc: '',
      args: [error],
    );
  }

  /// `Pre-proxy & Landing Proxy · {name}`
  String profileChainDialogTitle(Object name) {
    return Intl.message(
      'Pre-proxy & Landing Proxy · $name',
      name: 'profileChainDialogTitle',
      desc: '',
      args: [name],
    );
  }

  /// `Chain routing topology preview`
  String get chainTopologyPreview {
    return Intl.message(
      'Chain routing topology preview',
      name: 'chainTopologyPreview',
      desc: '',
      args: [],
    );
  }

  /// `Device app`
  String get chainNodeDeviceApp {
    return Intl.message(
      'Device app',
      name: 'chainNodeDeviceApp',
      desc: '',
      args: [],
    );
  }

  /// `Local`
  String get chainNodeLocal {
    return Intl.message('Local', name: 'chainNodeLocal', desc: '', args: []);
  }

  /// `Pre-proxy`
  String get chainNodePreProxy {
    return Intl.message(
      'Pre-proxy',
      name: 'chainNodePreProxy',
      desc: '',
      args: [],
    );
  }

  /// `Direct (none)`
  String get chainPreProxyNone {
    return Intl.message(
      'Direct (none)',
      name: 'chainPreProxyNone',
      desc: '',
      args: [],
    );
  }

  /// `Subscription node`
  String get chainNodeSubscription {
    return Intl.message(
      'Subscription node',
      name: 'chainNodeSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Group nodes`
  String get chainNodeGroupNodes {
    return Intl.message(
      'Group nodes',
      name: 'chainNodeGroupNodes',
      desc: '',
      args: [],
    );
  }

  /// `Default (none)`
  String get chainLandingProxyNone {
    return Intl.message(
      'Default (none)',
      name: 'chainLandingProxyNone',
      desc: '',
      args: [],
    );
  }

  /// `Enable chained proxy for this subscription group`
  String get enableProfileChain {
    return Intl.message(
      'Enable chained proxy for this subscription group',
      name: 'enableProfileChain',
      desc: '',
      args: [],
    );
  }

  /// `Supports pre-proxy relay hopping and final landing exit configuration`
  String get enableProfileChainDesc {
    return Intl.message(
      'Supports pre-proxy relay hopping and final landing exit configuration',
      name: 'enableProfileChainDesc',
      desc: '',
      args: [],
    );
  }

  /// `1. Pre-proxy`
  String get preProxySectionTitle {
    return Intl.message(
      '1. Pre-proxy',
      name: 'preProxySectionTitle',
      desc: '',
      args: [],
    );
  }

  /// `Before traffic enters the subscription node, it first tunnels through the pre-proxy node. Useful for rescuing blocked nodes.`
  String get preProxySectionDesc {
    return Intl.message(
      'Before traffic enters the subscription node, it first tunnels through the pre-proxy node. Useful for rescuing blocked nodes.',
      name: 'preProxySectionDesc',
      desc: '',
      args: [],
    );
  }

  /// `None (connect directly to subscription node)`
  String get preProxyOptionNone {
    return Intl.message(
      'None (connect directly to subscription node)',
      name: 'preProxyOptionNone',
      desc: '',
      args: [],
    );
  }

  /// `✏️ Manually enter pre-proxy node name...`
  String get preProxyOptionCustom {
    return Intl.message(
      '✏️ Manually enter pre-proxy node name...',
      name: 'preProxyOptionCustom',
      desc: '',
      args: [],
    );
  }

  /// `Custom pre-proxy node name`
  String get customPreProxyName {
    return Intl.message(
      'Custom pre-proxy node name',
      name: 'customPreProxyName',
      desc: '',
      args: [],
    );
  }

  /// `2. Landing proxy`
  String get landingProxySectionTitle {
    return Intl.message(
      '2. Landing proxy',
      name: 'landingProxySectionTitle',
      desc: '',
      args: [],
    );
  }

  /// `The subscription node acts as the pre-proxy hop, and this node becomes the final exit. Useful for hiding airport IPs, chaining WARP to avoid blocking, and unlocking AI and streaming.`
  String get landingProxySectionDesc {
    return Intl.message(
      'The subscription node acts as the pre-proxy hop, and this node becomes the final exit. Useful for hiding airport IPs, chaining WARP to avoid blocking, and unlocking AI and streaming.',
      name: 'landingProxySectionDesc',
      desc: '',
      args: [],
    );
  }

  /// `None (use subscription node as final exit)`
  String get landingProxyOptionNone {
    return Intl.message(
      'None (use subscription node as final exit)',
      name: 'landingProxyOptionNone',
      desc: '',
      args: [],
    );
  }

  /// `✏️ Manually enter landing node name...`
  String get landingProxyOptionCustom {
    return Intl.message(
      '✏️ Manually enter landing node name...',
      name: 'landingProxyOptionCustom',
      desc: '',
      args: [],
    );
  }

  /// `Custom landing node name`
  String get customLandingProxyName {
    return Intl.message(
      'Custom landing node name',
      name: 'customLandingProxyName',
      desc: '',
      args: [],
    );
  }

  /// `Pre-proxy and landing proxy settings saved`
  String get profileChainSaved {
    return Intl.message(
      'Pre-proxy and landing proxy settings saved',
      name: 'profileChainSaved',
      desc: '',
      args: [],
    );
  }

  /// `Save and apply`
  String get saveAndApply {
    return Intl.message(
      'Save and apply',
      name: 'saveAndApply',
      desc: '',
      args: [],
    );
  }

  /// `Confirm deletion`
  String get confirmDelete {
    return Intl.message(
      'Confirm deletion',
      name: 'confirmDelete',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete node "{name}"?`
  String confirmDeleteNodeMsg(Object name) {
    return Intl.message(
      'Are you sure you want to delete node "$name"?',
      name: 'confirmDeleteNodeMsg',
      desc: '',
      args: [name],
    );
  }

  /// `Node deleted: {name}`
  String nodeDeleted(Object name) {
    return Intl.message(
      'Node deleted: $name',
      name: 'nodeDeleted',
      desc: '',
      args: [name],
    );
  }

  /// `Batch import share links`
  String get batchImportShareLinks {
    return Intl.message(
      'Batch import share links',
      name: 'batchImportShareLinks',
      desc: '',
      args: [],
    );
  }

  /// `Supports single/multi-line links or YAML/JSON node snippets:`
  String get batchImportSupportHint {
    return Intl.message(
      'Supports single/multi-line links or YAML/JSON node snippets:',
      name: 'batchImportSupportHint',
      desc: '',
      args: [],
    );
  }

  /// `Paste node share links or node config (YAML/JSON) here...`
  String get batchImportPasteHint {
    return Intl.message(
      'Paste node share links or node config (YAML/JSON) here...',
      name: 'batchImportPasteHint',
      desc: '',
      args: [],
    );
  }

  /// `No valid node link could be parsed. Please check the format.`
  String get batchImportParseFailed {
    return Intl.message(
      'No valid node link could be parsed. Please check the format.',
      name: 'batchImportParseFailed',
      desc: '',
      args: [],
    );
  }

  /// `Successfully imported {count} node(s)`
  String batchImportSuccess(Object count) {
    return Intl.message(
      'Successfully imported $count node(s)',
      name: 'batchImportSuccess',
      desc: '',
      args: [count],
    );
  }

  /// `Confirm import`
  String get confirmImport {
    return Intl.message(
      'Confirm import',
      name: 'confirmImport',
      desc: '',
      args: [],
    );
  }

  /// `Node management · {name}`
  String nodeManagement(Object name) {
    return Intl.message(
      'Node management · $name',
      name: 'nodeManagement',
      desc: '',
      args: [name],
    );
  }

  /// `Batch import links`
  String get batchImportLinks {
    return Intl.message(
      'Batch import links',
      name: 'batchImportLinks',
      desc: '',
      args: [],
    );
  }

  /// `Refresh`
  String get refresh {
    return Intl.message('Refresh', name: 'refresh', desc: '', args: []);
  }

  /// `Manually add node`
  String get manualAddNode {
    return Intl.message(
      'Manually add node',
      name: 'manualAddNode',
      desc: '',
      args: [],
    );
  }

  /// `No nodes in this group yet`
  String get noNodesInGroup {
    return Intl.message(
      'No nodes in this group yet',
      name: 'noNodesInGroup',
      desc: '',
      args: [],
    );
  }

  /// `Tap "Manually add node" at the bottom right or "Batch import links" at the top right`
  String get noNodesInGroupHint {
    return Intl.message(
      'Tap "Manually add node" at the bottom right or "Batch import links" at the top right',
      name: 'noNodesInGroupHint',
      desc: '',
      args: [],
    );
  }

  /// `Import share links`
  String get importShareLinks {
    return Intl.message(
      'Import share links',
      name: 'importShareLinks',
      desc: '',
      args: [],
    );
  }

  /// `Manual entry`
  String get manualEntry {
    return Intl.message(
      'Manual entry',
      name: 'manualEntry',
      desc: '',
      args: [],
    );
  }

  /// `Unnamed node`
  String get unnamedNode {
    return Intl.message(
      'Unnamed node',
      name: 'unnamedNode',
      desc: '',
      args: [],
    );
  }

  /// `Custom config node`
  String get customConfigNode {
    return Intl.message(
      'Custom config node',
      name: 'customConfigNode',
      desc: '',
      args: [],
    );
  }

  /// `Delete node`
  String get deleteNode {
    return Intl.message('Delete node', name: 'deleteNode', desc: '', args: []);
  }

  /// `Node protocol`
  String get nodeProtocol {
    return Intl.message(
      'Node protocol',
      name: 'nodeProtocol',
      desc: '',
      args: [],
    );
  }

  /// `Enter or paste a complete node YAML or JSON config snippet here:`
  String get customConfigHintText {
    return Intl.message(
      'Enter or paste a complete node YAML or JSON config snippet here:',
      name: 'customConfigHintText',
      desc: '',
      args: [],
    );
  }

  /// `Custom config (YAML / JSON)`
  String get customConfigLabel {
    return Intl.message(
      'Custom config (YAML / JSON)',
      name: 'customConfigLabel',
      desc: '',
      args: [],
    );
  }

  /// `Node name`
  String get nodeNameLabel {
    return Intl.message('Node name', name: 'nodeNameLabel', desc: '', args: []);
  }

  /// `e.g. Hong Kong 01 - {proto}`
  String nodeNameHint(Object proto) {
    return Intl.message(
      'e.g. Hong Kong 01 - $proto',
      name: 'nodeNameHint',
      desc: '',
      args: [proto],
    );
  }

  /// `Server address`
  String get serverAddressLabel {
    return Intl.message(
      'Server address',
      name: 'serverAddressLabel',
      desc: '',
      args: [],
    );
  }

  /// `IP or domain`
  String get serverAddressHint {
    return Intl.message(
      'IP or domain',
      name: 'serverAddressHint',
      desc: '',
      args: [],
    );
  }

  /// `Port`
  String get portLabel {
    return Intl.message('Port', name: 'portLabel', desc: '', args: []);
  }

  /// `Private key`
  String get privateKey {
    return Intl.message('Private key', name: 'privateKey', desc: '', args: []);
  }

  /// `PSK pre-shared key`
  String get pskKey {
    return Intl.message(
      'PSK pre-shared key',
      name: 'pskKey',
      desc: '',
      args: [],
    );
  }

  /// `Password`
  String get passwordAuth {
    return Intl.message('Password', name: 'passwordAuth', desc: '', args: []);
  }

  /// `Juicity password (fill UUID above)`
  String get juicityPassword {
    return Intl.message(
      'Juicity password (fill UUID above)',
      name: 'juicityPassword',
      desc: '',
      args: [],
    );
  }

  /// `Username (optional)`
  String get usernameOptional {
    return Intl.message(
      'Username (optional)',
      name: 'usernameOptional',
      desc: '',
      args: [],
    );
  }

  /// `Network`
  String get networkLabel {
    return Intl.message('Network', name: 'networkLabel', desc: '', args: []);
  }

  /// `Security/TLS`
  String get securityLabel {
    return Intl.message(
      'Security/TLS',
      name: 'securityLabel',
      desc: '',
      args: [],
    );
  }

  /// `None (plaintext)`
  String get securityNonePlain {
    return Intl.message(
      'None (plaintext)',
      name: 'securityNonePlain',
      desc: '',
      args: [],
    );
  }

  /// `Obfs mode`
  String get obfsModeLabel {
    return Intl.message('Obfs mode', name: 'obfsModeLabel', desc: '', args: []);
  }

  /// `None (off)`
  String get obfsNoneOff {
    return Intl.message('None (off)', name: 'obfsNoneOff', desc: '', args: []);
  }

  /// `Snell version (1-4)`
  String get snellVersion {
    return Intl.message(
      'Snell version (1-4)',
      name: 'snellVersion',
      desc: '',
      args: [],
    );
  }

  /// `REALITY public key`
  String get realityPublicKey {
    return Intl.message(
      'REALITY public key',
      name: 'realityPublicKey',
      desc: '',
      args: [],
    );
  }

  /// `SNI (ServerName / camouflage domain)`
  String get sniLabel {
    return Intl.message(
      'SNI (ServerName / camouflage domain)',
      name: 'sniLabel',
      desc: '',
      args: [],
    );
  }

  /// `Leave blank to default to the server address`
  String get sniHint {
    return Intl.message(
      'Leave blank to default to the server address',
      name: 'sniHint',
      desc: '',
      args: [],
    );
  }

  /// `Cipher`
  String get cipherLabel {
    return Intl.message('Cipher', name: 'cipherLabel', desc: '', args: []);
  }

  /// `Up`
  String get upLabel {
    return Intl.message('Up', name: 'upLabel', desc: '', args: []);
  }

  /// `Down`
  String get downLabel {
    return Intl.message('Down', name: 'downLabel', desc: '', args: []);
  }

  /// `Peer public key`
  String get peerPublicKey {
    return Intl.message(
      'Peer public key',
      name: 'peerPublicKey',
      desc: '',
      args: [],
    );
  }

  /// `Local IP`
  String get localIpLabel {
    return Intl.message('Local IP', name: 'localIpLabel', desc: '', args: []);
  }

  /// `AmneziaWG 2/3 obfuscation parameters (Jc / Jmin / Jmax / S1 / S2 / H1-H4)`
  String get amneziaObfsParams {
    return Intl.message(
      'AmneziaWG 2/3 obfuscation parameters (Jc / Jmin / Jmax / S1 / S2 / H1-H4)',
      name: 'amneziaObfsParams',
      desc: '',
      args: [],
    );
  }

  /// `Jc (junk packet count)`
  String get jcLabel {
    return Intl.message(
      'Jc (junk packet count)',
      name: 'jcLabel',
      desc: '',
      args: [],
    );
  }

  /// `Enable UDP forwarding`
  String get enableUdpForwarding {
    return Intl.message(
      'Enable UDP forwarding',
      name: 'enableUdpForwarding',
      desc: '',
      args: [],
    );
  }

  /// `Skip certificate verification`
  String get skipCertVerify {
    return Intl.message(
      'Skip certificate verification',
      name: 'skipCertVerify',
      desc: '',
      args: [],
    );
  }

  /// `Fixes self-signed certificate or TLS handshake errors`
  String get skipCertVerifyDesc {
    return Intl.message(
      'Fixes self-signed certificate or TLS handshake errors',
      name: 'skipCertVerifyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Please enter the server address`
  String get serverAddressRequired {
    return Intl.message(
      'Please enter the server address',
      name: 'serverAddressRequired',
      desc: '',
      args: [],
    );
  }

  /// `Node added: {name}`
  String nodeAdded(Object name) {
    return Intl.message(
      'Node added: $name',
      name: 'nodeAdded',
      desc: '',
      args: [name],
    );
  }

  /// `Save node`
  String get saveNode {
    return Intl.message('Save node', name: 'saveNode', desc: '', args: []);
  }

  /// `Network Detection URL`
  String get networkDetectionUrl {
    return Intl.message(
      'Network Detection URL',
      name: 'networkDetectionUrl',
      desc: '',
      args: [],
    );
  }

  /// `IP Risk Intel`
  String get ipRiskIntel {
    return Intl.message(
      'IP Risk Intel',
      name: 'ipRiskIntel',
      desc: '',
      args: [],
    );
  }

  /// `Sends your IP to a third party (no privacy policy)`
  String get ipRiskPrivacyNote {
    return Intl.message(
      'Sends your IP to a third party (no privacy policy)',
      name: 'ipRiskPrivacyNote',
      desc: '',
      args: [],
    );
  }

  /// `Enable lookup`
  String get ipRiskEnable {
    return Intl.message(
      'Enable lookup',
      name: 'ipRiskEnable',
      desc: '',
      args: [],
    );
  }

  /// `Not flagged`
  String get ipRiskNotFlagged {
    return Intl.message(
      'Not flagged',
      name: 'ipRiskNotFlagged',
      desc: '',
      args: [],
    );
  }

  /// `Stale — not real-time`
  String get ipRiskStale {
    return Intl.message(
      'Stale — not real-time',
      name: 'ipRiskStale',
      desc: '',
      args: [],
    );
  }

  /// `Native IP`
  String get ipRiskNativeType {
    return Intl.message(
      'Native IP',
      name: 'ipRiskNativeType',
      desc: '',
      args: [],
    );
  }

  /// `Unknown Limits`
  String get ipRiskUnknownNotes {
    return Intl.message(
      'Unknown Limits',
      name: 'ipRiskUnknownNotes',
      desc: '',
      args: [],
    );
  }

  /// `Customise Fields`
  String get ipRiskFieldsTitle {
    return Intl.message(
      'Customise Fields',
      name: 'ipRiskFieldsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Risk Markers`
  String get fieldMarkers {
    return Intl.message(
      'Risk Markers',
      name: 'fieldMarkers',
      desc: '',
      args: [],
    );
  }

  /// `Purity Score`
  String get fieldScore {
    return Intl.message('Purity Score', name: 'fieldScore', desc: '', args: []);
  }

  /// `Scenario Scores`
  String get fieldScenarios {
    return Intl.message(
      'Scenario Scores',
      name: 'fieldScenarios',
      desc: '',
      args: [],
    );
  }

  /// `Native IP`
  String get fieldNativeType {
    return Intl.message(
      'Native IP',
      name: 'fieldNativeType',
      desc: '',
      args: [],
    );
  }

  /// `Usage Type`
  String get fieldUsageType {
    return Intl.message(
      'Usage Type',
      name: 'fieldUsageType',
      desc: '',
      args: [],
    );
  }

  /// `ASN`
  String get fieldAsn {
    return Intl.message('ASN', name: 'fieldAsn', desc: '', args: []);
  }

  /// `Abuse Reports`
  String get fieldAbuse {
    return Intl.message(
      'Abuse Reports',
      name: 'fieldAbuse',
      desc: '',
      args: [],
    );
  }

  /// `Blocklists`
  String get fieldBlocklists {
    return Intl.message(
      'Blocklists',
      name: 'fieldBlocklists',
      desc: '',
      args: [],
    );
  }

  /// `Unknowns`
  String get fieldUnknownNotes {
    return Intl.message(
      'Unknowns',
      name: 'fieldUnknownNotes',
      desc: '',
      args: [],
    );
  }

  /// `VPN`
  String get ipRiskVpn {
    return Intl.message('VPN', name: 'ipRiskVpn', desc: '', args: []);
  }

  /// `Proxy`
  String get ipRiskProxy {
    return Intl.message('Proxy', name: 'ipRiskProxy', desc: '', args: []);
  }

  /// `Tor`
  String get ipRiskTor {
    return Intl.message('Tor', name: 'ipRiskTor', desc: '', args: []);
  }

  /// `Hosting/DC`
  String get ipRiskHosting {
    return Intl.message(
      'Hosting/DC',
      name: 'ipRiskHosting',
      desc: '',
      args: [],
    );
  }

  /// `Relay`
  String get ipRiskRelay {
    return Intl.message('Relay', name: 'ipRiskRelay', desc: '', args: []);
  }

  /// `Mobile`
  String get ipRiskMobile {
    return Intl.message('Mobile', name: 'ipRiskMobile', desc: '', args: []);
  }

  /// `Bogon`
  String get ipRiskBogon {
    return Intl.message('Bogon', name: 'ipRiskBogon', desc: '', args: []);
  }

  /// `Search bot`
  String get ipRiskSearchEngineBot {
    return Intl.message(
      'Search bot',
      name: 'ipRiskSearchEngineBot',
      desc: '',
      args: [],
    );
  }

  /// `Abuse reports`
  String get ipRiskAbuse {
    return Intl.message(
      'Abuse reports',
      name: 'ipRiskAbuse',
      desc: '',
      args: [],
    );
  }

  /// `Blocklists`
  String get ipRiskBlocklists {
    return Intl.message(
      'Blocklists',
      name: 'ipRiskBlocklists',
      desc: '',
      args: [],
    );
  }

  /// `What this data cannot tell`
  String get ipRiskLimits {
    return Intl.message(
      'What this data cannot tell',
      name: 'ipRiskLimits',
      desc: '',
      args: [],
    );
  }

  /// `Open full report`
  String get ipRiskOpenReport {
    return Intl.message(
      'Open full report',
      name: 'ipRiskOpenReport',
      desc: '',
      args: [],
    );
  }

  /// `Lookup failed`
  String get ipRiskFailed {
    return Intl.message(
      'Lookup failed',
      name: 'ipRiskFailed',
      desc: '',
      args: [],
    );
  }

  /// `Source Purity Score`
  String get ipRiskScore {
    return Intl.message(
      'Source Purity Score',
      name: 'ipRiskScore',
      desc: '',
      args: [],
    );
  }

  /// `Assessment`
  String get ipRiskVerdict {
    return Intl.message(
      'Assessment',
      name: 'ipRiskVerdict',
      desc: '',
      args: [],
    );
  }

  /// `Score Factors`
  String get ipRiskFactors {
    return Intl.message(
      'Score Factors',
      name: 'ipRiskFactors',
      desc: '',
      args: [],
    );
  }

  /// `Scenario Scores`
  String get ipRiskScenarios {
    return Intl.message(
      'Scenario Scores',
      name: 'ipRiskScenarios',
      desc: '',
      args: [],
    );
  }

  /// `AI Services`
  String get scenarioAi {
    return Intl.message('AI Services', name: 'scenarioAi', desc: '', args: []);
  }

  /// `Social Sign-up`
  String get scenarioSocial {
    return Intl.message(
      'Social Sign-up',
      name: 'scenarioSocial',
      desc: '',
      args: [],
    );
  }

  /// `Streaming`
  String get scenarioStreaming {
    return Intl.message(
      'Streaming',
      name: 'scenarioStreaming',
      desc: '',
      args: [],
    );
  }

  /// `Gaming`
  String get scenarioGaming {
    return Intl.message('Gaming', name: 'scenarioGaming', desc: '', args: []);
  }

  /// `E-commerce`
  String get scenarioEcommerce {
    return Intl.message(
      'E-commerce',
      name: 'scenarioEcommerce',
      desc: '',
      args: [],
    );
  }

  /// `Email`
  String get scenarioEmail {
    return Intl.message('Email', name: 'scenarioEmail', desc: '', args: []);
  }

  /// `Intelligence Analytics`
  String get chainIntelAnalytics {
    return Intl.message(
      'Intelligence Analytics',
      name: 'chainIntelAnalytics',
      desc: '',
      args: [],
    );
  }

  /// `Avg Latency`
  String get chainAvgLatency {
    return Intl.message(
      'Avg Latency',
      name: 'chainAvgLatency',
      desc: '',
      args: [],
    );
  }

  /// `Top Failure Reason`
  String get chainTopFailureReason {
    return Intl.message(
      'Top Failure Reason',
      name: 'chainTopFailureReason',
      desc: '',
      args: [],
    );
  }

  /// `Node Reliability`
  String get chainNodeReliability {
    return Intl.message(
      'Node Reliability',
      name: 'chainNodeReliability',
      desc: '',
      args: [],
    );
  }

  /// `Health Score`
  String get chainHealthScore {
    return Intl.message(
      'Health Score',
      name: 'chainHealthScore',
      desc: '',
      args: [],
    );
  }

  /// `Decision Support`
  String get chainDecisionSupport {
    return Intl.message(
      'Decision Support',
      name: 'chainDecisionSupport',
      desc: '',
      args: [],
    );
  }

  /// `Chain Diagnostic`
  String get chainDiagnosticTitle {
    return Intl.message(
      'Chain Diagnostic',
      name: 'chainDiagnosticTitle',
      desc: '',
      args: [],
    );
  }

  /// `Health`
  String get chainHealthLabel {
    return Intl.message('Health', name: 'chainHealthLabel', desc: '', args: []);
  }

  /// `Events`
  String get chainEventsLabel {
    return Intl.message('Events', name: 'chainEventsLabel', desc: '', args: []);
  }

  /// `Failures`
  String get chainFailuresLabel {
    return Intl.message(
      'Failures',
      name: 'chainFailuresLabel',
      desc: '',
      args: [],
    );
  }

  /// `Export Report`
  String get chainExportReport {
    return Intl.message(
      'Export Report',
      name: 'chainExportReport',
      desc: '',
      args: [],
    );
  }

  /// `Exporting...`
  String get chainExporting {
    return Intl.message(
      'Exporting...',
      name: 'chainExporting',
      desc: '',
      args: [],
    );
  }

  /// `Chain Support`
  String get chainSupportTitle {
    return Intl.message(
      'Chain Support',
      name: 'chainSupportTitle',
      desc: '',
      args: [],
    );
  }

  /// `Package Ready`
  String get chainPackageReady {
    return Intl.message(
      'Package Ready',
      name: 'chainPackageReady',
      desc: '',
      args: [],
    );
  }

  /// `Generated on`
  String get chainGeneratedOn {
    return Intl.message(
      'Generated on',
      name: 'chainGeneratedOn',
      desc: '',
      args: [],
    );
  }

  /// `Open Folder`
  String get chainOpenFolder {
    return Intl.message(
      'Open Folder',
      name: 'chainOpenFolder',
      desc: '',
      args: [],
    );
  }

  /// `Share`
  String get chainShareLabel {
    return Intl.message('Share', name: 'chainShareLabel', desc: '', args: []);
  }

  /// `Diagnostic Package`
  String get chainDiagnosticPackage {
    return Intl.message(
      'Diagnostic Package',
      name: 'chainDiagnosticPackage',
      desc: '',
      args: [],
    );
  }

  /// `Create Support Package`
  String get chainCreateSupportPackage {
    return Intl.message(
      'Create Support Package',
      name: 'chainCreateSupportPackage',
      desc: '',
      args: [],
    );
  }

  /// `Creating...`
  String get chainCreatingPackage {
    return Intl.message(
      'Creating...',
      name: 'chainCreatingPackage',
      desc: '',
      args: [],
    );
  }

  /// `Network Type`
  String get networkType {
    return Intl.message(
      'Network Type',
      name: 'networkType',
      desc: '',
      args: [],
    );
  }

  /// `Intranet & Gateway`
  String get intranetAndGateway {
    return Intl.message(
      'Intranet & Gateway',
      name: 'intranetAndGateway',
      desc: '',
      args: [],
    );
  }

  /// `Interface`
  String get networkInterface {
    return Intl.message(
      'Interface',
      name: 'networkInterface',
      desc: '',
      args: [],
    );
  }

  /// `Default Gateway`
  String get defaultGateway {
    return Intl.message(
      'Default Gateway',
      name: 'defaultGateway',
      desc: '',
      args: [],
    );
  }

  /// `System DNS`
  String get systemDns {
    return Intl.message('System DNS', name: 'systemDns', desc: '', args: []);
  }

  /// `Open Gateway`
  String get openGateway {
    return Intl.message(
      'Open Gateway',
      name: 'openGateway',
      desc: '',
      args: [],
    );
  }

  /// `LAN Share Address`
  String get lanShareAddress {
    return Intl.message(
      'LAN Share Address',
      name: 'lanShareAddress',
      desc: '',
      args: [],
    );
  }

  /// `Prevent DNS leak`
  String get preventDnsLeak {
    return Intl.message(
      'Prevent DNS leak',
      name: 'preventDnsLeak',
      desc: '',
      args: [],
    );
  }

  /// `Keeps DNS inside the tunnel and replaces router or ISP resolvers with public DoH, so the local network never sees your domains.`
  String get preventDnsLeakDesc {
    return Intl.message(
      'Keeps DNS inside the tunnel and replaces router or ISP resolvers with public DoH, so the local network never sees your domains.',
      name: 'preventDnsLeakDesc',
      desc: '',
      args: [],
    );
  }

  /// `0 (default 2408)`
  String get warpStr0 {
    return Intl.message(
      '0 (default 2408)',
      name: 'warpStr0',
      desc: '0 (默认 2408)',
      args: [],
    );
  }

  /// `1280 (recommended, best for UDP)`
  String get warpStr1 {
    return Intl.message(
      '1280 (recommended, best for UDP)',
      name: 'warpStr1',
      desc: '1280 (推荐，UDP代理最优)',
      args: [],
    );
  }

  /// `1360 (balanced)`
  String get warpStr2 {
    return Intl.message(
      '1360 (balanced)',
      name: 'warpStr2',
      desc: '1360 (适中)',
      args: [],
    );
  }

  /// `1420 (standard)`
  String get warpStr3 {
    return Intl.message(
      '1420 (standard)',
      name: 'warpStr3',
      desc: '1420 (标准)',
      args: [],
    );
  }

  /// `AI and streaming unlock`
  String get warpStr4 {
    return Intl.message(
      'AI and streaming unlock',
      name: 'warpStr4',
      desc: 'AI 与流媒体解锁',
      args: [],
    );
  }

  /// `Cloudflare peer public key`
  String get warpStr5 {
    return Intl.message(
      'Cloudflare peer public key',
      name: 'warpStr5',
      desc: 'Cloudflare 对端公钥',
      args: [],
    );
  }

  /// `DIRECT (connect to Cloudflare directly)`
  String get warpStr6 {
    return Intl.message(
      'DIRECT (connect to Cloudflare directly)',
      name: 'warpStr6',
      desc: 'DIRECT (直连 Cloudflare)',
      args: [],
    );
  }

  /// `Google region-leak check`
  String get warpStr7 {
    return Intl.message(
      'Google region-leak check',
      name: 'warpStr7',
      desc: 'Google 防送中评定',
      args: [],
    );
  }

  /// `MTU set to 1280 (recommended)`
  String get warpStr8 {
    return Intl.message(
      'MTU set to 1280 (recommended)',
      name: 'warpStr8',
      desc: 'MTU 已设为 1280 (推荐)',
      args: [],
    );
  }

  /// `MTU set to 1360`
  String get warpStr9 {
    return Intl.message(
      'MTU set to 1360',
      name: 'warpStr9',
      desc: 'MTU 已设为 1360',
      args: [],
    );
  }

  /// `MTU set to 1420 (standard)`
  String get warpStr10 {
    return Intl.message(
      'MTU set to 1420 (standard)',
      name: 'warpStr10',
      desc: 'MTU 已设为 1420 (标准)',
      args: [],
    );
  }

  /// `WARP credentials and details`
  String get warpStr11 {
    return Intl.message(
      'WARP credentials and details',
      name: 'warpStr11',
      desc: 'WARP 凭据与高级详情',
      args: [],
    );
  }

  /// `WARP reset to its default configuration`
  String get warpStr12 {
    return Intl.message(
      'WARP reset to its default configuration',
      name: 'warpStr12',
      desc: 'WARP 已重置为初始默认配置',
      args: [],
    );
  }

  /// `WARP routing mode`
  String get warpStr13 {
    return Intl.message(
      'WARP routing mode',
      name: 'warpStr13',
      desc: 'WARP 路由模式',
      args: [],
    );
  }

  /// `WARP+ activation (warp=plus)`
  String get warpStr14 {
    return Intl.message(
      'WARP+ activation (warp=plus)',
      name: 'warpStr14',
      desc: 'WARP+ 极速加速激活 (warp=plus)',
      args: [],
    );
  }

  /// `WireGuard keys`
  String get warpStr15 {
    return Intl.message(
      'WireGuard keys',
      name: 'warpStr15',
      desc: 'WireGuard 密钥信息',
      args: [],
    );
  }

  /// `auto (default)`
  String get warpStr16 {
    return Intl.message(
      'auto (default)',
      name: 'warpStr16',
      desc: 'auto (默认)',
      args: [],
    );
  }

  /// `auto, or e.g. 162.159.193.1`
  String get warpStr17 {
    return Intl.message(
      'auto, or e.g. 162.159.193.1',
      name: 'warpStr17',
      desc: 'auto 或例如 162.159.193.1',
      args: [],
    );
  }

  /// `⚠️ Region may be exposed`
  String get warpStr18 {
    return Intl.message(
      '⚠️ Region may be exposed',
      name: 'warpStr18',
      desc: '⚠️ 可能送中',
      args: [],
    );
  }

  /// `⚡ Check WARP status`
  String get warpStr19 {
    return Intl.message(
      '⚡ Check WARP status',
      name: 'warpStr19',
      desc: '⚡ 一键检测 WARP 真实状态',
      args: [],
    );
  }

  /// `⚡ Follow main selector (recommended)`
  String get warpStr20 {
    return Intl.message(
      '⚡ Follow main selector (recommended)',
      name: 'warpStr20',
      desc: '⚡ 跟随后台主选择 (推荐)',
      args: [],
    );
  }

  /// `⚡ Follow main selector (uses the active provider node)`
  String get warpStr21 {
    return Intl.message(
      '⚡ Follow main selector (uses the active provider node)',
      name: 'warpStr21',
      desc: '⚡ 跟随后台主选择 (自动匹配当前机场节点)',
      args: [],
    );
  }

  /// `⚪ Local key pair`
  String get warpStr22 {
    return Intl.message(
      '⚪ Local key pair',
      name: 'warpStr22',
      desc: '⚪ 本地密钥对',
      args: [],
    );
  }

  /// `✈️ WARP dialer`
  String get warpStr23 {
    return Intl.message(
      '✈️ WARP dialer',
      name: 'warpStr23',
      desc: '✈️ WARP跳板',
      args: [],
    );
  }

  /// `Optimize`
  String get warpStr24 {
    return Intl.message('Optimize', name: 'warpStr24', desc: '一键优选', args: []);
  }

  /// `Generate an X25519 key pair and register with Cloudflare`
  String get warpStr25 {
    return Intl.message(
      'Generate an X25519 key pair and register with Cloudflare',
      name: 'warpStr25',
      desc: '一键生成 X25519 密钥对并向 Cloudflare 注册设备',
      args: [],
    );
  }

  /// `Run diagnostics`
  String get warpStr26 {
    return Intl.message(
      'Run diagnostics',
      name: 'warpStr26',
      desc: '一键诊断检测',
      args: [],
    );
  }

  /// `Same view as the switch card, with live latency`
  String get warpStr27 {
    return Intl.message(
      'Same view as the switch card, with live latency',
      name: 'warpStr27',
      desc: '与切换卡片相同的界面，可看到实时延迟',
      args: [],
    );
  }

  /// `Choose from node list…`
  String get warpStr28 {
    return Intl.message(
      'Choose from node list…',
      name: 'warpStr28',
      desc: '从节点列表选择…',
      args: [],
    );
  }

  /// `Preferred IP`
  String get warpStr29 {
    return Intl.message(
      'Preferred IP',
      name: 'warpStr29',
      desc: '优选 IP',
      args: [],
    );
  }

  /// `Preferred IP / hostname`
  String get warpStr30 {
    return Intl.message(
      'Preferred IP / hostname',
      name: 'warpStr30',
      desc: '优选 IP / 域名',
      args: [],
    );
  }

  /// `Preferred IP saved`
  String get warpStr31 {
    return Intl.message(
      'Preferred IP saved',
      name: 'warpStr31',
      desc: '优选 IP 已保存',
      args: [],
    );
  }

  /// `Preferred IP reset to auto`
  String get warpStr32 {
    return Intl.message(
      'Preferred IP reset to auto',
      name: 'warpStr32',
      desc: '优选 IP 已重置为 auto',
      args: [],
    );
  }

  /// `Preferred IP scan`
  String get warpStr33 {
    return Intl.message(
      'Preferred IP scan',
      name: 'warpStr33',
      desc: '优选 IP 扫描',
      args: [],
    );
  }

  /// `The preferred IP is the entry address; it affects speed and stability.`
  String get warpStr34 {
    return Intl.message(
      'The preferred IP is the entry address; it affects speed and stability.',
      name: 'warpStr34',
      desc: '优选 IP 改变的是「入口地址」，影响速度与稳定性；',
      args: [],
    );
  }

  /// `How it works`
  String get warpStr35 {
    return Intl.message(
      'How it works',
      name: 'warpStr35',
      desc: '使用指南与原理解释',
      args: [],
    );
  }

  /// `Use the fastest`
  String get warpStr36 {
    return Intl.message(
      'Use the fastest',
      name: 'warpStr36',
      desc: '使用最快',
      args: [],
    );
  }

  /// `Save`
  String get warpStr37 {
    return Intl.message('Save', name: 'warpStr37', desc: '保存', args: []);
  }

  /// `Close`
  String get warpStr38 {
    return Intl.message('Close', name: 'warpStr38', desc: '关闭', args: []);
  }

  /// `The exit IP is chosen by Cloudflare's nearest routing and does not change.`
  String get warpStr39 {
    return Intl.message(
      'The exit IP is chosen by Cloudflare\'s nearest routing and does not change.',
      name: 'warpStr39',
      desc: '出口 IP 由 Cloudflare 就近调度决定，不会因此变化。',
      args: [],
    );
  }

  /// `Real exit IP`
  String get warpStr40 {
    return Intl.message(
      'Real exit IP',
      name: 'warpStr40',
      desc: '出口真实 IP',
      args: [],
    );
  }

  /// `Dialer proxy`
  String get warpStr41 {
    return Intl.message(
      'Dialer proxy',
      name: 'warpStr41',
      desc: '前置跳板代理 (Dialer-Proxy)',
      args: [],
    );
  }

  /// `Cancel`
  String get warpStr42 {
    return Intl.message('Cancel', name: 'warpStr42', desc: '取消', args: []);
  }

  /// `Enable WARP`
  String get warpStr43 {
    return Intl.message(
      'Enable WARP',
      name: 'warpStr43',
      desc: '启用 WARP',
      args: [],
    );
  }

  /// `Client public key`
  String get warpStr44 {
    return Intl.message(
      'Client public key',
      name: 'warpStr44',
      desc: '客户端公钥 (PublicKey)',
      args: [],
    );
  }

  /// `Client private key`
  String get warpStr45 {
    return Intl.message(
      'Client private key',
      name: 'warpStr45',
      desc: '客户端私钥 (PrivateKey)',
      args: [],
    );
  }

  /// `Client reserved bytes`
  String get warpStr46 {
    return Intl.message(
      'Client reserved bytes',
      name: 'warpStr46',
      desc: '客户端预留字段 (Reserved)',
      args: [],
    );
  }

  /// `No rules yet - with no rules nothing is routed in this mode`
  String get warpStr47 {
    return Intl.message(
      'No rules yet - with no rules nothing is routed in this mode',
      name: 'warpStr47',
      desc: '尚未添加规则 —— 此模式下规则为空则不分流',
      args: [],
    );
  }

  /// `Not verified yet`
  String get warpStr48 {
    return Intl.message(
      'Not verified yet',
      name: 'warpStr48',
      desc: '尚未进行真实有效性检测',
      args: [],
    );
  }

  /// `Key saved; it applies on the next handshake or registration`
  String get warpStr49 {
    return Intl.message(
      'Key saved; it applies on the next handshake or registration',
      name: 'warpStr49',
      desc: '已保存密钥，将在下次握手或注册时生效',
      args: [],
    );
  }

  /// `WARP disabled`
  String get warpStr50 {
    return Intl.message(
      'WARP disabled',
      name: 'warpStr50',
      desc: '已关闭 WARP',
      args: [],
    );
  }

  /// `Cloudflare WARP enabled`
  String get warpStr51 {
    return Intl.message(
      'Cloudflare WARP enabled',
      name: 'warpStr51',
      desc: '已启用 Cloudflare WARP',
      args: [],
    );
  }

  /// `WARP enabled`
  String get warpStr52 {
    return Intl.message(
      'WARP enabled',
      name: 'warpStr52',
      desc: '已开启 WARP',
      args: [],
    );
  }

  /// `License key cleared`
  String get warpStr53 {
    return Intl.message(
      'License key cleared',
      name: 'warpStr53',
      desc: '已清除许可证密钥',
      args: [],
    );
  }

  /// `Set to follow the main selector`
  String get warpStr54 {
    return Intl.message(
      'Set to follow the main selector',
      name: 'warpStr54',
      desc: '已设为跟随后台主选择',
      args: [],
    );
  }

  /// `Curve25519 key pair regenerated`
  String get warpStr55 {
    return Intl.message(
      'Curve25519 key pair regenerated',
      name: 'warpStr55',
      desc: '已重新生成 Curve25519 密钥对',
      args: [],
    );
  }

  /// `Reset to the default: route WARP through the proxy`
  String get warpStr56 {
    return Intl.message(
      'Reset to the default: route WARP through the proxy',
      name: 'warpStr56',
      desc: '已重置为默认「通过代理路由 WARP」',
      args: [],
    );
  }

  /// `Mode: route the proxy through WARP. Every provider node is chained through the WARP tunnel, which rescues nodes blocked by the GFW. No dialer needs to be chosen.`
  String get warpStr57 {
    return Intl.message(
      'Mode: route the proxy through WARP. Every provider node is chained through the WARP tunnel, which rescues nodes blocked by the GFW. No dialer needs to be chosen.',
      name: 'warpStr57',
      desc: '当前为「通过 WARP 路由代理」模式：所有机场代理节点均自动级联经由 WARP 隧道出境连接，能有效拯救被 GFW 阻断的节点，无需额外选择前置跳板。',
      args: [],
    );
  }

  /// `Not checked`
  String get warpStr58 {
    return Intl.message(
      'Not checked',
      name: 'warpStr58',
      desc: '待检测',
      args: [],
    );
  }

  /// `For the cleanest result, turn the proxy off before scanning.`
  String get warpStr59 {
    return Intl.message(
      'For the cleanest result, turn the proxy off before scanning.',
      name: 'warpStr59',
      desc: '想拿到最干净的数值，可先关闭代理再扫描。',
      args: [],
    );
  }

  /// `Note: latency measured with the proxy on includes tunnel overhead.`
  String get warpStr60 {
    return Intl.message(
      'Note: latency measured with the proxy on includes tunnel overhead.',
      name: 'warpStr60',
      desc: '提示：开启代理时测得的延迟包含隧道开销。',
      args: [],
    );
  }

  /// `Not enabled`
  String get warpStr61 {
    return Intl.message(
      'Not enabled',
      name: 'warpStr61',
      desc: '未启用',
      args: [],
    );
  }

  /// `Not set`
  String get warpStr62 {
    return Intl.message('Not set', name: 'warpStr62', desc: '未设置', args: []);
  }

  /// `Provider nodes`
  String get warpStr63 {
    return Intl.message(
      'Provider nodes',
      name: 'warpStr63',
      desc: '机场代理节点',
      args: [],
    );
  }

  /// `Show full WireGuard keys`
  String get warpStr64 {
    return Intl.message(
      'Show full WireGuard keys',
      name: 'warpStr64',
      desc: '查看完整 WireGuard 密钥',
      args: [],
    );
  }

  /// `Checking…`
  String get warpStr65 {
    return Intl.message(
      'Checking…',
      name: 'warpStr65',
      desc: '检测中...',
      args: [],
    );
  }

  /// `Registering the device with Cloudflare and generating keys…`
  String get warpStr66 {
    return Intl.message(
      'Registering the device with Cloudflare and generating keys…',
      name: 'warpStr66',
      desc: '正在向 Cloudflare 官方注册设备并生成密钥...',
      args: [],
    );
  }

  /// `Running diagnostics…`
  String get warpStr67 {
    return Intl.message(
      'Running diagnostics…',
      name: 'warpStr67',
      desc: '正在深度诊断...',
      args: [],
    );
  }

  /// `Generating an X25519 key and registering the device…`
  String get warpStr68 {
    return Intl.message(
      'Generating an X25519 key and registering the device…',
      name: 'warpStr68',
      desc: '正在生成 X25519 密钥并向 Cloudflare 注册设备...',
      args: [],
    );
  }

  /// `Binding the key through the official API…`
  String get warpStr69 {
    return Intl.message(
      'Binding the key through the official API…',
      name: 'warpStr69',
      desc: '正在通过官方接口绑定密钥...',
      args: [],
    );
  }

  /// `No reachable nodes. Check the network, or turn the proxy off and retry.`
  String get warpStr70 {
    return Intl.message(
      'No reachable nodes. Check the network, or turn the proxy off and retry.',
      name: 'warpStr70',
      desc: '没有探测到可用节点。请检查网络，或关闭代理后重试。',
      args: [],
    );
  }

  /// `Traffic goes through WARP first, then to the provider node - useful when a node is blocked`
  String get warpStr71 {
    return Intl.message(
      'Traffic goes through WARP first, then to the provider node - useful when a node is blocked',
      name: 'warpStr71',
      desc: '流量先经过 WARP 再连接代理节点，用于节点被阻断时救砖',
      args: [],
    );
  }

  /// `Traffic goes through the provider node, then out via WARP - avoids region leaks and unlocks AI`
  String get warpStr72 {
    return Intl.message(
      'Traffic goes through the provider node, then out via WARP - avoids region leaks and unlocks AI',
      name: 'warpStr72',
      desc: '流量经代理节点后再连 WARP 出口，用于防送中与解锁 AI',
      args: [],
    );
  }

  /// `Activate and bind`
  String get warpStr73 {
    return Intl.message(
      'Activate and bind',
      name: 'warpStr73',
      desc: '激活绑定',
      args: [],
    );
  }

  /// `Tap to enable WARP`
  String get warpStr74 {
    return Intl.message(
      'Tap to enable WARP',
      name: 'warpStr74',
      desc: '点击开启 WARP 功能',
      args: [],
    );
  }

  /// `Generate WARP configuration`
  String get warpStr75 {
    return Intl.message(
      'Generate WARP configuration',
      name: 'warpStr75',
      desc: '生成 WARP 配置',
      args: [],
    );
  }

  /// `Generated (a built-in valid key pair was loaded)`
  String get warpStr76 {
    return Intl.message(
      'Generated (a built-in valid key pair was loaded)',
      name: 'warpStr76',
      desc: '生成完成（已载入内置合法密钥对）',
      args: [],
    );
  }

  /// `Direct or normal proxy (warp=off)`
  String get warpStr77 {
    return Intl.message(
      'Direct or normal proxy (warp=off)',
      name: 'warpStr77',
      desc: '直连或普通代理 (warp=off)',
      args: [],
    );
  }

  /// `OK`
  String get warpStr78 {
    return Intl.message('OK', name: 'warpStr78', desc: '确定', args: []);
  }

  /// `Port`
  String get warpStr79 {
    return Intl.message('Port', name: 'warpStr79', desc: '端口', args: []);
  }

  /// `Port`
  String get warpStr80 {
    return Intl.message('Port', name: 'warpStr80', desc: '端口 (Port)', args: []);
  }

  /// `Port number`
  String get warpStr81 {
    return Intl.message(
      'Port number',
      name: 'warpStr81',
      desc: '端口号',
      args: [],
    );
  }

  /// `Port updated`
  String get warpStr82 {
    return Intl.message(
      'Port updated',
      name: 'warpStr82',
      desc: '端口已更新',
      args: [],
    );
  }

  /// `Port reset to 0 (default 2408)`
  String get warpStr83 {
    return Intl.message(
      'Port reset to 0 (default 2408)',
      name: 'warpStr83',
      desc: '端口已重置为 0 (默认 2408)',
      args: [],
    );
  }

  /// `Policy groups`
  String get warpStr84 {
    return Intl.message(
      'Policy groups',
      name: 'warpStr84',
      desc: '策略组',
      args: [],
    );
  }

  /// `Bind a WARP+ license key`
  String get warpStr85 {
    return Intl.message(
      'Bind a WARP+ license key',
      name: 'warpStr85',
      desc: '绑定 WARP+ 许可证密钥',
      args: [],
    );
  }

  /// `Uses the provider node currently selected in the panel`
  String get warpStr86 {
    return Intl.message(
      'Uses the provider node currently selected in the panel',
      name: 'warpStr86',
      desc: '自动匹配您在控制面板中选中的当前机场节点',
      args: [],
    );
  }

  /// `Custom rules`
  String get warpStr87 {
    return Intl.message(
      'Custom rules',
      name: 'warpStr87',
      desc: '自定义规则',
      args: [],
    );
  }

  /// `Virtual IPv4`
  String get warpStr88 {
    return Intl.message(
      'Virtual IPv4',
      name: 'warpStr88',
      desc: '虚拟 IPv4',
      args: [],
    );
  }

  /// `Virtual IPv6`
  String get warpStr89 {
    return Intl.message(
      'Virtual IPv6',
      name: 'warpStr89',
      desc: '虚拟 IPv6',
      args: [],
    );
  }

  /// `Avoids captchas and region locks`
  String get warpStr90 {
    return Intl.message(
      'Avoids captchas and region locks',
      name: 'warpStr90',
      desc: '规避验证码/区域锁定',
      args: [],
    );
  }

  /// `Unbind`
  String get warpStr91 {
    return Intl.message('Unbind', name: 'warpStr91', desc: '解绑', args: []);
  }

  /// `License key`
  String get warpStr92 {
    return Intl.message(
      'License key',
      name: 'warpStr92',
      desc: '许可证密钥',
      args: [],
    );
  }

  /// `Set the WireGuard port (0 means the default 2408):`
  String get warpStr93 {
    return Intl.message(
      'Set the WireGuard port (0 means the default 2408):',
      name: 'warpStr93',
      desc: '设置 WireGuard 端口（0 为默认 2408 端口）：',
      args: [],
    );
  }

  /// `Set the preferred IP for Cloudflare WARP; enter auto to use the official best IP:`
  String get warpStr94 {
    return Intl.message(
      'Set the preferred IP for Cloudflare WARP; enter auto to use the official best IP:',
      name: 'warpStr94',
      desc: '设置连接 Cloudflare WARP 的优选 IP，输入 auto 则自动使用官方最优 IP：',
      args: [],
    );
  }

  /// `Follow dialer`
  String get warpStr95 {
    return Intl.message(
      'Follow dialer',
      name: 'warpStr95',
      desc: '跟随跳板',
      args: [],
    );
  }

  /// `Edge colo`
  String get warpStr96 {
    return Intl.message(
      'Edge colo',
      name: 'warpStr96',
      desc: '边缘机房 (Colo)',
      args: [],
    );
  }

  /// `Connection incomplete or check timed out`
  String get warpStr97 {
    return Intl.message(
      'Connection incomplete or check timed out',
      name: 'warpStr97',
      desc: '连接未完成或检测超时',
      args: [],
    );
  }

  /// `Choose the WARP dialer`
  String get warpStr98 {
    return Intl.message(
      'Choose the WARP dialer',
      name: 'warpStr98',
      desc: '选择 WARP 前置跳板',
      args: [],
    );
  }

  /// `Choose the WireGuard MTU`
  String get warpStr99 {
    return Intl.message(
      'Choose the WireGuard MTU',
      name: 'warpStr99',
      desc: '选择 WireGuard MTU',
      args: [],
    );
  }

  /// `Route the proxy through WARP`
  String get warpStr100 {
    return Intl.message(
      'Route the proxy through WARP',
      name: 'warpStr100',
      desc: '通过 WARP 路由代理',
      args: [],
    );
  }

  /// `Route WARP through the proxy`
  String get warpStr101 {
    return Intl.message(
      'Route WARP through the proxy',
      name: 'warpStr101',
      desc: '通过代理路由 WARP',
      args: [],
    );
  }

  /// `Regenerate keys`
  String get warpStr102 {
    return Intl.message(
      'Regenerate keys',
      name: 'warpStr102',
      desc: '重新生成密钥',
      args: [],
    );
  }

  /// `Reset`
  String get warpStr103 {
    return Intl.message('Reset', name: 'warpStr103', desc: '重置', args: []);
  }

  /// `Reset to defaults`
  String get warpStr104 {
    return Intl.message(
      'Reset to defaults',
      name: 'warpStr104',
      desc: '重置为默认配置',
      args: [],
    );
  }

  /// `🎉 WARP+ license activated`
  String get warpStr105 {
    return Intl.message(
      '🎉 WARP+ license activated',
      name: 'warpStr105',
      desc: '🎉 WARP+ 许可证激活成功！',
      args: [],
    );
  }

  /// `🎉 Device and keys generated`
  String get warpStr106 {
    return Intl.message(
      '🎉 Device and keys generated',
      name: 'warpStr106',
      desc: '🎉 官方设备与密钥生成成功！',
      args: [],
    );
  }

  /// `👑 WARP+ device`
  String get warpStr107 {
    return Intl.message(
      '👑 WARP+ device',
      name: 'warpStr107',
      desc: '👑 WARP+ 极速会员设备',
      args: [],
    );
  }

  /// `💡 When to use each mode`
  String get warpStr108 {
    return Intl.message(
      '💡 When to use each mode',
      name: 'warpStr108',
      desc: '💡 使用场景与路由模式原理',
      args: [],
    );
  }

  /// `🛡️ Native search (excellent)`
  String get warpStr109 {
    return Intl.message(
      '🛡️ Native search (excellent)',
      name: 'warpStr109',
      desc: '🛡️ 原生搜索 (极佳)',
      args: [],
    );
  }

  /// `🟢 Official free device`
  String get warpStr110 {
    return Intl.message(
      '🟢 Official free device',
      name: 'warpStr110',
      desc: '🟢 官方免费设备',
      args: [],
    );
  }

  /// `🟢 Unrestricted`
  String get warpStr111 {
    return Intl.message(
      '🟢 Unrestricted',
      name: 'warpStr111',
      desc: '🟢 畅通无阻',
      args: [],
    );
  }

  /// `Switched to {label}`
  String warpSwitchedTo(String label) {
    return Intl.message(
      'Switched to $label',
      name: 'warpSwitchedTo',
      desc: '',
      args: [label],
    );
  }

  /// `Copied {label}`
  String warpCopied(String label) {
    return Intl.message(
      'Copied $label',
      name: 'warpCopied',
      desc: '',
      args: [label],
    );
  }

  /// `Using {ip}`
  String warpIpChosen(String ip) {
    return Intl.message(
      'Using $ip',
      name: 'warpIpChosen',
      desc: '',
      args: [ip],
    );
  }

  /// `Using the fastest node: {ip}`
  String warpFastestChosen(String ip) {
    return Intl.message(
      'Using the fastest node: $ip',
      name: 'warpFastestChosen',
      desc: '',
      args: [ip],
    );
  }

  /// `Region: {loc}`
  String warpRegion(String loc) {
    return Intl.message(
      'Region: $loc',
      name: 'warpRegion',
      desc: '',
      args: [loc],
    );
  }

  /// `🎉 Diagnostics passed. WARP is active (colo: {colo}, exit: {ip})`
  String warpDiagOk(String colo, String ip) {
    return Intl.message(
      '🎉 Diagnostics passed. WARP is active (colo: $colo, exit: $ip)',
      name: 'warpDiagOk',
      desc: '',
      args: [colo, ip],
    );
  }

  /// `Note: connected to exit {ip} but no WARP signature was found - check the dialer`
  String warpNoSignature(String ip) {
    return Intl.message(
      'Note: connected to exit $ip but no WARP signature was found - check the dialer',
      name: 'warpNoSignature',
      desc: '',
      args: [ip],
    );
  }

  /// `Dialer set to {name}`
  String warpDialerSet(String name) {
    return Intl.message(
      'Dialer set to $name',
      name: 'warpDialerSet',
      desc: '',
      args: [name],
    );
  }

  /// `Manage / add nodes`
  String get profileManageNodes {
    return Intl.message(
      'Manage / add nodes',
      name: 'profileManageNodes',
      desc: '',
      args: [],
    );
  }

  /// `Pre and landing proxies`
  String get profileChainProxies {
    return Intl.message(
      'Pre and landing proxies',
      name: 'profileChainProxies',
      desc: '',
      args: [],
    );
  }

  /// `Routing mode`
  String get warpModeTitle {
    return Intl.message(
      'Routing mode',
      name: 'warpModeTitle',
      desc: '',
      args: [],
    );
  }

  /// `Smart: AI unlock (recommended)`
  String get warpModeSmart {
    return Intl.message(
      'Smart: AI unlock (recommended)',
      name: 'warpModeSmart',
      desc: '',
      args: [],
    );
  }

  /// `Routes Google, OpenAI, Claude and Gemini through WARP; everything else keeps the provider's native speed`
  String get warpModeSmartDesc {
    return Intl.message(
      'Routes Google, OpenAI, Claude and Gemini through WARP; everything else keeps the provider\'s native speed',
      name: 'warpModeSmartDesc',
      desc: '',
      args: [],
    );
  }

  /// `Route everything through WARP`
  String get warpModeAll {
    return Intl.message(
      'Route everything through WARP',
      name: 'warpModeAll',
      desc: '',
      args: [],
    );
  }

  /// `All proxy traffic is encapsulated through WARP, hiding the provider's real exit IP`
  String get warpModeAllDesc {
    return Intl.message(
      'All proxy traffic is encapsulated through WARP, hiding the provider\'s real exit IP',
      name: 'warpModeAllDesc',
      desc: '',
      args: [],
    );
  }

  /// `Custom rule-based routing`
  String get warpModeCustom {
    return Intl.message(
      'Custom rule-based routing',
      name: 'warpModeCustom',
      desc: '',
      args: [],
    );
  }

  /// `Decides per rule whether traffic goes out through WARP`
  String get warpModeCustomDesc {
    return Intl.message(
      'Decides per rule whether traffic goes out through WARP',
      name: 'warpModeCustomDesc',
      desc: '',
      args: [],
    );
  }

  /// `Join the aggregate group`
  String get aggregateJoin {
    return Intl.message(
      'Join the aggregate group',
      name: 'aggregateJoin',
      desc: '',
      args: [],
    );
  }

  /// `Merges this profile's nodes into the aggregate group`
  String get aggregateJoinDesc {
    return Intl.message(
      'Merges this profile\'s nodes into the aggregate group',
      name: 'aggregateJoinDesc',
      desc: '',
      args: [],
    );
  }

  /// `Aggregate prefix (empty uses the profile name)`
  String get aggregatePrefix {
    return Intl.message(
      'Aggregate prefix (empty uses the profile name)',
      name: 'aggregatePrefix',
      desc: '',
      args: [],
    );
  }

  /// `IP or domain`
  String get chainIpOrDomain {
    return Intl.message(
      'IP or domain',
      name: 'chainIpOrDomain',
      desc: '',
      args: [],
    );
  }

  /// `WebRTC leak protection:`
  String get chainWebrtcProtect {
    return Intl.message(
      'WebRTC leak protection:',
      name: 'chainWebrtcProtect',
      desc: '',
      args: [],
    );
  }

  /// `Connectivity to common services`
  String get chainMainTargets {
    return Intl.message(
      'Connectivity to common services',
      name: 'chainMainTargets',
      desc: '',
      args: [],
    );
  }

  /// `Delete`
  String get chainDelete {
    return Intl.message('Delete', name: 'chainDelete', desc: '', args: []);
  }

  /// `Remove this hop`
  String get chainDeleteHop {
    return Intl.message(
      'Remove this hop',
      name: 'chainDeleteHop',
      desc: '',
      args: [],
    );
  }

  /// `Live topology`
  String get chainTopology {
    return Intl.message(
      'Live topology',
      name: 'chainTopology',
      desc: '',
      args: [],
    );
  }

  /// `Optional`
  String get chainOptional {
    return Intl.message('Optional', name: 'chainOptional', desc: '', args: []);
  }

  /// `Failed`
  String get chainFailed {
    return Intl.message('Failed', name: 'chainFailed', desc: '', args: []);
  }

  /// `No landing residential node yet`
  String get chainNoResidential {
    return Intl.message(
      'No landing residential node yet',
      name: 'chainNoResidential',
      desc: '',
      args: [],
    );
  }

  /// `Ready`
  String get chainReady {
    return Intl.message('Ready', name: 'chainReady', desc: '', args: []);
  }

  /// `Chain proxy enabled`
  String get chainEnabled {
    return Intl.message(
      'Chain proxy enabled',
      name: 'chainEnabled',
      desc: '',
      args: [],
    );
  }

  /// `No nodes match the filter`
  String get chainNoMatch {
    return Intl.message(
      'No nodes match the filter',
      name: 'chainNoMatch',
      desc: '',
      args: [],
    );
  }

  /// `Device time zone:`
  String get chainTz {
    return Intl.message(
      'Device time zone:',
      name: 'chainTz',
      desc: '',
      args: [],
    );
  }

  /// `Off`
  String get chainDisabled {
    return Intl.message('Off', name: 'chainDisabled', desc: '', args: []);
  }

  /// `Test`
  String get chainSpeedTest {
    return Intl.message('Test', name: 'chainSpeedTest', desc: '', args: []);
  }

  /// `Add relay server`
  String get chainAddRelay {
    return Intl.message(
      'Add relay server',
      name: 'chainAddRelay',
      desc: '',
      args: [],
    );
  }

  /// `Empty uses the global default dialer`
  String get chainInheritDefault {
    return Intl.message(
      'Empty uses the global default dialer',
      name: 'chainInheritDefault',
      desc: '',
      args: [],
    );
  }

  /// `Target network`
  String get chainTargetNet {
    return Intl.message(
      'Target network',
      name: 'chainTargetNet',
      desc: '',
      args: [],
    );
  }

  /// `Edit`
  String get chainEdit {
    return Intl.message('Edit', name: 'chainEdit', desc: '', args: []);
  }

  /// `Edit landing proxy`
  String get chainEditLanding {
    return Intl.message(
      'Edit landing proxy',
      name: 'chainEditLanding',
      desc: '',
      args: [],
    );
  }

  /// `On device`
  String get chainDeviceSide {
    return Intl.message(
      'On device',
      name: 'chainDeviceSide',
      desc: '',
      args: [],
    );
  }

  /// `Enter the server address first`
  String get chainEnterServer {
    return Intl.message(
      'Enter the server address first',
      name: 'chainEnterServer',
      desc: '',
      args: [],
    );
  }

  /// `Enter the server address`
  String get chainEnterServerHint {
    return Intl.message(
      'Enter the server address',
      name: 'chainEnterServerHint',
      desc: '',
      args: [],
    );
  }

  /// `Timeout`
  String get chainTimeout {
    return Intl.message('Timeout', name: 'chainTimeout', desc: '', args: []);
  }

  /// `Follow main selector`
  String get chainFollowMain {
    return Intl.message(
      'Follow main selector',
      name: 'chainFollowMain',
      desc: '',
      args: [],
    );
  }

  /// `Reset filter`
  String get chainResetFilter {
    return Intl.message(
      'Reset filter',
      name: 'chainResetFilter',
      desc: '',
      args: [],
    );
  }

  /// `Probing the chain…`
  String get chainProbing {
    return Intl.message(
      'Probing the chain…',
      name: 'chainProbing',
      desc: '',
      args: [],
    );
  }

  /// `• Dialer (hop): the first relay the device connects to, carrying the first leg of the route.`
  String get chainHelpHop {
    return Intl.message(
      '• Dialer (hop): the first relay the device connects to, carrying the first leg of the route.',
      name: 'chainHelpHop',
      desc: '',
      args: [],
    );
  }

  /// `• Multi-hop: traffic is routed in stages through the dialer and the landing node, so the topology stays decoupled.`
  String get chainHelpMultiHop {
    return Intl.message(
      '• Multi-hop: traffic is routed in stages through the dialer and the landing node, so the topology stays decoupled.',
      name: 'chainHelpMultiHop',
      desc: '',
      args: [],
    );
  }

  /// `⚠️ Why ToDetect flags the IP time zone in red, and what to do:`
  String get chainTzWhy {
    return Intl.message(
      '⚠️ Why ToDetect flags the IP time zone in red, and what to do:',
      name: 'chainTzWhy',
      desc: '',
      args: [],
    );
  }

  /// `What are the dialer and the landing node?`
  String get chainHelpTitle {
    return Intl.message(
      'What are the dialer and the landing node?',
      name: 'chainHelpTitle',
      desc: '',
      args: [],
    );
  }

  /// `e.g. US residential 01`
  String get chainResidentialExample {
    return Intl.message(
      'e.g. US residential 01',
      name: 'chainResidentialExample',
      desc: '',
      args: [],
    );
  }

  /// `Inserts a relay at the end of the chain, before the exit`
  String get chainAddRelayDesc {
    return Intl.message(
      'Inserts a relay at the end of the chain, before the exit',
      name: 'chainAddRelayDesc',
      desc: '',
      args: [],
    );
  }

  /// `Not probed yet: the colour reflects configuration, not health`
  String get chainNotProbed {
    return Intl.message(
      'Not probed yet: the colour reflects configuration, not health',
      name: 'chainNotProbed',
      desc: '',
      args: [],
    );
  }

  /// `STUN/TURN blocked (zero leaks)`
  String get chainStunBlocked {
    return Intl.message(
      'STUN/TURN blocked (zero leaks)',
      name: 'chainStunBlocked',
      desc: '',
      args: [],
    );
  }

  /// `Add and enable at least one landing proxy first`
  String get chainNeedLanding {
    return Intl.message(
      'Add and enable at least one landing proxy first',
      name: 'chainNeedLanding',
      desc: '',
      args: [],
    );
  }

  /// `Every hop probed cleanly; end-to-end reachability depends on the real request`
  String get chainProbePassed {
    return Intl.message(
      'Every hop probed cleanly; end-to-end reachability depends on the real request',
      name: 'chainProbePassed',
      desc: '',
      args: [],
    );
  }

  /// `Some hops have no result; unprobed nodes stay neutral`
  String get chainPartialProbe {
    return Intl.message(
      'Some hops have no result; unprobed nodes stay neutral',
      name: 'chainPartialProbe',
      desc: '',
      args: [],
    );
  }

  /// `Time zone and risk-control tips for ToDetect / Whoer / IPpure`
  String get chainTzAdvice {
    return Intl.message(
      'Time zone and risk-control tips for ToDetect / Whoer / IPpure',
      name: 'chainTzAdvice',
      desc: '',
      args: [],
    );
  }

  /// `🎯 Guide to cross-border accounts and fingerprint isolation`
  String get chainFingerprintGuide {
    return Intl.message(
      '🎯 Guide to cross-border accounts and fingerprint isolation',
      name: 'chainFingerprintGuide',
      desc: '',
      args: [],
    );
  }

  /// `Relay {index}`
  String chainRelayIndex(String index) {
    return Intl.message(
      'Relay $index',
      name: 'chainRelayIndex',
      desc: '',
      args: [index],
    );
  }

  /// `Residential {server}:{port}`
  String chainResidentialIp(String server, String port) {
    return Intl.message(
      'Residential $server:$port',
      name: 'chainResidentialIp',
      desc: '',
      args: [server, port],
    );
  }

  /// `Dialer: {name}`
  String chainDialerValue(String name) {
    return Intl.message(
      'Dialer: $name',
      name: 'chainDialerValue',
      desc: '',
      args: [name],
    );
  }

  /// `Route WARP through the proxy`
  String get warpRouteWarpOverProxy {
    return Intl.message(
      'Route WARP through the proxy',
      name: 'warpRouteWarpOverProxy',
      desc: '',
      args: [],
    );
  }

  /// `Route WARP through the proxy (recommended: provider plus WARP exit, avoids region leaks and unlocks streaming and AI)`
  String get warpRouteWarpOverProxyDesc {
    return Intl.message(
      'Route WARP through the proxy (recommended: provider plus WARP exit, avoids region leaks and unlocks streaming and AI)',
      name: 'warpRouteWarpOverProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Route the proxy through WARP`
  String get warpRouteProxyOverWarp {
    return Intl.message(
      'Route the proxy through WARP',
      name: 'warpRouteProxyOverWarp',
      desc: '',
      args: [],
    );
  }

  /// `Route the proxy through WARP (WARP as the dialer that reaches blocked nodes)`
  String get warpRouteProxyOverWarpDesc {
    return Intl.message(
      'Route the proxy through WARP (WARP as the dialer that reaches blocked nodes)',
      name: 'warpRouteProxyOverWarpDesc',
      desc: '',
      args: [],
    );
  }

  /// `Edge node {code}`
  String warpEdgeNode(String code) {
    return Intl.message(
      'Edge node $code',
      name: 'warpEdgeNode',
      desc: '',
      args: [code],
    );
  }

  /// `Unknown edge node`
  String get warpUnknownColo {
    return Intl.message(
      'Unknown edge node',
      name: 'warpUnknownColo',
      desc: '',
      args: [],
    );
  }

  /// `Save`
  String get nodeDetailSave {
    return Intl.message('Save', name: 'nodeDetailSave', desc: '', args: []);
  }

  /// `Close`
  String get nodeDetailClose {
    return Intl.message('Close', name: 'nodeDetailClose', desc: '', args: []);
  }

  /// `Cancel`
  String get nodeDetailCancel {
    return Intl.message('Cancel', name: 'nodeDetailCancel', desc: '', args: []);
  }

  /// `Copy config`
  String get nodeDetailCopyConfig {
    return Intl.message(
      'Copy config',
      name: 'nodeDetailCopyConfig',
      desc: '',
      args: [],
    );
  }

  /// `Copied`
  String get nodeDetailCopied {
    return Intl.message('Copied', name: 'nodeDetailCopied', desc: '', args: []);
  }

  /// `Saved; restart the core to apply`
  String get nodeDetailSaved {
    return Intl.message(
      'Saved; restart the core to apply',
      name: 'nodeDetailSaved',
      desc: '',
      args: [],
    );
  }

  /// `Modified`
  String get nodeDetailModified {
    return Intl.message(
      'Modified',
      name: 'nodeDetailModified',
      desc: '',
      args: [],
    );
  }

  /// `Restored the original config; restart the core to apply`
  String get nodeDetailRestored {
    return Intl.message(
      'Restored the original config; restart the core to apply',
      name: 'nodeDetailRestored',
      desc: '',
      args: [],
    );
  }

  /// `Restore original`
  String get nodeDetailRestore {
    return Intl.message(
      'Restore original',
      name: 'nodeDetailRestore',
      desc: '',
      args: [],
    );
  }

  /// `No original config for this node - it may come from a group or have been replaced by a subscription update`
  String get nodeDetailMissing {
    return Intl.message(
      'No original config for this node - it may come from a group or have been replaced by a subscription update',
      name: 'nodeDetailMissing',
      desc: '',
      args: [],
    );
  }

  /// `Edit`
  String get nodeDetailEdit {
    return Intl.message('Edit', name: 'nodeDetailEdit', desc: '', args: []);
  }

  /// `Edit {name}`
  String nodeDetailEditTitle(String name) {
    return Intl.message(
      'Edit $name',
      name: 'nodeDetailEditTitle',
      desc: '',
      args: [name],
    );
  }

  /// `Card can reach the core`
  String get generalCardCoreTitle {
    return Intl.message(
      'Card can reach the core',
      name: 'generalCardCoreTitle',
      desc: '',
      args: [],
    );
  }

  /// `The core always listens on the loopback address so the notification card can talk to it`
  String get generalCardCoreDesc {
    return Intl.message(
      'The core always listens on the loopback address so the notification card can talk to it',
      name: 'generalCardCoreDesc',
      desc: '',
      args: [],
    );
  }

  /// `Keep the service up when restarting the core`
  String get generalKeepService {
    return Intl.message(
      'Keep the service up when restarting the core',
      name: 'generalKeepService',
      desc: '',
      args: [],
    );
  }

  /// `Off: the service follows the core and the notification briefly shows disconnected`
  String get generalKeepServiceDesc {
    return Intl.message(
      'Off: the service follows the core and the notification briefly shows disconnected',
      name: 'generalKeepServiceDesc',
      desc: '',
      args: [],
    );
  }

  /// `Choose a node`
  String get cardNodeSelect {
    return Intl.message(
      'Choose a node',
      name: 'cardNodeSelect',
      desc: '',
      args: [],
    );
  }

  /// `Follow main selector`
  String get cardFollowMain {
    return Intl.message(
      'Follow main selector',
      name: 'cardFollowMain',
      desc: '',
      args: [],
    );
  }

  /// `Select`
  String get cardSelect {
    return Intl.message('Select', name: 'cardSelect', desc: '', args: []);
  }

  /// `🔗 Dialer: {hop}`
  String cardHopValue(String hop) {
    return Intl.message(
      '🔗 Dialer: $hop',
      name: 'cardHopValue',
      desc: '',
      args: [hop],
    );
  }

  /// `Checking…`
  String get smartChecking {
    return Intl.message('Checking…', name: 'smartChecking', desc: '', args: []);
  }

  /// `Check failed: {error}`
  String smartCheckFailed(String error) {
    return Intl.message(
      'Check failed: $error',
      name: 'smartCheckFailed',
      desc: '',
      args: [error],
    );
  }

  /// `No data`
  String get smartNoData {
    return Intl.message('No data', name: 'smartNoData', desc: '', args: []);
  }

  /// `No score`
  String get smartNoScore {
    return Intl.message('No score', name: 'smartNoScore', desc: '', args: []);
  }

  /// `Possibly unavailable`
  String get smartSuspect {
    return Intl.message(
      'Possibly unavailable',
      name: 'smartSuspect',
      desc: '',
      args: [],
    );
  }

  /// `Check now`
  String get smartCheckNow {
    return Intl.message('Check now', name: 'smartCheckNow', desc: '', args: []);
  }

  /// `Set as current route, then check`
  String get smartSetAsCurrent {
    return Intl.message(
      'Set as current route, then check',
      name: 'smartSetAsCurrent',
      desc: '',
      args: [],
    );
  }

  /// `Set this node as the current route before checking`
  String get smartNeedCurrent {
    return Intl.message(
      'Set this node as the current route before checking',
      name: 'smartNeedCurrent',
      desc: '',
      args: [],
    );
  }

  /// `Check again`
  String get smartRecheck {
    return Intl.message(
      'Check again',
      name: 'smartRecheck',
      desc: '',
      args: [],
    );
  }

  /// `Name`
  String get pickerName {
    return Intl.message('Name', name: 'pickerName', desc: '', args: []);
  }

  /// `Latency`
  String get pickerLatency {
    return Intl.message('Latency', name: 'pickerLatency', desc: '', args: []);
  }

  /// `Smart`
  String get pickerSmart {
    return Intl.message('Smart', name: 'pickerSmart', desc: '', args: []);
  }

  /// `No latency yet - sorting by name until a node is tested`
  String get pickerNoDelay {
    return Intl.message(
      'No latency yet - sorting by name until a node is tested',
      name: 'pickerNoDelay',
      desc: '',
      args: [],
    );
  }

  /// `Probing latency…`
  String get pickerProbing {
    return Intl.message(
      'Probing latency…',
      name: 'pickerProbing',
      desc: '',
      args: [],
    );
  }

  /// `Fluxora config push`
  String get tvPushTitle {
    return Intl.message(
      'Fluxora config push',
      name: 'tvPushTitle',
      desc: '',
      args: [],
    );
  }

  /// `✅ Sent to the TV. It is importing the config now…`
  String get tvPushDoneAuto {
    return Intl.message(
      '✅ Sent to the TV. It is importing the config now…',
      name: 'tvPushDoneAuto',
      desc: '',
      args: [],
    );
  }

  /// `✅ Config file sent to the TV`
  String get tvPushDoneFile {
    return Intl.message(
      '✅ Config file sent to the TV',
      name: 'tvPushDoneFile',
      desc: '',
      args: [],
    );
  }

  /// `❌ Failed - cannot reach the TV:`
  String get tvPushConnectFailed {
    return Intl.message(
      '❌ Failed - cannot reach the TV:',
      name: 'tvPushConnectFailed',
      desc: '',
      args: [],
    );
  }

  /// `❌ Failed:`
  String get tvPushFailed {
    return Intl.message('❌ Failed:', name: 'tvPushFailed', desc: '', args: []);
  }

  /// `❌ Could not read the file`
  String get tvReadFailed {
    return Intl.message(
      '❌ Could not read the file',
      name: 'tvReadFailed',
      desc: '',
      args: [],
    );
  }

  /// `Paste a Clash Meta subscription link (https://…)`
  String get tvUrlHint {
    return Intl.message(
      'Paste a Clash Meta subscription link (https://…)',
      name: 'tvUrlHint',
      desc: '',
      args: [],
    );
  }

  /// `Left empty, it is detected automatically`
  String get tvNameHint {
    return Intl.message(
      'Left empty, it is detected automatically',
      name: 'tvNameHint',
      desc: '',
      args: [],
    );
  }

  /// `Local config file`
  String get tvLocalFile {
    return Intl.message(
      'Local config file',
      name: 'tvLocalFile',
      desc: '',
      args: [],
    );
  }

  /// `Sending…`
  String get tvPushing {
    return Intl.message('Sending…', name: 'tvPushing', desc: '', args: []);
  }

  /// `Reading and sending…`
  String get tvReadingPushing {
    return Intl.message(
      'Reading and sending…',
      name: 'tvReadingPushing',
      desc: '',
      args: [],
    );
  }

  /// `Choose a .yaml / .yml config`
  String get tvPickFile {
    return Intl.message(
      'Choose a .yaml / .yml config',
      name: 'tvPickFile',
      desc: '',
      args: [],
    );
  }

  /// `Subscription link`
  String get tvSubscriptionUrl {
    return Intl.message(
      'Subscription link',
      name: 'tvSubscriptionUrl',
      desc: '',
      args: [],
    );
  }

  /// `Subscription link (URL)`
  String get tvSubscriptionUrlLabel {
    return Intl.message(
      'Subscription link (URL)',
      name: 'tvSubscriptionUrlLabel',
      desc: '',
      args: [],
    );
  }

  /// `Enter the subscription link first`
  String get tvNeedUrl {
    return Intl.message(
      'Enter the subscription link first',
      name: 'tvNeedUrl',
      desc: '',
      args: [],
    );
  }

  /// `Config name (optional)`
  String get tvConfigName {
    return Intl.message(
      'Config name (optional)',
      name: 'tvConfigName',
      desc: '',
      args: [],
    );
  }

  /// `🚀 Send to TV`
  String get tvPushToTv {
    return Intl.message(
      '🚀 Send to TV',
      name: 'tvPushToTv',
      desc: '',
      args: [],
    );
  }

  /// `🚀 Send config file`
  String get tvPushConfig {
    return Intl.message(
      '🚀 Send config file',
      name: 'tvPushConfig',
      desc: '',
      args: [],
    );
  }

  /// `Search nodes`
  String get chainSearchNode {
    return Intl.message(
      'Search nodes',
      name: 'chainSearchNode',
      desc: '',
      args: [],
    );
  }

  /// `None (use the subscription node directly)`
  String get chainNoneDirect {
    return Intl.message(
      'None (use the subscription node directly)',
      name: 'chainNoneDirect',
      desc: '',
      args: [],
    );
  }

  /// `No response from the node`
  String get ipCheckTimeout {
    return Intl.message(
      'No response from the node',
      name: 'ipCheckTimeout',
      desc: '',
      args: [],
    );
  }

  /// `Core is not ready`
  String get ipCheckCoreNotReady {
    return Intl.message(
      'Core is not ready',
      name: 'ipCheckCoreNotReady',
      desc: '',
      args: [],
    );
  }

  /// `This link returned a web page, not a script file. On GitHub, use the Raw link.`
  String get scriptUrlNotAScript {
    return Intl.message(
      'This link returned a web page, not a script file. On GitHub, use the Raw link.',
      name: 'scriptUrlNotAScript',
      desc: '',
      args: [],
    );
  }

  /// `Controller port fallback`
  String get controllerPortFallback {
    return Intl.message(
      'Controller port fallback',
      name: 'controllerPortFallback',
      desc: '',
      args: [],
    );
  }

  /// `When 9090 is taken at start-up, this session uses the next free port instead of leaving the switch card unable to reach the core.`
  String get controllerPortFallbackDesc {
    return Intl.message(
      'When 9090 is taken at start-up, this session uses the next free port instead of leaving the switch card unable to reach the core.',
      name: 'controllerPortFallbackDesc',
      desc: '',
      args: [],
    );
  }

  /// `Residential IP check`
  String get residentialIpCheck {
    return Intl.message(
      'Residential IP check',
      name: 'residentialIpCheck',
      desc: '',
      args: [],
    );
  }

  /// `Verifies the landing proxy credentials and the real exit IP.`
  String get residentialIpCheckDesc {
    return Intl.message(
      'Verifies the landing proxy credentials and the real exit IP.',
      name: 'residentialIpCheckDesc',
      desc: '',
      args: [],
    );
  }

  /// `Checking…`
  String get residentialIpChecking {
    return Intl.message(
      'Checking…',
      name: 'residentialIpChecking',
      desc: '',
      args: [],
    );
  }

  /// `Run check`
  String get residentialIpCheckStart {
    return Intl.message(
      'Run check',
      name: 'residentialIpCheckStart',
      desc: '',
      args: [],
    );
  }

  /// `Diagnostics`
  String get chainDiagnostics {
    return Intl.message(
      'Diagnostics',
      name: 'chainDiagnostics',
      desc: '',
      args: [],
    );
  }

  /// `A probe ran; open for the topology it used.`
  String get chainDiagnosticsOk {
    return Intl.message(
      'A probe ran; open for the topology it used.',
      name: 'chainDiagnosticsOk',
      desc: '',
      args: [],
    );
  }

  /// `The last probe failed; open for what it actually tested.`
  String get chainDiagnosticsFailed {
    return Intl.message(
      'The last probe failed; open for what it actually tested.',
      name: 'chainDiagnosticsFailed',
      desc: '',
      args: [],
    );
  }

  /// `Direct`
  String get residentialIpCheckDirect {
    return Intl.message(
      'Direct',
      name: 'residentialIpCheckDirect',
      desc: '',
      args: [],
    );
  }

  /// `Via chain`
  String get residentialIpCheckViaChain {
    return Intl.message(
      'Via chain',
      name: 'residentialIpCheckViaChain',
      desc: '',
      args: [],
    );
  }

  /// `System DNS mode`
  String get tunDnsMode {
    return Intl.message(
      'System DNS mode',
      name: 'tunDnsMode',
      desc: '',
      args: [],
    );
  }

  /// `How the core configures system DNS under TUN.`
  String get tunDnsModeDesc {
    return Intl.message(
      'How the core configures system DNS under TUN.',
      name: 'tunDnsModeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Follow core default`
  String get tunDnsModeDefault {
    return Intl.message(
      'Follow core default',
      name: 'tunDnsModeDefault',
      desc: '',
      args: [],
    );
  }

  /// `Do not touch system DNS`
  String get tunDnsModeDisabled {
    return Intl.message(
      'Do not touch system DNS',
      name: 'tunDnsModeDisabled',
      desc: '',
      args: [],
    );
  }

  /// `Set TUN address as system DNS`
  String get tunDnsModeNative {
    return Intl.message(
      'Set TUN address as system DNS',
      name: 'tunDnsModeNative',
      desc: '',
      args: [],
    );
  }

  /// `Also intercept DNS sent to other interfaces`
  String get tunDnsModeHijack {
    return Intl.message(
      'Also intercept DNS sent to other interfaces',
      name: 'tunDnsModeHijack',
      desc: '',
      args: [],
    );
  }

  /// `The core stopped unexpectedly. Restarting it.`
  String get coreAutoRestart {
    return Intl.message(
      'The core stopped unexpectedly. Restarting it.',
      name: 'coreAutoRestart',
      desc: '',
      args: [],
    );
  }

  /// `The core keeps stopping. Automatic restart has given up.`
  String get coreAutoRestartFailed {
    return Intl.message(
      'The core keeps stopping. Automatic restart has given up.',
      name: 'coreAutoRestartFailed',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'fa'),
      Locale.fromSubtags(languageCode: 'ja'),
      Locale.fromSubtags(languageCode: 'ko'),
      Locale.fromSubtags(languageCode: 'ru'),
      Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
      Locale.fromSubtags(languageCode: 'zh', countryCode: 'TC'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
