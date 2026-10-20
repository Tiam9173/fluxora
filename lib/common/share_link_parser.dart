import 'dart:convert';

/// 把分享链接解析成 mihomo 的 `proxies` 条目。
///
/// 只解析 mihomo 真正支持的协议：ss / vmess / vless / trojan / hysteria2 / tuic。
/// Naive、Juicity、Mieru、SSH 这些是 sing-box 才有的，写进配置内核会直接报错。
///
/// 解析失败返回 null，由调用方提示用户——宁可什么都不加，也不要塞一个坏节点
/// 进去让整个配置加载失败。
Map<String, dynamic>? parseShareLink(String raw) {
  final input = raw.trim();
  if (input.isEmpty) return null;
  final scheme = input.split('://').first.toLowerCase();
  try {
    return switch (scheme) {
      'ss' => _parseSs(input),
      'vmess' => _parseVmess(input),
      'vless' => _parseVless(input),
      'trojan' => _parseTrojan(input),
      'hysteria2' || 'hy2' => _parseHysteria2(input),
      'tuic' => _parseTuic(input),
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

/// 分享链接里的 base64 可能是无填充的标准编码，也可能是 url-safe 变体。
String _decodeBase64(String value) {
  var text = value.replaceAll('-', '+').replaceAll('_', '/');
  while (text.length % 4 != 0) {
    text += '=';
  }
  return utf8.decode(base64.decode(text));
}

Map<String, dynamic>? _parseSs(String input) {
  // 两种形式：
  //   ss://base64(method:pass)@host:port#name
  //   ss://base64(method:pass@host:port)#name
  final body = input.substring('ss://'.length);
  final hash = body.indexOf('#');
  final name = hash >= 0
      ? Uri.decodeComponent(body.substring(hash + 1))
      : '手动节点';
  final main = hash >= 0 ? body.substring(0, hash) : body;
  final query = main.indexOf('?');
  final withoutQuery = query >= 0 ? main.substring(0, query) : main;

  String method;
  String password;
  String hostPort;
  if (withoutQuery.contains('@')) {
    final at = withoutQuery.lastIndexOf('@');
    final cred = _decodeBase64(withoutQuery.substring(0, at));
    hostPort = withoutQuery.substring(at + 1);
    final sep = cred.indexOf(':');
    if (sep < 0) return null;
    method = cred.substring(0, sep);
    password = cred.substring(sep + 1);
  } else {
    final decoded = _decodeBase64(withoutQuery);
    final at = decoded.lastIndexOf('@');
    if (at < 0) return null;
    hostPort = decoded.substring(at + 1);
    final cred = decoded.substring(0, at);
    final sep = cred.indexOf(':');
    if (sep < 0) return null;
    method = cred.substring(0, sep);
    password = cred.substring(sep + 1);
  }
  final host = _splitHost(hostPort);
  if (host == null) return null;
  return {
    'name': name,
    'type': 'ss',
    'server': host.$1,
    'port': host.$2,
    'cipher': method,
    'password': password,
    'udp': true,
  };
}

Map<String, dynamic>? _parseVmess(String input) {
  final payload = input.substring('vmess://'.length);
  final json = jsonDecode(_decodeBase64(payload));
  if (json is! Map) return null;
  final server = json['add']?.toString();
  final port = int.tryParse(json['port']?.toString() ?? '');
  if (server == null || port == null) return null;

  final result = <String, dynamic>{
    'name': json['ps']?.toString().isNotEmpty == true
        ? json['ps'].toString()
        : '手动节点',
    'type': 'vmess',
    'server': server,
    'port': port,
    'uuid': json['id']?.toString() ?? '',
    'alterId': int.tryParse(json['aid']?.toString() ?? '0') ?? 0,
    'cipher': json['scy']?.toString().isNotEmpty == true
        ? json['scy'].toString()
        : 'auto',
    'udp': true,
  };
  final network = json['net']?.toString();
  if (network != null && network.isNotEmpty && network != 'tcp') {
    result['network'] = network;
  }
  final tls = json['tls']?.toString();
  if (tls == 'tls') {
    result['tls'] = true;
    final sni = json['sni']?.toString();
    if (sni != null && sni.isNotEmpty) result['servername'] = sni;
  }
  final path = json['path']?.toString();
  if (path != null && path.isNotEmpty) {
    result['ws-opts'] = {
      'path': path,
      if (json['host']?.toString().isNotEmpty == true)
        'headers': {'Host': json['host'].toString()},
    };
  }
  return result;
}

Map<String, dynamic>? _parseVless(String input) {
  final uri = Uri.tryParse(input);
  if (uri == null || uri.host.isEmpty) return null;
  final query = uri.queryParameters;
  final result = <String, dynamic>{
    'name': _fragmentName(uri, '手动节点'),
    'type': 'vless',
    'server': uri.host,
    'port': uri.hasPort ? uri.port : 443,
    'uuid': uri.userInfo,
    'udp': true,
  };
  _applyTransport(result, query);
  _applyTls(result, query, uri.host);
  return result;
}

Map<String, dynamic>? _parseTrojan(String input) {
  final uri = Uri.tryParse(input);
  if (uri == null || uri.host.isEmpty) return null;
  final result = <String, dynamic>{
    'name': _fragmentName(uri, '手动节点'),
    'type': 'trojan',
    'server': uri.host,
    'port': uri.hasPort ? uri.port : 443,
    'password': uri.userInfo,
    'udp': true,
  };
  _applyTransport(result, uri.queryParameters);
  _applyTls(result, uri.queryParameters, uri.host);
  return result;
}

Map<String, dynamic>? _parseHysteria2(String input) {
  final uri = Uri.tryParse(input);
  if (uri == null || uri.host.isEmpty) return null;
  final query = uri.queryParameters;
  final result = <String, dynamic>{
    'name': _fragmentName(uri, '手动节点'),
    'type': 'hysteria2',
    'server': uri.host,
    'port': uri.hasPort ? uri.port : 443,
    'password': uri.userInfo,
  };
  final sni = query['sni'] ?? query['peer'];
  if (sni != null && sni.isNotEmpty) result['sni'] = sni;
  if (query['insecure'] == '1') result['skip-cert-verify'] = true;
  final obfs = query['obfs'];
  if (obfs != null && obfs.isNotEmpty) {
    result['obfs'] = obfs;
    final obfsPassword = query['obfs-password'];
    if (obfsPassword != null && obfsPassword.isNotEmpty) {
      result['obfs-password'] = obfsPassword;
    }
  }
  return result;
}

Map<String, dynamic>? _parseTuic(String input) {
  final uri = Uri.tryParse(input);
  if (uri == null || uri.host.isEmpty) return null;
  final query = uri.queryParameters;
  final userInfo = uri.userInfo.split(':');
  if (userInfo.isEmpty || userInfo.first.isEmpty) return null;
  final result = <String, dynamic>{
    'name': _fragmentName(uri, '手动节点'),
    'type': 'tuic',
    'server': uri.host,
    'port': uri.hasPort ? uri.port : 443,
    'uuid': userInfo.first,
    if (userInfo.length > 1) 'password': userInfo[1],
  };
  final sni = query['sni'];
  if (sni != null && sni.isNotEmpty) result['sni'] = sni;
  if (query['insecure'] == '1') result['skip-cert-verify'] = true;
  final alpn = query['alpn'];
  if (alpn != null && alpn.isNotEmpty) result['alpn'] = alpn.split(',');
  return result;
}

String _fragmentName(Uri uri, String fallback) {
  if (uri.fragment.isEmpty) return fallback;
  return Uri.decodeComponent(uri.fragment);
}

/// ws / grpc / http 这些传输层选项，vmess 和 vless 的写法基本一致。
void _applyTransport(Map<String, dynamic> result, Map<String, String> query) {
  final type = query['type'];
  if (type != null && type.isNotEmpty && type != 'tcp') {
    result['network'] = type;
  }
  if (type == 'ws') {
    final host = query['host'];
    result['ws-opts'] = {
      if (query['path']?.isNotEmpty == true) 'path': query['path'],
      if (host != null && host.isNotEmpty) 'headers': {'Host': host},
    };
  } else if (type == 'grpc') {
    result['grpc-opts'] = {
      if (query['serviceName']?.isNotEmpty == true)
        'grpc-service-name': query['serviceName'],
    };
  }
}

void _applyTls(
  Map<String, dynamic> result,
  Map<String, String> query,
  String host,
) {
  final security = query['security'];
  if (security == 'tls' || security == 'reality') {
    result['tls'] = true;
    final sni = query['sni'];
    if (sni != null && sni.isNotEmpty) {
      result['servername'] = sni;
    } else {
      result['servername'] = host;
    }
  }
  if (query['allowInsecure'] == '1' || query['insecure'] == '1') {
    result['skip-cert-verify'] = true;
  }
  final alpn = query['alpn'];
  if (alpn != null && alpn.isNotEmpty) {
    result['alpn'] = alpn.split(',');
  }
  final fingerprint = query['fp'];
  if (fingerprint != null && fingerprint.isNotEmpty) {
    result['client-fingerprint'] = fingerprint;
  }
}

/// `host:port` / `[v6]:port` → (host, port)
(String, int)? _splitHost(String hostPort) {
  if (hostPort.startsWith('[')) {
    final end = hostPort.indexOf(']');
    if (end < 0) return null;
    final host = hostPort.substring(1, end);
    final rest = hostPort.substring(end + 1);
    final port = int.tryParse(rest.replaceFirst(':', ''));
    return port == null ? null : (host, port);
  }
  final sep = hostPort.lastIndexOf(':');
  if (sep < 0) return null;
  final port = int.tryParse(hostPort.substring(sep + 1));
  if (port == null) return null;
  return (hostPort.substring(0, sep), port);
}
