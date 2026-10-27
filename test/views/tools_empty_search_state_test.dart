import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Test-only: `path_provider` is a transitive dependency. Faking the platform
// instance is the only way to make `appPath` resolvable in a VM test. Same
// pattern as `mobile_narrow_layout_test.dart`.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/tools.dart';
import 'package:fluxora/widgets/fluxora/fluxora.dart';

/// Phase 1C-2 B2 — `tools.dart` search empty-state branch.
///
/// `_buildSearchResults` returns a single list item when the query matches
/// nothing; B2 replaced its `NullStatus` with `FluxoraEmptyState`. These cases
/// pin that branch only: the item must render without exception inside the
/// `ListView.builder` (unbounded item height) at a normal configuration and at
/// a narrow size with 1.4x text scale.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// `globalState` is a process-wide singleton: without a per-test reset the
  /// second case would reuse the first case's (now unmounted) ref.
  bool controllerBound = false;

  late Directory appPathSandbox;

  setUpAll(() async {
    appPathSandbox = Directory.systemTemp.createTempSync(
      'fluxora_tools_empty_',
    );
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
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
  });

  /// `globalState.theme` / `globalState.measure` are `late` globals that
  /// production fills in `ThemeManager`; seeded from a `Builder` inside the
  /// live tree, same as `mobile_narrow_layout_test.dart`.
  Widget seedGlobals(Widget child) {
    return Builder(
      builder: (ctx) {
        globalState.theme = CommonTheme.of(ctx, 1.0);
        globalState.measure = Measure.of(ctx, 1.0);
        return child;
      },
    );
  }

  Future<void> pumpTools(
    WidgetTester tester,
    Size size,
    double textScale,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (ctx, ref, _) {
                // Entering search mode mounts `SystemBackBlock`, whose
                // initState / dispose read `globalState.appController`.
                // Production binds it in `application.dart`; bind once per test
                // (same pattern as `application_lifecycle_guard_test.dart`).
                if (!controllerBound) {
                  controllerBound = true;
                  globalState.appController = AppController(ctx, ref);
                }
                return Builder(
                  builder: (ctx) => MediaQuery(
                    data: MediaQuery.of(
                      ctx,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: seedGlobals(const ToolsView()),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
  }

  for (final (size, textScale) in const [
    (Size(360, 640), 1.0),
    (Size(280, 560), 1.4),
  ]) {
    testWidgets(
      'ToolsView no-match search renders FluxoraEmptyState without overflow '
      '@ ${size.width}x${size.height} + ${textScale}x',
      (tester) async {
        controllerBound = false;
        await pumpTools(tester, size, textScale);

        // Enter search mode through the app-bar action, then type a query
        // that matches none of the search items.
        await tester.tap(find.byIcon(Icons.search));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'zzz_no_match_zzzz');

        // `_onSearchChanged` debounces the query by 500ms.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        expect(find.byType(FluxoraEmptyState), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Leave search mode inside the test body. The binding's post-test
        // `runApp(Container())` unmounts `SystemBackBlock`, whose dispose
        // callback reads `globalState.appController` — while the tree (and the
        // controller's ref) is still alive that is safe.
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();

        expect(find.byType(FluxoraEmptyState), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
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
