import 'dart:async';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/connection/connections.dart';
import 'package:bett_box/widgets/widgets.dart';
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
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(iconData: Icons.ballot, label: appLocalizations.connection),
        onPressed: () {
          showExtend(
            context,
            builder: (_, type) {
              return const ConnectionsView(respectCurrentPage: false);
            },
          );
        },
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$_count',
                  style: context.textTheme.bodyLarge?.toLight.adjustSize(2),
                ),
                const SizedBox(width: 4),
                Text(
                  ' Connections',
                  style: context.textTheme.bodyMedium?.toLight.adjustSize(0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
