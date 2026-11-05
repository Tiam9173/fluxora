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

/// Phase 11 — the two remaining optimistic-write paths.
///
/// Both have the same shape as D5: write the selection map first, then talk to
/// the core, and never undo the write when the core refuses.
///
/// * `changeProxyDebounce` — the write happens in `card.dart` before the call;
///   the debounced callback discards its future, so a rejection becomes an
///   unhandled async error *and* leaves the fake selection in place.
/// * `changeMode` — writes the selection map per group before `changeProxy`,
///   then only logs a failure.
///
/// Fake Core only. No real core, socket, TUN, DNS, route or system proxy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeClashCore fake;
  late WidgetRef capturedRef;
  late Directory tmp;

  const groupName = 'Proxy';
  const oldNode = 'Node-Old';
  const newNode = 'Node-New';
  const dedicated = '🔗 链式代理';

  Group group(String name, String now) => Group(
        type: GroupType.Selector,
        name: name,
        now: now,
        all: [
          Proxy(name: oldNode, type: 'vless'),
          Proxy(name: newNode, type: 'vless'),
          Proxy(name: dedicated, type: 'selector'),
        ],
      );

  setUp(() async {
    fake = _FakeClashCore();
    clashCore.clashInterface = fake;

    // `_updateClashConfig` awaits `preferences.sharedPreferencesCompleter` on
    // desktop, which never completes under the test binding. Non-desktop keeps
    // that branch out of the way; nothing else in these paths depends on it.
    System.platformOverride = 'android';

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

    tmp = await Directory.systemTemp.createTemp('fluxora_p11_');
    String p(String name) => '${tmp.path}${Platform.pathSeparator}$name';
    ChainProxyManager.configFilePathOverride = p('chain_proxies.json');
    ChainProxyManager.fallbackPoolFilePathOverride = p('chain_pool.json');
    ChainProxyManager.reliabilityStatsFilePathOverride = p('chain_stats.json');
    ChainProxyManager.coreConfigReloadOverride = () async {};
    ChainProxyManager.capabilityProbeSourceOverride = const [];
    ChainProxyManager.resetInstanceForTest();
    final chain = ChainProxyManager();
    await chain.init();
    // `changeMode` only builds a batch when the chain is on.
    await chain.updateConfig((c) => c.copyWith(enable: true));
  });

  tearDown(() async {
    System.platformOverride = null;
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    ChainProxyManager.coreConfigReloadOverride = null;
    ChainProxyManager.capabilityProbeSourceOverride = null;
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<_TestController> pump(
    WidgetTester tester, {
    Map<String, String> selected = const {},
  }) async {
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

    final controller = _TestController(
      tester.element(find.byType(SizedBox).first),
      capturedRef,
    );

    final profile = Profile.normal(
      label: 'P11',
    ).copyWith(selectedMap: {...selected});
    capturedRef.read(profilesProvider.notifier).setProfile(profile);
    capturedRef.read(currentProfileIdProvider.notifier).value = profile.id;
    controller.readBack = () => [group(groupName, oldNode)];

    return controller;
  }

  Map<String, String> selectedMap() =>
      capturedRef.read(currentProfileProvider)?.selectedMap ??
      <String, String>{};

  /// Mirrors `card.dart` — the only production caller.
  ///
  /// That caller hands the whole job to the controller; the controller writes
  /// the optimistic selection itself so it can undo it on rejection.
  void selectFromCard(AppController controller, String group, String node) {
    controller.changeProxyDebounce(group, node);
  }

  // ── changeProxyDebounce ──────────────────────────────────────────────────

  testWidgets('debounced select — core rejects, the optimistic write reverts', (
    tester,
  ) async {
    final controller = await pump(tester, selected: {groupName: oldNode});
    fake.acceptAll = false;

    selectFromCard(controller, groupName, newNode);

    // The optimistic write is still immediate — that part must not change.
    expect(
      selectedMap()[groupName],
      newNode,
      reason: 'the UI still updates before the debounce fires',
    );

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();

    expect(
      selectedMap()[groupName],
      oldNode,
      reason: 'a rejected debounced select must not stay on screen',
    );
  });

  testWidgets('debounced select — core accepts, the selection stays', (
    tester,
  ) async {
    final controller = await pump(tester, selected: {groupName: oldNode});
    fake.acceptAll = true;
    controller.readBack = () => [group(groupName, newNode)];

    selectFromCard(controller, groupName, newNode);

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();

    expect(selectedMap()[groupName], newNode);
  });

  // ── url-test groups must not be locked by a tap ──────────────────────────

  testWidgets('a tap on a url-test group switches it without locking it', (
    tester,
  ) async {
    final controller = await pump(tester, selected: {groupName: oldNode});
    // The group the proxies page would show for 自动选择.
    controller.readBack = () => [
          Group(
            type: GroupType.URLTest,
            name: groupName,
            now: oldNode,
            all: [
              Proxy(name: oldNode, type: 'vless'),
              Proxy(name: newNode, type: 'vless'),
            ],
          ),
        ];
    await controller.updateGroups();
    fake.acceptAll = true;

    selectFromCard(controller, groupName, newNode);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();

    expect(
      fake.changeProxyCalls,
      contains(groupName),
      reason: 'the tap must still switch the node',
    );
    expect(
      selectedMap()[groupName],
      isNot(newNode),
      reason: 'persisting the pick would lock the group and stop auto-select',
    );
  });

  // ── auto-select: jump to the fastest measured node ───────────────────────

  Group urlTestGroup(String now) => Group(
        type: GroupType.URLTest,
        name: groupName,
        now: now,
        all: [
          Proxy(name: oldNode, type: 'vless'),
          Proxy(name: newNode, type: 'vless'),
          Proxy(name: 'Slow', type: 'vless'),
        ],
      );

  testWidgets('an unlocked url-test group jumps to the fastest node', (
    tester,
  ) async {
    final controller = await pump(tester);
    controller.readBack = () => [urlTestGroup(oldNode)];
    await controller.updateGroups();

    final url = capturedRef.read(appSettingProvider).testUrl;
    controller.setDelay(Delay(url: url, name: oldNode, value: 300));
    controller.setDelay(Delay(url: url, name: newNode, value: 40));
    controller.setDelay(Delay(url: url, name: 'Slow', value: 500));
    fake.acceptAll = true;

    await controller.selectFastestForGroup(groupName);

    expect(
      fake.changes,
      contains((groupName, newNode)),
      reason: 'the core only re-tests on its interval; we already know the winner',
    );
  });

  testWidgets('a locked url-test group is left alone', (tester) async {
    final controller = await pump(tester, selected: {groupName: oldNode});
    controller.readBack = () => [urlTestGroup(oldNode)];
    await controller.updateGroups();

    final url = capturedRef.read(appSettingProvider).testUrl;
    controller.setDelay(Delay(url: url, name: newNode, value: 40));
    fake.acceptAll = true;

    await controller.selectFastestForGroup(groupName);

    expect(
      fake.changes,
      isEmpty,
      reason: 'a lock is the user saying "do not move this"',
    );
  });

  // ── changeMode ───────────────────────────────────────────────────────────

  testWidgets('changeMode — a rejected group sync is rolled back', (
    tester,
  ) async {
    // GLOBAL already points at the chain, so switching to global mode wants to
    // re-assert the dedicated group on GLOBAL.
    final controller = await pump(tester, selected: {'Other': dedicated});
    fake.reject.add('GLOBAL');

    await controller.changeMode(Mode.global);
    // Drain the debounced `updateGroups` / `addCheckIpNum` timers and the 2 s
    // idle GC that `_updateClashConfig` schedules.
    await tester.pump(const Duration(seconds: 3));

    expect(
      selectedMap()['GLOBAL'],
      isNot(dedicated),
      reason: 'the core refused the GLOBAL change; keeping it is a fake state',
    );
  });

  testWidgets('changeMode — an accepted group sync is kept', (tester) async {
    final controller = await pump(tester, selected: {'Other': dedicated});
    fake.acceptAll = true;

    await controller.changeMode(Mode.global);
    await tester.pump(const Duration(seconds: 3));

    expect(selectedMap()['GLOBAL'], dedicated);
  });
}

/// Core double: only the methods these paths reach are real.
class _FakeClashCore implements ClashHandlerInterface {
  bool acceptAll = true;
  final Set<String> reject = <String>{};
  final List<String> changeProxyCalls = <String>[];
  final List<(String, String)> changes = <(String, String)>[];

  @override
  FutureOr<String> changeProxy(ChangeProxyParams changeProxyParams) {
    final name = changeProxyParams.groupName;
    changeProxyCalls.add(name);
    changes.add((name, changeProxyParams.proxyName));
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

  /// `_updateClashConfig` schedules an idle GC 2 s after a successful push.
  @override
  Future<bool> forceGc({bool forceFreeOSMemory = false}) async => true;

  /// `_updateClashConfig` throws when the core answers with a message.
  @override
  Future<String> updateConfig(UpdateParams updateParams) async => '';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('unexpected core call: ${invocation.memberName}');
  }
}

/// `AppController` whose core read-back is scripted instead of hitting a core.
class _TestController extends AppController {
  _TestController(super.context, super.ref);

  List<Group> Function() readBack = () => const [];

  @override
  Future<void> updateGroups({List<ExternalProvider>? preloadedProviders}) async {
    ref.read(groupsProvider.notifier).value = readBack();
  }
}
