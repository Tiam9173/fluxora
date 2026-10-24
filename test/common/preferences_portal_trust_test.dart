import 'package:fluxora/common/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Preferences preferences;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.sharedPreferencesCompleter.future;
  });

  setUp(() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    await prefs?.remove(Preferences.trustedPortalHostsKey);
  });

  test('trusted portal host is normalized and deduplicated', () async {
    await preferences.trustPortalHost('Example.COM');
    await preferences.trustPortalHost('example.com');

    expect(await preferences.isPortalHostTrusted('example.com'), isTrue);
    expect(await preferences.isPortalHostTrusted('EXAMPLE.COM'), isTrue);
    expect(await preferences.isPortalHostTrusted('other.example'), isFalse);
  });

  test('empty host is never trusted', () async {
    await preferences.trustPortalHost('   ');

    expect(await preferences.isPortalHostTrusted(''), isFalse);
  });
}
