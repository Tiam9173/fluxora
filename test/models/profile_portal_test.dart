import 'dart:convert';

import 'package:fluxora/common/string.dart';
import 'package:fluxora/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Profile profile({
    String portalUrl = '',
    String portalLabel = '',
    ProfilePortalSource portalSource = ProfilePortalSource.unset,
  }) {
    return Profile(
      id: 'portal-test',
      autoUpdateDuration: Duration.zero,
      portalUrl: portalUrl,
      portalLabel: portalLabel,
      portalSource: portalSource,
    );
  }

  test('portal fields survive a JSON round trip', () {
    final original = profile(
      portalUrl: 'https://example.com/renew',
      portalLabel: 'Renew',
      portalSource: ProfilePortalSource.manual,
    );

    final restored = Profile.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );

    expect(restored.portalUrl, 'https://example.com/renew');
    expect(restored.portalLabel, 'Renew');
    expect(restored.portalSource, ProfilePortalSource.manual);
  });

  test('subscription header is adopted only when no manual value exists', () {
    final unset = profile();
    expect(
      unset.withSubscriptionPortalHeader('https://example.com').portalSource,
      ProfilePortalSource.subscription,
    );

    final manual = profile(
      portalUrl: 'https://manual.example',
      portalSource: ProfilePortalSource.manual,
    );
    final unchanged = manual.withSubscriptionPortalHeader(
      'https://subscription.example',
    );
    expect(unchanged.portalUrl, 'https://manual.example');
    expect(unchanged.portalSource, ProfilePortalSource.manual);
  });

  test('invalid or missing header does not erase the current link', () {
    final current = profile(
      portalUrl: 'https://example.com',
      portalSource: ProfilePortalSource.subscription,
    );

    expect(current.withSubscriptionPortalHeader(null).portalUrl, current.portalUrl);
    expect(
      current.withSubscriptionPortalHeader('javascript:alert(1)').portalUrl,
      current.portalUrl,
    );
  });

  test('safe web URL rejects non-http schemes and embedded credentials', () {
    expect('https://example.com/path?q=1'.isSafeWebUrl, isTrue);
    expect('http://example.com'.isSafeWebUrl, isTrue);
    expect('ftp://example.com'.isSafeWebUrl, isFalse);
    expect('javascript:alert(1)'.isSafeWebUrl, isFalse);
    expect('https://user:pass@example.com'.isSafeWebUrl, isFalse);
    expect('https://exa mple.com'.isSafeWebUrl, isFalse);
    expect(''.isSafeWebUrl, isFalse);
  });

  test('subscription domain suggestion keeps scheme and host', () {
    expect(
      'https://sub.example.com/api/v1?token=x'.webUrlOrigin,
      'https://sub.example.com',
    );
    expect('https://sub.example.com:8443/a'.webUrlOrigin, 'https://sub.example.com:8443');
    expect('not a url'.webUrlOrigin, isNull);
  });
}
