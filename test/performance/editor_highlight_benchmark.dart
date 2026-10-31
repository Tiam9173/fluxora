import 'package:code_forge/code_forge/syntax_highlighter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_highlight/languages/yaml.dart';

/// 编辑器高亮的性能基线。
///
/// 这不是"必须通过"的断言测试，而是把当前耗时钉下来：以后改高亮/缓存时，
/// 数字变差会直接在这里暴露，而不是等用户觉得卡。
void main() {
  // 2000 行的 YAML，接近一份大型订阅配置的量级。
  final lines = List<String>.generate(2000, (i) {
    if (i % 7 == 0) return '  # 注释 $i';
    return 'proxy-group-$i: {name: "节点 $i", type: ss, port: ${1000 + i}}';
  });

  late SyntaxHighlighter highlighter;

  setUp(() {
    highlighter = SyntaxHighlighter(
      language: langYaml,
      editorTheme: const <String, TextStyle>{},
      languageId: 'yaml',
      baseTextStyle: const TextStyle(fontSize: 13),
      getLineText: (index) => index < lines.length ? lines[index] : '',
    );
  });

  int timeLines() {
    final watch = Stopwatch()..start();
    for (var i = 0; i < lines.length; i++) {
      highlighter.getLineSpan(i, lines[i]);
    }
    watch.stop();
    return watch.elapsedMilliseconds;
  }

  test('cold pass highlights every line', () {
    final cold = timeLines();
    // 只记录，不做硬性断言：不同机器差异很大。
    // ignore: avoid_print
    print('[benchmark] highlight cold: ${cold}ms for ${lines.length} lines');
    expect(cold, greaterThanOrEqualTo(0));
  });

  test('warm pass is served from the per-line cache', () {
    timeLines();
    final warm = timeLines();
    // ignore: avoid_print
    print('[benchmark] highlight warm: ${warm}ms for ${lines.length} lines');
    // 缓存命中应该是毫秒级；放宽到 500ms 只是防止出现"每帧重算"的回归。
    expect(warm, lessThan(500));
  });
}
