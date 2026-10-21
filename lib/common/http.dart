import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/state.dart';

class FluxoraHttpOverrides extends HttpOverrides {
  static String handleFindProxy(Uri url) {
    if ([localhost].contains(url.host)) {
      return 'DIRECT';
    }
    final isStart = globalState.appState.runTime != null;
    // 用 effectiveMixedPort，不是配置里的值：端口被占用时内核会在本次会话
    // 里改用另一个端口，还按配置值连就会直接连接被拒——IP 检测就是这样
    // 变成"请尝试手动刷新"的。
    return proxyRuleFor(
      isStart: isStart,
      port: globalState.appController.effectiveMixedPort,
    );
  }

  /// 纯函数：决定某次请求要不要走代理、走哪个端口。
  ///
  /// 抽出来是为了能测：真实调用依赖 `globalState`，测试里起不来，而这段
  /// 逻辑正是"端口避让后连错端口"出问题的地方。
  @visibleForTesting
  static String proxyRuleFor({required bool isStart, required int port}) {
    return isStart ? 'PROXY localhost:$port' : 'DIRECT';
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (_, _, _) => true;
    client.findProxy = handleFindProxy;
    return client;
  }
}
