import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../common/common.dart';
import '../models/common.dart';
import '../providers/config.dart';

/// Aurora's floating mobile dock.
///
/// ## Why this replaced `google_nav_bar`
///
/// `GNav` renders one `tabBackgroundColor` pill, one `hoverColor` for every
/// item, and expands the selected tab to reveal its label. There is no seam for
/// a brand accent, no separate focus treatment, and no way to keep the label
/// visible without the pill resizing on selection — so the only things a design
/// system could tune were two colours. Phase 02 replaces it with a bar that
/// speaks the same language as [AuroraNavigationRail]:
///
/// | state    | treatment                                                    |
/// | -------- | ------------------------------------------------------------ |
/// | selected | low-saturation brand wash + a 16×3 accent tick on top of the   |
/// |          | pill + brand icon + full-strength label                        |
/// | hovered  | 6 % `onSurface` wash (dark) / 5 % (light), never the tick      |
/// | focused  | 2 px `primary` ring around the pill                            |
///
/// The rail puts its accent on the **left edge**; the dock rotates the same
/// gesture to the **top edge**, which is the only side with room in a 44 px
/// item. Everything else — the tint, the radius family, the type scale, the
/// "brand on the graphic, contrast on the text" split — is shared.
///
/// Unlike the old bar, **every** item keeps its label. `GNav` only expanded the
/// selected one, which made the bar change height as you navigated and hid the
/// destination names behind an interaction.
class AuroraBottomNavBar extends ConsumerWidget {
  const AuroraBottomNavBar({
    super.key,
    required this.navigationItems,
    required this.selectedIndex,
    required this.onTabChange,
  });

  /// Item height. 3 px accent lane + 20 icon + 2 gap + 15 label.
  static const double itemHeight = 44;

  final List<NavigationItem> navigationItems;
  final int selectedIndex;
  final ValueChanged<int> onTabChange;

  IconData _iconOf(Widget iconWidget) {
    if (iconWidget is Icon) return iconWidget.icon ?? Icons.home;
    return Icons.home;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final enableHapticFeedback = ref.watch(
      appSettingProvider.select((state) => state.enableNavBarHapticFeedback),
    );

    void handleTabChange(int index) {
      if (system.isAndroid && enableHapticFeedback) {
        HapticFeedback.selectionClick();
      }
      onTabChange(index);
    }

    return RepaintBoundary(
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.only(
            left: FluxoraSpacing.lg,
            right: FluxoraSpacing.lg,
            top: FluxoraSpacing.sm,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              // 24 rather than the old 36: a 36 radius on a 78 px bar reads as
              // a capsule, which made the dock look heavier than the content it
              // floats over. 24 keeps the corner unmistakably soft without the
              // pill silhouette.
              borderRadius: BorderRadius.circular(FluxoraRadius.xl),
              border: Border.all(
                color: scheme.outlineVariant.withValues(
                  alpha: scheme.brightness == Brightness.light ? 0.45 : 0.3,
                ),
                width: 1,
              ),
              // It is a floating surface above scrolling content, i.e. the
              // `menu` rung (§8.1 / §8.2). The ladder already encodes "soft in
              // light, faint in dark", so the widget does not invent numbers.
              boxShadow: FluxoraElevation.of(scheme.brightness).menu,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FluxoraSpacing.sm,
                vertical: FluxoraSpacing.xs + FluxoraSpacing.xxs,
              ),
              child: Row(
                children: [
                  for (var index = 0; index < navigationItems.length; index++)
                    Expanded(
                      child: _AuroraDockItem(
                        icon: _iconOf(navigationItems[index].icon),
                        label: Intl.message(navigationItems[index].label.name),
                        selected: index == selectedIndex,
                        onTap: () => handleTabChange(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuroraDockItem extends StatefulWidget {
  const _AuroraDockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AuroraDockItem> createState() => _AuroraDockItemState();
}

class _AuroraDockItemState extends State<_AuroraDockItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = scheme.brightness;
    final selected = widget.selected;

    final tint = FluxoraColorSet.selectionTint(scheme.primary, brightness);
    final hoverWash = scheme.onSurface.withValues(
      alpha: brightness == Brightness.dark ? 0.06 : 0.05,
    );
    final iconColor = selected ? scheme.primary : scheme.onSurfaceVariant;
    // Same split as the rail: `primary` on the tinted pill is ~4.1:1 in the
    // light theme, so the label stays neutral and the icon + accent carry the
    // brand.
    final labelColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular(FluxoraRadius.md);

    // No `Stack`: a fixed-height box clipped the label at 1.4x (measured: 1 px
    // overflow at 320×640). The accent lane is a real child instead, so the item
    // grows with the text and the dock height follows — which is fine, because
    // `home.dart` measures the dock and injects the real inset.
    return Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AuroraBottomNavBar.itemHeight,
        ),
        child: Material(
          color: selected
              ? tint
              : (_hovered ? hoverWash : Colors.transparent),
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
            // Feedback is not tied to the haptics preference: turning off
            // vibration should not turn off the touch response.
            splashColor: scheme.primary.withValues(alpha: 0.10),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FluxoraSpacing.xxs,
                vertical: FluxoraSpacing.xxs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Accent lane. Always 3 px tall so the icon does not shift
                  // when the selection moves; only the tick itself appears.
                  SizedBox(
                    height: 3,
                    child: selected
                        ? Center(
                            child: Container(
                              key: const ValueKey('aurora-dock-accent'),
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
                  const SizedBox(height: FluxoraSpacing.xxs),
                  Icon(widget.icon, size: 20, color: iconColor),
                  const SizedBox(height: FluxoraSpacing.xxs),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (Theme.of(context).textTheme.labelLarge ??
                                const TextStyle())
                            .copyWith(
                      fontSize: FluxoraFontSize.compact,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: labelColor,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
