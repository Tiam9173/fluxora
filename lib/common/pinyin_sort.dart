import 'pinyin_initial_table.dart';

/// Sort key for a node name: initials for Chinese, letters/digits otherwise.
///
/// Node names mix flags, emoji, Chinese and Latin (`🇺🇸美国05-HY2 |公益1倍`).
/// Sorting those by code point puts every Chinese character in Unicode order,
/// which reads as random to anyone who reads Chinese - they expect A→Z by
/// pinyin. This builds a key that matches that expectation and drops the
/// decoration that has no reading order at all.
///
/// Characters with no initial (emoji, punctuation, rare ideographs outside
/// GB2312) are skipped rather than sorted: they carry no order of their own, and
/// keeping them would let a flag decide the position of a node.
String pinyinSortKey(String name) {
  final buffer = StringBuffer();
  for (final rune in name.runes) {
    // ASCII letters and digits read in their own order.
    if ((rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A)) {
      buffer.writeCharCode(rune >= 0x61 ? rune - 0x20 : rune);
      continue;
    }
    // Only CJK ideographs have a pinyin initial; skip everything else.
    if (rune < 0x4E00 || rune > 0x9FFF) continue;
    final initial = pinyinInitialOf(String.fromCharCode(rune));
    if (initial != null) buffer.write(initial);
  }
  return buffer.toString();
}

/// The initial letter of a single Chinese character, or null when it is not in
/// the table (rare ideographs, extensions A/B).
String? pinyinInitialOf(String char) {
  for (final entry in pinyinInitialBuckets.entries) {
    if (entry.value.contains(char)) return entry.key;
  }
  return null;
}

/// A→Z by pinyin, falling back to the raw name so equal keys stay stable.
int compareByPinyin(String a, String b) {
  final byKey = pinyinSortKey(a).compareTo(pinyinSortKey(b));
  if (byKey != 0) return byKey;
  return a.compareTo(b);
}
