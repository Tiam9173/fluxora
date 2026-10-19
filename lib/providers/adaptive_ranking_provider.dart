import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chain_proxy_node_view_model.dart';
import '../models/chain_fallback_pool.dart';
import '../models/latency_freshness.dart';
import '../models/latency_state.dart';
import '../services/chain_adaptive_score_service.dart';
import '../services/chain_capability_service.dart';
import '../services/proxy_semantic_classifier.dart';
import '../manager/chain_proxy_manager.dart';
import '../providers/providers.dart';
import '../models/common.dart';
import '../models/chain_proxy.dart';
import '../services/network_fingerprint_provider.dart';
import '../providers/chain_proxy.dart';

import '../services/chain_adaptive_ranking_cache_service.dart';
import '../common/pinyin_sort.dart';

typedef AdaptiveRankingParams = ({FallbackCandidateRole role, String sortMode});

final adaptiveRankingProvider =
    Provider.family<List<ChainProxyNodeViewModel>, AdaptiveRankingParams>((
  ref,
  params,
) {
  final role = params.role;
  final sortMode = params.sortMode;

  // Read triggers that must invalidate the cache implicitly:
  final groups = ref.watch(groupsProvider);
  final selectedMap = ref.watch(selectedMapProvider);
  final manager = ref.watch(chainProxyConfigProvider.select((_) => chainProxyManager));
  // P1.2-A: rebuild when the config-level capability view changes. The revision
  // feeds `stateFingerprint` below, so a change here produces a cache miss.
  final capabilityRevision = ref.watch(
    chainProxyConfigProvider.select((m) => m.capabilityRevision),
  );
  // P1.3: rebuild when the manager bumps `stateVersion`. Reliability samples are
  // recorded through the manager (`_writeBackProbeResultsToCandidates`, and
  // `ChainFailoverService._updateCandidateStats` on the failover path), each
  // followed by a `notifyListeners()` that bumps it. This closes the loop:
  // sample → stateVersion → provider rebuild → new `stateFingerprint` below →
  // cache miss → fresh stats → new ranking.
  final stateVersion = ref.watch(
    chainProxyConfigProvider.select((m) => m.stateVersion),
  );
  final fingerprint = networkFingerprintProvider.getCurrentFingerprint();
  
  // Create a robust fingerprint based on the latest reactive states.
  // Any change to these inputs effectively forms a new fingerprint, guaranteeing a cache miss.
  final stateFingerprint = rankingStateFingerprint(
    networkFingerprint: fingerprint,
    stateVersion: stateVersion,
    capabilityRevision: capabilityRevision,
    selectedMap: selectedMap,
    groups: groups,
  );

  final cacheKey = ChainAdaptiveRankingCacheKey(
    role: role,
    networkFingerprint: fingerprint,
    sortMode: sortMode,
  );

  return chainAdaptiveRankingCacheService.getOrComputeSync(
    key: cacheKey,
    currentStateFingerprint: stateFingerprint,
    compute: () {
      final Set<Proxy> allProxies = {};
      for (final g in groups) {
        if (g.name != 'GLOBAL') {
          for (final p in g.all) {
            // B4: the single shared classification rule — built-in policies,
            // proxy groups and shadow nodes are not ordinary nodes. Subscription
            // "information" nodes are deliberately NOT name-filtered here; they
            // stay selectable so P1.1-D2 can keep collecting real samples.
            if (ChainProxyConfig.isSelectableProxy(name: p.name, type: p.type)) {
              allProxies.add(p);
            }
          }
        }
      }

      final fallbackPool = manager.fallbackPool;

      final allCandidates = [
        ...fallbackPool.entryCandidates,
        ...fallbackPool.relayCandidates,
        ...fallbackPool.exitCandidates,
      ].where((c) => c.role == role).toList();

      int globalTotalTrials = 0;
      for (final c in allCandidates) {
        final stats = c.statsByContext[fingerprint];
        if (stats != null) {
          globalTotalTrials += stats.totalSamples;
        }
      }

      final List<ChainProxyNodeViewModel> viewModels = [];

      final allPoolCandidates = [
        ...fallbackPool.entryCandidates,
        ...fallbackPool.relayCandidates,
        ...fallbackPool.exitCandidates,
      ];

      for (final proxy in allProxies) {
        ChainFallbackCandidate candidate;
        final idx = allCandidates.indexWhere((c) => c.nodeName == proxy.name);
        if (idx >= 0) {
          candidate = allCandidates[idx];
        } else {
          candidate = ChainFallbackCandidate(nodeName: proxy.name, role: role);
        }

        // P1.2-A: prefer the real config-level capability view
        // (configDeclared / runtime evidence) over the static protocol baseline.
        final profile =
            chainProxyManager.capabilityProfiles[proxy.name] ??
            ChainCapabilityService.getBaselineCapability(proxy.type);
        // P1.2-F: the badge reports the probe-derived (TCP) evidence; the
        // profile no longer carries a single evidence value.
        final evidence = profile.tcp.evidence;

        final score = ChainAdaptiveScoreService.calculateNodeScore(
          candidate: candidate,
          capabilityProfile: profile,
          globalTotalTrials: globalTotalTrials,
        );

        final isLocked = selectedMap.containsValue(proxy.name);

        // Derived presentation flags (never persisted): the node counts as
        // observed only when real telemetry samples exist for this network
        // context. `totalSamples` is the sample counter used above for
        // `globalTotalTrials`.
        final nodeStats = candidate.statsByContext[fingerprint];
        final hasObservedTelemetry = (nodeStats?.totalSamples ?? 0) > 0;

        // P1.1-D2: behavioural availability classification from the same real
        // telemetry. Presentation-only — never persisted, never mutates the
        // candidate.
        final semanticType = ProxySemanticClassifier.classify(nodeStats);

        viewModels.add(ChainProxyNodeViewModel(
          proxy: proxy,
          nodeName: proxy.name,
          score: score,
          health: candidate.health,
          // P1.3-C4-Step5 (Q4 = change the source only): the card represents a
          // **node**, so it must show that node's own hop latency — not
          // `candidate.latencyMs`, which is the compat shim holding the
          // *chain* total (`totalChainLatencyMs`, itself the last hop's delay).
          //
          // Freshness-gated: missing / stale / foreign-network / wrong-scope all
          // collapse to `null`, which the card already renders as "unknown".
          // Deliberately NOT back-filled from `chainLatency` — a different
          // measurement would be mislabelled as this node's own.
          latencyMs: LatencyFreshness.visibleLatencyMs(
            state: candidate.nodeLatency,
            now: DateTime.now(),
            currentFingerprint: fingerprint,
            expectedScope: LatencyScope.node,
          ),
          capabilityEvidence: evidence,
          isLocked: isLocked,
          isFailoverCandidate:
              allPoolCandidates.any((c) => c.nodeName == proxy.name),
          hasObservedTelemetry: hasObservedTelemetry,
          semanticType: semanticType,
        ));
      }

      if (sortMode == 'latency') {
        // P1.3-C4-Step5 (Q1 + Q7): the rule now lives in the view model so it is
        // independently testable, and it sorts by the **node's own** latency.
        // Valid values first (ascending); unknowns last, in a stable name order.
        //
        // P2 (option 3): when NO node has a usable latency the list therefore
        // falls back to that name order — a stable, predictable rule, never a
        // fabricated 0 ms and never a silent switch to the Smart order. The
        // picker surfaces a 「暂无延迟数据」 hint for exactly that case, so the
        // fallback is visible instead of being mistaken for real latency sorting.
        viewModels.sort(ChainProxyNodeViewModel.compareByLatency);
      } else if (sortMode == 'name') {
        // A→Z by pinyin, not by code point: Chinese names in Unicode order look
        // shuffled to anyone who reads them.
        viewModels.sort((a, b) => compareByPinyin(a.nodeName, b.nodeName));
      } else {
        viewModels.sort((a, b) => a.compareTo(b));
      }

      // P1.1-D2: keep the chosen sort order, but always sink behaviourally
      // non-connectable nodes to the bottom. They are annotated, never hidden.
      final List<ChainProxyNodeViewModel> ordered = [];
      final List<ChainProxyNodeViewModel> sunk = [];
      for (final vm in viewModels) {
        (vm.isNonConnectable ? sunk : ordered).add(vm);
      }
      return [...ordered, ...sunk];
    },
  );
});

