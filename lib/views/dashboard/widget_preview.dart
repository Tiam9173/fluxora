import 'package:flutter/material.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';

/// Static thumbnails never mount live controls or start background work.
class DashboardWidgetPreview extends StatelessWidget {
  const DashboardWidgetPreview({super.key, required this.type});
  final DashboardWidget type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final content = switch (type) {
      DashboardWidget.startButton => Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chinese ? '连接' : 'Connection',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  chinese ? '节点 · 示例' : 'Example node',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: const Icon(Icons.power_settings_new_rounded),
          ),
        ],
      ),
      DashboardWidget.networkSpeed ||
      DashboardWidget.networkSpeedSmall => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '↓ 12.8 MB/s     ↑ 1.2 MB/s',
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: CustomPaint(painter: _PreviewTrend(scheme.primary))),
        ],
      ),
      DashboardWidget.outboundMode || DashboardWidget.outboundModeV2 => Row(
        children: [
          for (final (index, label)
              in (chinese ? ['规则', '全局', '直连'] : ['Rule', 'Global', 'Direct'])
                  .indexed)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: index == 0
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHigh,
                  borderRadius: FluxoraRadius.fullAll,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      DashboardWidget.tunButton ||
      DashboardWidget.vpnButton ||
      DashboardWidget.systemProxyButton ||
      DashboardWidget.ipv6Switch ||
      DashboardWidget.wakelockSwitch ||
      DashboardWidget.dnsOverride ||
      DashboardWidget.snifferOverride ||
      DashboardWidget.ntpOverride => Row(
        children: [
          Icon(type.icon, size: 30, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              type.title,
              maxLines: 2,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 24,
            padding: const EdgeInsets.all(3),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: FluxoraRadius.fullAll,
            ),
            child: CircleAvatar(radius: 9, backgroundColor: scheme.onPrimary),
          ),
        ],
      ),
      DashboardWidget.networkDetection ||
      DashboardWidget.mediaUnlock ||
      DashboardWidget.mediaUnlockSmall ||
      DashboardWidget.fcmStatus => Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final label
              in type == DashboardWidget.networkDetection
                  ? ['IPv4', 'IPv6']
                  : [type.title, chinese ? '检测结果' : 'Results'])
            Row(
              children: [
                Icon(type.icon, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(label, maxLines: 1)),
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
              ],
            ),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(type.icon, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                switch (type) {
                  DashboardWidget.trafficUsage => '128.6 GB',
                  DashboardWidget.intranetIp => '192.168.1.8',
                  DashboardWidget.memoryInfo => '128 MB',
                  DashboardWidget.connectionsCount => '24',
                  DashboardWidget.providersInfo =>
                    chinese ? '订阅示例' : 'Example subscription',
                  _ => type.title,
                },
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: FluxoraRadius.fullAll,
            child: LinearProgressIndicator(
              value: .62,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    };
    return IgnorePointer(
      child: ExcludeSemantics(
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: FluxoraRadius.lgAll,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer.withValues(alpha: .65),
                  scheme.surfaceContainerLow,
                ],
              ),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .5),
              ),
            ),
            child: Padding(padding: const EdgeInsets.all(14), child: content),
          ),
        ),
      ),
    );
  }
}

class _PreviewTrend extends CustomPainter {
  const _PreviewTrend(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * .8)
      ..cubicTo(
        size.width * .2,
        size.height,
        size.width * .2,
        0,
        size.width * .4,
        size.height * .35,
      )
      ..cubicTo(
        size.width * .6,
        size.height,
        size.width * .7,
        0,
        size.width,
        size.height * .15,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PreviewTrend oldDelegate) => color != oldDelegate.color;
}
