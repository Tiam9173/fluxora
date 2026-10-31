import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommonPopupRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  ValueNotifier<Offset> offsetNotifier;

  /// OS-level "reduce motion" when the popup was opened.
  ///
  /// The popup is a route transition; under reduced motion it appears in place
  /// with no fade, no scale and no travel.
  final bool reduceMotion;

  CommonPopupRoute({
    required this.barrierLabel,
    required this.builder,
    required this.offsetNotifier,
    this.reduceMotion = false,
  });

  @override
  String? barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const align = Alignment.topRight;
    // The field carries the preference for `transitionDuration`, which has no
    // context; reading it here as well means a route constructed directly (as
    // the tests and any future caller may do) still lands in its final state.
    final reduce =
        reduceMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: offsetNotifier,
        builder: (_, value, child) {
          return Align(
            alignment: align,
            child: CustomSingleChildLayout(
              delegate: OverflowAwareLayoutDelegate(
                offset: value.translate(48, -8),
              ),
              child: child,
            ),
          );
        },
        child: AnimatedBuilder(
          animation: animation,
          // `Curve.transform` rather than a `CurvedAnimation`: this builder runs
          // on every tick, and `CurvedAnimation`'s constructor adds a status
          // listener to its parent that only `dispose()` removes — one leaked
          // listener per frame for the life of the route.
          builder: (_, Widget? child) {
            final value = reduce
                ? 1.0
                : FluxoraMotion.enter.transform(animation.value);
            return Opacity(
              // Starts at 0. The old `0.1 + 0.9 * value` painted the popup at
              // 10 % opacity on its first frame — a visible flash on open.
              opacity: value,
              child: Transform.scale(
                alignment: align,
                // §10.4 caps scaling at 1.1×; the old 0.7 → 1.0 was a 1.43×
                // change, the largest scale animation in the app.
                scale: 0.98 + 0.02 * value,
                child: Transform.translate(
                  offset: Offset(0, -10) * (1 - value),
                  child: child!,
                ),
              ),
            );
          },
          child: builder(context),
        ),
      ),
    );
  }

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : FluxoraMotion.fast;
}

typedef PopupOpen = Function({Offset offset});

class CommonPopupBox extends StatefulWidget {
  final Widget Function(PopupOpen open) targetBuilder;
  final Widget popup;

  const CommonPopupBox({
    super.key,
    required this.targetBuilder,
    required this.popup,
  });

  @override
  State<CommonPopupBox> createState() => _CommonPopupBoxState();
}

class _CommonPopupBoxState extends State<CommonPopupBox> {
  bool _isOpen = false;
  final _targetOffsetValueNotifier = ValueNotifier<Offset>(Offset.zero);
  Offset _offset = Offset.zero;

  void _open({Offset offset = Offset.zero}) {
    _offset = offset;
    _updateOffset();
    _isOpen = true;
    Navigator.of(context)
        .push(
          CommonPopupRoute(
            barrierLabel: utils.id,
            reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
            builder: (BuildContext context) {
              return widget.popup;
            },
            offsetNotifier: _targetOffsetValueNotifier,
          ),
        )
        .then((_) {
          _isOpen = false;
        });
  }

  void _updateOffset() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final viewPadding = MediaQuery.of(context).viewPadding;
    _targetOffsetValueNotifier.value = renderBox
        .localToGlobal(
          Offset.zero.translate(viewPadding.right, viewPadding.top),
        )
        .translate(_offset.dx, _offset.dy);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isOpen) {
            _updateOffset();
          }
        });
        return widget.targetBuilder(_open);
      },
    );
  }
}

class OverflowAwareLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset offset;

  OverflowAwareLayoutDelegate({required this.offset});

  @override
  Size getSize(BoxConstraints constraints) {
    return Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final safeOffset = Offset(16, 16);
    double x = (offset.dx - childSize.width).clamp(
      0,
      size.width - safeOffset.dx - childSize.width,
    );
    double y = (offset.dy).clamp(
      0,
      size.height - safeOffset.dy - childSize.height,
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant OverflowAwareLayoutDelegate oldDelegate) {
    return oldDelegate.offset != offset;
  }
}

class CommonPopupMenu extends StatefulWidget {
  final List<PopupMenuItemData> items;
  final double minWidth;
  final double minItemVerticalPadding;
  final double fontSize;

  const CommonPopupMenu({
    super.key,
    required this.items,
    this.minWidth = 200,
    this.minItemVerticalPadding = 16,
    this.fontSize = 15,
  });

  @override
  State<CommonPopupMenu> createState() => _CommonPopupMenuState();
}

