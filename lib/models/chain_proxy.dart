import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

String _generateUuidV4() {
  final Random random = Random();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

enum ChainProxyProtocol {
  socks5('SOCKS5', 1080),
  http('HTTP', 8080),
  ss('Shadowsocks', 8388),
  trojan('Trojan', 443),
  vless('VLESS', 443),
  vmess('VMess', 443);

  final String displayName;
  final int defaultPort;

  const ChainProxyProtocol(this.displayName, this.defaultPort);

  static ChainProxyProtocol fromString(String? val) {
    if (val == null) return ChainProxyProtocol.socks5;
    final lower = val.toLowerCase().trim();
    return switch (lower) {
      'socks5' || 'socks' || 'socks5h' => ChainProxyProtocol.socks5,
      'http' || 'https' => ChainProxyProtocol.http,
      'ss' || 'shadowsocks' => ChainProxyProtocol.ss,
      'trojan' => ChainProxyProtocol.trojan,
      'vless' => ChainProxyProtocol.vless,
      'vmess' => ChainProxyProtocol.vmess,
      _ => ChainProxyProtocol.socks5,
    };
  }
}

class LandingProxy {
  final String id;
  final String name;
  final ChainProxyProtocol protocol;
  final String server;
  final int port;
  final String username;
  final String password;
  final String? cipher;
  final bool tls;
  final String? sni;
  final bool udp;
  final String? dialerProxy;
  final bool enable;

  const LandingProxy({
    required this.id,
    required this.name,
    this.protocol = ChainProxyProtocol.socks5,
    required this.server,
    required this.port,
    this.username = '',
    this.password = '',
    this.cipher,
    this.tls = false,
    this.sni,
    this.udp = true,
    this.dialerProxy,
    this.enable = true,
  });

  factory LandingProxy.create({
    String? name,
    ChainProxyProtocol protocol = ChainProxyProtocol.socks5,
    required String server,
    required int port,
    String username = '',
    String password = '',
    String? cipher,
    bool tls = false,
    String? sni,
    bool udp = true,
    String? dialerProxy,
    bool enable = true,
  }) {
    final cleanServer = server.trim();
    final defaultName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : '住宅IP-$cleanServer:$port';
    return LandingProxy(
      id: _generateUuidV4(),
      name: defaultName,
      protocol: protocol,
      server: cleanServer,
      port: port,
      username: username.trim(),
      password: password.trim(),
      cipher: cipher?.trim(),
      tls: tls,
      sni: sni?.trim(),
      udp: udp,
      dialerProxy: dialerProxy?.trim(),
      enable: enable,
    );
  }

  LandingProxy copyWith({
    String? id,
    String? name,
    ChainProxyProtocol? protocol,
    String? server,
    int? port,
    String? username,
    String? password,
    String? cipher,
    bool? tls,
    String? sni,
    bool? udp,
    String? dialerProxy,
    bool? enable,
  }) {
    return LandingProxy(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      server: server ?? this.server,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      cipher: cipher ?? this.cipher,
      tls: tls ?? this.tls,
      sni: sni ?? this.sni,
      udp: udp ?? this.udp,
      dialerProxy: dialerProxy ?? this.dialerProxy,
      enable: enable ?? this.enable,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'protocol': protocol.name,
      'server': server,
      'port': port,
      'username': username,
      'password': password,
      if (cipher != null && cipher!.isNotEmpty) 'cipher': cipher,
      'tls': tls,
      if (sni != null && sni!.isNotEmpty) 'sni': sni,
      'udp': udp,
      if (dialerProxy != null && dialerProxy!.isNotEmpty)
        'dialerProxy': dialerProxy,
      'enable': enable,
    };
  }

  factory LandingProxy.fromJson(Map<String, dynamic> json) {
    return LandingProxy(
      id: json['id']?.toString() ?? _generateUuidV4(),
      name: json['name']?.toString() ?? '住宅IP',
      protocol: ChainProxyProtocol.fromString(json['protocol']?.toString()),
      server: json['server']?.toString() ?? '',
      port: (json['port'] is int)
          ? json['port'] as int
          : int.tryParse(json['port']?.toString() ?? '') ?? 1080,
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      cipher: json['cipher']?.toString(),
      tls: json['tls'] == true,
      sni: json['sni']?.toString(),
      udp: json['udp'] != false,
      dialerProxy: json['dialerProxy']?.toString(),
      enable: json['enable'] != false,
    );
  }

  Map<String, dynamic> toMihomoProxyMap(String effectiveDialer) {
    final map = <String, dynamic>{
      'name': name,
      'server': server,
      'port': port,
      'udp': udp,
    };

    switch (protocol) {
      case ChainProxyProtocol.socks5:
        map['type'] = 'socks5';
        if (username.isNotEmpty) map['username'] = username;
        if (password.isNotEmpty) map['password'] = password;
        break;
      case ChainProxyProtocol.http:
        map['type'] = 'http';
        if (username.isNotEmpty) map['username'] = username;
        if (password.isNotEmpty) map['password'] = password;
        if (tls) {
          map['tls'] = true;
          map['skip-cert-verify'] = true;
          if (sni != null && sni!.isNotEmpty) map['sni'] = sni;
          map['alpn'] = ['h2', 'http/1.1'];
        }
        break;
      case ChainProxyProtocol.ss:
        map['type'] = 'ss';
        map['cipher'] = (cipher != null && cipher!.isNotEmpty)
            ? cipher
            : 'aes-256-gcm';
        map['password'] = password;
        break;
      case ChainProxyProtocol.trojan:
        map['type'] = 'trojan';
        map['password'] = password;
        map['skip-cert-verify'] = true;
        if (sni != null && sni!.isNotEmpty) map['sni'] = sni;
        break;
      case ChainProxyProtocol.vless:
        map['type'] = 'vless';
        map['uuid'] = password;
        if (tls) {
          map['tls'] = true;
          map['skip-cert-verify'] = true;
          if (sni != null && sni!.isNotEmpty) map['servername'] = sni;
        }
        break;
      case ChainProxyProtocol.vmess:
        map['type'] = 'vmess';
        map['uuid'] = password;
        map['alterId'] = 0;
        map['cipher'] = 'auto';
        if (tls) {
          map['tls'] = true;
          map['skip-cert-verify'] = true;
          if (sni != null && sni!.isNotEmpty) map['servername'] = sni;
        }
        break;
    }

    final hop = (dialerProxy != null && dialerProxy!.trim().isNotEmpty)
        ? dialerProxy!.trim()
        : effectiveDialer.trim();

    if (hop.isNotEmpty && hop.toUpperCase() != 'DIRECT') {
      map['dialer-proxy'] = hop;
    }

    return map;
  }
}

class ChainProxyConfig {
  final bool enable;
  final String defaultDialerProxy;
  final bool autoInjectGroups;
  final bool createDedicatedGroup;
  final String dedicatedGroupName;
  final bool preventWebRtcLeak;
  final List<LandingProxy> landingProxies;

  const ChainProxyConfig({
    this.enable = false,
    this.defaultDialerProxy = '',
    this.autoInjectGroups = true,
    this.createDedicatedGroup = true,
    this.dedicatedGroupName = '🔗 链式代理',
    this.preventWebRtcLeak = true,
    this.landingProxies = const [],
  });

  ChainProxyConfig copyWith({
    bool? enable,
    String? defaultDialerProxy,
    bool? autoInjectGroups,
    bool? createDedicatedGroup,
    String? dedicatedGroupName,
    bool? preventWebRtcLeak,
    List<LandingProxy>? landingProxies,
  }) {
    return ChainProxyConfig(
      enable: enable ?? this.enable,
      defaultDialerProxy: defaultDialerProxy ?? this.defaultDialerProxy,
      autoInjectGroups: autoInjectGroups ?? this.autoInjectGroups,
      createDedicatedGroup: createDedicatedGroup ?? this.createDedicatedGroup,
      dedicatedGroupName: dedicatedGroupName ?? this.dedicatedGroupName,
      preventWebRtcLeak: preventWebRtcLeak ?? this.preventWebRtcLeak,
      landingProxies: landingProxies ?? this.landingProxies,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enable': enable,
      'defaultDialerProxy': defaultDialerProxy,
      'autoInjectGroups': autoInjectGroups,
      'createDedicatedGroup': createDedicatedGroup,
      'dedicatedGroupName': dedicatedGroupName,
      'preventWebRtcLeak': preventWebRtcLeak,
      'landingProxies': landingProxies.map((e) => e.toJson()).toList(),
    };
  }

  factory ChainProxyConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ChainProxyConfig();
    final list = json['landingProxies'];
    return ChainProxyConfig(
      enable: json['enable'] == true,
      defaultDialerProxy: json['defaultDialerProxy']?.toString() ?? '',
      autoInjectGroups: json['autoInjectGroups'] != false,
      createDedicatedGroup: json['createDedicatedGroup'] != false,
      dedicatedGroupName: json['dedicatedGroupName']?.toString().isNotEmpty == true
          ? json['dedicatedGroupName'].toString()
          : '🔗 链式代理',
      preventWebRtcLeak: json['preventWebRtcLeak'] != false,
      landingProxies: list is List
          ? list
              .whereType<Map>()
              .map((e) => LandingProxy.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  void applyToClashConfig(Map<String, dynamic> rawConfig) {
    // 1. WebRTC Leak Prevention: Injects high-priority STUN/TURN blocking rules for all nodes
    if (preventWebRtcLeak) {
      final rawRules = rawConfig['rules'];
      final List<dynamic> rulesList = (rawRules is List)
          ? List<dynamic>.from(rawRules)
          : <dynamic>[];

      const webRtcRules = [
        'DOMAIN-KEYWORD,stun,REJECT',
        'DOMAIN-KEYWORD,turn,REJECT',
        'DOMAIN-SUFFIX,stun.cloudflare.com,REJECT',
        'DOMAIN-SUFFIX,stun.l.google.com,REJECT',
        'DOMAIN-SUFFIX,stun1.l.google.com,REJECT',
        'DOMAIN-SUFFIX,stun2.l.google.com,REJECT',
        'DOMAIN-SUFFIX,stun3.l.google.com,REJECT',
        'DOMAIN-SUFFIX,stun4.l.google.com,REJECT',
        'DOMAIN-SUFFIX,stun.services.mozilla.com,REJECT',
        'DOMAIN-SUFFIX,stun.qq.com,REJECT',
        'DOMAIN-SUFFIX,stun.miwifi.com,REJECT',
        'DOMAIN-SUFFIX,stun.chat.bilibili.com,REJECT',
        'DOMAIN-SUFFIX,stun.hitv.com,REJECT',
        'DST-PORT,3478,REJECT',
        'DST-PORT,3479,REJECT',
        'DST-PORT,5349,REJECT',
        'DST-PORT,5350,REJECT',
        'DST-PORT,19302,REJECT',
        'DST-PORT,19305,REJECT',
        'DST-PORT,19307,REJECT',
      ];

      final existingRuleSet = rulesList.map((e) => e.toString().trim()).toSet();
      final rulesToInsert = webRtcRules.where((r) => !existingRuleSet.contains(r)).toList();
      rulesList.insertAll(0, rulesToInsert);
      rawConfig['rules'] = rulesList;
    }

    if (!enable) return;

    final activeLandings = landingProxies.where((p) => p.enable).toList();
    if (activeLandings.isEmpty) return;

    // Ensure proxies list
    final rawProxies = rawConfig['proxies'];
    final List<dynamic> proxiesList = (rawProxies is List)
        ? List<dynamic>.from(rawProxies)
        : <dynamic>[];
    rawConfig['proxies'] = proxiesList;

    // Collect existing airport/outbound proxy names BEFORE injecting any landing proxies
    final List<String> airportProxyNames = [];
    final Set<String> existingProxyOrGroupNames = {
      'DIRECT',
      'REJECT',
      'REJECT-DROP',
      'GLOBAL',
    };

    for (final item in proxiesList) {
      if (item is Map && item['name'] != null) {
        final name = item['name'].toString();
        airportProxyNames.add(name);
        existingProxyOrGroupNames.add(name);
      }
    }

    final rawGroups = rawConfig['proxy-groups'];
    final List<dynamic> groupList = (rawGroups is List)
        ? List<dynamic>.from(rawGroups)
        : <dynamic>[];
    rawConfig['proxy-groups'] = groupList;

    for (final group in groupList) {
      if (group is Map && group['name'] != null) {
        existingProxyOrGroupNames.add(group['name'].toString());
      }
    }

    // Performance, throughput & latency acceleration for multi-hop chain proxies
    rawConfig['tcp-concurrent'] = true;
    rawConfig['unified-delay'] = true;
    rawConfig['keep-alive-idle'] = 600;
    rawConfig['keep-alive-interval'] = 15;

    // Determine dedicated hop group for loop-free dialer-proxy
    const String dedicatedHopGroupName = '✈️ 链式跳板';
    String configuredHop = defaultDialerProxy.trim();

    // Check if configuredHop is a specific existing airport proxy
    final bool isHopSpecificProxy = configuredHop.isNotEmpty &&
        configuredHop.toUpperCase() != 'DIRECT' &&
        airportProxyNames.contains(configuredHop);

    final bool isHopDirect = configuredHop.toUpperCase() == 'DIRECT';

    // If configuredHop is empty or not a valid single proxy, we use dedicatedHopGroupName
    final String fallbackHop = (isHopSpecificProxy || isHopDirect)
        ? configuredHop
        : dedicatedHopGroupName;

    // Create the dedicated hop group if fallbackHop is dedicatedHopGroupName
    if (fallbackHop == dedicatedHopGroupName) {
      final existingHopIndex = groupList.indexWhere(
        (g) => g is Map && g['name'] == dedicatedHopGroupName,
      );

      // Filter out non-proxy informational / dummy notice nodes
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
            lower.contains('发布') ||
            lower.contains('提示') ||
            lower.contains('traffic') ||
            lower.contains('expire') ||
            lower.contains('reset') ||
            lower.contains('website') ||
            lower.contains('notice') ||
            lower.contains('info') ||
            lower.contains('subscribe');
      }

      final cleanAirportProxyNames = airportProxyNames
          .where((name) => !isInformationalName(name))
          .toList();

      final hopProxies = cleanAirportProxyNames.isNotEmpty
          ? List<dynamic>.from(cleanAirportProxyNames)
          : (airportProxyNames.isNotEmpty
              ? List<dynamic>.from(airportProxyNames)
              : <dynamic>['DIRECT']);

      final hopGroupMap = <String, dynamic>{
        'name': dedicatedHopGroupName,
        'type': 'select',
        'proxies': hopProxies,
      };

      if (existingHopIndex != -1) {
        groupList[existingHopIndex] = hopGroupMap;
      } else {
        groupList.add(hopGroupMap);
      }
      existingProxyOrGroupNames.add(dedicatedHopGroupName);
    }

    final injectedProxyNames = <String>[];

    for (final landing in activeLandings) {
      String effectiveHop;
      if (landing.dialerProxy != null && landing.dialerProxy!.trim().isNotEmpty) {
        effectiveHop = landing.dialerProxy!.trim();
      } else {
        effectiveHop = fallbackHop;
      }

      // If effectiveHop is not found in airport proxies and not dedicatedHopGroupName and not DIRECT:
      if (effectiveHop != 'DIRECT' &&
          effectiveHop != dedicatedHopGroupName &&
          !airportProxyNames.contains(effectiveHop)) {
        effectiveHop = fallbackHop;
      }

      final proxyMap = landing.toMihomoProxyMap(effectiveHop);
      proxiesList.add(proxyMap);
      injectedProxyNames.add(landing.name);
      existingProxyOrGroupNames.add(landing.name);
    }

    // Group integration
    if (injectedProxyNames.isNotEmpty) {
      final effectiveDedicatedGroupName = dedicatedGroupName.isNotEmpty
          ? dedicatedGroupName
          : '🔗 链式代理';

      if (createDedicatedGroup) {
        final existingIndex = groupList.indexWhere(
          (g) => g is Map && g['name'] == effectiveDedicatedGroupName,
        );
        final dedicatedGroupMap = <String, dynamic>{
          'name': effectiveDedicatedGroupName,
          'type': 'select',
          'proxies': [
            ...injectedProxyNames,
            'DIRECT',
          ],
        };

        if (existingIndex != -1) {
          groupList[existingIndex] = dedicatedGroupMap;
        } else {
          if (groupList.isNotEmpty &&
              groupList.first is Map &&
              groupList.first['name'] == 'GLOBAL') {
            groupList.insert(1, dedicatedGroupMap);
          } else {
            groupList.insert(0, dedicatedGroupMap);
          }
        }
      }

      // 1. Ensure GLOBAL group has access to dedicated group and landing proxies
      final globalGroup = groupList.firstWhere(
        (g) => g is Map && g['name'] == 'GLOBAL',
        orElse: () => null,
      );
      if (globalGroup is Map && globalGroup['proxies'] is List) {
        final gProxies = List<dynamic>.from(globalGroup['proxies'] as List);
        if (createDedicatedGroup && !gProxies.contains(effectiveDedicatedGroupName)) {
          gProxies.add(effectiveDedicatedGroupName);
        }
        for (final name in injectedProxyNames) {
          if (!gProxies.contains(name)) {
            gProxies.add(name);
          }
        }
        globalGroup['proxies'] = gProxies;
      }

      // 2. Auto-inject into user selector groups without circular loops
      if (autoInjectGroups) {
        const excludedGroupKeywords = [
          '直连',
          '拦截',
          'direct',
          'reject',
          'pass',
          'cloudflare',
          'cdn',
          'rule',
          '漏网之鱼',
        ];

        for (final g in groupList) {
          if (g is! Map) continue;
          final groupName = g['name']?.toString() ?? '';
          if (groupName == effectiveDedicatedGroupName ||
              groupName == dedicatedHopGroupName ||
              groupName == 'GLOBAL') {
            continue;
          }

          final lower = groupName.toLowerCase();
          if (excludedGroupKeywords.any((kw) => lower.contains(kw))) {
            continue;
          }

          final gType = g['type']?.toString().toLowerCase();
          if (gType == 'select') {
            final groupProxies = g['proxies'] is List
                ? List<dynamic>.from(g['proxies'] as List)
                : <dynamic>[];

            // Add dedicated group choice if created
            if (createDedicatedGroup && !groupProxies.contains(effectiveDedicatedGroupName)) {
              groupProxies.add(effectiveDedicatedGroupName);
            }

            for (final name in injectedProxyNames) {
              if (!groupProxies.contains(name)) {
                // ALWAYS APPEND to the end, never insert at 0 to avoid hijacking defaults
                groupProxies.add(name);
              }
            }
            g['proxies'] = groupProxies;
          }
        }
      }

      rawConfig['proxy-groups'] = groupList;
    }

    // Ensure solid bootstrap DNS resolution and fake-ip-filter for proxy domains
    final dns = rawConfig['dns'];
    if (dns is Map) {
      final psn = dns['proxy-server-nameserver'];
      final List<dynamic> psnList = (psn is List)
          ? List<dynamic>.from(psn)
          : (psn is String ? [psn] : <dynamic>[]);
      for (final s in ['223.5.5.5', '119.29.29.29', '114.114.114.114', 'system://']) {
        if (!psnList.contains(s)) {
          psnList.add(s);
        }
      }
      dns['proxy-server-nameserver'] = psnList;

      final defNs = dns['default-nameserver'];
      final List<dynamic> defNsList = (defNs is List)
          ? List<dynamic>.from(defNs)
          : (defNs is String ? [defNs] : <dynamic>[]);
      for (final s in ['223.5.5.5', '119.29.29.29', '114.114.114.114', 'system://']) {
        if (!defNsList.contains(s)) {
          defNsList.add(s);
        }
      }
      dns['default-nameserver'] = defNsList;

      final fif = dns['fake-ip-filter'];
      final List<dynamic> fifList = (fif is List)
          ? List<dynamic>.from(fif)
          : (fif is String ? [fif] : <dynamic>[]);
      for (final landing in activeLandings) {
        final server = landing.server.trim();
        if (server.isNotEmpty && !server.contains(':') && InternetAddress.tryParse(server) == null) {
          if (!fifList.contains(server)) fifList.add(server);
          if (!fifList.contains('+.$server')) fifList.add('+.$server');
        }
      }
      dns['fake-ip-filter'] = fifList;
    }
  }
}

class LandingProxyParser {
  static final RegExp _ipPortUserPassReg = RegExp(
    r'^([a-zA-Z0-9.\-_]+):(\d{1,5}):([^:\s]+):([^\s]+)$',
  );

  static final RegExp _userPassIpPortReg = RegExp(
    r'^([^:\s]+):([^@\s]+)@([a-zA-Z0-9.\-_]+):(\d{1,5})$',
  );

  static final RegExp _ipPortReg = RegExp(
    r'^([a-zA-Z0-9.\-_]+):(\d{1,5})$',
  );

  static List<LandingProxy> parseText(String input, {String? dialerProxy}) {
    final results = <LandingProxy>[];
    if (input.trim().isEmpty) return results;

    final lines = input.split(RegExp(r'[\r\n]+'));

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }

      final parsed = _parseSingleLine(line, dialerProxy: dialerProxy);
      if (parsed != null) {
        results.add(parsed);
      }
    }

    return results;
  }

  static LandingProxy? _parseSingleLine(String line, {String? dialerProxy}) {
    // 1. URI Schemes: socks5://, http://, etc.
    if (line.contains('://')) {
      final uri = Uri.tryParse(line);
      if (uri != null && uri.host.isNotEmpty && uri.hasPort) {
        final scheme = uri.scheme.toLowerCase();
        final protocol = ChainProxyProtocol.fromString(scheme);
        var username = '';
        var password = '';
        if (uri.userInfo.isNotEmpty) {
          final parts = uri.userInfo.split(':');
          username = Uri.decodeComponent(parts[0]);
          if (parts.length > 1) {
            password = Uri.decodeComponent(parts.sublist(1).join(':'));
          }
        }
        var name = uri.fragment.isNotEmpty
            ? Uri.decodeComponent(uri.fragment)
            : '住宅IP-${uri.host}:${uri.port}';

        return LandingProxy.create(
          name: name,
          protocol: protocol,
          server: uri.host,
          port: uri.port,
          username: username,
          password: password,
          dialerProxy: dialerProxy,
        );
      }
    }

    // 2. Shadowsocks standard ss://BASE64
    if (line.startsWith('ss://')) {
      try {
        final rest = line.substring(5);
        final tagIndex = rest.indexOf('#');
        var base64Part = tagIndex != -1 ? rest.substring(0, tagIndex) : rest;
        var tag = tagIndex != -1 ? Uri.decodeComponent(rest.substring(tagIndex + 1)) : '';
        
        final decoded = utf8.decode(base64Decode(base64.normalize(base64Part)));
        final match = _userPassIpPortReg.firstMatch(decoded);
        if (match != null) {
          final cipher = match.group(1)!;
          final pass = match.group(2)!;
          final host = match.group(3)!;
          final port = int.tryParse(match.group(4)!) ?? 8388;
          return LandingProxy.create(
            name: tag.isNotEmpty ? tag : '住宅IP-$host:$port',
            protocol: ChainProxyProtocol.ss,
            server: host,
            port: port,
            cipher: cipher,
            password: pass,
            dialerProxy: dialerProxy,
          );
        }
      } catch (_) {}
    }

    // 3. IP:PORT:USER:PASS (Top format from residential proxy providers)
    final match1 = _ipPortUserPassReg.firstMatch(line);
    if (match1 != null) {
      final server = match1.group(1)!;
      final port = int.tryParse(match1.group(2)!) ?? 1080;
      final user = match1.group(3)!;
      final pass = match1.group(4)!;
      return LandingProxy.create(
        name: '住宅IP-$server:$port',
        protocol: ChainProxyProtocol.socks5,
        server: server,
        port: port,
        username: user,
        password: pass,
        dialerProxy: dialerProxy,
      );
    }

    // 4. USER:PASS@IP:PORT
    final match2 = _userPassIpPortReg.firstMatch(line);
    if (match2 != null) {
      final user = match2.group(1)!;
      final pass = match2.group(2)!;
      final server = match2.group(3)!;
      final port = int.tryParse(match2.group(4)!) ?? 1080;
      return LandingProxy.create(
        name: '住宅IP-$server:$port',
        protocol: ChainProxyProtocol.socks5,
        server: server,
        port: port,
        username: user,
        password: pass,
        dialerProxy: dialerProxy,
      );
    }

    // 5. IP:PORT (IP whitelist authentication)
    final match3 = _ipPortReg.firstMatch(line);
    if (match3 != null) {
      final server = match3.group(1)!;
      final port = int.tryParse(match3.group(2)!) ?? 1080;
      return LandingProxy.create(
        name: '住宅IP-$server:$port',
        protocol: ChainProxyProtocol.socks5,
        server: server,
        port: port,
        dialerProxy: dialerProxy,
      );
    }

    return null;
  }
}

