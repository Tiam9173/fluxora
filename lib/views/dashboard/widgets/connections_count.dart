import 'dart:async';

import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/connection/connections.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';

class ConnectionsCount extends StatefulWidget {
  const ConnectionsCount({super.key});

  @override
  State<ConnectionsCount> createState() => _ConnectionsCountState();
}

class _ConnectionsCountState extends State<ConnectionsCount> {
  int _count = 0;
  late final VoidCallback _tickListener;
  Timer? _initTimer;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _tickListener = _updateConnections;
    dashboardRefreshManager.tick2s.addListener(_tickListener);
    _initTimer = Timer(const Duration(milliseconds: 1000), _updateConnections);
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    dashboardRefreshManager.tick2s.removeListener(_tickListener);
    super.dispose();
  }

  Future<void> _updateConnections() async {
    if (!mounted) return;
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      final connections = await clashCore.getConnections();
      if (mounted) {
        setState(() {
          _count = connections.length;
        });
      }
    } catch (e) {
      // Ignore error, keep current value
    } finally {
      _isUpdating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return SizedBox(
      height: getWidgetHeight(1),
      child: FluxoraCard(
        info: Info(iconData: Icons.ballot, label: appLocalizations.connection),
        onTap: () {
          showExtend(
            context,
            builder: (_, type) {
              return const ConnectionsView(respectCurrentPage: false);
            },
          );
        },
        child: Padding(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Monospaced so the figure does not jitter while it ticks.
                Text(
                  '$_count',
                  style: FluxoraTypography.numericTitle.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: FluxoraSpacing.xs),
                Text(
                  appLocalizations.connections,
                  style: FluxoraTypography.label.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
