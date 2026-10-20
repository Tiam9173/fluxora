package io.fluxora.app.services

import android.content.Context
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.app.Notification
import android.app.Notification.FOREGROUND_SERVICE_IMMEDIATE
import android.app.NotificationChannel
import android.app.NotificationManager
import android.widget.RemoteViews
import android.app.PendingIntent
import android.app.Service
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import io.fluxora.app.GlobalState
import io.fluxora.app.R
import io.fluxora.app.models.VpnOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.withContext
import android.content.ComponentName
import android.content.Intent

import android.graphics.BitmapFactory
import kotlinx.coroutines.launch

interface BaseServiceInterface {
    suspend fun start(options: VpnOptions): Int
    fun stop()
    suspend fun startForeground()
}

/// Builds the expanded (big) notification view with all four action buttons.
///
/// The stock layout renders at most three actions, so a fourth added through
/// `addAction` is dropped without a word. A custom big content view is the only
/// way to show four. The collapsed state is left to the system, which keeps the
/// notification collapsed until the user expands it.
fun Service.buildCollapsedNotificationViews(
    title: String,
    content: String
): RemoteViews {
    val views = RemoteViews(packageName, R.layout.notification_collapsed)
    views.setTextViewText(R.id.nf_title, title)
    views.setTextViewText(R.id.nf_speed, content)
    return views
}

fun Service.buildExpandedNotificationViews(
    title: String,
    content: String
): RemoteViews {
    val views = RemoteViews(packageName, R.layout.notification_expanded)
    views.setTextViewText(R.id.nf_title, title)
    views.setTextViewText(R.id.nf_speed, content)

    val flags = if (Build.VERSION.SDK_INT >= 31) {
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    } else {
        PendingIntent.FLAG_UPDATE_CURRENT
    }
    val serviceClass = this::class.java
    fun action(action: String, requestCode: Int): PendingIntent =
        PendingIntent.getService(
            this,
            requestCode,
            Intent(this, serviceClass).setAction(action).setPackage(packageName),
            flags
        )

    views.setOnClickPendingIntent(
        R.id.nf_stop, action(FluxoraService.ACTION_STOP, 101)
    )
    // Switch opens the app: the card needs a UI to draw in, and asking the
    // service to forward it only worked while the Flutter UI was still alive.
    views.setOnClickPendingIntent(R.id.nf_switch, buildSwitchCardIntent(flags))
    views.setOnClickPendingIntent(
        R.id.nf_reset, action(FluxoraService.ACTION_RESET, 103)
    )
    views.setOnClickPendingIntent(
        R.id.nf_speed_test, action(FluxoraService.ACTION_SPEED_TEST, 104)
    )
    return views
}

/// Opens the app and asks it to show the compact switch card.
///
/// The previous implementation forwarded the action to Dart, which needed a live
/// navigator context — null whenever the UI had been torn down, so the button
/// did nothing. Launching the activity first guarantees there is a UI to draw in.
fun Service.buildSwitchCardIntent(flags: Int): PendingIntent {
    // 直接启动独立的透明 Activity：主窗口一旦创建就是不透明的，复用它永远
    // 得不到"卡片浮在桌面上"的效果。
    val intent = Intent(this, io.fluxora.app.CardActivity::class.java).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        putExtra(EXTRA_SHOW_SWITCH_CARD, true)
    }
    return PendingIntent.getActivity(this, 102, intent, flags)
}

const val EXTRA_SHOW_SWITCH_CARD = "io.fluxora.app.extra.SHOW_SWITCH_CARD"

