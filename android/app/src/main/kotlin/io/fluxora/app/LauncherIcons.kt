package io.fluxora.app

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/** Finite, packaged resources only; user input is never a component name. */
object LauncherIcons {
    val styles = listOf("official", "classic", "aqua", "premium", "speed", "sky", "sunset", "blue_night")

    private fun suffix(style: String) = style.split('_').joinToString("") {
        it.replaceFirstChar { char -> char.uppercaseChar() }
    }

    private fun name(style: String, dark: Boolean) = when {
        style == "official" && !dark -> "io.fluxora.app.MainActivity"
        style == "official" -> "io.fluxora.app.MainActivityDark"
        else -> "io.fluxora.app.Icon${suffix(style)}${if (dark) "Dark" else "Light"}"
    }

    private fun components(context: Context) = buildList {
        for (style in styles) for (dark in listOf(false, true)) {
            add(ComponentName(context.packageName, name(style, dark)))
        }
        add(ComponentName(context.packageName, "io.fluxora.app.MainActivityLight"))
    }

    private fun enabled(pm: PackageManager, component: ComponentName): Boolean {
        return when (pm.getComponentEnabledSetting(component)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT ->
                component.className == "io.fluxora.app.MainActivity"
            else -> false
        }
    }

    fun current(context: Context): Map<String, Any> {
        val pm = context.packageManager
        for (style in styles) for (dark in listOf(false, true)) {
            if (enabled(pm, ComponentName(context.packageName, name(style, dark)))) {
                return mapOf("style" to style, "useDarkIcon" to dark)
            }
        }
        val legacy = ComponentName(context.packageName, "io.fluxora.app.MainActivityLight")
        check(enabled(pm, legacy)) { "No enabled Fluxora launcher component" }
        return mapOf("style" to "official", "useDarkIcon" to false)
    }

    fun set(context: Context, style: String, dark: Boolean) {
        require(style in styles) { "Unknown icon style" }
        val pm = context.packageManager
        val target = ComponentName(context.packageName, name(style, dark))
        val all = components(context)
        val before = all.associateWith { pm.getComponentEnabledSetting(it) }
        val flags = PackageManager.DONT_KILL_APP
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.setComponentEnabledSettings(all.map {
                PackageManager.ComponentEnabledSetting(it,
                    if (it == target) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                    else PackageManager.COMPONENT_ENABLED_STATE_DISABLED, flags)
            })
        } else {
            try {
                // Keep a launcher entry available throughout the pre-33 transition.
                pm.setComponentEnabledSetting(target, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, flags)
                all.filter { it != target }.forEach {
                    pm.setComponentEnabledSetting(it, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, flags)
                }
            } catch (error: Exception) {
                // Restore previously enabled entries before removing the new one.
                all.sortedBy { if (before[it] == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                    (before[it] == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT &&
                    it.className == "io.fluxora.app.MainActivity")) 0 else 1 }.forEach {
                    runCatching { pm.setComponentEnabledSetting(it, before.getValue(it), flags) }
                        .onFailure { rollbackError -> error.addSuppressed(rollbackError) }
                }
                throw error
            }
        }
    }
}
