package io.fluxora.app.services

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder
import io.fluxora.app.GlobalState
import io.fluxora.app.models.VpnOptions

class FluxoraService : Service(), BaseServiceInterface {

    private val binder = LocalBinder()
    @Volatile
    private var isStopped = false
    private val foregroundNotification = ForegroundNotification(this) { isStopped }

    private val fairMemoryHelper = FairMemoryHelper("FluxoraService")

    override fun onCreate() {
        super.onCreate()
        fairMemoryHelper.register(
            context = this,
            onTrim = { GlobalState.getCurrentVPNPlugin()?.requestGc() },
            onKill = { /* system will kill process; service has no extra state to save */ }
        )
    }

    inner class LocalBinder : Binder() {
        fun getService() = this@FluxoraService
    }

    override suspend fun start(options: VpnOptions) = 0

    override fun stop() {
        if (isStopped) return
        isStopped = true

        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                stopForeground(true)
            }
        }.onFailure { android.util.Log.e("FluxoraService", "Failed to stop foreground: ${it.message}") }

        runCatching {
            getSystemService(android.app.NotificationManager::class.java)
                ?.cancel(GlobalState.NOTIFICATION_ID)
        }.onFailure { android.util.Log.e("FluxoraService", "Failed to cancel notification: ${it.message}") }

        stopSelf()
    }

    override suspend fun startForeground() = foregroundNotification.update(force = true)

    override suspend fun updateNotificationSpeed(speedInfo: String) =
        foregroundNotification.update(speedInfo = speedInfo)

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level == 10 || level == 15 || level >= 40) {
            GlobalState.getCurrentVPNPlugin()?.requestGc()
        }
    }

    override fun onBind(intent: Intent): IBinder = binder

    /// Notification action dispatch.
    ///
    /// Stop is handled here (nothing else needs to know); switch, reset and
    /// speed test are forwarded to the app, because they operate on the config,
    /// the connection table and the delay state — all of which live in Dart.
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        handleNotificationAction(intent)
        return START_NOT_STICKY
    }

    companion object {
        const val ACTION_STOP = "io.fluxora.app.action.STOP"
        const val ACTION_SWITCH = "io.fluxora.app.action.SWITCH"
        const val ACTION_RESET = "io.fluxora.app.action.RESET"
        const val ACTION_SPEED_TEST = "io.fluxora.app.action.SPEED_TEST"

        /// Drops and re-posts the notification so a reset is visible.
        /// Handled natively: the feedback must not depend on Dart being
        /// reachable.
        const val ACTION_FLASH = "io.fluxora.app.action.FLASH"
    }

    override fun onDestroy() {
        stop()
        fairMemoryHelper.unregister(this)
        super.onDestroy()
    }
}
