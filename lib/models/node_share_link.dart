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
    if (server.isEmpty || port.isEmpty) return null;
    final name = proxy['name']?.toString() ?? '$server:$port';

    switch (type) {
      case 'vmess':
        return _vmess(proxy, server, port, name);
      case 'vless':
        return _vless(proxy, server, port, name);
      case 'ss':
        return _ss(proxy, server, port, name);
      case 'trojan':
        return _trojan(proxy, server, port, name);
      case 'hysteria2':
        return _hysteria2(proxy, server, port, name);
      case 'socks5':
        return _userPassUri('socks5', proxy, server, port, name);
      case 'http':
        return _userPassUri('http', proxy, server, port, name);
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
    final params = <String, String>{
      if (_sni(proxy).isNotEmpty) 'sni': _sni(proxy),
      if (_isTrue(proxy['skip-cert-verify'])) 'allowInsecure': '1',
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    return 'trojan://$password@$server:$port$query#${Uri.encodeComponent(name)}';
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
}
