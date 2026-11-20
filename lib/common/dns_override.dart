import 'dart:io' show InternetAddress;

const _publicDnsAddresses = {
  '223.5.5.5',
  '223.6.6.6',
  '119.29.29.29',
  '1.12.12.12',
  '120.53.53.53',
  '114.114.114.114',
  '180.76.76.76',
  '1.2.4.8',
  '116.116.116.116',
  '101.226.4.6',
  '123.125.81.6',
  '180.184.1.1',
  '180.184.2.2',

  '1.1.1.1',
  '1.0.0.1',
  '8.8.8.8',
  '8.8.4.4',
  '9.9.9.9',
  '149.112.112.112',
  '208.67.222.222',
  '208.67.220.220',
  '94.140.14.14',
  '94.140.15.15',
  '76.76.2.0',
  '76.76.10.0',
  '185.228.168.9',
  '185.228.169.9',
  '77.88.8.8',
  '77.88.8.1',
  '156.154.70.1',
  '156.154.71.1',
};

const _publicDnsDomains = [
  'dns.alidns.com',
  'doh.pub',
  'dot.pub',
  'dns.pub',
  'doh.dnspod.cn',
  'doh.360.cn',
  'dns.baidu.com',
  'dns.google',
  'dns.google.com',
  'cloudflare-dns.com',
  'quad9.net',
  'opendns.com',
  'dns.nextdns.io',
  'dns1.nextdns.io',
  'dns2.nextdns.io',
  'dns.adguard.com',
  'dns-family.adguard.com',
  'dns-unfiltered.adguard.com',
  'adguard-dns.com',
];

Uri? _dnsEndpoint(String value) {
  if (value.contains('://')) return Uri.tryParse(value);
  if (value.contains(':') && InternetAddress.tryParse(value) != null) {
    return Uri(scheme: 'udp', host: value);
  }
  return Uri.tryParse('udp://$value');
}

String _dnsHost(Uri endpoint) {
  final host = endpoint.host;
  return host.endsWith('.') ? host.substring(0, host.length - 1) : host;
}

bool _isSystemDns(Uri endpoint) {
  return switch (endpoint.scheme) {
    'system' => true,
    'dhcp' ||
    'udp' ||
    'tcp' ||
    'tls' ||
    'https' ||
    'http' ||
    'quic' => _dnsHost(endpoint) == 'system',
    _ => false,
  };
}

bool _isPublicDns(Uri endpoint) {
  final host = _dnsHost(endpoint);
  return switch (endpoint.scheme) {
    'udp' || 'tcp' || 'tls' || 'https' || 'http' || 'quic' =>
      _publicDnsAddresses.contains(host) ||
          _publicDnsDomains.any(
            (domain) => host == domain || host.endsWith('.$domain'),
          ),
    _ => false,
  };
}

bool _usesDnsListener(Uri? endpoint, Uri? listener) {
  if (endpoint == null ||
      listener == null ||
      !listener.hasPort ||
      (endpoint.scheme != 'udp' && endpoint.scheme != 'tcp')) {
    return false;
  }
  final port = endpoint.hasPort ? endpoint.port : 53;
  if (port != listener.port) return false;

  final host = _dnsHost(endpoint);
  final listenHost = _dnsHost(listener);
  if (host == listenHost) return true;
  final address = InternetAddress.tryParse(host);
  if (listenHost.isEmpty || listenHost == '0.0.0.0' || listenHost == '::') {
    return host == 'localhost' || (address?.isLoopback ?? false);
  }
  return address != null && address == InternetAddress.tryParse(listenHost);
}

bool matchDomainPattern(String pattern, Iterable<String> domains) {
  pattern = pattern.toLowerCase();

  if (!pattern.contains('*') &&
      !pattern.startsWith('+.') &&
      !pattern.startsWith('.')) {
    return domains.any((d) => d.toLowerCase() == pattern);
  }

  final domainList = domains.map((d) => d.toLowerCase()).toList();

  if (pattern.startsWith('+.')) {
    final suffix = pattern.substring(2);
    return domainList.any(
      (domain) => domain == suffix || domain.endsWith('.$suffix'),
    );
  }

  if (pattern.startsWith('.')) {
    final suffix = pattern.substring(1);
    return domainList.any(
      (domain) => domain != suffix && domain.endsWith('.$suffix'),
    );
  }

  final patternParts = pattern.split('.');
  return domainList.any((domain) {
    final domainParts = domain.split('.');
    return patternParts.length == domainParts.length &&
        patternParts.indexed.every(
          (entry) => entry.$2 == '*' || entry.$2 == domainParts[entry.$1],
        );
  });
}

