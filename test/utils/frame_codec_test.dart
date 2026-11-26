import 'dart:async';
import 'dart:typed_data';

import 'package:fluxora/utils/frame_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fragmented and coalesced frames preserve UTF-8 and empty messages', () {
    const values = ['', '中文节点 🇨🇳', 'last'];
    final wire = Uint8List.fromList([
      for (final value in values) ...FrameCodec.encode(value),
    ]);
    for (var chunk = 1; chunk <= wire.length; chunk++) {
      final decoder = FrameDecoder();
      final received = <String>[];
      for (var i = 0; i < wire.length; i += chunk) {
        received.addAll(
          decoder.decode(
            Uint8List.sublistView(
              wire,
              i,
              i + chunk < wire.length ? i + chunk : wire.length,
            ),
          ),
        );
      }
      expect(received, values, reason: 'chunk size $chunk');
    }
  });

  test('partial input is owned independently of a reused caller buffer', () {
    final decoder = FrameDecoder();
    final frame = FrameCodec.encode('abcdef');
    final first = Uint8List.fromList(frame.sublist(0, 6));
    expect(decoder.decode(first), isEmpty);
    first.fillRange(0, first.length, 255);
    expect(decoder.decode(Uint8List.sublistView(frame, 6)), ['abcdef']);
  });

  test(
    'invalid lengths and UTF-8 clear state and allow the next valid frame',
    () {
      final invalid = Uint8List(4);
      ByteData.sublistView(
        invalid,
      ).setUint32(0, 10 * 1024 * 1024 + 1, Endian.little);
      final decoder = FrameDecoder();
      for (final data in [
        invalid,
        Uint8List.fromList([1, 0, 0, 0, 255]),
      ]) {
        expect(() => decoder.decode(data), throwsFormatException);
        expect(decoder.decode(FrameCodec.encode('recovered')), ['recovered']);
      }
    },
  );

  test('reset discards incomplete header and payload', () {
    final decoder = FrameDecoder();
    final frame = FrameCodec.encode('discarded');
    for (final size in [2, 6]) {
      expect(decoder.decode(Uint8List.sublistView(frame, 0, size)), isEmpty);
      decoder.reset();
      expect(decoder.decode(FrameCodec.encode('new')), ['new']);
    }
  });

  test(
    'stream transformer receives a large frame in small fragments',
    () async {
      final value = '节点' * 200000;
      final frame = FrameCodec.encode(value);
      final parts = [
        for (var i = 0; i < frame.length; i += 4096)
          Uint8List.sublistView(
            frame,
            i,
            i + 4096 < frame.length ? i + 4096 : frame.length,
          ),
      ];
      final results = await Stream.fromIterable(
        parts,
      ).transform(FrameDecoderTransformer()).toList();
      expect(results, [value]);
    },
  );
}
