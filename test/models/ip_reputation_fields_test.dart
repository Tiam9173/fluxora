import 'package:fluxora/models/ip_reputation.dart';
import 'package:flutter_test/flutter_test.dart';

/// item 6 — the field-selection resolver. Pure, so these are cheap and they pin
/// the two rules that keep the setting invisible until it is used.
void main() {
  group('resolveIpReputationFields', () {
    test('null/empty means "not customised" and yields every field', () {
      expect(resolveIpReputationFields(null), IpReputationFieldIds.all.toSet());
      expect(resolveIpReputationFields({}), IpReputationFieldIds.all.toSet());
    });

    test('a selection is honoured exactly, so nothing can be shown', () {
      final only = {IpReputationFieldIds.score};

      final resolved = resolveIpReputationFields(only);

      expect(resolved, {IpReputationFieldIds.score});
    });

    test('unknown ids are dropped rather than surfaced', () {
      final resolved = resolveIpReputationFields({
        IpReputationFieldIds.asn,
        'a-field-we-shipped-in-2027',
      });

      expect(resolved, {IpReputationFieldIds.asn});
    });

    test('a selection of only stale ids resolves to empty, not to all', () {
      final resolved = resolveIpReputationFields({'retired-field'});

      expect(resolved, isEmpty);
    });
  });
}
