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

/// 通知栏「切换」卡片。
///
/// 独立 Activity + 独立引擎，而不是复用主界面：
///
/// * 窗口透明属性只能在窗口创建前定。复用主窗口时，App 一旦运行过，那个窗口
///   就是不透明的，之后无论怎么设都改不回来。
/// * 一个 `FlutterEngine` 同时只能挂一个 Activity。主界面在后台时虽然可以
///   detach/attach，但返回时重建容易黑屏。
///
/// `RenderMode.texture` 是另一半：Flutter 默认用 `SurfaceView` 渲染，它单独
/// 占一个图层，不参与窗口的透明合成 —— 窗口再透明，画布也是黑的。`TextureView`
/// 是普通 View，会跟着窗口 alpha 一起合成。
class CardActivity : FlutterActivity() {
    companion object {
        private const val CARD_ENGINE_ID = "fluxora_card_engine"

        /// 清掉缓存引擎：Activity 真正退出后，下次进来重新起一个更省事。
        fun releaseEngine() {
            FlutterEngineCache.getInstance().get(CARD_ENGINE_ID)?.destroy()
            FlutterEngineCache.getInstance().remove(CARD_ENGINE_ID)
        }
    }

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun onCreate(savedInstanceState: Bundle?) {
        // 主题由 Manifest 指定（TranslucentTheme），这里只保证窗口本身也不画背景。
        window.setBackgroundDrawable(
            android.graphics.drawable.ColorDrawable(android.graphics.Color.TRANSPARENT)
        )
        super.onCreate(savedInstanceState)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(CARD_ENGINE_ID)?.let { return it }

        val app = applicationContext as FluxoraApplication
        val options = FlutterEngineGroup.Options(app).apply {
            dartEntrypoint = DartExecutor.DartEntrypoint(
                "package:fluxora/card_only_main.dart",
                "cardMain",
            )
        }
        return app.engineGroup.createAndRunEngine(options).apply {
            cache.put(CARD_ENGINE_ID, this)
            // 卡片自己的通道：只做「切换节点」和「关闭」，不复用主 App 的 vpn 通道，
            // 免得两个引擎抢同一个 MethodChannel。
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
