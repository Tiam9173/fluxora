import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'dart:typed_data';

class FrameCodec {
  static Uint8List encode(String data) {
    final bytes = utf8.encode(data);
    final frame = Uint8List(4 + bytes.length);
    final buffer = ByteData.sublistView(frame);
    buffer.setUint32(0, bytes.length, Endian.little);
    frame.setRange(4, frame.length, bytes);
    return frame;
  }
}

class FrameDecoder {
  final BytesBuilder _builder = BytesBuilder();
  final Uint8List _header = Uint8List(4);
  int _headerLength = 0;
  int? _length;

  List<String> decode(Uint8List data) {
    final results = <String>[];
    int offset = 0;

    try {
      while (offset < data.length) {
        if (_length == null) {
          final count = min(4 - _headerLength, data.length - offset);
          _header.setRange(_headerLength, _headerLength + count, data, offset);
          _headerLength += count;
          offset += count;
          if (_headerLength < 4) break;
          final length = ByteData.sublistView(
            _header,
          ).getUint32(0, Endian.little);
          if (length > 10 * 1024 * 1024) {
            throw FormatException('Invalid or too large frame length: $length');
          }
          _length = length;
        }
        final length = _length!;
        if (_builder.isEmpty && data.length - offset >= length) {
          results.add(
            utf8.decode(Uint8List.sublistView(data, offset, offset + length)),
          );
          offset += length;
          _length = null;
          _headerLength = 0;
          continue;
        }
        final count = min(length - _builder.length, data.length - offset);
        _builder.add(Uint8List.sublistView(data, offset, offset + count));
        offset += count;
        if (_builder.length < length) break;
        results.add(utf8.decode(_builder.takeBytes()));
        _length = null;
        _headerLength = 0;
      }
    } catch (e) {
      reset();
      rethrow;
    }

    return results;
  }

  void reset() {
    _builder.clear();
    _length = null;
    _headerLength = 0;
  }
}

class FrameDecoderTransformer extends StreamTransformerBase<Uint8List, String> {
  @override
  Stream<String> bind(Stream<Uint8List> stream) {
    final decoder = FrameDecoder();
    return stream.expand((data) => decoder.decode(data));
  }
}
