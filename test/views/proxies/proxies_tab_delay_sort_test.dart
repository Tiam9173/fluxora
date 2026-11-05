import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/proxies/card.dart';
import 'package:fluxora/views/proxies/tab.dart';

/// The tab-style proxies page: does a finished delay test actually re-render
/// the new order?
///
/// Reported symptom: after a speed test some nodes that show a delay keep their
/// old position, and tapping one of them re-sorts immediately — obvious when
/// the group has many nodes.
///
/// The sort *function* is already proven correct
/// (`test/controller/delay_sort_production_test.dart`, 300 nodes). This drives
/// the real `ProxyGroupView` instead: delays land, then `sortNum` bumps (what
/// `delayTest` does at the end), and the rendered order is read back.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  late WidgetRef ref;
  late AppController controller;
  late String testUrl;

  setUp(() {
    globalState.appState = AppState(
      viewSize: const Size(400, 900),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
  });

  int latencyOf(int i) => (i * 7) % 400 + 3;

  /// Pumps the real group view; returns the notifier that stands in for
  /// `sortNumProvider`.
  Future<ValueNotifier<num>> pumpGroup(
    WidgetTester tester,
    List<String> names,
  ) async {
    final sortNum = ValueNotifier<num>(0);
    // `ProxyGroupView` reads `globalState.appController` while building, and
    // that controller needs a `BuildContext` — so the tree is mounted once as a
    // placeholder, the controller is bound, and only then is the real view
    // swapped in. Same `ProviderScope` throughout, so the delays written below
    // stay in the container the view reads.
    final ready = ValueNotifier<bool>(false);
    final group = Group(
      type: GroupType.Selector,
      name: 'G',
      all: [for (final n in names) Proxy(name: n, type: 'vless')],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (ctx) {
              globalState.theme = CommonTheme.of(ctx, 1.0);
              globalState.measure = Measure.of(ctx, 1.0);
              return Consumer(
                builder: (context, r, child) {
                  ref = r;
                  return Scaffold(
                    body: ValueListenableBuilder<bool>(
                      valueListenable: ready,
                      builder: (context, isReady, child) {
                        if (!isReady) return const SizedBox.shrink();
                        return ValueListenableBuilder<num>(
                          valueListenable: sortNum,
                          builder: (context, sn, child) => ProxyGroupView(
                            group: group,
                            columns: 1,
                            cardType: ProxyCardType.shrink,
                            sortType: ProxiesSortType.delay,
                            sortNum: sn,
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    controller = AppController(
      tester.element(find.byType(Scaffold).first),
      ref,
    );
    globalState.appController = controller;
    testUrl = ref.read(appSettingProvider).testUrl;

    ready.value = true;
    await tester.pump();
    return sortNum;
  }

  /// Node names in the order the grid actually lays them out.
  ///
  /// Read from the widgets rather than from rendered text: the card renders its
  /// name through `EmojiText`, so a `Text` scan finds nothing.
  List<String> renderedNames(WidgetTester tester) => [
    for (final card in tester.widgetList<ProxyCard>(find.byType(ProxyCard)))
      card.proxy.name,
  ];

  testWidgets('finishing a test re-renders the delay order (8 nodes)', (
    tester,
  ) async {
    const count = 8;
    final names = [for (var i = 0; i < count; i++) 'n$i'];
    final sortNum = await pumpGroup(tester, names);

    // Nothing tested yet: the list keeps the order it arrived in (only the
    // cards inside the viewport are built, so compare that prefix).
    final initial = renderedNames(tester);
    expect(initial, isNotEmpty);
    expect(initial, names.take(initial.length));

    for (var i = 0; i < count; i++) {
      controller.setDelay(Delay(url: testUrl, name: 'n$i', value: latencyOf(i)));
    }
    // What `delayTest` does once every probe has landed.
    controller.addSortNum();
    sortNum.value = 1;
    await tester.pump();

    final expected = [for (var i = 0; i < count; i++) i]
      ..sort((a, b) => latencyOf(a).compareTo(latencyOf(b)));

    final rendered = renderedNames(tester);
    expect(rendered, [for (final i in expected.take(rendered.length)) 'n$i']);
  });

  testWidgets('finishing a test re-renders the delay order (120 nodes)', (
    tester,
  ) async {
    const count = 120;
    final names = [for (var i = 0; i < count; i++) 'n$i'];
    final sortNum = await pumpGroup(tester, names);

    for (var i = 0; i < count; i++) {
      controller.setDelay(Delay(url: testUrl, name: 'n$i', value: latencyOf(i)));
    }
    controller.addSortNum();
    sortNum.value = 1;
    await tester.pump();

    final expected = [for (var i = 0; i < count; i++) i]
      ..sort((a, b) => latencyOf(a).compareTo(latencyOf(b)));

    // Only the visible prefix is built by the lazy grid, so compare what is
    // actually rendered against the same prefix of the expected order.
    final rendered = renderedNames(tester);
    expect(rendered, isNotEmpty);
    expect(rendered, [for (final i in expected.take(rendered.length)) 'n$i']);
  });
}
