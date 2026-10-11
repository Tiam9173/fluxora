import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_proxy_node_view_model.dart';
import 'package:fluxora/models/common.dart';

/// P1.3-C4-Step5 — the 「延迟」 sort rule (`ChainProxyNodeViewModel.compareByLatency`).
///
/// Decision Q1 + Q7: the rule is extracted so it is independently testable (no
/// provider harness needed), and it must:
///   · rank nodes that have a valid latency first, ascending;
///   · sink unknowns (`latencyMs == null`) to the end;
///   · keep unknowns — and equal values — in a deterministic name order, since
///     `List.sort` is not stable;
///   · never treat `null` as `0 ms`.
void main() {
  ChainProxyNodeViewModel node(String name, int? latencyMs) {
    return ChainProxyNodeViewModel(
      proxy: Proxy(name: name, type: 'SS'),
      nodeName: name,
      latencyMs: latencyMs,
    );
  }

  List<String> sortedNames(List<ChainProxyNodeViewModel> nodes) {
    final list = [...nodes]..sort(ChainProxyNodeViewModel.compareByLatency);
    return list.map((n) => n.nodeName).toList();
  }

  group('ChainProxyNodeViewModel.compareByLatency — Step5 latency sort', () {
    test('C1. valid latencies first (ascending), unknown sinks to the end', () {
      expect(
        sortedNames([node('C-unknown', null), node('B-200ms', 200), node('A-50ms', 50)]),
        ['A-50ms', 'B-200ms', 'C-unknown'],
      );
    });

    test('C2. unknowns keep a deterministic (name) order — List.sort is unstable',
        () {
      expect(
        sortedNames([node('UnknownB', null), node('UnknownA', null)]),
        ['UnknownA', 'UnknownB'],
      );
    });

    test('C3. equal latencies fall back to name order', () {
      expect(
        sortedNames([node('Zeta', 100), node('Alpha', 100)]),
        ['Alpha', 'Zeta'],
      );
    });

    test('C4. null is NOT treated as 0 ms', () {
      expect(
        sortedNames([node('Unknown', null), node('Zero', 0)]),
        ['Zero', 'Unknown'],
        reason: 'a 0 ms reading must still outrank a missing one',
      );
    });
  });
}
