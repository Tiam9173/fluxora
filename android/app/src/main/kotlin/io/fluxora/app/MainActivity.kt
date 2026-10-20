package io.fluxora.app

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.fluxora.app.plugins.AppPlugin
import io.fluxora.app.plugins.ServicePlugin
import io.fluxora.app.plugins.TilePlugin
import io.fluxora.app.plugins.VpnPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import io.fluxora.app.services.EXTRA_SHOW_SWITCH_CARD

class MainActivity : FlutterActivity() {
    companion object {
        private const val MAIN_ENGINE_ID = "fluxora_main_engine"
    }

    private fun isTvDevice(context: Context): Boolean {
        val uiModeManager = context.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        if (uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
            return true
        }
        val packageManager = context.packageManager
        return packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                || packageManager.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
    }

    /// True when the notification's switch button launched us only to show the
    /// card. The window then has to be translucent, so the launcher shows
    /// around it instead of the app.
    private fun isCardOnlyLaunch(intent: Intent?): Boolean =
        intent?.getBooleanExtra(EXTRA_SHOW_SWITCH_CARD, false) == true

    override fun onCreate(savedInstanceState: Bundle?) {
        // 窗口始终透明：正常模式下 Flutter 根节点自己画不透明背景，看起来
        // 和以前完全一样；卡片模式下根节点画透明，桌面就透出来了。
        //
        // 之所以不能只在卡片启动时设：窗口属性只能在窗口创建前定，而"App 已
        // 在后台、点通知切节点"走的是 onNewIntent，那时窗口早就存在了。
        window.setFormat(android.graphics.PixelFormat.TRANSLUCENT)
        window.setBackgroundDrawable(
            android.graphics.drawable.ColorDrawable(android.graphics.Color.TRANSPARENT)
        )
        val isEngineCached = FlutterEngineCache.getInstance().contains(MAIN_ENGINE_ID)
        if (isTvDevice(this) || isEngineCached) {
            setTheme(R.style.NormalTheme)
        } else {
            installSplashScreen()
        }
        super.onCreate(savedInstanceState)
        handleSwitchCardIntent(intent, isColdStart = true)
    }

    override fun onStop() {
        super.onStop()
        GlobalState.appInBackground = true
    }

    override fun onResume() {
        super.onResume()
        GlobalState.appInBackground = false
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleSwitchCardIntent(intent, isColdStart = false)
    }

    /// The notification's switch button launches this activity with an extra.
    /// It is consumed here rather than forwarded from the service, because the
    /// card needs a live UI — and the service has no way to know whether one
    /// exists.
    private fun handleSwitchCardIntent(intent: Intent?, isColdStart: Boolean) {
        if (intent?.getBooleanExtra(EXTRA_SHOW_SWITCH_CARD, false) != true) return
        intent.removeExtra(EXTRA_SHOW_SWITCH_CARD)
        // Recorded rather than posted on a timer: on a cold start the engine is
        // still booting and a fixed delay either fires too early (no handler
        // yet) or too late (user already navigated). Dart pulls it when ready.
        GlobalState.pendingNotificationAction = "switch"
        // 窗口现在始终透明，所以卡片模式不再受"冷启动"限制：只要用户不是在
        // App 里（后台或刚启动），就浮在桌面上显示卡片。
        //
        // `appInBackground` 在 onStop 置位、onResume 清除，而 onNewIntent 在
        // onResume 之前触发，所以这里读到的仍是启动前的状态。
        GlobalState.cardOnlyLaunch = isColdStart || GlobalState.appInBackground
        // When the app is already in the foreground there is no lifecycle
        // change, so nothing would ever pull the pending action. Push it now;
        // Dart ignores it if it has no navigator yet and pulls it on resume.
        GlobalState.flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            io.flutter.plugin.common.MethodChannel(messenger, "vpn")
                .invokeMethod("notificationSwitch", null)
        }
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val engineCache = FlutterEngineCache.getInstance()
        return engineCache.get(MAIN_ENGINE_ID) ?: createAndCacheEngine(context, engineCache)
    }

    private fun createAndCacheEngine(context: Context, cache: FlutterEngineCache): FlutterEngine {
        val app = context.applicationContext as FluxoraApplication
        val options = FlutterEngineGroup.Options(app).apply {
            dartEntrypoint = DartExecutor.DartEntrypoint.createDefault()
        }
        return app.engineGroup.createAndRunEngine(options).apply {
            GeneratedPluginRegistrant.registerWith(this)
            cache.put(MAIN_ENGINE_ID, this)
            GlobalState.flutterEngine = this
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        listOf(VpnPlugin, AppPlugin(), ServicePlugin(), TilePlugin()).forEach { plugin ->
            if (flutterEngine.plugins.get(plugin.javaClass) == null) {
                flutterEngine.plugins.add(plugin)
            }
        }

        setupHapticsChannel(flutterEngine)

        GlobalState.flutterEngine = flutterEngine
    }

    private fun setupHapticsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "code_forge/haptics")
            .setMethodCallHandler { call, result ->
                val decorView = window?.decorView
                if (decorView == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "handleMove" -> {
                        decorView.performHapticFeedback(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                HapticFeedbackConstants.TEXT_HANDLE_MOVE
                            } else {
                                HapticFeedbackConstants.LONG_PRESS
                            }
                        )
                        result.success(null)
                    }
                    "longPress" -> {
                        decorView.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        val engine = flutterEngine
        if (engine != null) {
            engine.navigationChannel.popRoute()
        } else {
            super.onBackPressed()
        }
    }

    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        return try {
            super.dispatchTouchEvent(ev)
        } catch (e: RuntimeException) {
            if (e.message?.contains("FlutterJNI is not attached to native") == true) {
                Log.w("MainActivity", "Ignore touch event while FlutterJNI is not attached")
                false
            } else {
                throw e
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
    }
}
