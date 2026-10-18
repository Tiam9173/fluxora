package io.fluxora.app.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.fluxora.app.GlobalState

/// Receives the notification's action buttons.
///
/// `PendingIntent.getService` never reached `onStartCommand` — the taps did
/// nothing while the `getActivity` one (switch) worked, which points at service
/// intents rather than at the buttons. Broadcasts are what ownbox uses for the
/// same buttons, and a manifest-declared receiver also keeps working when the
/// service is not the one that posted the notification.
class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val action = intent?.action ?: return
        Log.i(TAG, "received $action")
        val plugin = GlobalState.getCurrentVPNPlugin()
        if (plugin == null) {
            Log.w(TAG, "$action: no VpnPlugin attached")
            return
        }
        val delivered = runCatching {
            when (action) {
                FluxoraService.ACTION_STOP -> plugin.requestNotificationStop()
                FluxoraService.ACTION_RESET -> plugin.requestNotificationReset()
                FluxoraService.ACTION_SPEED_TEST -> plugin.requestNotificationSpeedTest()
                // Without this the when is not exhaustive over String and the
                // whole expression degrades to Unit.
                else -> false
            }
        }.getOrElse {
            Log.e(TAG, "$action: forward failed: ${it.message}")
            false
        }

        // No Dart side attached (the UI was torn down while the tunnel kept
        // running) — stopping must still work, so do it here.
        if (!delivered && action == FluxoraService.ACTION_STOP) {
            Log.w(TAG, "stop: no Dart channel, stopping natively")
            context?.let {
                it.stopService(Intent(it, FluxoraVpnService::class.java))
                it.stopService(Intent(it, FluxoraService::class.java))
            }
        }
    }

    companion object {
        private const val TAG = "NotificationAction"
    }
}
