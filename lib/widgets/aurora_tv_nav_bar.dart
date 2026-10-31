import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/common.dart';
import 'aurora_navigation_rail.dart';

/// Aurora's TV navigation bar — the 10-foot variant of the dock.
///
/// ## Why this is a separate widget
///
/// The TV bar used to be a private method of `_HomePageState`, reachable only
/// when `globalState.isAndroidTV` is true. That flag is set inside
/// `GlobalState.init()` behind `if (system.isAndroid)`, so on a Windows test
/// host it can never become true — the bar was untestable, and the only way to
/// reach it would have been a production debug setter. Extracting it keeps the
/// production behaviour identical while making the component testable on its
/// own terms: the caller owns the [FocusNode]s and the selection, the widget
/// owns the visuals and the left/right traversal.
///
/// ## Visual language
///
/// Same three signals as the rail and the dock, sized for a couch:
///
/// | state             | treatment                                            |
/// | ----------------- | ---------------------------------------------------- |
/// | selected          | brand wash + 16×3 accent tick + brand icon + `w600`   |
/// | focused           | **3 px** `primary` ring (2 px is invisible at 3 m)    |
/// | focused + selected| both — the ring wraps the wash, they do not merge     |
/// | idle              | transparent, muted icon and label                     |
///
/// The ring is a *reserved* 3 px border: transparent when idle, so gaining
/// focus never shifts the item. That matters here more than anywhere else —
/// a remote moves focus constantly, and a layout jump would make the whole row
/// twitch.
class AuroraTvNavBar extends StatelessWidget {
  const AuroraTvNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.focusNodes,
    required this.onSelect,
  });

  /// 3 px, not 2: at three metres the 2 px ring the bar used to draw read as a
  /// hairline, and focus is the *only* pointer a remote has.
  static const double focusRingWidth = 3;

  /// Kept from the original implementation so the row keeps its footprint on
  /// a 1920-wide TV.
  static const double itemMinWidth = 120;

  final List<AuroraRailDestination> destinations;
  final int selectedIndex;

  /// One node per destination, owned by the caller — the shell also uses them
  /// to move focus when the page changes.
  final List<FocusNode> focusNodes;

  final ValueChanged<int> onSelect;

  int get _focusedIndex => focusNodes.indexWhere((node) => node.hasFocus);

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final focused = _focusedIndex;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      // The bar is the last stop; leaving downward has nowhere to go.
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (focused > 0) {
        focusNodes[focused - 1].requestFocus();
      }
      // `handled` even at the left edge: an unhandled arrow would bubble to the
      // page and move focus somewhere the user did not ask for.
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (focused >= 0 && focused < focusNodes.length - 1) {
        focusNodes[focused + 1].requestFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        // A floating navigation surface above content — the `menu` rung, same
        // as the mobile dock.
        boxShadow: FluxoraElevation.of(scheme.brightness).menu,
      ),
      child: SafeArea(
        child: Focus(
          onKeyEvent: _handleKey,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: destinations.asMap().entries.map((entry) {
              final index = entry.key;
              return FocusTraversalOrder(
                order: NumericFocusOrder(index.toDouble()),
                child: AnimatedBuilder(
                  animation: focusNodes[index],
                  builder: (context, _) => _AuroraTvItem(
                    destination: entry.value,
                    selected: index == selectedIndex,
                    focused: focusNodes[index].hasFocus,
                    focusNode: focusNodes[index],
                    onTap: () => onSelect(index),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _AuroraTvItem extends StatelessWidget {
  const _AuroraTvItem({
    required this.destination,
    required this.selected,
    required this.focused,
    required this.focusNode,
    required this.onTap,
  });

  final AuroraRailDestination destination;
  final bool selected;
  final bool focused;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = FluxoraColorSet.selectionTint(
      scheme.primary,
      scheme.brightness,
    );
    // A focused-but-not-current item needs *some* fill, otherwise on a large
    // panel the ring alone is easy to lose against the tinted current item.
    final focusWash = scheme.primary.withValues(alpha: 0.10);

    final iconColor = selected ? scheme.primary : scheme.onSurfaceVariant;
    // Same split as the rail and dock: brand on the graphic, `onSurface` on the
    // text so it clears 4.5:1 against the tinted pill.
    final labelColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        focusNode: focusNode,
        borderRadius: BorderRadius.circular(FluxoraRadius.md),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: AuroraTvNavBar.itemMinWidth,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: FluxoraSpacing.xxl + FluxoraSpacing.xs,
            vertical: FluxoraSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? tint : (focused ? focusWash : Colors.transparent),
            borderRadius: BorderRadius.circular(FluxoraRadius.md),
            // Always 3 px: transparent when idle, so focus never moves the row.
            border: Border.all(
              color: focused ? scheme.primary : Colors.transparent,
              width: AuroraTvNavBar.focusRingWidth,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Accent lane, same gesture as the dock: a short tick above the
              // icon, on the current page only.
              SizedBox(
                height: 3,
                child: selected
                    ? Center(
                        child: Container(
                          key: const ValueKey('aurora-tv-accent'),
                          width: 16,
                          height: 3,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: FluxoraSpacing.xs),
              IconTheme.merge(
                data: IconThemeData(color: iconColor, size: 24),
                child: destination.icon,
              ),
              const SizedBox(height: FluxoraSpacing.xs),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (Theme.of(context).textTheme.labelLarge ??
                            const TextStyle())
                        .copyWith(
                  fontSize: FluxoraFontSize.compact,
                  height: 1.15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: labelColor,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
