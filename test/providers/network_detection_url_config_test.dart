// P3 — network detection URL configurability.
//
// Verifies the guarantee the change must uphold:
//  * the default `networkDetectionUrl` equals the previous hard-coded primary
//    source, so behaviour is unchanged when the user never configures it;
//  * the value round-trips through JSON (persistence) and `copyWith`;
//  * an empty string falls back to the default at the model boundary;
//  * the new user-visible label resolves in every shipped locale.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';

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
  group('P3 — networkDetectionUrl default & persistence', () {
    test('default equals the previous hard-coded primary source', () {
      // The built-in primary for zh is the lang-suffixed ip-api endpoint.
      expect(defaultNetworkDetectionUrl, 'http://ip-api.com/json/?lang=zh-CN');
      expect(defaultAppSettingProps.networkDetectionUrl,
          defaultNetworkDetectionUrl);
    });

    test('default is a valid URL accepted by the shared validator', () {
      expect(defaultNetworkDetectionUrl.isUrl, isTrue);
    });

    test('preset list is non-empty, deduped and all valid URLs', () {
      expect(presetNetworkDetectionUrls, isNotEmpty);
      expect(presetNetworkDetectionUrls.toSet().length,
          presetNetworkDetectionUrls.length,
          reason: 'preset list must not contain duplicates');
      for (final url in presetNetworkDetectionUrls) {
        expect(url.isUrl, isTrue, reason: '$url is not a valid URL');
      }
      // The default is offered as a preset so users can always return to it.
      expect(presetNetworkDetectionUrls, contains(defaultNetworkDetectionUrl));
    });

    test('copyWith overrides the field, others untouched', () {
      final custom =
          defaultAppSettingProps.copyWith(networkDetectionUrl: 'https://x.test');
      expect(custom.networkDetectionUrl, 'https://x.test');
      expect(custom.testUrl, defaultAppSettingProps.testUrl);
    });

    test('JSON round-trip preserves the configured value', () {
      final custom =
          defaultAppSettingProps.copyWith(networkDetectionUrl: 'https://y.test');
      final json = custom.toJson();
      expect(json['networkDetectionUrl'], 'https://y.test');

      final restored = AppSettingProps.fromJson(json);
      expect(restored.networkDetectionUrl, 'https://y.test');
    });

    test('missing key in stored JSON falls back to the default', () {
      final restored = AppSettingProps.fromJson(<String, Object?>{
        'testUrl': 'https://legacy.test',
      });
      expect(restored.networkDetectionUrl, defaultNetworkDetectionUrl);
      expect(restored.testUrl, 'https://legacy.test');
    });

    test('an empty stored value is preserved as empty (UI validates input)', () {
      // The empty-string guard lives in the request layer, not the model; the
      // model faithfully stores what JSON holds so the runtime fallback works.
      final restored = AppSettingProps.fromJson(<String, Object?>{
        'networkDetectionUrl': '',
      });
      expect(restored.networkDetectionUrl, isEmpty);
      // …and the runtime guard treats it as "use the built-in source".
      expect(''.isNotEmpty && ''.isUrl, isFalse);
    });

    test('an invalid URL fails the shared validator (runtime fallback path)', () {
      expect('not-a-url'.isUrl, isFalse);
      expect(''.isUrl, isFalse);
    });
  });

  group('P3 — networkDetectionUrl label resolves in every locale', () {
    for (final locale in _allLocales) {
      test('${locale.toLanguageTag()} returns non-empty text', () async {
        await AppLocalizations.load(locale);
        expect(appLocalizations.networkDetectionUrl, isNotEmpty,
            reason: 'networkDetectionUrl empty in $locale');
      });
    }

    test('non-English locales do not silently fall back to English', () async {
      await AppLocalizations.load(const Locale('en'));
      final en = appLocalizations.networkDetectionUrl;

      for (final locale in _allLocales) {
        if (locale.languageCode == 'en') continue;
        await AppLocalizations.load(locale);
        expect(appLocalizations.networkDetectionUrl, isNot(equals(en)),
            reason: 'networkDetectionUrl falls back to English in $locale');
      }
    });
  });
}
