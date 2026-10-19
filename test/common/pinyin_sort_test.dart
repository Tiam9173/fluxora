import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/pinyin_sort.dart';

void main() {
  group('pinyin sort key', () {
    test('keeps latin letters and digits in order', () {
      expect(pinyinSortKey('HK-01'), 'HK01');
    });

    test('maps Chinese to initials', () {
      expect(pinyinSortKey('美国'), 'MG');
      expect(pinyinSortKey('日本'), 'RB');
    });

    test('drops flags and punctuation so they cannot decide the order', () {
      expect(pinyinSortKey('🇺🇸美国05-HY2 |公益1倍'), 'MG05HY2GY1B');
    });

    test('returns empty for a name with no readable characters', () {
      expect(pinyinSortKey('🇺🇸 ★'), '');
    });
  });

  group('compareByPinyin', () {
    test('sorts Chinese A to Z by pinyin, not by code point', () {
      final names = ['日本', '巴西', '阿根廷', '美国'];
      names.sort(compareByPinyin);
      expect(names, ['阿根廷', '巴西', '美国', '日本']);
    });

    test('falls back to the raw name when keys tie', () {
      // Both are "MG"; the tie-break must be deterministic.
      final names = ['美国B', '美国A'];
      names.sort(compareByPinyin);
      expect(names.first, '美国A');
    });

    test('keeps latin names usable', () {
      final names = ['Node-B', 'Node-A'];
      names.sort(compareByPinyin);
      expect(names, ['Node-A', 'Node-B']);
    });
  });
}
