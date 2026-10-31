import 'package:flutter/widgets.dart';

/// Publishes the floating dock's measured height to the page underneath it.
///
/// ## Why this exists
///
/// The mobile shell paints the dock **over** the page, so pages have to reserve
/// space for it. Two mechanisms grew up around that:
///
/// * `generateListView` reads the dock height from the `MediaQuery.padding.bottom`
///   the shell injects — always correct.
/// * Six hand-built pages (dashboard, logs, profiles, proxies list, proxies tab,
///   tools) call `getFloatingBottomBarReserveHeight()`, which used to return a
///   fixed 84 px. That number was an estimate of the *old* `GNav` dock. The
///   Aurora dock measures 77 px at 1.0× and 92 px at 2.0×, so the constant
///   over-reserved at normal text and **under-reserved by 8 px** at 2.0×.
///
/// `MediaQuery.padding` cannot carry the fix: those pages add their own bottom
/// padding on top of it, so reading the injected inset there would double-count
/// (the helper's own comment already records that mistake). An inherited widget
/// is the smallest thing that (a) carries the real number, (b) rebuilds the
/// pages when the measurement changes, and (c) adds no global mutable state —
/// its lifetime is exactly the page subtree's.
///
/// The shell publishes the value only on mobile. When it is absent — desktop,
/// TV, or any host that does not mount the dock — readers fall back to their own
/// estimate.
@immutable
class FloatingDockMetrics extends InheritedWidget {
  const FloatingDockMetrics({super.key, required this.height, required super.child});

  /// Measured dock height in logical pixels, or `0` before the first
  /// post-frame measure has landed.
  final double height;

  /// The dock height, or `0` when no dock is mounted above this subtree.
  ///
  /// Registers a dependency, so a page that reserves space re-lays-out when the
  /// dock's height changes (text scale, rotation, window resize).
  static double maybeHeightOf(BuildContext context) {
    final metrics = context
        .dependOnInheritedWidgetOfExactType<FloatingDockMetrics>();
    return metrics?.height ?? 0;
  }

  @override
  bool updateShouldNotify(FloatingDockMetrics oldWidget) =>
      oldWidget.height != height;
}
