enum IpVersion {
  v4('IPv4'),
  v6('IPv6'),
  unknown('Unknown');

  final String label;
  const IpVersion(this.label);

  static IpVersion fromString(String? val) {
    if (val == null) return IpVersion.unknown;
    final lower = val.toLowerCase().trim();
    if (lower == 'v4' || lower == 'ipv4') return IpVersion.v4;
    if (lower == 'v6' || lower == 'ipv6') return IpVersion.v6;
    return IpVersion.unknown;
  }

  static IpVersion detect(String ip) {
    final clean = ip.trim();
    if (clean.contains(':')) {
      return IpVersion.v6;
    }
    if (clean.contains('.')) {
      final parts = clean.split('.');
      if (parts.length == 4 && parts.every((p) => int.tryParse(p) != null)) {
        return IpVersion.v4;
      }
    }
    return IpVersion.unknown;
  }
}

class PublicIpInfo {
  final String ip;
  final IpVersion version;
  final String? country;
  final String? countryCode;
  final String? region;
  final String? city;
  final String? isp;
  final String? asn;
  final DateTime timestamp;
  final String source;

  const PublicIpInfo({
    required this.ip,
    required this.version,
    this.country,
    this.countryCode,
    this.region,
    this.city,
    this.isp,
    this.asn,
    required this.timestamp,
    required this.source,
  });

  PublicIpInfo copyWith({
    String? ip,
    IpVersion? version,
    String? country,
    String? countryCode,
    String? region,
    String? city,
    String? isp,
    String? asn,
    DateTime? timestamp,
    String? source,
  }) {
    return PublicIpInfo(
      ip: ip ?? this.ip,
      version: version ?? this.version,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      region: region ?? this.region,
      city: city ?? this.city,
      isp: isp ?? this.isp,
      asn: asn ?? this.asn,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'version': version.name,
      if (country != null) 'country': country,
      if (countryCode != null) 'countryCode': countryCode,
      if (region != null) 'region': region,
      if (city != null) 'city': city,
      if (isp != null) 'isp': isp,
      if (asn != null) 'asn': asn,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
    };
  }

  factory PublicIpInfo.fromJson(Map<String, dynamic> json) {
    final rawIp = json['ip']?.toString().trim() ?? '';
    final rawVer = json['version']?.toString();
    final ver = rawVer != null
        ? IpVersion.fromString(rawVer)
        : IpVersion.detect(rawIp);

    DateTime ts;
    try {
      final rawTs = json['timestamp']?.toString();
      ts = rawTs != null ? DateTime.parse(rawTs) : DateTime.now();
    } catch (_) {
      ts = DateTime.now();
    }

    return PublicIpInfo(
      ip: rawIp,
      version: ver,
      country: json['country']?.toString(),
      countryCode: json['countryCode']?.toString(),
      region: json['region']?.toString(),
      city: json['city']?.toString(),
      isp: json['isp']?.toString(),
      asn: json['asn']?.toString(),
      timestamp: ts,
      source: json['source']?.toString() ?? 'unknown',
    );
  }

  @override
  String toString() {
    return 'PublicIpInfo(ip: $ip, ver: ${version.label}, country: $countryCode, isp: $isp, asn: $asn, src: $source)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublicIpInfo &&
        other.ip == ip &&
        other.version == version &&
        other.country == country &&
        other.countryCode == countryCode &&
        other.region == region &&
        other.city == city &&
        other.isp == isp &&
        other.asn == asn &&
        other.source == source;
  }

  @override
  int get hashCode => Object.hash(
    ip,
    version,
    country,
    countryCode,
    region,
    city,
    isp,
    asn,
    source,
  );
}
