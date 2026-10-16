import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';

/// item 6 (Bettbox 1.19.3) — loopback protection.
///
/// `buildLoopbackRules` is pure and top-level precisely so these assertions can
/// exist: its call site sits in the middle of a large async config patch that a
/// unit test cannot reach.
void main() {
  group('ClashConfig.listenPorts', () {
    test('joins every non-zero listener with a slash', () {
      const config = ClashConfig(
        mixedPort: 7890,
        port: 7891,
        socksPort: 7892,
        redirPort: 7893,
        tproxyPort: 7894,
      );
      expect(config.listenPorts, '7890/7891/7892/7893/7894');
    });

    test('drops unset ports instead of emitting zeros', () {
      // A zero port means "not listening"; feeding `0` to DST-PORT would be
      // meaningless at best.
      const config = ClashConfig(mixedPort: 7890);
      expect(config.listenPorts, '7890');
    });

    test('is empty when nothing is listening', () {
      const config = ClashConfig(
        mixedPort: 0,
        port: 0,
        socksPort: 0,
        redirPort: 0,
        tproxyPort: 0,
      );
      expect(config.listenPorts, isEmpty);
    });
  });

  group('buildLoopbackRules', () {
    test('rejects loopback to the listener on both address families', () {
      const config = ClashConfig(mixedPort: 7890, port: 7891);
      final rules = buildLoopbackRules(config, isAndroid: false);

      expect(rules, [
        'AND,((DST-PORT,7890/7891),(IP-CIDR,127.0.0.0/8,no-resolve)),REJECT',
        'AND,((DST-PORT,7890/7891),(IP-CIDR6,::1/128,no-resolve)),REJECT',
      ]);
    });

    test('emits nothing port-based when nothing is listening', () {
      const config = ClashConfig(
        mixedPort: 0,
        port: 0,
        socksPort: 0,
        redirPort: 0,
        tproxyPort: 0,
      );
      expect(buildLoopbackRules(config, isAndroid: false), isEmpty);
    });

    test('adds the Android DoT rule only on Android', () {
      const config = ClashConfig(mixedPort: 7890);

      final android = buildLoopbackRules(config, isAndroid: true);
      expect(android, hasLength(3));
      expect(
        android.last,
        'AND,((DST-PORT,853),(IP-CIDR,198.51.100.0/30,no-resolve)),REJECT',
      );

      final desktop = buildLoopbackRules(config, isAndroid: false);
      expect(desktop, hasLength(2));
      expect(
        desktop.any((rule) => rule.contains('853')),
        isFalse,
      );
    });

    test('the Android rule survives an otherwise empty port set', () {
      // The two halves are independent: a device with no listener still gets the
      // platform-specific rule.
      const config = ClashConfig(
        mixedPort: 0,
        port: 0,
        socksPort: 0,
        redirPort: 0,
        tproxyPort: 0,
      );
      final rules = buildLoopbackRules(config, isAndroid: true);
      expect(rules, hasLength(1));
      expect(rules.single, contains('853'));
    });
  });
}
