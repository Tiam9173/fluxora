import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';

/// Does the production delay sort place **every** measured node by latency?
///
/// Reported symptom (tab-style proxies page, obvious with many nodes): after a
/// speed test some nodes that do show a delay keep their old position; tapping
/// one of them makes the list re-sort immediately.
///
/// `getSortProxies` resolves each node's delay through `getDelayProvider`
/// **inside the comparator**, so a large group issues O(n log n) provider
/// reads during build. This drives the real `AppController` and the real
/// provider chain — delays are written through the same `setDelay` the probe
/// uses — and checks the resulting order at two sizes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WidgetRef ref;
  late AppController controller;
  late String testUrl;

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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, r, child) {
            ref = r;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    controller = AppController(
      tester.element(find.byType(SizedBox).first),
      ref,
    );
    testUrl = ref.read(appSettingProvider).testUrl;
  }

  /// Node `n<i>` gets latency `(i * 7) % 400 + 3` — a non-monotonic mapping, so
  /// a list that is merely "already in order" cannot pass by accident.
  int latencyOf(int i) => (i * 7) % 400 + 3;

  testWidgets(
    'manual latency survives health checks before and after startup',
    (tester) async {
      await pump(tester);
      final savedStart = globalState.startTime;
      addTearDown(() => globalState.startTime = savedStart);
      globalState.startTime = DateTime.now();
      final measured = Delay(url: testUrl, name: 'n0', value: 42);
      final timeout = measured.copyWith(value: -1);
      int? latency() => ref.read(delayDataSourceProvider)[testUrl]?['n0'];

      controller.setDelay(measured.copyWith(value: 0));
      controller.setDelay(timeout, background: true);
      expect(latency(), 0);
      controller.setDelay(measured);
      controller.setDelay(timeout, background: true);
      controller.setDelay(timeout, startup: true);
      expect(latency(), 42);
      controller.setDelay(timeout.copyWith(name: 'n1'), background: true);
      expect(ref.read(delayDataSourceProvider)[testUrl]?['n1'], -1);
      controller.setDelay(measured.copyWith(value: 68), background: true);
      controller.setDelay(measured.copyWith(value: 72), startup: true);
      expect(latency(), 42);
      controller.setDelay(timeout);
      expect(latency(), -1);

      controller.setDelay(measured);
      globalState.startTime = DateTime.now().subtract(
        const Duration(minutes: 1),
      );
      controller.setDelay(timeout, background: true);
      controller.setDelay(measured.copyWith(value: 91), background: true);
      expect(latency(), 42);
      controller.setDelay(timeout);
      controller.setDelay(measured, background: true);
      expect(latency(), -1);

      final otherUrl = '$testUrl?fixture=1';
      controller.setDelay(measured.copyWith(url: otherUrl), background: true);
      expect(ref.read(delayDataSourceProvider)[otherUrl]?['n0'], 42);
      controller.setDelay(measured.copyWith(name: 'n1'), background: true);
      expect(ref.read(delayDataSourceProvider)[testUrl]?['n1'], 42);
    },
  );

  Future<List<String>> sortedNames(WidgetTester tester, int count) async {
    await pump(tester);
    final names = [for (var i = 0; i < count; i++) 'n$i'];
    for (var i = 0; i < count; i++) {
      controller.setDelay(Delay(url: testUrl, name: 'n$i', value: latencyOf(i)));
    }
    final proxies = [for (final n in names) Proxy(name: n, type: 'vless')];
    final sorted = controller.getSortProxies(
      proxies: proxies,
      sortType: ProxiesSortType.delay,
    );
    return [for (final p in sorted) p.name];
  }

  testWidgets('small group: every measured node is in latency order', (
    tester,
  ) async {
    const count = 8;
    final actual = await sortedNames(tester, count);
    final expected = [
      for (var i = 0; i < count; i++) i,
    ]..sort((a, b) => latencyOf(a).compareTo(latencyOf(b)));

    expect(actual, [for (final i in expected) 'n$i']);
  });

  testWidgets('large group: every measured node is in latency order', (
    tester,
  ) async {
    const count = 300;
    final actual = await sortedNames(tester, count);
    final expected = [
      for (var i = 0; i < count; i++) i,
    ]..sort((a, b) => latencyOf(a).compareTo(latencyOf(b)));

    expect(
      actual,
      [for (final i in expected) 'n$i'],
      reason: 'a measured node must never be left where it started',
    );
  });
}
