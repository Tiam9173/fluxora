package io.fluxora.app

import android.content.ComponentName
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.service.quicksettings.TileService
import io.fluxora.app.plugins.AppPlugin
import io.fluxora.app.plugins.ServicePlugin
import io.fluxora.app.plugins.TilePlugin
import io.fluxora.app.plugins.VpnPlugin
import io.fluxora.app.services.FluxoraTileService
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

enum class RunState {
    START,
    PENDING,
    STOP
}

object GlobalState {
    val runLock = ReentrantLock()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val mainHandler = Handler(Looper.getMainLooper())

    const val NOTIFICATION_CHANNEL = "Fluxora"
    const val NOTIFICATION_CHANNEL_HIGH = "Fluxora_High"
    const val NOTIFICATION_CHANNEL_SUSPENDED = "Fluxora_Suspended"
    const val NOTIFICATION_ID = 1

    private const val TOGGLE_DEBOUNCE_MS = 1000L
    private const val PENDING_TIMEOUT_MS = 5000L
    private const val PENDING_TIMEOUT_RETRIES = 2
    private const val STOP_LOCK_TIMEOUT_MS = 5000L
    private const val VPN_STATE_PREFS = "vpn_state"
    private const val WAS_RUNNING_KEY = "was_running"

    @Volatile
    private var lastToggleAt = 0L

    /// Latest user intent. A tap during PENDING only changes this value; the
    /// in-flight transition reconciles to it when it settles.
    @Volatile
    private var requestedRunning = false

    @Volatile
    private var hasDeferredIntent = false

    private var pendingTimeoutRetries = 0

    @Volatile
    var currentRunState: RunState = RunState.STOP
        private set

    private val _runState = MutableStateFlow(RunState.STOP)
    val runState = _runState.asStateFlow()

    private var pendingTimeoutJob: Job? = null

    var flutterEngine: FlutterEngine? = null
    private var serviceEngine: FlutterEngine? = null

    @Volatile
    var isSmartStopped = false

    @Volatile
    var isStopping = false

    @Volatile
    var currentProfileName: String = ""
        set(value) {
            if (field != value) {
                field = value
                requestTileUpdate()
            }
        }

    @Volatile
    var isSpeedNotificationEnabled: Boolean = false
        set(value) {
            if (field != value) {
                field = value
                requestTileUpdate()
            }
        }

    @Volatile
    var isNotificationHighPriority: Boolean = false

    fun updateRunState(newState: RunState) {
        if (currentRunState == newState) return

        if (newState != RunState.PENDING) {
            pendingTimeoutJob?.cancel()
            pendingTimeoutJob = null
            pendingTimeoutRetries = 0
            persistWasRunning(newState == RunState.START)
        }
        currentRunState = newState
        _runState.value = newState
        requestTileUpdate()

        if (newState != RunState.PENDING) {
            if (!hasDeferredIntent) {
                requestedRunning = newState == RunState.START
            }
            scope.launch { reconcileDeferredIntent(newState) }
        }
    }

    private fun reconcileDeferredIntent(settledState: RunState) {
        if (!hasDeferredIntent) return
        hasDeferredIntent = false
        when {
            settledState == RunState.START && !requestedRunning ->
                beginStop(allowPending = false)
            settledState == RunState.STOP && requestedRunning ->
                beginStart()
        }
    }

    private fun persistWasRunning(value: Boolean) {
        runCatching {
            FluxoraApplication.getAppContext()
                .getSharedPreferences(VPN_STATE_PREFS, android.content.Context.MODE_PRIVATE)
                .edit()
                .putBoolean(WAS_RUNNING_KEY, value)
                .apply()
        }
    }

    /// Whether the tunnel was running when the previous process ended. Used by
    /// the package-replaced receiver so an app update never starts a VPN the
    /// user had deliberately stopped.
    fun wasRunningBeforeRestart(): Boolean = runCatching {
        FluxoraApplication.getAppContext()
            .getSharedPreferences(VPN_STATE_PREFS, android.content.Context.MODE_PRIVATE)
            .getBoolean(WAS_RUNNING_KEY, false)
    }.getOrDefault(false)

