import 'dart:io';

import 'package:fluxora/common/http.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('proxy rule for app requests', () {
    test('nothing is proxied before the core is running', () {
      expect(
        FluxoraHttpOverrides.proxyRuleFor(isStart: false, port: 7890),
        'DIRECT',
      );
    });

    test('the rule uses the port it is given, not a fixed one', () {
      expect(
        FluxoraHttpOverrides.proxyRuleFor(isStart: true, port: 7891),
        'PROXY localhost:7891',
      );
      expect(
        FluxoraHttpOverrides.proxyRuleFor(isStart: true, port: 7890),
        'PROXY localhost:7890',
      );
    });
  });

  group('port fallback', () {
    test('the proxy rule is built from the session port, never the config', () {
      // 端口被占用时内核会在本次会话改用另一个端口。如果这里读的是配置值，
      // App 自己的请求（IP 检测、媒体解锁…）就会连到一个没人监听的端口上，
      // 表现是"网络正常但检测一直失败"。
      final source = File('lib/common/http.dart').readAsStringSync();

      expect(
        source.contains('effectiveMixedPort'),
        isTrue,
        reason: 'handleFindProxy must resolve the session port',
      );
      expect(
        source.contains('patchClashConfig.mixedPort'),
        isFalse,
        reason: 'the configured port is not necessarily the one in use',
      );
    });
  });
}
