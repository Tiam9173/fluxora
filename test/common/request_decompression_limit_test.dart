import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fluxora/common/request.dart';
import 'package:fluxora/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _maxDecompressedBytes = 64 * 1024 * 1024;

void main() {
  setUpAll(() {
    globalState.packageInfo = PackageInfo(
      appName: 'Fluxora',
      packageName: 'io.fluxora.app',
      version: 'test',
      buildNumber: '0',
    );
  });

  Future<void> expectDeflatePayload(
    List<int> Function(List<int>) encode,
  ) async {
    final expected = Uint8List.fromList(List<int>.filled(1024, 0x42));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response.headers.set(
        HttpHeaders.contentEncodingHeader,
        'deflate',
      );
      request.response.add(encode(expected));
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final response = await Request().getFileResponseForUrl(
      'http://127.0.0.1:${server.port}/subscription',
    );

    expect(response.data, expected);
  }

  test('accepts a gzip response below the output limit', () async {
    final expected = Uint8List.fromList(List<int>.filled(1024, 0x41));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      request.response.add(gzip.encode(expected));
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final response = await Request().getFileResponseForUrl(
      'http://127.0.0.1:${server.port}/subscription',
    );

    expect(response.data, expected);
  });

  test('accepts a gzip response exactly at the output limit', () async {
    final expected = Uint8List(_maxDecompressedBytes);
    final compressed = gzip.encode(expected);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      request.response.add(compressed);
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final response = await Request().getFileResponseForUrl(
      'http://127.0.0.1:${server.port}/subscription',
    );

    expect((response.data as Uint8List).length, _maxDecompressedBytes);
  });

  test('accepts zlib-wrapped deflate below the output limit', () async {
    await expectDeflatePayload(zlib.encoder.convert);
  });

  test('accepts raw deflate fallback below the output limit', () async {
    await expectDeflatePayload(ZLibEncoder(raw: true).convert);
  });

  test('rejects a gzip response that expands past the output limit', () async {
    final oversized = Uint8List.fromList(
      List<int>.filled(_maxDecompressedBytes + 1, 0x41),
    );
    final compressed = gzip.encode(oversized);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      request.response.add(compressed);
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    await expectLater(
      Request().getFileResponseForUrl(
        'http://127.0.0.1:${server.port}/subscription',
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Decompressed response exceeds 64 MiB',
        ),
      ),
    );
  });

  test(
    'rejects a truncated gzip response instead of returning compressed data',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
        request.response.add([0x1f, 0x8b, 0x08, 0x00]);
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });

      await expectLater(
        Request().getFileResponseForUrl(
          'http://127.0.0.1:${server.port}/subscription',
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('cancels a pending subscription response', () async {
    final requestArrived = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) {
      if (!requestArrived.isCompleted) requestArrived.complete();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });
    final cancelToken = CancelToken();
    final response = Request().getFileResponseForUrl(
      'http://127.0.0.1:${server.port}/subscription',
      cancelToken: cancelToken,
    );

    await requestArrived.future;
    cancelToken.cancel('test cancellation');

    await expectLater(response, throwsA(isA<DioException>()));
  });

  test('accepts an empty uncompressed response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final response = await Request().getFileResponseForUrl(
      'http://127.0.0.1:${server.port}/subscription',
    );

    expect(response.data, isEmpty);
  });

  test('rejects an encoded response body over 64 MiB while streaming', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      final chunk = Uint8List(64 * 1024);
      var remaining = _maxDecompressedBytes + 1;
      var sent = 0;
      try {
        while (remaining > 0) {
          final length = remaining < chunk.length ? remaining : chunk.length;
          request.response.add(chunk.sublist(0, length));
          remaining -= length;
          sent += length;
          if (sent % (4 * 1024 * 1024) == 0) {
            await request.response.flush();
          }
        }
        await request.response.close();
      } on HttpException {
        // The bounded reader cancels the response as soon as it crosses limit.
      }
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    await expectLater(
      Request().getFileResponseForUrl(
        'http://127.0.0.1:${server.port}/large-response',
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'HTTP response body exceeds 64 MiB',
        ),
      ),
    );
  });

  test('accepts an encoded response body exactly at 64 MiB', () async {
    final payload = Uint8List(_maxDecompressedBytes);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response.add(payload);
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final response = await Request().getFileResponseForUrl(
      'http://127.0.0.1:${server.port}/limit-response',
    );

    expect((response.data as Uint8List).length, _maxDecompressedBytes);
  });
}
