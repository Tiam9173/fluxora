import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/manager/warp_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/proxies/warp_view.dart';

/// B4.1 — WARP hop picker node filtering.
///
/// Exercises the **real** production path: `WarpView` → the
/// 「前置跳板代理 (Dialer-Proxy)」 tile → `_showHopPickerSheet`, then asserts on
/// what the sheet actually renders. No production file is modified and the UI
/// is not refactored — the sheet is driven through its own entry point.
///
/// Covered contract (B4.1 §4):
///   · self-loop — the WARP outbound itself is never offered as its own dialer
///   · `DIRECT` / built-in policies are not offered as ordinary nodes
///   · nested-group members (type = Selector/URLTest/…) are not ordinary nodes
///   · chain shadow nodes (`🔗中转·` / `🔗出口·`) are not ordinary nodes
///   · ordinary protocols are still offered
///   · unknown, non-built-in types are still offered (conservative)
///   · the 「策略组」 section keeps offering proxy groups independently
///
/// **Provider lifecycle (B4.1 isolation fix).** `warpProvider` is a
/// `ChangeNotifierProvider` that returns the **process-wide** `warpManager`
/// singleton (`lib/providers/warp.dart:4-6`), and riverpod disposes a
/// `ChangeNotifierProvider`'s notifier when its element is disposed. Pumping a
/// fresh `ProviderScope` per `testWidgets` therefore *disposed the global
/// singleton at the end of the first test*, so the second test failed with
/// `A WarpManager was used after being disposed`.
///
/// Exactly ONE container may therefore be created/disposed per process — the
/// same rule already documented for `chainProxyManager` in
/// `test/providers/chain_proxy_providers_test.dart:14-29`. This file follows
/// that pattern: one `ProviderContainer` in `setUpAll`, disposed in
/// `tearDownAll`, mounted with `UncontrolledProviderScope` (which does **not**
/// own the container's lifecycle).
void main() {
  group('B4.1 — WARP hop picker node filtering', () {
    late Directory tempDir;
    // One container for the whole file — see the lifecycle note above.
    late ProviderContainer container;

    setUpAll(() async {
      // The manager is a process-wide singleton; point its persistence seam at a
      // throwaway path so `init()` never touches the real app data directory.
      tempDir = await Directory.systemTemp.createTemp('fluxora_b41_warp_');
      WarpManager.configFilePathOverride =
          '${tempDir.path}${Platform.pathSeparator}warp_config.json';
      await warpManager.init();
      container = ProviderContainer();
    });

    tearDownAll(() async {
      // Single disposal point for the process-wide `warpManager` notifier.
      container.dispose();
      WarpManager.configFilePathOverride = null;
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Best effort: the OS may still hold a handle on the temp dir.
      }
    });

    setUp(() {
      // `showSheet` reads `globalState.appState.viewMode` to pick a bottom vs
      // side sheet. A mobile-width `viewSize` keeps it a bottom sheet. `WarpView`
      // itself never touches `appController`.
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

    /// Pumps `WarpView`, taps the hop tile and returns once the sheet is open.
    Future<void> openHopPicker(WidgetTester tester, List<Group> groups) async {
      // A tall, realistic surface so the page's lazy `ListView` builds the hop
      // card without needing to scroll.
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Seed the fixture through the *reused* container instead of overriding a
      // per-test scope. `Groups.onUpdate` writes straight to
      // `globalState.appState.groups`, so the value survives even if the
      // (auto-dispose) provider is rebuilt between reads.
      container.read(groupsProvider.notifier).value = groups;

      // `WarpView` already supplies its own `CommonScaffold` (that is exactly
      // how production instantiates it — `const WarpView()` with no `type`), so
      // no extra `Scaffold` is added here.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WarpView()),
        ),
      );
      // Bounded pumps rather than `pumpAndSettle`: the page must not be required
      // to reach a fully-settled state for the assertions to be meaningful, and
      // `pumpAndSettle` turns any framework animation into a hard timeout.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final hopTile = find.text('前置跳板代理 (Dialer-Proxy)');
      if (hopTile.evaluate().isEmpty) {
        // The body is a lazy `ListView`; scroll until the card is built. Guard
        // the scrollable lookup so an empty tree surfaces as the real assertion
        // failure below rather than as `Bad state: No element`.
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.scrollUntilVisible(
            hopTile,
            300,
            scrollable: scrollable.first,
          );
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      expect(
        hopTile,
        findsOneWidget,
        reason: 'the hop tile must render — default routingMode is warpOverProxy',
      );

      await tester.ensureVisible(hopTile);
      await tester.pump();
      await tester.tap(hopTile);
      // `showModalBottomSheet` pushes a route; pump its entrance explicitly.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('机场代理节点'),
        findsOneWidget,
        reason: 'the hop picker sheet must be open',
      );
    }

    testWidgets('offers ordinary nodes and refuses internal/non-node objects',
        (tester) async {
      // Read the LIVE names the production filter compares against — this is the
      // whole point of B4.1 (no hard-coded literals).
      final proxyName = warpManager.config.proxyName;
      final warpExitGroupName = warpManager.config.dedicatedGroupName;
      final chainGroupName = chainProxyManager.config.dedicatedGroupName;
      const warpHopGroupName = '✈️ WARP跳板';

      final groups = <Group>[
        Group(
          name: 'Airport-Manual',
          type: GroupType.Selector,
          all: const [
            Proxy(name: 'Tokyo-01', type: 'vless'),
            Proxy(name: 'Osaka-02', type: 'trojan'),
            Proxy(name: '剩余流量：103.23 GB', type: 'hysteria2'),
            Proxy(name: 'Future-Proto', type: 'some-new-protocol'),
            Proxy(name: 'DIRECT', type: 'Direct'),
            Proxy(name: 'REJECT', type: 'Reject'),
            Proxy(name: 'InnerAuto', type: 'URLTest'),
            Proxy(name: '🔗中转·Tokyo-01', type: 'vless'),
          ],
          now: '',
        ),
        // The WARP outbound itself — must never be offered as its own dialer.
        Group(
          name: warpExitGroupName,
          type: GroupType.Selector,
          all: [Proxy(name: proxyName, type: 'wireguard')],
          now: '',
        ),
        // Chain + WARP internal groups — skipped entirely.
        Group(
          name: chainGroupName,
          type: GroupType.Selector,
          all: const [Proxy(name: 'ChainInternal', type: 'vless')],
          now: '',
        ),
        Group(
          name: warpHopGroupName,
          type: GroupType.Selector,
          all: const [Proxy(name: 'HopInternal', type: 'vless')],
          now: '',
        ),
        // A plain strategy group with no members — 策略组 section only.
        Group(name: 'Airport-Auto', type: GroupType.URLTest, all: const [], now: ''),
      ];

      await openHopPicker(tester, groups);

      // ── ordinary nodes are offered ────────────────────────────────────────
      expect(find.text('Tokyo-01'), findsOneWidget);
      expect(find.text('Osaka-02'), findsOneWidget);
      // subscription "information" node — behavioural classification, not a
      // name blacklist (B4.1 forbids one).
      expect(find.text('剩余流量：103.23 GB'), findsOneWidget);
      // unknown, non-built-in type is kept (conservative).
      expect(find.text('Future-Proto'), findsOneWidget);

      // ── built-in policies are not ordinary nodes ──────────────────────────
      // NOTE: the sheet has a *fixed* tile titled 'DIRECT (直连 Cloudflare)';
      // an exact 'DIRECT' node row must not exist.
      expect(find.text('DIRECT'), findsNothing);
      expect(find.text('REJECT'), findsNothing);

      // ── nested-group member is not an ordinary node ───────────────────────
      expect(find.text('InnerAuto'), findsNothing);

      // ── chain shadow node is not an ordinary node ─────────────────────────
      expect(find.text('🔗中转·Tokyo-01'), findsNothing);

      // ── self-loop: the WARP outbound is never its own dialer ──────────────
      expect(
        find.text(proxyName),
        findsNothing,
        reason: 'the WARP outbound must not be offered as its own dialer',
      );

      // ── internal groups contribute no nodes at all ────────────────────────
      expect(find.text('ChainInternal'), findsNothing);
      expect(find.text('HopInternal'), findsNothing);

      // ── the 「策略组」 section still offers proxy groups independently ──────
      expect(find.text('策略组'), findsOneWidget);
      expect(find.text('Airport-Manual'), findsOneWidget);
      expect(find.text('Airport-Auto'), findsOneWidget);
      // …but the internal groups are not offered as策略组 either.
      expect(find.text(chainGroupName), findsNothing);
      expect(find.text(warpExitGroupName), findsNothing);
      expect(find.text(warpHopGroupName), findsNothing);
    });

    testWidgets('keeps a group rename from leaking internal groups',
        (tester) async {
      // Guards the B4.1 de-hardcoding: the picker must follow the LIVE
      // `ChainProxyConfig.dedicatedGroupName`, not the historical literal.
      final chainGroupName = chainProxyManager.config.dedicatedGroupName;
      expect(
        chainGroupName,
        isNotEmpty,
        reason: 'the chain group name must come from live config',
      );

      final groups = <Group>[
        Group(
          name: chainGroupName,
          type: GroupType.Selector,
          all: const [Proxy(name: 'ChainInternal', type: 'vless')],
          now: '',
        ),
        Group(
          name: 'Proxy',
          type: GroupType.Selector,
          all: const [Proxy(name: 'Tokyo-01', type: 'vless')],
          now: '',
        ),
      ];

      await openHopPicker(tester, groups);

      expect(find.text('ChainInternal'), findsNothing);
      expect(find.text(chainGroupName), findsNothing);
      expect(find.text('Tokyo-01'), findsOneWidget);
    });
  });
}
