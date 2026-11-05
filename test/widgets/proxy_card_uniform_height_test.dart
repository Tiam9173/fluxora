import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/widgets/fluxora/fluxora_latency_badge.dart';
import 'package:fluxora/widgets/fluxora/fluxora_proxy_tile.dart';

/// Card rhythm in the proxies grid.
///
/// Reported: in list style the node cards do not look alike — they read as
/// different heights / densities side by side, even though the list gives every
/// card in a row the same box.
///
/// The cause is inside the card, not in the row: the name used to take its
/// natural height, so a long name (the screenshots are full of them, e.g.
/// "距离下次重置剩余：19 天") pushed the status row down while a short one left
/// it high. Bettbox avoids this by reserving `bodyMediumHeight * maxLines` for
/// the name block; the tile now does the same, text-scaler aware.
void main() {
  /// Two columns on a 360 dp phone.
  const cardWidth = (360 - 16 * 2 - 8 * 2) / 2;

  /// `getItemHeight()` for the list style.
  const cardHeight = 84.0;

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: cardWidth, height: cardHeight, child: child),
      ),
    ),
  );

  // Long enough to wrap for certain at ~160 dp, which is what the
  // screenshots show (a full sentence used as a node name).
  const longName = '距离下次重置剩余：19 天，这是很长的节点名称用于测试';
  // Short enough to stay on one line at this width — that is the whole
  // point: one card wraps, the other does not.
  const shortName = '短名';

  Widget tile(String name, {int nameMaxLines = 2}) => FluxoraProxyTile(
    name: name,
    protocol: 'Vless',
    delay: -1,
    compact: true,
    nameMaxLines: nameMaxLines,
    latencySlot: const FluxoraLatencyBadge(delay: -1),
  );

  testWidgets('the status row sits at the same height whether the name wraps', (
    tester,
  ) async {
    // A roomy box: centring must not be able to hide the difference.
    Widget tallHost(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: cardWidth, height: 160, child: child),
        ),
      ),
    );

    await tester.pumpWidget(tallHost(tile(shortName)));
    expect(tester.takeException(), isNull);
    final shortY = tester.getTopLeft(find.byType(FluxoraLatencyBadge)).dy;

    await tester.pumpWidget(tallHost(tile(longName)));
    expect(tester.takeException(), isNull);
    final longY = tester.getTopLeft(find.byType(FluxoraLatencyBadge)).dy;

    expect(
      longY,
      shortY,
      reason: 'a wrapped name must not push the status row down a card',
    );
  });

  testWidgets('both cards keep the same box at one-line names', (tester) async {
    await tester.pumpWidget(host(tile(longName, nameMaxLines: 1)));
    expect(tester.takeException(), isNull);
    final longSize = tester.getSize(find.byType(FluxoraProxyTile));

    await tester.pumpWidget(host(tile(shortName, nameMaxLines: 1)));
    expect(tester.takeException(), isNull);
    final shortSize = tester.getSize(find.byType(FluxoraProxyTile));

    expect(longSize, shortSize, reason: 'same box, same rhythm');
  });
}
