import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';

/// Static thumbnails show the selected shape without starting live widgets.
class DashboardWidgetPreview extends StatelessWidget {
  const DashboardWidgetPreview({
    super.key,
    required this.type,
    this.layout = DashboardWidgetLayout.original,
  });

  final DashboardWidget type;
  final DashboardWidgetLayout layout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final selected = layout == DashboardWidgetLayout.original
        ? DashboardWidgetLayout.defaultPreviewFor(type)
        : layout;
    final aspectRatio = selected.widthUnits * .8 / selected.heightRows;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          constraints.maxWidth,
          constraints.maxHeight * aspectRatio,
        );
        final height = width / aspectRatio;
        return Center(
          child: SizedBox(
            key: ValueKey(
              'dashboard-widget-preview-${type.name}-${selected.name}',
            ),
            width: width,
            height: height,
            child: IgnorePointer(
              child: ExcludeSemantics(
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
                  child: Padding(
                    padding: EdgeInsets.all(math.min(12, width * .08)),
                    child: LayoutBuilder(
                      builder: (context, inner) => _previewContent(
                        type,
                        Size(inner.maxWidth, inner.maxHeight),
                        scheme,
                        chinese,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _previewContent(
  DashboardWidget type,
  Size size,
  ColorScheme scheme,
  bool chinese,
) {
  final narrow = size.width < 94;
  final isSpeed =
      type == DashboardWidget.networkSpeed ||
      type == DashboardWidget.networkSpeedSmall;
  final isSwitch = {
    DashboardWidget.tunButton,
    DashboardWidget.vpnButton,
    DashboardWidget.systemProxyButton,
    DashboardWidget.ipv6Switch,
    DashboardWidget.wakelockSwitch,
    DashboardWidget.dnsOverride,
    DashboardWidget.snifferOverride,
    DashboardWidget.ntpOverride,
  }.contains(type);
  final isStatus = {
    DashboardWidget.networkDetection,
    DashboardWidget.mediaUnlock,
    DashboardWidget.mediaUnlockSmall,
    DashboardWidget.fcmStatus,
  }.contains(type);

  if (isSpeed) {
    final chart = CustomPaint(
      painter: _PreviewTrend(scheme.primary),
      child: const SizedBox.expand(),
    );
    if (narrow) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.speed_rounded, size: 15, color: scheme.primary),
          const SizedBox(height: 5),
          Icon(Icons.arrow_downward_rounded, size: 10, color: scheme.primary),
          _previewValue('12.8', scheme, size: 10, align: TextAlign.center),
          const SizedBox(height: 4),
          Expanded(child: chart),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.arrow_downward_rounded, size: 13, color: scheme.primary),
            const SizedBox(width: 3),
            Expanded(
              child: _previewValue(
                '12.8 MB/s',
                scheme,
                size: size.width < 150 ? 10 : 13,
              ),
            ),
            if (size.width >= 180) ...[
              Icon(
                Icons.arrow_upward_rounded,
                size: 12,
                color: scheme.secondary,
              ),
              const SizedBox(width: 2),
              _previewLabel('1.2', scheme, color: scheme.secondary),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Expanded(child: chart),
      ],
    );
  }

  if (type == DashboardWidget.startButton) {
    if (narrow) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.power_settings_new_rounded,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(height: 5),
          _previewLabel(chinese ? '已连接' : 'Connected', scheme),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _previewLabel(chinese ? '代理服务' : 'Proxy service', scheme),
              const SizedBox(height: 4),
              _previewValue(chinese ? '已连接' : 'Connected', scheme, size: 14),
            ],
          ),
        ),
        CircleAvatar(
          radius: math.min(17, size.height * .28),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: const Icon(Icons.power_settings_new_rounded, size: 18),
        ),
      ],
    );
  }

  if (type == DashboardWidget.outboundMode ||
      type == DashboardWidget.outboundModeV2) {
    final labels = chinese ? ['规则', '全局', '直连'] : ['Rule', 'Global', 'Direct'];
    return Flex(
      direction: narrow ? Axis.vertical : Axis.horizontal,
      children: [
        for (final (index, label) in labels.indexed)
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: narrow ? 0 : 2,
                vertical: narrow ? 2 : 0,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index == 0
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHigh,
                borderRadius: FluxoraRadius.fullAll,
              ),
              child: _previewLabel(
                label,
                scheme,
                color: index == 0 ? scheme.onPrimaryContainer : null,
                align: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  if (isSwitch) {
    final label = switch (type) {
      DashboardWidget.tunButton => 'TUN',
      DashboardWidget.vpnButton => 'VPN',
      DashboardWidget.systemProxyButton => chinese ? '系统代理' : 'Proxy',
      DashboardWidget.ipv6Switch => 'IPv6',
      DashboardWidget.wakelockSwitch => chinese ? '保持唤醒' : 'Wake lock',
      DashboardWidget.dnsOverride => chinese ? 'DNS 覆写' : 'DNS override',
      DashboardWidget.snifferOverride => chinese ? '流量嗅探' : 'Sniffer',
      _ => chinese ? 'NTP 覆写' : 'NTP override',
    };
    final toggle = Container(
      width: narrow ? 27 : 34,
      height: 18,
      padding: const EdgeInsets.all(2),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: FluxoraRadius.fullAll,
      ),
      child: CircleAvatar(radius: 7, backgroundColor: scheme.onPrimary),
    );
    return narrow
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(type.icon, size: 16, color: scheme.primary),
              const SizedBox(height: 6),
              _previewLabel(label, scheme, align: TextAlign.center),
              const SizedBox(height: 6),
              toggle,
            ],
          )
        : Row(
            children: [
              Icon(type.icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(child: _previewLabel(label, scheme)),
              const SizedBox(width: 6),
              toggle,
            ],
          );
  }

  if (isStatus) {
    final labels = type == DashboardWidget.networkDetection
        ? const ['IPv4', 'IPv6']
        : [chinese ? '服务' : 'Service', chinese ? '可用' : 'Available'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final label in labels)
          Row(
            mainAxisSize: narrow ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(type.icon, size: narrow ? 12 : 15, color: scheme.primary),
              if (!narrow) const SizedBox(width: 6),
              if (!narrow) Expanded(child: _previewLabel(label, scheme)),
              Icon(
                Icons.check_circle_rounded,
                size: narrow ? 11 : 14,
                color: scheme.primary,
              ),
            ],
          ),
      ],
    );
  }

  final value = switch (type) {
    DashboardWidget.trafficUsage => '128.6 GB',
    DashboardWidget.intranetIp => narrow ? '192.168' : '192.168.1.8',
    DashboardWidget.memoryInfo => '128 MB',
    DashboardWidget.connectionsCount => '24',
    DashboardWidget.providersInfo => chinese ? '3 个订阅' : '3 sources',
    _ => chinese ? '运行中' : 'Active',
  };
  final label = switch (type) {
    DashboardWidget.trafficUsage => chinese ? '流量' : 'Traffic',
    DashboardWidget.intranetIp => chinese ? '内网 IP' : 'LAN IP',
    DashboardWidget.memoryInfo => chinese ? '内存' : 'Memory',
    DashboardWidget.connectionsCount => chinese ? '连接数' : 'Connections',
    DashboardWidget.providersInfo => chinese ? '订阅' : 'Providers',
    _ => chinese ? '状态' : 'Status',
  };

  if (narrow) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(type.icon, size: 16, color: scheme.primary),
        const SizedBox(height: 6),
        _previewValue(value, scheme, size: 10, align: TextAlign.center),
        const SizedBox(height: 8),
        _previewProgress(scheme),
      ],
    );
  }
  if (size.height < 66 && size.width > 120) {
    return Row(
      children: [
        Icon(type.icon, size: 17, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _previewLabel(label, scheme),
              _previewValue(value, scheme, size: 13),
            ],
          ),
        ),
        SizedBox(width: size.width * .24, child: _previewProgress(scheme)),
      ],
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Icon(type.icon, size: 17, color: scheme.primary),
          const SizedBox(width: 7),
          Expanded(child: _previewLabel(label, scheme)),
        ],
      ),
      _previewValue(value, scheme, size: size.width < 120 ? 12 : 16),
      _previewProgress(scheme),
    ],
  );
}

Widget _previewProgress(ColorScheme scheme) => ClipRRect(
  borderRadius: FluxoraRadius.fullAll,
  child: LinearProgressIndicator(
    value: .62,
    minHeight: 4,
    backgroundColor: scheme.surfaceContainerHighest,
  ),
);

Widget _previewLabel(
  String value,
  ColorScheme scheme, {
  Color? color,
  TextAlign align = TextAlign.start,
}) => Text(
  value,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  textAlign: align,
  style: TextStyle(
    color: color ?? scheme.onSurfaceVariant,
    fontSize: 9,
    fontWeight: FontWeight.w500,
  ),
);

Widget _previewValue(
  String value,
  ColorScheme scheme, {
  double size = 13,
  TextAlign align = TextAlign.start,
}) => Text(
  value,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  textAlign: align,
  style: TextStyle(
    color: scheme.onSurface,
    fontSize: size,
    fontWeight: FontWeight.w600,
    height: 1.15,
  ),
);

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