enum TargetService {
  cloudflare(
    'Cloudflare',
    'https://cp.cloudflare.com/generate_204',
    '基础网络与 CDN 连通',
  ),
  google(
    'Google',
    'https://www.google.com/generate_204',
    '谷歌搜索与基础生态',
  ),
  openai(
    'OpenAI / ChatGPT',
    'https://chatgpt.com',
    'ChatGPT 与大模型交互',
  ),
  tiktok(
    'TikTok',
    'https://www.tiktok.com',
    '海外短视频与社媒运营',
  ),
  amazon(
    'Amazon',
    'https://www.amazon.com',
    '跨境电商与海淘支付',
  ),
  youtube(
    'YouTube',
    'https://www.youtube.com/generate_204',
    '4K 流媒体与音视频传输',
  );

  final String label;
  final String testUrl;
  final String desc;

  const TargetService(this.label, this.testUrl, this.desc);
}

class TargetHealthResult {
  final TargetService service;
  final int? delay;
  final bool isSuccess;
  final String? error;

  const TargetHealthResult({
    required this.service,
    this.delay,
    required this.isSuccess,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'service': service.name,
        'delay': delay,
        'isSuccess': isSuccess,
        if (error != null) 'error': error,
      };

  factory TargetHealthResult.fromJson(Map<String, dynamic> json) {
    return TargetHealthResult(
      service: TargetService.values.firstWhere(
        (e) => e.name == json['service'],
        orElse: () => TargetService.cloudflare,
      ),
      delay: json['delay'] as int?,
      isSuccess: json['isSuccess'] == true,
      error: json['error']?.toString(),
    );
  }
}

enum HealthStatus {
  healthy('正常', '全项服务连接顺畅'),
  warning('部分受限', '基础可用，个别目标服务超时'),
  error('不可用', '无法连通或身份验证失败'),
  testing('检测中', '正在测试各项服务连通性'),
  untested('未体检', '尚未进行可用性检测');

