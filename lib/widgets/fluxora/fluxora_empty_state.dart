import 'package:fluxora/common/common.dart';
import 'package:fluxora/widgets/text.dart';
import 'package:flutter/material.dart';

/// A unified empty / unavailable / error placeholder.
///
/// Replaces the many ad-hoc "nothing here" blocks with one restrained layout:
/// a tonal icon chip, a title, an optional description and an optional action.
/// There are deliberately **no large illustrations** — the Fluxora principles
/// call for restraint over decoration.
///
/// Colours come from `ColorScheme` (`surfaceContainer` chip, `onSurface` title,
/// `onSurfaceVariant` description), so light / dark / `pureBlack` all work.
///
/// ```dart
/// const FluxoraEmptyState(
///   icon: Icons.wifi_off,
///   title: 'Not connected',
///   description: 'Pick a node to start.',
/// );
/// ```
///
/// Note: this generalises the existing `NullStatus` widget (which only renders a
/// centred label). `NullStatus` is intentionally left untouched in D4.5 so no
/// existing call site changes behaviour; migrating those call sites here is a
/// later stage.
class FluxoraEmptyState extends StatelessWidget {
  const FluxoraEmptyState({
    super.key,
    this.icon,
    this.title,
    this.description,
    this.action,
    this.iconColor,
    this.compact = false,
  });

  final IconData? icon;

  /// Primary message.
  final String? title;

  /// Supporting message.
  final String? description;

  /// Optional call-to-action below the text.
  final Widget? action;

  /// Overrides the icon colour. Defaults to `onSurfaceVariant`.
  ///
  /// Pass a semantic token (e.g. `FluxoraColors.error`) for error states rather
  /// than a hardcoded `Colors.red`.
  final Color? iconColor;

  /// Tightens spacing and icon size for use inside small panels.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final titleText = title;
    final descriptionText = description;

    final iconSize = compact ? 20.0 : 24.0;
    final chipSize = compact ? 36.0 : 48.0;

    return Semantics(
      label: [titleText, descriptionText].whereType<String>().join('. '),
      child: Padding(
        padding: EdgeInsets.all(
          compact ? FluxoraSpacing.md : FluxoraSpacing.pagePadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Container(
                width: chipSize,
                height: chipSize,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: iconColor ?? colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: compact ? FluxoraSpacing.md : FluxoraSpacing.lg),
            ],
            if (titleText != null && titleText.isNotEmpty)
              EmojiText(
                titleText,
                textAlign: TextAlign.center,
                style: (compact
                        ? FluxoraTypography.body
                        : FluxoraTypography.title)
                    .copyWith(color: colorScheme.onSurface),
              ),
            if (descriptionText != null && descriptionText.isNotEmpty) ...[
              const SizedBox(height: FluxoraSpacing.sm),
              Text(
                descriptionText,
                textAlign: TextAlign.center,
                style: FluxoraTypography.body.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: compact ? FluxoraSpacing.md : FluxoraSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
