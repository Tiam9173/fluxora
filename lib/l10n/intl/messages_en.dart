// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(role) => "Add ${role} candidate";

  static String m1(role) => "Add ${role} backup candidate";

  static String m2(completed, total) => "Checking (${completed}/${total})…";

  static String m3(count) => "Successfully imported ${count} node(s)";

  static String m4(hop) => "🔗 Dialer: ${hop}";

  static String m5(name) => "Dialer: ${name}";

  static String m6(index) => "Relay ${index}";

  static String m7(server, port) => "Residential ${server}:${port}";

  static String m8(count) => "Cleared ${count} invalid nodes";

  static String m9(name) => "Are you sure you want to delete node \"${name}\"?";

  static String m10(error) => "Failed to create group: ${error}";

  static String m11(name) =>
      "Blank group \"${name}\" created, please add nodes";

  static String m12(count) =>
      "${Intl.plural(count, one: 'day', other: 'days')}";

  static String m13(label) => "Delete selected ${label}?";

  static String m14(label) => "Delete current ${label}?";

  static String m15(label) => "${label} cannot be empty";

  static String m16(label) => "${label} already exists";

  static String m17(reason) => "Failover failed: ${reason}";

  static String m18(node) => "Failover succeeded, switched to [${node}]";

  static String m19(count) =>
      "${Intl.plural(count, one: 'hour', other: 'hours')}";

  static String m20(count) => "Imported ${count} landing proxy nodes";

  static String m21(count) => "${count}";

  static String m22(count) =>
      "${Intl.plural(count, one: 'minute', other: 'minutes')}";

  static String m23(count) =>
      "${Intl.plural(count, one: 'month', other: 'months')}";

  static String m24(name) => "Node added: ${name}";

  static String m25(name) => "Node deleted: ${name}";

  static String m26(name) => "Edit ${name}";

  static String m27(name) => "Node management · ${name}";

  static String m28(proto) => "e.g. Hong Kong 01 - ${proto}";

  static String m29(label) => "No ${label}";

  static String m30(label) => "${label} must be a number";

  static String m31(from, to) =>
      "Port ${from} is in use; using ${to} for this session";

  static String m32(label) =>
      "${label} must be between 1024 and 49151, 0 to disable";

  static String m33(name) => "Pre-proxy & Landing Proxy · ${name}";

  static String m34(statusCode) =>
      "Failed to import profile. Please check your network status or try resetting the subscription link ( HTTP error code: ${statusCode} )";

  static String m35(count) => "${count} items selected";

  static String m36(error) => "Check failed: ${error}";

  static String m37(name) => "Still using: ${name}";

  static String m38(label) => "${label} must be a URL";

  static String m39(label) => "Copied ${label}";

  static String m40(colo, ip) =>
      "🎉 Diagnostics passed. WARP is active (colo: ${colo}, exit: ${ip})";

  static String m41(name) => "Dialer set to ${name}";

  static String m42(code) => "Edge node ${code}";

  static String m43(ip) => "Using the fastest node: ${ip}";

  static String m44(ip) => "Using ${ip}";

  static String m45(ip) =>
      "Note: connected to exit ${ip} but no WARP signature was found - check the dialer";

  static String m46(loc) => "Region: ${loc}";

  static String m47(label) => "Switched to ${label}";

  static String m48(count) =>
      "${Intl.plural(count, one: 'year', other: 'years')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("About"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Access Control"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Only route selected apps through VPN",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "Configure per-app access allowlist/blocklist",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Exclude selected apps from VPN",
    ),
    "account": MessageLookupByLibrary.simpleMessage("Account"),
    "action": MessageLookupByLibrary.simpleMessage("Action"),
    "action_mode": MessageLookupByLibrary.simpleMessage("Switch Mode"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("System Proxy"),
    "action_start": MessageLookupByLibrary.simpleMessage("Start/Stop"),
    "action_tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "action_view": MessageLookupByLibrary.simpleMessage("Show/Hide"),
    "activeGoroutines": MessageLookupByLibrary.simpleMessage("Goroutines"),
    "add": MessageLookupByLibrary.simpleMessage("Add"),
    "addLandingProxy": MessageLookupByLibrary.simpleMessage(
      "Add Landing Proxy",
    ),
    "addProfile": MessageLookupByLibrary.simpleMessage("Add Profile"),
    "addRoleCandidate": m0,
    "addRoleFallbackCandidate": m1,
    "addRule": MessageLookupByLibrary.simpleMessage("Add Rule"),
    "addTunnel": MessageLookupByLibrary.simpleMessage("Add Forwarding"),
    "addUser": MessageLookupByLibrary.simpleMessage("Add User"),
    "addedOriginRules": MessageLookupByLibrary.simpleMessage(
      "Append to Original Rules",
    ),
    "address": MessageLookupByLibrary.simpleMessage("Address"),
    "addressHelp": MessageLookupByLibrary.simpleMessage(
      "WebDAV server address",
    ),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid WebDAV address",
    ),
    "adminAutoLaunch": MessageLookupByLibrary.simpleMessage(
      "Admin Auto-Launch",
    ),
    "adminAutoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Auto-start with admin privileges",
    ),
    "advancedSettings": MessageLookupByLibrary.simpleMessage(
      "Advanced Settings",
    ),
    "ageKeyGenerateTitle": MessageLookupByLibrary.simpleMessage(
      "Age Key Generation",
    ),
    "ageKeyPairGeneratedSuccess": MessageLookupByLibrary.simpleMessage(
      "X25519 Key pair generated, please keep it safe",
    ),
    "agePrivateKeyLabel": MessageLookupByLibrary.simpleMessage(
      "Age Private Key",
    ),
    "agePrivateKeyRequired": MessageLookupByLibrary.simpleMessage(
      "Please enter a correct Age private key first",
    ),
    "agePublicKeyLabel": MessageLookupByLibrary.simpleMessage("Age Public Key"),
    "ageSecretKeyInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid Age secret key (must start with AGE-SECRET-KEY-)",
    ),
    "ageSecretKeyOptional": MessageLookupByLibrary.simpleMessage(
      "Age Secret Key (Optional)",
    ),
    "aggregateJoin": MessageLookupByLibrary.simpleMessage(
      "Join the aggregate group",
    ),
    "aggregateJoinDesc": MessageLookupByLibrary.simpleMessage(
      "Merges this profile\'s nodes into the aggregate group",
    ),
    "aggregatePrefix": MessageLookupByLibrary.simpleMessage(
      "Aggregate prefix (empty uses the profile name)",
    ),
    "ago": MessageLookupByLibrary.simpleMessage(" ago"),
    "agree": MessageLookupByLibrary.simpleMessage("Agree"),
    "allApps": MessageLookupByLibrary.simpleMessage("All Apps"),
    "allocatedMemory": MessageLookupByLibrary.simpleMessage("Allocated"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("Allow Bypassing VPN"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "Allow specific apps to bypass VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Allow LAN"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Allow LAN access to proxy",
    ),
    "alreadyInWhitelist": MessageLookupByLibrary.simpleMessage(
      "Already in whitelist",
    ),
    "alwaysShowTitleBar": MessageLookupByLibrary.simpleMessage("Title Buttons"),
    "alwaysShowTitleBarDesc": MessageLookupByLibrary.simpleMessage(
      "Always show the title bar buttons in the top-right corner",
    ),
    "amneziaObfsParams": MessageLookupByLibrary.simpleMessage(
      "AmneziaWG 2/3 obfuscation parameters (Jc / Jmin / Jmax / S1 / S2 / H1-H4)",
    ),
    "app": MessageLookupByLibrary.simpleMessage("App"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "App Access Control",
    ),
    "appDesc": MessageLookupByLibrary.simpleMessage("App-related settings"),
    "application": MessageLookupByLibrary.simpleMessage("Application"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "Modify application settings",
    ),
    "ascending": MessageLookupByLibrary.simpleMessage("Ascending"),
    "authorized": MessageLookupByLibrary.simpleMessage("Authorized"),
    "auto": MessageLookupByLibrary.simpleMessage("Auto"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Auto Check Updates",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Check updates on app launch",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Auto-Close Connections",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Close connections when switching nodes",
    ),
    "autoFailover": MessageLookupByLibrary.simpleMessage("Automatic failover"),
    "autoFailoverOffDesc": MessageLookupByLibrary.simpleMessage(
      "Off: only the button below can switch manually",
    ),
    "autoFailoverOnDesc": MessageLookupByLibrary.simpleMessage(
      "Switches to a backup candidate when the chain keeps failing",
    ),
    "autoInjectGroups": MessageLookupByLibrary.simpleMessage(
      "Auto-inject into the main selector group",
    ),
    "autoInjectGroupsDesc": MessageLookupByLibrary.simpleMessage(
      "Automatically adds enabled landing proxies to main routing groups such as 「节点选择」",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Auto Launch"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Launch on system startup",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("Auto Run"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Connect on app launch",
    ),
    "autoScroll": MessageLookupByLibrary.simpleMessage("Auto Scroll"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Auto Set System DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Auto Update"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Auto update interval (min)",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Back"),
    "backup": MessageLookupByLibrary.simpleMessage("Backup"),
    "backupAndRecovery": MessageLookupByLibrary.simpleMessage(
      "Backup & Restore",
    ),
    "backupAndRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "Sync data via WebDAV or locally",
    ),
    "backupPassword": MessageLookupByLibrary.simpleMessage("Backup password"),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("Backup Successful"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Core Configuration"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Global core settings",
    ),
    "batchCheckingProgress": m2,
    "batchImportLinks": MessageLookupByLibrary.simpleMessage(
      "Batch import links",
    ),
    "batchImportParseFailed": MessageLookupByLibrary.simpleMessage(
      "No valid node link could be parsed. Please check the format.",
    ),
    "batchImportPasteHint": MessageLookupByLibrary.simpleMessage(
      "Paste node share links or node config (YAML/JSON) here...",
    ),
    "batchImportShareLinks": MessageLookupByLibrary.simpleMessage(
      "Batch import share links",
    ),
    "batchImportSuccess": m3,
    "batchImportSupportHint": MessageLookupByLibrary.simpleMessage(
      "Supports single/multi-line links or YAML/JSON node snippets:",
    ),
    "batteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Battery Optimization",
    ),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "Request battery optimization whitelist",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("Bind"),
    "blacklist": MessageLookupByLibrary.simpleMessage("Blacklist"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("Blacklist Mode"),
    "blockComment": MessageLookupByLibrary.simpleMessage("Comment"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Bypass Domain"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Active only when System Proxy is on",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "Bypass Private Network",
    ),
    "bypassPrivateRouteDesc": MessageLookupByLibrary.simpleMessage(
      "Automatically bypass private network IP addresses",
    ),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage("Cache Algorithm"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "Cache corrupted. Clear it?",
    ),
    "cameraPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "Camera Permission Denied",
    ),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Camera permission is required to scan QR codes. Please grant it in settings.",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cancelFilterSystemApp": MessageLookupByLibrary.simpleMessage(
      "Show System Apps",
    ),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("Deselect All"),
    "cardFollowMain": MessageLookupByLibrary.simpleMessage(
      "Follow main selector",
    ),
    "cardHopValue": m4,
    "cardNodeSelect": MessageLookupByLibrary.simpleMessage("Choose a node"),
    "cardSelect": MessageLookupByLibrary.simpleMessage("Select"),
    "categoryAi": MessageLookupByLibrary.simpleMessage("AI"),
    "categoryAll": MessageLookupByLibrary.simpleMessage("All"),
    "categoryChina": MessageLookupByLibrary.simpleMessage("China Direct"),
    "categoryCrypto": MessageLookupByLibrary.simpleMessage("Crypto"),
    "categoryDeveloper": MessageLookupByLibrary.simpleMessage("Developer"),
    "categoryGaming": MessageLookupByLibrary.simpleMessage("Gaming Center"),
    "categorySocial": MessageLookupByLibrary.simpleMessage("Social Platforms"),
    "categoryStreaming": MessageLookupByLibrary.simpleMessage("Streaming"),
    "chainAddRelay": MessageLookupByLibrary.simpleMessage("Add relay server"),
    "chainAddRelayDesc": MessageLookupByLibrary.simpleMessage(
      "Inserts a relay at the end of the chain, before the exit",
    ),
    "chainAvgLatency": MessageLookupByLibrary.simpleMessage("Avg Latency"),
    "chainCreateSupportPackage": MessageLookupByLibrary.simpleMessage(
      "Create Support Package",
    ),
    "chainCreatingPackage": MessageLookupByLibrary.simpleMessage("Creating..."),
    "chainDecisionSupport": MessageLookupByLibrary.simpleMessage(
      "Decision Support",
    ),
    "chainDelete": MessageLookupByLibrary.simpleMessage("Delete"),
    "chainDeleteHop": MessageLookupByLibrary.simpleMessage("Remove this hop"),
    "chainDeviceSide": MessageLookupByLibrary.simpleMessage("On device"),
    "chainDiagnosticPackage": MessageLookupByLibrary.simpleMessage(
      "Diagnostic Package",
    ),
    "chainDiagnosticTitle": MessageLookupByLibrary.simpleMessage(
      "Chain Diagnostic",
    ),
    "chainDiagnostics": MessageLookupByLibrary.simpleMessage("Diagnostics"),
    "chainDiagnosticsFailed": MessageLookupByLibrary.simpleMessage(
      "The last probe failed; open for what it actually tested.",
    ),
    "chainDiagnosticsOk": MessageLookupByLibrary.simpleMessage(
      "A probe ran; open for the topology it used.",
    ),
    "chainDialerValue": m5,
    "chainDisabled": MessageLookupByLibrary.simpleMessage("Off"),
    "chainEdit": MessageLookupByLibrary.simpleMessage("Edit"),
    "chainEditLanding": MessageLookupByLibrary.simpleMessage(
      "Edit landing proxy",
    ),
    "chainEnabled": MessageLookupByLibrary.simpleMessage("Chain proxy enabled"),
    "chainEnterServer": MessageLookupByLibrary.simpleMessage(
      "Enter the server address first",
    ),
    "chainEnterServerHint": MessageLookupByLibrary.simpleMessage(
      "Enter the server address",
    ),
    "chainEventsLabel": MessageLookupByLibrary.simpleMessage("Events"),
    "chainExportReport": MessageLookupByLibrary.simpleMessage("Export Report"),
    "chainExporting": MessageLookupByLibrary.simpleMessage("Exporting..."),
    "chainFailed": MessageLookupByLibrary.simpleMessage("Failed"),
    "chainFailuresLabel": MessageLookupByLibrary.simpleMessage("Failures"),
    "chainFingerprintGuide": MessageLookupByLibrary.simpleMessage(
      "🎯 Guide to cross-border accounts and fingerprint isolation",
    ),
    "chainFollowMain": MessageLookupByLibrary.simpleMessage(
      "Follow main selector",
    ),
    "chainGeneratedOn": MessageLookupByLibrary.simpleMessage("Generated on"),
    "chainHealthLabel": MessageLookupByLibrary.simpleMessage("Health"),
    "chainHealthScore": MessageLookupByLibrary.simpleMessage("Health Score"),
    "chainHelpHop": MessageLookupByLibrary.simpleMessage(
      "• Dialer (hop): the first relay the device connects to, carrying the first leg of the route.",
    ),
    "chainHelpMultiHop": MessageLookupByLibrary.simpleMessage(
      "• Multi-hop: traffic is routed in stages through the dialer and the landing node, so the topology stays decoupled.",
    ),
    "chainHelpTitle": MessageLookupByLibrary.simpleMessage(
      "What are the dialer and the landing node?",
    ),
    "chainHopExitNode": MessageLookupByLibrary.simpleMessage(
      "Hop 3 (exit node)",
    ),
    "chainHopIncomplete": MessageLookupByLibrary.simpleMessage(
      "Incomplete three-hop chain: select a relay node and an exit node",
    ),
    "chainHopMode": MessageLookupByLibrary.simpleMessage("Chain Hops"),
    "chainHopModeDesc": MessageLookupByLibrary.simpleMessage(
      "Two hops: entry hop → landing exit. Three hops inserts an additional relay node.",
    ),
    "chainHopNotSelected": MessageLookupByLibrary.simpleMessage("Not selected"),
    "chainHopRelayNode": MessageLookupByLibrary.simpleMessage(
      "Hop 2 (relay node)",
    ),
    "chainHopUnavailable": MessageLookupByLibrary.simpleMessage(
      "Could not read the list of available nodes, so node availability could not be verified",
    ),
    "chainInheritDefault": MessageLookupByLibrary.simpleMessage(
      "Empty uses the global default dialer",
    ),
    "chainIntelAnalytics": MessageLookupByLibrary.simpleMessage(
      "Intelligence Analytics",
    ),
    "chainIpOrDomain": MessageLookupByLibrary.simpleMessage("IP or domain"),
    "chainLandingProxyNone": MessageLookupByLibrary.simpleMessage(
      "Default (none)",
    ),
    "chainMainTargets": MessageLookupByLibrary.simpleMessage(
      "Connectivity to common services",
    ),
    "chainNeedLanding": MessageLookupByLibrary.simpleMessage(
      "Add and enable at least one landing proxy first",
    ),
    "chainNoMatch": MessageLookupByLibrary.simpleMessage(
      "No nodes match the filter",
    ),
    "chainNoResidential": MessageLookupByLibrary.simpleMessage(
      "No landing residential node yet",
    ),
    "chainNodeDeviceApp": MessageLookupByLibrary.simpleMessage("Device app"),
    "chainNodeGroupNodes": MessageLookupByLibrary.simpleMessage("Group nodes"),
    "chainNodeLocal": MessageLookupByLibrary.simpleMessage("Local"),
    "chainNodePreProxy": MessageLookupByLibrary.simpleMessage("Pre-proxy"),
    "chainNodeReliability": MessageLookupByLibrary.simpleMessage(
      "Node Reliability",
    ),
    "chainNodeSubscription": MessageLookupByLibrary.simpleMessage(
      "Subscription node",
    ),
    "chainNoneDirect": MessageLookupByLibrary.simpleMessage(
      "None (use the subscription node directly)",
    ),
    "chainNotProbed": MessageLookupByLibrary.simpleMessage(
      "Not probed yet: the colour reflects configuration, not health",
    ),
    "chainOpenFolder": MessageLookupByLibrary.simpleMessage("Open Folder"),
    "chainOptional": MessageLookupByLibrary.simpleMessage("Optional"),
    "chainPackageReady": MessageLookupByLibrary.simpleMessage("Package Ready"),
    "chainPartialProbe": MessageLookupByLibrary.simpleMessage(
      "Some hops have no result; unprobed nodes stay neutral",
    ),
    "chainPreProxyNone": MessageLookupByLibrary.simpleMessage("Direct (none)"),
    "chainProbeNow": MessageLookupByLibrary.simpleMessage("Probe chain"),
    "chainProbePassed": MessageLookupByLibrary.simpleMessage(
      "Every hop probed cleanly; end-to-end reachability depends on the real request",
    ),
    "chainProbing": MessageLookupByLibrary.simpleMessage("Probing the chain…"),
    "chainProxy": MessageLookupByLibrary.simpleMessage("Chain Proxy"),
    "chainProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Configure an entry hop and a static residential landing IP",
    ),
    "chainReady": MessageLookupByLibrary.simpleMessage("Ready"),
    "chainRelayIndex": m6,
    "chainResetFilter": MessageLookupByLibrary.simpleMessage("Reset filter"),
    "chainResidentialExample": MessageLookupByLibrary.simpleMessage(
      "e.g. US residential 01",
    ),
    "chainResidentialIp": m7,
    "chainSearchNode": MessageLookupByLibrary.simpleMessage("Search nodes"),
    "chainShareLabel": MessageLookupByLibrary.simpleMessage("Share"),
    "chainSpeedTest": MessageLookupByLibrary.simpleMessage("Test"),
    "chainStunBlocked": MessageLookupByLibrary.simpleMessage(
      "STUN/TURN blocked (zero leaks)",
    ),
    "chainSupportTitle": MessageLookupByLibrary.simpleMessage("Chain Support"),
    "chainTargetNet": MessageLookupByLibrary.simpleMessage("Target network"),
    "chainTimeout": MessageLookupByLibrary.simpleMessage("Timeout"),
    "chainTopFailureReason": MessageLookupByLibrary.simpleMessage(
      "Top Failure Reason",
    ),
    "chainTopology": MessageLookupByLibrary.simpleMessage("Live topology"),
    "chainTopologyPreview": MessageLookupByLibrary.simpleMessage(
      "Chain routing topology preview",
    ),
    "chainTz": MessageLookupByLibrary.simpleMessage("Device time zone:"),
    "chainTzAdvice": MessageLookupByLibrary.simpleMessage(
      "Time zone and risk-control tips for ToDetect / Whoer / IPpure",
    ),
    "chainTzWhy": MessageLookupByLibrary.simpleMessage(
      "⚠️ Why ToDetect flags the IP time zone in red, and what to do:",
    ),
    "chainWebrtcProtect": MessageLookupByLibrary.simpleMessage(
      "WebRTC leak protection:",
    ),
    "checkError": MessageLookupByLibrary.simpleMessage("Check Failed"),
    "checkFailed": MessageLookupByLibrary.simpleMessage("Timeout"),
    "checkOrAddProfile": MessageLookupByLibrary.simpleMessage(
      "Please add a profile first",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Check for Updates"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "Already on the latest version",
    ),
    "checkUpdatePrerelease": MessageLookupByLibrary.simpleMessage("Preview"),
    "checkUpdateStable": MessageLookupByLibrary.simpleMessage("Stable"),
    "checking": MessageLookupByLibrary.simpleMessage("Checking..."),
    "cipher": MessageLookupByLibrary.simpleMessage("Cipher"),
    "cipherLabel": MessageLookupByLibrary.simpleMessage("Cipher"),
    "circle": MessageLookupByLibrary.simpleMessage("Circle"),
    "clear": MessageLookupByLibrary.simpleMessage("Clear"),
    "clearAllRulesAndScripts": MessageLookupByLibrary.simpleMessage(
      "Clear all rules and scripts",
    ),
    "clearAllRulesAndScriptsTip": MessageLookupByLibrary.simpleMessage(
      "This removes every profile\'s override rules and all global scripts. It cannot be undone.",
    ),
    "clearCacheDesc": MessageLookupByLibrary.simpleMessage(
      "Clear FakeIP and DNS cache?",
    ),
    "clearCacheTitle": MessageLookupByLibrary.simpleMessage("Clear Cache"),
    "clearData": MessageLookupByLibrary.simpleMessage("Clear Data"),
    "clearDataTipDesc": MessageLookupByLibrary.simpleMessage(
      "This operation will reset the application. Please make backups. Are you sure you want to continue?",
    ),
    "clearDataTipTitle": MessageLookupByLibrary.simpleMessage(
      "Dangerous Operation",
    ),
    "clearInvalidProxies": MessageLookupByLibrary.simpleMessage(
      "Remove unavailable nodes",
    ),
    "clearedInvalidCount": m8,
    "clipboard": MessageLookupByLibrary.simpleMessage("Clipboard"),
    "clipboardDesc": MessageLookupByLibrary.simpleMessage(
      "Get profile link from clipboard",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Export to Clipboard",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Import from Clipboard",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Close"),
    "closeAll": MessageLookupByLibrary.simpleMessage("Close All"),
    "color": MessageLookupByLibrary.simpleMessage("Color"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("Color Schemes"),
    "columns": MessageLookupByLibrary.simpleMessage("Columns"),
    "compatible": MessageLookupByLibrary.simpleMessage("Compatible Mode"),
    "compatibleDesc": MessageLookupByLibrary.simpleMessage(
      "Enabling this mode may limit some features, but provides full Clash support",
    ),
    "concurrencyLimit": MessageLookupByLibrary.simpleMessage(
      "Concurrency Limit",
    ),
    "concurrencyLimitDesc": MessageLookupByLibrary.simpleMessage(
      "Maximum concurrent delay tests",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "confirmClearInvalid": MessageLookupByLibrary.simpleMessage(
      "Remove every residential IP that failed the check?",
    ),
    "confirmDelete": MessageLookupByLibrary.simpleMessage("Confirm deletion"),
    "confirmDeleteNodeMsg": m9,
    "confirmImport": MessageLookupByLibrary.simpleMessage("Confirm import"),
    "confirmPassword": MessageLookupByLibrary.simpleMessage("Confirm password"),
    "connection": MessageLookupByLibrary.simpleMessage("Active"),
    "connections": MessageLookupByLibrary.simpleMessage("Connections"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "View active connections",
    ),
    "connectionsSort": MessageLookupByLibrary.simpleMessage("Connections Sort"),
    "connectivity": MessageLookupByLibrary.simpleMessage("Connectivity:"),
    "contactMe": MessageLookupByLibrary.simpleMessage("Contact Me"),
    "content": MessageLookupByLibrary.simpleMessage("Content"),
    "contentScheme": MessageLookupByLibrary.simpleMessage("Content"),
    "continent": MessageLookupByLibrary.simpleMessage("Continent"),
    "controlSecret": MessageLookupByLibrary.simpleMessage("Control Secret"),
    "controlSecretDesc": MessageLookupByLibrary.simpleMessage(
      "RESTful API access password",
    ),
    "controllerPortFallback": MessageLookupByLibrary.simpleMessage(
      "Controller port fallback",
    ),
    "controllerPortFallbackDesc": MessageLookupByLibrary.simpleMessage(
      "When 9090 is taken at start-up, this session uses the next free port instead of leaving the switch card unable to reach the core.",
    ),
    "copiedPackageName": MessageLookupByLibrary.simpleMessage(
      "Copied package name",
    ),
    "copiedToClipboard": MessageLookupByLibrary.simpleMessage(
      "Copied to clipboard",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Copy"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Copy Environment Variable",
    ),
    "copyLink": MessageLookupByLibrary.simpleMessage("Copy Link"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Copy Successful"),
    "core": MessageLookupByLibrary.simpleMessage("Core"),
    "coreConnected": MessageLookupByLibrary.simpleMessage("Connected"),
    "coreInfo": MessageLookupByLibrary.simpleMessage("Core Info"),
    "coreStatus": MessageLookupByLibrary.simpleMessage("Core Status"),
    "coreSuspended": MessageLookupByLibrary.simpleMessage("Suspended"),
    "country": MessageLookupByLibrary.simpleMessage("Country"),
    "countryOrRegion": MessageLookupByLibrary.simpleMessage("Country / Region"),
    "crashTest": MessageLookupByLibrary.simpleMessage("Crash Test"),
    "create": MessageLookupByLibrary.simpleMessage("Create"),
    "createEmptyGroup": MessageLookupByLibrary.simpleMessage(
      "Create Empty Group",
    ),
    "createEmptyGroupDesc": MessageLookupByLibrary.simpleMessage(
      "Create a new blank configuration, supporting manual entry and management of self-hosted nodes across all protocols",
    ),
    "createEmptyGroupHint": MessageLookupByLibrary.simpleMessage(
      "After creating a blank group, you can manually add nodes for each protocol or import share links in bulk with one click.",
    ),
    "createGroupFailed": m10,
    "createGroupSuccess": m11,
    "creationTime": MessageLookupByLibrary.simpleMessage("Creation Time"),
    "custom": MessageLookupByLibrary.simpleMessage("Custom"),
    "customConfigHintText": MessageLookupByLibrary.simpleMessage(
      "Enter or paste a complete node YAML or JSON config snippet here:",
    ),
    "customConfigLabel": MessageLookupByLibrary.simpleMessage(
      "Custom config (YAML / JSON)",
    ),
    "customConfigNode": MessageLookupByLibrary.simpleMessage(
      "Custom config node",
    ),
    "customDashboardTitle": MessageLookupByLibrary.simpleMessage(
      "Custom Dashboard Title",
    ),
    "customLandingProxyName": MessageLookupByLibrary.simpleMessage(
      "Custom landing node name",
    ),
    "customNodesDefaultName": MessageLookupByLibrary.simpleMessage(
      "Custom Nodes",
    ),
    "customPreProxyName": MessageLookupByLibrary.simpleMessage(
      "Custom pre-proxy node name",
    ),
    "customScriptOptions": MessageLookupByLibrary.simpleMessage(
      "Custom Rule Switch",
    ),
    "customUrl": MessageLookupByLibrary.simpleMessage("Custom URL"),
    "cut": MessageLookupByLibrary.simpleMessage("Cut"),
    "dark": MessageLookupByLibrary.simpleMessage("Dark"),
    "darkIcon": MessageLookupByLibrary.simpleMessage("Dark Icon"),
    "darkIconDesc": MessageLookupByLibrary.simpleMessage(
      "Manually switch dark app icon",
    ),
    "dashboard": MessageLookupByLibrary.simpleMessage("Home"),
    "days": m12,
    "dedicatedGroup": MessageLookupByLibrary.simpleMessage(
      "Create a dedicated chain proxy group",
    ),
    "dedicatedGroupDesc": MessageLookupByLibrary.simpleMessage(
      "Adds a standalone 「🔗 链式代理」 policy group card on the proxies page",
    ),
    "defaultDialerProxy": MessageLookupByLibrary.simpleMessage(
      "Default Entry Hop",
    ),
    "defaultDialerProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Entry node or policy group that landing proxies use by default (a selector group is recommended)",
    ),
    "defaultGateway": MessageLookupByLibrary.simpleMessage("Default Gateway"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "Default Nameserver",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Used to resolve DNS servers",
    ),
    "defaultSort": MessageLookupByLibrary.simpleMessage("Default Sort"),
    "defaultText": MessageLookupByLibrary.simpleMessage("Default"),
    "delay": MessageLookupByLibrary.simpleMessage("Delay"),
    "delayAnimation": MessageLookupByLibrary.simpleMessage("Delay Animation"),
    "delayAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Customize animation during delay testing",
    ),
    "delaySort": MessageLookupByLibrary.simpleMessage("Sort by Delay"),
    "delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "deleteMultipTip": m13,
    "deleteNode": MessageLookupByLibrary.simpleMessage("Delete node"),
    "deleteTip": m14,
    "deleteTunnel": MessageLookupByLibrary.simpleMessage("Delete Forwarding"),
    "desc": MessageLookupByLibrary.simpleMessage(
      "Fluxora is based on the powerful and flexible Mihomo (Clash.Meta) proxy kernel, dedicated to a superior user experience. Our vision: Clear routes, calm control",
    ),
    "descending": MessageLookupByLibrary.simpleMessage("Descending"),
    "destination": MessageLookupByLibrary.simpleMessage("Destination"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "Destination GeoIP",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "Destination IP ASN",
    ),
    "details": MessageLookupByLibrary.simpleMessage("Details"),
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Third-party API result (for reference only)",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Developer Mode"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Developer mode is enabled.",
    ),
    "diagnosticAdvice": MessageLookupByLibrary.simpleMessage(
      "Diagnostic advice",
    ),
    "dialerIp4pConvert": MessageLookupByLibrary.simpleMessage(
      "Enable Dialer IP4P Conversion",
    ),
    "dialerIp4pConvertDesc": MessageLookupByLibrary.simpleMessage(
      "Enable dialer IP4P address conversion feature",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("Direct"),
    "directConnection": MessageLookupByLibrary.simpleMessage("DIRECT (no hop)"),
    "directNameserver": MessageLookupByLibrary.simpleMessage(
      "Direct Nameserver",
    ),
    "directNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Used to resolve direct domains",
    ),
    "directNameserverFollowPolicy": MessageLookupByLibrary.simpleMessage(
      "Direct DNS Follows Policy",
    ),
    "disableQuic": MessageLookupByLibrary.simpleMessage("Disable QUIC"),
    "disableQuicDesc": MessageLookupByLibrary.simpleMessage(
      "Disable QUIC to resolve specific network issues",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage("Disclaimer"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "This free open-source software is for non-commercial learning and personal use only. Proxy services are independent of this software. By agreeing, you acknowledge this; otherwise, please exit.",
    ),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "New Version Available",
    ),
    "discovery": MessageLookupByLibrary.simpleMessage("New Version Found"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("DNS-related settings"),
    "dnsHijack": MessageLookupByLibrary.simpleMessage("DNS Hijack"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "Redirect DNS queries to internal DNS module",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS Mode"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage(
      "Do you want to pass",
    ),
    "domain": MessageLookupByLibrary.simpleMessage("Organization / Domain"),
    "domainName": MessageLookupByLibrary.simpleMessage("Domain"),
    "doubleBounce": MessageLookupByLibrary.simpleMessage("Double Bounce"),
    "downLabel": MessageLookupByLibrary.simpleMessage("Down"),
    "download": MessageLookupByLibrary.simpleMessage("Download"),
    "dozeSuspend": MessageLookupByLibrary.simpleMessage("Doze Support"),
    "dozeSuspendDesc": MessageLookupByLibrary.simpleMessage(
      "Sync with system Doze mode",
    ),
    "duplicateNodeSkipped": MessageLookupByLibrary.simpleMessage(
      "Skipped duplicate node names (landing proxies must be unique)",
    ),
    "edit": MessageLookupByLibrary.simpleMessage("Edit"),
    "editTunnel": MessageLookupByLibrary.simpleMessage("Edit Forwarding"),
    "emptyLandingTip": MessageLookupByLibrary.simpleMessage(
      "No residential landing nodes yet. Paste in the common formats used by major residential IP providers (IPRoyal, LunaProxy, Oxylabs and others) to import them in one click.",
    ),
    "emptyTip": m15,
    "enableChainProxy": MessageLookupByLibrary.simpleMessage(
      "Enable Chain Proxy",
    ),
    "enableChainProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Relay through an entry node to reach the landing proxy, bypassing network restrictions while keeping a real residential exit",
    ),
    "enableCrashReport": MessageLookupByLibrary.simpleMessage(
      "Crash Analytics",
    ),
    "enableCrashReportDesc": MessageLookupByLibrary.simpleMessage(
      "Upload crash logs when needed",
    ),
    "enableOverride": MessageLookupByLibrary.simpleMessage("Enable Override"),
    "enableProfileChain": MessageLookupByLibrary.simpleMessage(
      "Enable chained proxy for this subscription group",
    ),
    "enableProfileChainDesc": MessageLookupByLibrary.simpleMessage(
      "Supports pre-proxy relay hopping and final landing exit configuration",
    ),
    "enableTraySpeed": MessageLookupByLibrary.simpleMessage("Tray Speed"),
    "enableTraySpeedDesc": MessageLookupByLibrary.simpleMessage(
      "Display upload and download rates in the menu bar",
    ),
    "enableUdpForwarding": MessageLookupByLibrary.simpleMessage(
      "Enable UDP forwarding",
    ),
    "encryptBackup": MessageLookupByLibrary.simpleMessage("Encrypt backup"),
    "encryptBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Encrypt the backup content with AES-256-GCM. The password is not stored; if lost, the backup cannot be restored",
    ),
    "endpointIndependentNat": MessageLookupByLibrary.simpleMessage(
      "NAT Enhancement",
    ),
    "endpointIndependentNatConfirmDesc": MessageLookupByLibrary.simpleMessage(
      "Enabling Endpoint-Independent NAT feature may slightly degrade performance. It is recommended to enable it only if necessary and you are familiar with it.",
    ),
    "endpointIndependentNatDesc": MessageLookupByLibrary.simpleMessage(
      "Optimize UDP/P2P application experience",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" entries"),
    "exclude": MessageLookupByLibrary.simpleMessage("Hide from Recents"),
    "excludeChina": MessageLookupByLibrary.simpleMessage("Exclude China"),
    "excludeChinaDesc": MessageLookupByLibrary.simpleMessage(
      "Allow China QUIC traffic instead of blocking all",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "Hide app from recent tasks list",
    ),
    "existsTip": m16,
    "exit": MessageLookupByLibrary.simpleMessage("Exit"),
    "expand": MessageLookupByLibrary.simpleMessage("Standard"),
    "experimental": MessageLookupByLibrary.simpleMessage("Experimental"),
    "experimentalDesc": MessageLookupByLibrary.simpleMessage(
      "Use with caution",
    ),
    "expirationTime": MessageLookupByLibrary.simpleMessage("Expiration Time"),
    "expired": MessageLookupByLibrary.simpleMessage("Expired"),
    "export": MessageLookupByLibrary.simpleMessage("Export"),
    "exportFile": MessageLookupByLibrary.simpleMessage("Export File"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Export Logs"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("Export Successful"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("Expressive"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "External Controller",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Control core via online port",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("External Link"),
    "externalResources": MessageLookupByLibrary.simpleMessage(
      "External Resources",
    ),
    "fadingCircle": MessageLookupByLibrary.simpleMessage("Fading Circle"),
    "fadingFour": MessageLookupByLibrary.simpleMessage("Fading Four"),
    "failover": MessageLookupByLibrary.simpleMessage("Failover"),
    "failoverEnableFirst": MessageLookupByLibrary.simpleMessage(
      "Enable chain proxy first",
    ),
    "failoverFailed": m17,
    "failoverInProgress": MessageLookupByLibrary.simpleMessage("Failing over…"),
    "failoverManualHint": MessageLookupByLibrary.simpleMessage(
      "Switch to a backup candidate manually when the chain fails",
    ),
    "failoverNoCandidates": MessageLookupByLibrary.simpleMessage(
      "No backup candidates configured yet",
    ),
    "failoverNoCandidatesAdvice": MessageLookupByLibrary.simpleMessage(
      "Add a backup candidate for at least one role above, then try again",
    ),
    "failoverSuccess": m18,
    "failoverTrigger": MessageLookupByLibrary.simpleMessage("Fail over now"),
    "failoverTriggerReason": MessageLookupByLibrary.simpleMessage(
      "User triggered failover manually",
    ),
    "fakeIpFilterMode": MessageLookupByLibrary.simpleMessage(
      "FakeIP Filter Mode",
    ),
    "fakeIpFilterModeDesc": MessageLookupByLibrary.simpleMessage(
      "Specify FakeIP filter mode",
    ),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("FakeIP Filter"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("FakeIP Range"),
    "fakeipRangeV6": MessageLookupByLibrary.simpleMessage("FakeIPv6 Range"),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("FakeIP TTL"),
    "fallback": MessageLookupByLibrary.simpleMessage("Fallback"),
    "fallbackConcurrent": MessageLookupByLibrary.simpleMessage(
      "Fallback Concurrent",
    ),
    "fallbackConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Query default DNS and Fallback synchronously",
    ),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Usually offshore DNS",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Fallback Filter"),
    "fcmOptimization": MessageLookupByLibrary.simpleMessage("FCM Optimization"),
    "fcmOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "Enhance FCM connection stability",
    ),
    "fcmTip": MessageLookupByLibrary.simpleMessage(
      "FCM connection and support depend on the device itself, the results are for reference only. Due to system permission reasons, you need to disable \"Allow bypass VPN\" in settings to get accurate results",
    ),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("Fidelity"),
    "fieldAbuse": MessageLookupByLibrary.simpleMessage("Abuse Reports"),
    "fieldAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "fieldBlocklists": MessageLookupByLibrary.simpleMessage("Blocklists"),
    "fieldMarkers": MessageLookupByLibrary.simpleMessage("Risk Markers"),
    "fieldNativeType": MessageLookupByLibrary.simpleMessage("Native IP"),
    "fieldScenarios": MessageLookupByLibrary.simpleMessage("Scenario Scores"),
    "fieldScore": MessageLookupByLibrary.simpleMessage("Purity Score"),
    "fieldUnknownNotes": MessageLookupByLibrary.simpleMessage("Unknowns"),
    "fieldUsageType": MessageLookupByLibrary.simpleMessage("Usage Type"),
    "file": MessageLookupByLibrary.simpleMessage("File"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("Upload profile file"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "File modified. Save changes?",
    ),
    "filterAll": MessageLookupByLibrary.simpleMessage("All"),
    "filterError": MessageLookupByLibrary.simpleMessage(
      "Unavailable / not checked",
    ),
    "filterHealthy": MessageLookupByLibrary.simpleMessage("Working only"),
    "filterSystemApp": MessageLookupByLibrary.simpleMessage(
      "Filter System Apps",
    ),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("Find Process"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "Enable process matching",
    ),
    "flagged": MessageLookupByLibrary.simpleMessage("Flagged"),
    "followMainSelector": MessageLookupByLibrary.simpleMessage(
      "Follow the current selector group (recommended)",
    ),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Font"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage(
      "Force DNS Mapping",
    ),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "Force mapping DNS results to connections",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("Force Sniff Domain"),
    "forceGCDesc": MessageLookupByLibrary.simpleMessage(
      "Force kernel garbage collection? Experimental, use with caution.",
    ),
    "forceGCTitle": MessageLookupByLibrary.simpleMessage(
      "Force Garbage Collection",
    ),
    "formatError": MessageLookupByLibrary.simpleMessage(
      "Please check the format",
    ),
    "fourColumns": MessageLookupByLibrary.simpleMessage("4 Columns"),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("Fruit Salad"),
    "general": MessageLookupByLibrary.simpleMessage("General"),
    "generalCardCoreDesc": MessageLookupByLibrary.simpleMessage(
      "The core always listens on the loopback address so the notification card can talk to it",
    ),
    "generalCardCoreTitle": MessageLookupByLibrary.simpleMessage(
      "Card can reach the core",
    ),
    "generalDesc": MessageLookupByLibrary.simpleMessage(
      "Modify global settings",
    ),
    "generalKeepService": MessageLookupByLibrary.simpleMessage(
      "Keep the service up when restarting the core",
    ),
    "generalKeepServiceDesc": MessageLookupByLibrary.simpleMessage(
      "Off: the service follows the core and the notification briefly shows disconnected",
    ),
    "generateFromPrivateKey": MessageLookupByLibrary.simpleMessage(
      "Generate from Age private key",
    ),
    "generateSecret": MessageLookupByLibrary.simpleMessage("Generate"),
    "geoData": MessageLookupByLibrary.simpleMessage("GeoData"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage("GEO Low Memory"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "Use GEO low memory loader",
    ),
    "geodataUse": MessageLookupByLibrary.simpleMessage("GEO Load"),
    "geoipCode": MessageLookupByLibrary.simpleMessage("GeoIP Code"),
    "getOriginRules": MessageLookupByLibrary.simpleMessage("Original Rules"),
    "global": MessageLookupByLibrary.simpleMessage("Global"),
    "go": MessageLookupByLibrary.simpleMessage("Go"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Download Now"),
    "groupName": MessageLookupByLibrary.simpleMessage("Group Name"),
    "harmonyFont": MessageLookupByLibrary.simpleMessage("Font Fix"),
    "harmonyFontDesc": MessageLookupByLibrary.simpleMessage(
      "Use built-in font to fix display issues",
    ),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Cache modifications?",
    ),
    "healthCheck": MessageLookupByLibrary.simpleMessage("Connectivity Check"),
    "healthCheckAll": MessageLookupByLibrary.simpleMessage("Full Check"),
    "healthCheckTimeout": MessageLookupByLibrary.simpleMessage("Timeout"),
    "healthCheckTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "Node health check timeout",
    ),
    "healthError": MessageLookupByLibrary.simpleMessage("Unavailable"),
    "healthHealthy": MessageLookupByLibrary.simpleMessage("Working"),
    "healthReport": MessageLookupByLibrary.simpleMessage(
      "Residential IP Connectivity Report",
    ),
    "healthUntested": MessageLookupByLibrary.simpleMessage("Not checked"),
    "healthWarning": MessageLookupByLibrary.simpleMessage("Partially limited"),
    "heapObjects": MessageLookupByLibrary.simpleMessage("Objects"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "Hide timed-out nodes",
    ),
    "hideTimeoutProxiesDesc": MessageLookupByLibrary.simpleMessage(
      "Leave out nodes whose last delay test timed out",
    ),
    "highPriority": MessageLookupByLibrary.simpleMessage("High Priority"),
    "highPriorityDesc": MessageLookupByLibrary.simpleMessage(
      "Increase priority of main process and core process",
    ),
    "highRefreshRate": MessageLookupByLibrary.simpleMessage(
      "High Refresh Rate",
    ),
    "highRefreshRateDesc": MessageLookupByLibrary.simpleMessage(
      "Enable highest refresh rate support",
    ),
    "hop": MessageLookupByLibrary.simpleMessage("Hop"),
    "host": MessageLookupByLibrary.simpleMessage("Host"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage(
      "Append hosts to current config",
    ),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("Hotkey Conflict"),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "Hotkey Management",
    ),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "Control app via keyboard",
    ),
    "hours": m19,
    "httpPortSniffer": MessageLookupByLibrary.simpleMessage(
      "HTTP Port Sniffing",
    ),
    "icmpForwarding": MessageLookupByLibrary.simpleMessage("ICMP Forwarding"),
    "icmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Enable ICMP Ping",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("Icon"),
    "iconConfiguration": MessageLookupByLibrary.simpleMessage(
      "Icon Configuration",
    ),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Icon Style"),
    "import": MessageLookupByLibrary.simpleMessage("Import"),
    "importFailed": MessageLookupByLibrary.simpleMessage("Import failed"),
    "importFile": MessageLookupByLibrary.simpleMessage("Import from File"),
    "importFromCode": MessageLookupByLibrary.simpleMessage("Import from Code"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "importShareLinks": MessageLookupByLibrary.simpleMessage(
      "Import share links",
    ),
    "importSuccessCount": m20,
    "importUrl": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("Never Expires"),
    "inheritDefaultDialer": MessageLookupByLibrary.simpleMessage(
      "Inherit the global default hop",
    ),
    "init": MessageLookupByLibrary.simpleMessage("Init"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "Enter a valid hotkey",
    ),
    "inputProxyTextHint": MessageLookupByLibrary.simpleMessage(
      "Paste residential IP details, e.g.\n198.51.100.1:8000:username:password\nor socks5://user:pass@198.51.100.1:8000\nSupports pasting multiple lines at once.",
    ),
    "installTime": MessageLookupByLibrary.simpleMessage("Install Time"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("Smart Select"),
    "internet": MessageLookupByLibrary.simpleMessage("Internet"),
    "interval": MessageLookupByLibrary.simpleMessage("Interval"),
    "intranetAndGateway": MessageLookupByLibrary.simpleMessage(
      "Intranet & Gateway",
    ),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Local IP"),
    "invalidIpFormat": MessageLookupByLibrary.simpleMessage(
      "Invalid IP or CIDR format",
    ),
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP Address"),
    "ipCheckCoreNotReady": MessageLookupByLibrary.simpleMessage(
      "Core is not ready",
    ),
    "ipCheckTimeout": MessageLookupByLibrary.simpleMessage(
      "No response from the node",
    ),
    "ipClickBehavior": MessageLookupByLibrary.simpleMessage("Toggle Display"),
    "ipPrivacyProtection": MessageLookupByLibrary.simpleMessage(
      "Hide IP Display",
    ),
    "ipRiskAbuse": MessageLookupByLibrary.simpleMessage("Abuse reports"),
    "ipRiskBlocklists": MessageLookupByLibrary.simpleMessage("Blocklists"),
    "ipRiskBogon": MessageLookupByLibrary.simpleMessage("Bogon"),
    "ipRiskEnable": MessageLookupByLibrary.simpleMessage("Enable lookup"),
    "ipRiskFactors": MessageLookupByLibrary.simpleMessage("Score Factors"),
    "ipRiskFailed": MessageLookupByLibrary.simpleMessage("Lookup failed"),
    "ipRiskFieldsTitle": MessageLookupByLibrary.simpleMessage(
      "Customise Fields",
    ),
    "ipRiskHosting": MessageLookupByLibrary.simpleMessage("Hosting/DC"),
    "ipRiskIntel": MessageLookupByLibrary.simpleMessage("IP Risk Intel"),
    "ipRiskLimits": MessageLookupByLibrary.simpleMessage(
      "What this data cannot tell",
    ),
    "ipRiskMobile": MessageLookupByLibrary.simpleMessage("Mobile"),
    "ipRiskNativeType": MessageLookupByLibrary.simpleMessage("Native IP"),
    "ipRiskNotFlagged": MessageLookupByLibrary.simpleMessage("Not flagged"),
    "ipRiskOpenReport": MessageLookupByLibrary.simpleMessage(
      "Open full report",
    ),
    "ipRiskPrivacyNote": MessageLookupByLibrary.simpleMessage(
      "Sends your IP to a third party (no privacy policy)",
    ),
    "ipRiskProxy": MessageLookupByLibrary.simpleMessage("Proxy"),
    "ipRiskRelay": MessageLookupByLibrary.simpleMessage("Relay"),
    "ipRiskScenarios": MessageLookupByLibrary.simpleMessage("Scenario Scores"),
    "ipRiskScore": MessageLookupByLibrary.simpleMessage("Source Purity Score"),
    "ipRiskSearchEngineBot": MessageLookupByLibrary.simpleMessage("Search bot"),
    "ipRiskStale": MessageLookupByLibrary.simpleMessage(
      "Stale — not real-time",
    ),
    "ipRiskTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipRiskUnknownNotes": MessageLookupByLibrary.simpleMessage(
      "Unknown Limits",
    ),
    "ipRiskVerdict": MessageLookupByLibrary.simpleMessage("Assessment"),
    "ipRiskVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP/CIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "Enable IPv6 traffic routing",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "Allow IPv6 inbound",
    ),
    "isp": MessageLookupByLibrary.simpleMessage("ISP"),
    "itemsCount": m21,
    "jcLabel": MessageLookupByLibrary.simpleMessage("Jc (junk packet count)"),
    "juicityPassword": MessageLookupByLibrary.simpleMessage(
      "Juicity password (fill UUID above)",
    ),
    "just": MessageLookupByLibrary.simpleMessage("Just now"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "TCP keep-alive interval",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Key"),
    "lanShareAddress": MessageLookupByLibrary.simpleMessage(
      "LAN Share Address",
    ),
    "landingProxies": MessageLookupByLibrary.simpleMessage(
      "Residential Landing Nodes",
    ),
    "landingProxyOptionCustom": MessageLookupByLibrary.simpleMessage(
      "✏️ Manually enter landing node name...",
    ),
    "landingProxyOptionNone": MessageLookupByLibrary.simpleMessage(
      "None (use subscription node as final exit)",
    ),
    "landingProxySectionDesc": MessageLookupByLibrary.simpleMessage(
      "The subscription node acts as the pre-proxy hop, and this node becomes the final exit. Useful for hiding airport IPs, chaining WARP to avoid blocking, and unlocking AI and streaming.",
    ),
    "landingProxySectionTitle": MessageLookupByLibrary.simpleMessage(
      "2. Landing proxy",
    ),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "lastEdit": MessageLookupByLibrary.simpleMessage("Last edited"),
    "layout": MessageLookupByLibrary.simpleMessage("Layout"),
    "leftClickBehavior": MessageLookupByLibrary.simpleMessage("Left Click"),
    "legacyBackup": MessageLookupByLibrary.simpleMessage("Legacy backup"),
    "light": MessageLookupByLibrary.simpleMessage("Light"),
    "limitedUnlock": MessageLookupByLibrary.simpleMessage("Originals Only"),
    "lineWrap": MessageLookupByLibrary.simpleMessage("Wrap Lines"),
    "list": MessageLookupByLibrary.simpleMessage("List"),
    "listen": MessageLookupByLibrary.simpleMessage("Listen"),
    "local": MessageLookupByLibrary.simpleMessage("Local"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Backup data locally",
    ),
    "localFile": MessageLookupByLibrary.simpleMessage("Local File"),
    "localIpLabel": MessageLookupByLibrary.simpleMessage("Local IP"),
    "localRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "Restore data from file",
    ),
    "locate": MessageLookupByLibrary.simpleMessage("Locate"),
    "log": MessageLookupByLibrary.simpleMessage("Log"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Log Level"),
    "logcat": MessageLookupByLibrary.simpleMessage("Log Capture"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Show log capture entry",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Logs"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("View captured logs"),
    "logsTest": MessageLookupByLibrary.simpleMessage("Logs Test"),
    "loopback": MessageLookupByLibrary.simpleMessage("Loopback Unlock"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "UWP loopback unlocking tool",
    ),
    "loopbackProtection": MessageLookupByLibrary.simpleMessage(
      "Loopback Protection",
    ),
    "loopbackProtectionDesc": MessageLookupByLibrary.simpleMessage(
      "Block loopback traffic from network errors",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Loose"),
    "manualAddNode": MessageLookupByLibrary.simpleMessage("Manually add node"),
    "manualEntry": MessageLookupByLibrary.simpleMessage("Manual entry"),
    "manualRefreshIp": MessageLookupByLibrary.simpleMessage("Refresh IP"),
    "maximize": MessageLookupByLibrary.simpleMessage("Maximize"),
    "mediaUnlock": MessageLookupByLibrary.simpleMessage("Connectivity Test"),
    "mediaUnlockColorfulIcons": MessageLookupByLibrary.simpleMessage(
      "Show colored icons by default",
    ),
    "mediaUnlockDetails": MessageLookupByLibrary.simpleMessage(
      "Connectivity Test Details",
    ),
    "mediaUnlockDisplaySettings": MessageLookupByLibrary.simpleMessage(
      "Display Settings",
    ),
    "mediaUnlockExtraDetails": MessageLookupByLibrary.simpleMessage(
      "Show more IP details",
    ),
    "mediaUnlockMiscSettings": MessageLookupByLibrary.simpleMessage(
      "Misc Settings",
    ),
    "mediaUnlockPinnedSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Select up to 4 items to pin on the widget",
    ),
    "mediaUnlockRefreshOnNodeChange": MessageLookupByLibrary.simpleMessage(
      "Auto refresh on node change",
    ),
    "mediaUnlockSelectLimit": MessageLookupByLibrary.simpleMessage(
      "You can select up to 4 items",
    ),
    "mediaUnlocked": MessageLookupByLibrary.simpleMessage("Unlocked"),
    "memoryAndRuntime": MessageLookupByLibrary.simpleMessage(
      "Memory & Runtime",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Memory"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage(
      "The current memory information value displayed is the dynamic stack memory usage of the core during runtime, not the complete APP memory statistics, for reference only.",
    ),
    "messageTest": MessageLookupByLibrary.simpleMessage("Message Test"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "This is a message.",
    ),
    "min": MessageLookupByLibrary.simpleMessage("Min"),
    "minimize": MessageLookupByLibrary.simpleMessage("Minimize"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("Minimize on Exit"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Override default exit behavior",
    ),
    "minutes": m22,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Mixed Port"),
    "mode": MessageLookupByLibrary.simpleMessage("Mode"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Monochrome"),
    "months": m23,
    "more": MessageLookupByLibrary.simpleMessage("More"),
    "moreIpInfo": MessageLookupByLibrary.simpleMessage("More IP Information"),
    "name": MessageLookupByLibrary.simpleMessage("Name"),
    "nameSort": MessageLookupByLibrary.simpleMessage("Sort by Name"),
    "nameserver": MessageLookupByLibrary.simpleMessage("Nameserver"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Used to resolve domains",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Nameserver Policy",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Specify domain-specific nameservers",
    ),
    "navBarHapticFeedback": MessageLookupByLibrary.simpleMessage(
      "Haptic Feedback",
    ),
    "navBarHapticFeedbackDesc": MessageLookupByLibrary.simpleMessage(
      "Vibrate on navigation tab switch",
    ),
    "navConnections": MessageLookupByLibrary.simpleMessage("Active"),
    "navTools": MessageLookupByLibrary.simpleMessage("More"),
    "network": MessageLookupByLibrary.simpleMessage("Network"),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "Modify network-related settings",
    ),
    "networkDetection": MessageLookupByLibrary.simpleMessage("Network"),
    "networkDetectionUrl": MessageLookupByLibrary.simpleMessage(
      "Network Detection URL",
    ),
    "networkErrorRetryLater": MessageLookupByLibrary.simpleMessage(
      "Network error, please try again later",
    ),
    "networkFix": MessageLookupByLibrary.simpleMessage("Network Fix"),
    "networkFixDesc": MessageLookupByLibrary.simpleMessage(
      "Fix system network globe icon issue",
    ),
    "networkInterface": MessageLookupByLibrary.simpleMessage("Interface"),
    "networkLabel": MessageLookupByLibrary.simpleMessage("Network"),
    "networkMatch": MessageLookupByLibrary.simpleMessage("Network Match"),
    "networkMatchHint": MessageLookupByLibrary.simpleMessage(
      "Enter IP, CIDR or Gateway:IP/CIDR",
    ),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Network Speed"),
    "networkSpeedNotification": MessageLookupByLibrary.simpleMessage(
      "Speed in Notification",
    ),
    "networkSpeedNotificationDesc": MessageLookupByLibrary.simpleMessage(
      "Show speed and subscription info in notification bar",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("Network Type"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("Neutral"),
    "noAnimation": MessageLookupByLibrary.simpleMessage("Default"),
    "noBackupFileFound": MessageLookupByLibrary.simpleMessage(
      "No backup file found",
    ),
    "noData": MessageLookupByLibrary.simpleMessage("No Data"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("No Hotkeys"),
    "noIcon": MessageLookupByLibrary.simpleMessage("No Icon"),
    "noInfo": MessageLookupByLibrary.simpleMessage("No Info"),
    "noInvalidProxies": MessageLookupByLibrary.simpleMessage(
      "There are no unavailable nodes right now",
    ),
    "noMoreInfoDesc": MessageLookupByLibrary.simpleMessage("No more info"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("No Network"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("No Network App"),
    "noNodesInGroup": MessageLookupByLibrary.simpleMessage(
      "No nodes in this group yet",
    ),
    "noNodesInGroupHint": MessageLookupByLibrary.simpleMessage(
      "Tap \"Manually add node\" at the bottom right or \"Batch import links\" at the top right",
    ),
    "noProfileInEffect": MessageLookupByLibrary.simpleMessage(
      "No config in effect",
    ),
    "noProxy": MessageLookupByLibrary.simpleMessage("No Proxy"),
    "noProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Please create or add a valid profile",
    ),
    "noResolve": MessageLookupByLibrary.simpleMessage("No Resolve"),
    "noStatusAvailable": MessageLookupByLibrary.simpleMessage("No Status"),
    "noUsageData": MessageLookupByLibrary.simpleMessage("No usage data"),
    "nodeAdded": m24,
    "nodeDeleted": m25,
    "nodeDetailCancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "nodeDetailClose": MessageLookupByLibrary.simpleMessage("Close"),
    "nodeDetailCopied": MessageLookupByLibrary.simpleMessage("Copied"),
    "nodeDetailCopyConfig": MessageLookupByLibrary.simpleMessage("Copy config"),
    "nodeDetailEdit": MessageLookupByLibrary.simpleMessage("Edit"),
    "nodeDetailEditTitle": m26,
    "nodeDetailMissing": MessageLookupByLibrary.simpleMessage(
      "No original config for this node - it may come from a group or have been replaced by a subscription update",
    ),
    "nodeDetailModified": MessageLookupByLibrary.simpleMessage("Modified"),
    "nodeDetailRestore": MessageLookupByLibrary.simpleMessage(
      "Restore original",
    ),
    "nodeDetailRestored": MessageLookupByLibrary.simpleMessage(
      "Restored the original config; restart the core to apply",
    ),
    "nodeDetailSave": MessageLookupByLibrary.simpleMessage("Save"),
    "nodeDetailSaved": MessageLookupByLibrary.simpleMessage(
      "Saved; restart the core to apply",
    ),
    "nodeExclusion": MessageLookupByLibrary.simpleMessage("Node Exclusion"),
    "nodeExclusionDesc": MessageLookupByLibrary.simpleMessage(
      "Exclude all matched nodes",
    ),
    "nodeExclusionPlaceholder": MessageLookupByLibrary.simpleMessage(
      "HK|Hong Kong|🇭🇰",
    ),
    "nodeManagement": m27,
    "nodeName": MessageLookupByLibrary.simpleMessage("Node Name"),
    "nodeNameHint": m28,
    "nodeNameLabel": MessageLookupByLibrary.simpleMessage("Node name"),
    "nodeProtocol": MessageLookupByLibrary.simpleMessage("Node protocol"),
    "none": MessageLookupByLibrary.simpleMessage("None"),
    "notRecommended": MessageLookupByLibrary.simpleMessage("Not Recommended"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "Current proxy group cannot be selected.",
    ),
    "notUnlocked": MessageLookupByLibrary.simpleMessage("Not Unlocked"),
    "notificationHighPriority": MessageLookupByLibrary.simpleMessage(
      "High Priority",
    ),
    "notificationHighPriorityDesc": MessageLookupByLibrary.simpleMessage(
      "Adjust current notification bar to foreground high priority",
    ),
    "notificationHighPriorityTip": MessageLookupByLibrary.simpleMessage(
      "High-priority notifications can alleviate background core keep-alive issues on some customized systems. If your VPN service is currently running normally, it is recommended to keep this option disabled. Are you sure you want to enable it?",
    ),
    "ntp": MessageLookupByLibrary.simpleMessage("NTP"),
    "ntpDesc": MessageLookupByLibrary.simpleMessage("Use NTP time service"),
    "ntpInterval": MessageLookupByLibrary.simpleMessage("Update Interval"),
    "ntpPort": MessageLookupByLibrary.simpleMessage("Port"),
    "ntpServer": MessageLookupByLibrary.simpleMessage("Server"),
    "ntpStatus": MessageLookupByLibrary.simpleMessage("Status"),
    "ntpStatusDesc": MessageLookupByLibrary.simpleMessage(
      "Enable NTP time service",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "No profile. Please add one.",
    ),
    "nullTip": m29,
    "numberTip": m30,
    "obfsModeLabel": MessageLookupByLibrary.simpleMessage("Obfs mode"),
    "obfsNoneOff": MessageLookupByLibrary.simpleMessage("None (off)"),
    "officialCommunity": MessageLookupByLibrary.simpleMessage(
      "Official community",
    ),
    "oneColumn": MessageLookupByLibrary.simpleMessage("1 Column"),
    "onlinePanel": MessageLookupByLibrary.simpleMessage("Online Panel"),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("Icon Only"),
    "onlyOtherApps": MessageLookupByLibrary.simpleMessage(
      "Third-Party Apps Only",
    ),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Proxy Traffic Only",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Only record proxy traffic",
    ),
    "openDashboard": MessageLookupByLibrary.simpleMessage("Open Zashboard"),
    "openGateway": MessageLookupByLibrary.simpleMessage("Open Gateway"),
    "openSettings": MessageLookupByLibrary.simpleMessage("Open Settings"),
    "operatorOrAsn": MessageLookupByLibrary.simpleMessage("Organization / ASN"),
    "options": MessageLookupByLibrary.simpleMessage("Options"),
    "other": MessageLookupByLibrary.simpleMessage("Other"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Other Contributors (Random Order)",
    ),
    "otherSettings": MessageLookupByLibrary.simpleMessage("Enhanced Tools"),
    "otherSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Modify enhanced tool settings",
    ),
    "outboundMode": MessageLookupByLibrary.simpleMessage("Outbound Mode"),
    "override": MessageLookupByLibrary.simpleMessage("Override"),
    "overrideDesc": MessageLookupByLibrary.simpleMessage(
      "Override proxy configurations",
    ),
    "overrideDestination": MessageLookupByLibrary.simpleMessage(
      "Override Destination",
    ),
    "overrideDestinationDesc": MessageLookupByLibrary.simpleMessage(
      "Override destination with sniffed result",
    ),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Override DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Override profile\'s DNS settings",
    ),
    "overrideExperimental": MessageLookupByLibrary.simpleMessage(
      "Override Experimental",
    ),
    "overrideExperimentalDesc": MessageLookupByLibrary.simpleMessage(
      "Override profile\'s Experimental settings",
    ),
    "overrideInvalidTip": MessageLookupByLibrary.simpleMessage(
      "Inactive in script mode",
    ),
    "overrideNtp": MessageLookupByLibrary.simpleMessage("Override NTP"),
    "overrideNtpDesc": MessageLookupByLibrary.simpleMessage(
      "Override profile\'s NTP settings",
    ),
    "overrideOriginRules": MessageLookupByLibrary.simpleMessage(
      "Override Original Rules",
    ),
    "overrideSniffer": MessageLookupByLibrary.simpleMessage("Override Sniffer"),
    "overrideSnifferDesc": MessageLookupByLibrary.simpleMessage(
      "Override profile\'s Sniffer settings",
    ),
    "overrideTestUrl": MessageLookupByLibrary.simpleMessage("Override Config"),
    "overrideTunnel": MessageLookupByLibrary.simpleMessage("Override Tunnel"),
    "overrideTunnelDesc": MessageLookupByLibrary.simpleMessage(
      "Override profile\'s Tunnel settings",
    ),
    "packageListPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "Permission denied. Cannot access app list.",
    ),
    "packageListPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Permission to access installed apps is required. Grant now?",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("Palette"),
    "parseNoValidNode": MessageLookupByLibrary.simpleMessage(
      "No valid proxy information found. Please check the format.",
    ),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("Parse Pure IP"),
    "parsePureIpDesc": MessageLookupByLibrary.simpleMessage(
      "Parse pure IP connections",
    ),
    "password": MessageLookupByLibrary.simpleMessage("Password"),
    "passwordAuth": MessageLookupByLibrary.simpleMessage("Password"),
    "passwordMismatch": MessageLookupByLibrary.simpleMessage(
      "Passwords do not match",
    ),
    "paste": MessageLookupByLibrary.simpleMessage("Paste"),
    "pasteFromClipboard": MessageLookupByLibrary.simpleMessage(
      "Paste from Clipboard",
    ),
    "peerPublicKey": MessageLookupByLibrary.simpleMessage("Peer public key"),
    "pickerLatency": MessageLookupByLibrary.simpleMessage("Latency"),
    "pickerName": MessageLookupByLibrary.simpleMessage("Name"),
    "pickerNoDelay": MessageLookupByLibrary.simpleMessage(
      "No latency yet - sorting by name until a node is tested",
    ),
    "pickerProbing": MessageLookupByLibrary.simpleMessage("Probing latency…"),
    "pickerSmart": MessageLookupByLibrary.simpleMessage("Smart"),
    "pin": MessageLookupByLibrary.simpleMessage("Pin"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Please bind WebDAV",
    ),
    "pleaseCloseSystemProxyFirst": MessageLookupByLibrary.simpleMessage(
      "Please close System Proxy first",
    ),
    "pleaseCloseTunFirst": MessageLookupByLibrary.simpleMessage(
      "Please close TUN first",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Please enter a script name",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "Please enter the admin password",
    ),
    "pleaseUploadFile": MessageLookupByLibrary.simpleMessage(
      "Please upload a file",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Please upload a valid QR code",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Port"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a different port",
    ),
    "portFallback": MessageLookupByLibrary.simpleMessage("Port Fallback"),
    "portFallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Use another port when the configured one is already taken",
    ),
    "portFallbackNotice": m31,
    "portLabel": MessageLookupByLibrary.simpleMessage("Port"),
    "portTip": m32,
    "powerSwitch": MessageLookupByLibrary.simpleMessage("Power"),
    "preProxyOptionCustom": MessageLookupByLibrary.simpleMessage(
      "✏️ Manually enter pre-proxy node name...",
    ),
    "preProxyOptionNone": MessageLookupByLibrary.simpleMessage(
      "None (connect directly to subscription node)",
    ),
    "preProxySectionDesc": MessageLookupByLibrary.simpleMessage(
      "Before traffic enters the subscription node, it first tunnels through the pre-proxy node. Useful for rescuing blocked nodes.",
    ),
    "preProxySectionTitle": MessageLookupByLibrary.simpleMessage(
      "1. Pre-proxy",
    ),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Prioritize DoH HTTP/3",
    ),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("Press a key"),
    "preventDnsLeak": MessageLookupByLibrary.simpleMessage("Prevent DNS leak"),
    "preventDnsLeakDesc": MessageLookupByLibrary.simpleMessage(
      "Keeps DNS inside the tunnel and replaces router or ISP resolvers with public DoH, so the local network never sees your domains.",
    ),
    "preventWebRtcLeak": MessageLookupByLibrary.simpleMessage(
      "Prevent WebRTC real IP leaks",
    ),
    "preventWebRtcLeakDesc": MessageLookupByLibrary.simpleMessage(
      "Blocks STUN/TURN probes to stop real public IP exposure, keeping overseas accounts and cross-border e-commerce safe",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Preview"),
    "privateIp": MessageLookupByLibrary.simpleMessage(
      "Private / LAN IP Address",
    ),
    "privateKey": MessageLookupByLibrary.simpleMessage("Private key"),
    "profile": MessageLookupByLibrary.simpleMessage("Profile"),
    "profileAndRules": MessageLookupByLibrary.simpleMessage("Profile & Rules"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("Please enter a valid interval"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("Please enter update interval"),
    "profileChainDialogTitle": m33,
    "profileChainProxies": MessageLookupByLibrary.simpleMessage(
      "Pre and landing proxies",
    ),
    "profileChainSaved": MessageLookupByLibrary.simpleMessage(
      "Pre-proxy and landing proxy settings saved",
    ),
    "profileFallbackFailed": MessageLookupByLibrary.simpleMessage(
      "The previous config could not be restored either",
    ),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "Profile modified. Disable auto-update?",
    ),
    "profileImportFailed": m34,
    "profileManageNodes": MessageLookupByLibrary.simpleMessage(
      "Manage / add nodes",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please enter a profile name",
    ),
    "profileParseErrorDesc": MessageLookupByLibrary.simpleMessage(
      "Profile parse error",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid URL",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please enter a profile URL",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Profiles"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Profile Sorting"),
    "progress": MessageLookupByLibrary.simpleMessage("Progress"),
    "project": MessageLookupByLibrary.simpleMessage("Project"),
    "protocol": MessageLookupByLibrary.simpleMessage("Proxy Protocol"),
    "providers": MessageLookupByLibrary.simpleMessage("Providers"),
    "provinceAndCity": MessageLookupByLibrary.simpleMessage("Province / City"),
    "proxies": MessageLookupByLibrary.simpleMessage("Proxies"),
    "proxiesCount": MessageLookupByLibrary.simpleMessage("Proxies"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage("Proxy Settings"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("Proxy Chains"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Proxy Group"),
    "proxyGroupsCount": MessageLookupByLibrary.simpleMessage("Proxy Groups"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("Proxy Nameserver"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Used to resolve proxy nodes",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("Proxy Port"),
    "proxyPortDesc": MessageLookupByLibrary.simpleMessage(
      "Set the Clash listening port",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Proxy Providers"),
    "proxyProvidersCount": MessageLookupByLibrary.simpleMessage(
      "Proxy Providers",
    ),
    "pskKey": MessageLookupByLibrary.simpleMessage("PSK pre-shared key"),
    "pulse": MessageLookupByLibrary.simpleMessage("Pulse"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Pure Black Mode"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR Code"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Scan QR code to get profile",
    ),
    "quicGoDisableEcn": MessageLookupByLibrary.simpleMessage(
      "Disable QUIC ECN",
    ),
    "quicGoDisableEcnDesc": MessageLookupByLibrary.simpleMessage(
      "Disable QUIC Explicit Congestion Notification",
    ),
    "quicGoDisableGso": MessageLookupByLibrary.simpleMessage(
      "Disable QUIC GSO",
    ),
    "quicGoDisableGsoDesc": MessageLookupByLibrary.simpleMessage(
      "Disable QUIC Generic Segmentation Offload",
    ),
    "quicPortSniffer": MessageLookupByLibrary.simpleMessage(
      "QUIC Port Sniffing",
    ),
    "quickImport": MessageLookupByLibrary.simpleMessage("Smart Quick Import"),
    "quickImportDesc": MessageLookupByLibrary.simpleMessage(
      "One-click import from IP:port:user:password, links and other common formats",
    ),
    "quickResponse": MessageLookupByLibrary.simpleMessage("Quick Response"),
    "quickResponseDesc": MessageLookupByLibrary.simpleMessage(
      "Disconnect on network change (WiFi/Mobile)",
    ),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("Rainbow"),
    "realTimeSpeed": MessageLookupByLibrary.simpleMessage("Real-time Speed"),
    "realityPublicKey": MessageLookupByLibrary.simpleMessage(
      "REALITY public key",
    ),
    "reclaimableMemory": MessageLookupByLibrary.simpleMessage("Reclaimable"),
    "recovery": MessageLookupByLibrary.simpleMessage("Restore"),
    "recoveryAll": MessageLookupByLibrary.simpleMessage("Restore All Data"),
    "recoveryProfiles": MessageLookupByLibrary.simpleMessage(
      "Restore Profiles Only",
    ),
    "recoveryStrategy": MessageLookupByLibrary.simpleMessage(
      "Recovery Strategy",
    ),
    "recoveryStrategy_compatible": MessageLookupByLibrary.simpleMessage(
      "Compatible",
    ),
    "recoveryStrategy_override": MessageLookupByLibrary.simpleMessage(
      "Override",
    ),
    "recoverySuccess": MessageLookupByLibrary.simpleMessage(
      "Restore Successful",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir Port"),
    "redo": MessageLookupByLibrary.simpleMessage("Redo"),
    "refresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "refreshAppList": MessageLookupByLibrary.simpleMessage("Refresh App List"),
    "refreshAppListConfirm": MessageLookupByLibrary.simpleMessage(
      "Refresh the app list?",
    ),
    "regExp": MessageLookupByLibrary.simpleMessage("RegExp"),
    "remote": MessageLookupByLibrary.simpleMessage("Remote"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Backup data to WebDAV",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "Remote Destination",
    ),
    "remoteRecoveryDesc": MessageLookupByLibrary.simpleMessage(
      "Restore data from WebDAV",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Remove"),
    "rename": MessageLookupByLibrary.simpleMessage("Rename"),
    "replace": MessageLookupByLibrary.simpleMessage("Replace"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("Replace All"),
    "request": MessageLookupByLibrary.simpleMessage("Request"),
    "requests": MessageLookupByLibrary.simpleMessage("Requests"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage(
      "View recent request logs",
    ),
    "reset": MessageLookupByLibrary.simpleMessage("Reset"),
    "resetIconCache": MessageLookupByLibrary.simpleMessage("Reset Icon Cache"),
    "resetIconCacheDesc": MessageLookupByLibrary.simpleMessage(
      "Reset the local icon cache? This is safe, the app will fetch icons from their remote links again automatically.",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to reset?",
    ),
    "residentialIpCheck": MessageLookupByLibrary.simpleMessage(
      "Residential IP check",
    ),
    "residentialIpCheckDesc": MessageLookupByLibrary.simpleMessage(
      "Verifies the landing proxy credentials and the real exit IP.",
    ),
    "residentialIpCheckDirect": MessageLookupByLibrary.simpleMessage("Direct"),
    "residentialIpCheckStart": MessageLookupByLibrary.simpleMessage(
      "Run check",
    ),
    "residentialIpCheckViaChain": MessageLookupByLibrary.simpleMessage(
      "Via chain",
    ),
    "residentialIpChecking": MessageLookupByLibrary.simpleMessage("Checking…"),
    "resources": MessageLookupByLibrary.simpleMessage("Resources"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage(
      "External resource info",
    ),
    "respectRules": MessageLookupByLibrary.simpleMessage("Respect Rules"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS connections follow Rules",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("Restart"),
    "restartApp": MessageLookupByLibrary.simpleMessage("Restart App"),
    "restartCore": MessageLookupByLibrary.simpleMessage("Restart core"),
    "restartCoreDesc": MessageLookupByLibrary.simpleMessage(
      "Manually restart the core?",
    ),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Restart the core? Active connections will briefly drop.",
    ),
    "restartCoreTitle": MessageLookupByLibrary.simpleMessage("Restart Core"),
    "restartTip": MessageLookupByLibrary.simpleMessage(
      "Restart TUN for changes to take effect",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Restore"),
    "retest": MessageLookupByLibrary.simpleMessage("Check again"),
    "retry": MessageLookupByLibrary.simpleMessage("Retry"),
    "rightClickBehavior": MessageLookupByLibrary.simpleMessage("Right Click"),
    "roleEntry": MessageLookupByLibrary.simpleMessage("Entry node"),
    "roleExit": MessageLookupByLibrary.simpleMessage("Landing exit"),
    "roleRelay": MessageLookupByLibrary.simpleMessage("Relay node"),
    "rotatingCircle": MessageLookupByLibrary.simpleMessage("Rotating Circle"),
    "rule": MessageLookupByLibrary.simpleMessage("Rule"),
    "ruleName": MessageLookupByLibrary.simpleMessage("Rule Name"),
    "ruleProviderWarningsTitle": MessageLookupByLibrary.simpleMessage(
      "Some rule-sets were not loaded",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Rule Providers"),
    "ruleProvidersCount": MessageLookupByLibrary.simpleMessage(
      "Rule Providers",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Rule Target"),
    "rulesCount": MessageLookupByLibrary.simpleMessage("Rules"),
    "runTime": MessageLookupByLibrary.simpleMessage("Uptime"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage("Runtime Config"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "saveAndApply": MessageLookupByLibrary.simpleMessage("Save and apply"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("Save changes?"),
    "saveNode": MessageLookupByLibrary.simpleMessage("Save node"),
    "saveTip": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to save?",
    ),
    "scenarioAi": MessageLookupByLibrary.simpleMessage("AI Services"),
    "scenarioEcommerce": MessageLookupByLibrary.simpleMessage("E-commerce"),
    "scenarioEmail": MessageLookupByLibrary.simpleMessage("Email"),
    "scenarioGaming": MessageLookupByLibrary.simpleMessage("Gaming"),
    "scenarioSocial": MessageLookupByLibrary.simpleMessage("Social Sign-up"),
    "scenarioStreaming": MessageLookupByLibrary.simpleMessage("Streaming"),
    "script": MessageLookupByLibrary.simpleMessage("Script"),
    "scriptDesc": MessageLookupByLibrary.simpleMessage(
      "Global override script config",
    ),
    "scriptUrlNotAScript": MessageLookupByLibrary.simpleMessage(
      "This link returned a web page, not a script file. On GitHub, use the Raw link.",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Search"),
    "seconds": MessageLookupByLibrary.simpleMessage("Seconds"),
    "secretCopied": MessageLookupByLibrary.simpleMessage(
      "Secret copied to clipboard",
    ),
    "securityLabel": MessageLookupByLibrary.simpleMessage("Security/TLS"),
    "securityNonePlain": MessageLookupByLibrary.simpleMessage(
      "None (plaintext)",
    ),
    "selectAll": MessageLookupByLibrary.simpleMessage("Select All"),
    "selectBackupVersion": MessageLookupByLibrary.simpleMessage(
      "Select Backup Version",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("Selected"),
    "selectedCountTitle": m35,
    "serverAddress": MessageLookupByLibrary.simpleMessage("Server Address"),
    "serverAddressHint": MessageLookupByLibrary.simpleMessage("IP or domain"),
    "serverAddressLabel": MessageLookupByLibrary.simpleMessage(
      "Server address",
    ),
    "serverAddressRequired": MessageLookupByLibrary.simpleMessage(
      "Please enter the server address",
    ),
    "serviceReady": MessageLookupByLibrary.simpleMessage("Service Ready"),
    "serviceRunning": MessageLookupByLibrary.simpleMessage("Service Running"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "show": MessageLookupByLibrary.simpleMessage("Show"),
    "showHiddenItems": MessageLookupByLibrary.simpleMessage(
      "Show Hidden Items",
    ),
    "showMenu": MessageLookupByLibrary.simpleMessage("Open Menu"),
    "showPanel": MessageLookupByLibrary.simpleMessage("Show Window"),
    "showStartSwitch": MessageLookupByLibrary.simpleMessage("Linkage Switch"),
    "showStartSwitchDesc": MessageLookupByLibrary.simpleMessage(
      "Display independent switch button on the homepage",
    ),
    "shrink": MessageLookupByLibrary.simpleMessage("Compact"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Silent Launch"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Start in the background",
    ),
    "size": MessageLookupByLibrary.simpleMessage("Size"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage(
      "Skip certificate verification",
    ),
    "skipCertVerifyDesc": MessageLookupByLibrary.simpleMessage(
      "Fixes self-signed certificate or TLS handshake errors",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage("Skip Domain"),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage(
      "Skip Destination IP",
    ),
    "skipLocalAuth": MessageLookupByLibrary.simpleMessage(
      "Skip Local Authentication",
    ),
    "skipLocalAuthDesc": MessageLookupByLibrary.simpleMessage(
      "Allow local machine to access proxy without credentials",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage("Skip Source IP"),
    "smartAutoStop": MessageLookupByLibrary.simpleMessage("Smart Auto-Stop"),
    "smartAutoStopDesc": MessageLookupByLibrary.simpleMessage(
      "Stop VPN on specific networks",
    ),
    "smartAutoStopServiceRunning": MessageLookupByLibrary.simpleMessage(
      "Smart Auto-Stop running",
    ),
    "smartCheckFailed": m36,
    "smartCheckNow": MessageLookupByLibrary.simpleMessage("Check now"),
    "smartChecking": MessageLookupByLibrary.simpleMessage("Checking…"),
    "smartDelayLaunch": MessageLookupByLibrary.simpleMessage("Smart Delay"),
    "smartDelayLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Launch after network connected",
    ),
    "smartNeedCurrent": MessageLookupByLibrary.simpleMessage(
      "Set this node as the current route before checking",
    ),
    "smartNoData": MessageLookupByLibrary.simpleMessage("No data"),
    "smartNoScore": MessageLookupByLibrary.simpleMessage("No score"),
    "smartRecheck": MessageLookupByLibrary.simpleMessage("Check again"),
    "smartSetAsCurrent": MessageLookupByLibrary.simpleMessage(
      "Set as current route, then check",
    ),
    "smartSuspect": MessageLookupByLibrary.simpleMessage(
      "Possibly unavailable",
    ),
    "snellVersion": MessageLookupByLibrary.simpleMessage("Snell version (1-4)"),
    "sniHint": MessageLookupByLibrary.simpleMessage(
      "Leave blank to default to the server address",
    ),
    "sniLabel": MessageLookupByLibrary.simpleMessage(
      "SNI (ServerName / camouflage domain)",
    ),
    "sniffer": MessageLookupByLibrary.simpleMessage("Sniffer"),
    "snifferAddressHint": MessageLookupByLibrary.simpleMessage(
      "One address per line",
    ),
    "snifferDesc": MessageLookupByLibrary.simpleMessage(
      "Modify domain sniffer config",
    ),
    "snifferDomainHint": MessageLookupByLibrary.simpleMessage(
      "One domain per line",
    ),
    "snifferPorts": MessageLookupByLibrary.simpleMessage("Ports"),
    "snifferPortsHint": MessageLookupByLibrary.simpleMessage(
      "e.g.: 80, 8080-8880",
    ),
    "snifferStatus": MessageLookupByLibrary.simpleMessage("Status"),
    "snifferStatusDesc": MessageLookupByLibrary.simpleMessage(
      "Enable Sniffer service",
    ),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks Port"),
    "sort": MessageLookupByLibrary.simpleMessage("Sort"),
    "source": MessageLookupByLibrary.simpleMessage("Source"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("Source IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Special Proxy"),
    "specialRules": MessageLookupByLibrary.simpleMessage("Special Rules"),
    "specificDialerProxy": MessageLookupByLibrary.simpleMessage(
      "Specify a dedicated hop",
    ),
    "spinningLines": MessageLookupByLibrary.simpleMessage("Spinning Lines"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Stack Mode"),
    "standard": MessageLookupByLibrary.simpleMessage("Standard"),
    "start": MessageLookupByLibrary.simpleMessage("Start"),
    "startTest": MessageLookupByLibrary.simpleMessage("Delay Test"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Starting..."),
    "status": MessageLookupByLibrary.simpleMessage("Status"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "Uses system DNS when disabled",
    ),
    "stillUsingProfile": m37,
    "stop": MessageLookupByLibrary.simpleMessage("Stop"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Stopping..."),
    "storeFix": MessageLookupByLibrary.simpleMessage("Store Fix"),
    "storeFixDesc": MessageLookupByLibrary.simpleMessage(
      "Fix Play Store download issues",
    ),
    "strictRoute": MessageLookupByLibrary.simpleMessage("Strict Route"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "Use TUN strict routing mode",
    ),
    "style": MessageLookupByLibrary.simpleMessage("Style"),
    "subRule": MessageLookupByLibrary.simpleMessage("Sub Rule"),
    "submit": MessageLookupByLibrary.simpleMessage("Submit"),
    "success": MessageLookupByLibrary.simpleMessage("Success"),
    "switchLabel": MessageLookupByLibrary.simpleMessage("Switch"),
    "switchProfileFailed": MessageLookupByLibrary.simpleMessage(
      "Switch Subscription Failed",
    ),
    "switchProxy": MessageLookupByLibrary.simpleMessage("Switch"),
    "switchToDomesticIp": MessageLookupByLibrary.simpleMessage(
      "Get Domestic IP",
    ),
    "sync": MessageLookupByLibrary.simpleMessage("Sync"),
    "syncAll": MessageLookupByLibrary.simpleMessage("Sync All"),
    "syncDelayAnimation": MessageLookupByLibrary.simpleMessage(
      "Sync animation to other pages",
    ),
    "syncFailed": MessageLookupByLibrary.simpleMessage("Sync Failed"),
    "system": MessageLookupByLibrary.simpleMessage("System"),
    "systemApp": MessageLookupByLibrary.simpleMessage("System App"),
    "systemDns": MessageLookupByLibrary.simpleMessage("System DNS"),
    "systemFont": MessageLookupByLibrary.simpleMessage("System Font"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("System Proxy"),
    "systemProxyActualOff": MessageLookupByLibrary.simpleMessage(
      "The system proxy is actually off",
    ),
    "systemProxyActualOn": MessageLookupByLibrary.simpleMessage(
      "The system proxy is actually on",
    ),
    "systemProxyActualStatus": MessageLookupByLibrary.simpleMessage(
      "Actual system status",
    ),
    "systemProxyChecking": MessageLookupByLibrary.simpleMessage(
      "Checking the actual system status…",
    ),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage("Set system proxy"),
    "systemProxyMismatchOff": MessageLookupByLibrary.simpleMessage(
      "The system proxy is still on",
    ),
    "systemProxyMismatchOn": MessageLookupByLibrary.simpleMessage(
      "The setting requests the proxy on, but the system proxy is not actually on",
    ),
    "systemProxyUnknown": MessageLookupByLibrary.simpleMessage(
      "Cannot determine the system proxy status",
    ),
    "systemProxyUnsupported": MessageLookupByLibrary.simpleMessage(
      "This platform does not support system proxy status detection",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Tab"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP Concurrent"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Allow concurrent TCP connections",
    ),
    "telegramChannel": MessageLookupByLibrary.simpleMessage("Telegram channel"),
    "telegramGroup": MessageLookupByLibrary.simpleMessage("Telegram group"),
    "testAll": MessageLookupByLibrary.simpleMessage("Test All"),
    "testCurrentProxy": MessageLookupByLibrary.simpleMessage(
      "Test connectivity",
    ),
    "testUrl": MessageLookupByLibrary.simpleMessage("Test URL"),
    "testing": MessageLookupByLibrary.simpleMessage("Testing"),
    "testingHealth": MessageLookupByLibrary.simpleMessage("Checking…"),
    "textScale": MessageLookupByLibrary.simpleMessage("Text Scaling"),
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Theme Color"),
    "themeDesc": MessageLookupByLibrary.simpleMessage(
      "Set theme color and icon",
    ),
    "themeMode": MessageLookupByLibrary.simpleMessage("Theme Mode"),
    "threeBounce": MessageLookupByLibrary.simpleMessage("Three Bounce"),
    "threeColumns": MessageLookupByLibrary.simpleMessage("3 Columns"),
    "threeInOut": MessageLookupByLibrary.simpleMessage("Three In Out"),
    "tight": MessageLookupByLibrary.simpleMessage("Compact"),
    "time": MessageLookupByLibrary.simpleMessage("Time"),
    "timeoutLabel": MessageLookupByLibrary.simpleMessage("Timeout"),
    "tip": MessageLookupByLibrary.simpleMessage("Tip"),
    "titleColor": MessageLookupByLibrary.simpleMessage("Title colour"),
    "titleTooLong": MessageLookupByLibrary.simpleMessage(
      "Title is too long, maximum 20 characters supported",
    ),
    "tlsPortSniffer": MessageLookupByLibrary.simpleMessage("TLS Port Sniffing"),
    "toggle": MessageLookupByLibrary.simpleMessage("Toggle"),
    "tolerateRuleProviderErrors": MessageLookupByLibrary.simpleMessage(
      "Ignore rule-set load failures",
    ),
    "tolerateRuleProviderErrorsDesc": MessageLookupByLibrary.simpleMessage(
      "Apply the config even if some rule-sets failed to download. When off, any rule-set failure rejects the whole config",
    ),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("Tonal Spot"),
    "tooManyRules": MessageLookupByLibrary.simpleMessage("Max 5 rules allowed"),
    "tools": MessageLookupByLibrary.simpleMessage("Tools"),
    "topologyClient": MessageLookupByLibrary.simpleMessage("This device"),
    "topologyHop": MessageLookupByLibrary.simpleMessage("Entry hop"),
    "topologyLanding": MessageLookupByLibrary.simpleMessage(
      "Residential landing",
    ),
    "topologyRelay": MessageLookupByLibrary.simpleMessage("Relay node"),
    "topologyTarget": MessageLookupByLibrary.simpleMessage("Target service"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("Total Traffic"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxy Port"),
    "trafficSinceStart": MessageLookupByLibrary.simpleMessage(
      "Since this session started",
    ),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Traffic Usage"),
    "trayClickBehavior": MessageLookupByLibrary.simpleMessage(
      "Tray Click Behavior",
    ),
    "trayEnhancement": MessageLookupByLibrary.simpleMessage("Tray Enhancement"),
    "trayEnhancementDesc": MessageLookupByLibrary.simpleMessage(
      "Control proxy groups in system tray menu",
    ),
    "trayIconInvert": MessageLookupByLibrary.simpleMessage("Invert Tray Icon"),
    "trayIconInvertDesc": MessageLookupByLibrary.simpleMessage(
      "Invert the current tray icon color",
    ),
    "tryManualRefresh": MessageLookupByLibrary.simpleMessage(
      "Please try manual refresh",
    ),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunActualOff": MessageLookupByLibrary.simpleMessage(
      "The system TUN is actually disabled",
    ),
    "tunActualOn": MessageLookupByLibrary.simpleMessage(
      "The system TUN is actually enabled",
    ),
    "tunActualStatus": MessageLookupByLibrary.simpleMessage(
      "Actual TUN status",
    ),
    "tunChecking": MessageLookupByLibrary.simpleMessage(
      "Checking the actual TUN status…",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "Use TUN to take over device traffic",
    ),
    "tunEnableRequireAdmin": MessageLookupByLibrary.simpleMessage(
      "Enabling the TUN virtual network adapter requires Administrator or ROOT privileges.",
    ),
    "tunMismatchOff": MessageLookupByLibrary.simpleMessage(
      "TUN is still enabled",
    ),
    "tunMismatchOn": MessageLookupByLibrary.simpleMessage(
      "The setting requests TUN on, but the system TUN is not actually enabled",
    ),
    "tunUnknown": MessageLookupByLibrary.simpleMessage(
      "Cannot determine the actual TUN status",
    ),
    "tunUnsupported": MessageLookupByLibrary.simpleMessage(
      "This platform does not report the actual TUN status",
    ),
    "tunVirtualAddress": MessageLookupByLibrary.simpleMessage(
      "TUN Virtual Network Adapter",
    ),
    "tunnel": MessageLookupByLibrary.simpleMessage("Tunnel"),
    "tunnelAddress": MessageLookupByLibrary.simpleMessage("Listen Address"),
    "tunnelAddressHint": MessageLookupByLibrary.simpleMessage(
      "e.g.: 127.0.0.1:6553",
    ),
    "tunnelDesc": MessageLookupByLibrary.simpleMessage(
      "Use traffic forwarding tunnel",
    ),
    "tunnelList": MessageLookupByLibrary.simpleMessage("Forwarding List"),
    "tunnelNetwork": MessageLookupByLibrary.simpleMessage("Network Protocol"),
    "tunnelNetworkHint": MessageLookupByLibrary.simpleMessage("e.g.: tcp, udp"),
    "tunnelProxy": MessageLookupByLibrary.simpleMessage("Proxy Name"),
    "tunnelProxyHint": MessageLookupByLibrary.simpleMessage(
      "e.g.: proxy (optional)",
    ),
    "tunnelTarget": MessageLookupByLibrary.simpleMessage("Target Address"),
    "tunnelTargetHint": MessageLookupByLibrary.simpleMessage(
      "e.g.: 114.114.114.114:53",
    ),
    "tvConfigName": MessageLookupByLibrary.simpleMessage(
      "Config name (optional)",
    ),
    "tvLocalFile": MessageLookupByLibrary.simpleMessage("Local config file"),
    "tvNameHint": MessageLookupByLibrary.simpleMessage(
      "Left empty, it is detected automatically",
    ),
    "tvNeedUrl": MessageLookupByLibrary.simpleMessage(
      "Enter the subscription link first",
    ),
    "tvPickFile": MessageLookupByLibrary.simpleMessage(
      "Choose a .yaml / .yml config",
    ),
    "tvPushConfig": MessageLookupByLibrary.simpleMessage("🚀 Send config file"),
    "tvPushConnectFailed": MessageLookupByLibrary.simpleMessage(
      "❌ Failed - cannot reach the TV:",
    ),
    "tvPushDoneAuto": MessageLookupByLibrary.simpleMessage(
      "✅ Sent to the TV. It is importing the config now…",
    ),
    "tvPushDoneFile": MessageLookupByLibrary.simpleMessage(
      "✅ Config file sent to the TV",
    ),
    "tvPushFailed": MessageLookupByLibrary.simpleMessage("❌ Failed:"),
    "tvPushTitle": MessageLookupByLibrary.simpleMessage("Fluxora config push"),
    "tvPushToTv": MessageLookupByLibrary.simpleMessage("🚀 Send to TV"),
    "tvPushing": MessageLookupByLibrary.simpleMessage("Sending…"),
    "tvReadFailed": MessageLookupByLibrary.simpleMessage(
      "❌ Could not read the file",
    ),
    "tvReadingPushing": MessageLookupByLibrary.simpleMessage(
      "Reading and sending…",
    ),
    "tvScanManualUrl": MessageLookupByLibrary.simpleMessage(
      "Or enter directly in phone browser:",
    ),
    "tvScanNoNetwork": MessageLookupByLibrary.simpleMessage(
      "No available LAN detected, please check Wi-Fi",
    ),
    "tvScanStep1": MessageLookupByLibrary.simpleMessage(
      "Ensure phone and TV are on the same Wi-Fi network",
    ),
    "tvScanStep2": MessageLookupByLibrary.simpleMessage(
      "Scan the QR code with a supported camera or browser",
    ),
    "tvScanStep3": MessageLookupByLibrary.simpleMessage(
      "Paste subscription URL or upload profile on the webpage and push",
    ),
    "tvScanSuccess": MessageLookupByLibrary.simpleMessage(
      "Profile received, importing...",
    ),
    "tvScanWaiting": MessageLookupByLibrary.simpleMessage(
      "Waiting for profile from phone...",
    ),
    "tvSubscriptionUrl": MessageLookupByLibrary.simpleMessage(
      "Subscription link",
    ),
    "tvSubscriptionUrlLabel": MessageLookupByLibrary.simpleMessage(
      "Subscription link (URL)",
    ),
    "tvUrlHint": MessageLookupByLibrary.simpleMessage(
      "Paste a Clash Meta subscription link (https://…)",
    ),
    "twoColumns": MessageLookupByLibrary.simpleMessage("2 Columns"),
    "udpForwarding": MessageLookupByLibrary.simpleMessage("UDP Forwarding"),
    "udpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Turn this off if the residential IP does not support UDP and causes errors",
    ),
    "unableToUpdateCurrentProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Unable to update current profile",
    ),
    "unauthorized": MessageLookupByLibrary.simpleMessage("Unauthorized"),
    "undo": MessageLookupByLibrary.simpleMessage("Undo"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Unified Delay"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Exclude handshake delays from testing",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("Unknown"),
    "unlocked": MessageLookupByLibrary.simpleMessage("Completed"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Unnamed"),
    "unnamedNode": MessageLookupByLibrary.simpleMessage("Unnamed node"),
    "unpin": MessageLookupByLibrary.simpleMessage("Unpin"),
    "upLabel": MessageLookupByLibrary.simpleMessage("Up"),
    "update": MessageLookupByLibrary.simpleMessage("Update"),
    "updateTime": MessageLookupByLibrary.simpleMessage("Update Time"),
    "upload": MessageLookupByLibrary.simpleMessage("Upload"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("Get profile via URL"),
    "urlTip": m38,
    "useGlobalScriptOverride": MessageLookupByLibrary.simpleMessage(
      "Use Global Script Override",
    ),
    "useHosts": MessageLookupByLibrary.simpleMessage("Use Hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("Use System Hosts"),
    "userAuth": MessageLookupByLibrary.simpleMessage("User Authentication"),
    "username": MessageLookupByLibrary.simpleMessage("Username"),
    "usernameCannotContainColon": MessageLookupByLibrary.simpleMessage(
      "Username cannot contain colons",
    ),
    "usernameOptional": MessageLookupByLibrary.simpleMessage(
      "Username (optional)",
    ),
    "value": MessageLookupByLibrary.simpleMessage("Value"),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("Vibrant"),
    "view": MessageLookupByLibrary.simpleMessage("View"),
    "viewDetailedIpData": MessageLookupByLibrary.simpleMessage(
      "View Detailed IP Data",
    ),
    "vpnDesc": MessageLookupByLibrary.simpleMessage("VPN-related settings"),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "Route system traffic via VpnService",
    ),
    "vpnSystemProxyConfirmDesc": MessageLookupByLibrary.simpleMessage(
      "HTTP proxy is generally not recommended on non-desktop platforms. Only enable this feature when necessary and you fully understand the implications.",
    ),
    "vpnSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Attach HTTP proxy to VpnService",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage(
      "Restart VPN to apply changes",
    ),
    "wakelock": MessageLookupByLibrary.simpleMessage("Wakelock"),
    "wakelockDescription": MessageLookupByLibrary.simpleMessage(
      "Keeps the screen on and app active in the background without requiring special CPU wakelock permissions.",
    ),
    "warpCopied": m39,
    "warpDiagOk": m40,
    "warpDialerSet": m41,
    "warpEdgeNode": m42,
    "warpFastestChosen": m43,
    "warpIpChosen": m44,
    "warpModeAll": MessageLookupByLibrary.simpleMessage(
      "Route everything through WARP",
    ),
    "warpModeAllDesc": MessageLookupByLibrary.simpleMessage(
      "All proxy traffic is encapsulated through WARP, hiding the provider\'s real exit IP",
    ),
    "warpModeCustom": MessageLookupByLibrary.simpleMessage(
      "Custom rule-based routing",
    ),
    "warpModeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "Decides per rule whether traffic goes out through WARP",
    ),
    "warpModeSmart": MessageLookupByLibrary.simpleMessage(
      "Smart: AI unlock (recommended)",
    ),
    "warpModeSmartDesc": MessageLookupByLibrary.simpleMessage(
      "Routes Google, OpenAI, Claude and Gemini through WARP; everything else keeps the provider\'s native speed",
    ),
    "warpModeTitle": MessageLookupByLibrary.simpleMessage("Routing mode"),
    "warpNoSignature": m45,
    "warpRegion": m46,
    "warpRouteProxyOverWarp": MessageLookupByLibrary.simpleMessage(
      "Route the proxy through WARP",
    ),
    "warpRouteProxyOverWarpDesc": MessageLookupByLibrary.simpleMessage(
      "Route the proxy through WARP (WARP as the dialer that reaches blocked nodes)",
    ),
    "warpRouteWarpOverProxy": MessageLookupByLibrary.simpleMessage(
      "Route WARP through the proxy",
    ),
    "warpRouteWarpOverProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Route WARP through the proxy (recommended: provider plus WARP exit, avoids region leaks and unlocks streaming and AI)",
    ),
    "warpStr0": MessageLookupByLibrary.simpleMessage("0 (default 2408)"),
    "warpStr1": MessageLookupByLibrary.simpleMessage(
      "1280 (recommended, best for UDP)",
    ),
    "warpStr10": MessageLookupByLibrary.simpleMessage(
      "MTU set to 1420 (standard)",
    ),
    "warpStr100": MessageLookupByLibrary.simpleMessage(
      "Route the proxy through WARP",
    ),
    "warpStr101": MessageLookupByLibrary.simpleMessage(
      "Route WARP through the proxy",
    ),
    "warpStr102": MessageLookupByLibrary.simpleMessage("Regenerate keys"),
    "warpStr103": MessageLookupByLibrary.simpleMessage("Reset"),
    "warpStr104": MessageLookupByLibrary.simpleMessage("Reset to defaults"),
    "warpStr105": MessageLookupByLibrary.simpleMessage(
      "🎉 WARP+ license activated",
    ),
    "warpStr106": MessageLookupByLibrary.simpleMessage(
      "🎉 Device and keys generated",
    ),
    "warpStr107": MessageLookupByLibrary.simpleMessage("👑 WARP+ device"),
    "warpStr108": MessageLookupByLibrary.simpleMessage(
      "💡 When to use each mode",
    ),
    "warpStr109": MessageLookupByLibrary.simpleMessage(
      "🛡️ Native search (excellent)",
    ),
    "warpStr11": MessageLookupByLibrary.simpleMessage(
      "WARP credentials and details",
    ),
    "warpStr110": MessageLookupByLibrary.simpleMessage(
      "🟢 Official free device",
    ),
    "warpStr111": MessageLookupByLibrary.simpleMessage("🟢 Unrestricted"),
    "warpStr12": MessageLookupByLibrary.simpleMessage(
      "WARP reset to its default configuration",
    ),
    "warpStr13": MessageLookupByLibrary.simpleMessage("WARP routing mode"),
    "warpStr14": MessageLookupByLibrary.simpleMessage(
      "WARP+ activation (warp=plus)",
    ),
    "warpStr15": MessageLookupByLibrary.simpleMessage("WireGuard keys"),
    "warpStr16": MessageLookupByLibrary.simpleMessage("auto (default)"),
    "warpStr17": MessageLookupByLibrary.simpleMessage(
      "auto, or e.g. 162.159.193.1",
    ),
    "warpStr18": MessageLookupByLibrary.simpleMessage(
      "⚠️ Region may be exposed",
    ),
    "warpStr19": MessageLookupByLibrary.simpleMessage("⚡ Check WARP status"),
    "warpStr2": MessageLookupByLibrary.simpleMessage("1360 (balanced)"),
    "warpStr20": MessageLookupByLibrary.simpleMessage(
      "⚡ Follow main selector (recommended)",
    ),
    "warpStr21": MessageLookupByLibrary.simpleMessage(
      "⚡ Follow main selector (uses the active provider node)",
    ),
    "warpStr22": MessageLookupByLibrary.simpleMessage("⚪ Local key pair"),
    "warpStr23": MessageLookupByLibrary.simpleMessage("✈️ WARP dialer"),
    "warpStr24": MessageLookupByLibrary.simpleMessage("Optimize"),
    "warpStr25": MessageLookupByLibrary.simpleMessage(
      "Generate an X25519 key pair and register with Cloudflare",
    ),
    "warpStr26": MessageLookupByLibrary.simpleMessage("Run diagnostics"),
    "warpStr27": MessageLookupByLibrary.simpleMessage(
      "Same view as the switch card, with live latency",
    ),
    "warpStr28": MessageLookupByLibrary.simpleMessage("Choose from node list…"),
    "warpStr29": MessageLookupByLibrary.simpleMessage("Preferred IP"),
    "warpStr3": MessageLookupByLibrary.simpleMessage("1420 (standard)"),
    "warpStr30": MessageLookupByLibrary.simpleMessage(
      "Preferred IP / hostname",
    ),
    "warpStr31": MessageLookupByLibrary.simpleMessage("Preferred IP saved"),
    "warpStr32": MessageLookupByLibrary.simpleMessage(
      "Preferred IP reset to auto",
    ),
    "warpStr33": MessageLookupByLibrary.simpleMessage("Preferred IP scan"),
    "warpStr34": MessageLookupByLibrary.simpleMessage(
      "The preferred IP is the entry address; it affects speed and stability.",
    ),
    "warpStr35": MessageLookupByLibrary.simpleMessage("How it works"),
    "warpStr36": MessageLookupByLibrary.simpleMessage("Use the fastest"),
    "warpStr37": MessageLookupByLibrary.simpleMessage("Save"),
    "warpStr38": MessageLookupByLibrary.simpleMessage("Close"),
    "warpStr39": MessageLookupByLibrary.simpleMessage(
      "The exit IP is chosen by Cloudflare\'s nearest routing and does not change.",
    ),
    "warpStr4": MessageLookupByLibrary.simpleMessage("AI and streaming unlock"),
    "warpStr40": MessageLookupByLibrary.simpleMessage("Real exit IP"),
    "warpStr41": MessageLookupByLibrary.simpleMessage("Dialer proxy"),
    "warpStr42": MessageLookupByLibrary.simpleMessage("Cancel"),
    "warpStr43": MessageLookupByLibrary.simpleMessage("Enable WARP"),
    "warpStr44": MessageLookupByLibrary.simpleMessage("Client public key"),
    "warpStr45": MessageLookupByLibrary.simpleMessage("Client private key"),
    "warpStr46": MessageLookupByLibrary.simpleMessage("Client reserved bytes"),
    "warpStr47": MessageLookupByLibrary.simpleMessage(
      "No rules yet - with no rules nothing is routed in this mode",
    ),
    "warpStr48": MessageLookupByLibrary.simpleMessage("Not verified yet"),
    "warpStr49": MessageLookupByLibrary.simpleMessage(
      "Key saved; it applies on the next handshake or registration",
    ),
    "warpStr5": MessageLookupByLibrary.simpleMessage(
      "Cloudflare peer public key",
    ),
    "warpStr50": MessageLookupByLibrary.simpleMessage("WARP disabled"),
    "warpStr51": MessageLookupByLibrary.simpleMessage(
      "Cloudflare WARP enabled",
    ),
    "warpStr52": MessageLookupByLibrary.simpleMessage("WARP enabled"),
    "warpStr53": MessageLookupByLibrary.simpleMessage("License key cleared"),
    "warpStr54": MessageLookupByLibrary.simpleMessage(
      "Set to follow the main selector",
    ),
    "warpStr55": MessageLookupByLibrary.simpleMessage(
      "Curve25519 key pair regenerated",
    ),
    "warpStr56": MessageLookupByLibrary.simpleMessage(
      "Reset to the default: route WARP through the proxy",
    ),
    "warpStr57": MessageLookupByLibrary.simpleMessage(
      "Mode: route the proxy through WARP. Every provider node is chained through the WARP tunnel, which rescues nodes blocked by the GFW. No dialer needs to be chosen.",
    ),
    "warpStr58": MessageLookupByLibrary.simpleMessage("Not checked"),
    "warpStr59": MessageLookupByLibrary.simpleMessage(
      "For the cleanest result, turn the proxy off before scanning.",
    ),
    "warpStr6": MessageLookupByLibrary.simpleMessage(
      "DIRECT (connect to Cloudflare directly)",
    ),
    "warpStr60": MessageLookupByLibrary.simpleMessage(
      "Note: latency measured with the proxy on includes tunnel overhead.",
    ),
    "warpStr61": MessageLookupByLibrary.simpleMessage("Not enabled"),
    "warpStr62": MessageLookupByLibrary.simpleMessage("Not set"),
    "warpStr63": MessageLookupByLibrary.simpleMessage("Provider nodes"),
    "warpStr64": MessageLookupByLibrary.simpleMessage(
      "Show full WireGuard keys",
    ),
    "warpStr65": MessageLookupByLibrary.simpleMessage("Checking…"),
    "warpStr66": MessageLookupByLibrary.simpleMessage(
      "Registering the device with Cloudflare and generating keys…",
    ),
    "warpStr67": MessageLookupByLibrary.simpleMessage("Running diagnostics…"),
    "warpStr68": MessageLookupByLibrary.simpleMessage(
      "Generating an X25519 key and registering the device…",
    ),
    "warpStr69": MessageLookupByLibrary.simpleMessage(
      "Binding the key through the official API…",
    ),
    "warpStr7": MessageLookupByLibrary.simpleMessage(
      "Google region-leak check",
    ),
    "warpStr70": MessageLookupByLibrary.simpleMessage(
      "No reachable nodes. Check the network, or turn the proxy off and retry.",
    ),
    "warpStr71": MessageLookupByLibrary.simpleMessage(
      "Traffic goes through WARP first, then to the provider node - useful when a node is blocked",
    ),
    "warpStr72": MessageLookupByLibrary.simpleMessage(
      "Traffic goes through the provider node, then out via WARP - avoids region leaks and unlocks AI",
    ),
    "warpStr73": MessageLookupByLibrary.simpleMessage("Activate and bind"),
    "warpStr74": MessageLookupByLibrary.simpleMessage("Tap to enable WARP"),
    "warpStr75": MessageLookupByLibrary.simpleMessage(
      "Generate WARP configuration",
    ),
    "warpStr76": MessageLookupByLibrary.simpleMessage(
      "Generated (a built-in valid key pair was loaded)",
    ),
    "warpStr77": MessageLookupByLibrary.simpleMessage(
      "Direct or normal proxy (warp=off)",
    ),
    "warpStr78": MessageLookupByLibrary.simpleMessage("OK"),
    "warpStr79": MessageLookupByLibrary.simpleMessage("Port"),
    "warpStr8": MessageLookupByLibrary.simpleMessage(
      "MTU set to 1280 (recommended)",
    ),
    "warpStr80": MessageLookupByLibrary.simpleMessage("Port"),
    "warpStr81": MessageLookupByLibrary.simpleMessage("Port number"),
    "warpStr82": MessageLookupByLibrary.simpleMessage("Port updated"),
    "warpStr83": MessageLookupByLibrary.simpleMessage(
      "Port reset to 0 (default 2408)",
    ),
    "warpStr84": MessageLookupByLibrary.simpleMessage("Policy groups"),
    "warpStr85": MessageLookupByLibrary.simpleMessage(
      "Bind a WARP+ license key",
    ),
    "warpStr86": MessageLookupByLibrary.simpleMessage(
      "Uses the provider node currently selected in the panel",
    ),
    "warpStr87": MessageLookupByLibrary.simpleMessage("Custom rules"),
    "warpStr88": MessageLookupByLibrary.simpleMessage("Virtual IPv4"),
    "warpStr89": MessageLookupByLibrary.simpleMessage("Virtual IPv6"),
    "warpStr9": MessageLookupByLibrary.simpleMessage("MTU set to 1360"),
    "warpStr90": MessageLookupByLibrary.simpleMessage(
      "Avoids captchas and region locks",
    ),
    "warpStr91": MessageLookupByLibrary.simpleMessage("Unbind"),
    "warpStr92": MessageLookupByLibrary.simpleMessage("License key"),
    "warpStr93": MessageLookupByLibrary.simpleMessage(
      "Set the WireGuard port (0 means the default 2408):",
    ),
    "warpStr94": MessageLookupByLibrary.simpleMessage(
      "Set the preferred IP for Cloudflare WARP; enter auto to use the official best IP:",
    ),
    "warpStr95": MessageLookupByLibrary.simpleMessage("Follow dialer"),
    "warpStr96": MessageLookupByLibrary.simpleMessage("Edge colo"),
    "warpStr97": MessageLookupByLibrary.simpleMessage(
      "Connection incomplete or check timed out",
    ),
    "warpStr98": MessageLookupByLibrary.simpleMessage("Choose the WARP dialer"),
    "warpStr99": MessageLookupByLibrary.simpleMessage(
      "Choose the WireGuard MTU",
    ),
    "warpSwitchedTo": m47,
    "warpUnknownColo": MessageLookupByLibrary.simpleMessage(
      "Unknown edge node",
    ),
    "wave": MessageLookupByLibrary.simpleMessage("Wave"),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "WebDAV Configuration",
    ),
    "whitelist": MessageLookupByLibrary.simpleMessage("Whitelist"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("Whitelist Mode"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("Write to System"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "Requires administrator privileges",
    ),
    "wrongBackupPassword": MessageLookupByLibrary.simpleMessage(
      "Wrong password or the backup was tampered with",
    ),
    "years": m48,
  };
}