  final String label;
  final String desc;

  const HealthStatus(this.label, this.desc);
}

class ProxyHealthReport {
  final String proxyId;
  final String proxyName;
  final HealthStatus status;
  final List<TargetHealthResult> targets;
  final String diagnosticTips;
  final DateTime testedAt;
  final int? minDelay;
  final int? avgDelay;

  const ProxyHealthReport({
    required this.proxyId,
    required this.proxyName,
    required this.status,
    this.targets = const [],
    this.diagnosticTips = '',
    required this.testedAt,
    this.minDelay,
    this.avgDelay,
  });

  bool get isHealthy => status == HealthStatus.healthy;
  bool get hasError => status == HealthStatus.error;
  bool get isTesting => status == HealthStatus.testing;

  bool isTargetAvailable(TargetService service) {
    return targets.any((t) => t.service == service && t.isSuccess);
  }

  int? getTargetDelay(TargetService service) {
    for (final t in targets) {
      if (t.service == service) return t.delay;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'proxyId': proxyId,
        'proxyName': proxyName,
        'status': status.name,
        'targets': targets.map((t) => t.toJson()).toList(),
        'diagnosticTips': diagnosticTips,
        'testedAt': testedAt.toIso8601String(),
        'minDelay': minDelay,
        'avgDelay': avgDelay,
      };

  factory ProxyHealthReport.fromJson(Map<String, dynamic> json) {
    final targetList = json['targets'];
    return ProxyHealthReport(
      proxyId: json['proxyId']?.toString() ?? '',
      proxyName: json['proxyName']?.toString() ?? '',
      status: HealthStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => HealthStatus.untested,
      ),
      targets: targetList is List
          ? targetList
              .whereType<Map>()
              .map((e) => TargetHealthResult.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      diagnosticTips: json['diagnosticTips']?.toString() ?? '',
      testedAt: DateTime.tryParse(json['testedAt']?.toString() ?? '') ?? DateTime.now(),
      minDelay: json['minDelay'] as int?,
      avgDelay: json['avgDelay'] as int?,
    );
  }
}

class DirectCheckResult {
  final bool isSuccess;
  final int? delay;
  final String message;
  final bool isAuthError;

