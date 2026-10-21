import 'package:fluxora/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('suggestScriptLabel', () {
    test('uses the file name from the url', () {
      expect(
        suggestScriptLabel(
          content: 'function main(c) { return c; }',
          url: 'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/'
              'master/rewrite/Advertising.js',
        ),
        'Advertising',
      );
    });

    test('falls back to the parent directory for generic file names', () {
      // .../Advertising/main.js 里的 "main" 说明不了任何事，用目录名。
      expect(
        suggestScriptLabel(
          content: 'function main(c) { return c; }',
          url: 'https://example.com/rewrite/Advertising/main.js',
        ),
        'Advertising',
      );
    });

    test('decodes percent escapes', () {
      expect(
        suggestScriptLabel(
          content: 'function main(c) { return c; }',
          url: 'https://example.com/%E5%B9%BF%E5%91%8A.js',
        ),
        '广告',
      );
    });

    test('a @name comment wins over the file name', () {
      const content = '''
// @name 广告拦截
function main(config) { return config; }
''';
      expect(
        suggestScriptLabel(
          content: content,
          url: 'https://example.com/whatever.js',
        ),
        '广告拦截',
      );
    });

    test('an imported file uses its own name', () {
      expect(
        suggestScriptLabel(
          content: 'function main(c) { return c; }',
          fileName: 'my-rules.plugin',
        ),
        'my-rules',
      );
    });

    test('returns null when there is nothing to go on', () {
      expect(
        suggestScriptLabel(content: 'function main(c) { return c; }'),
        isNull,
      );
    });

    test('clips a very long name', () {
      final label = suggestScriptLabel(
        content: 'function main(c) { return c; }',
        url: 'https://example.com/${'a' * 60}.js',
      );
      expect(label, isNotNull);
      expect(label!.length, lessThanOrEqualTo(24));
    });
  });
}
