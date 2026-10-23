import 'dart:async';
import 'dart:math' as math;

import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:fluxora/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// 曲线只画最近这些帧：300ms 一帧，40 帧约 12 秒，正好覆盖一轮测速。
  static const _historyLimit = 40;
  final List<Point> _history = [];

  double _scale = 100;
  double _peak = 0;

  @override
  void initState() {
    super.initState();
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
        if (p.isRunning && p.headlineMbps > 0) {
          _history.add(Point(_history.length.toDouble(), p.headlineMbps));
          if (_history.length > _historyLimit) _history.removeAt(0);
        }
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
      _history.clear();
      _peak = 0;
      _scale = 100;
      _progress = const SpeedTestProgress(phase: 'latency');
    });
    // 12 秒：选源要查出口位置、拉服务器列表、探节点、拉 32KB 验证，3 秒会误报。
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 12), () {
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

  /// 量程只在几个档位之间跳，避免测速途中刻度来回变。
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

  /// 低于 1 Mbps 用 Kbps，避免出现 "0.35 Mbps" 这种读数。
  static String _fmt(double mbps) {
    if (mbps > 0 && mbps < 1) return (mbps * 1000).toStringAsFixed(0);
    if (mbps >= 1000) return (mbps / 1000).toStringAsFixed(2);
    if (mbps >= 100) return mbps.toStringAsFixed(0);
    if (mbps >= 10) return mbps.toStringAsFixed(1);
    return mbps.toStringAsFixed(2);
  }

  static String _unitFor(double mbps) {
    if (mbps > 0 && mbps < 1) return 'Kbps';
    if (mbps >= 1000) return 'Gbps';
    return 'Mbps';
  }

  String get _phaseText {
    switch (_progress.phase) {
      case 'latency':
        return appLocalizations.stPhaseLatency;
      case 'download':
        return appLocalizations.stPhaseDownload;
      case 'upload':
        return appLocalizations.stPhaseUpload;
      case 'done':
        return appLocalizations.stPhaseDone;
      case 'failed':
        return appLocalizations.stPhaseFailed;
      default:
        return '';
    }
  }

  Future<void> _copy() async {
    final p = _progress;
    final where = globalState.isStart
        ? appLocalizations.viaProxy
        : appLocalizations.viaDirect;
    final text = [
      'Fluxora',
      '${appLocalizations.stLatency} ${p.latencyMs}ms · '
          '${appLocalizations.stJitter} ${p.jitterMs}ms',
      '${appLocalizations.download} ${_fmt(p.downMbps)} ${_unitFor(p.downMbps)}',
      '${appLocalizations.upload} ${_fmt(p.upMbps)} ${_unitFor(p.upMbps)}',
      if (p.serverName.isNotEmpty) '${p.serverName} · $where',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      // 默认贴底会被底部导航栏挡住，改成浮起并抬高。
      SnackBar(
        content: Text(appLocalizations.stCopied),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final p = _progress;
    final target = p.headlineMbps;
    // 系统开了「减少动画」时补间必须归零（项目规范 §10.5）。
    final reduceMotion = MediaQuery.of(context).disableAnimations;

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
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: target),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
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
                          Text(
                            '${_unitFor(value)} / ${_scaleLabel(_scale)}',
                            style: context.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            _PhaseDots(phase: p.phase),
            if (_phaseText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _phaseText,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // 测速过程的形状：能看出稳不稳、有没有掉速。
            SizedBox(
              height: 56,
              child: RepaintBoundary(
                child: _history.length < 2
                    ? const SizedBox.shrink()
                    : LineChart(
                        points: _history,
                        color: scheme.primary,
                        gradient: true,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat(
                  context,
                  Icons.speed,
                  '${p.latencyMs}',
                  'ms',
                  sub: p.jitterMs > 0 ? '±${p.jitterMs}ms' : null,
                ),
                _stat(
                  context,
                  Icons.arrow_downward,
                  _fmt(p.downMbps),
                  _unitFor(p.downMbps),
                ),
                _stat(
                  context,
                  Icons.arrow_upward,
                  _fmt(p.upMbps),
                  _unitFor(p.upMbps),
                ),
              ],
            ),
            if (p.serverName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${p.serverName} · '
                  '${globalState.isStart ? appLocalizations.viaProxy : appLocalizations.viaDirect}',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
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
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _running ? null : _start,
                    child: Text(
                      p.isDone || p.isFailed
                          ? appLocalizations.retry
                          : appLocalizations.start,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: p.isDone ? _copy : null,
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(appLocalizations.stCopy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    IconData icon,
    String value,
    String unit, {
    String? sub,
  }) {
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
        if (sub != null)
          Text(
            sub,
            style: context.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
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
