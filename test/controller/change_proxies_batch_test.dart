import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/core.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';

/// Phase 10 — D5: `changeProxiesBatch` must not leave a fake selection behind.
///
/// The defect: it wrote the optimistic selection map **before** talking to the
/// core, then caught a failed `changeProxy` and only logged it. A rejected
/// change therefore left the UI showing a node the core had never accepted, and
/// `updateGroups()` could not repair it — its reconciliation is gated on
/// `newGroup.now != oldGroup.now`, which is false when the core rejected.
///
/// Everything here is a Fake Core. No real core, socket, TUN, DNS, route or
/// system proxy is touched: `clashCore.clashInterface` is swapped for a
/// recording double, and `updateGroups()` is overridden so the read-back is
/// scripted instead of going through `Isolate.run` + a live core.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeClashCore fake;
  late WidgetRef capturedRef;

  const groupName = 'Proxy';
  const oldNode = 'Node-Old';
  const newNode = 'Node-New';

  Group group(String name, String now) => Group(
        type: GroupType.Selector,
        name: name,
        now: now,
        all: [
          Proxy(name: oldNode, type: 'vless'),
          Proxy(name: newNode, type: 'vless'),
        ],
      );

  setUp(() {
    fake = _FakeClashCore();
    clashCore.clashInterface = fake;

    // `DetectionState.startCheck` reads `globalState.appState` synchronously
    // and bails out when `isInit` is false — the default. Seeding it keeps the
    // tail of `changeProxiesBatch` from throwing on a late field.
    globalState.appState = AppState(
      brightness: Brightness.light,
      version: 1,
      viewSize: Size.zero,
      requests: FixedList(10),
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
  });

  /// Builds a controller wired to a scripted read-back.
  ///
  /// `readBack` is what the core would report after the batch. Returning the
  /// pre-change groups models a read-back that never landed.
  Future<_TestController> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, child) {
            capturedRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final context = tester.element(find.byType(SizedBox).first);
    final controller = _TestController(context, capturedRef);

    // A profile has to exist: `updateCurrentSelectedMap` is a no-op when
    // `currentProfileProvider` is null, so without one there is nothing to
    // observe.
    final profile = Profile.normal(
      label: 'D5',
    ).copyWith(selectedMap: {groupName: oldNode});
    capturedRef.read(profilesProvider.notifier).setProfile(profile);
    capturedRef.read(currentProfileIdProvider.notifier).value = profile.id;

    return controller;
  }

  Map<String, String> selectedMap() =>
      capturedRef.read(currentProfileProvider)?.selectedMap ??
      <String, String>{};

  testWidgets('core accepts — UI and core agree', (tester) async {
    final controller = await pump(tester);
    fake.acceptAll = true;
    controller.readBack = () => [group(groupName, newNode)];

    final ok = await controller.changeProxiesBatch({groupName: newNode});

    expect(ok, isTrue);
    expect(fake.changeProxyCalls, [groupName], reason: 'exactly one attempt');
    expect(selectedMap()[groupName], newNode);
  });

  testWidgets('core rejects — the fake selection is rolled back', (
    tester,
  ) async {
    final controller = await pump(tester);
    fake.acceptAll = false;
    // The core never moved, so the read-back still reports the old node.
    controller.readBack = () => [group(groupName, oldNode)];

    final ok = await controller.changeProxiesBatch({groupName: newNode});

    expect(ok, isFalse, reason: 'a rejected change is not a success');
    expect(
      selectedMap()[groupName],
      oldNode,
      reason: 'the optimistic write must not survive a rejection',
    );
  });

  testWidgets('partial batch — each group reflects its own outcome', (
    tester,
  ) async {
    final controller = await pump(tester);
    const otherGroup = 'Other';

    final profile = capturedRef.read(currentProfileProvider)!;
    capturedRef.read(profilesProvider.notifier).setProfile(
          profile.copyWith(
            selectedMap: {groupName: oldNode, otherGroup: oldNode},
          ),
        );

    fake.reject.add(otherGroup);
    controller.readBack = () => [
          group(groupName, newNode),
          group(otherGroup, oldNode),
        ];

    final ok = await controller.changeProxiesBatch({
      groupName: newNode,
      otherGroup: newNode,
    });

    expect(ok, isFalse);
    expect(selectedMap()[groupName], newNode, reason: 'accepted group keeps it');
    expect(
      selectedMap()[otherGroup],
      oldNode,
      reason: 'rejected group must revert on its own',
    );
  });

  testWidgets('read-back never landed — success is not reported', (
    tester,
  ) async {
    final controller = await pump(tester);
    fake.acceptAll = true;
    // Every `changeProxy` was accepted, but the core read-back returned stale
    // groups. Returning from `updateGroups()` proves nothing: `_updateGroups`
    // swallows its own failures.
    controller.readBack = () => [group(groupName, oldNode)];

    final ok = await controller.changeProxiesBatch({groupName: newNode});

    expect(
      ok,
      isFalse,
      reason: 'unverifiable must not be reported as verified',
    );
    expect(
      selectedMap()[groupName],
      oldNode,
      reason: 'an unconfirmed change must not stay in the selection map — '
          'returning false while the UI still shows the new node is a fake '
          'state, not a failure report',
    );
  });

  testWidgets('read-back omits the group — the optimistic write is undone', (
    tester,
  ) async {
    final controller = await pump(tester);
    fake.acceptAll = true;
    // The core answered, but the read-back does not contain the group at all.
    // Nothing can be proven about it.
    controller.readBack = () => const [];

    final ok = await controller.changeProxiesBatch({groupName: newNode});

    expect(ok, isFalse);
    expect(
      selectedMap()[groupName],
      oldNode,
      reason: 'a group the read-back never mentions is not a confirmed group',
    );
  });

  testWidgets('partial read-back — confirmed keeps, unconfirmed reverts, '
      'untouched groups survive', (tester) async {
    final controller = await pump(tester);
    const otherGroup = 'Other';
    const bystander = 'Bystander';

    // A group that is NOT part of the batch, with its own selection. The fix
    // must not disturb it.
    final profile = capturedRef.read(currentProfileProvider)!;
    capturedRef.read(profilesProvider.notifier).setProfile(
          profile.copyWith(
            selectedMap: {
              groupName: oldNode,
              otherGroup: oldNode,
              bystander: 'Node-Bystander',
            },
          ),
        );

    // No exception anywhere: both `changeProxy` calls "succeed". Only the
    // read-back tells them apart.
    fake.acceptAll = true;
    controller.readBack = () => [
          group(groupName, newNode), // confirmed
          group(otherGroup, oldNode), // core never moved
        ];

    final ok = await controller.changeProxiesBatch({
      groupName: newNode,
      otherGroup: newNode,
    });

    expect(ok, isFalse);
    expect(selectedMap()[groupName], newNode, reason: 'confirmed group keeps it');
    expect(
      selectedMap()[otherGroup],
      oldNode,
      reason: 'unconfirmed group reverts even though nothing threw',
    );
    expect(
      selectedMap()[bystander],
      'Node-Bystander',
      reason: 'a group outside the batch must not be touched',
    );
  });

  testWidgets('empty map — nothing to do, no core call, reported as success', (
    tester,
  ) async {
    final controller = await pump(tester);

    final ok = await controller.changeProxiesBatch(<String, String>{});

    expect(ok, isTrue, reason: 'an empty batch cannot half-apply');
    expect(fake.changeProxyCalls, isEmpty);
  });

  // ── chain layer: what "nothing to select" means ──────────────────────────
  //
  // In `direct` mode there is no selector at all, so `_autoSelectChainGroup`
  // builds an empty batch map. That is a genuine "nothing to drive", not a
  // failure — the config itself is the whole change.
  testWidgets('chain enable in direct mode — empty batch is success, not '
      'failure', (tester) async {
    final controller = await pump(tester);
    globalState.appController = controller;

    // `ChainProxyManager.init()` uses real timers, which never fire under the
    // fake async zone `testWidgets` installs — hence `runAsync`.
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('fluxora_d5_chain_');
      addTearDown(() async {
        ChainProxyManager.configFilePathOverride = null;
        ChainProxyManager.fallbackPoolFilePathOverride = null;
        ChainProxyManager.reliabilityStatsFilePathOverride = null;
        ChainProxyManager.coreConfigReloadOverride = null;
        ChainProxyManager.capabilityProbeSourceOverride = null;
        if (dir.existsSync()) await dir.delete(recursive: true);
      });

      String p(String name) => '${dir.path}${Platform.pathSeparator}$name';
      ChainProxyManager.configFilePathOverride = p('chain_proxies.json');
      ChainProxyManager.fallbackPoolFilePathOverride = p('chain_pool.json');
      ChainProxyManager.reliabilityStatsFilePathOverride = p('chain_stats.json');
      ChainProxyManager.coreConfigReloadOverride = () async {};
      ChainProxyManager.capabilityProbeSourceOverride = const [];

      capturedRef
          .read(patchClashConfigProvider.notifier)
          .updateState((state) => state.copyWith(mode: Mode.direct));

      ChainProxyManager.resetInstanceForTest();
      final manager = ChainProxyManager();
      await manager.init();

      final enabled = await manager.setEnable(true);

      expect(
        enabled,
        isTrue,
        reason: 'direct mode has no selector; nothing to drive is not a failure',
      );
      expect(
        fake.changeProxyCalls,
        isEmpty,
        reason: 'the chain must not touch a selector it does not have',
      );
    });
  });
}