/// RC.11-A (F-AR1): the ranking cache key's state fingerprint.
///
/// Order-independent, and the group component digests the **real node set**.
/// The previous `groups.fold<int>(0, (h, g) => h ^ g.all.length)` was not
/// injective — group sizes `{3, 5}` and `{2, 4}` both XOR to `6` — so a node
/// add/remove could leave the fingerprint unchanged and serve a cache hit whose
/// `viewModels` still described the **old** node set. Hashing each group's name
/// together with its member names also catches a same-count replacement, which
/// a size-only digest cannot see.
///
/// Pure and side-effect free, so the collision cases are directly testable.
@visibleForTesting
String rankingStateFingerprint({
  required String networkFingerprint,
  required int stateVersion,
  required int capabilityRevision,
  required Map<String, String> selectedMap,
  required List<Group> groups,
}) => [
  networkFingerprint,
  stateVersion.toString(),
  capabilityRevision.toString(),
  selectedMap.keys.map((k) => '$k=${selectedMap[k]}').join(','),
  // Sorted before combining, so a mere reordering of the same groups does not
  // produce a spurious cache miss — the old XOR component was order-independent
  // too, and that property is worth keeping.
  //
  // RC.11-B.2 (F-AR1-EDGE): each group's member names are sorted *before* they
  // are hashed. `Object.hashAll` is positional, so an unsorted member list made
  // the group digest sensitive to the mere ORDER of members within a group —
  // a reordered (but otherwise identical) member list produced a different
  // fingerprint and therefore a spurious cache miss with a full recompute.
  // Sorting is the scheme-① fix: the group digest is still fully
  // order-independent, the strong `SystemHash` mixing is retained (unlike the
  // weaker `hashAllUnordered`), and duplicates are deliberately NOT removed, so
  // `[n1, n1, n2]` still hashes differently from `[n1, n2]` — the count
  // semantics of a repeated member are preserved.
  Object.hashAll(
    [
      for (final g in groups)
        Object.hash(
          g.name,
          Object.hashAll(g.all.map((p) => p.name).toList()..sort()),
        ),
    ]..sort(),
  ).toString(),
].join('|');
