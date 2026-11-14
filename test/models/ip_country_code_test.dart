import 'package:fluxora/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IPIP country names resolve beyond China', () {
    for (final (name, code) in [
      ('中国', 'CN'),
      ('日本', 'JP'),
      ('美国', 'US'),
      ('新加坡', 'SG'),
      ('紐西蘭', 'NZ'),
      ('São Tomé & Príncipe', 'ST'),
    ]) {
      final info = IpInfo.fromJson({
        'ret': 'ok',
        'data': {
          'ip': '192.0.2.1',
          'location': [name],
        },
      });
      expect(info.flagCountryCode, code, reason: name);
      expect(info.country, name);
    }
  });

  test('a fallback can fill only a missing code for the same IP', () {
    const primary = IpInfo(ip: '192.0.2.1', countryCode: 'ZZ', isp: 'Primary');
    const fallback = IpInfo(ip: '192.0.2.1', countryCode: ' sg ');
    expect(primary.flagCountryCode, isNull);
    expect(primary.withCountryCodeFrom(fallback).flagCountryCode, 'SG');
    expect(primary.withCountryCodeFrom(fallback).isp, 'Primary');
    expect(
      primary.withCountryCodeFrom(fallback.copyWith(ip: '192.0.2.2')),
      same(primary),
    );
    final known = primary.copyWith(countryCode: 'jp');
    expect(known.withCountryCodeFrom(fallback), same(known));
  });
}
