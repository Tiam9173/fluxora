import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/app.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/providers/state.dart';
import 'package:fluxora/state.dart';

/// What actually refreshes the proxies page's sort order.
///
/// The reported symptom: after a delay test the list keeps its old order, and
/// only selecting a node makes it re-sort.
///
/// Comparing **state values** rather than counting listener callbacks: with
/// auto-dispose providers a `container.listen` subscription can be dropped
/// between reads, which silently makes an emission counter report 0 for every
/// provider — a false "nothing rebuilds".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

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
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  test('control: the sort type reaches the tab state', () {
    final before = container.read(proxiesTabStateProvider).proxiesSortType;

    container
        .read(proxiesStyleSettingProvider.notifier)
        .updateState((s) => s.copyWith(sortType: ProxiesSortType.name));

    final after = container.read(proxiesTabStateProvider).proxiesSortType;

    expect(after, isNot(before), reason: 'harness sanity check');
  });

  test('a sortNum bump reaches the tab state', () {
    final before = container.read(proxiesTabStateProvider).sortNum;

    container.read(sortNumProvider.notifier).add();

    final after = container.read(proxiesTabStateProvider).sortNum;

    expect(after, isNot(before), reason: 'the tab view must re-sort');
  });

  test('a sortNum bump reaches the list state', () {
    final before = container.read(proxiesListStateProvider).sortNum;

    container.read(sortNumProvider.notifier).add();

    final after = container.read(proxiesListStateProvider).sortNum;

    expect(after, isNot(before), reason: 'the list view must re-sort');
  });

  test('the delay value is readable right after it is written', () {
    container
        .read(delayDataSourceProvider.notifier)
        .setDelay(const Delay(url: 'https://x', name: 'Node-A', value: 42));

    expect(container.read(delayDataSourceProvider)['https://x']?['Node-A'], 42);
  });

  test('the appState copy follows the provider even with no listeners', () {
    // `lib/views/proxies/list.dart` keys its sliver cache on
    // `globalState.appState.delayMap` — a copy that `DelayDataSource.onUpdate`
    // writes through `updateShouldNotify`. If that copy lags the provider, the
    // cache key stays identical and the list keeps its old order.
    expect(globalState.appState.delayMap, isEmpty);

    container
        .read(delayDataSourceProvider.notifier)
        .setDelay(const Delay(url: 'https://x', name: 'Node-A', value: 42));

    expect(
      globalState.appState.delayMap['https://x']?['Node-A'],
      42,
      reason: 'the cache key source must track the provider',
    );
  });
}
