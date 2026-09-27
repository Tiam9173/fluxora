import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/widgets/card.dart';
import 'package:flutter/material.dart';

/// Fluxora's surface / card primitive.
///
/// A **thin wrapper over [CommonCard]**, not a re-implementation: the border,
/// hover and selection colour logic already lives there and is already driven by
/// `ColorScheme`. This widget only adds what a design-system card needs —
/// Fluxora radius, Fluxora padding, a margin, a semantic label and a restrained
/// "highlighted" ring.
///
/// Colours come entirely from `ColorScheme` (re-skinned by `genColorScheme`),
/// so light / dark / `pureBlack` / Material You all keep working. No colour is
/// hardcoded and there is no glow or neon.
///
/// ```dart
/// FluxoraCard(child: Text('Hello'));
/// FluxoraCard(onTap: open, selected: true, child: content);
/// ```
class FluxoraCard extends StatelessWidget {
  const FluxoraCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.highlighted = false,
    this.filled = false,
    this.info,
    this.semanticLabel,
    this.enterAnimated = false,
  });

  /// Card content.
  final Widget child;

  /// Inner padding.
  ///
  /// Defaults to [FluxoraSpacing.cardInsets] for a plain card, and to
  /// [EdgeInsets.zero] when [info] is set — the header brings its own
  /// `baseInfoEdgeInsets` and dashboard cards already pad their body, so adding
  /// the default inset on top would double-pad.
  final EdgeInsetsGeometry? padding;

  /// Outer margin, applied outside the card surface.
  final EdgeInsetsGeometry? margin;

  /// Makes the card tappable. When null (and [onLongPress] is null) the card
  /// collapses its tap target and behaves as a plain surface.
  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  /// Persistent selection: container tint plus a primary border.
  final bool selected;

  /// Transient emphasis — a subtle 1px primary ring outside the surface.
  ///
  /// Deliberately restrained (no glow, no shadow boost) per the Fluxora
  /// "克制" principle. Independent of [selected].
  final bool highlighted;

  /// Uses the `surfaceContainer` fill instead of `surfaceContainerLow`.
  final bool filled;

  /// Optional header (icon + label + trailing actions), rendered by
  /// [CommonCard]'s `InfoHeader`.
  ///
  /// Added in D4.6 so existing dashboard cards can adopt the Fluxora radius and
  /// elevation while keeping their headers, without being rewritten.
  final Info? info;

  /// Accessibility label announced for the whole card.
  final String? semanticLabel;

  /// Reuses [CommonCard]'s fade+scale entrance.
  final bool enterAnimated;

  @override
  Widget build(BuildContext context) {
    // `CommonCard.padding` is declared but never applied inside its `build`,
    // so the inset is applied here rather than passed through.
    Widget card = CommonCard(
      radius: FluxoraRadius.card,
      type: filled ? CommonCardType.filled : CommonCardType.plain,
      isSelected: selected,
      onPressed: onTap,
      onLongPress: onLongPress,
      enterAnimated: enterAnimated,
      info: info,
      child: Padding(
        padding: padding ?? (info != null ? EdgeInsets.zero : FluxoraSpacing.cardInsets),
        child: child,
      ),
    );

    if (highlighted) {
      card = Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FluxoraRadius.card + 1),
          border: Border.all(
            color: context.colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
        child: card,
      );
    }

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    if (semanticLabel != null) {
      card = Semantics(label: semanticLabel, container: true, child: card);
    }

    return card;
  }
}
