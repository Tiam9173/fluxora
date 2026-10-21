import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// 测试环境统一加载项目自带的字体。
///
/// 主题里指定了 `fontFamily`（HarmonyOS Sans 等），但测试不会走 assets 加载，
/// 于是每个平台各自回退到系统字体：Windows 和 Linux runner 的字宽不同，同一个
/// 布局测试在两边一个溢出、一个不溢出。
///
/// 这里在**所有测试文件之前**把真实字体注册进去，文本度量就和平台无关了。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await _loadFont('HarmonyOS_Sans', 'assets/fonts/HarmonyOS_Sans_SC_Regular.ttf');
  await _loadFont('JetBrainsMono', 'assets/fonts/JetBrainsMono-Regular.ttf');
  await testMain();
}

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final bytes = ByteData.sublistView(file.readAsBytesSync());
  final loader = FontLoader(family)..addFont(Future.value(bytes));
  await loader.load();
}
