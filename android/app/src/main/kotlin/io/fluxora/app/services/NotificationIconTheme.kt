package io.fluxora.app.services

/**
 * 通知栏大图标该用深色还是浅色版本。
 *
 * 这个值由 Flutter 侧在主题变化时写入。它和桌面启动图标的「深色图标」开关
 * 是两件事：启动图标在桌面上，通知图标在通知栏里，后者应当跟随当前界面主题，
 * 而不是跟随一个用户手动设置、且与主题无关的开关。
 */
object NotificationIconTheme {
    @Volatile
    var isDark: Boolean = false
}
