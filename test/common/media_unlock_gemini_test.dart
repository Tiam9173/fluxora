import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/media_unlock_checker.dart';
import 'package:fluxora/models/models.dart';

/// item 6 (Bettbox 1.19.4) — the Gemini unlock test.
///
/// The old logic was `statusCode == 200 && !realUri.contains('unavailable')`,
/// which reported **unlocked** for countries where Gemini serves a normal-looking
/// page but is not actually usable. Two things were missing: a region blocklist
/// (Gemini answers 200 in several sanctioned regions) and body-phrase detection
/// (the refusal is worded several different ways and the redirect target is not
/// always `unavailable`).
void main() {
  MediaUnlockStatus status({
    int statusCode = 200,
    String realUrl = 'https://gemini.google.com/app',
    String body = '',
    String? rawRegion,
  }) => MediaUnlockChecker.geminiUnlockStatus(
    statusCode: statusCode,
    realUrl: realUrl,
    body: body,
    rawRegion: rawRegion,
  );

  group('geminiUnlockStatus — a clean response is unlocked', () {
    test('200 with no refusal marker', () {
      expect(status(body: '<html>Gemini</html>'), MediaUnlockStatus.unlocked);
    });

    test('a supported region still unlocks', () {
      expect(status(body: '...', rawRegion: 'USA'), MediaUnlockStatus.unlocked);
      expect(status(body: '...', rawRegion: 'JPN'), MediaUnlockStatus.unlocked);
      expect(status(body: '...', rawRegion: 'DEU'), MediaUnlockStatus.unlocked);
    });
  });

  group('geminiUnlockStatus — the status code still gates', () {
    test('a non-200 is blocked', () {
      expect(status(statusCode: 403), MediaUnlockStatus.blocked);
      expect(status(statusCode: 429), MediaUnlockStatus.blocked);
      expect(status(statusCode: 500), MediaUnlockStatus.blocked);
    });
  });

  group('geminiUnlockStatus — a blocked region is blocked even on 200', () {
    test('alpha-2 codes', () {
      for (final code in const ['CN', 'MO', 'RU', 'BY', 'IR', 'KP', 'SY', 'CU', 'VE', 'MM', 'SD', 'AF', 'SS', 'YE', 'ZW']) {
        expect(
          status(rawRegion: code),
          MediaUnlockStatus.blocked,
          reason: '$code must not report unlocked',
        );
      }
    });

    test('alpha-3 codes', () {
      for (final code in const ['CHN', 'MAC', 'RUS', 'BLR', 'IRN', 'PRK', 'SYR', 'CUB', 'VEN', 'MMR', 'SDN', 'AFG', 'SSD', 'YEM', 'ZWE']) {
        expect(
          status(rawRegion: code),
          MediaUnlockStatus.blocked,
          reason: '$code must not report unlocked',
        );
      }
    });

    test('a region that merely starts with a blocked code is not blocked', () {
      // Only an exact match counts; "CO" (Colombia) must not be caught by "CU".
      expect(status(rawRegion: 'CO'), MediaUnlockStatus.unlocked);
      expect(status(rawRegion: 'CM'), MediaUnlockStatus.unlocked);
    });
  });

  group('geminiUnlockStatus — body refusals are caught', () {
    test('every refusal phrasing', () {
      const phrases = [
        'is not supported in your country',
        "isn't supported in your country",
        'not available in your country',
        'unavailable in your country',
        'is not currently supported',
        "isn't currently supported",
      ];
      for (final phrase in phrases) {
        expect(
          status(body: '<html><body>Gemini $phrase.</body></html>'),
          MediaUnlockStatus.blocked,
          reason: 'the "$phrase" phrasing must be caught',
        );
      }
    });

    test('the unavailable redirect target is still caught', () {
      expect(
        status(realUrl: 'https://gemini.google.com/unavailable'),
        MediaUnlockStatus.blocked,
      );
    });

    test('a refusal in another language is not silently passed', () {
      // We cannot translate every locale, but the region blocklist is the
      // backstop for the ones Gemini phrases differently.
      expect(status(body: '很抱歉', rawRegion: 'CN'), MediaUnlockStatus.blocked);
    });
  });
}
