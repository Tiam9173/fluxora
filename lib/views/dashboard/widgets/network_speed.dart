import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/app.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'speed_test_card.dart';

class NetworkSpeed extends ConsumerWidget {
  const NetworkSpeed({super.key});

  // Cache as const
  static const _initPoints = [Point(0, 0), Point(1, 0)];

  static List<Point> _getPoints(List<Traffic> traffics) {
    if (traffics.isEmpty) return _initPoints;

    // Pre-allocate array capacity
    final totalLength = traffics.length + _initPoints.length;
    final result = List<Point>.filled(totalLength, Point(0, 0));

    // Assign init points
    result[0] = _initPoints[0];
    result[1] = _initPoints[1];

    // Assign traffic points
    for (int i = 0; i < traffics.length; i++) {
      result[i + 2] = Point((i + 2).toDouble(), traffics[i].speed.toDouble());
    }

    return result;
  }

  static Traffic _getLastTraffic(List<Traffic> traffics) {
    if (traffics.isEmpty) return Traffic();
    return traffics.last;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: getWidgetHeight(1.5),
      child: FluxoraCard(
        onTap: () {
          showDialog(context: context, builder: (_) => const SpeedTestCard());
        },
        info: Info(
          label: appLocalizations.networkSpeed,
          iconData: Icons.speed_sharp,
        ),
        child: RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: TickerMode.valuesOf(context).enabled
                ? dashboardRefreshManager.tick1s
                : dashboardRefreshManager.paused,
            builder: (_, _, _) {
              final traffics = ref.read(trafficsProvider).list;
              final points = _getPoints(traffics);
              final last = _getLastTraffic(traffics);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FluxoraSpacing.lg,
                      vertical: FluxoraSpacing.sm,
                    ),
                    child: Wrap(
                      spacing: FluxoraSpacing.xl,
                      runSpacing: FluxoraSpacing.sm,
                      children: [
                        FluxoraSpeedGauge(
                          mode: FluxoraSpeedGaugeMode.download,
                          download: traffics.isEmpty ? null : last.down.value,
                          // No sample is unknown (—), not a measured zero or loading task.
                          state: traffics.isEmpty
                              ? FluxoraSpeedGaugeState.zero
                              : null,
                        ),
                        FluxoraSpeedGauge(
                          mode: FluxoraSpeedGaugeMode.upload,
                          upload: traffics.isEmpty ? null : last.up.value,
                          state: traffics.isEmpty
                              ? FluxoraSpeedGaugeState.zero
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LineChart(
                      gradient: true,
                      color: primaryColor,
                      points: points,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
