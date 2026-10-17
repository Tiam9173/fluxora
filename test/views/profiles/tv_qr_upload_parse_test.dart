import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/views/profiles/tv_qr_import_dialog.dart';

/// item 6 ③ — the validation half of the LAN upload endpoint, pullable out of
/// the dialog precisely so the phone-facing decisions ("empty", "invalid
/// URL", default file name) are pinned without a running HttpServer or a TV.
void main() {
  group('parseTvUploadPayload — URL pushes', () {
    test('a valid subscription URL is accepted, trimmed', () {
      final result = parseTvUploadPayload({
        'url': '  https://example.com/sub.yaml  ',
      });

      expect(result.error, isNull);
      expect(result.payload, isNotNull);
      expect(result.payload!.isFile, isFalse);
      expect(result.payload!.url, 'https://example.com/sub.yaml');
    });

    test('an empty URL is rejected with the phone-facing message', () {
      final result = parseTvUploadPayload({'url': '   '});

      expect(result.payload, isNull);
      expect(result.error, 'Invalid URL');
    });

    test('a malformed URL is rejected, not guessed at', () {
      final result = parseTvUploadPayload({'url': 'not a url'});

      expect(result.payload, isNull);
      expect(result.error, 'Invalid URL');
    });

    test('a missing url field is rejected', () {
      final result = parseTvUploadPayload(<String, dynamic>{});

      expect(result.payload, isNull);
      expect(result.error, 'Invalid URL');
    });
  });

  group('parseTvUploadPayload — file pushes', () {
    test('type=file carries the content and the name', () {
      final result = parseTvUploadPayload({
        'type': 'file',
        'name': 'my.yaml',
        'content': 'proxies: []',
      });

      expect(result.error, isNull);
      expect(result.payload!.isFile, isTrue);
      expect(result.payload!.name, 'my.yaml');
      expect(result.payload!.content, 'proxies: []');
    });

    test('a bare content key is treated as a file push', () {
      final result = parseTvUploadPayload({'content': 'rules: []'});

      expect(result.payload!.isFile, isTrue);
      expect(result.payload!.content, 'rules: []');
    });

    test('a blank name falls back to config.yaml', () {
      final result = parseTvUploadPayload({
        'type': 'file',
        'name': '',
        'content': 'x: 1',
      });

      expect(result.payload!.name, 'config.yaml');
    });

    test('whitespace-only content is rejected as empty', () {
      final result = parseTvUploadPayload({
        'type': 'file',
        'name': 'my.yaml',
        'content': '   \n  ',
      });

      expect(result.payload, isNull);
      expect(result.error, 'Content is empty');
    });
  });
}