  const DirectCheckResult({
    required this.isSuccess,
    this.delay,
    required this.message,
    this.isAuthError = false,
  });
}

class DirectSocketVerifier {
  static Future<DirectCheckResult> verify({
    required String server,
    required int port,
    ChainProxyProtocol protocol = ChainProxyProtocol.socks5,
    String username = '',
    String password = '',
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(server, port, timeout: timeout);
      if (protocol == ChainProxyProtocol.socks5) {
        final res = await _verifySocks5(socket, username, password, timeout);
        sw.stop();
        return DirectCheckResult(
          isSuccess: res.isSuccess,
          delay: sw.elapsedMilliseconds,
          message: res.message,
          isAuthError: res.isAuthError,
        );
      } else if (protocol == ChainProxyProtocol.http) {
        final res = await _verifyHttp(socket, server, port, username, password, timeout);
        sw.stop();
        return DirectCheckResult(
          isSuccess: res.isSuccess,
          delay: sw.elapsedMilliseconds,
          message: res.message,
          isAuthError: res.isAuthError,
        );
      } else {
        sw.stop();
        return DirectCheckResult(
          isSuccess: true,
          delay: sw.elapsedMilliseconds,
          message: 'TCP 端口连通正常 (${protocol.displayName})',
        );
      }
    } on SocketException catch (e) {
      sw.stop();
      return DirectCheckResult(
        isSuccess: false,
        message: '连接失败: ${e.osError?.message ?? e.message}',
      );
    } on TimeoutException {
      sw.stop();
      return DirectCheckResult(
        isSuccess: false,
        message: '连接超时（超过 ${timeout.inSeconds} 秒未响应）',
      );
    } catch (e) {
      sw.stop();
      return DirectCheckResult(
        isSuccess: false,
        message: '测试异常: $e',
      );
    } finally {
      try {
        await socket?.close();
        socket?.destroy();
      } catch (_) {}
    }
  }

