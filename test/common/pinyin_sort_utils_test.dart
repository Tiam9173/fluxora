import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';

/// The **live** pinyin sort key and comparator.
///
/// `utils.getPinyin` and `utils.sortByChar` are the production name-ordering
/// primitives behind the proxies page (`AppController._sortOfName`,
/// `controller.dart:2284`) and the package picker (`AccessSortType.none`,
/// `models/selector.dart:195`). Neither had any test before this file.
///
/// What this file pins — and only what the implementation actually promises:
///   · `getPinyin` reads the **first character only** and turns a Chinese one
///     into its full tone-less syllable (`中` → `zhong`); everything else is
///     passed through unchanged (`A` → `A`, `5` → `5`, `-` → `-`).
///   · `sortByChar` compares two keys character by character,
///     **case-insensitively**, and treats the empty string as smallest.
///
/// Deliberately **not** asserted:
///   · **Emoji / flag prefixes.** `getPinyin` slices with `substring(0, 1)`,
///     which splits a surrogate pair and yields a lone high surrogate. That is
///     a side effect of the current implementation, not a designed contract, so
///     pinning it here would freeze an accident.
///   · **The relative order of equal keys.** `List.sort` is documented as *not
///     guaranteed stable*, and `_sortOfName` has no tie-break, so two names
///     with the same first character have no defined order. Only the comparator
///     returning `0` is asserted.
void main() {
  group('utils.getPinyin — first-character sort key', () {
    test('Chinese first character → its full tone-less syllable', () {
      expect(utils.getPinyin('中'), 'zhong');
      expect(utils.getPinyin('北'), 'bei');
      expect(utils.getPinyin('上'), 'shang');
      expect(utils.getPinyin('香'), 'xiang');
    });

    test('Latin letters pass through unchanged (case preserved)', () {
      expect(utils.getPinyin('A'), 'A');
      expect(utils.getPinyin('z'), 'z');
    });

    test('digits pass through unchanged', () {
      expect(utils.getPinyin('5'), '5');
      expect(utils.getPinyin('0'), '0');
    });

    test('punctuation passes through unchanged', () {
      expect(utils.getPinyin('-'), '-');
      expect(utils.getPinyin('_'), '_');
    });

    test('only the FIRST character is read', () {
      // The rest of the name never reaches the key.
      expect(utils.getPinyin('中国'), utils.getPinyin('中'));
      expect(utils.getPinyin('Alpha-1'), 'A');
      expect(utils.getPinyin('5G'), '5');
    });

    test('empty string → empty key', () {
      expect(utils.getPinyin(''), '');
    });
  });

  group('utils.sortByChar — case-insensitive comparator', () {
    test('is case-insensitive for the same letter', () {
      expect(utils.sortByChar('A', 'a'), 0);
      expect(utils.sortByChar('a', 'A'), 0);
      expect(utils.sortByChar('Zhong', 'zhong'), 0);
    });

    test('orders letters alphabetically, ignoring case', () {
      expect(utils.sortByChar('apple', 'Banana'), lessThan(0));
      expect(utils.sortByChar('Banana', 'apple'), greaterThan(0));
    });

    test('digits sort before letters', () {
      expect(utils.sortByChar('5', 'A'), lessThan(0));
      expect(utils.sortByChar('A', '5'), greaterThan(0));
    });

    test('punctuation sorts before digits', () {
      expect(utils.sortByChar('-', '5'), lessThan(0));
      expect(utils.sortByChar('5', '-'), greaterThan(0));
    });

    test('the empty string is the smallest key', () {
      expect(utils.sortByChar('', ''), 0);
      expect(utils.sortByChar('', 'a'), -1);
      expect(utils.sortByChar('a', ''), 1);
    });

    test('a proper prefix sorts first', () {
      expect(utils.sortByChar('ab', 'abc'), lessThan(0));
      expect(utils.sortByChar('abc', 'ab'), greaterThan(0));
    });

    test('compares past a shared prefix', () {
      // 'zhang' vs 'zhong' — first difference is 'a' < 'o'.
      expect(utils.sortByChar('zhang', 'zhong'), lessThan(0));
    });

    test('identical keys compare equal', () {
      expect(utils.sortByChar('zhong', 'zhong'), 0);
    });
  });

  group('sorting node names with the live comparator', () {
    // Every key in these fixtures is distinct, so the resulting order is fully
    // determined — no reliance on `List.sort` stability.
    List<String> sortedNames(List<String> names) {
      final list = [...names]
        ..sort((a, b) => utils.sortByChar(utils.getPinyin(a), utils.getPinyin(b)));
      return list;
    }

    test('Chinese names sort by pinyin, not by code point', () {
      // bei < shang < xiang < zhong
      expect(sortedNames(['中', '北', '香', '上']), ['北', '上', '香', '中']);
    });

    test('Latin names sort case-insensitively', () {
      expect(
        sortedNames(['beta', 'Alpha', 'gamma']),
        ['Alpha', 'beta', 'gamma'],
      );
    });

    test('Chinese and Latin interleave by their first letter', () {
      // 'bei' < 'gamma'  →  北 before gamma
      expect(sortedNames(['gamma', '北']), ['北', 'gamma']);
      // 'zhong' > 'gamma'  →  中 after gamma
      expect(sortedNames(['中', 'gamma']), ['gamma', '中']);
    });

    test('digits and punctuation take part in the ordering', () {
      // '-' (0x2D) < '5' (0x35) < 'A' (0x41) < 'zhong'
      expect(
        sortedNames(['中', 'apple', '5G', '-dash']),
        ['-dash', '5G', 'apple', '中'],
      );
    });

    test('equal first characters compare equal (no tie-break exists)', () {
      // Both keys are 'xiang'; the comparator must not invent an order.
      expect(
        utils.sortByChar(utils.getPinyin('香港01'), utils.getPinyin('香港02')),
        0,
      );
    });
  });
}
