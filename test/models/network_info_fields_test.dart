import 'dart:convert';
import 'package:fluxora/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public IP info preserves location and ASN without a risk score', () {
    final info = IpInfo.fromJson({
      'ip': '2001:db8::1',
      'asn': 64500,
      'asOrganization': 'Example Network',
      'country': 'Japan',
      'countryCode': 'JP',
      'region': 'Tokyo',
      'city': 'Tokyo',
    });
    expect(info.ip, '2001:db8::1');
    expect(info.flagCountryCode, 'JP');
    expect(info.asn, 'AS64500');
    expect(info.asName, 'Example Network');
    expect(info.province, 'Tokyo');
  });

  test(
    'missing field preferences use defaults; empty and custom selections persist',
    () {
      final original = AppSettingProps.fromJson({});
      expect(
        original.networkInfoFields,
        containsAll(['country', 'region', 'isp', 'asn', 'domain']),
      );
      for (final fields in [
        <String>{},
        {'country', 'asn'},
      ]) {
        final restored = AppSettingProps.fromJson(
          jsonDecode(
            jsonEncode(original.copyWith(networkInfoFields: fields).toJson()),
          ),
        );
        expect(restored.networkInfoFields, fields);
        expect(restored.ipReputationFields, original.ipReputationFields);
      }
    },
  );
}