  static Future<({bool isSuccess, String message, bool isAuthError})> _verifySocks5(
    Socket socket,
    String username,
    String password,
    Duration timeout,
  ) async {
    final hasAuth = username.isNotEmpty || password.isNotEmpty;
    socket.add([0x05, 0x02, 0x00, 0x02]);
    await socket.flush();

    final resp = await _readExactBytes(socket, 2, timeout);
    if (resp.length < 2 || resp[0] != 0x05) {
      return (
        isSuccess: false,
        message: '非标准 SOCKS5 协议响应',
        isAuthError: false,
      );
    }

    final method = resp[1];
    if (method == 0xFF) {
      return (
        isSuccess: false,
        message: 'SOCKS5 服务端拒绝认证方法',
        isAuthError: true,
      );
    }

    if (method == 0x02) {
      if (!hasAuth) {
        return (
          isSuccess: false,
          message: '服务端要求账号密码认证，但当前未配置',
          isAuthError: true,
        );
      }
      final uBytes = utf8.encode(username);
      final pBytes = utf8.encode(password);
      final authPacket = <int>[
        0x01,
        uBytes.length,
        ...uBytes,
        pBytes.length,
        ...pBytes,
      ];
      socket.add(authPacket);
      await socket.flush();

      final authResp = await _readExactBytes(socket, 2, timeout);
      if (authResp.length < 2 || authResp[1] != 0x00) {
        return (
          isSuccess: false,
          message: '住宅 IP 账号或密码错误 (认证失败)',
          isAuthError: true,
        );
      }
    }

    return (
      isSuccess: true,
      message: method == 0x02 ? 'SOCKS5 认证成功，连接正常' : 'SOCKS5 握手成功 (免密)',
      isAuthError: false,
    );
  }

