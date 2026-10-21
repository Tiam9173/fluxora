
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Test-only: `path_provider` is a transitive dependency. Faking the platform
// instance is the only way to make `appPath` resolvable in a VM test — without
// it `ProfileNodesView._loadProxies()` never settles and the empty state (where
// the action buttons live) is never built. Same pattern as
// `layout_overflow_repro_test.dart`.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/backup_and_recovery.dart';
import 'package:fluxora/views/config/config.dart';
import 'package:fluxora/views/config/dns.dart';
import 'package:fluxora/views/config/experimental.dart';
import 'package:fluxora/views/config/general.dart';
import 'package:fluxora/views/config/network.dart';
import 'package:fluxora/views/config/ntp.dart';
import 'package:fluxora/views/config/sniffer.dart';
import 'package:fluxora/views/config/tunnel.dart';
import 'package:fluxora/views/connection/item.dart';
import 'package:fluxora/views/dashboard/widgets/online_panel.dart';
import 'package:fluxora/views/dashboard/widgets/traffic_usage.dart';
import 'package:fluxora/views/logs.dart';
import 'package:fluxora/views/other_setting.dart';
import 'package:fluxora/views/profiles/add_profile.dart';
import 'package:fluxora/views/profiles/override_profile.dart';
import 'package:fluxora/views/profiles/profile_nodes_view.dart';
import 'package:fluxora/views/resources.dart';

