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
  static Color colorOf(BuildContext context, FluxoraStatusKind status) {
    final fluxora = FluxoraColorSet.of(Theme.of(context).brightness);
    return switch (status) {
      FluxoraStatusKind.connected => fluxora.success,
      FluxoraStatusKind.connecting => fluxora.info,
      FluxoraStatusKind.disconnected => fluxora.outline,
      FluxoraStatusKind.error => fluxora.error,
      FluxoraStatusKind.warning => fluxora.warning,
      FluxoraStatusKind.unknown => fluxora.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(context, status);
    final text = label;
    final showText = showLabel && text != null && text.isNotEmpty;

    final indicator = Container(
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
          // No `Flexible` here on purpose: this row has no flexible siblings,
          // so a non-flex child receives the incoming max width — the ellipsis
          // still works in a bounded parent, and an unbounded parent cannot
          // trigger RenderFlex's "non-zero flex but unbounded constraints"
          // assertion.
          EmojiText(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FluxoraTypography.label.copyWith(color: color),
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
