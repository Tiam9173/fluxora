import 'package:fluxora/common/common.dart';
import 'package:fluxora/widgets/fluxora/fluxora_card.dart';
import 'package:fluxora/widgets/fluxora/fluxora_latency_badge.dart';
import 'package:fluxora/widgets/fluxora/fluxora_status.dart';
import 'package:fluxora/widgets/text.dart';
import 'package:flutter/material.dart';

/// A reusable proxy / node row for the future Proxy page.
///
/// Information hierarchy (`D4.5` spec):
///
/// ```text
/// Node Name
/// ├── Status
/// ├── Protocol / Type
/// ├── Latency
/// └── optional traffic / metadata
/// ```
///
/// Composed from [FluxoraCard] + [FluxoraStatus] + [FluxoraLatencyBadge] so the
/// visual language stays in one place. This is a **presentational** widget: it
/// takes plain values and never reads a provider, so the existing Proxy page is
/// untouched and can migrate incrementally.
///
/// ```dart
/// FluxoraProxyTile(
///   name: '🇭🇰 Hong Kong 01',
///   protocol: 'Trojan',
///   status: FluxoraStatusKind.connected,
///   delay: 42,
///   onTap: () => select(proxy),
/// );
/// ```
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

  /// Protocol / type, e.g. `Trojan`. Doubles as the [FluxoraStatus] label.
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

  /// Replaces the built-in [FluxoraLatencyBadge].
  ///
  /// Lets a host keep its own latency affordance (e.g. the proxy list's
  /// testing spinner and its tap-to-test bolt button) while still using this
  /// tile's layout.
  final Widget? latencySlot;

  final bool showStatus;
  final bool showLatency;

  /// Tightens padding and steps the name down from `title` to `body` for dense
  /// lists.
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final hasSecondary =
        showStatus || showLatency || traffic != null || description != null;

    final nameStyle = (compact ? FluxoraTypography.body : FluxoraTypography.title)
        .copyWith(
          color: selected ? colorScheme.primary : colorScheme.onSurface,
        );

    final card = FluxoraCard(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: name,
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: compact ? FluxoraSpacing.md : FluxoraSpacing.lg,
            vertical: compact ? FluxoraSpacing.sm : FluxoraSpacing.md,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: FluxoraSpacing.md),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmojiText(
                  name,
                  maxLines: nameMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: nameStyle,
                ),
                if (description != null) ...[
                  const SizedBox(height: FluxoraSpacing.xxs),
                  description!,
                ],
                if (hasSecondary) ...[
                  const SizedBox(height: FluxoraSpacing.xs),
                  // Wrap rather than Row so long protocol names or narrow
                  // windows degrade gracefully instead of overflowing.
                  Wrap(
                    spacing: FluxoraSpacing.md,
                    runSpacing: FluxoraSpacing.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (showStatus)
                        FluxoraStatus(status: status, label: protocol),
                      if (showLatency)
                        latencySlot ?? FluxoraLatencyBadge(delay: delay),
                      if (traffic != null)
                        Text(
                          traffic!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FluxoraTypography.caption.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: FluxoraSpacing.md),
            trailing!,
          ],
        ],
      ),
    );

    if (height == null) return card;
    return SizedBox(height: height, child: card);
  }
}
