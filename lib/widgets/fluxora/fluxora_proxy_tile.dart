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
    final colorScheme = context.colorScheme;
    final hasSecondary =
        showStatus || showLatency || traffic != null || description != null;
    final nameStyle =
        (compact ? FluxoraTypography.body : FluxoraTypography.title).copyWith(
          // A touch heavier than body weight: node names are the primary label
          // and sit next to dense status text, so the hierarchy needs the help.
          fontWeight: FontWeight.w600,
          color: selected ? colorScheme.primary : colorScheme.onSurface,
        );

    final card = FluxoraCard(
      // Dense rows stay opaque and never request per-row backdrop filters.
      filled: FluxoraMaterial.of(context).enabled,
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
          // Selected marker: a short accent tick on the leading edge. Fixed
          // height on purpose — the tile's height is fixed by the list's
          // itemExtent, so the marker must not grow the row.
          if (selected) ...[
            Container(
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: FluxoraSpacing.sm),
          ],
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
                // Fixed name area, `nameMaxLines` lines tall, whether or not
                // the name actually wraps.
                //
                // Letting the name take its natural height made two cards in
                // the same row look different: a long name pushed the status
                // row down, a short one left it high, so the row read as
                // "these cards are not the same size" even though the boxes
                // were identical. Bettbox reserves the same way
                // (`measure.bodyMediumHeight * maxLines`); this is the
                // text-scaler-aware equivalent so it holds at 2.0× too.
                SizedBox(
                  height: _nameAreaHeight(context, nameStyle),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: EmojiText(
                      name,
                      maxLines: nameMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle,
                    ),
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: FluxoraSpacing.xxs),
                  description!,
                ],
                if (hasSecondary) ...[
                  const SizedBox(height: FluxoraSpacing.xs),
                  // One line, always. The proxy list gives this tile a fixed
                  // height (`getItemHeight`), which budgets exactly **one**
                  // secondary line; the old `Wrap` took a second line whenever
                  // status + latency did not fit, and the row overflowed —
                  // measured at 320 px, 2.0× text, protocol
                  // `VLESS-Reality-Vision` (and again at 3.0× / in `min` cards).
                  //
                  // The status label is the part that yields: it is secondary
                  // information, while the latency badge is the reason the user
                  // is looking at the row.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showStatus)
                        Flexible(
                          child: FluxoraStatus(status: status, label: protocol),
                        ),
                      if (showLatency) ...[
                        // `sm`, not `md`: at 3-column width the row has ~1.5 dp
                        // of slack left after both children shrink, and the
                        // wider gap was exactly what tipped it over.
                        if (showStatus)
                          const SizedBox(width: FluxoraSpacing.sm),
                        // The badge used to take its intrinsic width, so on a
                        // narrow card (a three-column phone grid is ~104 dp) the
                        // row overflowed even with no extra decoration — and
                        // adding the lock mark as `trailing` stole another
                        // ~24 dp, pushing the latency clean out of view. That is
                        // the reported "锁定后看不到延迟". Flexible + scale-down
                        // keeps it on screen at any width.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child:
                                latencySlot ??
                                FluxoraLatencyBadge(delay: delay),
                          ),
                        ),
                      ],
                      if (traffic != null) ...[
                        const SizedBox(width: FluxoraSpacing.md),
                        Flexible(
                          child: Text(
                            traffic!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FluxoraTypography.caption.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
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
