package io.fluxora.app.services

import android.content.ComponentName
import android.content.Context

object NotificationComponentCache {

    @Volatile
    private var cached: ComponentName? = null

    fun get(context: Context): ComponentName {
        cached?.let { return it }

        synchronized(this) {
            cached?.let { return it }
            val result = checkNotNull(context.packageManager
                .getLaunchIntentForPackage(context.packageName)?.component) {
                "No enabled Fluxora launcher component"
            }
            cached = result
            return result
        }
    }

    @Synchronized
    fun invalidate() {
        cached = null
    }

}
