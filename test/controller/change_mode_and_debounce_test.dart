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
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';

/// Fake Core only. No real core, socket, TUN, DNS, route or system proxy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

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

  /// Exercises the same selection entry point as the node card and tray.
  void selectFromCard(AppController controller, String group, String node) {
    controller.selectProxy(group, node);
  }

  // ── Node selection ───────────────────────────────────────────────────────

  testWidgets('a native error string preserves the confirmed node', (
    tester,
  ) async {
    final controller = await pump(tester, selected: {groupName: oldNode});
    fake.nativeError = true;
    selectFromCard(controller, groupName, newNode);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(selectedMap()[groupName], oldNode);
  });

  testWidgets('node selection preserves the previous choice on rejection', (
    tester,
  ) async {
    final controller = await pump(tester, selected: {groupName: oldNode});
    fake.acceptAll = false;

    selectFromCard(controller, groupName, newNode);

    // A pending request must not overwrite the last confirmed choice.
    expect(selectedMap()[groupName], oldNode);

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

  testWidgets(
    'rapid choices preserve the last confirmed node if the next fails',
    (tester) async {
      final controller = await pump(tester, selected: {groupName: oldNode});
      final first = Completer<void>();
      fake.beforeChange = (params) async {
        if (params.proxyName == newNode) await first.future;
        if (params.proxyName == dedicated) throw StateError('rejected');
      };
      controller.readBack = () => [group(groupName, newNode)];
      selectFromCard(controller, groupName, newNode);
      selectFromCard(controller, groupName, dedicated);
      await tester.pump();
      expect(selectedMap()[groupName], oldNode);
      first.complete();
      await tester.pump();
      expect(fake.changes, [(groupName, newNode), (groupName, dedicated)]);
      expect(selectedMap()[groupName], newNode);
    },
  );

  testWidgets('a successful write without matching readback is not saved', (
    tester,
  ) async {
    final controller = await pump(tester, selected: {groupName: oldNode});
    fake.confirmSelection = false;
    await expectLater(
      controller.changeProxy(groupName: groupName, proxyName: newNode),
      throwsStateError,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(selectedMap()[groupName], oldNode);
  });

  testWidgets('a manual url-test selection is explicitly persisted as a lock', (
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
      newNode,
      reason:
          'native Set is a persistent override, so the UI must expose its lock',
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

  testWidgets('an unlocked url-test group lets the native health policy select', (
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
      contains((groupName, '')),
      reason:
          'clearing ForceSet resumes native health/tolerance instead of relocking',
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
  bool nativeError = false;
  final Set<String> reject = <String>{};
  final List<String> changeProxyCalls = <String>[];
  final List<(String, String)> changes = <(String, String)>[];
  final Map<String, String> selections = {};
  bool confirmSelection = true;
  Future<void> Function(ChangeProxyParams)? beforeChange;

  @override
  Future<String> changeProxy(ChangeProxyParams changeProxyParams) async {
    final name = changeProxyParams.groupName;
    changeProxyCalls.add(name);
    changes.add((name, changeProxyParams.proxyName));
    if (nativeError) return 'proxy not exist';
    if (!acceptAll || reject.contains(name)) {
      throw StateError('core rejected $name');
    }
    await beforeChange?.call(changeProxyParams);
    if (confirmSelection) selections[name] = changeProxyParams.proxyName;
    return '';
  }

  @override
  Future<Map> getProxies() async => {
    for (final entry in selections.entries)
      entry.key: {'now': entry.value, 'fixed': entry.value},
  };

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
  Future<void> updateGroups({
    List<ExternalProvider>? preloadedProviders,
  }) async {
    ref.read(groupsProvider.notifier).value = readBack();
  }
}
