package io.fluxora.app.services

import android.content.Context
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

    fun smallIcon(context: Context): Int = when (
        context.getSharedPreferences("fluxora_brand", Context.MODE_PRIVATE)
            .getString("notification_style", "flow")
    ) {
        "plain" -> R.drawable.ic_notification_plain
        "outline" -> R.drawable.ic_notification_outline
        else -> R.drawable.ic_notification_flow
    }
}