    private val tileRetryRunnable = Runnable {
        FluxoraTileService.refreshActive()
        requestListeningStateSafely()
    }

    fun requestTileUpdate() {
        mainHandler.post {
            FluxoraTileService.refreshActive()
            requestListeningStateSafely()
            mainHandler.removeCallbacks(tileRetryRunnable)
            mainHandler.postDelayed(tileRetryRunnable, 1000L)
        }
    }

    private fun requestListeningStateSafely() {
        runCatching {
            val context = FluxoraApplication.getAppContext()
            TileService.requestListeningState(
                context,
                ComponentName(context, FluxoraTileService::class.java)
            )
        }.onFailure {
            android.util.Log.w("GlobalState", "requestTileUpdate failed: ${it.message}")
        }
    }

    private fun startPendingTimeout() {
        pendingTimeoutJob?.cancel()
        pendingTimeoutJob = scope.launch {
            delay(PENDING_TIMEOUT_MS)
            pendingTimeoutJob = null
            if (currentRunState != RunState.PENDING) return@launch

            if (!VpnPlugin.isServiceConnected()) {
                android.util.Log.w(
                    "GlobalState",
                    "PENDING timed out without a connected service; resetting to STOP",
                )
                updateRunState(RunState.STOP)
                return@launch
            }

            // A connected service can still be starting the core. Do not claim
            // STOP while the tunnel may come up; force a deferred stop when the
            // latest user intent is stop, otherwise keep waiting honestly.
            if (hasDeferredIntent && !requestedRunning) {
                hasDeferredIntent = false
                beginStop(allowPending = true)
                return@launch
            }

            if (pendingTimeoutRetries < PENDING_TIMEOUT_RETRIES) {
                pendingTimeoutRetries++
                android.util.Log.w(
                    "GlobalState",
                    "PENDING timed out with a connected service; waiting (retry $pendingTimeoutRetries)",
                )
                startPendingTimeout()
            } else {
                android.util.Log.w(
                    "GlobalState",
                    "PENDING still unresolved after retries; preserving PENDING state",
                )
            }
        }
    }

    fun updateIsStopping(value: Boolean) {
        isStopping = value
        runCatching {
            val ts = if (value) System.currentTimeMillis() else 0L
            FluxoraApplication.getAppContext()
                .getSharedPreferences("vpn_state", android.content.Context.MODE_PRIVATE)
                .edit()
                .putLong("stop_lock_ts", ts)
                .apply()
        }
    }

    fun isCurrentlyStopping(): Boolean {
        if (isStopping) return true
        return runCatching {
            val sp = FluxoraApplication.getAppContext()
                .getSharedPreferences("vpn_state", android.content.Context.MODE_PRIVATE)
            val ts = sp.getLong("stop_lock_ts", 0L)
            if (ts == 0L) return false

            val now = System.currentTimeMillis()
            if (now - ts > STOP_LOCK_TIMEOUT_MS) {
                sp.edit().remove("stop_lock_ts").apply()
                false
            } else {
                true
            }
        }.getOrDefault(false)
    }

    fun getCurrentAppPlugin(): AppPlugin? {
        val currentEngine = flutterEngine ?: serviceEngine
        return currentEngine?.plugins?.get(AppPlugin::class.java) as? AppPlugin
    }

    fun syncStatus() {
        if (currentRunState == RunState.PENDING) return
        val status = VpnPlugin.getStatus()
        requestedRunning = status
        updateRunState(if (status) RunState.START else RunState.STOP)
    }

    suspend fun getText(text: String): String = getCurrentAppPlugin()?.getText(text) ?: ""

    fun getCurrentTilePlugin(): TilePlugin? {
        val currentEngine = flutterEngine ?: serviceEngine
        return currentEngine?.plugins?.get(TilePlugin::class.java) as? TilePlugin
    }

    /// Set when a notification button cold-starts the app. Dart consumes it as
    /// soon as its channel is live, which removes the guesswork of posting the
    /// request after some arbitrary delay.
    @Volatile
    var pendingNotificationAction: String? = null

    /// Set when the app was launched purely to host the switch card.
    @Volatile
    var cardOnlyLaunch: Boolean = false

    /// 当前前台 Activity。卡片关闭时需要它把任务退到后台。
    var currentActivity: android.app.Activity? = null

