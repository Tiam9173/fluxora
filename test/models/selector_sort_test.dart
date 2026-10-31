import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';

/// The **access-control package list** ordering.
///
/// `PackageListSelectorState.getSortList` (`selector.dart:169`) is the
/// production entry the access page calls (`views/access.dart:427`, `:803`).
/// Its local `comparePackages` (`selector.dart:188`) applies, in order:
///
///   1. **selected packages first** — `selectedList.contains(packageName)`;
///   2. the configured `AccessSortType`:
///      · `none` → `utils.sortByChar(utils.getPinyin(label), …)`, i.e. the
///        **pinyin of the label's first character**, case-insensitively;
///   3. **`packageName.compareTo` tie-break** when the sort key is equal.
///
/// This file pins step 2 (`none`) and step 3. The pinyin comparator itself is
/// covered in `test/common/pinyin_sort_utils_test.dart`; here it is exercised
/// through the real `getSortList`, not a copy.
///
/// Deliberately **not** asserted: the relative order of two packages whose
/// sort key *and* package name are both equal — the comparator returns `0`
/// and `List.sort` is not guaranteed stable, so only determinism is checked.
void main() {
  Package pkg(
    String packageName,
    String label, {
    bool system = false,
    bool internet = true,
  }) => Package(
    packageName: packageName,
    label: label,
    system: system,
    internet: internet,
  );

  /// `AccessControl` defaults to `AccessSortType.none` with no manual list and
  /// no system / non-internet filtering, so nothing is dropped before sorting.
  List<String> sortLabels(List<Package> packages, {List<String> selected = const []}) {
    final state = PackageListSelectorState(
      packages: packages,
      accessControl: const AccessControl(),
    );
    return state
        .getSortList(selected)
        .map((p) => p.label)
        .toList();
  }

  group('AccessSortType.none — pinyin of the label', () {
    test('default AccessControl really is AccessSortType.none', () {
      expect(const AccessControl().sort, AccessSortType.none);
    });

    test('Chinese labels sort by pinyin, not by code point', () {
      // pinyin: 北(bei) < 中(zhong)
      // code point would give: 中(U+4E2D) < 北(U+5317)
      expect(
        sortLabels([
          pkg('com.example.zhong', '中'),
          pkg('com.example.bei', '北'),
        ]),
        ['北', '中'],
      );
    });

    test('Latin labels sort case-insensitively', () {
      // lowercase: alpha < beta  →  ['alpha', 'Beta']
      // code point would give: 'Beta'(B=0x42) < 'alpha'(a=0x61)
      expect(
        sortLabels([
          pkg('com.example.beta', 'Beta'),
          pkg('com.example.alpha', 'alpha'),
        ]),
        ['alpha', 'Beta'],
      );
    });

    test('only the first character of the label decides the key', () {
      // Both keys are 'a'; the rest of the label is never read.
      // The tie is broken by packageName, so this also proves step 3 exists.
      expect(
        sortLabels([
          pkg('com.example.zzz', '阿里'),
          pkg('com.example.aaa', '阿'),
        ]),
        ['阿', '阿里'],
      );
    });

    test('digits sort before letters', () {
      // '5' (0x35) < 'Z' (0x5A) after the case-insensitive compare
      expect(
        sortLabels([
          pkg('com.example.z', 'Zulu'),
          pkg('com.example.n', '5G'),
        ]),
        ['5G', 'Zulu'],
      );
    });
  });

  group('packageName tie-break', () {
    test('breaks a pinyin tie by package name', () {
      // Same label → same key → falls through to packageName.compareTo.
      final state = PackageListSelectorState(
        packages: [
          pkg('com.example.zzz', '阿'),
          pkg('com.example.aaa', '阿'),
          pkg('com.example.mmm', '阿'),
        ],
        accessControl: const AccessControl(),
      );
      expect(
        state.getSortList(const []).map((p) => p.packageName).toList(),
        ['com.example.aaa', 'com.example.mmm', 'com.example.zzz'],
      );
    });

    test('tie-break does not override a non-zero pinyin order', () {
      // 北(bei) < 中(zhong), so the tie-break never runs even though
      // 'com.example.aaa' would sort first by package name.
      final state = PackageListSelectorState(
        packages: [
          pkg('com.example.aaa', '中'),
          pkg('com.example.zzz', '北'),
        ],
        accessControl: const AccessControl(),
      );
      expect(
        state.getSortList(const []).map((p) => p.packageName).toList(),
        ['com.example.zzz', 'com.example.aaa'],
      );
    });

    test('fully equal keys are left unordered (only determinism is asserted)',
        () {
      // Same key and same packageName → comparator returns 0. `List.sort` is
      // not guaranteed stable, so only membership and repeatability hold.
      final state = PackageListSelectorState(
        packages: [
          pkg('com.example.same', '阿一'),
          pkg('com.example.same', '阿二'),
        ],
        accessControl: const AccessControl(),
      );

      final first = state.getSortList(const []).map((p) => p.label).toList();
      expect(first.length, 2);
      expect(first.toSet(), {'阿一', '阿二'});

      for (var i = 0; i < 5; i++) {
        expect(
          state.getSortList(const []).map((p) => p.label).toList(),
          first,
        );
      }
    });
  });

  group('selected packages and input immutability', () {
    test('selected packages come first regardless of the sort key', () {
      // '中' sorts last by pinyin, but it is selected → it leads.
      final state = PackageListSelectorState(
        packages: [
          pkg('com.example.zhong', '中'),
          pkg('com.example.bei', '北'),
          pkg('com.example.xiang', '香'),
        ],
        accessControl: const AccessControl(),
      );

      expect(
        state.getSortList(['com.example.zhong']).map((p) => p.label).toList(),
        ['中', '北', '香'],
      );
    });

    test('the caller\'s package list is not mutated', () {
      final packages = [
        pkg('com.example.zhong', '中'),
        pkg('com.example.bei', '北'),
        pkg('com.example.xiang', '香'),
      ];
      final state = PackageListSelectorState(
        packages: packages,
        accessControl: const AccessControl(),
      );

      state.getSortList(const []);

      expect(
        packages.map((p) => p.label).toList(),
        ['中', '北', '香'],
        reason: 'getSortList sorts a copy (`[...filtered, ...manualPackages]`)',
      );
    });
  });
}
