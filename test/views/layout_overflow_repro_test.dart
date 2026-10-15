import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Test-only: both are transitive dependencies of `path_provider`. Faking the
// platform instance is the only way to make `appPath` resolvable in a VM test
// (the default `getDownloadsPath()` throws before any channel mock can answer).
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/chain_proxy.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/dashboard/widgets/connections_count.dart';
import 'package:fluxora/views/dashboard/widgets/fcm_status.dart';
import 'package:fluxora/views/dashboard/widgets/intranet_ip.dart';
import 'package:fluxora/views/dashboard/widgets/media_unlock_small.dart';
import 'package:fluxora/views/dashboard/widgets/providers_info.dart';
import 'package:fluxora/views/config/sniffer.dart';
import 'package:fluxora/views/profiles/add_profile.dart';
import 'package:fluxora/views/profiles/override_profile.dart';
import 'package:fluxora/views/profiles/profile_chain_dialog.dart';
import 'package:fluxora/views/profiles/profile_nodes_view.dart';
import 'package:fluxora/views/proxies/chain_proxy_view.dart';
import 'package:fluxora/views/proxies/chain_support_confirm_dialog.dart';

/// RC.7 — layout overflow **reproduction** harness.
///
/// The RC.7 brief is explicit: a fixed size or a `Row` without `Expanded` in the
/// source is a *candidate*, not a defect. Only a widget that actually overflows
/// counts. This file pumps real production widgets at several window sizes and
/// lets Flutter's own `RenderFlex overflowed` error decide, so a passing test is
/// positive evidence that the widget is fine at that size.
///
/// Sizes cover the desktop range the app ships for:
///   360x300   — a deliberately cramped window (the failure mode the reference
///               article describes)
///   640x480   — a small but realistic window
///   800x600   — the common default
///   1280x720  — a large window
void main() {
  late Directory appPathSandbox;

  // Production widgets read the global `appLocalizations`, whose `_current` is
  // only set by `AppLocalizations.load`. `appPath` also needs a working
  // `path_provider`: without it, `ProfileNodesView.initState` raises an
  // **unhandled async** `UnsupportedError` from `getDownloadsDirectory()`
  // (macOS-only in the platform interface, and thrown before any channel mock
  // can answer) that would fail a test before its layout is judged. The fake
  // below is the same pattern `windows_runtime_validation_test.dart` uses.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    appPathSandbox = Directory.systemTemp.createTempSync('fluxora_rc7_path_');
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

  const List<Size> sizes = [
    Size(360, 300),
    Size(640, 480),
    Size(800, 600),
    Size(1280, 720),
  ];

  // P1 — narrow-screen regression tier for the ChainProxyView topology header.
  //
  // The shared [sizes] list above starts at 360 dp, but the topology card header
  // (Expanded title + probe button + status chip) actually overflowed at 280 dp.
  // These extra widths are scoped to the ChainProxyView group only: the other
  // groups in this file are desktop-only dialogs/pages whose minimum supported
  // width is 360 dp, so widening the shared list would assert behaviour they
  // never claimed to support. The check itself is unchanged (`takeException`).
  const List<Size> narrowSizes = [
    Size(320, 640),
    Size(280, 560),
  ];

  Future<void> applySize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Asserts the widget under test produced **no layout overflow**.
  ///
  /// The RC.7 acceptance criterion is "the reproduced overflow is fixed", so any
  /// pending exception — `RenderFlex overflowed` or otherwise — is a failure.
  void expectNoOverflow(WidgetTester tester) {
    Object? error = tester.takeException();
    while (error != null) {
      fail('unexpected exception while laying out: $error');
    }
  }

  group('RC.7 — ChainSupportConfirmDialog', () {
    for (final size in sizes) {
      testWidgets('no overflow at ${size.width}x${size.height}', (tester) async {
        await applySize(tester, size);

        await tester.pumpWidget(
          ProviderScope(
            child: const MaterialApp(
              home: Scaffold(body: ChainSupportConfirmDialog()),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Create Support Package'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('RC.7 — dashboard widgets', () {
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
    /// production fills in `ThemeManager`; several dashboard widgets read them
    /// directly. They are seeded from a `Builder` **inside the live tree** — a
    /// context captured from a throwaway pump would be deactivated by the time
    /// the widget under test reads it.
    Widget seedGlobals(Widget child) {
      return Builder(
        builder: (ctx) {
          globalState.theme = CommonTheme.of(ctx, 1.0);
          globalState.measure = Measure.of(ctx, 1.0);
          return child;
        },
      );
    }

    final Map<String, Widget Function()> widgets = {
      'ConnectionsCount': () => const ConnectionsCount(),
      'ProvidersInfo': () => const ProvidersInfo(),
      'IntranetIP': () => const IntranetIP(),
      'FcmStatus': () => const FcmStatus(),
      'MediaUnlockSmall': () => const MediaUnlockSmall(),
    };

    for (final entry in widgets.entries) {
      for (final size in sizes) {
        testWidgets(
          '${entry.key} no overflow at ${size.width}x${size.height}',
          (tester) async {
            await applySize(tester, size);

            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  home: seedGlobals(Scaffold(body: entry.value())),
                ),
              ),
            );
            await tester.pump();

            expectNoOverflow(tester);
          },
        );
      }
    }
  });

  group('RC.7 — ProfileNodesView batch-import dialog', () {
    // `ProfileNodesView` is a plain StatefulWidget with no `ref` dependency, so
    // it can be driven through its real entry point: tap the app-bar action and
    // assert on what the dialog actually renders.
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

    Profile profile() => Profile(
      id: 'rc7-layout-profile',
      label: 'RC7',
      autoUpdateDuration: const Duration(days: 1),
    );

    Future<void> openBatchImport(WidgetTester tester, Size size) async {
      await applySize(tester, size);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: ProfileNodesView(profile: profile())),
        ),
      );
      await tester.pump();

      // The app-bar action is rendered regardless of the async `_loadProxies`
      // state, so it is the reliable entry point.
      await tester.tap(find.byTooltip('批量导入链接'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    for (final size in sizes) {
      testWidgets(
        'batch-import dialog no overflow at ${size.width}x${size.height}',
        (tester) async {
          await openBatchImport(tester, size);

          expect(find.text('批量导入分享链接'), findsOneWidget);
          expectNoOverflow(tester);
        },
      );
    }
  });

  group('RC.7 — profile dialogs (audit batch)', () {
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

    Profile profile() => Profile(
      id: 'rc7-audit',
      label: 'RC7',
      autoUpdateDuration: const Duration(days: 1),
    );

    Future<void> pumpWidgetAt(
      WidgetTester tester,
      Size size,
      Widget child, {
      bool runAsync = false,
    }) async {
      await applySize(tester, size);
      if (runAsync) {
        // The widget kicks off real async work in `initState`; let it finish
        // inside `runAsync` (a real-async zone) so the assertion sees the loaded
        // layout rather than a mid-load frame.
        await tester.runAsync(() async {
          await tester.pumpWidget(
            ProviderScope(child: MaterialApp(home: Scaffold(body: child))),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
      } else {
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: Scaffold(body: child))),
        );
      }
      await tester.pump();
    }

    // `SizedBox(width: 520)` inside an `AlertDialog` (profile_chain_dialog.dart:93).
    for (final size in sizes) {
      testWidgets(
        'ProfileChainDialog no overflow at ${size.width}x${size.height}',
        (tester) async {
          await pumpWidgetAt(
            tester,
            size,
            ProfileChainDialog(profile: profile()),
            runAsync: true,
          );
          expectNoOverflow(tester);
        },
      );
    }

    // `DropdownMenu(width: 200, menuHeight: 250)` (override_profile.dart:854/921).
    for (final size in sizes) {
      testWidgets(
        'AddRuleDialog no overflow at ${size.width}x${size.height}',
        (tester) async {
          await pumpWidgetAt(
            tester,
            size,
            const AddRuleDialog(snippet: ClashConfigSnippet()),
          );
          expectNoOverflow(tester);
        },
      );
    }

    // `SizedBox(height: 300)` empty state inside a scrollable sliver
    // (override_profile.dart:489).
    for (final size in sizes) {
      testWidgets(
        'RuleContent no overflow at ${size.width}x${size.height}',
        (tester) async {
          // `RuleContent.build` returns a **sliver** (`SliverToBoxAdapter`), so
          // it has to be hosted by a sliver container — not `Scaffold.body`.
          await pumpWidgetAt(
            tester,
            size,
            const CustomScrollView(
              slivers: [RuleContent(maxWidth: 400)],
            ),
          );
          expectNoOverflow(tester);
        },
      );
    }
  });

  group('RC.7 — remaining fixed-size candidates (audit batch 2)', () {
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

    Future<void> pumpPage(WidgetTester tester, Size size, Widget page) async {
      await applySize(tester, size);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: page)),
      );
      await tester.pump();
    }

    // `SizedBox(width: 300)` in the sniffer port dialog (sniffer.dart:331),
    // opened by tapping the HTTP port item.
    for (final size in sizes) {
      testWidgets(
        'sniffer port dialog no overflow at ${size.width}x${size.height}',
        (tester) async {
          await pumpPage(
            tester,
            size,
            const Scaffold(body: HttpPortSnifferItem()),
          );
          await tester.tap(find.text('80, 8080-8880'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expectNoOverflow(tester);
        },
      );
    }

    // `SizedBox(width: 520)` in `_ManualNodeFormDialog`
    // (profile_nodes_view.dart:781), opened from the page FAB.
    for (final size in sizes) {
      testWidgets(
        'manual-add-node dialog no overflow at ${size.width}x${size.height}',
        (tester) async {
          await pumpPage(
            tester,
            size,
            ProfileNodesView(
              profile: Profile(
                id: 'rc7-audit-2',
                label: 'RC7',
                autoUpdateDuration: const Duration(days: 1),
              ),
            ),
          );
          await tester.tap(find.byType(FloatingActionButton));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expectNoOverflow(tester);
        },
      );
    }
  });

  group('RC.7 — add-profile dialog (audit batch 3)', () {
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

    // `SizedBox(width: 380)` in the "new empty group" AlertDialog
    // (add_profile.dart:197), opened from the add-profile list.
    for (final size in sizes) {
      testWidgets(
        'new-empty-group dialog no overflow at ${size.width}x${size.height}',
        (tester) async {
          await applySize(tester, size);
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: Builder(
                  // Production passes the host context in; the dialog is opened
                  // against it.
                  builder: (ctx) => AddProfileView(context: ctx),
                ),
              ),
            ),
          );
          await tester.pump();

          final entry = find.text('新建空白分组');
          expect(entry, findsOneWidget, reason: 'the trigger must be present');
          await tester.tap(entry);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expectNoOverflow(tester);
        },
      );
    }
  });

  // ── NOT VERIFIED (deliberately not asserted) ───────────────────────────────
  //
  // These candidates could not be reproduced in this harness, so they are
  // **unverified** — NOT "no overflow":
  //
  //  · `theme.dart:723` `_PaletteDialog` (SizedBox 250x250). The dialog is
  //    private and its only trigger is a `+` control inside the theme page's
  //    colour grid, which this harness cannot reach (the add control is not
  //    built for the pumped view), so the dialog never opens.
  //  · `dashboard/widgets/core_status_dialog.dart` — needs the live core-status
  //    provider stack (`ViewSize` → `globalState.appState`, plus core providers
  //    that throw without a running core).
  //  · `dashboard/widgets/memory_info.dart` — starts a periodic `Timer`, which
  //    the test framework rejects with `!timersPending` before any layout is
  //    judged.

  group('RC.7 — ChainProxyView', () {
    // One container for the whole file: `chainProxyConfigProvider` is a
    // `ChangeNotifierProvider` over the process-wide singleton, and riverpod
    // disposes the notifier with the container.
    late Directory tempDir;
    late ProviderContainer container;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('fluxora_rc7_layout_');
      final sep = Platform.pathSeparator;
      ChainProxyManager.configFilePathOverride =
          '${tempDir.path}${sep}chain_proxies.json';
      ChainProxyManager.fallbackPoolFilePathOverride =
          '${tempDir.path}${sep}chain_fallback_pool.json';
      ChainProxyManager.reliabilityStatsFilePathOverride =
          '${tempDir.path}${sep}chain_reliability_stats.json';
      ChainProxyManager.coreRunningOverride = true;
      container = ProviderContainer(
        overrides: [chainProbeReportProvider.overrideWith((ref) => null)],
      );
    });

    tearDownAll(() async {
      container.dispose();
      ChainProxyManager.configFilePathOverride = null;
      ChainProxyManager.fallbackPoolFilePathOverride = null;
      ChainProxyManager.reliabilityStatsFilePathOverride = null;
      ChainProxyManager.coreRunningOverride = null;
      try {
        await tempDir.delete(recursive: true);
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

    Future<void> pumpAt(
      WidgetTester tester,
      Size size,
      ChainProxyConfig config,
    ) async {
      await applySize(tester, size);

      // Real file I/O never completes inside the fake-async zone `testWidgets`
      // installs, so it has to run through `runAsync`.
      await tester.runAsync(() => chainProxyManager.updateConfig((_) => config));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChainProxyView()),
        ),
      );
      await tester.pump();
    }

    /// Long, realistic node names — the case a fixed-width `Row` actually breaks
    /// on. `landingProxies` is populated so the two-hop exit renders.
    ChainProxyConfig twoHop() => const ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.twoHop,
      hop1Node: 'HK-01-香港-中转-东京-优化线路-01',
      hop2Node: 'US-住宅-洛杉矶-静态-出口-超长节点名称-99',
      defaultDialerProxy: 'HK-01-香港-中转-东京-优化线路-01',
    );

    ChainProxyConfig threeHop() => const ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.threeHop,
      hop1Node: 'HK-01-香港-中转-东京-优化线路-01',
      hop2Node: 'SG-01-新加坡-中转-超长名称-02',
      hop3Node: 'US-住宅-洛杉矶-静态-出口-超长节点名称-99',
      defaultDialerProxy: 'HK-01-香港-中转-东京-优化线路-01',
    );

    // P1: include the narrow tier so the topology-header overflow that only
    // appeared below 360 dp is permanently covered.
    for (final size in [...sizes, ...narrowSizes]) {
      testWidgets('two-hop, no overflow at ${size.width}x${size.height}',
          (tester) async {
        await pumpAt(tester, size, twoHop());
        expect(tester.takeException(), isNull);
      });

      testWidgets('three-hop, no overflow at ${size.width}x${size.height}',
          (tester) async {
        await pumpAt(tester, size, threeHop());
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// Redirects every `path_provider` call into a sandbox directory.
///
/// Mirrors `FakeWindowsPathProviderPlatform` in
/// `test/services/windows_runtime_validation_test.dart`.
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
