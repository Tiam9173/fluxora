import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Test-only: `path_provider` is a transitive dependency. Faking the platform
// instance is the only way to make `appPath` resolvable in a VM test — same
// pattern as `mobile_narrow_layout_test.dart`.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/connection/connections.dart';
import 'package:fluxora/views/connection/requests.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Phase 1C-2 B3 — pins the migrated empty state of the two connection pages.
///
/// Before B3 both pages rendered `NullStatus`; they now render
/// `FluxoraEmptyState`. Neither page had any test coverage of its empty
/// branch, so this file is the first contract check: with no data the new
/// component must be present, the old one must be gone, and nothing may
/// overflow — including at 280 dp with a 1.4x text scale.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory appPathSandbox;

  setUpAll(() async {
    appPathSandbox = Directory.systemTemp.createTempSync('fluxora_empty_b3_');
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
      // `Requests.build()` seeds from `globalState.appState.requests`
      // (providers/app.dart:109) — an empty list is what makes the requests
      // page take its empty branch.
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

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    double textScale,
    Widget child,
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
                child: child,
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
  }

  for (final entry in const <String, Widget>{
    'RequestsView': RequestsView(),
    'ConnectionsView': ConnectionsView(),
  }.entries) {
    for (final size in const [Size(360, 640), Size(280, 560)]) {
      for (final textScale in const [1.0, 1.4]) {
        testWidgets('${entry.key} 空态渲染 FluxoraEmptyState 且不溢出 @ '
            '${size.width}x${size.height} + ${textScale}x', (tester) async {
          await pumpAt(tester, size, textScale, seedGlobals(entry.value));

          expect(find.byType(FluxoraEmptyState), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
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