  static Future<({bool isSuccess, String message, bool isAuthError})> _verifyHttp(
    Socket socket,
    String server,
    int port,
    String username,
    String password,
    Duration timeout,
  ) async {
    final hasAuth = username.isNotEmpty || password.isNotEmpty;
    final headers = StringBuffer();
    headers.write('CONNECT 1.1.1.1:80 HTTP/1.1\r\n');
    headers.write('Host: 1.1.1.1:80\r\n');
    headers.write('User-Agent: Bettbox/1.0\r\n');
    if (hasAuth) {
      final cred = base64Encode(utf8.encode('$username:$password'));
      headers.write('Proxy-Authorization: Basic $cred\r\n');
    }
    headers.write('\r\n');

    socket.write(headers.toString());
    await socket.flush();

    final respLine = await _readLine(socket, timeout);
    if (respLine.contains('200')) {
      return (isSuccess: true, message: 'HTTP 代理握手成功', isAuthError: false);
    } else if (respLine.contains('407')) {
      return (isSuccess: false, message: 'HTTP 代理鉴权失败 (407 账号或密码错误)', isAuthError: true);
    } else {
      return (
        isSuccess: false,
        message: 'HTTP 代理响应异常: ${respLine.trim()}',
        isAuthError: false,
      );
    }
  }

