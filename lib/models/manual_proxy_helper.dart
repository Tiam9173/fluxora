import 'dart:convert';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

enum ManualProtocol {
  vmess,
  vless,
  ss,
  ssr,
  trojan,
  trojanGo,
  hysteria,
  hysteria2,
  tuic,
  wireguard,
  amneziaWg,
  snell,
  ssh,
  shadowTls,
  juicity,
  naive,
  socks5,
  http,
  direct,
  custom,
}

extension ManualProtocolExt on ManualProtocol {
  String get displayName => switch (this) {
        ManualProtocol.vmess => 'VMess',
        ManualProtocol.vless => 'VLESS',
        ManualProtocol.ss => 'Shadowsocks',
        ManualProtocol.ssr => 'ShadowsocksR',
        ManualProtocol.trojan => 'Trojan',
        ManualProtocol.trojanGo => 'Trojan Go',
        ManualProtocol.hysteria => 'Hysteria',
        ManualProtocol.hysteria2 => 'Hysteria 2',
        ManualProtocol.tuic => 'TUIC',
        ManualProtocol.wireguard => 'WireGuard',
        ManualProtocol.amneziaWg => 'AmneziaWG 2/3',
        ManualProtocol.snell => 'Snell',
        ManualProtocol.ssh => 'SSH',
        ManualProtocol.shadowTls => 'ShadowTLS',
        ManualProtocol.juicity => 'Juicity',
        ManualProtocol.naive => 'Naïve (NaiveProxy)',
        ManualProtocol.socks5 => 'SOCKS5',
        ManualProtocol.http => 'HTTP(S)',
        ManualProtocol.direct => 'Direct (直连)',
        ManualProtocol.custom => 'Custom Config (自定义配置)',
      };

  String get typeKey => switch (this) {
        ManualProtocol.vmess => 'vmess',
        ManualProtocol.vless => 'vless',
        ManualProtocol.ss => 'ss',
        ManualProtocol.ssr => 'ssr',
        ManualProtocol.trojan => 'trojan',
        ManualProtocol.trojanGo => 'trojan',
        ManualProtocol.hysteria => 'hysteria',
        ManualProtocol.hysteria2 => 'hysteria2',
        ManualProtocol.tuic => 'tuic',
        ManualProtocol.wireguard => 'wireguard',
        ManualProtocol.amneziaWg => 'wireguard',
        ManualProtocol.snell => 'snell',
        ManualProtocol.ssh => 'ssh',
        ManualProtocol.shadowTls => 'shadow-tls',
        ManualProtocol.juicity => 'juicity',
        ManualProtocol.naive => 'http',
        ManualProtocol.socks5 => 'socks5',
        ManualProtocol.http => 'http',
        ManualProtocol.direct => 'direct',
        ManualProtocol.custom => 'custom',
      };

  Color get badgeColor => switch (this) {
        ManualProtocol.vmess => Colors.deepPurple,
        ManualProtocol.vless => Colors.blue,
        ManualProtocol.ss => Colors.teal,
        ManualProtocol.ssr => Colors.cyan,
        ManualProtocol.trojan => Colors.orange,
        ManualProtocol.trojanGo => Colors.deepOrange,
        ManualProtocol.hysteria => Colors.pink,
        ManualProtocol.hysteria2 => Colors.red,
        ManualProtocol.tuic => Colors.amber.shade800,
        ManualProtocol.wireguard => Colors.green,
        ManualProtocol.amneziaWg => Colors.lightGreen.shade800,
        ManualProtocol.snell => Colors.indigo,
        ManualProtocol.ssh => Colors.brown,
        ManualProtocol.shadowTls => Colors.purple,
        ManualProtocol.juicity => Colors.lime.shade900,
        ManualProtocol.naive => Colors.blueGrey,
        ManualProtocol.socks5 => Colors.blueGrey.shade600,
        ManualProtocol.http => Colors.grey.shade700,
        ManualProtocol.direct => Colors.green.shade700,
        ManualProtocol.custom => Colors.grey.shade600,
      };
}

class ManualProxyHelper {
  /// Base64 decoding with padding and URL-safe normalization
  static String safeBase64Decode(String input) {
    String normalized = input.trim().replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return utf8.decode(base64Decode(normalized));
  }

  /// Safe Base64 encoding
  static String safeBase64Encode(String input) {
    return base64Encode(utf8.encode(input));
  }