    /// 主界面是否在后台。
    ///
    /// onStop 置位、onResume 清除。通知动作走 onNewIntent（在 onResume 之前），
    /// 所以那时读到的仍是"点通知前"的状态——用它判断该不该浮出卡片。
    var appInBackground: Boolean = false

    /// Notification button labels pushed from Dart so they follow the in-app
    /// language rather than the system one.
    @Volatile
    var notificationLabels: Map<String, String>? = null

    fun getCurrentVPNPlugin(): VpnPlugin? {
        return serviceEngine?.plugins?.get(VpnPlugin::class.java) as? VpnPlugin
    }

    fun handleToggle() {
        if (!acquireToggleSlot()) return
        val targetRunning = when (currentRunState) {
            RunState.START -> false
            RunState.STOP -> true
            RunState.PENDING -> !requestedRunning
        }
        requestedRunning = targetRunning
        when (currentRunState) {
            RunState.START -> if (!targetRunning) beginStop(allowPending = false)
            RunState.STOP -> if (targetRunning) beginStart()
            RunState.PENDING -> hasDeferredIntent = true
        }
    }

    fun handleStart(skipDebounce: Boolean = false): Boolean {
        if (!skipDebounce && !acquireToggleSlot()) return false
        return beginStart()
    }

    fun handleStop(skipDebounce: Boolean = false) {
        if (!skipDebounce && !acquireToggleSlot()) return
        beginStop(allowPending = false)
    }

    private fun beginStart(): Boolean {
        if (currentRunState != RunState.STOP) return false
        requestedRunning = true
        hasDeferredIntent = false
        updateRunState(RunState.PENDING)
        startPendingTimeout()
        runLock.withLock {
            getCurrentTilePlugin()?.handleStart() ?: initServiceEngine()
        }
        return true
    }

    private fun beginStop(allowPending: Boolean) {
        val allowed = currentRunState == RunState.START ||
            (allowPending && currentRunState == RunState.PENDING)
        if (!allowed) return

        requestedRunning = false
        hasDeferredIntent = false
        if (currentRunState != RunState.PENDING) {
            updateRunState(RunState.PENDING)
        }
        startPendingTimeout()
        runLock.withLock {
            val tilePlugin = getCurrentTilePlugin()
            if (tilePlugin != null) {
                tilePlugin.handleStop()
            } else {
                VpnPlugin.handleStop(force = true)
            }
        }
    }

    private fun acquireToggleSlot(): Boolean {
        val now = SystemClock.elapsedRealtime()
        synchronized(this) {
            if (now - lastToggleAt < TOGGLE_DEBOUNCE_MS) return false
            lastToggleAt = now
            return true
        }
    }

    fun handleTryDestroy() {
        if (flutterEngine == null) destroyServiceEngine()
    }

    fun destroyServiceEngine() {
        runLock.withLock {
            serviceEngine?.destroy()
            serviceEngine = null
        }
    }

    fun initServiceEngine(flags: List<String>? = null) {
        runLock.withLock {
            if (serviceEngine != null) return
            
            val defaultArgs = if (flutterEngine == null && !isCurrentlyStopping()) listOf("quick") else null
            val args = flags ?: defaultArgs
            
            val app = FluxoraApplication.getAppContext() as FluxoraApplication
            val vpnService = DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "_service"
            )
            val options = io.flutter.embedding.engine.FlutterEngineGroup.Options(app).apply {
                dartEntrypoint = vpnService
                dartEntrypointArgs = args
            }
            
            serviceEngine = app.engineGroup.createAndRunEngine(options).apply {
                GeneratedPluginRegistrant.registerWith(this)
                listOf(VpnPlugin, AppPlugin(), TilePlugin(), ServicePlugin()).forEach { plugin ->
                    if (plugins.get(plugin.javaClass) == null) {
                        plugins.add(plugin)
                    }
                }
            }
        }
    }

    fun isServiceEngineRunning(): Boolean = serviceEngine != null

    fun reconnectIpc() {
        (serviceEngine?.plugins?.get(TilePlugin::class.java) as? TilePlugin)?.handleReconnectIpc()
    }
}
