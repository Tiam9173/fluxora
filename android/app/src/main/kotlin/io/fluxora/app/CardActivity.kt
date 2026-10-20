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
        private const val CARD_ENGINE_ID = "fluxora_card_engine"
    }

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        GlobalState.currentActivity = this
        // 复用主引擎时窗口格式不会自动跟着变透明，必须显式设置；否则主题
        // 是半透明的、画布却按不透明合成，四周就是一片白。
        window.setFormat(android.graphics.PixelFormat.TRANSLUCENT)
        window.setBackgroundDrawable(
            android.graphics.drawable.ColorDrawable(android.graphics.Color.TRANSPARENT)
        )
        super.onCreate(savedInstanceState)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(CARD_ENGINE_ID)?.let { return it }

        // 独立引擎：一个 FlutterEngine 只能服务一个 Activity，共用主引擎会让
        // 主界面回来时黑屏；而且渲染表面的透明性在第一个窗口创建时就定死，
        // 共用必然不透明。
        val app = applicationContext as FluxoraApplication
        val options = FlutterEngineGroup.Options(app).apply {
            dartEntrypoint = DartExecutor.DartEntrypoint(
                "package:fluxora/card_only_main.dart",
                "cardMain",
            )
        }
        return app.engineGroup.createAndRunEngine(options).apply {
            GeneratedPluginRegistrant.registerWith(this)
            cache.put(CARD_ENGINE_ID, this)
            MethodChannel(dartExecutor.binaryMessenger, "card")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "close" -> {
                            result.success(true)
                            finish()
                        }
                        else -> result.notImplemented()
                    }
                }
        }
    }
}
