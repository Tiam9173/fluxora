import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/models.dart';

/// item 6 (Bettbox 1.19.4) — the persisted bypass list is not trusted.
///
/// A bare `::1` in the Windows system-proxy bypass list makes the underlying
/// `InternetSetOption` call fail outright, leaving the system proxy **unset**
/// rather than merely misconfigured. Fluxora's own default never contains it, but
/// a user can type it, paste it, or import a config that does.
void main() {
  group('NetworkProps.fromJson drops ::1 from the bypass list', () {
    test('a bare ::1 is removed', () {
      final props = NetworkProps.fromJson({
        'systemProxy': true,
        'bypassDomain': ['localhost', '::1', '127.*'],
      });

      expect(props.bypassDomain, ['localhost', '127.*']);
      expect(props.bypassDomain, isNot(contains('::1')));
    });

    test('a list without ::1 is left untouched', () {
      final props = NetworkProps.fromJson({
        'bypassDomain': ['localhost', '127.*', '10.*'],
      });

      expect(props.bypassDomain, ['localhost', '127.*', '10.*']);
    });

    test('other IPv6-shaped entries survive', () {
      // Only the exact `::1` form is invalid for the Windows call. A bracketed
      // or CIDR form is a different string and must not be silently dropped.
      final props = NetworkProps.fromJson({
        'bypassDomain': ['[::1]', '::1/128', 'fe80::/10', '::1'],
      });

      expect(props.bypassDomain, ['[::1]', '::1/128', 'fe80::/10']);
    });

    test('several ::1 occurrences are all removed', () {
      final props = NetworkProps.fromJson({
        'bypassDomain': ['::1', 'localhost', '::1', '::1'],
      });

      expect(props.bypassDomain, ['localhost']);
    });

    test('a null payload still yields the defaults', () {
      final props = NetworkProps.fromJson(null);
      expect(props.bypassDomain, defaultBypassDomain);
    });

    test('the other fields survive the sanitising', () {
      final props = NetworkProps.fromJson({
        'systemProxy': true,
        'bypassDomain': ['::1'],
        'bypassPrivateRoute': false,
        'autoSetSystemDns': false,
      });

      expect(props.systemProxy, isTrue);
      expect(props.bypassPrivateRoute, isFalse);
      expect(props.autoSetSystemDns, isFalse);
      expect(props.bypassDomain, isEmpty);
    });
  });

  group('withoutInvalidBypassEntries', () {
    test('returns the same instance when nothing is dropped', () {
      const props = NetworkProps(bypassDomain: ['localhost']);
      expect(props.withoutInvalidBypassEntries(), same(props));
    });

    test('returns a new instance when ::1 is dropped', () {
      const props = NetworkProps(bypassDomain: ['localhost', '::1']);
      final cleaned = props.withoutInvalidBypassEntries();

      expect(cleaned.bypassDomain, ['localhost']);
      expect(cleaned, isNot(same(props)));
    });
  });
}
