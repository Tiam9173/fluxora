import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/chain_proxy_node_view_model.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/adaptive_ranking_provider.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/proxies/intelligent_node_picker_sheet.dart';
import 'package:fluxora/widgets/sheet.dart';

/// item 2 — the entry-hop picker offers **policy groups**, not only concrete
/// nodes.
///
/// The generation side is pinned in `test/models/chain_proxy_test.dart`; this
/// file pins the picker's list arithmetic — the group section must sit between
/// DIRECT and the node cards, and must render even when there are zero nodes.
///
/// `adaptiveRankingProvider` is overridden wholesale, so this test never touches
/// the process-wide `chainProxyManager` singleton.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.load(const Locale('zh', 'CN'));
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

  Widget buildSheet({
    required List<Group> groups,
    List<ChainProxyNodeViewModel> nodes = const [],
  }) {
    return ProviderScope(
      overrides: [
        groupsProvider.overrideWithValue(groups),
        adaptiveRankingProvider.overrideWith((ref, params) => nodes),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: IntelligentNodePickerSheet(
            title: 'T',
            currentHop: '',
            excludedHops: const {},
            allowDirect: true,
            allowFollowMain: false,
            onSelect: (_) {},
            role: FallbackCandidateRole.entry,
            sheetType: SheetType.page,
          ),
        ),
      ),
    );
  }

  Group selectorGroup(String name) =>
      Group(type: GroupType.Selector, name: name, all: const []);

  testWidgets('item 2 — 无具体节点时仍展示策略组分区', (tester) async {
    await tester.pumpWidget(buildSheet(groups: [selectorGroup('🔰 节点选择')]));
    await tester.pumpAndSettle();

    expect(find.text('🔰 节点选择'), findsOneWidget);
  });

  testWidgets('item 2 — 链式专用组不出现在可选策略组中', (tester) async {
    await tester.pumpWidget(
      buildSheet(
        groups: [
          selectorGroup('🔗 链式代理'),
          selectorGroup('✈️ 链式跳板'),
          selectorGroup('🔰 节点选择'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🔰 节点选择'), findsOneWidget);
    expect(find.text('🔗 链式代理'), findsNothing);
    expect(find.text('✈️ 链式跳板'), findsNothing);
  });

  testWidgets('item 2 — 策略组与具体节点共存时两者都渲染', (tester) async {
    await tester.pumpWidget(
      buildSheet(
        groups: [selectorGroup('🔰 节点选择')],
        nodes: [
          ChainProxyNodeViewModel(
            proxy: const Proxy(name: 'Tokyo-01', type: 'vless'),
            nodeName: 'Tokyo-01',
          ),
          ChainProxyNodeViewModel(
            proxy: const Proxy(name: 'Osaka-02', type: 'hysteria2'),
            nodeName: 'Osaka-02',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🔰 节点选择'), findsOneWidget);
    // The node cards follow the group section — an off-by-one in the index
    // arithmetic would drop or duplicate these.
    expect(find.text('Tokyo-01'), findsOneWidget);
    expect(find.text('Osaka-02'), findsOneWidget);
  });
}
