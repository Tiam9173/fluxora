import 'dart:convert';
import 'package:bett_box/common/curve25519.dart';

enum WarpMode {
  googleAndAi('智能防送中与 AI 解锁 (推荐)', '针对 Google、OpenAI、Claude、Gemini 等平台套 WARP 出口，其余保持机场原生高速'),
  all('全局接管模式', '所有代理出站流量全部经过 WARP 进行二次封装，隐藏真实机场落地 IP'),
  custom('自定义规则分流', '根据指定域名或 IP 规则决定是否通过 WARP 出口');

  final String label;
  final String description;

  const WarpMode(this.label, this.description);

  static WarpMode fromString(String? val) {
    if (val == null) return WarpMode.googleAndAi;
    final lower = val.toLowerCase().trim();
    return switch (lower) {
      'all' || 'global' => WarpMode.all,
      'custom' => WarpMode.custom,
      _ => WarpMode.googleAndAi,
    };
  }
}

enum WarpRoutingMode {
  warpOverProxy('通过代理路由 WARP', '通过代理路由 WARP (推荐: 机场套 WARP 出口，防送中、解锁流媒体与 AI)'),
  proxyOverWarp('通过 WARP 路由代理', '通过 WARP 路由代理 (WARP 作为前置跳板连通被封锁的节点)');

  final String label;
  final String description;

  const WarpRoutingMode(this.label, this.description);

  static WarpRoutingMode fromString(String? val) {
    if (val == null) return WarpRoutingMode.warpOverProxy;
    final lower = val.toLowerCase().trim();
    if (lower.contains('proxy_over_warp') ||
        lower.contains('proxyoverwarp') ||
        lower.contains('warp_as_entry') ||
        lower == 'proxyoverwarp') {
      return WarpRoutingMode.proxyOverWarp;
    }
    return WarpRoutingMode.warpOverProxy;
  }
}

class WarpConfig {
  static const String defaultPeerPublicKey =
      'bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=';
  static const String defaultEndpoint = '162.159.192.1';
  static const int defaultPort = 2408;
  static const String defaultV4 = '172.16.0.2/32';
  static const String defaultV6 = '2606:4700:110:88a1::1/128';
  static const String defaultProxyName = '🛡️ Cloudflare WARP';
  static const String defaultDedicatedGroupName = '🛡️ WARP 出口';

  final bool enable;
  final String proxyName;
  final String dedicatedGroupName;
  final String privateKey;
  final String publicKey;
  final String peerPublicKey;
  final String server;
  final int port;
  final String cleanIp;
  final String ip;
  final String ipv6;
  final List<int> reserved;
  final int mtu;
  final bool udp;
  final bool remoteDnsResolve;
  final String defaultDialerProxy;
  final WarpRoutingMode routingMode;
  final WarpMode mode;
  final String licenseKey;
  final String accountId;
  final String accountToken;
  final String accountType; // free, plus, teams
  final String noiseCount;
  final String noiseMode;
  final String noiseSize;
  final String noiseDelay;
  final List<String> customRules;

  const WarpConfig({
    this.enable = false,
    this.proxyName = defaultProxyName,
    this.dedicatedGroupName = defaultDedicatedGroupName,
    this.privateKey = '',
    this.publicKey = '',
    this.peerPublicKey = defaultPeerPublicKey,
    this.server = defaultEndpoint,
    this.port = defaultPort,
    this.cleanIp = 'auto',
    this.ip = defaultV4,
    this.ipv6 = defaultV6,
    this.reserved = const [0, 0, 0],
    this.mtu = 1280,
    this.udp = true,
    this.remoteDnsResolve = true,
    this.defaultDialerProxy = '',
    this.routingMode = WarpRoutingMode.warpOverProxy,
    this.mode = WarpMode.googleAndAi,
    this.licenseKey = '',
    this.accountId = '',
    this.accountToken = '',
    this.accountType = 'free',
    this.noiseCount = '1-3',
    this.noiseMode = 'm4',
    this.noiseSize = '10-30',
    this.noiseDelay = '10-30',
    this.customRules = const [],
  });

