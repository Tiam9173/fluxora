import 'package:fluxora/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('looksLikeScript', () {
    test('accepts ordinary scripts', () {
      expect(
        JavaScriptRuntimeManager.looksLikeScript(
          'function main(config) { return config; }',
        ),
        isTrue,
      );
      expect(
        JavaScriptRuntimeManager.looksLikeScript('  \n// comment\nvar a = 1;'),
        isTrue,
      );
    });

    test('rejects an HTML page', () {
      // GitHub 的页面地址返回 200 + 整页 HTML。存下来只会在启用时报
      // `unexpected token '<'`，用户看不出是链接贴错了。
      const html = '<!DOCTYPE html>\n<html lang="en" data-color-mode="auto">';
      expect(JavaScriptRuntimeManager.looksLikeScript(html), isFalse);
    });

    test('rejects an empty response', () {
      expect(JavaScriptRuntimeManager.looksLikeScript(''), isFalse);
      expect(JavaScriptRuntimeManager.looksLikeScript('   \n  '), isFalse);
    });

    test('an XML error body is rejected too', () {
      expect(
        JavaScriptRuntimeManager.looksLikeScript('<?xml version="1.0"?>'),
        isFalse,
      );
    });
  });
}