/// A `ClashHandlerInterface` double.
///
/// Only the methods `changeProxiesBatch` can reach are real; everything else
/// throws if it is ever called, so an unexpected dependency surfaces instead of
/// silently returning null.
class _FakeClashCore implements ClashHandlerInterface {
  bool acceptAll = true;
  final Set<String> reject = <String>{};
  final List<String> changeProxyCalls = <String>[];

  @override
  FutureOr<String> changeProxy(ChangeProxyParams changeProxyParams) {
    final name = changeProxyParams.groupName;
    changeProxyCalls.add(name);
    if (!acceptAll || reject.contains(name)) {
      throw StateError('core rejected $name');
    }
    return '';
  }

  @override
  Future<bool> closeConnections() async => true;

  @override
  FutureOr<bool> flushDnsCache() => true;

  @override
  Future<String> getMode() async => 'rule';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'unexpected core call: ${invocation.memberName}',
    );
  }
}

/// An `AppController` whose core read-back is scripted.
///
/// The production `updateGroups()` goes through `Isolate.run` + a live core.
/// Overriding it keeps the test a pure Fake while still exercising the real
/// `changeProxiesBatch` body.
class _TestController extends AppController {
  _TestController(super.context, super.ref);

  List<Group> Function() readBack = () => const [];

  @override
  Future<void> updateGroups({List<ExternalProvider>? preloadedProviders}) async {
    ref.read(groupsProvider.notifier).value = readBack();
  }
}