/// Shared notification-action dispatch.
///
/// Two different services can own the notification: [FluxoraVpnService] while
/// the tunnel is up and [FluxoraService] otherwise. They share no superclass,
/// so the handling lives here and each of them calls it from onStartCommand.
/// Returns true when the intent was an action button.
fun BaseServiceInterface.handleNotificationAction(intent: Intent?): Boolean {
    val action = intent?.action ?: return false
    if (!action.startsWith("io.fluxora.app.action.")) return false
    // Every branch logs: a silent button is indistinguishable from a broken
    // one, and the notification is the only place a user can press these.
    android.util.Log.i(TAG, "action=$action service=${this::class.java.simpleName}")
    return when (action) {
        FluxoraService.ACTION_STOP -> {
            // Stopping the service alone leaves Dart believing the tunnel is
            // still up, and its state machine then starts it again - which
            // looks exactly like "stop restarts the service". Ask the app to
            // stop; fall back to a plain stop if no engine is attached.
            val plugin = GlobalState.getCurrentVPNPlugin()
            if (plugin == null) {
                android.util.Log.w(TAG, "stop: no VpnPlugin, stopping service only")
                stop()
            } else {
                runCatching { plugin.requestNotificationStop() }.onFailure {
                    android.util.Log.e(TAG, "stop: forward failed: ${it.message}")
                    stop()
                }
            }
            true
        }
        FluxoraService.ACTION_SWITCH -> {
            forwardToApp("switch") {
                GlobalState.getCurrentVPNPlugin()?.requestNotificationSwitch()
            }
            true
        }
        FluxoraService.ACTION_RESET -> {
            forwardToApp("reset") {
                GlobalState.getCurrentVPNPlugin()?.requestNotificationReset()
            }
            true
        }
        FluxoraService.ACTION_FLASH -> {
            val vpnService = this as? FluxoraVpnService
            if (vpnService == null) {
                android.util.Log.w(TAG, "flash: not a VPN service")
            } else {
                kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main)
                    .launch { vpnService.flashNotification() }
            }
            true
        }
        FluxoraService.ACTION_SPEED_TEST -> {
            forwardToApp("speedTest") {
                GlobalState.getCurrentVPNPlugin()?.requestNotificationSpeedTest()
            }
            true
        }
        else -> false
    }
}

private const val TAG = "NotificationAction"

/// Forwards an action to Dart, logging the failure mode instead of dropping it.
private inline fun forwardToApp(name: String, block: () -> Unit) {
    val plugin = GlobalState.getCurrentVPNPlugin()
    if (plugin == null) {
        android.util.Log.w(TAG, "$name: no VpnPlugin attached (app not running?)")
        return
    }
    runCatching { block() }.onFailure {
        android.util.Log.e(TAG, "$name: forward failed: ${it.message}")
    }
}

suspend fun Service.createFluxoraNotificationBuilder(
    isSuspended: Boolean = GlobalState.isSmartStopped,
    isHighPriority: Boolean = GlobalState.isNotificationHighPriority
): NotificationCompat.Builder =
    withContext(Dispatchers.IO) {
        val defaultComponent = ComponentName(packageName, "io.fluxora.app.MainActivity")
        val lightComponent = ComponentName(packageName, "io.fluxora.app.MainActivityLight")
        val darkComponent = ComponentName(packageName, "io.fluxora.app.MainActivityDark")

        val targetComponent = NotificationComponentCache.get(packageManager, defaultComponent, lightComponent, darkComponent)

        android.util.Log.d("Notification", "Using ${targetComponent.className}")

        val intent = Intent().apply {
            component = targetComponent
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val flags = if (Build.VERSION.SDK_INT >= 31) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = withContext(Dispatchers.Main) {
            PendingIntent.getActivity(this@createFluxoraNotificationBuilder, 0, intent, flags)
        }

        val isDark = targetComponent == darkComponent
        val largeIconRes = if (isDark) {
            R.mipmap.ic_launcher
        } else {
            R.mipmap.ic_launcher_light
        }

        val largeIconBitmap = runCatching {
            BitmapFactory.decodeResource(resources, largeIconRes)
        }.getOrNull()

        val channelId = when {
            isSuspended -> GlobalState.NOTIFICATION_CHANNEL_SUSPENDED
            isHighPriority -> GlobalState.NOTIFICATION_CHANNEL_HIGH
            else -> GlobalState.NOTIFICATION_CHANNEL
        }
        val priority = if (isSuspended || isHighPriority) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_LOW

        NotificationCompat.Builder(this@createFluxoraNotificationBuilder, channelId).apply {
            setSmallIcon(R.drawable.ic)
            if (largeIconBitmap != null) {
                setLargeIcon(largeIconBitmap)
            }
            setContentTitle(getString(R.string.fluxora))
            setContentIntent(pendingIntent)
            setCategory(NotificationCompat.CATEGORY_SERVICE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                foregroundServiceBehavior = FOREGROUND_SERVICE_IMMEDIATE
            }
            setOngoing(true)
            setShowWhen(true)
            setOnlyAlertOnce(true)
            setPriority(priority)

            // Action buttons. Android renders its own expand chevron in the
            // collapsed state as soon as a notification carries actions, so
            // there is no custom expanded layout to maintain.
            //
            // The intents target *this* service class, so the buttons reach the
            // instance that built the notification (VpnService or plain
            // service) and land in its onStartCommand.
            val serviceClass = this@createFluxoraNotificationBuilder::class.java
            // Broadcasts, not getService: service intents from a notification
            // never reached onStartCommand here, while the getActivity one
            // (switch) did. ownbox uses broadcasts for these same buttons.
            fun actionIntent(action: String, requestCode: Int): PendingIntent =
                PendingIntent.getBroadcast(
                    this@createFluxoraNotificationBuilder,
                    requestCode,
                    Intent(action).setPackage(packageName),
                    flags
                )

            addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                (GlobalState.notificationLabels?.get("stop") ?: getString(R.string.action_stop)),
                actionIntent(FluxoraService.ACTION_STOP, 101)
            )
            addAction(
                android.R.drawable.ic_menu_compass,
                (GlobalState.notificationLabels?.get("switch") ?: getString(R.string.action_switch)),
                buildSwitchCardIntent(flags)
            )
            addAction(
                android.R.drawable.ic_menu_rotate,
                (GlobalState.notificationLabels?.get("reset") ?: getString(R.string.action_reset)),
                actionIntent(FluxoraService.ACTION_RESET, 103)
            )

            // Four buttons do not fit the stock layout, so the expanded state is
            // ours. The collapsed state stays the system one, which is what
            // keeps the notification closed until the user taps it.
            // Standard actions only. A custom RemoteViews layout rendered fine
            // but its buttons never dispatched: taps on a custom content view
            // are not turned into notification actions the way the stock row
            // is. ownbox (SagerNet) uses the stock row for the same reason.
            // The platform shows three, so speed test lives in the switch card
            // instead of being a fourth button that would never appear.
        }
    }

