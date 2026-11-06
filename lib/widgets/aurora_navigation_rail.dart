import 'package:flutter/material.dart';

import '../common/common.dart';

/// One entry in an Aurora navigation surface.
///
/// Shared by [AuroraNavigationRail] and `AuroraTvNavBar` — both need exactly an
/// icon and a label, and one type keeps the three navigation surfaces (rail,
/// dock, TV) speaking the same vocabulary instead of drifting apart.
///
/// Deliberately smaller than `NavigationRailDestination`: keeping the type local
/// means the visual components can evolve without dragging Material's
/// destination semantics along.
@immutable
class AuroraRailDestination {
  const AuroraRailDestination({required this.icon, required this.label});

  /// A bare `Icon` (or anything that reads `IconTheme`), so the rail can drive
  /// size and colour from the item's state.
  final Widget icon;

  /// Already-localised text.
  final String label;
}

/// Aurora's desktop navigation rail.
///
/// ## Why not `NavigationRail`
///
/// Material's rail hard-codes the item metrics — 56×32 indicator, fixed vertical
/// padding, `InkWell` hover/focus colours taken from the global theme — so the
/// only things a design system can change are the indicator colour and the label
/// text style. That is not enough to give the rail an identity, and it is why
/// Phase 02 replaces it instead of theming it.
///
/// What this widget adds over the stock rail:
///
/// * **Item rhythm**: a compact 44 px item with a 4 px gap, so destinations
///   read as one column instead of eight loosely spaced blocks.
/// * **Selection**: a low-saturation brand wash ([FluxoraColorSet.selectionTint])
///   plus a 3 px accent bar at the rail's own edge — the bar sits *outside* the
///   pill, which is what makes the selection legible at a glance from the
///   content area.
/// * **Three distinguishable states**: selected (wash + bar + brand icon),
///   hovered (6 % `onSurface` wash, no bar), focused (2 px `primary` ring).
///   Material's rail renders hover and focus as the same faint overlay.
/// * **Label hierarchy**: text beside icons when expanded, tooltips when folded;
///   13 px, `w600` when selected and `w500` otherwise, on
///   top of `onSurface` / `onSurfaceVariant`.
///
/// Colours are intentionally split: the **icon** and the **accent bar** carry
/// the violet brand token (a graphic), while the **label**
/// uses `onSurface` so it keeps ≥ 4.5:1 against the tinted pill in both themes.
class AuroraNavigationRail extends StatelessWidget {
  const AuroraNavigationRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.extended = true,
  });

  /// Icon-only width; the shell animates between these two widths.
  static const double collapsedWidth = 68;

  /// Width when labels sit beside the icons.
  static const double extendedWidth = 208;

  /// Minimum target height; expanded text can grow with accessibility scaling.
  static const double itemHeight = 44;

  /// Item height in [extended] mode, where the label is on the same row.
  static const double extendedItemHeight = 44;

  final List<AuroraRailDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: extended ? extendedWidth : collapsedWidth,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < destinations.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: FluxoraSpacing.xs),
                child: Semantics(
                  key: ValueKey('aurora-rail-destination-$index'),
                  label: destinations[index].label,
                  button: true,
                  selected: index == selectedIndex,
                  child: _AuroraRailItem(
                    destination: destinations[index],
                    selected: index == selectedIndex,
                    // During width animation keep text out of the narrow frame.
                    extended: extended && constraints.maxWidth >= 120,
                    onTap: () => onDestinationSelected(index),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuroraRailItem extends StatefulWidget {
  const _AuroraRailItem({
    required this.destination,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final AuroraRailDestination destination;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  State<_AuroraRailItem> createState() => _AuroraRailItemState();
}

class _AuroraRailItemState extends State<_AuroraRailItem> {
  /// Kept separate from `InkWell`'s own hover handling because the wash has to
  /// sit *under* the pill, not on top of it.
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = scheme.brightness;
    final selected = widget.selected;
    final accent = brightness == Brightness.dark
        ? FluxoraColors.dark.tertiary
        : FluxoraColors.light.tertiary;

    final tint = FluxoraColorSet.selectionTint(accent, brightness);
    final hoverWash = scheme.onSurface.withValues(
      alpha: brightness == Brightness.dark ? 0.06 : 0.05,
    );
    final iconColor = selected ? accent : scheme.onSurfaceVariant;
    // Text stays neutral; the icon and edge carry the violet brand colour.
    final labelColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular(FluxoraRadius.md);

    final background = selected
        ? tint
        : (_hovered ? hoverWash : Colors.transparent);

    final icon = ExcludeSemantics(
      child: IconTheme.merge(
        data: IconThemeData(size: 22, color: iconColor),
        child: widget.destination.icon,
      ),
    );

    final labelStyle =
        (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
          fontSize: FluxoraFontSize.compact,
          height: 1.15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: labelColor,
          letterSpacing: 0,
        );

    final label = ExcludeSemantics(
      child: Text(
        widget.destination.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: widget.extended ? TextAlign.start : TextAlign.center,
        style: labelStyle,
      ),
    );

    final content = widget.extended
        ? Row(
            children: [
              icon,
              const SizedBox(width: FluxoraSpacing.md),
              Expanded(child: label),
            ],
          )
        : icon;

    return Tooltip(
      message: widget.destination.label,
      excludeFromSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: widget.extended
              ? AuroraNavigationRail.extendedItemHeight
              : AuroraNavigationRail.itemHeight,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Accent lane. Always 6 px wide so the pill's left edge does not move
            // when the selection changes; only the bar itself appears or not.
            SizedBox(
              width: 3,
              child: selected
                  ? Container(
                      key: const ValueKey('aurora-rail-accent'),
                      height: 18,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(FluxoraRadius.xs),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Material(
                animationDuration: FluxoraMotion.ofContext(context).base,
                color: background,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: radius,
                  side: _focused
                      ? BorderSide(color: scheme.primary, width: 2)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: widget.onTap,
                  onHover: (value) {
                    if (_hovered != value) setState(() => _hovered = value);
                  },
                  onFocusChange: (value) {
                    if (_focused != value) setState(() => _focused = value);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: FluxoraSpacing.sm,
                      horizontal: widget.extended ? FluxoraSpacing.md : 0,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight:
                            AuroraNavigationRail.itemHeight -
                            2 * FluxoraSpacing.sm,
                      ),
                      child: Center(child: content),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
