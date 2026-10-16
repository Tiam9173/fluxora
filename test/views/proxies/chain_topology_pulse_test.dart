import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/views/proxies/chain_proxy_view.dart';

/// item 3-B / D7 — the topology-node pulse contract.
///
/// The pulse is deliberately expressed as pure functions so its rules can be
/// pinned without pumping the whole chain view (which needs the probe report
/// provider and a booted controller).
///
/// Brand rules being enforced (`D4_BRAND_PROPOSAL.md` §10.3–§10.5):
/// * only a probe that is actually in flight pulses;
/// * reduced motion disables looping entirely;
/// * the halo is a separate, fading layer — the node content itself is never
///   scaled (§10.4 caps scale changes at 1.1×).
void main() {
  group('pulse gating', () {
    test('only a probe in flight pulses', () {
      expect(
        topologyNodePulses(TopologySegmentState.checking, reduceMotion: false),
        isTrue,
      );
      for (final state in const [
        TopologySegmentState.healthy,
        TopologySegmentState.failed,
        TopologySegmentState.unknown,
        TopologySegmentState.notProbed,
      ]) {
        expect(
          topologyNodePulses(state, reduceMotion: false),
          isFalse,
          reason: '$state must be static',
        );
      }
    });

    test('reduced motion disables the loop for every state', () {
      for (final state in TopologySegmentState.values) {
        expect(
          topologyNodePulses(state, reduceMotion: true),
          isFalse,
          reason: '$state must not loop under reduced motion',
        );
      }
    });
  });

  group('halo geometry (§10.4: no scale on the content, no flash)', () {
    test('starts at the icon size and grows monotonically', () {
      expect(topologyHaloDiameter(0), 18);
      expect(topologyHaloDiameter(0.5), 24);
      expect(topologyHaloDiameter(1), 30);
      var previous = -1.0;
      for (var i = 0; i <= 20; i++) {
        final d = topologyHaloDiameter(i / 20);
        expect(d, greaterThan(previous), reason: 'must not shrink mid-loop');
        previous = d;
      }
    });

    test('opacity fades out as it expands and ends fully transparent', () {
      expect(topologyHaloOpacity(0), closeTo(0.20, 1e-9));
      expect(topologyHaloOpacity(0.5), closeTo(0.10, 1e-9));
      // Fully transparent at the end of the cycle: no ring is left behind and
      // there is no snap when the loop reverses.
      expect(topologyHaloOpacity(1), 0);
    });

    test('peak opacity stays low enough to read as a soft glow', () {
      final peak = List.generate(21, (i) => topologyHaloOpacity(i / 20)).reduce(
        (a, b) => a > b ? a : b,
      );
      expect(peak, closeTo(0.20, 1e-9));
      expect(peak, lessThan(0.25));
    });
  });

  // Structural guard: §10.4 forbids scale changes over 1.1× on the element.
  // The pulse must stay a separate halo layer — the node content must never be
  // wrapped in a Transform.scale / AnimatedScale.
  test('the node content is never scaled (§10.4)', () {
    final src = File('lib/views/proxies/chain_proxy_view.dart')
        .readAsStringSync();
    final nodeSource = src.substring(
      src.indexOf('class _TopologyNode extends StatefulWidget'),
      src.indexOf('class _ProxyHealthReportDialog'),
    );
    expect(
      nodeSource.contains('Transform.scale'),
      isFalse,
      reason: 'the topology node must not scale its content (§10.4, max 1.1x)',
    );
    expect(
      nodeSource.contains('AnimatedScale'),
      isFalse,
      reason: 'AnimatedScale would bypass the 1.1x cap',
    );
    // The halo is the only animated layer, and it is built from the pinned
    // pure helpers rather than inlined magic numbers.
    expect(nodeSource.contains('topologyHaloDiameter('), isTrue);
    expect(nodeSource.contains('topologyHaloOpacity('), isTrue);
  });
}
