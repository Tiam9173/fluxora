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
    await preferences.consumePendingAutoDelayTest();
  });

  test('pending auto-delay marker is consumed exactly once', () async {
    await preferences.markPendingAutoDelayTest();
    expect(await preferences.hasPendingAutoDelayTest(), isTrue);

    expect(await preferences.consumePendingAutoDelayTest(), isTrue);
    expect(await preferences.hasPendingAutoDelayTest(), isFalse);
    expect(await preferences.consumePendingAutoDelayTest(), isFalse);
  });

  test('stale marker is discarded without triggering a probe', () async {
    await preferences.markPendingAutoDelayTest();

    final staleNow = DateTime.now().add(const Duration(minutes: 11));
    expect(
      await preferences.consumePendingAutoDelayTest(now: staleNow),
      isFalse,
    );
  });

  test('a future timestamp is not treated as fresh', () async {
    await preferences.markPendingAutoDelayTest();

    final earlier = DateTime.now().subtract(const Duration(minutes: 1));
    expect(
      await preferences.consumePendingAutoDelayTest(now: earlier),
      isFalse,
    );
  });
}
