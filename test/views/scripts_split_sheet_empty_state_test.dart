import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Test-only: `path_provider` is a transitive dependency. Faking the platform
// instance is the only way to make `appPath` resolvable in a VM test — same
// pattern as the sibling B3–B5 empty-state suites.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/fluxora/fluxora.dart';
import 'package:fluxora/widgets/sheet.dart';

/// Phase 1C-2 B6 — the two split-sheet empty states in
/// `lib/views/profiles/scripts.dart`.
///
/// Targets: `_ScriptCustomOptionsSheet` and `_GroupSwitchOptionsSheet`. Both
/// empty branches (`keys.isEmpty`) rendered `NullStatus`; they now render
/// `FluxoraEmptyState(title: …, compact: true)` inside the sheet's
/// `Column > Expanded` slot (`AdaptiveSheetScaffold` body).
///
/// Why this file is a source contract + component test instead of the B3–B5
/// style "reach the production widget" pump: both sheets are private, and
/// their only entries are unreachable in a VM test —
/// * `showScriptCustomOptions` reads the script file and runs the native JS
///   runtime (`JavaScriptRuntimeManager.extractScriptOptions`);
/// * `showGroupSwitchOptions` loads the profile config through
///   `globalState.getProfileConfig` → `clashCore` → `ClashService`, whose
///   construction spawns the desktop core process (`Process.start`).
/// So group A pins the production wiring structurally (same pattern as
/// `chain_topology_pulse_test.dart`), and group B exercises the real component
/// inside the real `AdaptiveSheetScaffold` container to prove the compact
/// layout survives narrow / short / large-text constraints.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory appPathSandbox;

  setUpAll(() async {
    appPathSandbox = Directory.systemTemp.createTempSync('fluxora_empty_b6_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(appPathSandbox);
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  tearDownAll(() async {
    try {
      await appPathSandbox.delete(recursive: true);
    } catch (_) {
      // Best effort: the OS may still hold a handle on the temp dir.
    }
  });

  setUp(() {
    globalState.appState = AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.dark,
      requests: FixedList(0),
      version: 1,
      logs: FixedList(0),
      traffics: FixedList(0),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
  });

  /// `globalState.theme` / `globalState.measure` are `late` globals that
  /// production fills in `ThemeManager`; seeded from a `Builder` inside the
  /// live tree, same as the B3–B5 suites.
  Widget seedGlobals(Widget child) {
    return Builder(
      builder: (ctx) {
        globalState.theme = CommonTheme.of(ctx, 1.0);
        globalState.measure = Measure.of(ctx, 1.0);
        return child;
      },
    );
  }

  // ── A 组：源码契约 ────────────────────────────────────────────────────────
  // Both sheets are private and unreachable at runtime (see the file header),
  // so their migrated empty branches are pinned on the source itself.

  group('B6 source contract — scripts.dart split sheets', () {
    final src = File('lib/views/profiles/scripts.dart').readAsStringSync();

    String sheetSource(String startMarker, [String? endMarker]) {
      final from = src.indexOf(startMarker);
      if (from < 0) {
        throw StateError('marker not found: $startMarker');
      }
      final to = endMarker == null ? src.length : src.indexOf(endMarker, from);
      if (to <= from) {
        throw StateError('end marker not found after: $startMarker');
      }
      return src.substring(from, to);
    }

    final sheets = <String, String>{
      '_ScriptCustomOptionsSheet': sheetSource(
        'class _ScriptCustomOptionsSheet extends ConsumerStatefulWidget',
        'Future<void> showGroupSwitchOptions(',
      ),
      '_GroupSwitchOptionsSheet': sheetSource(
        'class _GroupSwitchOptionsSheet extends ConsumerStatefulWidget',
      ),
    };

    for (final entry in sheets.entries) {
      test('${entry.key} 空分支使用 FluxoraEmptyState(compact: true)', () {
        final sheet = entry.value;
        expect(
          'FluxoraEmptyState('.allMatches(sheet).length,
          1,
          reason: '${entry.key} 应有且仅有一个 FluxoraEmptyState 调用',
        );
        expect(
          sheet.contains('title: appLocalizations.noStatusAvailable'),
          isTrue,
          reason: '标题表达式必须原样保留',
        );
        expect(
          sheet.contains('compact: true'),
          isTrue,
          reason: '分屏面板空态必须使用 compact 模式',
        );
      });

      test('${entry.key} 不再包含 NullStatus 调用', () {
        expect(
          'NullStatus('.allMatches(entry.value).length,
          0,
          reason: '${entry.key} 空分支不得回退 NullStatus',
        );
      });
    }

    test('fluxora barrel import 存在', () {
      expect(
        src.contains("import 'package:fluxora/widgets/fluxora/fluxora.dart';"),
        isTrue,
      );
    });

    test('B8 已解除 B5 暂缓：ScriptsView 空态迁移后 scripts.dart 不含 NullStatus 调用', () {
      // B8 resolved the B5 deferral: the ScriptsView empty state (scripts.dart)
      // was migrated to FluxoraEmptyState; the file must contain zero
      // NullStatus calls.
      expect('NullStatus('.allMatches(src).length, 0);
    });
  });

  // ── B 组：组件运行时约束 ──────────────────────────────────────────────────
  // The real container: AdaptiveSheetScaffold(page) > body Column > Expanded,
  // i.e. the exact constraint chain the two sheets hand to the empty state.

  for (final size in const [Size(360, 640), Size(280, 560)]) {
    for (final textScale in const [1.0, 1.4]) {
      final scale = '${size.width}x${size.height} + ${textScale}x';

      testWidgets('compact 空态在 sheet Expanded 槽位内无溢出 @ $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.runAsync(() async {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: Builder(
                  builder: (ctx) => MediaQuery(
                    data: MediaQuery.of(
                      ctx,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: seedGlobals(
                      AdaptiveSheetScaffold(
                        type: SheetType.page,
                        title: appLocalizations.customScriptOptions,
                        body: Column(
                          children: [
                            Expanded(
                              child: FluxoraEmptyState(
                                title: appLocalizations.noStatusAvailable,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(FluxoraEmptyState), findsOneWidget);

        // compact: true is actually in effect — the root padding is
        // FluxoraSpacing.md (12), not the non-compact pagePadding (16).
        final padding = tester.widget<Padding>(
          find.descendant(
            of: find.byType(FluxoraEmptyState),
            matching: find.byType(Padding),
          ),
        );
        expect(padding.padding, const EdgeInsets.all(12));

        // The title expression reaches the user as rendered text.
        final titleFinder = find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText() == appLocalizations.noStatusAvailable,
        );
        expect(titleFinder, findsOneWidget);

        // The rendered title stays a single compact line even at 1.4x (14px
        // body × 1.4 ≈ 28px), so the content never grows toward the slot
        // height and nothing can overflow.
        final titleSize = tester.getSize(titleFinder);
        expect(
          titleSize.height,
          lessThan(40),
          reason: '标题必须保持单行紧凑高度',
        );
      });
    }
  }
}

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform(this.dir);

  final Directory dir;

  @override
  Future<String?> getTemporaryPath() async => dir.path;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;

  @override
  Future<String?> getLibraryPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getExternalStoragePath() async => dir.path;

  @override
  Future<List<String>?> getExternalCachePaths() async => [dir.path];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [dir.path];

  @override
  Future<String?> getDownloadsPath() async => dir.path;
}
