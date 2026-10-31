import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/widgets/fluxora/fluxora_latency_badge.dart';
import 'package:fluxora/widgets/fluxora/fluxora_status.dart';

/// Phase 03.7 收尾：页面层把 `outline`（Lines 角色）当中性文字色用。
///
/// 第 38 轮在共享组件里修了同一类缺陷（`FluxoraStatus` / `FluxoraLatencyBadge`），
/// 当时登记了 3 个页面文件里的 9 处。本轮逐点核对后实际是 **12 处**：10 处是
/// 文字或与文字并排的图标（改 `onSurfaceVariant`），1 处是刻意淡出的装饰插图
/// （`profile_nodes_view.dart` 空状态 64 px 图标，`outline @ 0.5`，保留），
/// 1 处（`chain_proxy_view:2242`）是第 38 轮漏记的说明文字。
///
/// 为什么这里用静态扫描而不是挂载整页：
///
/// * `CoreStatusDialog.initState` 直接 `await clashCore.getCoreStatus()`
///   （`core_status_dialog.dart:46`）—— 真实平台调用，挂载即触发内核。
/// * `chain_proxy_view` / `profile_nodes_view` 依赖真实 chain / profile 状态，
///   第 28、30 轮已证 shell harness 在这类页面上会造出假象。
///
/// 所以守卫针对**真实生产源码**（不是手工构造的颜色值），运行时部分则验证
/// `onSurfaceVariant` 在这些页面**实际绘制**的表面上的对比度。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The three files the audit covered.
  const audited = <String, String>{
    'lib/views/proxies/chain_proxy_view.dart': 'chain proxy page',
    'lib/views/dashboard/widgets/core_status_dialog.dart': 'core status dialog',
    'lib/views/profiles/profile_nodes_view.dart': 'profile nodes view',
  };

  /// A bare `colorScheme.outline` in a paint position is the defect. The single
  /// deliberate exception is the faded empty-state illustration, which is
  /// decoration rather than content — pinned by shape, not by line number, so
  /// moving it does not silently widen the allow-list.
  const decorativeAllowList = <String>{
    'lib/views/profiles/profile_nodes_view.dart',
  };

  group('the line role is not used as a foreground colour', () {
    test('no page paints text or icons with `colorScheme.outline`', () {
      final violations = <String>[];

      for (final path in audited.keys) {
        final lines = File(path).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!line.contains('colorScheme.outline')) continue;
          if (line.contains('outlineVariant')) continue;

          // The allow-listed shape: a deliberately faded decorative glyph.
          final faded = line.contains('.withValues(alpha:');
          if (faded && decorativeAllowList.contains(path)) continue;

          violations.add('$path:${i + 1}: ${line.trim()}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            '`FluxoraColorSet.outline` is the Lines role (#334155 / #CBD5E1) — '
            '1.1–1.7:1 on every card surface. Use `onSurfaceVariant` for muted '
            'foreground, or `.withValues(alpha:)` if the glyph is decoration.',
      );
    });

    test('the allow-list has exactly one entry', () {
      // A second entry should be a deliberate decision with a reason, not a
      // quiet way to silence the guard.
      expect(decorativeAllowList, hasLength(1));
    });

    test('the allow-listed glyph really is a faded decorative icon', () {
      // Verifies the exception is what it claims to be, so the guard cannot be
      // satisfied by an unrelated `withValues` on a text colour.
      final lines = File(
        'lib/views/profiles/profile_nodes_view.dart',
      ).readAsLinesSync();
      final index = lines.indexWhere(
        (l) => l.contains('colorScheme.outline') && !l.contains('outlineVariant'),
      );
      expect(index, greaterThan(0), reason: 'the exception should still exist');

      final above = lines.sublist(index - 4 < 0 ? 0 : index - 4, index).join('\n');
      expect(above, contains('Icon('));
      expect(above, contains('size: 64'));
      expect(lines[index], contains('.withValues(alpha: 0.5)'));
    });

    test('borders still use the Lines roles', () {
      // The point of the round is to keep `outline` / `outlineVariant` for
      // lines — so the fix must not have removed them from borders too.
      var borderUses = 0;
      for (final path in audited.keys) {
        final text = File(path).readAsStringSync();
        borderUses += 'BorderSide('.allMatches(text).length;
        borderUses += 'Border.all('.allMatches(text).length;
      }
      expect(
        borderUses,
        greaterThan(0),
        reason: 'these pages still draw borders',
      );

      final variantUses = audited.keys
          .map((p) => 'outlineVariant'.allMatches(File(p).readAsStringSync()).length)
          .fold<int>(0, (a, b) => a + b);
      expect(
        variantUses,
        greaterThanOrEqualTo(6),
        reason: 'the six divider/border uses of `outlineVariant` are untouched',
      );
    });
  });

  group('onSurfaceVariant clears AA on the surfaces these pages paint', () {
    ColorScheme schemeFor(Brightness brightness) {
      final container = ProviderContainer(
        overrides: [
          themeSettingProvider.overrideWith(
            () => _MockThemeSetting(
              ThemeProps(colorSource: ColorSource.fluxora),
            ),
          ),
        ],
      );
      // Synchronous dispose: the binding asserts `!timersPending` before
      // tear-downs run (same trap as an undisposed `SemanticsHandle`).
      try {
        return container.read(genColorSchemeProvider(brightness));
      } finally {
        container.dispose();
      }
    }

    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }

    for (final brightness in Brightness.values) {
      test('every surface these three pages draw on ($brightness)', () {
        final s = schemeFor(brightness);

        // Page background, plain card, filled card / toolbar, M3 dialog
        // surface, and the selected-card wash. These are the five planes the
        // audited call sites actually sit on.
        final surfaces = <String, Color>{
          'surface': s.surface,
          'surfaceContainerLow': s.surfaceContainerLow,
          'surfaceContainer': s.surfaceContainer,
          'surfaceContainerHigh': s.surfaceContainerHigh,
          'secondaryContainer': s.secondaryContainer,
        };

        for (final entry in surfaces.entries) {
          expect(
            contrast(s.onSurfaceVariant, entry.value),
            greaterThanOrEqualTo(4.5),
            reason:
                'onSurfaceVariant on ${entry.key} / $brightness is '
                '${contrast(s.onSurfaceVariant, entry.value).toStringAsFixed(2)}:1',
          );
        }
      });

      test('the line role would not have passed ($brightness)', () {
        // Quantifies why the swap was necessary rather than cosmetic. This is
        // the number quoted in the report; if the palette ever changes so that
        // `outline` is legible, this assertion starts failing and the whole
        // premise should be re-examined.
        final s = schemeFor(brightness);
        final line = FluxoraColorSet.of(brightness).outline;
        expect(
          contrast(line, s.surfaceContainerLow),
          lessThan(3.0),
          reason: '`outline` is a border tone, not a foreground tone',
        );
      });
    }
  });

  group('the shared components fixed in round 38 did not regress', () {
    testWidgets('FluxoraStatus neutral states stay on onSurfaceVariant', (
      tester,
    ) async {
      final s = schemeForDark();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: s),
          home: const Scaffold(
            body: FluxoraStatus(status: FluxoraStatusKind.unknown),
          ),
        ),
      );
      final ctx = tester.element(find.byType(FluxoraStatus));
      expect(
        FluxoraStatus.colorOf(ctx, FluxoraStatusKind.unknown),
        s.onSurfaceVariant,
      );
      expect(
        FluxoraStatus.colorOf(ctx, FluxoraStatusKind.disconnected),
        s.onSurfaceVariant,
      );
    });

    testWidgets('FluxoraLatencyBadge untested stays on onSurfaceVariant', (
      tester,
    ) async {
      final s = schemeForDark();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: s),
          home: const Scaffold(body: FluxoraLatencyBadge(delay: null)),
        ),
      );
      final ctx = tester.element(find.byType(FluxoraLatencyBadge));
      expect(
        FluxoraLatencyBadge.colorOf(ctx, FluxoraLatencyTier.untested),
        s.onSurfaceVariant,
      );
    });
  });
}

ColorScheme schemeForDark() {
  final container = ProviderContainer(
    overrides: [
      themeSettingProvider.overrideWith(
        () => _MockThemeSetting(
          ThemeProps(colorSource: ColorSource.fluxora),
        ),
      ),
    ],
  );
  try {
    return container.read(genColorSchemeProvider(Brightness.dark));
  } finally {
    container.dispose();
  }
}

class _MockThemeSetting extends ThemeSetting {
  _MockThemeSetting(this._props);

  ThemeProps _props;

  @override
  ThemeProps build() => _props;

  @override
  void updateState(ThemeProps Function(ThemeProps state) builder) {
    _props = builder(_props);
    state = _props;
  }

  @override
  void onUpdate(ThemeProps value) => _props = value;
}
