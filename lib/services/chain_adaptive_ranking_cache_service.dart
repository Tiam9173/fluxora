import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy_node_view_model.dart';

/// Cache key isolated by Hop Role, Network Context, and Sort Mode.
class ChainAdaptiveRankingCacheKey {
  final FallbackCandidateRole role;
  final String networkFingerprint;
  final String sortMode;

  ChainAdaptiveRankingCacheKey({
    required this.role,
    required this.networkFingerprint,
    this.sortMode = 'adaptive',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChainAdaptiveRankingCacheKey &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          networkFingerprint == other.networkFingerprint &&
          sortMode == other.sortMode;

  @override
  int get hashCode =>
      role.hashCode ^ networkFingerprint.hashCode ^ sortMode.hashCode;
}

class ChainAdaptiveRankingCacheEntry {
  final List<ChainProxyNodeViewModel> viewModels;
  final int generation;
  final DateTime createdAt;
  final String stateFingerprint;

  ChainAdaptiveRankingCacheEntry({
    required this.viewModels,
    required this.generation,
    required this.createdAt,
    required this.stateFingerprint,
  });
}

abstract class IChainAdaptiveRankingCacheService {
  void invalidateAll();
  void invalidateRole(FallbackCandidateRole role);
  Future<List<ChainProxyNodeViewModel>> getOrComputeAsync({
    required ChainAdaptiveRankingCacheKey key,
    required String currentStateFingerprint,
    required Future<List<ChainProxyNodeViewModel>> Function() compute,
  });

  List<ChainProxyNodeViewModel> getOrComputeSync({
    required ChainAdaptiveRankingCacheKey key,
    required String currentStateFingerprint,
    required List<ChainProxyNodeViewModel> Function() compute,
  });
  
  // Expose cache state for testing validation
  bool hasValidCache(ChainAdaptiveRankingCacheKey key, String currentStateFingerprint);
}

class ChainAdaptiveRankingCacheService implements IChainAdaptiveRankingCacheService {
  final Map<ChainAdaptiveRankingCacheKey, ChainAdaptiveRankingCacheEntry> _cache = {};
  final Map<ChainAdaptiveRankingCacheKey, Future<List<ChainProxyNodeViewModel>>> _inFlight = {};
  final Map<ChainAdaptiveRankingCacheKey, int> _generationByKey = {};

  int _nextGeneration(ChainAdaptiveRankingCacheKey key) {
    final gen = (_generationByKey[key] ?? 0) + 1;
    _generationByKey[key] = gen;
    return gen;
  }

  @override
  void invalidateAll() {
    _cache.clear();
    for (final key in _generationByKey.keys.toList()) {
      _generationByKey[key] = _generationByKey[key]! + 1;
    }
  }

  @override
  void invalidateRole(FallbackCandidateRole role) {
    _cache.removeWhere((key, _) => key.role == role);
    for (final key in _generationByKey.keys.toList()) {
      if (key.role == role) {
        _generationByKey[key] = _generationByKey[key]! + 1;
      }
    }
  }

  @override
  bool hasValidCache(ChainAdaptiveRankingCacheKey key, String currentStateFingerprint) {
    final cached = _cache[key];
    return cached != null && cached.stateFingerprint == currentStateFingerprint;
  }

  @override
  List<ChainProxyNodeViewModel> getOrComputeSync({
    required ChainAdaptiveRankingCacheKey key,
    required String currentStateFingerprint,
    required List<ChainProxyNodeViewModel> Function() compute,
  }) {
    final cached = _cache[key];
    if (cached != null && cached.stateFingerprint == currentStateFingerprint) {
      return List.unmodifiable(cached.viewModels);
    }

    final currentGen = _nextGeneration(key);
    final result = compute();
    
    // For synchronous, there's no race condition that could have bumped generation
    if (currentGen == _generationByKey[key]) {
      _cache[key] = ChainAdaptiveRankingCacheEntry(
        viewModels: List.unmodifiable(result),
        generation: currentGen,
        createdAt: DateTime.now(),
        stateFingerprint: currentStateFingerprint,
      );
    }
    
    return List.unmodifiable(result);
  }

  @override
  Future<List<ChainProxyNodeViewModel>> getOrComputeAsync({
    required ChainAdaptiveRankingCacheKey key,
    required String currentStateFingerprint,
    required Future<List<ChainProxyNodeViewModel>> Function() compute,
  }) async {
    final cached = _cache[key];
    // Cache Hit Validation: Check fingerprint equality.
    if (cached != null && cached.stateFingerprint == currentStateFingerprint) {
      return List.unmodifiable(cached.viewModels); // Immutability requirement
    }

    // In-flight Deduplication (Concurrency Requirement)
    if (_inFlight.containsKey(key)) {
      return _inFlight[key]!;
    }

    final currentGen = _nextGeneration(key);
    final computeFuture = compute();
    _inFlight[key] = computeFuture;

    try {
      final result = await computeFuture;
      
      // Generation Protection: Prevent stale async ranking from overwriting newer cache
      if (currentGen == _generationByKey[key]) {
        _cache[key] = ChainAdaptiveRankingCacheEntry(
          viewModels: List.unmodifiable(result),
          generation: currentGen,
          createdAt: DateTime.now(),
          stateFingerprint: currentStateFingerprint,
        );
      }
      
      return List.unmodifiable(result);
    } finally {
      if (_inFlight[key] == computeFuture) {
        _inFlight.remove(key);
      }
    }
  }
}

// Global Singleton (RAM-only scope, non-persistent, clears on restart)
final chainAdaptiveRankingCacheService = ChainAdaptiveRankingCacheService();
