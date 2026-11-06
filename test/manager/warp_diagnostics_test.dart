import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/core.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/manager/warp_manager.dart';

class _OfflineCore extends Fake implements ClashHandlerInterface {
  @override
  Future<bool> get isInit async => false;
  @override
  bool get hasLiveProcess => false;
}

class _Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  String? value(String name) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, this.body);
  @override
  final int statusCode;
  final String body;
  @override
  final HttpHeaders headers = _Headers();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(body)).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.response);
  final Future<HttpClientResponse> response;
  @override
  final HttpHeaders headers = _Headers();
  @override
  set followRedirects(bool value) {}
  @override
  Future<HttpClientResponse> close() => response;
}

class _Client extends Fake implements HttpClient {
  _Client(this.response);
  final Future<HttpClientResponse> response;
  bool closed = false;
  bool certificateBypass = false;
  @override
  set connectionTimeout(Duration? timeout) {}
  @override
  set findProxy(String Function(Uri)? callback) {}
  @override
  set badCertificateCallback(
    bool Function(X509Certificate, String, int)? callback,
  ) {
    certificateBypass = callback != null;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(response);
  @override
  void close({bool force = false}) {
    closed = true;
  }
}

void main() {
  late ClashHandlerInterface original;
  setUp(() {
    original = clashCore.clashInterface;
    clashCore.clashInterface = _OfflineCore();
  });
  tearDown(() => clashCore.clashInterface = original);

  test(
    'duplicate diagnostics share work and close both HTTP clients',
    () async {
      final trace = Completer<HttpClientResponse>();
      final clients = <_Client>[];
      await HttpOverrides.runZoned(
        () async {
          final first = warpManager.checkWarpStatus();
          final second = warpManager.checkWarpStatus();
          expect(identical(first, second), isTrue);
          await Future<void>.delayed(Duration.zero);
          expect(clients, hasLength(1));
          trace.complete(
            _Response(200, 'warp=on\nip=203.0.113.1\ncolo=FRA\nloc=DE\n'),
          );
          final report = await first;
          expect(report.isSuccess, isTrue);
          expect(report.isWarpActive, isTrue);
          expect(clients, hasLength(2));
          expect(clients.every((c) => c.closed), isTrue);
          expect(clients.any((c) => c.certificateBypass), isFalse);
          expect(warpManager.isTesting, isFalse);
        },
        createHttpClient: (_) {
          final client = _Client(
            clients.isEmpty ? trace.future : Future.value(_Response(204, '')),
          );
          clients.add(client);
          return client;
        },
      );
    },
  );

  test(
    'a stalled response has a whole-request deadline and releases the client',
    () {
      fakeAsync((clock) {
        final clients = <_Client>[];
        var completed = false;
        HttpOverrides.runZoned(
          () {
            warpManager.checkWarpStatus().then((report) {
              expect(report.isSuccess, isFalse);
              completed = true;
            });
            clock.flushMicrotasks();
            expect(warpManager.isTesting, isTrue);
            clock.elapse(const Duration(seconds: 13));
            expect(completed, isTrue);
            expect(clients.single.closed, isTrue);
            expect(warpManager.isTesting, isFalse);
          },
          createHttpClient: (_) {
            final client = _Client(Completer<HttpClientResponse>().future);
            clients.add(client);
            return client;
          },
        );
      });
    },
  );

  test('an HTTP error is a failed diagnostic and can be retried', () async {
    final clients = <_Client>[];
    await HttpOverrides.runZoned(
      () async {
        final first = await warpManager.checkWarpStatus();
        expect(first.isSuccess, isFalse);
        expect(clients.single.closed, isTrue);
        final second = await warpManager.checkWarpStatus();
        expect(second.isSuccess, isFalse);
        expect(clients, hasLength(2));
        expect(clients.every((c) => c.closed), isTrue);
      },
      createHttpClient: (_) {
        final client = _Client(Future.value(_Response(503, 'not a trace')));
        clients.add(client);
        return client;
      },
    );
  });
}