/// item 4 — narrow-screen / large-text-scale adaptation.
///
/// The app supports a text scale of 0.8–1.4 (`theme_manager.dart:71-85`), so a
/// layout that only fits at 1.0 is a real defect. Each case below is positive
/// evidence: a `RenderFlex overflowed` surfaces through `takeException()`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory appPathSandbox;

  setUpAll(() async {
    appPathSandbox = Directory.systemTemp.createTempSync('fluxora_item4_');
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

  Profile profile() => Profile(
    id: 'item4-narrow',
    label: 'Item4',
    autoUpdateDuration: const Duration(days: 1),
  );

  /// `globalState.theme` / `globalState.measure` are `late` globals that
  /// production fills in `ThemeManager`; several dashboard widgets read them
  /// directly. Seeded from a `Builder` inside the live tree, same as
  /// `layout_overflow_repro_test.dart`.
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
                data: MediaQuery.of(ctx).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
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

  for (final size in const [
    Size(360, 640),
    Size(320, 640),
    Size(280, 560),
  ]) {
    testWidgets(
      'ProfileNodesView 空态操作按钮不溢出 @ ${size.width}x${size.height} + 1.4x',
      (tester) async {
        await pumpAt(tester, size, 1.4, ProfileNodesView(profile: profile()));

        // Both empty-state actions must be present…
        expect(find.text(appLocalizations.importShareLinks), findsOneWidget);
        expect(find.text(appLocalizations.manualEntry), findsOneWidget);
        // …and the action row must not overflow.
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ── config pages ───────────────────────────────────────────────────────────
  //
  // The config pages are the largest surface item 4 covers and were NOT in the
  // existing RC.7 harness. Each `*ListView` is the whole page.
  final configPages = <String, Widget>{
    'ConfigView': const ConfigView(),
    'GeneralListView': const GeneralListView(),
    'NetworkListView': const NetworkListView(),
    'DnsListView': const DnsListView(),
    'NtpListView': const NtpListView(),
    'SnifferListView': const SnifferListView(),
    'TunnelListView': const TunnelListView(),
    'ExperimentalListView': const ExperimentalListView(),
  };

  for (final entry in configPages.entries) {
    for (final size in const [
      Size(360, 640),
      Size(320, 640),
      Size(280, 560),
    ]) {
      testWidgets(
        '${entry.key} 不溢出 @ ${size.width}x${size.height} + 1.4x',
        (tester) async {
          await pumpAt(tester, size, 1.4, entry.value);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // item 6 (Bettbox 1.19.4) — the resources page gained a `Providers |
  // Resources` title switch. With no providers it falls back to the plain title,
  // which is the state most likely to be hit and the one that must not overflow.
  for (final size in const [Size(360, 640), Size(320, 640), Size(280, 560)]) {
    testWidgets(
      'ResourcesView 不溢出 @ ${size.width}x${size.height} + 1.4x',
      (tester) async {
        await pumpAt(tester, size, 1.4, seedGlobals(const ResourcesView()));
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ── dialog titles built from `Row([Icon, Text])` ───────────────────────────
  //
  // `AlertDialog` applies a 40 px horizontal `insetPadding`, so at 280 dp the
  // dialog is only ~200 dp wide — narrower than the 360 dp the RC.7 harness
  // used. These titles carry an unwrapped `Text`, so they are worth pinning.
  const narrowSizes = [Size(320, 640), Size(280, 560)];

  for (final size in narrowSizes) {
    testWidgets('批量导入对话框标题不溢出 @ ${size.width} + 1.4x', (tester) async {
      await pumpAt(tester, size, 1.4, ProfileNodesView(profile: profile()));
      await tester.tap(find.byTooltip('批量导入链接'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
    });

    testWidgets('手动添加节点对话框标题不溢出 @ ${size.width} + 1.4x', (tester) async {
      await pumpAt(tester, size, 1.4, ProfileNodesView(profile: profile()));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
    });

    testWidgets('TraySection 不溢出 @ ${size.width} + 1.4x', (tester) async {
      // A bare `Column` needs a `Scaffold` host: pumped directly as
      // `MaterialApp.home` it reports a bogus 99360 px *vertical* overflow that
      // has nothing to do with the row being measured here.
      await pumpAt(
        tester,
        size,
        1.4,
        const Scaffold(body: SingleChildScrollView(child: TraySection())),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('新建空白分组对话框标题不溢出 @ ${size.width} + 1.4x', (tester) async {
      await pumpAt(
        tester,
        size,
        1.4,
        Builder(builder: (ctx) => AddProfileView(context: ctx)),
      );
      await tester.pump();

      final entry = find.text('新建空白分组');
      expect(entry, findsOneWidget, reason: 'the trigger must be present');
      await tester.tap(entry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull);
    });

    testWidgets('RuleContent 不溢出 @ ${size.width} + 1.4x', (tester) async {
      // Production passes `constraints.maxWidth - 104` (override_profile.dart:102),
      // so a 280 dp screen leaves the rule cards only ~176 dp.
      await pumpAt(
        tester,
        size,
        1.4,
        CustomScrollView(
          slivers: [RuleContent(maxWidth: size.width - 104)],
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  // ── remaining uncovered pages / cards ───────────────────────────────────────
  final moreWidgets = <String, Widget>{
    'TrafficUsage': const TrafficUsage(),
    'OnlinePanel': const OnlinePanel(),
    'BackupAndRecovery': const BackupAndRecovery(),
    // LogsView 打开时会向内核拉取历史日志。CI runner 上没有内核二进制，
    // 那个调用会抛 ProcessException 而不是溢出。这里注入一个空的历史来源，
    // 让布局用例不依赖内核——生产路径不变。
    'LogsView': LogsView(historyLoader: () async => const <Log>[]),
    'TrackerInfoItem': TrackerInfoItem(
      trackerInfo: TrackerInfo(
        id: 'item4',
        start: DateTime(2026, 1, 1),
        metadata: const Metadata(host: 'example.com'),
        chains: const ['DIRECT'],
        rule: 'MATCH',
        rulePayload: '',
      ),
      detailTitle: 'T',
      index: 0,
      count: 1,
    ),
  };

  // `BackupAndRecovery` / `LogsView` are whole pages that already contain a
  // `ListView` — wrapping them in a `SingleChildScrollView` would give that
  // list an unbounded height, so these are hosted directly.
  for (final entry in moreWidgets.entries) {
    for (final size in narrowSizes) {
      testWidgets('${entry.key} 不溢出 @ ${size.width} + 1.4x', (tester) async {
        await pumpAt(
          tester,
          size,
          1.4,
          seedGlobals(Scaffold(body: entry.value)),
        );
        expect(tester.takeException(), isNull);
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
