import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/widgets/fluxora/fluxora_latency_badge.dart';
import 'package:fluxora/widgets/fluxora/fluxora_proxy_tile.dart';
import 'package:fluxora/widgets/fluxora/fluxora_status.dart';

/// The locked-card layout.
///
/// Reported: once a node is locked (a computed group shows the lock mark as
/// `trailing`), the card's own information — the latency badge in particular —
/// stops being visible. The tile gives its trailing slot a fixed slice of the
/// row, so at the width a three-column phone grid actually uses, the text
/// column has to survive on what is left.
///
/// These cases pump the real tile at that width and let the framework report
/// any `RenderFlex` overflow, which is what a squeezed row looks like.
void main() {
  /// A three-column grid on a 360 dp phone: 16 dp page padding each side,
  /// 8 dp between columns.
  const cardWidth = (360 - 16 * 2 - 8 * 2) / 3;
  const cardHeight = 84.0;

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: cardWidth, height: cardHeight, child: child),
      ),
    ),
  );

  Widget badge(int delay) => FluxoraLatencyBadge(delay: delay);

  testWidgets('unlocked card shows the latency badge at 3-column width', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FluxoraProxyTile(
          name: '🇺🇸 美国-高速',
          protocol: 'ShadowSocks',
          delay: 162,
          compact: true,
          latencySlot: badge(162),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(FluxoraLatencyBadge), findsOneWidget);
  });

  testWidgets('locked card (trailing mark) keeps the latency badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FluxoraProxyTile(
          name: '🇺🇸 美国-高速',
          protocol: 'ShadowSocks',
          delay: 162,
          compact: true,
          selected: true,
          trailing: const Icon(Icons.lock_rounded, size: 16),
          latencySlot: badge(162),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byType(FluxoraLatencyBadge),
      findsOneWidget,
      reason: 'locking a node must not cost the row its latency',
    );
  });

  testWidgets('locked card keeps its status dot and metadata baseline', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const FluxoraProxyTile(
          name: 'Hong Kong residential 01',
          protocol: 'AnyTLS',
          delay: 383,
          compact: true,
          selected: true,
          status: FluxoraStatusKind.warning,
          nameMaxLines: 2,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          nameTrailing: Icon(Icons.lock_rounded, size: 14),
          latencySlot: FluxoraLatencyBadge(
            delay: 383,
            dense: true,
            tintBackground: false,
          ),
        ),
      ),
    );

    final protocol = tester.renderObject<RenderParagraph>(find.text('AnyTLS'));
    final latency = tester.renderObject<RenderParagraph>(find.text('383 ms'));
    double baseline(RenderParagraph paragraph) =>
        paragraph.localToGlobal(Offset.zero).dy +
        paragraph.getDryBaseline(
          paragraph.constraints,
          TextBaseline.alphabetic,
        )!;
    expect(baseline(protocol), closeTo(baseline(latency), .5));
    expect(find.byType(FluxoraStatus), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
