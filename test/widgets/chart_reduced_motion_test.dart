import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/bar_chart.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Phase 00.6-F10-C — behavioural cover for the three chart entrance animations.
///
/// The observable is the painter, not the source text: every painter here keeps
/// its tween position in a public field (`entryProgress` / `progress`), so each
/// assertion reads the exact value production paints with.
///
/// `disableAnimations` is driven through the real platform dispatcher (same
/// approach as `super_grid_drag_handle_test.dart`), so `MediaQuery` picks it up
/// the way the OS switch does in production — no synthetic `MediaQuery` is
/// injected into the tree.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    globalState.appState = AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
  });

  // ── helpers ────────────────────────────────────────────────────────────────

  /// `globalState.theme` / `globalState.measure` are `late` globals that
  /// production fills in `ThemeManager`. `DonutChartPainter` reads them through
  /// `NumExt.ap` while painting, so they have to be seeded from inside the live
  /// tree — same pattern as `mobile_narrow_layout_test.dart`.
  Widget seedGlobals(Widget child) {
    return Builder(
      builder: (ctx) {
        globalState.theme = CommonTheme.of(ctx, 1.0);
        globalState.measure = Measure.of(ctx, 1.0);
        return child;
      },
    );
  }

  /// Flips the OS-level "reduce motion" flag for the next pump.
  void setReduceMotion(WidgetTester tester, bool value) {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: value);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
  }

  T painterOf<T extends CustomPainter>(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is T),
    );
    return paint.painter! as T;
  }

  final dataA = <DonutChartData>[
    const DonutChartData(value: 10, color: Color(0xFF1B5FC4)),
    const DonutChartData(value: 30, color: Color(0xFF006A63)),
  ];
  final dataB = <DonutChartData>[
    const DonutChartData(value: 25, color: Color(0xFF1B5FC4)),
    const DonutChartData(value: 5, color: Color(0xFF006A63)),
  ];

  Future<void> pumpDonut(WidgetTester tester, List<DonutChartData> data) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: seedGlobals(
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: DonutChart(data: data),
              ),
            ),
          ),
        ),
      ),
    );
  }

  final barsA = const <BarChartData>[
    BarChartData(value: 10, label: 'a'),
    BarChartData(value: 20, label: 'b'),
  ];
  final barsB = const <BarChartData>[
    BarChartData(value: 30, label: 'a'),
    BarChartData(value: 5, label: 'b'),
  ];

  Future<void> pumpBar(WidgetTester tester, List<BarChartData> data) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 120,
              child: BarChart(data: data),
            ),
          ),
        ),
      ),
    );
  }

  // ── DonutChart ─────────────────────────────────────────────────────────────

  group('DonutChart entrance', () {
    testWidgets('reduced motion paints the finished ring on the first frame', (
      tester,
    ) async {
      setReduceMotion(tester, true);

      await pumpDonut(tester, dataA);

      // `entryProgress` is what the painter multiplies the sweep angle by, so
      // 1.0 means the ring is already complete — no blank first frame.
      expect(painterOf<DonutChartPainter>(tester).entryProgress, 1.0);
    });

    testWidgets('without reduced motion the ring sweeps in over 600 ms', (
      tester,
    ) async {
      setReduceMotion(tester, false);

      await pumpDonut(tester, dataA);
      expect(painterOf<DonutChartPainter>(tester).entryProgress, 0.0);

      // Half way through the fixed 600 ms entrance.
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        painterOf<DonutChartPainter>(tester).entryProgress,
        inExclusiveRange(0.0, 1.0),
      );

      await tester.pumpAndSettle();
      expect(painterOf<DonutChartPainter>(tester).entryProgress, 1.0);
    });

    testWidgets('a mid-session switch finishes an in-flight entrance', (
      tester,
    ) async {
      setReduceMotion(tester, false);

      await pumpDonut(tester, dataA);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        painterOf<DonutChartPainter>(tester).entryProgress,
        inExclusiveRange(0.0, 1.0),
        reason:
            'the entrance must actually be running for this test to mean '
            'anything',
      );

      // Same tree, same State — only the accessibility flag changes, so this
      // exercises `didChangeDependencies` rather than a fresh `initState`.
      setReduceMotion(tester, true);
      await pumpDonut(tester, dataA);

      expect(painterOf<DonutChartPainter>(tester).entryProgress, 1.0);
    });

    testWidgets('data updates keep their own tween under reduced motion', (
      tester,
    ) async {
      setReduceMotion(tester, true);

      await pumpDonut(tester, dataA);
      expect(painterOf<DonutChartPainter>(tester).entryProgress, 1.0);

      // Only `_dataController` drives `progress`; the entrance controller must
      // not be involved here.
      await pumpDonut(tester, dataB);
      expect(
        painterOf<DonutChartPainter>(tester).progress,
        0.0,
        reason: 'a data change must restart the value tween, not snap to it',
      );

      await tester.pumpAndSettle();
      expect(painterOf<DonutChartPainter>(tester).progress, 1.0);
      expect(
        painterOf<DonutChartPainter>(tester).entryProgress,
        1.0,
        reason: 'a data update must not re-run the entrance',
      );
    });
  });

  // ── BarChart ───────────────────────────────────────────────────────────────

  group('BarChart entrance', () {
    testWidgets('reduced motion starts the bars at their final geometry', (
      tester,
    ) async {
      setReduceMotion(tester, true);

      await pumpBar(tester, barsA);

      expect(painterOf<BarChartPainter>(tester).progress, 1.0);
    });

    testWidgets('without reduced motion the entrance still runs', (
      tester,
    ) async {
      setReduceMotion(tester, false);

      await pumpBar(tester, barsA);
      expect(painterOf<BarChartPainter>(tester).progress, 0.0);

      await tester.pumpAndSettle();
      expect(painterOf<BarChartPainter>(tester).progress, 1.0);
    });

    testWidgets('data updates still animate the bars', (tester) async {
      // Reduce motion on: proves the value tween is *not* routed through the
      // reduced-motion branch — the entrance and the data update share one
      // controller, and only the entrance was meant to be collapsed.
      setReduceMotion(tester, true);

      await pumpBar(tester, barsA);
      expect(painterOf<BarChartPainter>(tester).progress, 1.0);

      await pumpBar(tester, barsB);
      expect(
        painterOf<BarChartPainter>(tester).progress,
        0.0,
        reason: '`didUpdateWidget` must still restart the tween',
      );

      await tester.pumpAndSettle();
      expect(painterOf<BarChartPainter>(tester).progress, 1.0);
    });
  });

  // ── LineChart ──────────────────────────────────────────────────────────────

  group('LineChart', () {
    Future<void> pumpLine(WidgetTester tester, List<Point> points) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 120,
                child: LineChart(
                  points: points,
                  color: const Color(0xFF006A63),
                  duration: const Duration(milliseconds: 200),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // LineChart has no entrance animation at all (the controller is created but
    // never started, and `prevPoints == points` on the first frame), so nothing
    // is asserted about an entrance. Only the data tween is pinned, to prove the
    // reduced-motion batch did not disturb it.
    testWidgets('data updates land immediately under reduced motion', (
      tester,
    ) async {
      setReduceMotion(tester, true);

      await pumpLine(tester, const [Point(0, 0), Point(1, 10)]);
      expect(painterOf<LineChartPainter>(tester).progress, 1.0);

      await pumpLine(tester, const [Point(0, 5), Point(1, 20)]);
      expect(
        painterOf<LineChartPainter>(tester).progress,
        1.0,
        reason: 'the real sample is visible immediately under reduced motion',
      );

      await tester.pumpAndSettle();
      expect(painterOf<LineChartPainter>(tester).progress, 1.0);
    });
  });

  // ── BarChart bar colour ────────────────────────────────────────────────────
  //
  // The bars used to be a hardcoded `Colors.blue` inside the painter, which made
  // the dashboard's only bar chart the one surface painting a non-brand hue.
  // These pin that the fill now follows the theme, and that an explicit override
  // still wins.

  group('BarChart bar colour', () {
    Future<ColorScheme> pumpBarThemed(
      WidgetTester tester, {
      Color? color,
    }) async {
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7C75FF));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 120,
                child: BarChart(data: barsA, color: color),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return scheme;
    }

    testWidgets('bars follow the theme primary, not Material blue', (
      tester,
    ) async {
      final scheme = await pumpBarThemed(tester);

      final painter = painterOf<BarChartPainter>(tester);
      expect(painter.color, scheme.primary);
      expect(
        painter.color,
        isNot(Colors.blue),
        reason: 'the hardcoded Material blue must be gone',
      );
    });

    testWidgets('an explicit colour wins over the theme', (tester) async {
      const explicit = Color(0xFFFF7043);

      await pumpBarThemed(tester, color: explicit);

      expect(painterOf<BarChartPainter>(tester).color, explicit);
    });
  });
}
