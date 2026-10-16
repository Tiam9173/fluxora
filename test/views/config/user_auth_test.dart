import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/views/config/user_auth.dart';

/// item 6 (Bettbox 1.19.3) — LAN proxy credentials.
///
/// Covers the parts that decide what actually reaches the config: the defaults,
/// the JSON round-trip, and the `user:password` encoding. The dialog's form
/// validation is Flutter's own `TextFormField` machinery plus these helpers.
void main() {
  group('defaults and empty-value compatibility', () {
    test('a fresh config asks for no credentials', () {
      // This is what keeps every existing user unaffected: no credentials means
      // the config output skips the key entirely.
      const config = ClashConfig();
      expect(config.authentication, isEmpty);
    });

    test('loopback is exempt by default', () {
      const config = ClashConfig();
      expect(config.skipAuthPrefixes, defaultSkipAuthPrefixes);
      expect(config.skipAuthPrefixes, contains('127.0.0.1/8'));
      expect(config.skipAuthPrefixes, contains('::1/128'));
    });
  });

  group('deserialization from the wire format', () {
    // Note: a full `toJson`/`fromJson` round-trip is not used here. Fluxora's
    // `ClashConfig.toJson` emits `tun` as a `_Tun` instance rather than a map,
    // so `fromJson` fails on that field long before reaching `authentication`.
    // That is pre-existing and unrelated to credentials, so these tests build the
    // incoming map by hand and assert only what this feature owns.
    test('credentials are read from the `authentication` key', () {
      final config = ClashConfig.fromJson({
        'authentication': ['alice:secret', 'bob:hunter2'],
      });
      expect(config.authentication, ['alice:secret', 'bob:hunter2']);
    });

    test('skip-auth-prefixes is read under mihomo\'s wire name', () {
      final config = ClashConfig.fromJson({
        'skip-auth-prefixes': ['10.0.0.0/8'],
      });
      expect(config.skipAuthPrefixes, ['10.0.0.0/8']);
    });

    test('an absent authentication key yields an empty list, not null', () {
      // Every config written before this feature has no such key; reading it must
      // not produce a null that later code would have to guard.
      final config = ClashConfig.fromJson({});
      expect(config.authentication, isEmpty);
    });

    test('an absent skip-auth-prefixes key falls back to loopback', () {
      final config = ClashConfig.fromJson({});
      expect(config.skipAuthPrefixes, defaultSkipAuthPrefixes);
    });

    test('the wire key is what mihomo expects', () {
      expect(
        const ClashConfig(authentication: ['alice:secret']).toJson()['authentication'],
        ['alice:secret'],
      );
      expect(
        const ClashConfig(
          skipAuthPrefixes: ['10.0.0.0/8'],
        ).toJson()['skip-auth-prefixes'],
        ['10.0.0.0/8'],
      );
    });
  });

  group('parseAuthEntry', () {
    test('splits on the first colon', () {
      final parsed = parseAuthEntry('alice:secret');
      expect(parsed.username, 'alice');
      expect(parsed.password, 'secret');
    });

    test('a password may itself contain colons', () {
      // This is exactly why the username may not: the split has to be
      // unambiguous from the left.
      final parsed = parseAuthEntry('alice:a:b:c');
      expect(parsed.username, 'alice');
      expect(parsed.password, 'a:b:c');
    });

    test('an entry with no colon becomes a username with no password', () {
      final parsed = parseAuthEntry('alice');
      expect(parsed.username, 'alice');
      expect(parsed.password, isEmpty);
    });

    test('an empty password is preserved, not dropped', () {
      final parsed = parseAuthEntry('alice:');
      expect(parsed.username, 'alice');
      expect(parsed.password, isEmpty);
    });
  });

  group('formatAuthEntry', () {
    test('joins a complete pair', () {
      expect(formatAuthEntry('alice', 'secret'), 'alice:secret');
    });

    test('trims surrounding whitespace from the username', () {
      expect(formatAuthEntry('  alice  ', 'secret'), 'alice:secret');
    });

    test('rejects a missing password', () {
      // Writing `alice:` would store a credential that authenticates nothing.
      expect(formatAuthEntry('alice', ''), isNull);
    });

    test('rejects a blank username', () {
      expect(formatAuthEntry('', 'secret'), isNull);
      expect(formatAuthEntry('   ', 'secret'), isNull);
    });

    test('the password is not trimmed', () {
      // Spaces can be part of a password; only the username is normalised.
      expect(formatAuthEntry('alice', ' s '), 'alice: s ');
    });
  });

  group('round-trip through the helpers', () {
    test('parse then format is identity for a well-formed entry', () {
      const entry = 'alice:a:b';
      final parsed = parseAuthEntry(entry);
      expect(formatAuthEntry(parsed.username, parsed.password), entry);
    });
  });
}
