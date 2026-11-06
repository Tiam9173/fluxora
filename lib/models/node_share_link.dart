import 'dart:convert';

/// 把节点配置反向序列化成分享链接。
///
/// 导出的链接必须能被 `ManualProxyHelper.parseMultipleLinks` 读回来，否则就是
/// 一串"看着正常、粘回去却导入失败"的假数据——那比没有导出更糟。所以这里只
/// 覆盖解析器确实支持的协议，其余返回 null 让调用方跳过，而不是硬编一个。
class NodeShareLink {
  /// 返回 [proxy] 对应的分享链接；不支持的协议返回 null。
  ///
  /// [proxy] 就是订阅里的节点 Map（`type` / `server` / `port` / ...），
  /// 和 config.yaml 里 `proxies:` 下的结构一致。
  static String? fromProxy(Map proxy) {
    final type = proxy['type']?.toString().toLowerCase() ?? '';
    final server = proxy['server']?.toString() ?? '';
    final port = proxy['port']?.toString() ?? '';
    final name = proxy['name']?.toString() ?? '$server:$port';
    // `direct` has no address at all, so it has to be answered before the
    // server/port guard that every other protocol needs.
    if (type == 'direct') return 'direct://#${Uri.encodeComponent(name)}';
    if (server.isEmpty || port.isEmpty) return null;

    switch (type) {
      case 'vmess':
        return _vmess(proxy, server, port, name);
      case 'vless':
        return _vless(proxy, server, port, name);
      case 'ss':
        return _ss(proxy, server, port, name);
      case 'ssr':
        return _ssr(proxy, server, port, name);
      case 'trojan':
        return _trojan(proxy, server, port, name);
      case 'hysteria':
        return _hysteria(proxy, server, port, name);
      case 'hysteria2':
        return _hysteria2(proxy, server, port, name);
      case 'tuic':
        return _tuic(proxy, server, port, name);
      case 'anytls':
        return _anytls(proxy, server, port, name);
      case 'snell':
        return _snell(proxy, server, port, name);
      case 'ssh':
        return _ssh(proxy, server, port, name);
      case 'shadow-tls':
        return _shadowTls(proxy, server, port, name);
      case 'wireguard':
        return _wireguard(proxy, server, port, name);
      case 'socks5':
        return _userPassUri('socks5', proxy, server, port, name);
      case 'http':
        // `https://` is the only way the parser learns a plain HTTP proxy is
        // wrapped in TLS, so a `tls: true` node must not export as `http://`.
        return _userPassUri(
          _isTrue(proxy['tls']) ? 'https' : 'http',
          proxy,
          server,
          port,
          name,
        );
      default:
        return null;
    }
  }

  /// 批量导出：跳过不支持的协议，返回可直接粘贴到导入框的文本。
  static String exportAll(Iterable<Map> proxies) {
    final lines = <String>[];
    for (final proxy in proxies) {
      final link = fromProxy(proxy);
      if (link != null && link.isNotEmpty) lines.add(link);
    }
    return lines.join('\n');
  }

  // ── 各协议 ──────────────────────────────────────────────────────────

  static String _vmess(
    Map proxy,
    String server,
    String port,
    String name,
  ) {
    final obj = <String, dynamic>{
      'v': '2',
      'ps': name,
      'add': server,
      'port': port,
      'id': proxy['uuid']?.toString() ?? '',
      'aid': proxy['alterId']?.toString() ?? '0',
      'scy': proxy['cipher']?.toString() ?? 'auto',
      'net': proxy['network']?.toString() ?? 'tcp',
      'type': 'none',
      'host': proxy['ws-opts']?['headers']?['Host']?.toString() ?? '',
      'path': proxy['ws-opts']?['path']?.toString() ?? '',
      'tls': _isTrue(proxy['tls']) ? 'tls' : '',
      'sni': proxy['servername']?.toString() ?? '',
      'alpn': '',
    };
    return 'vmess://${base64Encode(utf8.encode(jsonEncode(obj)))}';
  }