  /// The effective endpoint server hostname / IP address
  String get effectiveServer {
    final c = cleanIp.trim();
    if (c.isNotEmpty && c.toLowerCase() != 'auto') {
      return c;
    }
    if (server.trim().isNotEmpty && server.trim().toLowerCase() != 'auto') {
      return server.trim();
    }
    return defaultEndpoint;
  }

  /// The effective WireGuard port
  int get effectivePort {
    if (port > 0) return port;
    return defaultPort;
  }

  /// Factory to generate a new initial WARP config with fresh Curve25519 keys
  factory WarpConfig.generateNew({
    bool enable = false,
    String defaultDialerProxy = '',
    WarpRoutingMode routingMode = WarpRoutingMode.warpOverProxy,
    WarpMode mode = WarpMode.googleAndAi,
  }) {
    final keyPair = Curve25519.generateKeyPair();
    return WarpConfig(
      enable: enable,
      privateKey: keyPair.privateKey,
      publicKey: keyPair.publicKey,
      defaultDialerProxy: defaultDialerProxy,
      routingMode: routingMode,
      mode: mode,
    );
  }

  WarpConfig copyWith({
    bool? enable,
    String? proxyName,
    String? dedicatedGroupName,
    String? privateKey,
    String? publicKey,
    String? peerPublicKey,
    String? server,
    int? port,
    String? cleanIp,
    String? ip,
    String? ipv6,
    List<int>? reserved,
    int? mtu,
    bool? udp,
    bool? remoteDnsResolve,
    String? defaultDialerProxy,
    WarpRoutingMode? routingMode,
    WarpMode? mode,
    String? licenseKey,
    String? accountId,
    String? accountToken,
    String? accountType,
    String? noiseCount,
    String? noiseMode,
    String? noiseSize,
    String? noiseDelay,
    List<String>? customRules,
  }) {
    return WarpConfig(
      enable: enable ?? this.enable,
      proxyName: proxyName ?? this.proxyName,
      dedicatedGroupName: dedicatedGroupName ?? this.dedicatedGroupName,
      privateKey: privateKey ?? this.privateKey,
      publicKey: publicKey ?? this.publicKey,
      peerPublicKey: peerPublicKey ?? this.peerPublicKey,
      server: server ?? this.server,
      port: port ?? this.port,
      cleanIp: cleanIp ?? this.cleanIp,
      ip: ip ?? this.ip,
      ipv6: ipv6 ?? this.ipv6,
      reserved: reserved ?? this.reserved,
      mtu: mtu ?? this.mtu,
      udp: udp ?? this.udp,
      remoteDnsResolve: remoteDnsResolve ?? this.remoteDnsResolve,
      defaultDialerProxy: defaultDialerProxy ?? this.defaultDialerProxy,
      routingMode: routingMode ?? this.routingMode,
      mode: mode ?? this.mode,
      licenseKey: licenseKey ?? this.licenseKey,
      accountId: accountId ?? this.accountId,
      accountToken: accountToken ?? this.accountToken,
      accountType: accountType ?? this.accountType,
      noiseCount: noiseCount ?? this.noiseCount,
      noiseMode: noiseMode ?? this.noiseMode,
      noiseSize: noiseSize ?? this.noiseSize,
      noiseDelay: noiseDelay ?? this.noiseDelay,
      customRules: customRules ?? this.customRules,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enable': enable,
      'proxyName': proxyName,
      'dedicatedGroupName': dedicatedGroupName,
      'privateKey': privateKey,
      'publicKey': publicKey,
      'peerPublicKey': peerPublicKey,
      'server': server,
      'port': port,
      'cleanIp': cleanIp,
      'ip': ip,
      'ipv6': ipv6,
      'reserved': reserved,
      'mtu': mtu,
      'udp': udp,
      'remoteDnsResolve': remoteDnsResolve,
      'defaultDialerProxy': defaultDialerProxy,
      'routingMode': routingMode.name,
      'mode': mode.name,
      'licenseKey': licenseKey,
      'accountId': accountId,
      'accountToken': accountToken,
      'accountType': accountType,
      'noiseCount': noiseCount,
      'noiseMode': noiseMode,
      'noiseSize': noiseSize,
      'noiseDelay': noiseDelay,
      'customRules': customRules,
    };
  }

