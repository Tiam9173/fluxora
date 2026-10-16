import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/models/chain_analytics.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/common/common.dart';

class ChainDiagnosticPanel extends ConsumerStatefulWidget {
  final ChainTelemetrySnapshot telemetrySnapshot;

  const ChainDiagnosticPanel({super.key, required this.telemetrySnapshot});

  @override
  ConsumerState<ChainDiagnosticPanel> createState() =>
      _ChainDiagnosticPanelState();
}

class _ChainDiagnosticPanelState extends ConsumerState<ChainDiagnosticPanel> {
  bool _isExporting = false;

  void _exportReport() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
    });

    try {
      final file = await chainProxyManager.exportChainDiagnosticReport();
      if (!mounted) return;
      if (file == null) return;
      context.showSnackBar('Report exported: ${file.path}');
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar('Export failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.telemetrySnapshot.isEmpty) {
      return const SizedBox.shrink();
    }

    final intelligence = ChainIntelligenceSnapshot.fromTelemetry(
      widget.telemetrySnapshot,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return CommonCard(
      type: CommonCardType.filled,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                // item 4 — unwrapped this card title overflowed at 280/320 dp
                // under the 1.4x text scale.
                Flexible(
                  child: Text(
                    appLocalizations.chainDiagnosticTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // item 4 — three unbounded stats overflowed the card at 280/320 dp
                // under the 1.4x text scale; give each a third of the width.
                Expanded(
                  child: _buildStat(
                    appLocalizations.chainHealthLabel,
                    '${intelligence.healthScore}',
                    colorScheme,
                  ),
                ),
                Expanded(
                  child: _buildStat(
                    appLocalizations.chainEventsLabel,
                    '${widget.telemetrySnapshot.totalEvents}',
                    colorScheme,
                  ),
                ),
                Expanded(
                  child: _buildStat(
                    appLocalizations.chainFailuresLabel,
                    '${widget.telemetrySnapshot.failedEvents}',
                    colorScheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(
                  _isExporting
                      ? appLocalizations.chainExporting
                      : appLocalizations.chainExportReport,
                ),
                onPressed: _isExporting ? null : _exportReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
