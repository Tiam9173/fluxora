package io.fluxora.app.services

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.fluxora.app.GlobalState
import io.fluxora.app.R

object NotificationIconTheme {
    @Volatile var isDark: Boolean = false

    fun setStyle(context: Context, style: String): Boolean {
        require(style in listOf("flow", "plain", "outline")) { "Unknown notification icon" }
        val prefs = context.getSharedPreferences("fluxora_brand", Context.MODE_PRIVATE)
        if (prefs.getString("notification_style", "flow") == style) return false
        check(prefs.edit().putString("notification_style", style).commit()) {
            "Unable to save notification icon"
        }
        return true
    }

    @Suppress("DEPRECATION")
    fun postedIconDiffers(context: Context): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        val notification = manager.activeNotifications
            .firstOrNull { it.id == GlobalState.NOTIFICATION_ID && it.tag == null }
            ?.notification ?: return false
        val posted = if (Build.VERSION.SDK_INT >= 28) notification.smallIcon?.resId else notification.icon
        return posted != smallIcon(context)
    }

    fun smallIcon(context: Context): Int = when (
        context.getSharedPreferences("fluxora_brand", Context.MODE_PRIVATE)
            .getString("notification_style", "flow")
    ) {
        "plain" -> R.drawable.ic_notification_plain
        "outline" -> R.drawable.ic_notification_outline
        else -> R.drawable.ic_notification_flow
    }
}
