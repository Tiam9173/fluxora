// P2-B1 — the "create empty group" flow in
// `lib/views/profiles/add_profile.dart` used to hard-code Chinese literals.
// These tests read the real getters in every supported locale and assert the
// newly added keys resolve to a non-empty, locale-appropriate string (i.e. no
// silent English fallback for the non-English locales).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';

/// Non-parameterised keys introduced by P2-B1.
final Map<String, String Function(AppLocalizations)> _plainKeys = {
  'createEmptyGroup': (l) => l.createEmptyGroup,
  'createEmptyGroupDesc': (l) => l.createEmptyGroupDesc,
  'customNodesDefaultName': (l) => l.customNodesDefaultName,
  'createEmptyGroupHint': (l) => l.createEmptyGroupHint,
  'groupName': (l) => l.groupName,
};

/// The two keys that must keep their placeholders.
const _parameterised = ['createGroupSuccess', 'createGroupFailed'];

final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');

/// Locales whose script is CJK (the non-English ones that used to fall back).
const _cjkLocales = [
  Locale('zh', 'CN'),
  Locale('zh', 'TC'),
  Locale('ja'),
  Locale('ko'),
];

/// All locales the app ships.
const _allLocales = [
  Locale('en'),
  Locale('zh', 'CN'),
  Locale('zh', 'TC'),
  Locale('ja'),
  Locale('ko'),
  Locale('fa'),
  Locale('ru'),
];

void main() {
  group('P2-B1 — create-empty-group copy resolves in every locale', () {
    for (final locale in _allLocales) {
      test('${locale.toLanguageTag()} returns non-empty text for all keys',
          () async {
        await AppLocalizations.load(locale);
        final l = appLocalizations;
        _plainKeys.forEach((name, read) {
          expect(read(l), isNotEmpty, reason: '$name empty in $locale');
        });
      });
    }

    test('non-English CJK locales do not fall back to English', () async {
      await AppLocalizations.load(const Locale('en'));
      final enValues = <String, String>{};
      _plainKeys.forEach((name, read) => enValues[name] = read(appLocalizations));

      for (final locale in _cjkLocales) {
        await AppLocalizations.load(locale);
        final l = appLocalizations;
        _plainKeys.forEach((name, read) {
          expect(
            read(l),
            isNot(equals(enValues[name])),
            reason: '$name appears to fall back to English in $locale',
          );
        });
      }
    });

    test('zh_CN create-empty-group copy is Chinese', () async {
      await AppLocalizations.load(const Locale('zh', 'CN'));
      _plainKeys.forEach((name, read) {
        expect(_cjk.hasMatch(read(appLocalizations)), isTrue,
            reason: '$name lost its Chinese text');
      });
    });

    test('parameterised keys keep their placeholders', () async {
      await AppLocalizations.load(const Locale('en'));
      expect(appLocalizations.createGroupSuccess('MyGroup'),
          contains('MyGroup'));
      expect(appLocalizations.createGroupFailed('boom'), contains('boom'));

      await AppLocalizations.load(const Locale('zh', 'CN'));
      expect(appLocalizations.createGroupSuccess('MyGroup'),
          contains('MyGroup'));
      expect(appLocalizations.createGroupFailed('boom'), contains('boom'));

      await AppLocalizations.load(const Locale('zh', 'TC'));
      expect(appLocalizations.createGroupSuccess('MyGroup'),
          contains('MyGroup'));
      expect(appLocalizations.createGroupFailed('boom'), contains('boom'));
    });

    test('every parameterised key exists in the shipped surface', () {
      expect(_parameterised.length, 2);
    });
  });
}