  static String _vless(
    Map proxy,
    String server,
    String port,
    String name,
  ) {
    final params = <String, String>{
      'encryption': proxy['encryption']?.toString() ?? 'none',
      'type': proxy['network']?.toString() ?? 'tcp',
      if (_isTrue(proxy['tls'])) 'security': _securityOf(proxy),
      if (_sni(proxy).isNotEmpty) 'sni': _sni(proxy),
      if (proxy['flow']?.toString().isNotEmpty == true)
        'flow': proxy['flow'].toString(),
      if (proxy['client-fingerprint']?.toString().isNotEmpty == true)
        'fp': proxy['client-fingerprint'].toString(),
      if (_realityPublicKey(proxy).isNotEmpty)
        'pbk': _realityPublicKey(proxy),
      if (_realityShortId(proxy).isNotEmpty) 'sid': _realityShortId(proxy),
      if (_isTrue(proxy['skip-cert-verify'])) 'allowInsecure': '1',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final uuid = proxy['uuid']?.toString() ?? '';
    return 'vless://$uuid@$server:$port?$query#${Uri.encodeComponent(name)}';
  }

  static String _ss(Map proxy, String server, String port, String name) {
    final method = proxy['cipher']?.toString() ?? '';
    final password = proxy['password']?.toString() ?? '';
    if (method.isEmpty) return '';
    // SIP002：用户信息整体 base64，避免密码里的特殊字符破坏 URI。
    final userInfo = base64Encode(utf8.encode('$method:$password'));
    return 'ss://$userInfo@$server:$port#${Uri.encodeComponent(name)}';
  }

  static String _trojan(Map proxy, String server, String port, String name) {
    final password = proxy['password']?.toString() ?? '';
    final network = proxy['network']?.toString().toLowerCase() ?? 'tcp';
    final params = <String, String>{
      if (_sni(proxy).isNotEmpty) 'sni': _sni(proxy),
      if (_isTrue(proxy['skip-cert-verify'])) 'allowInsecure': '1',
      if (network == 'ws' || network == 'grpc') 'type': network,
      if (network == 'ws') 'path': _wsPath(proxy),
      if (network == 'ws') 'host': _wsHost(proxy),
      if (network == 'grpc') 'path': _grpcServiceName(proxy),
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    return 'trojan://$password@$server:$port$query#${Uri.encodeComponent(name)}';
  }

  /// hysteria v1。注意它和 hysteria2 不是一个协议：认证字段是 `auth`/`auth_str`，
  /// 带宽用 `up`/`down` 描述，obfs 也没有单独的 password。
  static String _hysteria(
    Map proxy,
    String server,
    String port,
    String name,
  ) {
    final auth = proxy['auth_str']?.toString() ??
        proxy['auth-str']?.toString() ??
        proxy['auth']?.toString() ??
        proxy['password']?.toString() ??
        '';
    final params = <String, String>{
      if (auth.isNotEmpty) 'auth': auth,
      if (_sni(proxy).isNotEmpty) 'sni': _sni(proxy),
      if (_bandwidth(proxy['up']).isNotEmpty) 'up': _bandwidth(proxy['up']),
      if (_bandwidth(proxy['down']).isNotEmpty)
        'down': _bandwidth(proxy['down']),
      if (proxy['obfs']?.toString().isNotEmpty == true)
        'obfs': proxy['obfs'].toString(),
      if (proxy['protocol']?.toString().isNotEmpty == true)
        'protocol': proxy['protocol'].toString(),
      if (_alpn(proxy).isNotEmpty) 'alpn': _alpn(proxy),
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    return 'hysteria://$server:$port$query#${Uri.encodeComponent(name)}';
  }

  static String _tuic(Map proxy, String server, String port, String name) {
    final uuid = proxy['uuid']?.toString() ?? '';
    final password = proxy['password']?.toString() ?? '';
    if (uuid.isEmpty) return '';
    final params = <String, String>{
      if (_sni(proxy).isNotEmpty) 'sni': _sni(proxy),
      if (proxy['congestion-controller']?.toString().isNotEmpty == true)
        'congestion_control': proxy['congestion-controller'].toString(),
      if (proxy['udp-relay-mode']?.toString().isNotEmpty == true)
        'udp_relay_mode': proxy['udp-relay-mode'].toString(),
      if (_alpn(proxy).isNotEmpty) 'alpn': _alpn(proxy),
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    return 'tuic://$uuid:$password@$server:$port$query'
        '#${Uri.encodeComponent(name)}';
  }

  static String _anytls(Map proxy, String server, String port, String name) {
    final password = proxy['password']?.toString() ?? '';
    if (password.isEmpty) return '';
    final params = <String, String>{
      if (_sni(proxy).isNotEmpty) 'sni': _sni(proxy),
      if (_isTrue(proxy['skip-cert-verify'])) 'insecure': '1',
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    return 'anytls://$password@$server:$port$query'
        '#${Uri.encodeComponent(name)}';
  }

  static String _snell(Map proxy, String server, String port, String name) {
    final psk = proxy['psk']?.toString() ?? '';
    if (psk.isEmpty) return '';
    final obfs = proxy['obfs-opts'];
    final obfsMode = obfs is Map ? (obfs['mode']?.toString() ?? '') : '';
    final obfsHost = obfs is Map ? (obfs['host']?.toString() ?? '') : '';
    final params = <String, String>{
      if (proxy['version']?.toString().isNotEmpty == true)
        'version': proxy['version'].toString(),
      if (obfsMode.isNotEmpty && obfsMode != 'off') 'obfs': obfsMode,
      if (obfsHost.isNotEmpty) 'host': obfsHost,
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    return 'snell://$psk@$server:$port$query#${Uri.encodeComponent(name)}';
  }

  static String _ssh(Map proxy, String server, String port, String name) {
    final user = proxy['username']?.toString() ?? '';
    final pass = proxy['password']?.toString() ?? '';
    // 解析器会把空用户名默认成 `root`，导出时静默改掉身份比不导出更糟。
    if (user.isEmpty) return '';
    final auth = pass.isEmpty
        ? '${Uri.encodeComponent(user)}@'
        : '${Uri.encodeComponent(user)}:${Uri.encodeComponent(pass)}@';
    return 'ssh://$auth$server:$port#${Uri.encodeComponent(name)}';
  }

  static String _shadowTls(
    Map proxy,
    String server,
    String port,
    String name,
  ) {
    final password = proxy['password']?.toString() ?? '';
    if (password.isEmpty) return '';
    final params = <String, String>{
      if (_sni(proxy).isNotEmpty) 'sni': _sni(proxy),
      if (proxy['version']?.toString().isNotEmpty == true)
        'version': proxy['version'].toString(),
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    return 'shadow-tls://$password@$server:$port$query'
        '#${Uri.encodeComponent(name)}';
  }

  static String _wireguard(
    Map proxy,
    String server,
    String port,
    String name,
  ) {
    final privateKey = proxy['private-key']?.toString() ?? '';
    if (privateKey.isEmpty) return '';
    final params = <String, String>{
      if (proxy['public-key']?.toString().isNotEmpty == true)
        'public_key': proxy['public-key'].toString(),
      if (_ipOf(proxy).isNotEmpty) 'ip': _ipOf(proxy),
      if (proxy['preshared-key']?.toString().isNotEmpty == true)
        'preshared_key': proxy['preshared-key'].toString(),
      if (proxy['reserved'] is List)
        'reserved': (proxy['reserved'] as List).join(','),
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    return 'wireguard://$privateKey@$server:$port$query'
        '#${Uri.encodeComponent(name)}';
  }

  /// SSR 的链接体是一段 base64，里面再套 base64（密码、备注、obfs/proto 参数）。
  /// 所有内层 base64 都要按 query 组件编码，否则里面的 `+` 会被读成空格。
  static String _ssr(Map proxy, String server, String port, String name) {
    final method = proxy['cipher']?.toString() ?? '';
    final password = proxy['password']?.toString() ?? '';
    final protocol = proxy['protocol']?.toString() ?? 'origin';
    final obfs = proxy['obfs']?.toString() ?? 'plain';
    if (method.isEmpty) return '';
    final passwordB64 = base64Encode(utf8.encode(password));
    final params = <String>[
      'remarks=${Uri.encodeQueryComponent(base64Encode(utf8.encode(name)))}',
      if (proxy['obfs-param']?.toString().isNotEmpty == true)
        'obfsparam=${Uri.encodeQueryComponent(base64Encode(utf8.encode(proxy['obfs-param'].toString())))}',
      if (proxy['protocol-param']?.toString().isNotEmpty == true)
        'protoparam=${Uri.encodeQueryComponent(base64Encode(utf8.encode(proxy['protocol-param'].toString())))}',
    ];
    final body =
        '$server:$port:$protocol:$method:$obfs:$passwordB64/?${params.join('&')}';
    return 'ssr://${base64Encode(utf8.encode(body))}';
  }

  static String _hysteria2(
    Map proxy,
    String server,
    String port,
    String name,
  ) {
    final auth = proxy['password']?.toString() ??
        proxy['auth']?.toString() ??
        proxy['auth-str']?.toString() ??
        '';
    final params = <String, String>{
      if (_sni(proxy).isNotEmpty) 'sni': _sni(proxy),
      if (_isTrue(proxy['skip-cert-verify'])) 'insecure': '1',
      if (proxy['obfs']?.toString().isNotEmpty == true)
        'obfs': proxy['obfs'].toString(),
      if (proxy['obfs-password']?.toString().isNotEmpty == true)
        'obfs-password': proxy['obfs-password'].toString(),
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    return 'hysteria2://$auth@$server:$port$query#${Uri.encodeComponent(name)}';
  }

  static String _userPassUri(
    String scheme,
    Map proxy,
    String server,
    String port,
    String name,
  ) {
    final user = proxy['username']?.toString() ?? '';
    final pass = proxy['password']?.toString() ?? '';
    final auth = user.isEmpty
        ? ''
        : '${Uri.encodeComponent(user)}:${Uri.encodeComponent(pass)}@';
    return '$scheme://$auth$server:$port#${Uri.encodeComponent(name)}';
  }

  // ── 小工具 ──────────────────────────────────────────────────────────

  static bool _isTrue(Object? value) =>
      value == true || value?.toString().toLowerCase() == 'true';

  static String _sni(Map proxy) =>
      proxy['servername']?.toString() ??
      proxy['sni']?.toString() ??
      '';

  static String _securityOf(Map proxy) =>
      _realityPublicKey(proxy).isNotEmpty ? 'reality' : 'tls';

  static String _realityPublicKey(Map proxy) {
    final opts = proxy['reality-opts'];
    return opts is Map ? (opts['public-key']?.toString() ?? '') : '';
  }

  static String _realityShortId(Map proxy) {
    final opts = proxy['reality-opts'];
    return opts is Map ? (opts['short-id']?.toString() ?? '') : '';
  }

  static Map? _wsOpts(Map proxy) {
    final opts = proxy['ws-opts'];
    return opts is Map ? opts : null;
  }

  static String _wsPath(Map proxy) => _wsOpts(proxy)?['path']?.toString() ?? '';

  static String _wsHost(Map proxy) {
    final headers = _wsOpts(proxy)?['headers'];
    if (headers is Map) return headers['Host']?.toString() ?? '';
    return '';
  }

  static String _grpcServiceName(Map proxy) {
    final opts = proxy['grpc-opts'];
    if (opts is Map) return opts['grpc-service-name']?.toString() ?? '';
    return '';
  }

  /// 解析器读的 `alpn` 是逗号分隔字符串，节点里存的是列表。
  static String _alpn(Map proxy) {
    final alpn = proxy['alpn'];
    if (alpn is List) return alpn.map((e) => e.toString()).join(',');
    return alpn?.toString() ?? '';
  }

  /// hysteria 的带宽既可能写成 `30`，也可能写成 `30 Mbps`。解析器只认带
  /// `bps` 的形式（否则它会自己补一个 ` Mbps`），这里保持原样即可。
  static String _bandwidth(Object? value) => value?.toString() ?? '';

  /// WireGuard 的 `ip` 可能是字符串也可能是列表，解析器两种都不拒绝。
  static String _ipOf(Map proxy) {
    final ip = proxy['ip'];
    if (ip is List) return ip.map((e) => e.toString()).join(',');
    return ip?.toString() ?? '';
  }
}
