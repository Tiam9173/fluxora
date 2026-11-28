import 'package:fluxora/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'optional malformed usage metadata never prevents subscription import',
    () {
      final info = SubscriptionInfo.formHString(
        'upload=12; unknown; download=20; total=1000; expire=1800000000;',
      );
      expect(info.upload, 12);
      expect(info.download, 20);
      expect(info.total, 1000);
      expect(info.expire, 1800000000);
    },
  );

  test('finite decimal values are accepted and invalid values ignored', () {
    final info = SubscriptionInfo.formHString(
      'upload=1.5; download=NaN; total=Infinity; expire=-1',
    );
    expect(info.upload, 1);
    expect(info.download, 0);
    expect(info.total, 0);
    expect(info.expire, 0);
    expect(SubscriptionInfo.formHString(null), const SubscriptionInfo());
    expect(SubscriptionInfo.formHString(''), const SubscriptionInfo());
  });

  test('out-of-range metadata does not overflow usage or expiry display', () {
    final info = SubscriptionInfo.formHString(
      'upload=1e100; download=1e100; total=1e100; expire=8640000000001',
    );
    expect(info, const SubscriptionInfo());
    expect(info.expireDesc, isNull);
  });
}
