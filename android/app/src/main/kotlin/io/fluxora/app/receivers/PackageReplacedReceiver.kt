package io.fluxora.app.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.VpnService
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

        runCatching {
            if (VpnService.prepare(context) != null) {
                Log.w(TAG, "App updated but VPN permission requires user approval")
                return@runCatching
            }
            val started = GlobalState.handleStart(skipDebounce = true)
            Log.d(TAG, "App updated while VPN was running; restart requested=$started")
        }.onFailure { Log.e(TAG, "VPN restore after update failed", it) }
    }
}
