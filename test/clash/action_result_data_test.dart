import 'dart:convert';

import 'package:fluxora/clash/lib.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unwraps a successful ActionResult string payload', () {
    final raw = json.encode({
      'id': 'speed-1',
      'method': 'getTraffic',
      'data': '{"up":123,"down":456}',
      'code': 0,
    });

    expect(decodeActionResultData(raw), '{"up":123,"down":456}');
  });

  test('re-encodes a successful map payload', () {
    final raw = json.encode({
      'id': 'speed-2',
      'method': 'getTraffic',
      'data': {'up': 7, 'down': 8},
      'code': 0,
    });

    final decoded = json.decode(decodeActionResultData(raw)!);
    expect(decoded['up'], 7);
    expect(decoded['down'], 8);
  });

  test('rejects an ActionResult error envelope', () {
    final raw = json.encode({
      'id': 'speed-3',
      'method': 'getTraffic',
      'data': 'core not ready',
      'code': -1,
    });

    expect(decodeActionResultData(raw), isNull);
  });

  test('rejects malformed or non-envelope data', () {
    expect(decodeActionResultData(''), isNull);
    expect(decodeActionResultData('not json'), isNull);
    expect(decodeActionResultData('{"up":1,"down":2}'), isNull);
    expect(decodeActionResultData('[]'), isNull);
  });
}