  static Future<List<int>> _readExactBytes(
    Socket socket,
    int count,
    Duration timeout,
  ) async {
    final completer = Completer<List<int>>();
    final buffer = <int>[];
    StreamSubscription? sub;

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(buffer);
      }
    });

    sub = socket.listen((data) {
      buffer.addAll(data);
      if (buffer.length >= count && !completer.isCompleted) {
        timer.cancel();
        completer.complete(buffer.sublist(0, count));
        sub?.cancel();
      }
    }, onError: (_) {
      timer.cancel();
      if (!completer.isCompleted) completer.complete(buffer);
    }, onDone: () {
      timer.cancel();
      if (!completer.isCompleted) completer.complete(buffer);
    });

    final res = await completer.future;
    timer.cancel();
    sub.cancel();
    return res;
  }

  static Future<String> _readLine(Socket socket, Duration timeout) async {
    final completer = Completer<String>();
    final buffer = <int>[];
    late StreamSubscription sub;

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(utf8.decode(buffer, allowMalformed: true));
      }
    });

    sub = socket.listen((data) {
      buffer.addAll(data);
      final text = utf8.decode(buffer, allowMalformed: true);
      if (text.contains('\n') && !completer.isCompleted) {
        timer.cancel();
        completer.complete(text.split('\n').first);
        sub.cancel();
      }
    }, onError: (_) {
      timer.cancel();
      if (!completer.isCompleted) completer.complete(utf8.decode(buffer, allowMalformed: true));
    }, onDone: () {
      timer.cancel();
      if (!completer.isCompleted) completer.complete(utf8.decode(buffer, allowMalformed: true));
    });

    final res = await completer.future;
    timer.cancel();
    sub.cancel();
    return res;
  }
}

