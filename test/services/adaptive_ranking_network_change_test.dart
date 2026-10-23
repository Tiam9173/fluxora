import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy_node_view_model.dart';
import 'package:fluxora/models/chain_reliability_stats.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/models/latency_state.dart';
import 'package:fluxora/providers/adaptive_ranking_provider.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/services/chain_adaptive_ranking_cache_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/network_fingerprint_provider.dart';
import 'package:path/path.dart' as p;

/// RC.11-B.1 (G-AR1) — the production chain: a transport change must re-rank.
///
/// `RC11A_ACCEPTANCE_AUDIT.md` confirmed this chain by reading the Riverpod
/// library source (`change_notifier_provider.dart:231` forwards every
/// `ChangeNotifier.notifyListeners()` to `ref.notifyListeners()`), but there was
/// no project-level test for it. This file closes that gap.
///
/// **What this file proves**
///   * a real fingerprint change reaches the manager
///     (`NetworkFingerprintProvider._setCurrent` → `onChanged` →
///     `ChainProxyManager.init()`'s hook → `notifyListeners()` → `stateVersion`);
///   * the ranking provider then re-evaluates **against the new network
///     context**: a node whose only sample and only latency were recorded on the
///     previous transport loses both, and its score is recomputed from the new
///     context's statistics;
///   * switching back restores the previous context — the result follows the
///     fingerprint rather than being a one-way reset.
///
/// **What this file does NOT prove (recorded, never claimed)**
///   * `setMockFingerprint` shares the single mutation point (`_setCurrent`) with
///     the real `_apply` path, so the *notification* path is production
///     identical — but the real `Connectivity` stream is never started and no
///     real Wi-Fi ↔ cellular switch happens. Device-level verification remains a
///     separate runtime acceptance item.
///   * An emission alone is **not** evidence: `getOrComputeSync` returns a fresh
///     `List.unmodifiable(...)` on every call, so the listener fires even for an
///     unchanged result. Every pass/fail decision below is therefore based on
///     **content**, never on the emission count.
///
/// **Isolate constraints** (why this is its own file)
///   * `ChainProxyManager.init()` is one-shot per isolate (`_initialized`) and is
///     the only place the transport hook is installed
///     (`chain_proxy_manager.dart:242`).
///   * `chainProxyConfigProvider` wraps the process-wide manager singleton and
///     Riverpod disposes that notifier with the container, so exactly **one**
///     container may be created/disposed here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const wifi = NetworkFingerprintProvider.wifi;
  const cellular = NetworkFingerprintProvider.cellular;
  const params = (role: FallbackCandidateRole.entry, sortMode: 'name');
  const nodeName = 'N-01';

  late Directory tmp;
  late ChainProxyManager manager;
  late ProviderContainer container;
  late ProviderSubscription<List<ChainProxyNodeViewModel>> rankingSub;
  int emissions = 0;

  /// A candidate whose ONLY evidence — one success sample and one latency
  /// observation — is scoped to [wifi]. Under any other transport it must look
  /// untouched.
  ChainFallbackCandidate wifiScopedCandidate() => ChainFallbackCandidate(
    nodeName: nodeName,
    role: FallbackCandidateRole.entry,
    health: ChainHealthStatus.healthy,
    statsByContext: {
      wifi: ChainReliabilityStats.initial(
        networkFingerprint: wifi,
      ).recordEvent(isSuccess: true, now: DateTime.now()),
    },
    nodeLatency: LatencyState(
      latencyMs: 42,
      scope: LatencyScope.node,
      source: LatencySource.probe,
      testedAt: DateTime.now(),
      fingerprint: wifi,
    ),
  );

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('fluxora_rc11b1_');
    ChainProxyManager.configFilePathOverride = p.join(
      tmp.path,
      'chain_proxies.json',
    );
    ChainProxyManager.fallbackPoolFilePathOverride = p.join(
      tmp.path,
      'chain_fallback_pool.json',
    );
    ChainProxyManager.reliabilityStatsFilePathOverride = p.join(
      tmp.path,
      'chain_reliability_stats.json',
    );
    ChainProxyManager.chainProbeOverride = null;
    ChainProxyManager.capabilityProbeSourceOverride = null;

    manager = ChainProxyManager();
    // The production registration point — this installs the transport hook.
    await manager.init();

    container = ProviderContainer(
      overrides: [
        groupsProvider.overrideWithValue([
          Group(
            name: 'Proxy',
            type: GroupType.Selector,
            all: [Proxy(name: nodeName, type: 'vless')],
            now: '',
          ),
        ]),
        selectedMapProvider.overrideWithValue(const <String, String>{}),
      ],
    );

    rankingSub = container.listen(
      adaptiveRankingProvider(params),
      (_, _) => emissions++,
    );

    // Let `init()`'s fire-and-forget work settle. There is no core in tests, so
    // `refreshCapabilityProfiles` returns before touching any state — this just
    // makes sure it cannot race the first assertion.
    await Future<void>.value();
    await Future<void>.value();
  });

  tearDownAll(() async {
    rankingSub.close();
    await manager.flushReliabilityStats();
    container.dispose();
    networkFingerprintProvider.onChanged = null;
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    ChainProxyManager.chainProbeOverride = null;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  setUp(() {
    emissions = 0;
    // The ranking cache is a process-wide, RAM-only singleton — clear it so this
    // test starts from a genuine miss instead of another test's entry.
    chainAdaptiveRankingCacheService.invalidateAll();
  });

  test(
    'a transport change re-ranks against the NEW context, and switching back '
    'restores the previous one',
    () async {
      // ── Network A ──────────────────────────────────────────────────────────
      await manager.setFallbackPool(
        ChainFallbackPool(entryCandidates: [wifiScopedCandidate()]),
      );
      networkFingerprintProvider.setMockFingerprint(wifi);

      final before = container.read(adaptiveRankingProvider(params)).single;
      expect(
        before.hasObservedTelemetry,
        isTrue,
        reason: 'A holds a real sample for $nodeName',
      );
      expect(
        before.latencyMs,
        42,
        reason: "A holds $nodeName's own 42ms observation",
      );

      // ── Transport change A → B ─────────────────────────────────────────────
      final stateVersionBefore = manager.stateVersion;
      networkFingerprintProvider.setMockFingerprint(cellular);
      expect(
        manager.stateVersion,
        greaterThan(stateVersionBefore),
        reason:
            'the transport change must reach the manager, otherwise the '
            'ranking provider is never invalidated (F-AR4 wiring)',
      );

      final after = container.read(adaptiveRankingProvider(params)).single;

      // The re-evaluation must have used the NEW fingerprint. These three
      // assertions are the evidence — an emission alone would prove nothing.
      expect(
        after.hasObservedTelemetry,
        isFalse,
        reason: 'B has no samples for $nodeName yet',
      );
      expect(
        after.latencyMs,
        isNull,
        reason: "A's latency is scoped to A and must not be visible in B",
      );
      expect(
        after.score!.totalScore,
        isNot(equals(before.score!.totalScore)),
        reason: 'the score must be recomputed from the B-scoped statistics',
      );

      // ── Back to A ──────────────────────────────────────────────────────────
      networkFingerprintProvider.setMockFingerprint(wifi);
      final back = container.read(adaptiveRankingProvider(params)).single;
      expect(
        back.hasObservedTelemetry,
        isTrue,
        reason: 'the result follows the fingerprint, not a one-way reset',
      );
      expect(back.latencyMs, 42);
      expect(
        back.score!.totalScore,
        equals(before.score!.totalScore),
        reason: 'the same context must produce the same ranking',
      );

      // Secondary evidence only — never the basis of the pass/fail decision.
      expect(emissions, greaterThan(0));
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // Control — the assertions above are NOT trivially true.
  //
  // The main test's first assertion is that a fingerprint change bumps
  // `stateVersion`. This case removes the transport hook from the test side
  // (never touching production code) and shows the chain really depends on it:
  // with no hook, the very same call changes nothing. So the main test would
  // fail if `ChainProxyManager.init()` did not install the hook — and
  // `network_fingerprint_lifecycle_test.dart`'s case J pins that it does.
  // ────────────────────────────────────────────────────────────────────────────
  test('control: without the transport hook the change never reaches the manager',
      () {
    final hook = networkFingerprintProvider.onChanged;
    networkFingerprintProvider.onChanged = null;
    try {
      final stateVersionBefore = manager.stateVersion;
      networkFingerprintProvider.setMockFingerprint(cellular);
      expect(
        manager.stateVersion,
        stateVersionBefore,
        reason:
            'the fingerprint → manager chain is carried entirely by the hook, '
            'so the main test is not vacuous',
      );
    } finally {
      networkFingerprintProvider.onChanged = hook;
    }
  });
}
