package io.fluxora.app

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/// 通知栏「切换」卡片。
///
/// 独立 Activity，但**复用主引擎**：
///
/// * 独立 Activity 是必须的 —— 窗口透明属性只能在窗口创建前定，主窗口一旦
///   创建就是不透明的，复用主窗口永远做不出"卡片浮在桌面上"。
/// * `RenderMode.texture` 是另一半 —— Flutter 默认用 `SurfaceView`，它单独占
///   一个图层、不参与窗口透明合成，窗口再透明画布也是黑的。
/// * 引擎复用主缓存而不是另起一个 —— 卡片要显示的正是主 App 的状态（订阅、
///   分组、延迟），共用引擎才拿得到；另起引擎等于把整个 App 再启动一遍。
class CardActivity : FlutterActivity() {
    companion object {
        private const val MAIN_ENGINE_ID = "fluxora_main_engine"
    }

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // Dart 侧据此把根节点换成卡片；由 `isCardOnlyLaunch` 读取并清零。
        GlobalState.cardOnlyLaunch = true
        GlobalState.currentActivity = this
        // 复用主引擎时窗口格式不会自动跟着变透明，必须显式设置；否则主题
        // 是半透明的、画布却按不透明合成，四周就是一片白。
        window.setFormat(android.graphics.PixelFormat.TRANSLUCENT)
        window.setBackgroundDrawable(
            android.graphics.drawable.ColorDrawable(android.graphics.Color.TRANSPARENT)
        )
        super.onCreate(savedInstanceState)

        // 引擎可能在 onCreate 期间才建好，等它就绪再把 Dart 切到卡片模式。
        if (flutterEngine != null) {
            notifyDart()
        } else {
            window.decorView.postDelayed({ notifyDart() }, 150)
        }
    }

    override fun onDestroy() {
        // 让 Dart 把根节点切回主界面，否则下次正常打开 App 还是卡片页。
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, "vpn").invokeMethod("cardModeOff", null)
        }
        super.onDestroy()
    }

    private fun notifyDart() {
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger ?: return
        MethodChannel(messenger, "vpn").invokeMethod("notificationSwitch", null)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(MAIN_ENGINE_ID)?.let { return it }

        // 主 App 没跑过：按默认入口起一个，Dart 侧会因为 cardOnlyLaunch 直接
        // 进入卡片模式，不会去渲染主界面。
        val app = applicationContext as FluxoraApplication
        val options = FlutterEngineGroup.Options(app).apply {
            dartEntrypoint = DartExecutor.DartEntrypoint.createDefault()
        }
        return app.engineGroup.createAndRunEngine(options).apply {
            GeneratedPluginRegistrant.registerWith(this)
            cache.put(MAIN_ENGINE_ID, this)
        }
    }
}
