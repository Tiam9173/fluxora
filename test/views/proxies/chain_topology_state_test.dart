import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/chain_proxy.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/proxies/chain_proxy_view.dart';
import 'package:fluxora/widgets/widgets.dart';

/// P3 — the topology card must be driven by the **real** probe report.
///
/// Before P3 the card was coloured purely from `config.enable`, so a failing
/// chain still rendered as "ready". These tests pin the mapping and the render:
///   · `resolveTopologySegmentState` — the pure report → state mapping;
///   · `topologySegmentFlow` — the pure segment colour rule;
///   · the real `ChainProxyView`, pumped with a real config, asserting that the
///     per-hop outcome reaches the UI and follows a report update.
///
/// **Provider lifecycle.** `chainProxyConfigProvider` is a
/// `ChangeNotifierProvider` over the process-wide `chainProxyManager` singleton,
/// and riverpod disposes a `ChangeNotifierProvider`'s notifier with its element.
/// Exactly ONE container may therefore be created/disposed per process — the
/// rule documented in `test/providers/chain_proxy_providers_test.dart` and
/// `warp_view_hop_filter_test.dart`. This file follows it: one container in
/// `setUpAll`, mounted with `UncontrolledProviderScope` (which does not own it).
void main() {
  // ── fixtures ──────────────────────────────────────────────────────────────
  HopProbeState hop(
    int index,
    HopRole role,
    String name,
    HopProbeStatus status,
  ) => HopProbeState(
    hopIndex: index,
    role: role,
    nodeName: name,
    nodeAddress: name,
    status: status,
    testedAt: DateTime.now(),
  );

  ChainProbeReport reportWith({
    required ChainHopMode mode,
    required List<HopProbeState> hops,
    int? failureHop,
    ChainHealthStatus status = ChainHealthStatus.failed,
    DateTime? timestamp,
  }) => ChainProbeReport(
    mode: mode,
    isOverallHealthy: status == ChainHealthStatus.healthy,
    healthStatus: status,
    hops: hops,
    failureHop: failureHop,
    timestamp: timestamp ?? DateTime.now(),
  );

  // ── 1. the pure mapping ───────────────────────────────────────────────────
  group('P3 — resolveTopologySegmentState maps the real report', () {
    test('no report at all → notProbed (never a fabricated healthy)', () {
      expect(
        resolveTopologySegmentState(
          nodeName: 'HK-01',
          hopIndex: 1,
          report: null,
        ),
        TopologySegmentState.notProbed,
      );
    });

    test('a stale report is no evidence → notProbed', () {
      final stale = reportWith(
        mode: ChainHopMode.twoHop,
        hops: [
          hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.healthy),
          hop(2, HopRole.hop2Exit, 'US-01', HopProbeStatus.healthy),
        ],
        status: ChainHealthStatus.healthy,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'HK-01',
          hopIndex: 1,
          report: stale,
        ),
        TopologySegmentState.notProbed,
      );
    });

    test('first hop failed → first hop is failed', () {
      final report = reportWith(
        mode: ChainHopMode.twoHop,
        hops: [
          hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.timeout),
          hop(2, HopRole.hop2Exit, 'US-01', HopProbeStatus.failed),
        ],
        failureHop: 1,
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'HK-01',
          hopIndex: 1,
          report: report,
        ),
        TopologySegmentState.failed,
      );
    });

    test('second hop failed (two-hop) → the exit is failed, the entry is not',
        () {
      final report = reportWith(
        mode: ChainHopMode.twoHop,
        hops: [
          hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.healthy),
          hop(2, HopRole.hop2Exit, 'US-01', HopProbeStatus.failed),
        ],
        failureHop: 2,
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'US-01',
          hopIndex: 2,
          report: report,
        ),
        TopologySegmentState.failed,
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'HK-01',
          hopIndex: 1,
          report: report,
        ),
        TopologySegmentState.healthy,
      );
    });

    test('third hop failed (three-hop) → only the third hop is failed', () {
      final report = reportWith(
        mode: ChainHopMode.threeHop,
        hops: [
          hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.healthy),
          hop(2, HopRole.hop2Relay, 'SG-01', HopProbeStatus.healthy),
          hop(3, HopRole.hop3Exit, 'US-01', HopProbeStatus.failed),
        ],
        failureHop: 3,
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'US-01',
          hopIndex: 3,
          report: report,
        ),
        TopologySegmentState.failed,
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'SG-01',
          hopIndex: 2,
          report: report,
        ),
        TopologySegmentState.healthy,
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'HK-01',
          hopIndex: 1,
          report: report,
        ),
        TopologySegmentState.healthy,
      );
    });

    test('a node absent from a populated report → unknown, never healthy', () {
      final report = reportWith(
        mode: ChainHopMode.threeHop,
        hops: [
          hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.healthy),
        ],
        status: ChainHealthStatus.healthy,
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'US-01',
          hopIndex: 3,
          report: report,
        ),
        TopologySegmentState.unknown,
      );
    });

    test('a whole-chain failure never marks an unrelated hop as failed', () {
      // `failureHop` is absent ⇒ no specific hop is confirmed failed, even
      // though the report itself says the chain failed.
      final report = reportWith(
        mode: ChainHopMode.twoHop,
        hops: [
          hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.healthy),
          hop(2, HopRole.hop2Exit, 'US-01', HopProbeStatus.healthy),
        ],
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'HK-01',
          hopIndex: 1,
          report: report,
        ),
        TopologySegmentState.healthy,
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'US-01',
          hopIndex: 2,
          report: report,
        ),
        TopologySegmentState.healthy,
      );
    });

    test('an in-flight hop reports checking', () {
      final report = reportWith(
        mode: ChainHopMode.twoHop,
        hops: [
          hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.checking),
        ],
        status: ChainHealthStatus.checking,
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'HK-01',
          hopIndex: 1,
          report: report,
        ),
        TopologySegmentState.checking,
      );
    });

    test('a cancelled report is unknown, not healthy', () {
      final report = ChainProbeReport.cancelled(
        mode: ChainHopMode.twoHop,
        timestamp: DateTime.now(),
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'HK-01',
          hopIndex: 1,
          report: report,
        ),
        TopologySegmentState.unknown,
      );
    });

    test('a topology-level rejection still names the offending hop by index',
        () {
      // `probeChain` returns an EMPTY hop list for an invalid topology, with
      // `failureHop` pointing at the offending slot.
      final report = reportWith(
        mode: ChainHopMode.threeHop,
        hops: const [],
        failureHop: 3,
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'US-01',
          hopIndex: 3,
          report: report,
        ),
        TopologySegmentState.failed,
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'HK-01',
          hopIndex: 1,
          report: report,
        ),
        TopologySegmentState.unknown,
      );
    });

    test('degraded transport counts as healthy for that hop', () {
      final report = reportWith(
        mode: ChainHopMode.twoHop,
        hops: [
          HopProbeState(
            hopIndex: 2,
            role: HopRole.hop2Exit,
            nodeName: 'US-01',
            nodeAddress: 'US-01',
            status: HopProbeStatus.warning,
            healthStatus: ChainHealthStatus.degraded,
            testedAt: DateTime.now(),
          ),
        ],
        status: ChainHealthStatus.degraded,
      );
      expect(
        resolveTopologySegmentState(
          nodeName: 'US-01',
          hopIndex: 2,
          report: report,
        ),
        TopologySegmentState.healthy,
      );
    });
  });

  group('P3 — topologySegmentFlow', () {
    test('a failed end makes the segment an error', () {
      expect(
        topologySegmentFlow(
          TopologySegmentState.healthy,
          TopologySegmentState.failed,
        ),
        FluxoraFlowState.error,
      );
    });

    test('a healthy end with an unprobed edge is still connected', () {
      expect(
        topologySegmentFlow(
          TopologySegmentState.notProbed,
          TopologySegmentState.healthy,
        ),
        FluxoraFlowState.connected,
      );
    });

    test('no evidence on either end stays neutral — never green', () {
      expect(
        topologySegmentFlow(
          TopologySegmentState.notProbed,
          TopologySegmentState.unknown,
        ),
        FluxoraFlowState.idle,
      );
    });

    test('checking outranks healthy', () {
      expect(
        topologySegmentFlow(
          TopologySegmentState.checking,
          TopologySegmentState.healthy,
        ),
        FluxoraFlowState.connecting,
      );
    });

    test('error outranks checking', () {
      expect(
        topologySegmentFlow(
          TopologySegmentState.checking,
          TopologySegmentState.failed,
        ),
        FluxoraFlowState.error,
      );
    });
  });

  // ── 2. the real topology card ─────────────────────────────────────────────
  group('P3 — the topology card follows the real probe report', () {
    late Directory tempDir;
    late ProviderContainer container;
    ChainProbeReport? reportHolder;

    setUpAll(() async {
      // The view reads the global `appLocalizations`, whose `_current` is only
      // set by `AppLocalizations.load` — without it the first build asserts.
      await AppLocalizations.load(const Locale('zh', 'CN'));

      tempDir = await Directory.systemTemp.createTemp('fluxora_p3_topology_');
      final sep = Platform.pathSeparator;
      ChainProxyManager.configFilePathOverride =
          '${tempDir.path}${sep}chain_proxies.json';
      ChainProxyManager.fallbackPoolFilePathOverride =
          '${tempDir.path}${sep}chain_fallback_pool.json';
      ChainProxyManager.reliabilityStatsFilePathOverride =
          '${tempDir.path}${sep}chain_reliability_stats.json';
      ChainProxyManager.coreRunningOverride = true;
      container = ProviderContainer(
        overrides: [
          chainProbeReportProvider.overrideWith((ref) => reportHolder),
        ],
      );
    });

    tearDownAll(() async {
      // Single disposal point for the process-wide `chainProxyManager`.
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

    ChainProxyConfig twoHopConfig() => const ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.twoHop,
      hop1Node: 'HK-01',
      hop2Node: 'US-01',
      defaultDialerProxy: 'HK-01',
    );

    ChainProxyConfig threeHopConfig() => const ChainProxyConfig(
      enable: true,
      hopMode: ChainHopMode.threeHop,
      hop1Node: 'HK-01',
      hop2Node: 'SG-01',
      hop3Node: 'US-01',
      defaultDialerProxy: 'HK-01',
    );

    Future<void> pumpTopology(
      WidgetTester tester,
      ChainProxyConfig config,
      ChainProbeReport? report,
    ) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(
        () => chainProxyManager.updateConfig((_) => config),
      );
      reportHolder = report;
      container.invalidate(chainProbeReportProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChainProxyView()),
        ),
      );
      await tester.pump();
    }

    testWidgets('no report → says so, and claims no failure', (tester) async {
      await pumpTopology(tester, twoHopConfig(), null);

      expect(find.textContaining('尚未探测'), findsOneWidget);
      expect(find.textContaining('探测失败'), findsNothing);
      expect(find.textContaining('逐跳探测通过'), findsNothing);
    });

    testWidgets('second hop failed (two-hop) → the failure is surfaced',
        (tester) async {
      await pumpTopology(
        tester,
        twoHopConfig(),
        reportWith(
          mode: ChainHopMode.twoHop,
          hops: [
            hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.healthy),
            hop(2, HopRole.hop2Exit, 'US-01', HopProbeStatus.failed),
          ],
          failureHop: 2,
        ),
      );

      expect(find.textContaining('探测失败'), findsOneWidget);
      expect(find.textContaining('US-01'), findsWidgets);
    });

    testWidgets('first hop failed (three-hop) → the first hop is named',
        (tester) async {
      await pumpTopology(
        tester,
        threeHopConfig(),
        reportWith(
          mode: ChainHopMode.threeHop,
          hops: [
            hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.timeout),
            hop(2, HopRole.hop2Relay, 'SG-01', HopProbeStatus.failed),
            hop(3, HopRole.hop3Exit, 'US-01', HopProbeStatus.failed),
          ],
          failureHop: 1,
        ),
      );

      expect(find.textContaining('探测失败'), findsOneWidget);
      expect(find.textContaining('HK-01'), findsWidgets);
    });

    testWidgets('third hop failed (three-hop) → the third hop is named',
        (tester) async {
      await pumpTopology(
        tester,
        threeHopConfig(),
        reportWith(
          mode: ChainHopMode.threeHop,
          hops: [
            hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.healthy),
            hop(2, HopRole.hop2Relay, 'SG-01', HopProbeStatus.healthy),
            hop(3, HopRole.hop3Exit, 'US-01', HopProbeStatus.failed),
          ],
          failureHop: 3,
        ),
      );

      expect(find.textContaining('探测失败'), findsOneWidget);
      expect(find.textContaining('US-01'), findsWidgets);
    });

    testWidgets('all hops healthy → passes, with an end-to-end caveat',
        (tester) async {
      await pumpTopology(
        tester,
        threeHopConfig(),
        reportWith(
          mode: ChainHopMode.threeHop,
          hops: [
            hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.healthy),
            hop(2, HopRole.hop2Relay, 'SG-01', HopProbeStatus.healthy),
            hop(3, HopRole.hop3Exit, 'US-01', HopProbeStatus.healthy),
          ],
          status: ChainHealthStatus.healthy,
        ),
      );

      expect(find.textContaining('逐跳探测通过'), findsOneWidget);
      expect(find.textContaining('探测失败'), findsNothing);
    });

    testWidgets('a report update repaints the card', (tester) async {
      await pumpTopology(
        tester,
        twoHopConfig(),
        reportWith(
          mode: ChainHopMode.twoHop,
          hops: [
            hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.healthy),
            hop(2, HopRole.hop2Exit, 'US-01', HopProbeStatus.failed),
          ],
          failureHop: 2,
        ),
      );
      expect(find.textContaining('探测失败'), findsOneWidget);

      // The chain recovers → the card must follow the NEW report, not keep the
      // old colour.
      reportHolder = reportWith(
        mode: ChainHopMode.twoHop,
        hops: [
          hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.healthy),
          hop(2, HopRole.hop2Exit, 'US-01', HopProbeStatus.healthy),
        ],
        status: ChainHealthStatus.healthy,
      );
      container.invalidate(chainProbeReportProvider);
      await tester.pump();

      expect(find.textContaining('探测失败'), findsNothing);
      expect(find.textContaining('逐跳探测通过'), findsOneWidget);
    });

    testWidgets('a disabled chain never claims health', (tester) async {
      await pumpTopology(
        tester,
        const ChainProxyConfig(
          enable: false,
          hopMode: ChainHopMode.twoHop,
          hop1Node: 'HK-01',
          hop2Node: 'US-01',
          defaultDialerProxy: 'HK-01',
        ),
        reportWith(
          mode: ChainHopMode.twoHop,
          hops: [
            hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.healthy),
            hop(2, HopRole.hop2Exit, 'US-01', HopProbeStatus.healthy),
          ],
          status: ChainHealthStatus.healthy,
        ),
      );

      // The stale "healthy" report must not survive a disabled chain.
      expect(find.textContaining('逐跳探测通过'), findsNothing);
      expect(find.textContaining('探测失败'), findsNothing);
    });

    testWidgets('two-hop mode renders no third-hop residue', (tester) async {
      await pumpTopology(
        tester,
        twoHopConfig(),
        reportWith(
          mode: ChainHopMode.twoHop,
          hops: [
            hop(1, HopRole.hop1Entry, 'HK-01', HopProbeStatus.healthy),
            hop(2, HopRole.hop2Exit, 'US-01', HopProbeStatus.healthy),
          ],
          status: ChainHealthStatus.healthy,
        ),
      );

      // `SG-01` is the three-hop relay fixture; it must not leak into two-hop.
      expect(find.textContaining('SG-01'), findsNothing);
    });
  });
}
