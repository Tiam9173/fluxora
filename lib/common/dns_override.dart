const commonDnsList = [
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

  'alidns',
  'doh.pub',
  'dot.pub',
  'dns.pub',
  'dnspod',
  'dns.baidu',

  'dns.google',
  'cloudflare',
  'quad9',
  'opendns',
  'nextdns',
  'adguard',

  'system',
];

int hostSpecificity(String pattern) {
  if (pattern.startsWith('+.')) return 2;
  if (pattern.startsWith('.')) return 1;
  if (pattern.contains('*')) return 0;
  return 3;
}

bool matchDomainPattern(String pattern, Iterable<String> domains) {
  pattern = pattern.toLowerCase();

  if (!pattern.contains('*') && !pattern.startsWith('+.') && !pattern.startsWith('.')) {
    return domains.any((d) => d.toLowerCase() == pattern);
  }

  final domainList = domains.map((d) => d.toLowerCase()).toList();

  if (pattern.startsWith('+.')) {
    final suffix = pattern.substring(2);
    return domainList.any((domain) => domain == suffix || domain.endsWith('.$suffix'));
  }

  if (pattern.startsWith('.')) {
    final suffix = pattern.substring(1);
    return domainList.any((domain) => domain != suffix && domain.endsWith('.$suffix'));
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

List<dynamic> applyHostsToProxies(List<dynamic> proxies, Map<String, dynamic>? hosts) {
  if (hosts == null || hosts.isEmpty) return proxies;

  final hostEntries = hosts.entries
      .where((entry) =>
          (entry.value is String && (entry.value as String).isNotEmpty) ||
          (entry.value is List && (entry.value as List).isNotEmpty))
      .toList()
    ..sort((a, b) => hostSpecificity(b.key) - hostSpecificity(a.key));
  if (hostEntries.isEmpty) return proxies;

  String? targetOf(dynamic value) {
    if (value is List) {
      for (final item in value) {
        if (item is String && item.isNotEmpty) return item;
      }
      return null;
    }
    return value is String && value.isNotEmpty ? value : null;
  }

  final resolveCache = <String, String>{};

  String resolve(String server) {
    final cached = resolveCache[server];
    if (cached != null) return cached;

    final seen = <String>{};
    var current = server.toLowerCase();
    var result = server;
    while (seen.add(current)) {
      MapEntry<String, dynamic>? entry;
      for (final e in hostEntries) {
        if (matchDomainPattern(e.key, [current])) {
          entry = e;
          break;
        }
      }
      final target = entry == null ? null : targetOf(entry.value);
      if (target == null) break;
      result = target;
      current = target.toLowerCase();
    }
    resolveCache[server] = result;
    return result;
  }

  return proxies.map((proxy) {
    if (proxy is! Map) return proxy;
    final server = proxy['server'];
    if (server is! String) return proxy;
    final resolved = resolve(server);
    return resolved == server ? proxy : {...proxy, 'server': resolved};
  }).toList();
}

void applyDnsNodeOverride(
  Map<String, dynamic> rawConfig, {
  Map<String, dynamic>? originalDns,
  Map<String, dynamic>? originalHosts,
}) {
  originalDns ??= {};

  final proxyServerNameservers =
      (originalDns['proxy-server-nameserver'] as List?)?.cast<String>() ?? [];
  final listenValue = originalDns['listen'];
  final shouldRewriteByHosts = proxyServerNameservers.length == 1 &&
      listenValue is String &&
      listenValue.isNotEmpty &&
      proxyServerNameservers.any(
        (dns) => dns.toLowerCase().contains(listenValue.toLowerCase()),
      );

  final proxies = (rawConfig['proxies'] as List?) ?? const [];

  final mappedProxies =
      shouldRewriteByHosts ? applyHostsToProxies(proxies, originalHosts) : proxies;
  if (!identical(mappedProxies, proxies)) {
    rawConfig['proxies'] = mappedProxies;
  }

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
  if (shouldRewriteByHosts) {
    collectServers(mappedProxies);
  }

  final commonDnsSet = commonDnsList.toSet();
  if (shouldRewriteByHosts) {
    commonDnsSet.add(listenValue);
  }
  final commonDnsRegex = RegExp(
    commonDnsSet.map(RegExp.escape).join('|'),
    caseSensitive: false,
  );
  bool isCommonDns(String dns) => commonDnsRegex.hasMatch(dns);

  final privateDNS = <String>{};
  for (final dns in [...(originalDns['nameserver'] as List? ?? const []), ...proxyServerNameservers]) {
    final stripped = stripDnsSuffix(dns.toString());
    if (stripped.isNotEmpty && !isCommonDns(stripped)) {
      privateDNS.add(stripped);
    }
  }

  final originalPolicy = <String, dynamic>{
    ...?((originalDns['nameserver-policy'] as Map?)?.cast<String, dynamic>()),
    ...?((originalDns['proxy-server-nameserver-policy'] as Map?)?.cast<String, dynamic>()),
  };
  final proxyServerPolicy = <String, dynamic>{};
  for (final entry in originalPolicy.entries) {
    if (!matchDomainPattern(entry.key, proxyDomains)) continue;

    final value = entry.value;
    final strippedValue = value is List
        ? value.map((item) => stripDnsSuffix(item.toString())).where((item) => item.isNotEmpty).toList()
        : stripDnsSuffix(value.toString());
    if (strippedValue is List && strippedValue.isEmpty) continue;

    proxyServerPolicy[entry.key] = strippedValue;
  }

  final originalFakeIpFilter = (originalDns['fake-ip-filter'] as List?) ?? const [];
  final proxyFakeIpFilter = originalFakeIpFilter
      .where((pattern) => matchDomainPattern(pattern.toString(), proxyDomains))
      .map((pattern) => pattern.toString())
      .toList();

  final dns = (rawConfig['dns'] as Map?)?.cast<String, dynamic>();
  if (dns == null) return;

  if (privateDNS.isNotEmpty) {
    dns['proxy-server-nameserver'] = privateDNS.toList();
  }
  if (proxyServerPolicy.isNotEmpty) {
    dns['proxy-server-nameserver-policy'] = proxyServerPolicy;
  }
  if (proxyFakeIpFilter.isNotEmpty) {
    final existingFilter = (dns['fake-ip-filter'] as List?) ?? const [];
    dns['fake-ip-filter'] = [...existingFilter, ...proxyFakeIpFilter];
  }
}
