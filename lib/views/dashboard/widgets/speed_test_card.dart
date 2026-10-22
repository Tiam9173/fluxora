import 'dart:async';
import 'dart:math' as math;

import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/material.dart';

/// 从首页「网络速度」卡片点开的测速卡片。
///
/// 数字来自内核：`core/speedtest.go` 经代理发 8 条并发流。这里只负责画，
/// 不做任何测速逻辑——进度靠轮询 `speedTestStatus` 拿。
class SpeedTestCard extends StatefulWidget {
  const SpeedTestCard({super.key});

  @override
  State<SpeedTestCard> createState() => _SpeedTestCardState();
}

class _SpeedTestCardState extends State<SpeedTestCard> {
  Timer? _poll;
  Timer? _watchdog;
  SpeedTestProgress _progress = const SpeedTestProgress();
  bool _running = false;
  bool _gotFrame = false;

  /// 动态量程：按本轮见过的峰值往上取档，只增不减，避免测速途中弧线来回跳。
  double _scale = 100;
  double _peak = 0;

  @override
  void initState() {
    super.initState();
    // 300ms 一次：测速是秒级过程，这个间隔看不出延迟，也不会给 FFI 添负担。
    _poll = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      if (!mounted) return;
      final p = await clashCore.speedTestStatus();
      if (!mounted) return;
      if (p.phase != 'idle') {
        _gotFrame = true;
        _watchdog?.cancel();
      }
      setState(() {
        _progress = p;
        if (p.headlineMbps > _peak) _peak = p.headlineMbps;
        _scale = _scaleFor(_peak);
        if (p.isDone || p.isFailed) _running = false;
      });
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _gotFrame = false;
      _peak = 0;
      _scale = 100;
      _progress = const SpeedTestProgress(phase: 'latency');
    });
    // 3 秒没有任何一帧，说明内核那边没动，比一直显示 0 更容易定位。
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 3), () {
      if (!mounted || _gotFrame) return;
      setState(() {
        _running = false;
        _progress = const SpeedTestProgress(
          phase: 'failed',
          error: '内核没有响应测速请求',
        );
      });
    });
    try {
      await globalState.appController.speedTest();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _progress = SpeedTestProgress(phase: 'failed', error: '$e');
      });
    }
  }

  /// 量程只在这几个档位之间跳：100M / 500M / 1G / 2.5G / 5G。
  /// 用固定档位而不是"当前值 ×1.2"，是为了让弧线在整轮测速里刻度稳定。
  static double _scaleFor(double peak) {
    const buckets = [100.0, 500.0, 1000.0, 2500.0, 5000.0];
    for (final b in buckets) {
      if (peak <= b) return b;
    }
    return buckets.last;
  }

  static String _scaleLabel(double scale) {
    if (scale >= 1000) {
      final g = scale / 1000;
      return '${g == g.roundToDouble() ? g.toInt() : g}G';
    }
    return '${scale.toInt()}M';
  }

  String _fmt(double mbps) {
    if (mbps >= 100) return mbps.toStringAsFixed(0);
    if (mbps >= 10) return mbps.toStringAsFixed(1);
    return mbps.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final p = _progress;
    final target = p.headlineMbps;

    return Dialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appLocalizations.networkSpeed,
                    style: context.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: appLocalizations.close,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 数字和弧线一起用同一个补间，跳变会变成"爬上去"，读数更顺。
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: target),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(180, 180),
                        painter: _ArcPainter(
                          progress: (value / _scale).clamp(0.0, 1.0),
                          color: scheme.primary,
                          track: scheme.onSurfaceVariant.withValues(
                            alpha: 0.18,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _fmt(value),
                            style: context.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text('Mbps', style: context.textTheme.bodySmall),
                          Text(
                            '/ ${_scaleLabel(_scale)}',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _PhaseDots(phase: p.phase),
            if (p.serverName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${p.serverName} · ${appLocalizations.viaProxy}',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat(context, Icons.speed, '${p.latencyMs}', 'ms'),
                _stat(
                  context,
                  Icons.arrow_downward,
                  _fmt(p.downMbps),
                  'Mbps',
                ),
                _stat(context, Icons.arrow_upward, _fmt(p.upMbps), 'Mbps'),
              ],
            ),
            if (p.isFailed && p.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  p.error!,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _running ? null : _start,
                child: Text(
                  p.isDone || p.isFailed
                      ? appLocalizations.retry
                      : appLocalizations.start,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, IconData icon, String value, String unit) {
    final scheme = context.colorScheme;
    return Column(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(unit, style: context.textTheme.labelSmall),
      ],
    );
  }
}

/// 270° 的开口弧：从 -225° 起画，留出下方缺口。
class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const start = -math.pi * 1.25;
    const sweep = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      trackPaint,
    );

    if (progress <= 0) return;
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * progress,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

/// 延迟 → 下载 → 上传 三个点，当前阶段高亮。
class _PhaseDots extends StatelessWidget {
  const _PhaseDots({required this.phase});

  final String phase;

  static const _order = ['latency', 'download', 'upload'];

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    // done 时三个点应该全亮；indexOf 找不到会返回 -1，导致全灭。
    final current = phase == 'done' ? _order.length : _order.indexOf(phase);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _order.length; i++)
          Container(
            width: i == current ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i <= current
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
