import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 通知栏「切换」卡片专用的 Dart 入口。
///
/// 由 `CardActivity` 用独立引擎启动（`DartEntrypoint("cardMain")`），**不经过**
/// 主 App 的 `main()`：卡片只需要一屏内容，没必要把 controller、内核初始化、
/// 主界面路由全部跑一遍。
///
/// 第一步只验证一件事——窗口是否真的透明。确认之后再把 `SwitchCard` 接进来。
@pragma('vm:entry-point')
void cardMain() {
  runApp(const CardOnlyApp());
}

class CardOnlyApp extends StatelessWidget {
  const CardOnlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // MaterialApp 自己会画背景，不设透明的话卡片四周永远是黑的。
      color: Colors.transparent,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const CardOnlyScaffold(),
    );
  }
}

class CardOnlyScaffold extends StatelessWidget {
  const CardOnlyScaffold({super.key});

  Future<void> _close() async {
    try {
      await const MethodChannel('card').invokeMethod('close');
    } catch (_) {
      // 通道不可用时交给系统返回键处理。
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.layers_rounded, size: 32, color: colors.primary),
                  const SizedBox(height: 12),
                  const Text(
                    '卡片模式',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '如果这行字周围能看到桌面，说明透明生效了',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colors.outline),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _close,
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