String stripDnsSuffix(String dns) {
  final hashIndex = dns.indexOf('#');
  if (hashIndex == -1) return dns;
  final suffix = dns.substring(hashIndex + 1).toLowerCase().trim();
  if (suffix == 'direct' || suffix.startsWith('direct&')) return dns;
  return dns.substring(0, hashIndex);
}

void applyDnsNodeOverride(
  Map<String, dynamic> rawConfig, {
  Map<String, dynamic>? originalDns,
  bool keepSubscriptionPublicNodeResolvers = false,
}) {
  originalDns ??= {};

  final proxyServerNameservers =
      (originalDns['proxy-server-nameserver'] as List?)?.cast<String>() ?? [];
  final listenValue = originalDns['listen'];
  final listener = listenValue is String ? _dnsEndpoint(listenValue) : null;
  final dns = (rawConfig['dns'] as Map?)?.cast<String, dynamic>();
  if (dns == null) return;
  final newListenValue = dns['listen'];
  final newListener = newListenValue is String
      ? _dnsEndpoint(newListenValue)
      : null;
  bool usesLocalListener(Uri? endpoint) =>
      _usesDnsListener(endpoint, listener) ||
      _usesDnsListener(endpoint, newListener);
  final proxies = (rawConfig['proxies'] as List?) ?? const [];
  // The core resolves hosts while retaining server names for TLS verification.

  final proxyDomains = <String>{};
  void collectServers(List<dynamic> list) {
    for (final proxy in list) {
      if (proxy is Map) {
        final server = proxy['server'];
        if (server is String) proxyDomains.add(server.toLowerCase());
      }
    }
  }

  collectServers(proxies);

  final nodeResolvers = <String>{};
  void collectResolver(String value, {required bool explicit}) {
    final stripped = stripDnsSuffix(value.trim());
    if (stripped.isEmpty) return;
    final endpoint = _dnsEndpoint(stripped);
    if (endpoint == null ||
        _isSystemDns(endpoint) ||
        (!(explicit && keepSubscriptionPublicNodeResolvers) &&
            _isPublicDns(endpoint)) ||
        usesLocalListener(endpoint)) {
      return;
    }
    nodeResolvers.add(stripped);
  }

  for (final dns in originalDns['nameserver'] as List? ?? const []) {
    collectResolver(dns.toString(), explicit: false);
  }
  for (final dns in proxyServerNameservers) {
    collectResolver(dns, explicit: true);
  }

  final originalPolicy = <String, dynamic>{
    ...?((originalDns['nameserver-policy'] as Map?)?.cast<String, dynamic>()),
    ...?((originalDns['proxy-server-nameserver-policy'] as Map?)
        ?.cast<String, dynamic>()),
  };
  final proxyServerPolicy = <String, dynamic>{};
  for (final entry in originalPolicy.entries) {
    if (!matchDomainPattern(entry.key, proxyDomains)) continue;

    final value = entry.value;
    final servers = (value is List ? value : [value])
        .map((item) => stripDnsSuffix(item.toString().trim()))
        .where(
          (item) => item.isNotEmpty && !usesLocalListener(_dnsEndpoint(item)),
        )
        .toList();
    if (servers.isEmpty) continue;
    proxyServerPolicy[entry.key] = value is List ? servers : servers.single;
  }

  final originalFakeIpFilter =
      (originalDns['fake-ip-filter'] as List?) ?? const [];
  final proxyFakeIpFilter = originalFakeIpFilter
      .where((pattern) => matchDomainPattern(pattern.toString(), proxyDomains))
      .map((pattern) => pattern.toString())
      .toList();

  if (nodeResolvers.isNotEmpty) {
    dns['proxy-server-nameserver'] = nodeResolvers.toList();
  }
  if (proxyServerPolicy.isNotEmpty) {
    dns['proxy-server-nameserver-policy'] = proxyServerPolicy;
  }
  if (proxyFakeIpFilter.isNotEmpty) {
    final existingFilter = (dns['fake-ip-filter'] as List?) ?? const [];
    dns['fake-ip-filter'] = [...existingFilter, ...proxyFakeIpFilter];
  }
}
