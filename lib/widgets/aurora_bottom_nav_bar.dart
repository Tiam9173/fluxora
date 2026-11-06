import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../common/common.dart';
import '../models/common.dart';
import '../providers/config.dart';

/// Stable, labelled destinations in a restrained floating capsule.
/// Selection uses a neutral glass highlight; keyboard focus keeps its own ring.
class AuroraBottomNavBar extends ConsumerWidget {
  const AuroraBottomNavBar({
    super.key,
    required this.navigationItems,
    required this.selectedIndex,
    required this.onTabChange,
  });

  static const double itemHeight = 48;

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
          child: GlassSurface(
            radius: FluxoraRadius.sheet,
            floating: true,
            blur: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: FluxoraMaterial.of(context).enabled
                    ? Colors.transparent
                    : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(FluxoraRadius.sheet),
                border: FluxoraMaterial.of(context).enabled
                    ? null
                    : Border.all(
                        color: scheme.outlineVariant.withValues(
                          alpha: scheme.brightness == Brightness.light
                              ? 0.45
                              : 0.3,
                        ),
                        width: 1,
                      ),
                // It is a floating surface above scrolling content, i.e. the
                // `menu` rung (§8.1 / §8.2). The ladder already encodes "soft in
                // light, faint in dark", so the widget does not invent numbers.
                boxShadow: FluxoraMaterial.of(context).enabled
                    ? null
                    : FluxoraElevation.of(scheme.brightness).menu,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FluxoraSpacing.xs,
                  vertical: FluxoraSpacing.xs,
                ),
                child: Row(
                  children: [
                    for (var index = 0; index < navigationItems.length; index++)
                      Expanded(
                        child: _AuroraDockItem(
                          icon: _iconOf(navigationItems[index].icon),
                          label: Intl.message(
                            navigationItems[index].label.name,
                          ),
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

    final tint = scheme.onSurface.withValues(
      alpha: brightness == Brightness.dark ? .09 : .06,
    );
    final hoverWash = scheme.onSurface.withValues(
      alpha: brightness == Brightness.dark ? 0.06 : 0.05,
    );
    final iconColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    final labelColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular(FluxoraRadius.xl);

    return Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AuroraBottomNavBar.itemHeight,
        ),
        child: Material(
          animationDuration: FluxoraMotion.ofContext(context).base,
          color: selected ? tint : (_hovered ? hoverWash : Colors.transparent),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: _focused
                ? BorderSide(color: scheme.primary, width: 2)
                : BorderSide(
                    color: selected
                        ? scheme.onSurface.withValues(alpha: .16)
                        : Colors.transparent,
                  ),
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
              key: selected ? const ValueKey('aurora-dock-selection') : null,
              padding: const EdgeInsets.symmetric(
                horizontal: FluxoraSpacing.xxs,
                vertical: FluxoraSpacing.xxs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Icon(widget.icon, size: 22, color: iconColor),
                  ),
                  const SizedBox(height: FluxoraSpacing.xs),
                  // P8-2B F-3 — the `Semantics(label:)` above is the
                  // authoritative name. Left in the tree, this `Text` merges
                  // its own label into the same node and the screen reader
                  // announces "dashboard dashboard".
                  ExcludeSemantics(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (Theme.of(context).textTheme.labelLarge ??
                                  const TextStyle())
                              .copyWith(
                                fontSize: FluxoraFontSize.compact,
                                height: 1.1,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: labelColor,
                                letterSpacing: 0,
                              ),
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
