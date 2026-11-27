import 'dart:convert';

import 'package:fluxora/common/constant.dart';
import 'package:fluxora/common/preferences.dart';
import 'package:fluxora/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Config legacyConfig;

  setUpAll(() async {
    legacyConfig = Config(
      themeProps: const ThemeProps(),
      patchClashConfig: ClashConfig(
        dns: const Dns(
          nameserver: ['223.5.5.5', '119.29.29.29'],
          nameserverPolicy: {
            '+.internal.corp.com': '10.0.0.1',
            'geosite:cn': '119.29.29.29',
            'geosite:private': 'system',
            '*': 'system',
            'custom.example': '192.0.2.53',
          },
        ),
      ),
    );
    SharedPreferences.setMockInitialValues({
      configKey: jsonEncode(legacyConfig),
    });
    await preferences.sharedPreferencesCompleter.future;
  });

  test(
    'migrates only the obsolete built-in DNS policies and persists them',
    () async {
      final migrated = await preferences.getConfig();
      expect(migrated, isNotNull);
      expect(migrated!.patchClashConfig.dns.nameserverPolicy, {
        '+.internal.corp.com': '10.0.0.1',
        'geosite:cn':
            'https://dns.alidns.com/dns-query,https://doh.pub/dns-query',
        'geosite:private': 'system',
        'custom.example': '192.0.2.53',
      });
      expect(migrated.patchClashConfig.dns.nameserver, [
        'https://dns.alidns.com/dns-query',
        'https://doh.pub/dns-query',
      ]);

      final store = await SharedPreferences.getInstance();
      final saved = Config.compatibleFromJson(
        jsonDecode(store.getString(configKey)!) as Map<String, dynamic>,
      );
      expect(
        saved.patchClashConfig.dns.nameserverPolicy,
        migrated.patchClashConfig.dns.nameserverPolicy,
      );
    },
  );
}
