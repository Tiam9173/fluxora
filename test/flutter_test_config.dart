import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/service.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir_cleanup.dart';

/// 测试环境统一加载项目自带的字体。
///
/// 主题里指定了 `fontFamily`（HarmonyOS Sans 等），但测试不会走 assets 加载，
/// 于是每个平台各自回退到系统字体：Windows 和 Linux runner 的字宽不同，同一个
/// 布局测试在两边一个溢出、一个不溢出。
///
/// 这里在**所有测试文件之前**把真实字体注册进去，文本度量就和平台无关了。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // R7-6: keep the core transport out of the test process. Any test that reads
  // `clashCore` constructs the real `ClashService`, which otherwise binds
  // %TEMP%\Fluxora_<n>.sock and spawns the core binary — neither can succeed
  // here, and the socket file was never unlinked. Set before `testMain()` so it
  // lands before the singleton is first touched.
  ClashService.skipTransportForTest = true;

  await _loadFont('HarmonyOS_Sans', 'assets/fonts/HarmonyOS_Sans_SC_Regular.ttf');
  await _loadFont('JetBrainsMono', 'assets/fonts/JetBrainsMono-Regular.ttf');

  // R7-8.2: 根级 tearDownAll 由框架在「本文件全部测试执行完之后」调用。
  // R7-8.1 曾用 try/finally 包住 testMain()，但 `testExecutable` 返回发生在
  // `declarer.build()` 之前，而测试体在 build 之后才跑，所以那段 finally 跑在
  // 任何测试之前 —— 那时目录还没被创建，清理成了空操作。
  // 框架侧依据：remote_listener.dart:136-155（declare → build → 执行），
  // engine.dart:380-387（遍历完组内所有 entry 之后才跑 group.tearDownAll，
  // 且「即使关闭或 setUpAll 失败」也跑）。
  tearDownAll(_cleanCurrentTestDataDir);

  await testMain();
}

/// R7-8.1 / R7-8.2 — 删除本进程自己那个 `AppPath` 测试沙箱。
///
/// `lib/common/path.dart:130-139` 在 `FLUTTER_TEST == 'true'` 时，于第一次读取
/// `appPath` 的那一刻创建 `systemTemp/fluxora_test_data_<pid>`，而全仓没有任何
/// 地方删除它。这个文件是唯一能包住 `test/` 下**每个**测试文件的入口，所以清理
/// 放在这里，而不是散到 14+ 个测试文件里 —— 那些文件根本覆盖不到真正触发创建的
/// **间接**读取（`globalState` / `Profile.getFile()` / `AppController` 等）。
///
/// 范围刻意收得很窄：
///  * 路径用与生产完全相同的 `p.join` + `pid` 规则重建，**不读任何 `AppPath`
///    getter** —— 读它反而会构造 `AppPath`，把正要查找的目录创建出来；
///  * 只碰当前 PID，因此同时运行的另一个测试进程（不同 PID）的沙箱不受影响；
///  * `deleteTempDirWithRetry` 在真正删除前会再确认目标确实是系统临时目录的
///    真实子目录（含 realpath 解析，能挡住 junction / 符号链接改道）。
///
/// 清理失败绝不允许改变测试结果：只写 stderr，不向外抛 —— 本函数现在是
/// `tearDownAll` 回调，抛出去会变成一条失败记录，把一次本该通过的跑变红。
Future<void> _cleanCurrentTestDataDir() async {
  // 与 `_testDataDir()` 的守卫逐字一致：不满足时生产侧根本不会建目录。
  if (Platform.environment['FLUTTER_TEST'] != 'true') return;

  final Directory dir = Directory(
    p.join(Directory.systemTemp.path, 'fluxora_test_data_$pid'),
  );

  try {
    if (!dir.existsSync()) return;
    await deleteTempDirWithRetry(dir);
  } catch (error) {
    stderr.writeln('test data dir cleanup failed for "${dir.path}": $error');
  }
}

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final bytes = ByteData.sublistView(file.readAsBytesSync());
  final loader = FontLoader(family)..addFont(Future.value(bytes));
  await loader.load();
}
