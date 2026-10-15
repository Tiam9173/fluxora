import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy_node_view_model.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/models/latency_freshness.dart';
import 'package:fluxora/models/latency_state.dart';
import 'package:fluxora/providers/adaptive_ranking_provider.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/services/chain_adaptive_ranking_cache_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/network_fingerprint_provider.dart';
import 'package:path/path.dart' as p;

/// RC.11-C1 (F-AR5) — freshness-driven ranking auto-refresh.
///
/// **What this file proves**
///   * a latency observation crossing `LatencyFreshness.trustedMaxAge` /
///     `degradedMaxAge` re-ranks even when *nothing else* changed — the timer
///     advances `stateVersion`, which is already a `rankingStateFingerprint`
///     input, so the **existing** cache-miss path recomputes (it does NOT
///     bypass the cache);
///   * the re-armed single-shot timer fires only at a real boundary — it is not
///     a high-frequency poll;
///   * a token that never crosses a boundary schedules nothing at all;
///   * `dispose()` prevents any post-teardown notification;
///   * a candidate-set change re-arms rather than stacking timers.
///
/// **Layered evidence (never substituted for one another)**
///   1. *Provider rebuild* — `container.read(...)` identity. Explicitly NOT
///      treated as proof: `getOrComputeSync` returns a fresh
///      `List.unmodifiable(...)` on every call, so an emission is not evidence.
///   2. *Cache hit / miss* — a counter inside the injected `compute` closure.
///      This is the only sound proof that a recompute actually happened.
///   3. *ViewModel recompute* — the re-returned `latencyMs` value.
///   4. *UI repaint* — deliberately NOT used as a substitute for 2 or 3.
///
/// **Isolate constraints** (why this is its own file)
///   * `chainProxyConfigProvider` wraps the process-wide `ChainProxyManager`
///     singleton and Riverpod disposes that notifier with the container, so
///     exactly **one** container may be created/disposed here.
///   * `ChainProxyManager.init()` is one-shot per isolate (`_initialized`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const params = (role: FallbackCandidateRole.entry, sortMode: 'name');
  const nodeName = 'N-01';
  // A stable, fixed origin so every `testedAt` is deterministic.
  final origin = DateTime(2026, 1, 1, 12, 0, 0);

  late Directory tmp;
  late ChainProxyManager manager;
  late ProviderContainer container;

  /// The clock the production code reads while this file runs. Advanced in
  /// lockstep with `tester.pump(...)` so the real timer delay and the
  /// freshness arithmetic always describe the same instant.
  late DateTime fakeNow;

  ChainFallbackCandidate candidateWithNodeLatency({
    required int latencyMs,
    required DateTime testedAt,
    String? fingerprint,
  }) {
    return ChainFallbackCandidate(
      nodeName: nodeName,
      role: FallbackCandidateRole.entry,
      health: ChainHealthStatus.healthy,
      nodeLatency: LatencyState(
        latencyMs: latencyMs,
        scope: LatencyScope.node,
        source: LatencySource.probe,
        testedAt: testedAt,
        fingerprint: fingerprint ?? NetworkFingerprintProvider.wifi,
      ),
    );
  }

  /// Reconstructs the exact `stateFingerprint` `adaptiveRankingProvider`
  /// computes, from the same public inputs it watches
  /// (`adaptive_ranking_provider.dart:51-57`). Used only to address the shared
  /// cache singleton from a test.
  String stateFingerprintFor(ChainProxyManager m, ProviderContainer c) {
    return rankingStateFingerprint(
      networkFingerprint: NetworkFingerprintProvider.wifi,
      stateVersion: m.stateVersion,
      capabilityRevision: m.capabilityRevision,
      selectedMap: const <String, String>{},
      groups: c.read(groupsProvider),
    );
  }

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('fluxora_rc11c1_');
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
  });

  tearDownAll(() async {
    // NOTE: `T7` disposes the manager singleton on purpose (that IS its
    // subject). Riverpod's container would then double-dispose the wrapped
    // notifier, and that failure surfaces as an un-catchable zone error, so the
    // container is deliberately NOT torn down here. A leaked, already-disposed
    // container at the very end of the isolate is harmless.
    ChainProxyManager.freshnessClockOverride = null;
    networkFingerprintProvider.onChanged = null;
    ChainProxyManager.configFilePathOverride = null;
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    ChainProxyManager.reliabilityStatsFilePathOverride = null;
    ChainProxyManager.chainProbeOverride = null;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  setUp(() {
    fakeNow = origin;
    ChainProxyManager.freshnessClockOverride = () => fakeNow;
    networkFingerprintProvider.setMockFingerprint(
      NetworkFingerprintProvider.wifi,
    );
    // The ranking cache is a process-wide, RAM-only singleton — clear it so
    // each case starts from a genuine miss instead of another case's entry.
    chainAdaptiveRankingCacheService.invalidateAll();
  });

  tearDown(() {
    // Drop any timer this case armed, so it cannot outlive the case. `T7`
    // deliberately disposes the singleton (that IS its subject), so the
    // teardown must tolerate an already-disposed manager.
    try {
      manager.cancelFreshnessTick();
    } catch (_) {
      // Already disposed by T7 — nothing left to cancel.
    }
    ChainProxyManager.freshnessClockOverride = null;
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Scheduling logic — pure, no real waiting.
  // ────────────────────────────────────────────────────────────────────────────

  test('T-sched-1: a trusted observation schedules the transition to degraded',
      () async {
    await manager.setFallbackPool(
      ChainFallbackPool(
        entryCandidates: [
          candidateWithNodeLatency(
            latencyMs: 42,
            testedAt: origin.subtract(const Duration(minutes: 4)),
          ),
        ],
      ),
    );

    // 4 min old ⇒ trusted. The next boundary is 5 min ⇒ 1 min left, +1s guard.
    expect(
      manager.nextFreshnessTransitionDelay(),
      const Duration(minutes: 1, seconds: 1),
    );
  });

  test('T-sched-2: a degraded observation schedules the transition to unknown',
      () async {
    await manager.setFallbackPool(
      ChainFallbackPool(
        entryCandidates: [
          candidateWithNodeLatency(
            latencyMs: 42,
            testedAt: origin.subtract(const Duration(minutes: 20)),
          ),
        ],
      ),
    );

    // 20 min old ⇒ degraded. The next boundary is 30 min ⇒ 10 min left, +1s.
    expect(
      manager.nextFreshnessTransitionDelay(),
      const Duration(minutes: 10, seconds: 1),
    );
  });

  test('T-sched-3: an already-unknown observation schedules nothing', () async {
    await manager.setFallbackPool(
      ChainFallbackPool(
        entryCandidates: [
          candidateWithNodeLatency(
            latencyMs: 42,
            testedAt: origin.subtract(const Duration(minutes: 31)),
          ),
        ],
      ),
    );

    expect(
      manager.nextFreshnessTransitionDelay(),
      isNull,
      reason: 'unknown is terminal — there is no further transition to arm',
    );
  });

  test('T-sched-4: an empty pool schedules nothing', () async {
    await manager.setFallbackPool(const ChainFallbackPool());
    expect(manager.nextFreshnessTransitionDelay(), isNull);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Real-timer behaviour — `tester.pump` drives the Timer in test time.
  //
  // IMPORTANT — what is and is not controllable here:
  //   * The Timer runs on the test's FakeAsync clock, so `tester.pump(d)` DOES
  //     fire it, and `freshnessClockOverride` can steer the *schedule*.
  //   * `adaptiveRankingProvider` computes its own `now` with
  //     `DateTime.now()` (`adaptive_ranking_provider.dart:162`), which
  //     `tester.pump` does NOT advance (verified: a 2-hour pump moves the wall
  //     clock by 0 s). Its freshness verdict therefore always describes the
  //     REAL current instant.
  //
  // So each case below proves its claim in the layer where it is actually
  // observable, and never borrows one layer's evidence for another:
  //   * "the tick fires at the boundary" → `stateVersion` (layer 1)
  //   * "a fingerprint change causes a recompute" → compute count (layer 2)
  //   * "the value follows the gate" → `latencyMs` under a REAL clock (layer 3)
  // ────────────────────────────────────────────────────────────────────────────

  testWidgets(
    'T1: the tick fires at the 5-minute boundary and recomputes the ranking '
    'with no other state change',
    (tester) async {
      // A trusted observation, 4 min 55 s old ⇒ 5 s until degraded, +1s guard.
      //
      // Both clocks must agree on the same instant: the provider reads the REAL
      // `DateTime.now()` while the tick reads `freshnessClockOverride`. Anchoring
      // the injected clock to `now` keeps the schedule and the gate consistent.
      final realNow = DateTime.now();
      fakeNow = realNow;
      await manager.setFallbackPool(
        ChainFallbackPool(
          entryCandidates: [
            candidateWithNodeLatency(
              latencyMs: 42,
              testedAt: realNow.subtract(
                const Duration(minutes: 4, seconds: 55),
              ),
            ),
          ],
        ),
      );

      expect(
        manager.nextFreshnessTransitionDelay(),
        const Duration(seconds: 6),
        reason: '5 s to the boundary plus the 1 s anti-busy-loop guard',
      );

      final stateVersionBefore = manager.stateVersion;

      // Let 7 s of TEST time elapse; the armed single-shot timer must fire.
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();

      // Layer 1 — the invalidation went through the normal `stateVersion`
      // path (not a cache bypass, not a direct provider poke).
      expect(
        manager.stateVersion,
        greaterThan(stateVersionBefore),
        reason: 'the freshness tick must advance stateVersion',
      );

      // The callback re-armed a timer for the following boundary (by design).
      // Drop it so the framework's "no pending timers" invariant holds.
      manager.cancelFreshnessTick();
    },
  );

  testWidgets(
    'T2: past the 30-minute boundary the ranking recomputes and the '
    'ViewModel latency becomes null',
    (tester) async {
      // Layer 3 under a REAL clock: the provider reads `DateTime.now()`, so the
      // only faithful way to observe the gate is to give it a genuinely
      // over-age timestamp.
      await manager.setFallbackPool(
        ChainFallbackPool(
          entryCandidates: [
            candidateWithNodeLatency(
              latencyMs: 42,
              testedAt: DateTime.now().subtract(
                const Duration(minutes: 31),
              ),
            ),
          ],
        ),
      );

      final after = container.read(adaptiveRankingProvider(params)).single;
      expect(
        after.latencyMs,
        isNull,
        reason: 'past degradedMaxAge (30 min) the node has no usable latency',
      );

      // And the boundary is terminal: nothing is scheduled for it.
      expect(
        manager.nextFreshnessTransitionDelay(),
        isNull,
        reason: 'an already-unknown observation never transitions again',
      );

      // Contrast — the same node at 4 min IS visible, so the assertion above is
      // not vacuously true because of some unrelated null.
      await manager.setFallbackPool(
        ChainFallbackPool(
          entryCandidates: [
            candidateWithNodeLatency(
              latencyMs: 42,
              testedAt: DateTime.now().subtract(const Duration(minutes: 4)),
            ),
          ],
        ),
      );
      expect(
        container.read(adaptiveRankingProvider(params)).single.latencyMs,
        42,
      );
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // T2b — the END-TO-END causal chain, on the REAL clock.
  //
  // T2 above can only show that an already-stale observation renders as `null`
  // (its timestamp is 31 min old before the test even starts). This case closes
  // the gap the review flagged as P1/P2: ONE record, ONE timer, and the value
  // it produces genuinely changes across a real boundary:
  //
  //   record is `degraded` (42 ms visible)
  //     → single-shot timer expires (real 2 s wait)
  //     → `stateVersion` grows
  //     → `rankingStateFingerprint` changes → cache MISS → `compute()` runs
  //     → the SAME record is now `unknown`
  //     → the ViewModel reports `null`
  //
  // This is deliberately a plain `test`, NOT `testWidgets`: `tester.pump` only
  // advances a virtual clock (verified separately: a 2-hour pump moves
  // `DateTime.now()` by 0 s), which is exactly why T2 could not prove the
  // transition. A real `Future.delayed` advances the wall clock that both the
  // provider (`adaptive_ranking_provider.dart:162`) and the gate read, so the
  // crossing is observable without touching a third production file.
  // ────────────────────────────────────────────────────────────────────────────

  test(
    'T2b: timer expiry crosses a real freshness boundary and flips the '
    'ViewModel from 42 to null',
    () async {
      // Use the REAL clock for BOTH sides here: the injected clock is what the
      // schedule reads, and `null` makes it fall back to `DateTime.now()` — the
      // same instant the provider reads.
      ChainProxyManager.freshnessClockOverride = null;

      networkFingerprintProvider.setMockFingerprint(
        NetworkFingerprintProvider.wifi,
      );

      // Subscribe like the production picker does (`ref.watch`). Without a
      // listener a provider is lazy, so `notifyListeners()` alone would not
      // re-evaluate it — and the whole point here is that the tick drives a
      // REAL re-evaluation, not a passive read.
      int emissions = 0;
      final sub = container.listen(
        adaptiveRankingProvider(params),
        (_, _) => emissions++,
        fireImmediately: true,
      );
      addTearDown(sub.close);

      // 29 min 59 s old ⇒ `degraded`; the timer is ~1 s from the real boundary.
      await manager.setFallbackPool(
        ChainFallbackPool(
          entryCandidates: [
            candidateWithNodeLatency(
              latencyMs: 42,
              testedAt: DateTime.now().subtract(
                const Duration(seconds: 1799),
              ),
            ),
          ],
        ),
      );

      // Layer 3 — before: the record is still usable, at its RAW value.
      final before = container.read(adaptiveRankingProvider(params)).single;
      expect(
        before.latencyMs,
        42,
        reason: '29 min 59 s ago ⇒ degraded ⇒ still visible',
      );

      // Layer 2 — capture the cache entry the read above produced, so the
      // recompute below can be distinguished from a served-stale hit.
      // `rankingStateFingerprint` is `@visibleForTesting`, so the provider's
      // own key can be reconstructed exactly from public manager state.
      final key = ChainAdaptiveRankingCacheKey(
        role: FallbackCandidateRole.entry,
        networkFingerprint: NetworkFingerprintProvider.wifi,
        sortMode: 'name',
      );
      final String fingerprintBefore = stateFingerprintFor(manager, container);
      expect(
        chainAdaptiveRankingCacheService.hasValidCache(key, fingerprintBefore),
        isTrue,
        reason: 'the warm read must have written a cache entry',
      );

      final stateVersionBefore = manager.stateVersion;

      // The schedule is a real ~2 s (1 s to the boundary + the 1 s guard).
      final delay = manager.nextFreshnessTransitionDelay();
      expect(delay, isNotNull);
      expect(delay!.inSeconds, inInclusiveRange(1, 3));

      // Wait on the REAL clock; the armed single-shot timer fires.
      await Future<void>.delayed(delay + const Duration(milliseconds: 500));

      // Layer 1 — the tick fired and went through the normal version path.
      expect(
        manager.stateVersion,
        greaterThan(stateVersionBefore),
        reason: 'the real timer expiry must advance stateVersion',
      );

      // Layer 2 — the state fingerprint the provider is now keyed on has
      // changed, so the warmed entry could not have been reused: this was a
      // genuine cache MISS, and the `compute()` behind it ran. (A provider
      // emission alone would prove nothing — `getOrComputeSync` returns a fresh
      // list on every call.)
      final String fingerprintAfter = stateFingerprintFor(manager, container);
      expect(
        fingerprintAfter,
        isNot(equals(fingerprintBefore)),
        reason:
            'the timer-driven version bump must produce a different fingerprint',
      );
      expect(
        chainAdaptiveRankingCacheService.hasValidCache(key, fingerprintAfter),
        isTrue,
        reason: 'the recompute must have stored an entry under the NEW state',
      );
      expect(
        chainAdaptiveRankingCacheService.hasValidCache(key, fingerprintBefore),
        isFalse,
        reason: 'the OLD fingerprint must no longer be the stored one',
      );

      // Layer 3 — after: the SAME record crossed the boundary.
      final after = container.read(adaptiveRankingProvider(params)).single;
      expect(
        after.latencyMs,
        isNull,
        reason:
            'the same 42 ms observation is now past degradedMaxAge and must '
            'no longer be presented as a usable latency',
      );

      // The three layers are tied to ONE event, not three coincidences.
      expect(before.latencyMs, isNot(equals(after.latencyMs)));
      // Secondary evidence: the subscribed provider really did re-evaluate.
      expect(
        emissions,
        greaterThan(1),
        reason: 'the tick must have driven at least one re-evaluation',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'T3: no refresh happens before the boundary',
    (tester) async {
      // 4 min old ⇒ 1 min + 1 s until the degraded boundary.
      await manager.setFallbackPool(
        ChainFallbackPool(
          entryCandidates: [
            candidateWithNodeLatency(
              latencyMs: 42,
              testedAt: DateTime.now().subtract(const Duration(minutes: 4)),
            ),
          ],
        ),
      );

      final stateVersionBefore = manager.stateVersion;

      // Pump well short of the boundary.
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(
        manager.stateVersion,
        stateVersionBefore,
        reason: 'the tick must not fire before the boundary',
      );
      expect(
        container.read(adaptiveRankingProvider(params)).single.latencyMs,
        42,
      );
    },
  );

  testWidgets(
    'T5: a refresh needs no other business-state change',
    (tester) async {
      final realNow = DateTime.now();
      fakeNow = realNow;
      await manager.setFallbackPool(
        ChainFallbackPool(
          entryCandidates: [
            candidateWithNodeLatency(
              latencyMs: 42,
              testedAt: realNow.subtract(
                const Duration(minutes: 4, seconds: 58),
              ),
            ),
          ],
        ),
      );

      final stateVersionBefore = manager.stateVersion;
      // Only time passes — no pool write, no probe, no config change.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(
        manager.stateVersion,
        greaterThan(stateVersionBefore),
        reason:
            'time alone must be able to drive the invalidation — this is the '
            'entire point of F-AR5',
      );

      // The callback re-armed a timer for the following boundary (by design).
      manager.cancelFreshnessTick();
    },
  );

  testWidgets(
    'T6: re-arming on a new input does not leave the previous timer live',
    (tester) async {
      // First observation: 4 min old ⇒ would fire in ~61 s.
      await manager.setFallbackPool(
        ChainFallbackPool(
          entryCandidates: [
            candidateWithNodeLatency(
              latencyMs: 42,
              testedAt: DateTime.now().subtract(const Duration(minutes: 4)),
            ),
          ],
        ),
      );

      // Replace the pool with a fresh observation ⇒ ~5 min until the boundary.
      await manager.setFallbackPool(
        ChainFallbackPool(
          entryCandidates: [
            candidateWithNodeLatency(latencyMs: 77, testedAt: DateTime.now()),
          ],
        ),
      );

      final stateVersionBefore = manager.stateVersion;

      // Advance past where the FIRST timer would have fired (61 s) but well
      // short of the SECOND one (301 s). The old timer must not fire.
      await tester.pump(const Duration(seconds: 120));
      await tester.pump();

      expect(
        manager.stateVersion,
        stateVersionBefore,
        reason: 'the superseded timer must have been cancelled on re-arm',
      );
      expect(
        container.read(adaptiveRankingProvider(params)).single.latencyMs,
        77,
      );
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // Cache-hit / miss proof (layer 2) — the ONLY sound evidence.
  // ────────────────────────────────────────────────────────────────────────────

  test(
    'T8: same fingerprint, a differing stateVersion distinguishes a cache hit '
    'from a recompute',
    () {
      final service = ChainAdaptiveRankingCacheService();
      final key = ChainAdaptiveRankingCacheKey(
        role: FallbackCandidateRole.entry,
        networkFingerprint: NetworkFingerprintProvider.wifi,
      );

      int calls = 0;
      List<ChainProxyNodeViewModel> compute() {
        calls++;
        return const [
          ChainProxyNodeViewModel(
            proxy: Proxy(name: nodeName, type: 'vless'),
            nodeName: nodeName,
          ),
        ];
      }

      service.getOrComputeSync(
        key: key,
        currentStateFingerprint: 'fp|1',
        compute: compute,
      );
      expect(calls, 1);

      // Same fingerprint ⇒ a HIT: no recompute.
      service.getOrComputeSync(
        key: key,
        currentStateFingerprint: 'fp|1',
        compute: compute,
      );
      expect(
        calls,
        1,
        reason: 'an unchanged fingerprint must not recompute',
      );

      // A bumped stateVersion (what the freshness tick produces) ⇒ a MISS.
      service.getOrComputeSync(
        key: key,
        currentStateFingerprint: 'fp|2',
        compute: compute,
      );
      expect(
        calls,
        2,
        reason: 'the tick changes stateVersion, hence the fingerprint → miss',
      );
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // Control — the boundary arithmetic is not trivially satisfied.
  // ────────────────────────────────────────────────────────────────────────────

  test(
    'T-control: the +1s guard means an exact-boundary age still schedules',
    () async {
      // Exactly 5 min ⇒ still `trusted` (the `<=` contract). The transition is
      // therefore 1 s away, never 0 (a zero delay would risk a busy loop).
      await manager.setFallbackPool(
        ChainFallbackPool(
          entryCandidates: [
            candidateWithNodeLatency(
              latencyMs: 42,
              testedAt: origin.subtract(const Duration(minutes: 5)),
            ),
          ],
        ),
      );

      expect(LatencyFreshness.evaluate(
        state: LatencyState(
          latencyMs: 42,
          scope: LatencyScope.node,
          source: LatencySource.probe,
          testedAt: origin.subtract(const Duration(minutes: 5)),
          fingerprint: NetworkFingerprintProvider.wifi,
        ),
        now: origin,
        currentFingerprint: NetworkFingerprintProvider.wifi,
        expectedScope: LatencyScope.node,
      ), LatencyFreshness.trusted);

      expect(
        manager.nextFreshnessTransitionDelay(),
        const Duration(seconds: 1),
      );
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // T7 — MUST stay last.
  //
  // It disposes the process-wide manager singleton, which is the subject under
  // test here but leaves the singleton unusable for any later case. Keeping it
  // at the end (and letting `tearDownAll` tolerate the disposal) is what makes
  // that safe.
  //
  // What this case actually pins (verified by a non-vacuity probe): with the
  // `_freshnessTickTimer?.cancel()` line removed from `dispose()`, a timer
  // armed to fire *after* teardown would still be live and the test would see
  // it — so this is a real guard on the teardown path. The in-callback
  // `if (_disposed) return;` is a second, independent belt that this scenario
  // does not reach (the timer is already cancelled before it could fire); it is
  // kept for the same reason `notifyListeners()` keeps its own guard.
  // ────────────────────────────────────────────────────────────────────────────

  testWidgets(
    'T7: dispose prevents any post-teardown notification',
    (tester) async {
      await manager.setFallbackPool(
        ChainFallbackPool(
          entryCandidates: [
            candidateWithNodeLatency(
              latencyMs: 42,
              testedAt: origin.subtract(const Duration(minutes: 4, seconds: 55)),
            ),
          ],
        ),
      );

      // Sanity: a boundary really is armed before teardown, so the assertion
      // below cannot pass merely because nothing was ever scheduled.
      expect(
        manager.nextFreshnessTransitionDelay(),
        const Duration(seconds: 6),
      );

      final stateVersionBefore = manager.stateVersion;

      // Tear the manager down BEFORE the boundary fires.
      manager.dispose();

      fakeNow = origin.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(
        manager.stateVersion,
        stateVersionBefore,
        reason: 'a disposed manager must not notify listeners',
      );
    },
  );
}
