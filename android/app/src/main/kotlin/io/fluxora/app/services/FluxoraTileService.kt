package io.fluxora.app.services

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import io.fluxora.app.GlobalState
import io.fluxora.app.RunState
import io.fluxora.app.R
import io.fluxora.app.TempActivity
import io.fluxora.app.extensions.wrapAction
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

@RequiresApi(Build.VERSION_CODES.N)
class FluxoraTileService : TileService() {

    companion object {
        @Volatile
        private var activeInstance: FluxoraTileService? = null

        fun refreshActive() {
            activeInstance?.updateTile(GlobalState.currentRunState)
        }
    }

    private var scope: CoroutineScope? = null

    private fun updateTile(runState: RunState) {
        qsTile?.apply {
            state = when (runState) {
                RunState.START -> Tile.STATE_ACTIVE
                RunState.PENDING -> Tile.STATE_UNAVAILABLE
                RunState.STOP -> Tile.STATE_INACTIVE
            }
            if (GlobalState.isSpeedNotificationEnabled && GlobalState.currentProfileName.isNotEmpty()) {
                label = GlobalState.currentProfileName
            } else {
                label = getString(R.string.fluxora)
            }
            updateTile()
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        activeInstance = this
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        GlobalState.syncStatus()
        scope?.launch {
            GlobalState.runState.collect { updateTile(it) }
        }
    }

    override fun onStopListening() {
        if (activeInstance === this) {
            activeInstance = null
        }
        scope?.cancel()
        scope = null
        super.onStopListening()
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    override fun onClick() {
        super.onClick()
        // 磁贴没有 UI 上下文：VPN 授权弹窗、以 Activity 上下文启动服务都做不了。
        // 路由到透明中转站（TempActivity，立即 finish），由它带真实任务栈去
        // handleToggle——FlClash 同款做法，也是冷启动能成的关键。
        val intent = Intent(this, TempActivity::class.java).apply {
            action = wrapAction("CHANGE")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pi = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            startActivityAndCollapse(pi)
        } else if (isLocked) {
            // unlockAndRun needs a plain startActivity after the keyguard is
            // gone; collapsing first would discard the pending unlock action.
            unlockAndRun { startActivity(intent) }
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    override fun onDestroy() {
        if (activeInstance === this) {
            activeInstance = null
        }
        scope?.cancel()
        scope = null
        super.onDestroy()
    }
}