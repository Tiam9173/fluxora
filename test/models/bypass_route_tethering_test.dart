import 'package:fluxora/models/clash_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// 上游 issue #574：Android 16 的 Tethering 用零地址查 VPN 上游，
/// 默认私网绕过列表里没有能匹配 `0.0.0.0` 的路由，热点设备就断网。
void main() {
  group('resolveBypassRouteAddress', () {
    test('Android + 默认列表时补上 0.0.0.0/32', () {
      final routes = resolveBypassRouteAddress(isAndroid: true);

      expect(routes, contains('0.0.0.0/32'));
      // 默认项一个不少
      expect(
        routes,
        containsAll(defaultBypassPrivateRouteAddress),
      );
    });

    test('桌面平台不补：那条路由只对 Android Tethering 有意义', () {
      final routes = resolveBypassRouteAddress(isAndroid: false);

      expect(routes, isNot(contains('0.0.0.0/32')));
      expect(routes, containsAll(defaultBypassPrivateRouteAddress));
    });

    test('用户自定义路由时不改动：他清楚自己要什么', () {
      final routes = resolveBypassRouteAddress(
        isAndroid: true,
        custom: const ['10.0.0.0/8'],
      );

      expect(routes, equals(<String>['10.0.0.0/8']));
    });

    test('返回新列表，不污染全局默认值', () {
      final routes = resolveBypassRouteAddress(isAndroid: true);
      routes.add('9.9.9.9/32');

      expect(
        defaultBypassPrivateRouteAddress,
        isNot(contains('9.9.9.9/32')),
      );
      expect(
        defaultBypassPrivateRouteAddress,
        isNot(contains('0.0.0.0/32')),
      );
    });
  });
}
