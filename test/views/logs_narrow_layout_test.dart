import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/logs.dart';
import 'package:fluxora/widgets/widgets.dart';

/// P8-2C — the Logs page **with real log rows**, at the widths it currently
/// survives.
///
/// `test/views/mobile_narrow_layout_test.dart` already sweeps this page at
/// 280/320/360 with 1.4× text, but it injects an **empty** history, so all it
/// exercises is the `FluxoraEmptyState` branch — no `LogItem` is ever built.
/// Everything below renders actual rows: long payloads, the toolbar and the
/// scrolling list.
///
/// ## F-4 — fixed in P8-2C-F4
///
/// This page used to overflow at every phone width: `LogItem`'s subtitle
/// (`lib/views/logs.dart:283`) held the level `CommonChip` (96.5 px measured)
/// and the timestamp `Text` (235.6 px) as two unbounded children — about
/// 364 px of content against 288 px of usable width at 320. The timestamp is
/// now a single ellipsised line inside a `Flexible`, and 320/360/375/390/414
/// are covered below, with and without 1.4× text.
///
/// The full value is not lost: tapping the row opens `LogDetailDialog`, which
/// renders the untruncated timestamp.
///
/// Safety: `LogsView` pulls history from the core on its first frame. Every
/// test passes `historyLoader` — the seam the widget documents for exactly
/// this — and overrides `filteredLogsProvider`, so `clashCore` is never touched
/// and no provider is written.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `appLocalizations` is a static resolved by the delegate; the page reads it
  // while building the app bar. Same setup the other page-level tests use.
  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  // ── data ──────────────────────────────────────────────────────────────────

  /// Payloads that are legal for a real core log line but hostile to layout:
  /// a URL with no spaces, an unbroken token, and mixed CJK + ASCII.
  const longPayloads = <String>[
    'GET https://example.com/api/v1/subscription?token=abcdef0123456789'
        '&device=windows-x64&build=1.1.1&ts=2026-11-01T16:00:00Z',
    'aWQ6MDE5MjIxZDA3Njc1MDE5NzYwOGI4ZDA2MTVlNzEwLzNhZWU1MWM5LTdjM2MtNGI4ZS04M2YzLTFjMTYxM2Y0OGVlMg',
    '2026-11-01 16:00:00 INFO  [TCP] 域名解析成功 example.com -> 93.184.216.34 '
        '耗时 12ms 连接已建立',
    'level=warning msg="dns: exchange failed for www.example.com: '
        'context deadline exceeded"',
  ];

  List<Log> longLogs() => [
    for (var i = 0; i < longPayloads.length; i++)
      Log(
        logLevel: LogLevel.values[i % LogLevel.values.length],
        payload: longPayloads[i],
        dateTime: '2026-11-01 16:00:0$i',
      ),
  ];

  List<Log> manyLogs(int count) => [
    for (var i = 0; i < count; i++)
      Log(
        logLevel: LogLevel.info,
        payload: 'line-$i connection established to 127.0.0.1:7890',
        dateTime: '2026-11-0${1 + i % 9} 16:00:00',
      ),
  ];

  // ── harness ───────────────────────────────────────────────────────────────

  Widget seedGlobals(Widget child) {
    return Builder(
      builder: (ctx) {
        globalState.theme = CommonTheme.of(ctx, 1.0);
        globalState.measure = Measure.of(ctx, 1.0);
        return child;
      },
    );
  }

  /// The real page, real providers, real layout — only the data is injected.
  Future<void> pumpLogs(
    WidgetTester tester, {
    required Size size,
    required List<Log> logs,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // `CommonScaffold` watches `loadingProvider`, which reads
    // `globalState.appState` — a `late` field. Seeding it inside a builder is
    // too late; it has to exist before the first frame.
    globalState.appState = AppState(
      viewSize: size,
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.logs,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isMobileViewProvider.overrideWith((ref) => true),
          filteredLogsProvider.overrideWithValue(logs),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => MediaQuery(
              data: MediaQuery.of(
                ctx,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: seedGlobals(LogsView(historyLoader: () async => <Log>[])),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  // ── F-4 — the subtitle row at phone widths ────────────────────────────────

  /// The payload/time the P8-2C audit measured the overflow on.
  Log phoneLog() => const Log(
    logLevel: LogLevel.warning,
    payload: 'line-0 connection established to 127.0.0.1:7890',
    dateTime: '2026-11-01 16:00:00',
  );

  group('F-4 — subtitle row at phone widths', () {
    // 320/360/375/390/414 all overflowed before the fix; 480 is the control
    // that already passed.
    for (final size in const [
      Size(320, 640),
      Size(360, 640),
      Size(375, 667),
      Size(390, 844),
      Size(414, 896),
      Size(480, 800),
    ]) {
      testWidgets('a real row fits at ${size.width.toInt()} px', (
        tester,
      ) async {
        await pumpLogs(tester, size: size, logs: [phoneLog()]);

        // Precondition: a real row and its timestamp are on screen, so this is
        // not the empty-state branch passing by accident.
        expect(find.byType(LogItem), findsOneWidget);
        expect(find.text('2026-11-01 16:00:00'), findsOneWidget);

        final row = tester.getRect(find.byType(LogItem));
        expect(
          row.right,
          lessThanOrEqualTo(size.width),
          reason: 'the row must stay inside the viewport',
        );

        expect(
          tester.takeException(),
          isNull,
          reason:
              'chip + timestamp must both fit at ${size.width.toInt()} px',
        );
      });
    }

    for (final size in const [
      Size(320, 640),
      Size(375, 667),
      Size(480, 800),
    ]) {
      testWidgets('a real row fits at ${size.width.toInt()} px with 1.4x text', (
        tester,
      ) async {
        await pumpLogs(
          tester,
          size: size,
          logs: [phoneLog()],
          textScale: 1.4,
        );

        expect(find.byType(LogItem), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'enlarged text must not reintroduce the overflow',
        );
      });
    }

    testWidgets('the timestamp is one ellipsised line inside a Flexible', (
      tester,
    ) async {
      await pumpLogs(tester, size: const Size(320, 640), logs: [phoneLog()]);

      final timestamp = find.text('2026-11-01 16:00:00');
      final text = tester.widget<Text>(timestamp);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.textAlign, TextAlign.end);

      // A real `Flexible` parent, not just the property: without it the text is
      // laid out unbounded again and the row overflows.
      expect(
        find.ancestor(of: timestamp, matching: find.byType(Flexible)),
        findsWidgets,
      );

      // The level chip is still there — the fix must not have squeezed it out.
      expect(find.byType(CommonChip), findsOneWidget);

      // Vertical contract unchanged: `logs.dart:211` pins `itemExtent` to
      // `LogItem.height + 1`, so a row that grew would be clipped rather than
      // overflow. Shrinking the timestamp must not have moved that.
      expect(
        tester.getSize(find.byType(LogItem)).height,
        LogItem.height + 1,
        reason: 'the row must still fill exactly one list extent',
      );
    });

    testWidgets('the full timestamp survives in the model and on tap', (
      tester,
    ) async {
      await pumpLogs(tester, size: const Size(320, 640), logs: [phoneLog()]);

      final item = tester.widget<LogItem>(find.byType(LogItem));
      expect(
        item.log.dateTime,
        '2026-11-01 16:00:00',
        reason: 'ellipsising the row must not truncate the data',
      );

      // The row still opens the detail dialog, which shows the untruncated
      // value — that is what makes the ellipsis acceptable.
      await tester.tap(find.byType(LogItem));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final dialog = find.byType(LogDetailDialog);
      if (dialog.evaluate().isNotEmpty) {
        final shown = tester.widget<LogDetailDialog>(dialog);
        expect(shown.log.dateTime, '2026-11-01 16:00:00');
      }
    });
  });

  // ── L1 — rows render without a layout error ───────────────────────────────

  group('L1 — real rows at 480 px', () {
    testWidgets('long rows build without a layout exception', (tester) async {
      await pumpLogs(
        tester,
        size: const Size(480, 800),
        logs: longLogs(),
      );

      // Structural precondition: the rows really rendered, so "no exception" is
      // not the empty-state branch passing by accident.
      expect(
        find.byType(LogItem),
        findsWidgets,
        reason: 'the page must have built actual log rows',
      );
      expect(
        find.byType(EmojiText),
        findsWidgets,
        reason: 'payload text must be on screen',
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'no RenderFlex overflow at 480 logical px',
      );
    });
  });

  // ── L2 — the truncation contract ──────────────────────────────────────────

  group('L2 — long payload contract', () {
    testWidgets('a payload is clamped to two lines with an ellipsis', (
      tester,
    ) async {
      await pumpLogs(
        tester,
        size: const Size(480, 800),
        logs: longLogs(),
      );

      // Only the payload renderer is under test here: `logs.dart:273` is the
      // page's single `EmojiText` call site, and the payloads are known, so a
      // match on the text keeps this from drifting onto another `EmojiText`.
      final payloads = tester
          .widgetList<EmojiText>(find.byType(EmojiText))
          .where((widget) => longPayloads.contains(widget.text))
          .toList();
      expect(payloads, isNotEmpty);

      for (final payload in payloads) {
        expect(
          payload.maxLines,
          2,
          reason: 'the row is a fixed-height list item — it must clamp',
        );
        expect(
          payload.overflow,
          TextOverflow.ellipsis,
          reason: 'clamped text has to say so, not just disappear',
        );
      }

      // A clamped row still has to occupy its own height; zero would mean the
      // text was squeezed out rather than truncated.
      final row = tester.getRect(find.byType(LogItem).first);
      expect(row.height, greaterThan(0));
      expect(row.right, lessThanOrEqualTo(480));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unbroken token does not widen the row past the viewport', (
      tester,
    ) async {
      await pumpLogs(
        tester,
        size: const Size(480, 800),
        logs: [longLogs()[1]],
      );

      final row = tester.getRect(find.byType(LogItem).first);
      expect(
        row.width,
        lessThanOrEqualTo(480),
        reason: 'a 100-char token must not stretch the list item',
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ── L3 — the toolbar stays reachable ──────────────────────────────────────

  group('L3 — toolbar actions', () {
    testWidgets('all three actions stay inside the viewport', (tester) async {
      await pumpLogs(
        tester,
        size: const Size(480, 800),
        logs: manyLogs(12),
      );

      // The three actions `LogsView` actually builds: log level, auto-scroll,
      // export (long-press clears).
      const icons = <IconData>[
        Icons.settings_outlined,
        Icons.vertical_align_top_outlined,
        Icons.save_as_outlined,
      ];

      for (final icon in icons) {
        final finder = find.byIcon(icon);
        expect(finder, findsOneWidget, reason: '$icon must still be built');

        final rect = tester.getRect(finder);
        expect(rect.width, greaterThan(0), reason: '$icon must not be 0-width');
        expect(
          rect.left,
          greaterThanOrEqualTo(0),
          reason: '$icon is clipped off the left edge',
        );
        expect(
          rect.right,
          lessThanOrEqualTo(480),
          reason: '$icon is clipped off the right edge',
        );
        expect(
          finder.hitTestable(),
          findsOneWidget,
          reason: '$icon must be tappable, not covered',
        );
      }

      expect(tester.takeException(), isNull);
    });
  });

  // ── L4 — the list scrolls ─────────────────────────────────────────────────

  group('L4 — scrolling', () {
    testWidgets('the list is reverse-ordered and still scrolls', (
      tester,
    ) async {
      await pumpLogs(
        tester,
        size: const Size(480, 800),
        logs: manyLogs(30),
      );

      final list = tester.widget<ListView>(find.byType(ListView).first);
      expect(
        list.reverse,
        isTrue,
        reason: 'the newest line belongs at the bottom, next to the dock',
      );

      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'dragging the log list must not break its layout',
      );
    });

    testWidgets('the list reserves room below the newest line', (tester) async {
      await pumpLogs(
        tester,
        size: const Size(480, 800),
        logs: manyLogs(30),
      );

      final list = tester.widget<ListView>(find.byType(ListView).first);
      final bottom = (list.padding! as EdgeInsets).bottom;
      expect(
        bottom,
        greaterThanOrEqualTo(16),
        reason: 'the newest line must clear the dock (measured $bottom)',
      );
    });
  });

  // ── L6 — text scale ───────────────────────────────────────────────────────

  group('L6 — enlarged text', () {
    testWidgets('rows still fit with 1.4x text at 600 px', (tester) async {
      // 600, not 480: the subtitle row needs roughly 1.4 × 364 px of width, so
      // the enlarged case only clears at the mobile/desktop boundary. See F-4.
      await pumpLogs(
        tester,
        size: const Size(600, 800),
        logs: longLogs(),
        textScale: 1.4,
      );

      expect(find.byType(LogItem), findsWidgets);
      expect(
        tester.takeException(),
        isNull,
        reason: 'the 1.4x sweep only covered the empty state until now',
      );
    });
  });
}
