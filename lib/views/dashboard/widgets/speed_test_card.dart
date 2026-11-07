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
  bool _pollInFlight = false;
  int _generation = 0;
  int _sampleIndex = 0;

  /// 曲线只画最近这些帧：300ms 一帧，40 帧约 12 秒，正好覆盖一轮测速。
  static const _historyLimit = 40;
  final List<Point> _history = [];

  double _scale = 100;
  double _peak = 0;

  @override
  void initState() {
    super.initState();
    // 只在真的有测速在跑时才轮询。以前这里无条件起了一个 300ms 定时器，
    // 等于仪表盘开着的时候每秒向内核桥接问 3 次「测完了吗」——空转的唤醒
    // 对续航是纯损耗，而空闲时那些返回值也不会变。
    _syncOnce();
  }

  /// 进页面时读一次状态：可能上一次测速还在跑（比如从别的页切回来），
  /// 这时才需要继续轮询。
  Future<void> _syncOnce() async {
    if (!mounted) return;
    final generation = _generation;
    try {
      final p = await clashCore.speedTestStatus();
      if (!mounted || generation != _generation) return;
      _applyProgress(p);
      if (p.isRunning) _startPolling();
    } catch (error) {
      if (mounted && generation == _generation) {
        _applyProgress(SpeedTestProgress(phase: 'failed', error: '$error'));
      }
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      if (!mounted || _pollInFlight) return;
      final generation = _generation;
      _pollInFlight = true;
      try {
        final p = await clashCore.speedTestStatus();
        if (!mounted || generation != _generation) return;
        _applyProgress(p);
        if (p.isDone || p.isFailed || (!p.isRunning && _gotFrame)) {
          _poll?.cancel();
          _poll = null;
        }
      } catch (error) {
        if (mounted && generation == _generation) {
          _poll?.cancel();
          _applyProgress(SpeedTestProgress(phase: 'failed', error: '$error'));
        }
      } finally {
        _pollInFlight = false;
      }
    });
  }

  void _applyProgress(SpeedTestProgress p) {
    if (_running && !_gotFrame && p.phase == 'idle') return;
    if (p.phase != 'idle') {
      _gotFrame = true;
      _watchdog?.cancel();
    }
    setState(() {
      _progress = p;
      if (p.headlineMbps > _peak) _peak = p.headlineMbps;
      _scale = _scaleFor(_peak);
      if (p.isRunning && p.headlineMbps > 0) {
        _history.add(Point((_sampleIndex++).toDouble(), p.headlineMbps));
        if (_history.length > _historyLimit) _history.removeAt(0);
      }
      if (p.isRunning) _running = true;
      if (p.isDone || p.isFailed) _running = false;
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_running) return;
    final generation = ++_generation;
    setState(() {
      _running = true;
      _gotFrame = false;
      _history.clear();
      _sampleIndex = 0;
      _peak = 0;
      _scale = 100;
      _progress = const SpeedTestProgress(phase: 'latency');
    });
    // 12 秒：选源要查出口位置、拉服务器列表、探节点、拉 32KB 验证，3 秒会误报。
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 12), () {
      if (!mounted || _gotFrame || generation != _generation) return;
      _poll?.cancel();
      _poll = null;
      setState(() {
        _running = false;
        _progress = const SpeedTestProgress(
          phase: 'failed',
          error: '内核没有响应测速请求',
        );
      });
    });
    // 测速一开始才起轮询，结束就停——空闲时不该有定时器在跑。
    _startPolling();
    try {
      await globalState.appController.speedTest();
    } catch (e) {
      if (!mounted || generation != _generation) return;
      _poll?.cancel();
      _poll = null;
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
    final where = Localizations.localeOf(context).languageCode == 'zh'
        ? '内核路由'
        : 'Core routing';
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
    final motion = FluxoraMotion.ofContext(context);
    final measured = _gotFrame && (p.headlineMbps > 0 || p.isDone);
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final screen = MediaQuery.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: FluxoraMaterial.of(context).enabled
          ? Colors.transparent
          : scheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: (screen.size.height - screen.viewInsets.vertical - 48)
              .clamp(120, 760),
        ),
        child: GlassSurface(
          radius: FluxoraRadius.dialog,
          floating: true,
          blur: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (screen.textScaler.scale(1) < 1.6) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: FluxoraRadius.lgAll,
                        ),
                        child: Icon(
                          Icons.speed_rounded,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        chinese ? '网络测速' : 'Speed test',
                        style: context.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('speed-test-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: _running
                          ? (chinese ? '关闭面板，测速继续' : 'Close; test continues')
                          : appLocalizations.close,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: target),
                  duration: motion.slow,
                  curve: FluxoraMotion.standard,
                  builder: (context, value, _) => SizedBox(
                    width: 196,
                    height: 196,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(196, 196),
                          painter: _ArcPainter(
                            progress: (value / _scale).clamp(0, 1),
                            color: scheme.primary,
                            track: scheme.outlineVariant.withValues(alpha: .5),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              measured ? _fmt(target) : '—',
                              style: context.textTheme.displaySmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              measured
                                  ? _unitFor(target)
                                  : appLocalizations.networkSpeed,
                              style: context.textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _PhaseDots(phase: p.phase),
                const SizedBox(height: 8),
                Text(
                  _phaseText.isEmpty ? (chinese ? '就绪' : 'Ready') : _phaseText,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (final metric in [
                      (
                        Icons.speed_rounded,
                        p.latencyMs > 0 ? '${p.latencyMs}' : '—',
                        'ms',
                      ),
                      (
                        Icons.south_rounded,
                        measured ? _fmt(p.downMbps) : '—',
                        _unitFor(p.downMbps),
                      ),
                      (
                        Icons.north_rounded,
                        p.upMbps > 0 || p.isDone ? _fmt(p.upMbps) : '—',
                        _unitFor(p.upMbps),
                      ),
                    ])
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: FluxoraRadius.lgAll,
                          ),
                          child: _stat(
                            context,
                            metric.$1,
                            metric.$2,
                            metric.$3,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_history.length >= 2) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 64,
                    child: RepaintBoundary(
                      child: LineChart(
                        points: List.of(_history),
                        color: scheme.primary,
                        gradient: true,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (p.serverName.isNotEmpty)
                  Text(
                    '${p.serverName} · ${chinese ? '内核路由' : 'Core routing'}',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall,
                  ),
                if (p.isFailed && p.error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      p.error!,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('speed-test-start'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(160, 48),
                      ),
                      onPressed: _running ? null : _start,
                      icon: Icon(
                        _running
                            ? Icons.hourglass_top_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        _running
                            ? (chinese ? '测速中' : 'Testing')
                            : p.isDone || p.isFailed
                            ? appLocalizations.retry
                            : appLocalizations.start,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: p.isDone ? _copy : null,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(appLocalizations.stCopy),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
      old.progress != progress || old.color != color || old.track != track;
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