/// A menu is a keyboard surface, not just a list of tappable rows.
///
/// Phase 05.4 added the missing half: real `FocusNode`s with the WAI-ARIA
/// "roving tabindex" pattern (one Tab stop for the whole menu, arrows move
/// inside it), Enter/Space activation, and `button` / disabled semantics. The
/// pointer paths are untouched — the same `InkWell` still handles hover, splash
/// and tap, and a disabled row still has no `onTap`.
class _CommonPopupMenuState extends State<CommonPopupMenu> {
  final List<FocusNode> _nodes = <FocusNode>[];
  int? _focused;

  @override
  void initState() {
    super.initState();
    _syncNodes();
    // The menu is opened by a pointer or a key; either way the keyboard has to
    // land on the first row the user can actually act on.
    final first = _firstEnabled();
    if (first != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nodes[first].requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CommonPopupMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _syncNodes();
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncNodes() {
    while (_nodes.length < widget.items.length) {
      _nodes.add(FocusNode(debugLabel: 'CommonPopupMenu[${_nodes.length}]'));
    }
    while (_nodes.length > widget.items.length) {
      _nodes.removeLast().dispose();
    }
  }

  int? _firstEnabled() {
    for (var i = 0; i < widget.items.length; i++) {
      if (widget.items[i].onPressed != null) return i;
    }
    return null;
  }

  /// The single Tab stop: the focused row, else the first enabled one.
  int? get _tabStop => _focused ?? _firstEnabled();

  /// Moves the focus by [delta] rows, skipping disabled ones and wrapping.
  ///
  /// Wrapping is deliberate: a menu is short and the user's hand is on the
  /// arrow keys, so stopping at the end would feel like a dead control.
  void _moveFocus(int delta) {
    final count = widget.items.length;
    if (count == 0) return;
    final start = _focused ?? (delta > 0 ? -1 : 0);
    for (var step = 1; step <= count; step++) {
      final index = ((start + delta * step) % count + count) % count;
      if (widget.items[index].onPressed != null) {
        _nodes[index].requestFocus();
        return;
      }
    }
  }

  void _activate(int index) {
    final item = widget.items[index];
    final onPressed = item.onPressed;
    if (onPressed == null) return;
    Navigator.of(context).pop();
    onPressed();
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _activate(index);
      return KeyEventResult.handled;
    }
    // Escape is deliberately *not* handled here: `ModalRoute` maps it to
    // `DismissIntent` and pops the route for us.
    return KeyEventResult.ignored;
  }

  Widget _item(BuildContext context, int index) {
    final item = widget.items[index];
    final onPressed = item.onPressed;
    final disabled = onPressed == null;
    final color = disabled
        ? context.colorScheme.onSurface.opacity30
        : context.colorScheme.onSurface;
    final focused = _focused == index;
    final scheme = Theme.of(context).colorScheme;

    return Focus(
      focusNode: _nodes[index],
      canRequestFocus: !disabled,
      skipTraversal: index != _tabStop,
      onFocusChange: (hasFocus) {
        if (!mounted) return;
        setState(() {
          if (hasFocus) {
            _focused = index;
          } else if (_focused == index) {
            _focused = null;
          }
        });
      },
      onKeyEvent: (_, event) => _handleKey(index, event),
      child: Semantics(
        button: true,
        enabled: !disabled,
        child: DecoratedBox(
          // Always-present border so gaining focus never shifts the row; the
          // same 2 px `primary` ring the segmented control uses.
          decoration: BoxDecoration(
            border: Border.all(
              color: focused ? scheme.primary : const Color(0x00000000),
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: disabled
                ? null
                : () {
                    Navigator.of(context).pop();
                    onPressed();
                  },
            child: Container(
              constraints: BoxConstraints(minWidth: widget.minWidth),
              padding: EdgeInsets.only(
                left: 16,
                right: 64,
                top: widget.minItemVerticalPadding,
                bottom: widget.minItemVerticalPadding,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (item.icon != null) ...[
                    // The row already announces its label; the glyph must not
                    // repeat it.
                    ExcludeSemantics(
                      child: Icon(
                        item.icon,
                        size: widget.fontSize + 4,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Flexible(
                    child: Text(
                      item.label,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontSize: widget.fontSize,
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

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: IntrinsicWidth(
        child: Card(
          elevation: 12,
          color: context.colorScheme.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluxoraRadius.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < widget.items.length; index++) ...[
                _item(context, index),
                if (widget.items[index] != widget.items.last)
                  const Divider(height: 0),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
