import 'dart:io';

import 'package:fluxora/common/http.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('proxy rule for app requests', () {
    test('app requests reject an untrusted HTTPS certificate', () async {
      final context = SecurityContext()
        ..useCertificateChain('core/Clash.Meta/test/config/example.org.pem')
        ..usePrivateKey('core/Clash.Meta/test/config/example.org-key.pem');
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      addTearDown(() => server.close(force: true));
      server.listen((request) => request.response.close());

      final client = FluxoraHttpOverrides().createHttpClient(null)
        ..findProxy = (_) => 'DIRECT';
      addTearDown(() => client.close(force: true));
      await expectLater(
        () async {
          final response = await client
              .getUrl(Uri.https('127.0.0.1:${server.port}'));
          await (await response.close()).drain<void>();
        },
        throwsA(isA<HandshakeException>()),
      );
    });

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
