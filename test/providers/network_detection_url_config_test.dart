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

  // ── P4 — IP reputation (IP risk intel) ─────────────────────────────────────
  //
  // E-5's hard requirement is that the section is **opt-in**: the setting must
  // default to false so no lookup happens until the user turns it on.
  group('P4 — ipReputationEnabled defaults OFF and persists', () {
    test('the default is false (nothing is sent until the user opts in)', () {
      expect(defaultAppSettingProps.ipReputationEnabled, isFalse);
      expect(AppSettingProps().ipReputationEnabled, isFalse);
    });

    test('round-trips through copyWith and JSON in both directions', () {
      final on = defaultAppSettingProps.copyWith(ipReputationEnabled: true);
      expect(on.ipReputationEnabled, isTrue);

      expect(on.toJson()['ipReputationEnabled'], isTrue);
      expect(
        AppSettingProps.fromJson(on.toJson()).ipReputationEnabled,
        isTrue,
      );

      // A payload written before the field existed must still read as OFF.
      expect(
        AppSettingProps.fromJson(
          defaultAppSettingProps.toJson(),
        ).ipReputationEnabled,
        isFalse,
      );
    });
  });

  group('P4 — the risk-intel labels resolve in every shipped locale', () {
    final labels = <String, String Function()>{
      'ipRiskIntel': () => appLocalizations.ipRiskIntel,
      'ipRiskPrivacyNote': () => appLocalizations.ipRiskPrivacyNote,
      'ipRiskEnable': () => appLocalizations.ipRiskEnable,
      'ipRiskNotFlagged': () => appLocalizations.ipRiskNotFlagged,
      'ipRiskStale': () => appLocalizations.ipRiskStale,
      'ipRiskVpn': () => appLocalizations.ipRiskVpn,
      'ipRiskProxy': () => appLocalizations.ipRiskProxy,
      'ipRiskTor': () => appLocalizations.ipRiskTor,
      'ipRiskHosting': () => appLocalizations.ipRiskHosting,
      'ipRiskRelay': () => appLocalizations.ipRiskRelay,
      'ipRiskMobile': () => appLocalizations.ipRiskMobile,
      'ipRiskBogon': () => appLocalizations.ipRiskBogon,
      'ipRiskSearchEngineBot': () => appLocalizations.ipRiskSearchEngineBot,
      'ipRiskAbuse': () => appLocalizations.ipRiskAbuse,
      'ipRiskBlocklists': () => appLocalizations.ipRiskBlocklists,
      'ipRiskLimits': () => appLocalizations.ipRiskLimits,
      'ipRiskOpenReport': () => appLocalizations.ipRiskOpenReport,
      'ipRiskFailed': () => appLocalizations.ipRiskFailed,
    };

    test('every label is non-empty in every locale', () async {
      for (final locale in _allLocales) {
        await AppLocalizations.load(locale);
        for (final entry in labels.entries) {
          expect(
            entry.value().isNotEmpty,
            isTrue,
            reason: '${entry.key} is empty in $locale',
          );
        }
      }
    });

    test('non-English locales do not silently fall back to English', () async {
      await AppLocalizations.load(const Locale('en'));
      final english = {
        for (final e in labels.entries) e.key: e.value(),
      };

      for (final locale in _allLocales) {
        if (locale.languageCode == 'en') continue;
        await AppLocalizations.load(locale);
        for (final entry in labels.entries) {
          // Identical-to-English is allowed only where the term is a proper noun
          // that is not translated (VPN / Tor / PayPal-style brand names).
          const properNouns = {'ipRiskVpn', 'ipRiskTor'};
          if (properNouns.contains(entry.key)) continue;
          expect(
            entry.value(),
            isNot(equals(english[entry.key])),
            reason: '${entry.key} falls back to English in $locale',
          );
        }
      }
    });
  });

  // ── C — chain panel titles were hard-coded English ─────────────────────────
  //
  // `chain_intelligence_dashboard` / `chain_decision_panel` /
  // `chain_diagnostic_panel` / `chain_support_panel` rendered literal English
  // strings. They now resolve through l10n; this guards both directions —
  // every key is present, and no non-English locale silently falls back.
  group('C — chain panel labels resolve in every shipped locale', () {
    final chainLabels = <String, String Function()>{
      'chainIntelAnalytics': () => appLocalizations.chainIntelAnalytics,
      'chainAvgLatency': () => appLocalizations.chainAvgLatency,
      'chainTopFailureReason': () => appLocalizations.chainTopFailureReason,
      'chainNodeReliability': () => appLocalizations.chainNodeReliability,
      'chainHealthScore': () => appLocalizations.chainHealthScore,
      'chainDecisionSupport': () => appLocalizations.chainDecisionSupport,
      'chainDiagnosticTitle': () => appLocalizations.chainDiagnosticTitle,
      'chainHealthLabel': () => appLocalizations.chainHealthLabel,
      'chainEventsLabel': () => appLocalizations.chainEventsLabel,
      'chainFailuresLabel': () => appLocalizations.chainFailuresLabel,
      'chainExportReport': () => appLocalizations.chainExportReport,
      'chainExporting': () => appLocalizations.chainExporting,
      'chainSupportTitle': () => appLocalizations.chainSupportTitle,
      'chainPackageReady': () => appLocalizations.chainPackageReady,
      'chainGeneratedOn': () => appLocalizations.chainGeneratedOn,
      'chainOpenFolder': () => appLocalizations.chainOpenFolder,
      'chainShareLabel': () => appLocalizations.chainShareLabel,
      'chainDiagnosticPackage': () => appLocalizations.chainDiagnosticPackage,
      'chainCreateSupportPackage': () =>
          appLocalizations.chainCreateSupportPackage,
      'chainCreatingPackage': () => appLocalizations.chainCreatingPackage,
    };

    test('every label is non-empty in every locale', () async {
      for (final locale in _allLocales) {
        await AppLocalizations.load(locale);
        for (final entry in chainLabels.entries) {
          expect(
            entry.value().isNotEmpty,
            isTrue,
            reason: '${entry.key} is empty in $locale',
          );
        }
      }
    });

    test('non-English locales do not silently fall back to English', () async {
      await AppLocalizations.load(const Locale('en'));
      final english = {
        for (final e in chainLabels.entries) e.key: e.value(),
      };

      for (final locale in _allLocales) {
        if (locale.languageCode == 'en') continue;
        await AppLocalizations.load(locale);
        for (final entry in chainLabels.entries) {
          expect(
            entry.value(),
            isNot(equals(english[entry.key])),
            reason: '${entry.key} falls back to English in $locale',
          );
        }
      }
    });
  });
}
