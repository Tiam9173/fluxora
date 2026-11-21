import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/proxy_icon_sets.dart';

void main() {
  test('the built-in service preset uses bundled offline assets', () {
    expect(ProxyIconSets.services, isNotEmpty);
    expect(
      ProxyIconSets.services.values.every(
        (value) => value.startsWith('asset://assets/images/platforms/'),
      ),
      isTrue,
    );
    expect(
      ProxyIconSets.services.values.every(
        (value) => value.toLowerCase().endsWith('.svg'),
      ),
      isTrue,
    );
  });
}
