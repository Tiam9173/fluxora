import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/core.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/clash/service.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/providers/app.dart';
import 'package:fluxora/providers/state.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/proxies/common.dart';

class _DelayCore extends Fake implements ClashHandlerInterface {
  final requests = <String>[];
  final pending = <String, Completer<void>>{};
  bool completeImmediately = false;
  int peak = 0;

  @override
  Future<String> asyncTestDelay(String url, String proxyName) {
    requests.add(proxyName);
    final delay = jsonEncode(Delay(url: url, name: proxyName, value: 20));
    if (completeImmediately) {
      return Future.value(delay);
    }
    final result = pending[proxyName] = Completer<void>();
    if (pending.length > peak) peak = pending.length;
    return result.future.then((_) => delay);
  }

  void finish(String name) {
    pending.remove(name)!.complete();
  }

  void finishAll() {
    completeImmediately = true;
    for (final name in pending.keys.toList()) {
      finish(name);
    }
  }
}

void main() {
  setUpAll(() => ClashService.skipTransportForTest = true);
  const nodes = [
    Proxy(name: 'slow', type: 'vless'),
    Proxy(name: 'fast', type: 'vless'),
    Proxy(name: 'third', type: 'vless'),
    Proxy(name: 'fourth', type: 'vless'),
  ];

  late _DelayCore core;
  late WidgetRef ref;

  Future<void> setupBatch(WidgetTester tester) async {
    globalState.appState = AppState(
      viewSize: Size.zero,
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    final oldConfig = globalState.config;
    globalState.config = oldConfig.copyWith(
      currentProfileId: 'original',
      proxiesStyle: const ProxiesStyle(concurrencyLimit: 2),
    );
    core = _DelayCore();
    final original = clashCore.clashInterface;
    clashCore.clashInterface = core;
    addTearDown(() {
      globalState.config = oldConfig;
      clashCore.clashInterface = original;
    });
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            globalState.appController = AppController(context, ref);
            ref.watch(currentProfileIdProvider);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  testWidgets('finishing a node starts the next while a slow node runs', (
    tester,
  ) async {
    await setupBatch(tester);
    var callbacks = 0;
    final finished = delayTest(nodes, onDelayUpdated: () async => callbacks++);
    try {
      expect(core.requests, ['slow', 'fast']);
      core.finish('fast');
      await tester.pump();
      expect(core.requests, ['slow', 'fast', 'third']);
      expect(core.pending.keys, contains('slow'));
    } finally {
      core.finishAll();
      await finished;
    }
    expect(core.requests, ['slow', 'fast', 'third', 'fourth']);
    expect(core.peak, 2);
    expect(callbacks, 4);
  });

  testWidgets('batch retries a hidden node and shows it only after success', (
    tester,
  ) async {
    await setupBatch(tester);
    const group = Group(
      type: GroupType.Selector,
      name: 'test group',
      now: 'slow',
      all: [
        Proxy(name: 'slow', type: 'vless'),
        Proxy(name: 'fast', type: 'vless'),
      ],
      testUrl: 'https://fixture.invalid/204',
    );
    ref.read(groupsProvider.notifier).value = [group];
    ref
        .read(proxiesStyleSettingProvider.notifier)
        .updateState((state) => state.copyWith(hideTimeoutProxies: true));
    final url = globalState.appController.getRealTestUrl(group.testUrl);
    globalState.appController.setDelay(
      Delay(url: url, name: 'fast', value: -1),
    );
    List<Proxy> shown() =>
        ref.read(visibleGroupsStateProvider).value.single.all;
    expect(shown().map((node) => node.name), ['slow']);
    final done = delayTest(
      shown(),
      groupName: group.name,
      testUrl: group.testUrl,
    );
    try {
      expect(core.requests, ['slow', 'fast']);
      expect(shown().map((node) => node.name), ['slow']);
    } finally {
      core.finishAll();
      await done;
    }
    expect(shown().map((node) => node.name), ['slow', 'fast']);
  });

  testWidgets('changing profile stops dispatching queued nodes', (
    tester,
  ) async {
    await setupBatch(tester);
    final finished = delayTest(nodes);
    try {
      expect(core.requests, ['slow', 'fast']);
      ref.read(currentProfileIdProvider.notifier).value = 'new';
      core.finish('fast');
      await tester.pump();
      expect(core.requests, ['slow', 'fast']);
    } finally {
      core.finishAll();
      await finished;
    }
    expect(core.requests, ['slow', 'fast']);
  });
}
