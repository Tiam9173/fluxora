import 'package:flutter_test/flutter_test.dart';

import 'package:fluxora/common/rule_provider_warning.dart';

void main() {
  group('isRuleProviderOnlyWarning', () {
    test('empty is not a warning (nothing to tolerate)', () {
      expect(isRuleProviderOnlyWarning(''), isFalse);
      expect(isRuleProviderOnlyWarning('   \n  '), isFalse);
    });

    test('a single rule-provider warning is tolerated', () {
      expect(
        isRuleProviderOnlyWarning(
          'initial rule provider github error: 502 Bad Gateway',
        ),
        isTrue,
      );
    });

    test('several warnings, blank lines between them, are tolerated', () {
      expect(
        isRuleProviderOnlyWarning(
          'initial rule provider github error: 502 Bad Gateway\n'
          '\n'
          'initial rule provider awavenue-ads error: Get '
          "'https://cdn.jsdelivr.net/gh/x/y.yaml': EOF",
        ),
        isTrue,
      );
    });

    test('a real config error is never tolerated', () {
      expect(
        isRuleProviderOnlyWarning('level: error: unmarshal errors:'),
        isFalse,
      );
    });

    test('a warning followed by a real error is fatal', () {
      expect(
        isRuleProviderOnlyWarning(
          'initial rule provider github error: 502 Bad Gateway\n'
          'level: error: unmarshal errors:',
        ),
        isFalse,
      );
    });

    test('an unrecognised prefix is fatal, not guessed at', () {
      expect(
        isRuleProviderOnlyWarning('initial proxy provider foo error: 502'),
        isFalse,
      );
      expect(isRuleProviderOnlyWarning('rule provider github error'), isFalse);
    });

    test('matching is case-insensitive on the prefix', () {
      expect(
        isRuleProviderOnlyWarning('Initial Rule Provider github error: 502'),
        isTrue,
      );
    });
  });
}