  /// Parse a single proxy share link or snippet into a Clash.Meta proxy dictionary.
  static Map<String, dynamic>? parseShareLink(String link) {
    final raw = link.trim();
    if (raw.isEmpty) return null;

    try {
      if (raw.startsWith('vmess://')) {
        return _parseVMess(raw);
      } else if (raw.startsWith('vless://')) {
        return _parseVLESS(raw);
      } else if (raw.startsWith('ss://')) {
        return _parseSS(raw);
      } else if (raw.startsWith('ssr://')) {
        return _parseSSR(raw);
      } else if (raw.startsWith('trojan-go://')) {
        return _parseTrojanGo(raw);
      } else if (raw.startsWith('trojan://')) {
        return _parseTrojan(raw);
      } else if (raw.startsWith('hysteria2://') || raw.startsWith('hy2://')) {
        return _parseHysteria2(raw);
      } else if (raw.startsWith('hysteria://')) {
        return _parseHysteria(raw);
      } else if (raw.startsWith('tuic://')) {
        return _parseTUIC(raw);
      } else if (raw.startsWith('awg://') || raw.startsWith('amnezia://') || raw.startsWith('amneziawg://')) {
        return _parseAmneziaWG(raw);
      } else if (raw.startsWith('wireguard://')) {
        return _parseWireGuard(raw);
      } else if (raw.startsWith('snell://')) {
        return _parseSnell(raw);
      } else if (raw.startsWith('ssh://')) {
        return _parseSSH(raw);
      } else if (raw.startsWith('shadow-tls://') || raw.startsWith('shadowtls://')) {
        return _parseShadowTLS(raw);
      } else if (raw.startsWith('juicity://')) {
        return _parseJuicity(raw);
      } else if (raw.startsWith('naive+https://') || raw.startsWith('naive://')) {
        return _parseNaive(raw);
      } else if (raw.startsWith('socks5://') || raw.startsWith('socks://') || raw.startsWith('socks4://')) {
        return _parseSocks5(raw);
      } else if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return _parseHttp(raw);
      } else if (raw.startsWith('direct://')) {
        return _parseDirect(raw);
      } else if (raw.startsWith('{') || raw.contains('type:')) {
        return _parseRawYamlOrJson(raw);
      }
    } catch (e) {
      commonPrint.log('ManualProxyHelper: Failed to parse link $raw: $e');
    }
    return null;
  }

  /// Parse multiple links or YAML/JSON snippets (newline or whitespace delimited)
  static List<Map<String, dynamic>> parseMultipleLinks(String text) {
    final results = <Map<String, dynamic>>[];
    final trimmed = text.trim();
    if (trimmed.isEmpty) return results;

    // Check if entire text is a YAML block with proxies list
    if (trimmed.contains('proxies:')) {
      try {
        final yaml = loadYaml(trimmed);
        if (yaml is Map && yaml['proxies'] is List) {
          for (final p in yaml['proxies']) {
            if (p is Map && p['name'] != null && p['type'] != null) {
              results.add(deepConvertYamlMap(p));
            }
          }
          if (results.isNotEmpty) return results;
        }
      } catch (_) {}
    }

    final lines = trimmed.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      final lineTrimmed = line.trim();
      if (lineTrimmed.isEmpty) continue;
      final parsed = parseShareLink(lineTrimmed);
      if (parsed != null && parsed['name'] != null) {
        results.add(parsed);
      }
    }
    return results;
  }

  // --- Parser Implementations ---

  static Map<String, dynamic>? _parseVMess(String uri) {
    final b64Part = uri.substring('vmess://'.length).trim();
    final jsonStr = safeBase64Decode(b64Part);
    final json = jsonDecode(jsonStr);
    if (json is! Map) return null;

    final name = (json['ps']?.toString().trim().isNotEmpty == true)
        ? json['ps'].toString().trim()
        : 'VMess_${json['add']}_${json['port']}';
    final server = json['add']?.toString().trim() ?? '';
    final port = int.tryParse(json['port']?.toString() ?? '443') ?? 443;
    final uuid = json['id']?.toString().trim() ?? '';
    final alterId = int.tryParse(json['aid']?.toString() ?? '0') ?? 0;
    final cipher = json['scy']?.toString().trim();
    final net = json['net']?.toString().trim().toLowerCase() ?? 'tcp';
    final tlsStr = json['tls']?.toString().trim().toLowerCase();
    final isTls = tlsStr == 'tls' || tlsStr == '1' || tlsStr == 'true';
    final sni = json['sni']?.toString().trim();
    final host = json['host']?.toString().trim();
    final path = json['path']?.toString().trim();

    final map = <String, dynamic>{
      'name': name,
      'type': 'vmess',
      'server': server,
      'port': port,
      'uuid': uuid,
      'alterId': alterId,
      'cipher': (cipher != null && cipher.isNotEmpty) ? cipher : 'auto',
      'udp': true,
    };

    if (isTls) {
      map['tls'] = true;
      map['skip-cert-verify'] = true;
      if (sni != null && sni.isNotEmpty) {
        map['servername'] = sni;
      } else if (host != null && host.isNotEmpty) {
        map['servername'] = host;
      }
    }

    if (net == 'ws') {
      map['network'] = 'ws';
      final wsOpts = <String, dynamic>{};
      if (path != null && path.isNotEmpty) wsOpts['path'] = path;
      if (host != null && host.isNotEmpty) {
        wsOpts['headers'] = {'Host': host};
      }
      map['ws-opts'] = wsOpts;
    } else if (net == 'grpc') {
      map['network'] = 'grpc';
      final grpcOpts = <String, dynamic>{};
      if (path != null && path.isNotEmpty) {
        grpcOpts['grpc-service-name'] = path;
      }
      map['grpc-opts'] = grpcOpts;
    } else if (net == 'h2') {
      map['network'] = 'h2';
      final h2Opts = <String, dynamic>{};
      if (path != null && path.isNotEmpty) h2Opts['path'] = path;
      if (host != null && host.isNotEmpty) h2Opts['host'] = [host];
      map['h2-opts'] = h2Opts;
    } else if (net == 'httpupgrade') {
      map['network'] = 'httpupgrade';
      final huOpts = <String, dynamic>{};
      if (path != null && path.isNotEmpty) huOpts['path'] = path;
      if (host != null && host.isNotEmpty) {
        huOpts['headers'] = {'Host': host};
      }
      map['httpupgrade-opts'] = huOpts;
    }

    return map;
  }

  static Map<String, dynamic>? _parseVLESS(String rawUri) {
    final parsedUri = Uri.parse(rawUri);
    final uuid = parsedUri.userInfo;
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 443 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'VLESS_${server}_$port';
    final query = parsedUri.queryParameters;

    final net = query['type']?.toLowerCase() ?? 'tcp';
    final security = query['security']?.toLowerCase() ?? 'none';
    final flow = query['flow'];
    final sni = query['sni'];
    final host = query['host'];
    final path = query['path'];
    final pbk = query['pbk'];
    final sid = query['sid'];
    final fp = query['fp'];

    final map = <String, dynamic>{
      'name': name,
      'type': 'vless',
      'server': server,
      'port': port,
      'uuid': uuid,
      'udp': true,
    };

    if (flow != null && flow.isNotEmpty) {
      map['flow'] = flow;
    }

    if (security == 'tls') {
      map['tls'] = true;
      map['skip-cert-verify'] = true;
      if (sni != null && sni.isNotEmpty) {
        map['servername'] = sni;
      }
    } else if (security == 'reality') {
      map['tls'] = true;
      map['skip-cert-verify'] = true;
      if (sni != null && sni.isNotEmpty) {
        map['servername'] = sni;
      }
      final realityOpts = <String, dynamic>{};
      if (pbk != null && pbk.isNotEmpty) realityOpts['public-key'] = pbk;
      if (sid != null && sid.isNotEmpty) realityOpts['short-id'] = sid;
      map['reality-opts'] = realityOpts;
      if (fp != null && fp.isNotEmpty) {
        map['client-fingerprint'] = fp;
      }
    }

    if (net == 'ws') {
      map['network'] = 'ws';
      final wsOpts = <String, dynamic>{};
      if (path != null && path.isNotEmpty) wsOpts['path'] = Uri.decodeComponent(path);
      if (host != null && host.isNotEmpty) {
        wsOpts['headers'] = {'Host': host};
      }
      map['ws-opts'] = wsOpts;
    } else if (net == 'grpc') {
      map['network'] = 'grpc';
      final grpcOpts = <String, dynamic>{};
      if (path != null && path.isNotEmpty) {
        grpcOpts['grpc-service-name'] = Uri.decodeComponent(path);
      }
      map['grpc-opts'] = grpcOpts;
    } else if (net == 'httpupgrade') {
      map['network'] = 'httpupgrade';
      final huOpts = <String, dynamic>{};
      if (path != null && path.isNotEmpty) huOpts['path'] = Uri.decodeComponent(path);
      if (host != null && host.isNotEmpty) {
        huOpts['headers'] = {'Host': host};
      }
      map['httpupgrade-opts'] = huOpts;
    }

    return map;
  }

  static Map<String, dynamic>? _parseSS(String rawUri) {
    var uriStr = rawUri.replaceFirst('ss://', '');
    String name = '';
    if (uriStr.contains('#')) {
      final parts = uriStr.split('#');
      uriStr = parts[0];
      name = Uri.decodeComponent(parts[1]);
    }

    String method = '';
    String password = '';
    String server = '';
    int port = 8388;

    if (uriStr.contains('@')) {
      final atParts = uriStr.split('@');
      final userPart = atParts[0];
      final hostPart = atParts[1];

      if (userPart.contains(':')) {
        final up = userPart.split(':');
        method = up[0];
        password = up[1];
      } else {
        final decodedUser = safeBase64Decode(userPart);
        final up = decodedUser.split(':');
        if (up.length >= 2) {
          method = up[0];
          password = up.sublist(1).join(':');
        }
      }

      final hostPort = hostPart.split('/')[0].split('?')[0].split(':');
      if (hostPort.length >= 2) {
        server = hostPort[0];
        port = int.tryParse(hostPort[1]) ?? 8388;
      }
    } else {
      final decoded = safeBase64Decode(uriStr.split('?')[0]);
      final atIdx = decoded.indexOf('@');
      if (atIdx != -1) {
        final up = decoded.substring(0, atIdx).split(':');
        method = up[0];
        password = up.sublist(1).join(':');
        final hp = decoded.substring(atIdx + 1).split(':');
        server = hp[0];
        port = int.tryParse(hp[1]) ?? 8388;
      }
    }

    if (server.isEmpty) return null;
    if (name.isEmpty) name = 'SS_${server}_$port';

    return <String, dynamic>{
      'name': name,
      'type': 'ss',
      'server': server,
      'port': port,
      'cipher': method.isNotEmpty ? method : 'aes-256-gcm',
      'password': password,
      'udp': true,
    };
  }

  static Map<String, dynamic>? _parseSSR(String rawUri) {
    final b64 = rawUri.substring('ssr://'.length).trim();
    final decoded = safeBase64Decode(b64);
    final slashParts = decoded.split('/?');
    final mainParts = slashParts[0].split(':');
    if (mainParts.length < 6) return null;

    final server = mainParts[0];
    final port = int.tryParse(mainParts[1]) ?? 8388;
    final protocol = mainParts[2];
    final method = mainParts[3];
    final obfs = mainParts[4];
    final password = safeBase64Decode(mainParts[5]);

    String name = 'SSR_${server}_$port';
    String obfsParam = '';
    String protoParam = '';

    if (slashParts.length > 1) {
      final params = Uri.splitQueryString(slashParts[1]);
      if (params['remarks'] != null) {
        try {
          name = safeBase64Decode(params['remarks']!);
        } catch (_) {}
      }
      if (params['obfsparam'] != null) {
        try {
          obfsParam = safeBase64Decode(params['obfsparam']!);
        } catch (_) {}
      }
      if (params['protoparam'] != null) {
        try {
          protoParam = safeBase64Decode(params['protoparam']!);
        } catch (_) {}
      }
    }

    return <String, dynamic>{
      'name': name,
      'type': 'ssr',
      'server': server,
      'port': port,
      'cipher': method,
      'password': password,
      'protocol': protocol,
      'obfs': obfs,
      if (obfsParam.isNotEmpty) 'obfs-param': obfsParam,
      if (protoParam.isNotEmpty) 'protocol-param': protoParam,
      'udp': true,
    };
  }

  static Map<String, dynamic>? _parseTrojan(String rawUri) {
    final parsedUri = Uri.parse(rawUri);
    final password = parsedUri.userInfo;
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 443 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'Trojan_${server}_$port';
    final query = parsedUri.queryParameters;

    final sni = query['sni'] ?? query['peer'];
    final net = query['type']?.toLowerCase() ?? 'tcp';
    final path = query['path'];
    final host = query['host'];

    final map = <String, dynamic>{
      'name': name,
      'type': 'trojan',
      'server': server,
      'port': port,
      'password': password,
      'udp': true,
      'skip-cert-verify': true,
    };

    if (sni != null && sni.isNotEmpty) {
      map['sni'] = sni;
    }

    if (net == 'ws') {
      map['network'] = 'ws';
      final wsOpts = <String, dynamic>{};
      if (path != null && path.isNotEmpty) wsOpts['path'] = Uri.decodeComponent(path);
      if (host != null && host.isNotEmpty) {
        wsOpts['headers'] = {'Host': host};
      }
      map['ws-opts'] = wsOpts;
    } else if (net == 'grpc') {
      map['network'] = 'grpc';
      final grpcOpts = <String, dynamic>{};
      if (path != null && path.isNotEmpty) {
        grpcOpts['grpc-service-name'] = path;
      }
      map['grpc-opts'] = grpcOpts;
    }

    return map;
  }

  static Map<String, dynamic>? _parseTrojanGo(String rawUri) {
    final parsedUri = Uri.parse(rawUri.replaceFirst('trojan-go://', 'http://'));
    final password = parsedUri.userInfo;
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 443 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'TrojanGo_${server}_$port';
    final query = parsedUri.queryParameters;

    final sni = query['sni'] ?? query['peer'];
    final type = query['type']?.toLowerCase() ?? 'ws';
    final host = query['host'];
    final path = query['path'] ?? '/';

    final map = <String, dynamic>{
      'name': name,
      'type': 'trojan',
      'server': server,
      'port': port,
      'password': password,
      'udp': true,
      'skip-cert-verify': true,
    };

    if (sni != null && sni.isNotEmpty) map['sni'] = sni;
    if (type == 'ws') {
      map['network'] = 'ws';
      map['ws-opts'] = {
        'path': path,
        if (host != null && host.isNotEmpty) 'headers': {'Host': host},
      };
    }
    return map;
  }

  static Map<String, dynamic>? _parseHysteria(String rawUri) {
    final parsedUri = Uri.parse(rawUri.replaceFirst('hysteria://', 'http://'));
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 443 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'Hysteria_${server}_$port';
    final query = parsedUri.queryParameters;

    final auth = parsedUri.userInfo.isNotEmpty ? parsedUri.userInfo : (query['auth'] ?? query['auth_str'] ?? '');
    final up = query['up'] ?? '30 Mbps';
    final down = query['down'] ?? '100 Mbps';
    final sni = query['sni'] ?? query['peer'];
    final obfs = query['obfs'];
    final alpn = query['alpn'];
    final protocol = query['protocol'] ?? 'udp';

    return <String, dynamic>{
      'name': name,
      'type': 'hysteria',
      'server': server,
      'port': port,
      'auth_str': auth,
      'up': up.contains('bps') ? up : '$up Mbps',
      'down': down.contains('bps') ? down : '$down Mbps',
      if (sni != null && sni.isNotEmpty) 'sni': sni,
      if (obfs != null && obfs.isNotEmpty) 'obfs': obfs,
      if (alpn != null && alpn.isNotEmpty) 'alpn': alpn.split(','),
      'protocol': protocol,
      'skip-cert-verify': true,
    };
  }

  static Map<String, dynamic>? _parseHysteria2(String rawUri) {
    final prefix = rawUri.startsWith('hysteria2://') ? 'hysteria2://' : 'hy2://';
    final parsedUri = Uri.parse(rawUri.replaceFirst(prefix, 'http://'));
    final password = parsedUri.userInfo;
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 443 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'Hysteria2_${server}_$port';
    final query = parsedUri.queryParameters;

    final sni = query['sni'];
    final obfs = query['obfs'];
    final obfsPassword = query['obfs-password'];

    final map = <String, dynamic>{
      'name': name,
      'type': 'hysteria2',
      'server': server,
      'port': port,
      'password': password,
      'skip-cert-verify': true,
    };

    if (sni != null && sni.isNotEmpty) {
      map['sni'] = sni;
    }
    if (obfs != null && obfs.isNotEmpty) {
      map['obfs'] = obfs;
      if (obfsPassword != null && obfsPassword.isNotEmpty) {
        map['obfs-password'] = obfsPassword;
      }
    }

    return map;
  }

  static Map<String, dynamic>? _parseTUIC(String rawUri) {
    final parsedUri = Uri.parse(rawUri.replaceFirst('tuic://', 'http://'));
    final userInfo = parsedUri.userInfo;
    String uuid = '';
    String password = '';
    if (userInfo.contains(':')) {
      final parts = userInfo.split(':');
      uuid = parts[0];
      password = parts[1];
    } else {
      uuid = userInfo;
    }
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 8443 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'TUIC_${server}_$port';
    final query = parsedUri.queryParameters;

    final sni = query['sni'];
    final alpn = query['alpn'];
    final cc = query['congestion_control'] ?? 'bbr';
    final udpRelay = query['udp_relay_mode'] ?? 'native';

    final map = <String, dynamic>{
      'name': name,
      'type': 'tuic',
      'server': server,
      'port': port,
      'uuid': uuid,
      'password': password,
      'congestion-controller': cc,
      'udp-relay-mode': udpRelay,
      'reduce-rtt': true,
      'skip-cert-verify': true,
    };

    if (sni != null && sni.isNotEmpty) map['sni'] = sni;
    if (alpn != null && alpn.isNotEmpty) {
      map['alpn'] = alpn.split(',');
    }

    return map;
  }

  static Map<String, dynamic>? _parseAmneziaWG(String rawUri) {
    final prefix = rawUri.startsWith('awg://')
        ? 'awg://'
        : (rawUri.startsWith('amneziawg://') ? 'amneziawg://' : 'amnezia://');
    final parsedUri = Uri.parse(rawUri.replaceFirst(prefix, 'http://'));
    final privateKey = parsedUri.userInfo;
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 51820 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'AmneziaWG_${server}_$port';
    final query = parsedUri.queryParameters;

    final publicKey = query['public_key'] ?? query['public-key'] ?? '';
    final ip = query['ip'] ?? '10.0.0.2';
    final jc = int.tryParse(query['jc'] ?? '4') ?? 4;
    final jmin = int.tryParse(query['jmin'] ?? '40') ?? 40;
    final jmax = int.tryParse(query['jmax'] ?? '70') ?? 70;
    final s1 = int.tryParse(query['s1'] ?? '0') ?? 0;
    final s2 = int.tryParse(query['s2'] ?? '0') ?? 0;
    final h1 = int.tryParse(query['h1'] ?? '1') ?? 1;
    final h2 = int.tryParse(query['h2'] ?? '2') ?? 2;
    final h3 = int.tryParse(query['h3'] ?? '3') ?? 3;
    final h4 = int.tryParse(query['h4'] ?? '4') ?? 4;

    return <String, dynamic>{
      'name': name,
      'type': 'wireguard',
      'server': server,
      'port': port,
      'ip': ip,
      'public-key': publicKey,
      'private-key': privateKey,
      'udp': true,
      'remote-dns-resolve': true,
      'jc': jc,
      'jmin': jmin,
      'jmax': jmax,
      's1': s1,
      's2': s2,
      'h1': h1,
      'h2': h2,
      'h3': h3,
      'h4': h4,
    };
  }

  static Map<String, dynamic>? _parseWireGuard(String rawUri) {
    final parsedUri = Uri.parse(rawUri.replaceFirst('wireguard://', 'http://'));
    final privateKey = parsedUri.userInfo;
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 51820 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'WireGuard_${server}_$port';
    final query = parsedUri.queryParameters;

    final publicKey = query['public_key'] ?? query['public-key'] ?? '';
    final ip = query['ip'] ?? '10.0.0.2';
    final presharedKey = query['preshared_key'] ?? query['preshared-key'];
    final reservedStr = query['reserved'];

    final map = <String, dynamic>{
      'name': name,
      'type': 'wireguard',
      'server': server,
      'port': port,
      'ip': ip,
      'public-key': publicKey,
      'private-key': privateKey,
      'udp': true,
      'remote-dns-resolve': true,
    };

    if (presharedKey != null && presharedKey.isNotEmpty) {
      map['preshared-key'] = presharedKey;
    }
    if (reservedStr != null && reservedStr.isNotEmpty) {
      final parts = reservedStr.split(',').map((e) => int.tryParse(e.trim()) ?? 0).toList();
      map['reserved'] = parts;
    }

    return map;
  }

  static Map<String, dynamic>? _parseSnell(String rawUri) {
    final parsedUri = Uri.parse(rawUri.replaceFirst('snell://', 'http://'));
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 443 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'Snell_${server}_$port';
    final query = parsedUri.queryParameters;

    final psk = parsedUri.userInfo.isNotEmpty ? parsedUri.userInfo : (query['psk'] ?? '');
    final version = int.tryParse(query['version'] ?? '4') ?? 4;
    final obfsMode = query['obfs'] ?? query['mode'];
    final obfsHost = query['host'];

    final map = <String, dynamic>{
      'name': name,
      'type': 'snell',
      'server': server,
      'port': port,
      'psk': psk,
      'version': version,
    };

    if (obfsMode != null && obfsMode.isNotEmpty && obfsMode != 'off') {
      map['obfs-opts'] = {
        'mode': obfsMode,
        if (obfsHost != null && obfsHost.isNotEmpty) 'host': obfsHost,
      };
    }
    return map;
  }

  static Map<String, dynamic>? _parseSSH(String rawUri) {
    final parsedUri = Uri.parse(rawUri.replaceFirst('ssh://', 'http://'));
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 22 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'SSH_${server}_$port';
    final userInfo = parsedUri.userInfo;

    String user = 'root';
    String password = '';
    if (userInfo.contains(':')) {
      final parts = userInfo.split(':');
      user = parts[0];
      password = parts.sublist(1).join(':');
    } else if (userInfo.isNotEmpty) {
      user = userInfo;
    }

    return <String, dynamic>{
      'name': name,
      'type': 'ssh',
      'server': server,
      'port': port,
      'username': user,
      if (password.isNotEmpty) 'password': password,
    };
  }

  static Map<String, dynamic>? _parseShadowTLS(String rawUri) {
    final prefix = rawUri.startsWith('shadow-tls://') ? 'shadow-tls://' : 'shadowtls://';
    final parsedUri = Uri.parse(rawUri.replaceFirst(prefix, 'http://'));
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 443 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'ShadowTLS_${server}_$port';
    final query = parsedUri.queryParameters;

    final password = parsedUri.userInfo.isNotEmpty ? parsedUri.userInfo : (query['password'] ?? '');
    final sni = query['sni'] ?? query['host'] ?? '';
    final version = int.tryParse(query['version'] ?? '3') ?? 3;

    return <String, dynamic>{
      'name': name,
      'type': 'shadow-tls',
      'server': server,
      'port': port,
      'password': password,
      'sni': sni,
      'version': version,
    };
  }

  static Map<String, dynamic>? _parseJuicity(String rawUri) {
    final parsedUri = Uri.parse(rawUri.replaceFirst('juicity://', 'http://'));
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 443 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'Juicity_${server}_$port';
    final query = parsedUri.queryParameters;

    final userInfo = parsedUri.userInfo;
    String uuid = '';
    String password = '';
    if (userInfo.contains(':')) {
      final parts = userInfo.split(':');
      uuid = parts[0];
      password = parts[1];
    } else {
      uuid = userInfo;
    }

    final sni = query['sni'] ?? '';
    final cc = query['congestion_control'] ?? 'bbr';
    final allowInsecure = query['allow_insecure'] == '1' || query['allow_insecure'] == 'true';

    return <String, dynamic>{
      'name': name,
      'type': 'juicity',
      'server': server,
      'port': port,
      'uuid': uuid,
      'password': password,
      if (sni.isNotEmpty) 'sni': sni,
      'congestion-control': cc,
      'allow-insecure': allowInsecure,
    };
  }

  static Map<String, dynamic>? _parseNaive(String rawUri) {
    final prefix = rawUri.startsWith('naive+https://') ? 'naive+https://' : 'naive://';
    final parsedUri = Uri.parse(rawUri.replaceFirst(prefix, 'http://'));
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 443 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'Naive_${server}_$port';
    final userInfo = parsedUri.userInfo;

    String user = '';
    String password = '';
    if (userInfo.contains(':')) {
      final parts = userInfo.split(':');
      user = parts[0];
      password = parts[1];
    } else {
      user = userInfo;
    }

    return <String, dynamic>{
      'name': name,
      'type': 'http',
      'server': server,
      'port': port,
      'username': user,
      'password': password,
      'tls': true,
      'sni': server,
      'skip-cert-verify': true,
    };
  }

  static Map<String, dynamic>? _parseSocks5(String rawUri) {
    final prefix = rawUri.startsWith('socks5://')
        ? 'socks5://'
        : (rawUri.startsWith('socks4://') ? 'socks4://' : 'socks://');
    final parsedUri = Uri.parse(rawUri.replaceFirst(prefix, 'http://'));
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? 1080 : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'SOCKS5_${server}_$port';
    final userInfo = parsedUri.userInfo;

    final map = <String, dynamic>{
      'name': name,
      'type': 'socks5',
      'server': server,
      'port': port,
    };

    if (userInfo.isNotEmpty) {
      if (userInfo.contains(':')) {
        final parts = userInfo.split(':');
        map['username'] = parts[0];
        map['password'] = parts[1];
      } else {
        map['username'] = userInfo;
      }
    }

    return map;
  }

  static Map<String, dynamic>? _parseHttp(String rawUri) {
    final parsedUri = Uri.parse(rawUri);
    final isHttps = rawUri.startsWith('https://');
    final server = parsedUri.host;
    final port = parsedUri.port == 0 ? (isHttps ? 443 : 80) : parsedUri.port;
    final name = parsedUri.fragment.isNotEmpty
        ? Uri.decodeComponent(parsedUri.fragment)
        : 'HTTP_${server}_$port';
    final userInfo = parsedUri.userInfo;

    final map = <String, dynamic>{
      'name': name,
      'type': 'http',
      'server': server,
      'port': port,
      if (isHttps) 'tls': true,
    };

    if (userInfo.isNotEmpty) {
      if (userInfo.contains(':')) {
        final parts = userInfo.split(':');
        map['username'] = parts[0];
        map['password'] = parts[1];
      } else {
        map['username'] = userInfo;
      }
    }

    return map;
  }

  static Map<String, dynamic>? _parseDirect(String rawUri) {
    final parsed = Uri.parse(rawUri);
    final name = parsed.fragment.isNotEmpty ? Uri.decodeComponent(parsed.fragment) : 'DIRECT_NODE';
    return <String, dynamic>{
      'name': name,
      'type': 'direct',
    };
  }

  static Map<String, dynamic>? _parseRawYamlOrJson(String raw) {
    try {
      final loaded = loadYaml(raw);
      if (loaded is Map) {
        final map = deepConvertYamlMap(loaded);
        if (map.containsKey('type') && map.containsKey('name')) {
          return map;
        }
      }
    } catch (_) {}
    return null;
  }

  // --- Profile YAML Helpers ---

  /// Reads profile YAML and extracts existing proxies as a List of Maps.
  static Future<List<Map<String, dynamic>>> getProfileProxies(Profile profile) async {
    try {
      final file = await profile.getFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final yaml = loadYaml(content);
      if (yaml is Map && yaml['proxies'] is List) {
        final proxies = <Map<String, dynamic>>[];
        for (final p in yaml['proxies']) {
          if (p is Map) {
            proxies.add(Map<String, dynamic>.from(p));
          }
        }
        return proxies;
      }
    } catch (e) {
      commonPrint.log('ManualProxyHelper.getProfileProxies error: $e');
    }
    return [];
  }

  /// Appends or updates proxies in a Profile's YAML file.
  static Future<Profile> addOrUpdateProxiesToProfile(
    Profile profile,
    List<Map<String, dynamic>> newProxies,
  ) async {
    final file = await profile.getFile();
    String content = await file.exists() ? await file.readAsString() : '';

    Map<String, dynamic> configMap = {};
    if (content.trim().isNotEmpty) {
      try {
        final loaded = loadYaml(content);
        if (loaded is Map) {
          configMap = deepConvertYamlMap(loaded);
        }
      } catch (_) {}
    }

    // Ensure proxies list
    final List<dynamic> currentProxies = configMap['proxies'] is List
        ? List<dynamic>.from(configMap['proxies'] as List)
        : <dynamic>[];

    final newNames = <String>[];
    for (final newP in newProxies) {
      final pName = newP['name']?.toString() ?? '';
      if (pName.isEmpty) continue;
      newNames.add(pName);
      // Remove existing proxy with same name if any
      currentProxies.removeWhere((item) => item is Map && item['name'] == pName);
      currentProxies.add(newP);
    }
    configMap['proxies'] = currentProxies;

    // Ensure proxy-groups list has standard groups containing these proxies
    if (configMap['proxy-groups'] is! List || (configMap['proxy-groups'] as List).isEmpty) {
      configMap['proxy-groups'] = [
        {
          'name': 'PROXY',
          'type': 'select',
          'proxies': [...newNames, 'DIRECT'],
        }
      ];
    } else {
      final groups = configMap['proxy-groups'] as List;
      for (final g in groups) {
        if (g is Map && (g['type'] == 'select' || g['type'] == 'url-test' || g['type'] == 'fallback')) {
          final pList = g['proxies'] is List ? List<dynamic>.from(g['proxies'] as List) : <dynamic>[];
          for (final n in newNames) {
            if (!pList.contains(n)) {
              pList.insert(0, n);
            }
          }
          g['proxies'] = pList;
        }
      }
    }

    // Ensure basic rules
    if (configMap['rules'] is! List && configMap['rule'] is! List) {
      configMap['rules'] = ['MATCH,PROXY'];
    }

    final newYaml = await encodeYamlTask(configMap);
    final updatedProfile = await profile.saveFileWithString(newYaml);
    return updatedProfile;
  }

  /// Deletes a proxy from a Profile's YAML file by name.
  static Future<Profile> deleteProxyFromProfile(Profile profile, String proxyName) async {
    final file = await profile.getFile();
    String content = await file.exists() ? await file.readAsString() : '';
    if (content.trim().isEmpty) return profile;

    Map<String, dynamic> configMap = {};
    try {
      final loaded = loadYaml(content);
      if (loaded is Map) {
        configMap = deepConvertYamlMap(loaded);
      }
    } catch (_) {
      return profile;
    }

    if (configMap['proxies'] is List) {
      final list = List<dynamic>.from(configMap['proxies'] as List);
      list.removeWhere((item) => item is Map && item['name'] == proxyName);
      configMap['proxies'] = list;
    }

    if (configMap['proxy-groups'] is List) {
      for (final g in configMap['proxy-groups']) {
        if (g is Map && g['proxies'] is List) {
          final pList = List<dynamic>.from(g['proxies'] as List);
          pList.remove(proxyName);
          g['proxies'] = pList;
        }
      }
    }

    final newYaml = await encodeYamlTask(configMap);
    return await profile.saveFileWithString(newYaml);
  }

  /// Deep conversion of YamlMap/YamlList to standard Map/List
  static Map<String, dynamic> deepConvertYamlMap(Map yamlMap) {
    final map = <String, dynamic>{};
    for (final key in yamlMap.keys) {
      final value = yamlMap[key];
      map[key.toString()] = _convertYamlValue(value);
    }
    return map;
  }

  static dynamic _convertYamlValue(dynamic value) {
    if (value is Map) {
      return deepConvertYamlMap(value);
    } else if (value is List) {
      return value.map(_convertYamlValue).toList();
    }
    return value;
  }
}
