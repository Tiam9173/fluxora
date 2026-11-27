import 'package:fluxora/common/system.dart';
import 'package:fluxora/common/utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('service');

  setUp(() {
    System.platformOverride = 'android';
  });

  tearDown(() {
    System.platformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'distinguishes no strict resolver from a failed platform read',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => '');
      expect(await utils.getAndroidPrivateDnsServerName(), '');

      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      expect(await utils.getAndroidPrivateDnsServerName(), isNull);
    },
  );
}
