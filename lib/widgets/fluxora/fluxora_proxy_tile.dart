import 'package:fluxora/common/common.dart';
import 'package:fluxora/widgets/fluxora/fluxora_card.dart';
import 'package:fluxora/widgets/fluxora/fluxora_latency_badge.dart';
import 'package:fluxora/widgets/fluxora/fluxora_status.dart';
import 'package:fluxora/widgets/text.dart';
import 'package:flutter/material.dart';

/// A node card with a stable name block and a shared metadata baseline.
/// Selection and lock marks belong to the name; latency keeps the full width
/// below it. Node selection does not imply that the VPN is connected.
class FluxoraProxyTile extends StatelessWidget {
  const FluxoraProxyTile({
    super.key,
    required this.name,
    this.protocol,
    this.status = FluxoraStatusKind.unknown,
    this.delay,
    this.traffic,
    this.description,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.leading,
    this.trailing,
    this.nameTrailing,
    this.latencySlot,
    this.showStatus = true,
    this.showLatency = true,
    this.compact = false,
    this.height,
    this.padding,
    this.nameMaxLines = 1,
  });

  /// Node name. Emoji are rendered through `EmojiText`.
  final String name;

  /// Protocol / type, e.g. `Trojan`.
  final String? protocol;

  final FluxoraStatusKind status;

  /// `null` = untested, `0` = testing, `< 0` = timeout, `> 0` = ms.
  final int? delay;

  /// Optional metadata line, e.g. `↑ 1.2 MB/s`.
  final String? traffic;

  /// Optional secondary line rendered between the name and the status row
  /// (e.g. the chain-proxy hop, or the selected child of a nested group).
  ///
  /// Takes a widget so a host can supply its own exactly-sized content.
  final Widget? description;

  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Optional avatar / flag / icon slot before the text column.
  final Widget? leading;

  /// Optional trailing slot (e.g. a selection tick).
  final Widget? trailing;
  final Widget? nameTrailing;

  /// Replaces the built-in [FluxoraLatencyBadge].
  ///
  /// Lets a host keep its own latency affordance (e.g. the proxy list's
  /// testing spinner and its tap-to-test bolt button) while still using this
  /// tile's layout.
  final Widget? latencySlot;

  final bool showStatus;
  final bool showLatency;

  /// Tightens padding for dense lists.
  final bool compact;

  /// Pins the tile to an exact height.
  ///
  /// Required by hosts that lay out with fixed extents (the proxy list uses
  /// `itemExtentBuilder`). The content is centred inside the given height.
  final double? height;

  /// Overrides the inner padding.
  final EdgeInsetsGeometry? padding;

  /// How many lines the node name may occupy before ellipsising.
  ///
  /// The proxy list's wider card types used to allow two lines, so this keeps
  /// long node names fully readable.
  final int nameMaxLines;

  /// Height reserved for the name block, in device-independent pixels.
  ///
  /// `nameMaxLines` lines of [style], scaled the way the platform will scale
  /// it, so the reservation is correct at 1.0× and at 2.0× alike.
  double _nameAreaHeight(BuildContext context, TextStyle style) {
    final scaler = MediaQuery.textScalerOf(context);
    final fontSize = scaler.scale(style.fontSize ?? 14);
    return fontSize * (style.height ?? 1.2) * nameMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final nameStyle = FluxoraTypography.body.copyWith(
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    );
    final metadata = [
      if (showStatus && protocol?.isNotEmpty == true) protocol!,
      ?traffic,
    ].join(' · ');
    final marks = <Widget>[
      ?nameTrailing,
      ?trailing,
      if (selected && nameTrailing == null && trailing == null)
        Icon(Icons.check_circle_rounded, size: 15, color: scheme.primary),
    ];
    final card = FluxoraCard(
      radius: FluxoraRadius.lg,
      filled: FluxoraMaterial.of(context).enabled,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: name,
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: FluxoraSpacing.md,
            vertical: compact ? 6 : FluxoraSpacing.md,
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Expanded(
                child: SizedBox(
                  height: _nameAreaHeight(context, nameStyle),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: Tooltip(
                      message: name,
                      triggerMode: TooltipTriggerMode.manual,
                      child: EmojiText(
                        name,
                        maxLines: nameMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: nameStyle,
                      ),
                    ),
                  ),
                ),
              ),
              if (marks.isNotEmpty) ...[const SizedBox(width: 6), ...marks],
            ],
          ),
          if (description != null) ...[const SizedBox(height: 2), description!],
          if (metadata.isNotEmpty || showLatency) ...[
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: metadata.isEmpty
                        ? const SizedBox.shrink()
                        : Row(
                            children: [
                              FluxoraStatus(
                                status: status,
                                showLabel: false,
                                dotSize: 6,
                                semanticLabel: switch (status) {
                                  FluxoraStatusKind.connected =>
                                    chinese ? '延迟测试已响应' : 'Probe responded',
                                  FluxoraStatusKind.connecting =>
                                    chinese ? '正在测试延迟' : 'Testing latency',
                                  FluxoraStatusKind.error =>
                                    chinese ? '延迟测试失败' : 'Latency test failed',
                                  FluxoraStatusKind.warning =>
                                    chinese ? '延迟较高' : 'High latency',
                                  _ =>
                                    chinese ? '尚未测试延迟' : 'Latency not tested',
                                },
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Tooltip(
                                  message: metadata,
                                  child: EmojiText(
                                    metadata,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: FluxoraTypography.caption.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (showLatency) ...[
                    if (metadata.isNotEmpty) const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                            constraints.maxWidth * (metadata.isEmpty ? 1 : .64),
                      ),
                      child:
                          latencySlot ??
                          FluxoraLatencyBadge(
                            delay: delay,
                            dense: true,
                            tintBackground: false,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
    final content = height == null
        ? card
        : SizedBox(height: height, child: card);
    return Semantics(selected: selected, child: content);
  }
}
