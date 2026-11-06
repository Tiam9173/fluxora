import 'package:fluxora/common/common.dart';
import 'package:fluxora/widgets/text.dart';
import 'package:flutter/material.dart';

/// Fluxora connection / health states.
///
/// Maps onto the semantic colours in [FluxoraColorSet] — never onto
/// `Colors.green` / `Colors.red` / `Colors.orange`, which are scattered across
/// the existing proxy views.
enum FluxoraStatusKind {
  connected,
  connecting,
  disconnected,
  error,
  warning,
  unknown,
}

/// A small semantic status indicator: a coloured dot plus an optional label.
///
/// Colour is resolved from [FluxoraColorSet] for the current [Brightness], so
/// it is identical in light / dark / `pureBlack` and never hardcoded. The label
/// uses the same semantic tone (already contrast-safe: tone 40 in light,
/// tone 80 in dark) at [FluxoraTypography.label].
///
/// ```dart
/// FluxoraStatus(status: FluxoraStatusKind.connected, label: 'Connected');
/// FluxoraStatus(status: FluxoraStatusKind.error, showLabel: false);
/// ```
class FluxoraStatus extends StatelessWidget {
  const FluxoraStatus({
    super.key,
    required this.status,
    this.label,
    this.showLabel = true,
    this.dotSize = 8,
    this.semanticLabel,
  });

  final FluxoraStatusKind status;

  /// Text shown next to the dot. Omitted when null.
  final String? label;

  /// Set false for a bare indicator dot.
  final bool showLabel;

  final double dotSize;

  /// Overrides the announced label. Defaults to [label].
  final String? semanticLabel;

  /// The semantic colour for [status] at the current brightness.
  ///
  /// The two neutral kinds (`disconnected`, `unknown`) use
  /// `colorScheme.onSurfaceVariant`, **not** `FluxoraColorSet.outline`. That
  /// token is filed under "Lines" in `fluxora_colors.dart` — it is a *border*
  /// colour, and using it for text made the label effectively invisible:
  ///
  /// | surface | `outline` | `onSurfaceVariant` |
  /// | --- | --- | --- |
  /// | `surfaceContainerLow` | 1.68 / 1.48 | 10.23 / 9.31 |
  /// | `surfaceContainer` | 1.53 / 1.33 | 9.30 / 8.35 |
  /// | `secondaryContainer` (selected card) | 1.10 / 1.15 | 5.53 / 7.19 |
  ///
  /// (dark / light, WCAG contrast). 1.1–1.7:1 fails even the 3:1 *graphic*
  /// threshold, let alone the 4.5:1 text one — and this widget paints both the
  /// dot and the label with it. Real impact: every unselected node row in the
  /// proxy list shows its protocol name this way (`proxies/card.dart:329-333`),
  /// and so does the dashboard hero's "not connected" label
  /// (`dashboard/widgets/start_button.dart:433`).
  static Color colorOf(BuildContext context, FluxoraStatusKind status) {
    final scheme = Theme.of(context).colorScheme;
    final fluxora = FluxoraColorSet.of(scheme.brightness);
    return switch (status) {
      FluxoraStatusKind.connected => fluxora.success,
      FluxoraStatusKind.connecting => fluxora.info,
      FluxoraStatusKind.disconnected => scheme.onSurfaceVariant,
      FluxoraStatusKind.error => fluxora.error,
      FluxoraStatusKind.warning => fluxora.warning,
      FluxoraStatusKind.unknown => scheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(context, status);
    final text = label;
    final showText = showLabel && text != null && text.isNotEmpty;

    final indicator = AnimatedContainer(
      duration: FluxoraMotion.ofContext(context).fast,
      curve: FluxoraMotion.standard,
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        if (showText) ...[
          const SizedBox(width: FluxoraSpacing.sm),
          // `Flexible` so a long label ellipsises instead of overflowing the
          // row. Without it a bounded parent only *passed* the constraint down:
          // the label kept its intrinsic width and the Row overflowed to the
          // right — measured in the proxy list at 320 px / 2.0× text with the
          // protocol `VLESS-Reality-Vision` (340 px over).
          //
          // Requires a **bounded** width from the parent, which both call sites
          // provide (`Expanded > Column` in the dashboard hero, `Flexible` in
          // `FluxoraProxyTile`). An unbounded parent would trip RenderFlex's
          // "non-zero flex but unbounded constraints" assertion.
          Flexible(
            child: EmojiText(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FluxoraTypography.label.copyWith(color: color),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      label: semanticLabel ?? (showText ? text : status.name),
      child: content,
    );
  }
}
