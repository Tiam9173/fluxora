import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chain_proxy_node_view_model.dart';
import '../models/chain_fallback_pool.dart';
import '../services/chain_adaptive_score_service.dart';
import '../services/chain_capability_service.dart';
import '../manager/chain_proxy_manager.dart';
import '../providers/state.dart';
import '../providers/providers.dart';
import '../models/common.dart';
import '../models/chain_proxy.dart';
import '../services/network_fingerprint_provider.dart';
import '../providers/chain_proxy.dart';

import '../services/chain_adaptive_ranking_cache_service.dart';

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
  final fingerprint = networkFingerprintProvider.getCurrentFingerprint();
  
  // Create a robust fingerprint based on the latest reactive states.
  // Any change to these inputs effectively forms a new fingerprint, guaranteeing a cache miss.
  final stateFingerprint = [
    fingerprint,
    manager.stateVersion.toString(),
    selectedMap.keys.map((k) => '$k=${selectedMap[k]}').join(','),
    groups.fold<int>(0, (h, g) => h ^ g.all.length).toString(),
  ].join('|');

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
            if (p.type != 'URLTest' &&
                p.type != 'Fallback' &&
                p.type != 'LoadBalance' &&
                p.type != 'Selector' &&
                p.type != 'Direct' &&
                p.type != 'Reject' &&
                p.name != 'DIRECT' &&
                p.name != 'REJECT' &&
                p.name != 'REJECT-DROP' &&
                p.name != 'PASS' &&
                !ChainProxyConfig.isShadowNodeName(p.name)) {
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

        final profile = ChainCapabilityService.getBaselineCapability(proxy.type);
        final evidence = profile.evidence;

        final score = ChainAdaptiveScoreService.calculateNodeScore(
          candidate: candidate,
          capabilityProfile: profile,
          globalTotalTrials: globalTotalTrials,
        );

        final isLocked = selectedMap.containsValue(proxy.name);

        viewModels.add(ChainProxyNodeViewModel(
          proxy: proxy,
          nodeName: proxy.name,
          score: score,
          health: candidate.health,
          latencyMs: candidate.latencyMs,
          capabilityEvidence: evidence,
          isLocked: isLocked,
          isFailoverCandidate:
              allPoolCandidates.any((c) => c.nodeName == proxy.name),
        ));
      }

      if (sortMode == 'latency') {
        viewModels.sort((a, b) {
          final aLat = a.latencyMs ?? 99999;
          final bLat = b.latencyMs ?? 99999;
          if (aLat != bLat) return aLat.compareTo(bLat);
          return a.nodeName.compareTo(b.nodeName);
        });
      } else if (sortMode == 'name') {
        viewModels.sort((a, b) => a.nodeName.compareTo(b.nodeName));
      } else {
        viewModels.sort((a, b) => a.compareTo(b));
      }
      return viewModels;
    },
  );
});
