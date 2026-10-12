import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';

/// `utils.getSystemLocale()` decides the UI language when the user has not
/// picked one. It used to fall back to Chinese, which made the AppImage start
/// in Chinese under the POSIX `C` locale and failed the AppImageHub catalog
/// test:
/// https://github.com/AppImage/appimage.github.io/pull/5901
void main() {
  group('utils.getSystemLocale', () {
    /// Overrides the platform locale for the duration of one test.
    void usePlatformLocale(WidgetTester tester, Locale locale) {
      tester.platformDispatcher.localeTestValue = locale;
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    }

    testWidgets('the POSIX `C` locale falls back to English', (tester) async {
      // This is the exact case AppImageHub runs the AppImage under.
      usePlatformLocale(tester, const Locale('C'));

      expect(utils.getSystemLocale().languageCode, 'en');
    });

    testWidgets('an unsupported language falls back to English', (tester) async {
      usePlatformLocale(tester, const Locale('de'));

      expect(utils.getSystemLocale().languageCode, 'en');
    });

    testWidgets('English stays English', (tester) async {
      usePlatformLocale(tester, const Locale('en', 'US'));

      expect(utils.getSystemLocale().languageCode, 'en');
    });

    testWidgets('Chinese resolves Simplified vs Traditional', (tester) async {
      usePlatformLocale(tester, const Locale('zh', 'CN'));
      expect(utils.getSystemLocale(), const Locale('zh', 'CN'));

      tester.platformDispatcher.localeTestValue = const Locale('zh', 'TW');
      expect(utils.getSystemLocale(), const Locale('zh', 'TC'));

      tester.platformDispatcher.localeTestValue = const Locale('zh', 'HK');
      expect(utils.getSystemLocale(), const Locale('zh', 'TC'));

      tester.platformDispatcher.localeTestValue = const Locale('zh', 'MO');
      expect(utils.getSystemLocale(), const Locale('zh', 'TC'));

      tester.platformDispatcher.localeTestValue = const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
      );
      expect(utils.getSystemLocale(), const Locale('zh', 'TC'));

      // Plain `zh` without a region stays Simplified.
      tester.platformDispatcher.localeTestValue = const Locale('zh');
      expect(utils.getSystemLocale(), const Locale('zh', 'CN'));
    });

    testWidgets('every other supported language is preserved', (tester) async {
      for (final code in ['ja', 'ko', 'ru', 'fa']) {
        tester.platformDispatcher.localeTestValue = Locale(code);

        expect(
          utils.getSystemLocale().languageCode,
          code,
          reason: '$code must not be redirected to another language',
        );
      }
    });
  });
}
