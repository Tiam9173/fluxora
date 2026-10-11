import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/providers/chain_proxy.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';

/// P2.5-D — provider cleanup / wiring.
///
/// After P2.5-D the retained providers must expose **real** manager state (no
/// mock, no second telemetry store), and the six zero-consumer providers are
/// gone (their absence is enforced by compilation: this file references only
/// the retained set).
void main() {
  // `chainProxyConfigProvider` is a `ChangeNotifierProvider` that returns the
  // **process-wide** `chainProxyManager` singleton, and riverpod disposes the
  // notifier when the container is disposed. So exactly ONE container may be
  // disposed per process, and it must outlive every test in this file —
  // otherwise the first test's teardown kills the singleton for the next one
  // ("A ChainProxyManager was used after being disposed").
  late ProviderContainer container;

  setUpAll(() {
    container = ProviderContainer();
  });

  tearDownAll(() {
    container.dispose();
  });

  setUp(() => chainTelemetryService.clear());
  tearDown(() => chainTelemetryService.clear());

  test('A. the retained providers expose REAL manager state (no mock)', () {
    // Seed the REAL telemetry service before the first read.
    chainTelemetryService.record(
      ChainTelemetryEvent(
        type: ChainTelemetryEventType.probeStarted,
        timestamp: DateTime.now(),
      ),
    );

    // telemetry provider → the real manager telemetry snapshot
    expect(container.read(chainTelemetryProvider).totalEvents, 1);

    // support provider → null until a package is actually generated
    expect(container.read(chainSupportPackageProvider), isNull);

    // probing provider → the real manager flag
    expect(container.read(isProbingChainProvider), isFalse);

    // the config provider is backed by the production singleton, not a copy
    expect(
      identical(container.read(chainProxyConfigProvider), chainProxyManager),
      isTrue,
    );
  });

  test('B. delay providers read through the real manager', () {
    expect(container.read(chainProxyDelaysProvider), isEmpty);
    expect(container.read(chainProxyDelayProvider('any-node')), isNull);
  });
}
