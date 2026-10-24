package io.fluxora.app.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.fluxora.app.GlobalState

class PackageReplacedReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "PackageReplacedReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return

        if (!GlobalState.wasRunningBeforeRestart()) {
            Log.d(TAG, "App updated while VPN was stopped; not starting it")
            return
        }

        if (Build.VERSION.SDK_INT >= 36) {
            val started = GlobalState.handleStart(skipDebounce = true)
            Log.d(TAG, "App updated while VPN was running; restart requested=$started")
        } else {
            runCatching {
                android.net.VpnService.prepare(context)
            }.onFailure { Log.e(TAG, "Prepare failed", it) }
        }
    }
}
