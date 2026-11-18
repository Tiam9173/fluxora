import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'package:flutter/physics.dart';
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

class _AuroraBottomNavBarState extends ConsumerState<AuroraBottomNavBar>
    with SingleTickerProviderStateMixin {
  late final _position = AnimationController.unbounded(
    vsync: this,
    value: _selected.toDouble(),
  );
  final _previewIndex = ValueNotifier<int?>(null);
  bool _dragging = false;
  int? _destination;

  int get _last => widget.navigationItems.length - 1;
  int get _selected => _last < 0 ? 0 : widget.selectedIndex.clamp(0, _last);

  @override
  void didUpdateWidget(covariant AuroraBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length) {
      _dragging = false;
      _previewIndex.value = null;
      _destination = null;
      _position.value = _selected.toDouble();
    } else if (oldWidget.selectedIndex != widget.selectedIndex && !_dragging) {
      if (_destination != _selected) _settle(_selected);
    }
  }

  @override
  void dispose() {
    _previewIndex.dispose();
    _position.dispose();
    super.dispose();
  }

  void _settle(int index, {double? velocity}) {
    _destination = index;
    final motion = FluxoraMotion.ofContext(context);
    final target = index.toDouble();
    if (motion.reduceMotion || target == _position.value) {
      _position.value = target;
    } else if (velocity != null) {
      _position.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 320, damping: 29),
          _position.value,
          target,
          velocity.clamp(-8, 8),
          snapToEnd: true,
          tolerance: const Tolerance(distance: .003, velocity: .03),
        ),
      );
    } else {
      _position.animateTo(
        target,
        duration: motion.base,
        curve: motion.standard,
      );
    }
  }

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
              border: Border.fromBorderSide(
                BorderSide(color: lensHighlight.withValues(alpha: .16)),
              ),
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
      final canDrag = material.liquid && count > 1 && itemWidth > 0;
      final rtl = Directionality.of(context) == TextDirection.rtl;

      void drag(Offset position) {
        if (!_dragging) setState(() => _dragging = true);
        final x = rtl ? width - position.dx : position.dx;
        final track = x / itemWidth - .5;
        final inside = track.clamp(0.0, count - 1.0);
        final excess = track - inside;
        _position.value = motion.reduceMotion
            ? inside
            : inside + excess * .18 / (1 + excess.abs());
        _previewIndex.value = inside.round();
      }

      void finishDrag({double? pixelsPerSecond}) {
        if (!_dragging) return;
        final velocity = pixelsPerSecond == null
            ? 0.0
            : pixelsPerSecond / itemWidth * (rtl ? -1 : 1);
        final lead = motion.reduceMotion
            ? 0.0
            : (velocity * .10).clamp(-.40, .40);
        final destination = pixelsPerSecond == null
            ? _selected
            : (_position.value + lead).round().clamp(0, count - 1);
        setState(() => _dragging = false);
        _previewIndex.value = null;
        _settle(destination, velocity: velocity);
        if (destination != selectedIndex) {
          handleTabChange(destination);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                !_dragging &&
                _destination == destination &&
                _selected != destination) {
              _settle(_selected);
            }
          });
        }
      }

      return Listener(
        onPointerCancel: (_) => finishDrag(),
        child: GestureDetector(
          excludeFromSemantics: true,
          onLongPressStart: canDrag
              ? (details) => drag(details.localPosition)
              : null,
          onLongPressMoveUpdate: canDrag
              ? (details) => drag(details.localPosition)
              : null,
          onLongPressCancel: canDrag ? finishDrag : null,
          onLongPressEnd: canDrag
              ? (details) => finishDrag(
                  pixelsPerSecond: details.velocity.pixelsPerSecond.dx,
                )
              : null,
          onHorizontalDragStart: canDrag
              ? (details) => drag(details.localPosition)
              : null,
          onHorizontalDragUpdate: canDrag
              ? (details) => drag(details.localPosition)
              : null,
          onHorizontalDragCancel: canDrag ? finishDrag : null,
          onHorizontalDragEnd: canDrag
              ? (details) =>
                    finishDrag(pixelsPerSecond: details.primaryVelocity ?? 0)
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      end: _dragging && !motion.reduceMotion ? 1 : 0,
                    ),
                    duration: motion.fast,
                    curve: Curves.easeOutCubic,
                    child: lensMaterial,
                    builder: (context, lift, lens) => AnimatedBuilder(
                      animation: _position,
                      child: lens,
                      builder: (context, lens) {
                        final position = motion.reduceMotion && !_dragging
                            ? _selected.toDouble()
                            : _position.value;
                        final liftAmount = lift * (.5 + .5 * motion.intensity);
                        final stretch = liftAmount * .27;
                        final lensWidth = (itemWidth * (1 + stretch)).clamp(
                          0.0,
                          width,
                        );
                        final restPosition = position.clamp(0.0, count - 1.0);
                        final center = ((restPosition + .5) * itemWidth).clamp(
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
                          child: Transform.translate(
                            offset: Offset(
                              (position - restPosition) *
                                  itemWidth *
                                  (rtl ? -1 : 1),
                              0,
                            ),
                            child: Transform.scale(
                              scaleY: 1 + .24 * liftAmount,
                              child: SizedBox(
                                key: const ValueKey('aurora-dock-lens'),
                                width: lensWidth,
                                height: double.infinity,
                                child: lens,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<int?>(
                valueListenable: _previewIndex,
                builder: (context, preview, _) => Row(
                  children: [
                    for (var index = 0; index < count; index++)
                      Expanded(
                        child: _AuroraDockItem(
                          icon: _iconOf(navigationItems[index].icon),
                          label: Intl.message(
                            navigationItems[index].label.name,
                          ),
                          selected: index == selectedIndex,
                          emphasized: index == (preview ?? selectedIndex),
                          onTap: () => handleTabChange(index),
                        ),
                      ),
                  ],
                ),
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
    final liquid = FluxoraMaterial.of(context).liquid;

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
            splashFactory: liquid ? NoSplash.splashFactory : null,
            highlightColor: liquid ? hoverWash : null,
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
