import 'package:flutter/material.dart' show Locale;import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/views/dashboard/widgets/intranet_ip.dart';

/// item 6 — the LAN detail behind the "intranet IP" card.
///
/// Three things are pinned here:
/// 1. `NetworkInfo` survives the Android `MethodChannel` map shape it actually
///    travels in;
/// 2. the gateway button only appears for a real, reachable LAN router;
/// 3. the seven new labels resolve in every shipped locale.
void main() {
  group('NetworkInfo — the Android channel shape', () {
    test('round-trips the map the MethodChannel hands over', () {
      final info = NetworkInfo.fromJson({
        'type': 'Wi-Fi',
        'interfaceName': 'wlan0',
        'ip': '192.168.1.37',
        'gateway': '192.168.1.1',
        'dns': ['192.168.1.1', '8.8.8.8'],
      });

      expect(info.type, 'Wi-Fi');
      expect(info.interfaceName, 'wlan0');
      expect(info.ip, '192.168.1.37');
      expect(info.gateway, '192.168.1.1');
      expect(info.dns, ['192.168.1.1', '8.8.8.8']);

      expect(info.toJson(), {
        'type': 'Wi-Fi',
        'interfaceName': 'wlan0',
        'ip': '192.168.1.37',
        'gateway': '192.168.1.1',
        'dns': ['192.168.1.1', '8.8.8.8'],
      });
    });

    test('defaults to an empty report rather than throwing', () {
      final info = NetworkInfo.fromJson({});
      expect(info.type, '');
      expect(info.interfaceName, '');
      expect(info.ip, '');
      expect(info.gateway, '');
      expect(info.dns, isEmpty);
    });

    test('the desktop path can hand over a report directly', () {
      const info = NetworkInfo(
        type: 'Ethernet',
        interfaceName: 'en0',
        ip: '10.0.0.5',
        gateway: '10.0.0.1',
        dns: ['10.0.0.1'],
      );
      expect(info.toJson()['gateway'], '10.0.0.1');
    });
  });

  group('canOpenGateway — only a real LAN router', () {
    test('accepts the three RFC 1918 ranges', () {
      expect(canOpenGateway('192.168.1.1', 'Wi-Fi'), isTrue);
      expect(canOpenGateway('10.0.0.1', 'Wi-Fi'), isTrue);
      expect(canOpenGateway('172.16.0.1', 'Wi-Fi'), isTrue);
      expect(canOpenGateway('172.31.255.254', 'Wi-Fi'), isTrue);
    });

    test('rejects the cellular case', () {
      expect(canOpenGateway('192.168.1.1', 'Cellular'), isFalse);
      // Case-insensitive, because the Android transport string is fixed but the
      // desktop `Connectivity` string is not guaranteed to be.
      expect(canOpenGateway('192.168.1.1', 'cellular'), isFalse);
    });

    test('rejects non-routable and malformed values', () {
      for (final gateway in const [
        '',
        '0.0.0.0',
        '127.0.0.1', // loopback
        '169.254.1.1', // link-local
        '100.64.0.1', // carrier-grade NAT (RFC 6598)
        '100.127.255.254',
        '198.18.0.1', // benchmark (RFC 2544)
        '198.19.0.1',
        '172.15.0.1', // just outside RFC 1918
        '172.32.0.1',
        '192.169.0.1', // just outside RFC 1918
        '8.8.8.8', // public
        'not-an-ip',
        '1.2.3',
        '1.2.3.4.5',
        '999.1.1.1',
      ]) {
        expect(
          canOpenGateway(gateway, 'Wi-Fi'),
          isFalse,
          reason: '$gateway must not open a browser',
        );
      }
    });

    test('a public gateway is still not a LAN router', () {
      expect(canOpenGateway('1.1.1.1', 'Ethernet'), isFalse);
    });
  });

  group('LAN labels resolve in every shipped locale', () {
    final labels = <String, String Function()>{
      'intranetAndGateway': () => appLocalizations.intranetAndGateway,
      'networkType': () => appLocalizations.networkType,
      'networkInterface': () => appLocalizations.networkInterface,
      'defaultGateway': () => appLocalizations.defaultGateway,
      'systemDns': () => appLocalizations.systemDns,
      'openGateway': () => appLocalizations.openGateway,
      'lanShareAddress': () => appLocalizations.lanShareAddress,
    };

    // Same list the other locale tests use: `zh-TC` is how the project spells
    // Traditional Chinese, so `Locale.fromSubtags(scriptCode: 'Hant')` would
    // not match a supported locale and would fall back to English.
    const locales = [
      Locale('en'),
      Locale('zh', 'CN'),
      Locale('zh', 'TC'),
      Locale('ja'),
      Locale('ko'),
      Locale('ru'),
      Locale('fa'),
    ];

    test('every label is non-empty in every locale', () async {
      for (final locale in locales) {
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
      final english = {for (final e in labels.entries) e.key: e.value()};

      for (final locale in locales) {
        if (locale.languageCode == 'en') continue;
        await AppLocalizations.load(locale);
        for (final entry in labels.entries) {
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