  factory WarpConfig.fromJson(Map<String, dynamic> json) {
    List<int> parseReserved(dynamic val) {
      if (val is List) {
        return val.map((e) => int.tryParse(e.toString()) ?? 0).toList();
      }
      return const [0, 0, 0];
    }

    return WarpConfig(
      enable: json['enable'] == true,
      proxyName: json['proxyName']?.toString() ?? defaultProxyName,
      dedicatedGroupName:
          json['dedicatedGroupName']?.toString() ?? defaultDedicatedGroupName,
      privateKey: json['privateKey']?.toString() ?? '',
      publicKey: json['publicKey']?.toString() ?? '',
      peerPublicKey: json['peerPublicKey']?.toString() ?? defaultPeerPublicKey,
      server: json['server']?.toString() ?? defaultEndpoint,
      port: (json['port'] is int)
          ? json['port'] as int
          : int.tryParse(json['port']?.toString() ?? '') ?? defaultPort,
      cleanIp: json['cleanIp']?.toString() ?? 'auto',
      ip: json['ip']?.toString() ?? defaultV4,
      ipv6: json['ipv6']?.toString() ?? defaultV6,
      reserved: parseReserved(json['reserved']),
      mtu: (json['mtu'] is int)
          ? json['mtu'] as int
          : int.tryParse(json['mtu']?.toString() ?? '') ?? 1280,
      udp: json['udp'] != false,
      remoteDnsResolve: json['remoteDnsResolve'] != false,
      defaultDialerProxy: json['defaultDialerProxy']?.toString() ?? '',
      routingMode: WarpRoutingMode.fromString(json['routingMode']?.toString()),
      mode: WarpMode.fromString(json['mode']?.toString()),
      licenseKey: json['licenseKey']?.toString() ?? '',
      accountId: json['accountId']?.toString() ?? '',
      accountToken: json['accountToken']?.toString() ?? '',
      accountType: json['accountType']?.toString() ?? 'free',
      noiseCount: json['noiseCount']?.toString() ?? '1-3',
      noiseMode: json['noiseMode']?.toString() ?? 'm4',
      noiseSize: json['noiseSize']?.toString() ?? '10-30',
      noiseDelay: json['noiseDelay']?.toString() ?? '10-30',
      customRules: (json['customRules'] is List)
          ? (json['customRules'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }

  /// Builds the Mihomo (Clash.Meta) WireGuard proxy map with dialer-proxy
  Map<String, dynamic> toMihomoProxyMap([String effectiveDialer = '']) {
    final map = <String, dynamic>{
      'name': proxyName,
      'type': 'wireguard',
      'server': effectiveServer,
      'port': effectivePort,
      'ip': ip.trim().isNotEmpty ? ip.trim() : defaultV4,
      if (ipv6.trim().isNotEmpty) 'ipv6': ipv6.trim(),
      'private-key': privateKey.trim(),
      'public-key': peerPublicKey.trim().isNotEmpty
          ? peerPublicKey.trim()
          : defaultPeerPublicKey,
      'reserved': reserved.length == 3 ? reserved : [0, 0, 0],
      'mtu': mtu > 0 ? mtu : 1280,
      'udp': udp,
      'remote-dns-resolve': remoteDnsResolve,
      'dns': ['1.1.1.1', '1.0.0.1'],
    };

    if (effectiveDialer.isNotEmpty &&
        effectiveDialer.toUpperCase() != 'DIRECT') {
      map['dialer-proxy'] = effectiveDialer;
    }

    return map;
  }

  /// Injects WARP WireGuard proxy, dedicated group, and anti-redirect rules into Clash rawConfig
  void applyToClashConfig(Map<String, dynamic> rawConfig) {
    if (!enable || privateKey.trim().isEmpty) return;

    // 1. Ensure proxies list
    final rawProxies = rawConfig['proxies'];
    final List<dynamic> proxiesList = (rawProxies is List)
        ? List<dynamic>.from(rawProxies)
        : <dynamic>[];
    rawConfig['proxies'] = proxiesList;

    // Collect existing airport proxy names for dialer-proxy selection
    final List<String> airportProxyNames = [];
    final Set<String> existingNames = {
      'DIRECT',
      'REJECT',
      'REJECT-DROP',
      'GLOBAL',
      'PASS',
    };

    for (final item in proxiesList) {
      if (item is Map && item['name'] != null) {
        final name = item['name'].toString();
        if (name != proxyName) {
          airportProxyNames.add(name);
          existingNames.add(name);
        }
      }
    }

    // Performance settings for UDP over TCP/Proxy
    rawConfig['tcp-concurrent'] = true;
    rawConfig['unified-delay'] = true;

    // 2. Ensure proxy-groups
    final rawGroups = rawConfig['proxy-groups'];
    final List<dynamic> groupList = (rawGroups is List)
        ? List<dynamic>.from(rawGroups)
        : <dynamic>[];
    rawConfig['proxy-groups'] = groupList;

    // Check routingMode:
    // Case A: proxyOverWarp ("通过 WARP 路由代理")
    // Client -> WARP (direct) -> Airport Proxy -> Destination
    if (routingMode == WarpRoutingMode.proxyOverWarp) {
      // Inject WireGuard proxy with direct connection (no dialer-proxy)
      proxiesList.removeWhere((p) => p is Map && p['name'] == proxyName);
      proxiesList.add(toMihomoProxyMap(''));

      // Set dialer-proxy = proxyName for all airport proxies
      for (final item in proxiesList) {
        if (item is Map && item['name'] != null) {
          final name = item['name'].toString();
          if (name != proxyName && item['type'] != null) {
            item['dialer-proxy'] = proxyName;
          }
        }
      }

      // Add WARP node to general groups if not present
      for (final group in groupList) {
        if (group is Map) {
          final pList = group['proxies'];
          if (pList is List && !pList.contains(proxyName)) {
            pList.add(proxyName);
          }
        }
      }
      return;
    }

    // Case B: warpOverProxy ("通过代理路由 WARP", default)
    // Client -> Airport Proxy (hop) -> WARP (WireGuard) -> Destination
    const String dedicatedWarpHopGroup = '✈️ WARP跳板';
    String configuredHop = defaultDialerProxy.trim();

    final bool isHopSpecificProxy = configuredHop.isNotEmpty &&
        configuredHop.toUpperCase() != 'DIRECT' &&
        airportProxyNames.contains(configuredHop);

    final bool isHopDirect = configuredHop.toUpperCase() == 'DIRECT';

    final String effectiveHop = (isHopSpecificProxy || isHopDirect)
        ? configuredHop
        : dedicatedWarpHopGroup;

    // Filter out dummy/info nodes
    bool isInformationalName(String name) {
      final lower = name.toLowerCase();
      return lower.contains('剩余') ||
          lower.contains('流量') ||
          lower.contains('到期') ||
          lower.contains('重置') ||
          lower.contains('官网') ||
          lower.contains('网站') ||
          lower.contains('通知') ||
          lower.contains('更新') ||
          lower.contains('维护') ||
          lower.contains('群') ||
          lower.contains('频道') ||
          lower.contains('traffic') ||
          lower.contains('expire') ||
          lower.contains('reset') ||
          lower.contains('notice');
    }

    final validHopNodes = airportProxyNames
        .where((n) => !isInformationalName(n) && n != proxyName)
        .toList();

    // Create ✈️ WARP跳板 group if needed
    if (effectiveHop == dedicatedWarpHopGroup) {
      final existingIndex = groupList.indexWhere(
        (g) => g is Map && g['name'] == dedicatedWarpHopGroup,
      );

      final List<String> hopProxies = validHopNodes.isNotEmpty
          ? List<String>.from(validHopNodes)
          : (airportProxyNames.isNotEmpty
              ? List<String>.from(airportProxyNames)
              : ['DIRECT']);

      final dedicatedHopMap = <String, dynamic>{
        'name': dedicatedWarpHopGroup,
        'type': 'select',
        'proxies': hopProxies,
      };

      if (existingIndex >= 0) {
        groupList[existingIndex] = dedicatedHopMap;
      } else {
        groupList.insert(0, dedicatedHopMap);
      }
    }

    // 3. Inject WireGuard proxy
    proxiesList.removeWhere((p) => p is Map && p['name'] == proxyName);
    proxiesList.add(toMihomoProxyMap(effectiveHop));

    // 4. Create dedicated WARP outbound policy group: 🛡️ WARP 出口
    final warpOutboundGroupName = dedicatedGroupName.trim().isNotEmpty
        ? dedicatedGroupName.trim()
        : defaultDedicatedGroupName;

    final existingWarpGroupIndex = groupList.indexWhere(
      (g) => g is Map && g['name'] == warpOutboundGroupName,
    );

    final List<String> warpGroupProxies = [
      proxyName,
      'DIRECT',
      if (effectiveHop != warpOutboundGroupName) effectiveHop,
    ];

    final warpGroupMap = <String, dynamic>{
      'name': warpOutboundGroupName,
      'type': 'select',
      'proxies': warpGroupProxies,
    };

    if (existingWarpGroupIndex >= 0) {
      groupList[existingWarpGroupIndex] = warpGroupMap;
    } else {
      groupList.insert(0, warpGroupMap);
    }

    // 5. Handle routing rules and group injection based on mode
    final rawRules = rawConfig['rules'];
    final List<dynamic> rulesList = (rawRules is List)
        ? List<dynamic>.from(rawRules)
        : <dynamic>[];
    rawConfig['rules'] = rulesList;

    if (mode == WarpMode.googleAndAi) {
      // High-priority Anti-Google Redirection & AI unlock rules
      final List<String> priorityRules = [
        // Google Anti-Redirect & Anti-Captcha
        'DOMAIN-SUFFIX,google.com,$warpOutboundGroupName',
        'DOMAIN-SUFFIX,google.com.hk,$warpOutboundGroupName',
        'DOMAIN-SUFFIX,googleusercontent.com,$warpOutboundGroupName',
        'DOMAIN-SUFFIX,gstatic.com,$warpOutboundGroupName',
        'DOMAIN-SUFFIX,recaptcha.net,$warpOutboundGroupName',
        'DOMAIN-SUFFIX,recaptcha.com,$warpOutboundGroupName',
        'DOMAIN-KEYWORD,google,$warpOutboundGroupName',
        // OpenAI / ChatGPT Unlock
        'DOMAIN-SUFFIX,openai.com,$warpOutboundGroupName',
        'DOMAIN-SUFFIX,chatgpt.com,$warpOutboundGroupName',
        'DOMAIN-SUFFIX,oaistatic.com,$warpOutboundGroupName',
        'DOMAIN-SUFFIX,oaiusercontent.com,$warpOutboundGroupName',
        // Anthropic / Claude
        'DOMAIN-SUFFIX,anthropic.com,$warpOutboundGroupName',
        'DOMAIN-SUFFIX,claude.ai,$warpOutboundGroupName',
        // Gemini / Bard
        'DOMAIN-SUFFIX,bard.google.com,$warpOutboundGroupName',
        'DOMAIN-SUFFIX,gemini.google.com,$warpOutboundGroupName',
        // Cloudflare challenge & trace
        'DOMAIN-SUFFIX,cloudflare.com,$warpOutboundGroupName',
        'DOMAIN-SUFFIX,cloudflareclient.com,$warpOutboundGroupName',
        'DOMAIN-SUFFIX,workers.dev,$warpOutboundGroupName',
      ];

      final existingRuleSet = rulesList.map((e) => e.toString().trim()).toSet();
      final rulesToInsert =
          priorityRules.where((r) => !existingRuleSet.contains(r)).toList();
      rulesList.insertAll(0, rulesToInsert);
    } else if (mode == WarpMode.all) {
      // In all mode: add WARP proxy to other selector groups so it's globally selectable / top
      for (final group in groupList) {
        if (group is Map &&
            group['name'] != warpOutboundGroupName &&
            group['name'] != dedicatedWarpHopGroup) {
          final pList = group['proxies'];
          if (pList is List && !pList.contains(proxyName)) {
            pList.insert(0, proxyName);
          }
        }
      }
    } else if (mode == WarpMode.custom && customRules.isNotEmpty) {
      final existingRuleSet = rulesList.map((e) => e.toString().trim()).toSet();
      final rulesToInsert = customRules
          .where((r) => r.trim().isNotEmpty && !existingRuleSet.contains(r.trim()))
          .toList();
      rulesList.insertAll(0, rulesToInsert);
    }
  }
}

class WarpStatusReport {
  final bool isSuccess;
  final bool isWarpActive; // warp=on or warp=plus
  final String ip;
  final String colo;
  final String loc;
  final String warpType; // off, on, plus
  final int? latencyMs;
  final bool isGoogleAntiRedirect;
  final String googleStatus;
  final DateTime testedAt;
  final String? rawTrace;

  const WarpStatusReport({
    required this.isSuccess,
    required this.isWarpActive,
    required this.ip,
    required this.colo,
    required this.loc,
    required this.warpType,
    this.latencyMs,
    required this.isGoogleAntiRedirect,
    required this.googleStatus,
    required this.testedAt,
    this.rawTrace,
  });

  /// Readable Chinese city name for Cloudflare 3-letter IATA airport codes
  String get coloCityName {
    final c = colo.toUpperCase().trim();
    return switch (c) {
      'HKG' => '中国香港 (Hong Kong)',
      'TPE' => '中国台湾 (Taipei)',
      'NRT' => '日本东京成田 (Tokyo Narita)',
      'HND' => '日本东京羽田 (Tokyo Haneda)',
      'KIX' => '日本大阪 (Osaka)',
      'ICN' => '韩国首尔仁川 (Seoul)',
      'SIN' => '新加坡 (Singapore)',
      'BKK' => '泰国曼谷 (Bangkok)',
      'KUL' => '马来西亚吉隆坡 (Kuala Lumpur)',
      'SJC' => '美国圣何塞 (San Jose)',
      'LAX' => '美国洛杉矶 (Los Angeles)',
      'SFO' => '美国旧金山 (San Francisco)',
      'SEA' => '美国西雅图 (Seattle)',
      'ORD' => '美国芝加哥 (Chicago)',
      'DFW' => '美国达拉斯 (Dallas)',
      'JFK' || 'EWR' => '美国纽约 (New York)',
      'IAD' => '美国华盛顿 (Washington)',
      'FRA' => '德国法兰克福 (Frankfurt)',
      'LHR' => '英国伦敦 (London)',
      'AMS' => '荷兰阿姆斯特丹 (Amsterdam)',
      'CDG' => '法国巴黎 (Paris)',
      'SYD' => '澳大利亚悉尼 (Sydney)',
      'MEL' => '澳大利亚墨尔本 (Melbourne)',
      _ => c.isNotEmpty ? '边缘节点 $c' : '未知边缘节点',
    };
  }

  factory WarpStatusReport.fromTrace({
    required String traceText,
    required int? latencyMs,
    required bool googleOk,
    required String googleDetail,
  }) {
    final lines = LineSplitter.split(traceText);
    final map = <String, String>{};
    for (final line in lines) {
      final idx = line.indexOf('=');
      if (idx > 0) {
        final k = line.substring(0, idx).trim();
        final v = line.substring(idx + 1).trim();
        map[k] = v;
      }
    }

    final warpVal = map['warp']?.toLowerCase() ?? 'off';
    final isWarp = warpVal == 'on' || warpVal == 'plus';
    final ipVal = map['ip'] ?? '';
    final coloVal = map['colo'] ?? '';
    final locVal = map['loc'] ?? '';

    return WarpStatusReport(
      isSuccess: ipVal.isNotEmpty,
      isWarpActive: isWarp,
      ip: ipVal,
      colo: coloVal,
      loc: locVal,
      warpType: warpVal,
      latencyMs: latencyMs,
      isGoogleAntiRedirect: googleOk,
      googleStatus: googleDetail,
      testedAt: DateTime.now(),
      rawTrace: traceText,
    );
  }

  factory WarpStatusReport.failure(String message) {
    return WarpStatusReport(
      isSuccess: false,
      isWarpActive: false,
      ip: '',
      colo: '',
      loc: '',
      warpType: 'off',
      isGoogleAntiRedirect: false,
      googleStatus: message,
      testedAt: DateTime.now(),
    );
  }
}
