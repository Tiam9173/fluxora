package io.fluxora.app.services

import android.content.Context
import io.fluxora.app.R

object NotificationIconTheme {
    @Volatile var isDark: Boolean = false

    fun setStyle(context: Context, style: String) {
        require(style in listOf("flow", "plain", "outline")) { "Unknown notification icon" }
        check(context.getSharedPreferences("fluxora_brand", Context.MODE_PRIVATE).edit()
            .putString("notification_style", style).commit()) { "Unable to save notification icon" }
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
