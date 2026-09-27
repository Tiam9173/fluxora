import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:flutter/material.dart';

/// Which direction(s) a [FluxoraSpeedGauge] reports.
enum FluxoraSpeedGaugeMode { download, upload, combined }

/// Presentation state of a [FluxoraSpeedGauge].
enum FluxoraSpeedGaugeState {
  /// No sample yet.
  loading,

  /// Sampled, but nothing is moving.
  zero,

  /// Sampled with non-zero throughput.
  active,
}

/// A restrained network-speed read-out: `↓ 1.2 MB/s` / `↑ 340 KB/s`.
///
/// Deliberately **not** a dial or arc gauge — the Fluxora principles forbid
/// exaggerated dashboards, so this is a numeric read-out using
/// [FluxoraTypography.numericBody] / [FluxoraTypography.numericLabel]
/// (monospaced) so the digits do not jitter while values tick.
///
/// Numbers are formatted with the project's existing `TrafficValue` ladder
/// (B / KB / MB / GB / TB), so units match the rest of the app. This widget is
/// purely presentational — it takes plain byte-per-second values and never
/// reads a provider.
///
/// ```dart
/// FluxoraSpeedGauge(download: 1_258_291, upload: 43_008);
/// FluxoraSpeedGauge(mode: FluxoraSpeedGaugeMode.upload, upload: 0);
/// FluxoraSpeedGauge(); // loading
/// ```
class FluxoraSpeedGauge extends StatelessWidget {
  const FluxoraSpeedGauge({
    super.key,
    this.download,
    this.upload,
    this.mode = FluxoraSpeedGaugeMode.combined,
    this.state,
    this.label,
    this.compact = false,
  });

  /// Download throughput in bytes per second. `null` means "not sampled".
  final int? download;

  /// Upload throughput in bytes per second. `null` means "not sampled".
  final int? upload;

  final FluxoraSpeedGaugeMode mode;

  /// Overrides the derived state. When null it is inferred from the values.
  final FluxoraSpeedGaugeState? state;

  /// Optional caption above the values.
  final String? label;

  /// Uses the smaller numeric style and icon size.
  final bool compact;

  /// Infers [FluxoraSpeedGaugeState] from the supplied values.
  static FluxoraSpeedGaugeState deriveState({
    int? download,
    int? upload,
  }) {
    if (download == null && upload == null) {
      return FluxoraSpeedGaugeState.loading;
    }
    final total = (download ?? 0) + (upload ?? 0);
    return total == 0 ? FluxoraSpeedGaugeState.zero : FluxoraSpeedGaugeState.active;
  }

  /// Formats bytes-per-second using the shared `TrafficValue` unit ladder.
  static String formatSpeed(int? bytesPerSecond) {
    if (bytesPerSecond == null) return '—';
    if (bytesPerSecond == 0) return '0 B/s';
    return '${TrafficValue(value: bytesPerSecond).shortShow}/s';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = state ?? deriveState(download: download, upload: upload);
    final labelText = label;

    final children = <Widget>[
      if (labelText != null && labelText.isNotEmpty) ...[
        Text(
          labelText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FluxoraTypography.caption.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: FluxoraSpacing.xs),
      ],
      if (resolved == FluxoraSpeedGaugeState.loading)
        _buildLoading(context)
      else if (mode == FluxoraSpeedGaugeMode.combined)
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildValue(context, Icons.arrow_downward, formatSpeed(download)),
            const SizedBox(height: FluxoraSpacing.xs),
            _buildValue(context, Icons.arrow_upward, formatSpeed(upload)),
          ],
        )
      else
        _buildValue(
          context,
          mode == FluxoraSpeedGaugeMode.download
              ? Icons.arrow_downward
              : Icons.arrow_upward,
          formatSpeed(
            mode == FluxoraSpeedGaugeMode.download ? download : upload,
          ),
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildLoading(BuildContext context) {
    final size = compact ? 12.0 : 14.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: FluxoraSpacing.xs),
        Text(
          '—',
          style: (compact
                  ? FluxoraTypography.numericLabel
                  : FluxoraTypography.numericBody)
              .copyWith(color: context.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildValue(BuildContext context, IconData icon, String text) {
    final colorScheme = context.colorScheme;
    // No `Flexible`: the row has no flexible siblings, so children get the
    // incoming max width — ellipsis works when bounded, and an unbounded parent
    // cannot trip RenderFlex's unbounded-flex assertion.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: compact ? 12 : 14,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: FluxoraSpacing.xs),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (compact
                  ? FluxoraTypography.numericLabel
                  : FluxoraTypography.numericBody)
              .copyWith(color: colorScheme.onSurface),
        ),
      ],
    );
  }
}
