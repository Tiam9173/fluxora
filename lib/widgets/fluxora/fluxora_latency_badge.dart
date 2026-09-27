// Imports the token layer directly (not the `common/common.dart` barrel) so
// `lib/common/utils.dart` can depend on this file for the shared latency
// semantics without creating a barrel cycle.
import 'package:fluxora/common/tokens/tokens.dart';
import 'package:flutter/material.dart';

/// Latency tiers used by [FluxoraLatencyBadge].
enum FluxoraLatencyTier {
  /// Never tested.
  untested,

  /// A test is running.
  testing,

  /// Fast enough for interactive use.
  good,

  /// Usable but noticeably slow.
  fair,

  /// Slow — the connection will feel sluggish.
  poor,

  /// The probe did not answer.
  timeout,
}

/// A compact latency pill: `12 ms` / `120 ms` / `Timeout`.
///
/// Colours come from [FluxoraColorSet] semantic roles, never from hardcoded
/// values. Numbers use [FluxoraTypography.numericLabel] (monospaced) so the
/// width does not jitter while a probe is updating.
///
/// The `int?` convention matches the rest of the codebase
/// (`utils.getDelayColor`, `views/proxies/card.dart`):
///
/// | value | meaning |
/// | --- | --- |
/// | `null` | never tested |
/// | `0` | test in progress |
/// | `< 0` | timeout / unreachable |
/// | `> 0` | measured milliseconds |
///
/// ```dart
/// FluxoraLatencyBadge(delay: 42);
/// FluxoraLatencyBadge(delay: null, onTap: retest);
/// ```
class FluxoraLatencyBadge extends StatelessWidget {
  const FluxoraLatencyBadge({
    super.key,
    required this.delay,
    this.onTap,
    this.timeoutLabel = 'Timeout',
    this.tintBackground = true,
    this.dense = false,
  });

  /// Upper bound (exclusive) of the [FluxoraLatencyTier.good] tier, in ms.
  static const goodMax = 300;

  /// Upper bound (exclusive) of the [FluxoraLatencyTier.fair] tier, in ms.
  static const fairMax = 800;

  /// `null` = untested, `0` = testing, `< 0` = timeout, `> 0` = ms.
  final int? delay;

  /// Makes the badge tappable (e.g. to re-run a latency probe).
  final VoidCallback? onTap;

  /// Shown when [delay] is negative.
  final String timeoutLabel;

  /// Draws the soft tonal background. Turn off for a bare coloured label.
  final bool tintBackground;

  /// Compact mode for fixed-height rows (added in D4.7).
  ///
  /// Drops the vertical padding and pins the line height to 1.0, so the badge is
  /// exactly `fontSize` (12px) tall instead of ~20px. The proxy list uses an
  /// `itemExtentBuilder` with a fixed row height, so the badge has to fit inside
  /// the existing `labelSmallHeight` row without changing the list's extents.
  final bool dense;

  /// Classifies a raw delay value.
  static FluxoraLatencyTier tierOf(int? delay) {
    if (delay == null) return FluxoraLatencyTier.untested;
    if (delay == 0) return FluxoraLatencyTier.testing;
    if (delay < 0) return FluxoraLatencyTier.timeout;
    if (delay < goodMax) return FluxoraLatencyTier.good;
    if (delay < fairMax) return FluxoraLatencyTier.fair;
    return FluxoraLatencyTier.poor;
  }

  /// The semantic colour for [tier] at [brightness] — the single source of
  /// truth for latency colour, shared with `utils.getDelayColor`.
  static Color colorFor(Brightness brightness, FluxoraLatencyTier tier) {
    final fluxora = FluxoraColorSet.of(brightness);
    return switch (tier) {
      FluxoraLatencyTier.good => fluxora.success,
      FluxoraLatencyTier.fair => fluxora.warning,
      FluxoraLatencyTier.poor => fluxora.error,
      FluxoraLatencyTier.timeout => fluxora.error,
      FluxoraLatencyTier.testing => fluxora.info,
      FluxoraLatencyTier.untested => fluxora.outline,
    };
  }

  /// The semantic colour for [tier] at the current brightness.
  static Color colorOf(BuildContext context, FluxoraLatencyTier tier) =>
      colorFor(Theme.of(context).brightness, tier);

  String get _text {
    final value = delay;
    if (value == null) return '—';
    if (value == 0) return '…';
    if (value < 0) return timeoutLabel;
    return '$value ms';
  }

  @override
  Widget build(BuildContext context) {
    final tier = tierOf(delay);
    final color = colorOf(context, tier);

    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: FluxoraSpacing.sm,
        vertical: dense ? 0 : FluxoraSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: tintBackground ? color.withValues(alpha: 0.14) : null,
        borderRadius: FluxoraRadius.xsAll,
      ),
      child: Text(
        _text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FluxoraTypography.numericLabel.copyWith(
          color: color,
          height: dense ? 1.0 : null,
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(label: _text, child: pill);
    }
    return Semantics(
      button: true,
      label: _text,
      child: InkWell(
        onTap: onTap,
        borderRadius: FluxoraRadius.xsAll,
        child: pill,
      ),
    );
  }
}