fun Service.ensureNotificationChannel(
    isSuspended: Boolean = GlobalState.isSmartStopped,
    isHighPriority: Boolean = GlobalState.isNotificationHighPriority
) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val manager = getSystemService(NotificationManager::class.java) ?: return
    val channelId = when {
        isSuspended -> GlobalState.NOTIFICATION_CHANNEL_SUSPENDED
        isHighPriority -> GlobalState.NOTIFICATION_CHANNEL_HIGH
        else -> GlobalState.NOTIFICATION_CHANNEL
    }
    val channel = manager.getNotificationChannel(channelId)
    if (channel == null) {
        val importance = when {
            isSuspended -> NotificationManager.IMPORTANCE_DEFAULT
            isHighPriority -> NotificationManager.IMPORTANCE_HIGH
            else -> NotificationManager.IMPORTANCE_LOW
        }
        val name = when {
            isSuspended -> "Fluxora Suspended Service"
            isHighPriority -> "Fluxora High Priority Service"
            else -> "Fluxora Service"
        }
        val newChannel = NotificationChannel(channelId, name, importance).apply {
            setShowBadge(false)
            if (isSuspended || isHighPriority) {
                setSound(null, null)
                enableVibration(false)
            }
        }
        manager.createNotificationChannel(newChannel)
    }
}

@SuppressLint("ForegroundServiceType")
fun Service.startForeground(notification: Notification, useSpecialType: Boolean = true) {
    ensureNotificationChannel(GlobalState.isSmartStopped, GlobalState.isNotificationHighPriority)

    val type = if (Build.VERSION.SDK_INT >= 34 && useSpecialType && !GlobalState.isSmartStopped) {
        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
    } else {
        0
    }

    runCatching {
        if (type != 0) {
            startForeground(GlobalState.NOTIFICATION_ID, notification, type)
        } else {
            startForeground(GlobalState.NOTIFICATION_ID, notification)
        }
    }.onFailure {
        android.util.Log.e("BaseServiceInterface", "startForeground failed: ${it.message}")
        runCatching {
            startForeground(GlobalState.NOTIFICATION_ID, notification)
        }.onFailure { fallbackErr ->
            android.util.Log.e("BaseServiceInterface", "startForeground fallback failed: ${fallbackErr.message}")
        }
    }
}

/// Registers the notification action receiver at runtime.
///
/// A manifest-declared receiver would be simpler, but implicit broadcasts no
/// longer reach manifest receivers since Android 8, and `setPackage` does not
/// exempt them — the taps then arrive nowhere and the buttons look dead. This
/// is why ownbox registers its receiver from the service as well.
fun Service.registerNotificationActionReceiver(): BroadcastReceiver {
    val receiver = NotificationActionReceiver()
    val filter = IntentFilter().apply {
        addAction(FluxoraService.ACTION_STOP)
        addAction(FluxoraService.ACTION_RESET)
        addAction(FluxoraService.ACTION_SPEED_TEST)
    }
    if (Build.VERSION.SDK_INT >= 33) {
        registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
        registerReceiver(receiver, filter)
    }
    return receiver
}
