import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';

class _LoopbackClient extends Fake implements HttpClient {
  _LoopbackClient(this.client, this.port, {this.onProxyRule});

  final void Function(String)? onProxyRule;
  final HttpClient client;
  final int port;

  @override
  set autoUncompress(bool value) => client.autoUncompress = value;

  @override
  set connectionTimeout(Duration? value) => client.connectionTimeout = value;

  @override
  set findProxy(String Function(Uri)? callback) {
    onProxyRule?.call(callback!(Uri.https('ip.example')));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      client.openUrl(method, Uri.http('127.0.0.1:$port', '/${url.host}'));

  @override
  void close({bool force = false}) => client.close(force: force);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('direct IP detection overrides the inherited proxy rule', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.write(
        '{"status":"success","query":"192.0.2.10","countryCode":"US"}',
      );
      await request.response.close();
    });
    final real = FluxoraHttpOverrides().createHttpClient(null)
      ..findProxy = (_) => 'DIRECT';
    final rules = <String>[];

    final result = await HttpOverrides.runZoned(
      () => Request().checkIp(direct: true, retries: 0),
      createHttpClient: (_) =>
          _LoopbackClient(real, server.port, onProxyRule: rules.add),
    );
    expect(result.data?.ip, '192.0.2.10');
    expect(rules, isNotEmpty);
    expect(rules, everyElement('DIRECT'));
  });

  test(
    'the built-in probe displays a late IPv6 result without waiting for it',
    () async {
      final old = globalState.config;
      addTearDown(() => globalState.config = old);
      globalState.config = old.copyWith(
        patchClashConfig: old.patchClashConfig.copyWith(ipv6: true),
        appSetting: old.appSetting.copyWith(
          networkDetectionUrl: defaultNetworkDetectionUrl,
        ),
      );
      final gate = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        if (!gate.isCompleted) gate.complete();
        await server.close(force: true);
      });
      server.listen((request) async {
        if (request.uri.path == '/get.geojs.io') {
          await gate.future;
          request.response.write('{"ip":"2001:db8::10","country_code":"JP"}');
        } else {
          request.response.write(
            '{"status":"success","query":"192.0.2.10","countryCode":"US"}',
          );
        }
        await request.response.close();
      });
      final real = FluxoraHttpOverrides().createHttpClient(null)
        ..findProxy = (_) => 'DIRECT';
      final update = Completer<IpInfo>();
      await HttpOverrides.runZoned(() async {
        final result = await Request().checkIp(
          retries: 0,
          onUpdate: (info) {
            if (info.ip == '2001:db8::10' && !update.isCompleted) {
              update.complete(info);
            }
          },
        );
        expect(result.data?.ip, '192.0.2.10');
        gate.complete();
        expect(
          (await update.future.timeout(
            const Duration(seconds: 3),
          )).flagCountryCode,
          'JP',
        );
      }, createHttpClient: (_) => _LoopbackClient(real, server.port));
    },
  );
}
