import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/http.dart';

void main() {
  test(
    'HTTP checks use the local proxy and a fresh retry can recover',
    () async {
      final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var status = HttpStatus.serviceUnavailable;
      var requests = 0;
      proxy.listen((request) {
        requests++;
        expect(request.uri.host, 'unresolvable.invalid');
        request.response.statusCode = status;
        request.response.close();
      });
      try {
        final url = Uri.parse('http://unresolvable.invalid/generate_204');
        expect(
          await probeProxyConnection(HttpClient(), url, proxy.port),
          isFalse,
        );
        status = HttpStatus.noContent;
        expect(
          await probeProxyConnection(HttpClient(), url, proxy.port),
          isTrue,
        );
        expect(requests, 2);
      } finally {
        await proxy.close(force: true);
      }
    },
  );

  test(
    'redirects do not turn a captive portal into a successful check',
    () async {
      final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      proxy.listen((request) {
        requests++;
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          'http://portal.invalid/login',
        );
        request.response.close();
      });
      try {
        expect(
          await probeProxyConnection(
            HttpClient(),
            Uri.parse('http://probe.invalid/'),
            proxy.port,
          ),
          isFalse,
        );
        expect(requests, 1);
      } finally {
        await proxy.close(force: true);
      }
    },
  );

  test('superseding a pending check closes its connection promptly', () async {
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<void>();
    proxy.listen((request) => received.complete());
    final client = HttpClient();
    try {
      final result = probeProxyConnection(
        client,
        Uri.parse('http://probe.invalid/'),
        proxy.port,
      );
      await received.future;
      client.close(force: true);
      expect(await result.timeout(const Duration(seconds: 1)), isFalse);
    } finally {
      await proxy.close(force: true);
    }
  });

  test(
    'invalid endpoints and missing proxy ports fail without hanging',
    () async {
      expect(
        await probeProxyConnection(
          HttpClient(),
          Uri.parse('file:///tmp/probe'),
          1234,
        ),
        isFalse,
      );
      expect(
        await probeProxyConnection(
          HttpClient(),
          Uri.parse('https://example.invalid/'),
          0,
        ),
        isFalse,
      );
    },
  );
}
