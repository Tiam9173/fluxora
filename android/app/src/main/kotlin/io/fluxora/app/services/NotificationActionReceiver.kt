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
        runCatching {
            when (action) {
                FluxoraService.ACTION_STOP -> plugin.requestNotificationStop()
                FluxoraService.ACTION_RESET -> plugin.requestNotificationReset()
                FluxoraService.ACTION_SPEED_TEST -> plugin.requestNotificationSpeedTest()
            }
        }.onFailure { Log.e(TAG, "$action: forward failed: ${it.message}") }
    }

    companion object {
        private const val TAG = "NotificationAction"
    }
}
