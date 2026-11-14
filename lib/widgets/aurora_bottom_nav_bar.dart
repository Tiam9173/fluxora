import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show Intl;

import '../common/common.dart';
import '../models/common.dart';
import '../providers/config.dart';

/// Stable, labelled destinations in a restrained floating capsule.
/// Selection uses a neutral glass highlight; keyboard focus keeps its own ring.
class AuroraBottomNavBar extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<AuroraBottomNavBar> createState() => _AuroraBottomNavBarState();
}

class _AuroraBottomNavBarState extends ConsumerState<AuroraBottomNavBar> {
  double? _dragIndex;

  IconData _iconOf(Widget iconWidget) {
    if (iconWidget is Icon) return iconWidget.icon ?? Icons.home;
    return Icons.home;
  }

  @override
  Widget build(BuildContext context) {
    final navigationItems = widget.navigationItems;
    final selectedIndex = widget.selectedIndex;
    if (navigationItems.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final motion = FluxoraMotion.ofContext(context);
    final material = FluxoraMaterial.of(context);
    final pearl =
        material.isObsidian &&
        material.blurEnabled &&
        scheme.brightness == Brightness.light;
    final lensHighlight = pearl ? Colors.white : scheme.onSurface;
    final enableHapticFeedback = ref.watch(
      appSettingProvider.select((state) => state.enableNavBarHapticFeedback),
    );

    void handleTabChange(int index) {
      if (system.isAndroid && enableHapticFeedback) {
        HapticFeedback.selectionClick();
      }
      widget.onTabChange(index);
    }

    final lensMaterial = material.liquid
        ? DecoratedBox(
            // The dock already samples the background. A second filter here
            // bends the first lens and makes its edges visible twice.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FluxoraRadius.sheet),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(
                    alpha: scheme.brightness == Brightness.dark ? .13 : .52,
                  ),
                  scheme.primary.withValues(alpha: .11),
                ],
              ),
              border: Border.all(color: material.border(scheme)),
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(
                alpha: scheme.brightness == Brightness.dark ? .09 : .06,
              ),
              gradient: material.isObsidian && material.blurEnabled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        lensHighlight.withValues(alpha: pearl ? .9 : .13),
                        lensHighlight.withValues(alpha: pearl ? .35 : .035),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(FluxoraRadius.xl),
              border: Border.all(
                color: lensHighlight.withValues(alpha: pearl ? .95 : .16),
              ),
            ),
          );

    Widget buildTabs(BuildContext context, BoxConstraints constraints) {
      final count = navigationItems.length;
      final width = constraints.maxWidth;
      final itemWidth = width / count;
      final selected = selectedIndex.clamp(0, count - 1).toDouble();
      final dragging = _dragIndex != null;
      final target = (_dragIndex ?? selected).clamp(0.0, count - 1.0);
      final canDrag = material.liquid && count > 1 && itemWidth > 0;

      void drag(Offset position) {
        final x = Directionality.of(context) == TextDirection.rtl
            ? width - position.dx
            : position.dx;
        setState(
          () => _dragIndex = (x / itemWidth - .5).clamp(0.0, count - 1.0),
        );
      }

      void cancelDrag() {
        if (_dragIndex != null) setState(() => _dragIndex = null);
      }

      return Listener(
        onPointerCancel: (_) => cancelDrag(),
        child: GestureDetector(
          onHorizontalDragStart: canDrag
              ? (details) => drag(details.localPosition)
              : null,
          onHorizontalDragUpdate: canDrag
              ? (details) => drag(details.localPosition)
              : null,
          onHorizontalDragCancel: canDrag ? cancelDrag : null,
          onHorizontalDragEnd: canDrag
              ? (_) {
                  final destination = _dragIndex
                      ?.clamp(0.0, count - 1.0)
                      .round();
                  cancelDrag();
                  if (destination != null && destination != selectedIndex) {
                    handleTabChange(destination);
                  }
                }
              : null,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: const ValueKey('aurora-dock-indicator'),
                    tween: Tween(end: target),
                    duration: dragging ? Duration.zero : motion.base,
                    curve: material.liquid || motion.expressive
                        ? Curves.easeOutBack
                        : motion.standard,
                    child: lensMaterial,
                    builder: (context, position, lens) {
                      final stretch = material.liquid && !motion.reduceMotion
                          ? motion.intensity *
                                (dragging
                                    ? .32
                                    : .42 *
                                          (target - position).abs().clamp(0, 1))
                          : 0.0;
                      final lensWidth = (itemWidth * (1 + stretch)).clamp(
                        0.0,
                        width,
                      );
                      final center = ((position + .5) * itemWidth).clamp(
                        lensWidth / 2,
                        width - lensWidth / 2,
                      );
                      final travel = width - lensWidth;
                      return Align(
                        alignment: AlignmentDirectional(
                          travel <= 0
                              ? 0
                              : 2 * (center - lensWidth / 2) / travel - 1,
                          0,
                        ),
                        child: SizedBox(
                          key: const ValueKey('aurora-dock-lens'),
                          width: lensWidth,
                          height: double.infinity,
                          child: lens,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Row(
                children: [
                  for (var index = 0; index < count; index++)
                    Expanded(
                      child: _AuroraDockItem(
                        icon: _iconOf(navigationItems[index].icon),
                        label: Intl.message(navigationItems[index].label.name),
                        selected: index == selectedIndex,
                        emphasized: index == target.round(),
                        onTap: () => handleTabChange(index),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
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
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: GlassSurface(
                    radius: FluxoraRadius.sheet,
                    floating: true,
                    blur: true,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: material.enabled
                            ? null
                            : scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(
                          FluxoraRadius.sheet,
                        ),
                        border: material.enabled
                            ? null
                            : Border.all(
                                color: scheme.outlineVariant.withValues(
                                  alpha: scheme.brightness == Brightness.light
                                      ? .45
                                      : .3,
                                ),
                              ),
                        boxShadow: material.enabled
                            ? null
                            : FluxoraElevation.of(scheme.brightness).menu,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(FluxoraSpacing.xs),
                child: LayoutBuilder(builder: buildTabs),
              ),
            ],
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
    required this.emphasized,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool emphasized;
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

    final hoverWash = scheme.onSurface.withValues(
      alpha: brightness == Brightness.dark ? 0.06 : 0.05,
    );
    final foreground = widget.emphasized
        ? scheme.onSurface
        : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular(FluxoraRadius.xl);
    final motion = FluxoraMotion.ofContext(context);

    return Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AuroraBottomNavBar.itemHeight,
        ),
        child: Material(
          animationDuration: motion.base,
          color: _hovered ? hoverWash : Colors.transparent,
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
                  ExcludeSemantics(
                    child: AnimatedScale(
                      scale: widget.emphasized && !motion.reduceMotion
                          ? 1 + .1 * motion.intensity
                          : 1,
                      duration: motion.fast,
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        widget.icon,
                        key: selected
                            ? const ValueKey('aurora-dock-selection')
                            : null,
                        size: 22,
                        color: foreground,
                      ),
                    ),
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
                                color: foreground,
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
