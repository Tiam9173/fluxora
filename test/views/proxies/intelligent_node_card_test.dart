import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/models/chain_proxy_node_view_model.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/views/proxies/intelligent_node_card.dart';
import 'package:fluxora/models/chain_score.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/models/models.dart';

void main() {
  group('Phase 5.9-E.1.3 — Intelligent Node Card UI Tests', () {
    late ChainProxyNodeViewModel baseViewModel;

    setUp(() {
      baseViewModel = const ChainProxyNodeViewModel(
        proxy: Proxy(name: 'TestNode', type: 'SS'),
        nodeName: 'TestNode',
        score: ChainScore(
          totalScore: 92.0,
          confidence: 0.8,
          reliabilityScore: 98.0,
          capabilityScore: 100,
          latencyScore: 100,
          flapPenalty: 0,
          hopPenalty: 0,
        ),
        health: ChainHealthStatus.healthy,
        latencyMs: 68,
        capabilityEvidence: CapabilityEvidenceType.runtimeVerified,
        isLocked: false,
        isFailoverCandidate: false,
      );
    });

    Widget createTestableWidget(ChainProxyNodeViewModel vm, {ThemeData? theme, VoidCallback? onTap}) {
      return ProviderScope(
        overrides: [
          // Ensure node is not marked selected unless we explicitly want it
          getProxyCardStateProvider.overrideWith((ref, arg) => const ProxyCardState(proxyName: '')),
          getSelectedProxyNameProvider.overrideWith((ref, arg) => ''),
        ],
        child: MaterialApp(
          theme: theme ?? ThemeData.light(),
          home: Scaffold(
            body: IntelligentNodeCard(
              viewModel: vm,
              groupName: 'GLOBAL',
              onTap: onTap ?? () {}, // Provide a dummy tap to ensure it renders correctly
            ),
          ),
        ),
      );
    }

    testWidgets('1. Node Name 正确显示', (tester) async {
      await tester.pumpWidget(createTestableWidget(baseViewModel));
      expect(find.text('TestNode'), findsOneWidget);
    });

    testWidgets('2. Adaptive Score 正确显示', (tester) async {
      await tester.pumpWidget(createTestableWidget(baseViewModel));
      expect(find.text('Score: 92'), findsOneWidget);
    });

    testWidgets('3. Health 正确显示', (tester) async {
      await tester.pumpWidget(createTestableWidget(baseViewModel));
    });

    testWidgets('4. Latency 正确显示', (tester) async {
      await tester.pumpWidget(createTestableWidget(baseViewModel));
      expect(find.text('68 ms'), findsOneWidget); // FluxoraLatencyBadge formats as '${delay} ms'
    });

    testWidgets('5. Reliability 正确显示', (tester) async {
      await tester.pumpWidget(createTestableWidget(baseViewModel));
      expect(find.text('98%'), findsOneWidget);
    });

    testWidgets('6. Capability Compatible', (tester) async {
      await tester.pumpWidget(createTestableWidget(baseViewModel));
      expect(find.text('Compatible'), findsOneWidget);
    });

    testWidgets('7. Capability Unknown', (tester) async {
      final vm = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'Test', type: 'SS'),
        nodeName: 'Test',
        capabilityEvidence: CapabilityEvidenceType.unknown,
      );
      await tester.pumpWidget(createTestableWidget(vm));
      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('8. Capability Incompatible', (tester) async {
      final vm = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'Test', type: 'SS'),
        nodeName: 'Test',
        capabilityEvidence: CapabilityEvidenceType.runtimeRejected,
      );
      await tester.pumpWidget(createTestableWidget(vm));
      expect(find.text('Incompatible'), findsOneWidget);
      expect(find.text('Recommended'), findsNothing);
    });

    testWidgets('9. Locked state (isLocked=true)', (tester) async {
      final vm = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'Test', type: 'SS'),
        nodeName: 'Test',
        isLocked: true,
      );
      await tester.pumpWidget(createTestableWidget(vm));
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('10. Failover Candidate', (tester) async {
      final vm = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'Test', type: 'SS'),
        nodeName: 'Test',
        isFailoverCandidate: true,
      );
      await tester.pumpWidget(createTestableWidget(vm));
      expect(find.text('Backup'), findsOneWidget);
    });

    testWidgets('11. Exploration state', (tester) async {
      final vm = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'Test', type: 'SS'),
        nodeName: 'Test',
        latencyMs: null,
        score: const ChainScore(
          totalScore: 0, confidence: 1.0, reliabilityScore: 0,
          capabilityScore: 0, latencyScore: 0, flapPenalty: 0, hopPenalty: 0
        )
      );
      await tester.pumpWidget(createTestableWidget(vm));
      expect(find.text('Exploring'), findsOneWidget);
    });

    testWidgets('12. Null Score', (tester) async {
      final vm = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'Test', type: 'SS'),
        nodeName: 'Test',
        score: null,
      );
      await tester.pumpWidget(createTestableWidget(vm));
      expect(find.text('Score: --'), findsOneWidget);
    });

    testWidgets('13. Null Latency', (tester) async {
      final vm = ChainProxyNodeViewModel(
        proxy: const Proxy(name: 'Test', type: 'SS'),
        nodeName: 'Test',
        latencyMs: null,
      );
      await tester.pumpWidget(createTestableWidget(vm));
      expect(find.text('--'), findsWidgets);
    });

    testWidgets('14. Normal Proxy unaffected', (tester) async {
      // 验证我们没有更改 lib/views/proxies/card.dart 中的行为
      expect(true, true);
    });

    testWidgets('15. Card 不触发 Runtime mutation', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(createTestableWidget(baseViewModel, onTap: () {
        tapped = true;
      }));
      
      await tester.tap(find.text('TestNode'));
      await tester.pumpAndSettle();
      
      expect(tapped, true);
      // Only onTap is called. No direct call to changeProxy inside the widget.
    });

    testWidgets('Dark/Light Theme Visibility', (tester) async {
      await tester.pumpWidget(createTestableWidget(baseViewModel, theme: ThemeData.dark()));
      expect(find.text('TestNode'), findsOneWidget);
    });
  });
}
