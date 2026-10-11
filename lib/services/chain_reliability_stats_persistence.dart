import '../common/common.dart';
import '../models/chain_fallback_pool.dart';
import '../models/chain_reliability_stats.dart';
import 'atomic_config_storage.dart';
import 'persistence_schema.dart';

/// P2.1 — durable store for reliability statistics.
///
/// Shape: `role → nodeName → fingerprint → stats`. Keying by role keeps the
/// same node usable in several roles without merging their statistics, and
/// keying by fingerprint keeps separate network contexts independent.
///
/// Only the long-lived counters defined by [ChainReliabilityStats] are written.
/// Transient runtime state (probe/failover progress, cooldowns, subscriptions,
/// core handles, UI state) is never part of this format.
class ChainReliabilityStatsPersistence {
  const ChainReliabilityStatsPersistence();

  /// Bumped when the on-disk shape changes in an incompatible way. Mirrors the
  /// shared [PersistenceSchema.currentVersion] contract (P2.5-C).
  static const int schemaVersion = PersistenceSchema.currentVersion;

  static const String _versionKey = PersistenceSchema.versionKey;
  static const String _statsKey = 'statsByContext';

  /// Pure encode: role → node → fingerprint → stats.
  Map<String, dynamic> encode(
    Map<FallbackCandidateRole, Map<String, Map<String, ChainReliabilityStats>>>
    byRole,
  ) {
    return {
      _versionKey: schemaVersion,
      _statsKey: {
        for (final roleEntry in byRole.entries)
          roleEntry.key.name: {
            for (final nodeEntry in roleEntry.value.entries)
              nodeEntry.key: {
                for (final fpEntry in nodeEntry.value.entries)
                  fpEntry.key: fpEntry.value.toJson(),
              },
          },
      },
    };
  }

  /// Pure, tolerant decode — **gated by the schema version** (P2.5-C).
  ///
  /// The `version` value genuinely decides whether decoding happens:
  ///  * `current` (== [PersistenceSchema.currentVersion]) → decoded;
  ///  * `legacy` (no version key) → implicitly v1 → decoded;
  ///  * `unsupported` (a newer build's version) → **empty result**;
  ///  * `invalid` (`"1"`, `null`, `0`, `-3`, `1.0`) → **empty result**.
  ///
  /// Within a decodable payload, decoding stays tolerant: unknown roles, extra
  /// fields and wrongly-typed nodes are skipped rather than throwing, so a
  /// partially corrupt file can never block startup.
  Map<FallbackCandidateRole, Map<String, Map<String, ChainReliabilityStats>>>
  decode(Map<String, dynamic>? json) {
    final result =
        <FallbackCandidateRole, Map<String, Map<String, ChainReliabilityStats>>>{};
    if (json == null) return result;

    final status = PersistenceSchema.statusOf(json);
    if (!PersistenceSchema.isDecodable(status)) {
      commonPrint.log(
        'ChainReliabilityStatsPersistence: refusing to decode a '
        '${status.name} schema version '
        '(${PersistenceSchema.versionKey}='
        '${json[PersistenceSchema.versionKey]}); expected '
        '${PersistenceSchema.currentVersion}',
      );
      return result;
    }

    final raw = json[_statsKey];
    if (raw is! Map) return result;

    for (final roleEntry in raw.entries) {
      final role = FallbackCandidateRole.fromString(roleEntry.key.toString());
      final nodes = roleEntry.value;
      if (nodes is! Map) continue;

      final byNode = <String, Map<String, ChainReliabilityStats>>{};
      for (final nodeEntry in nodes.entries) {
        final fps = nodeEntry.value;
        if (fps is! Map) continue;

        final byFp = <String, ChainReliabilityStats>{};
        for (final fpEntry in fps.entries) {
          final value = fpEntry.value;
          if (value is! Map) continue;
          byFp[fpEntry.key.toString()] = ChainReliabilityStats.fromJson(
            value,
            fallbackFingerprint: fpEntry.key.toString(),
          );
        }
        if (byFp.isNotEmpty) byNode[nodeEntry.key.toString()] = byFp;
      }
      if (byNode.isNotEmpty) result[role] = byNode;
    }
    return result;
  }

  /// Reads and decodes the store **through the shared [AtomicConfigStorage]**,
  /// so a missing or corrupt primary file recovers from `.bak` / orphan `.tmp`
  /// exactly like the chain-config and fallback-pool reads (P2.5-A).
  ///
  /// **Never throws**: `AtomicConfigStorage.load()` returns `null` when nothing
  /// usable is on disk (missing / empty / malformed / unreadable), which decodes
  /// to an empty map so startup continues. The decoding shape is unchanged.
  Future<Map<FallbackCandidateRole, Map<String, Map<String, ChainReliabilityStats>>>>
  load(String filePath) async {
    try {
      // P2.5-C: the schema predicate is applied to every recovery candidate, so
      // an unsupported/invalid primary cannot mask a valid `.bak` / `.tmp`.
      final decoded = await AtomicConfigStorage(filePath).load(
        accept: PersistenceSchema.accepts,
      );
      return decode(decoded);
    } catch (e) {
      commonPrint.log(
        'ChainReliabilityStatsPersistence: failed to load $filePath: $e',
      );
      return const {};
    }
  }

  /// Writes the store. **Never throws**: a failure is logged and the in-memory
  /// state is left untouched, so probe / ranking / failover keep working.
  /// Returns `true` when the file was written.
  Future<bool> save(
    String filePath,
    Map<FallbackCandidateRole, Map<String, Map<String, ChainReliabilityStats>>>
    byRole,
  ) async {
    try {
      // P2.4-A: crash-safe atomic write (tmp → validate → .bak → rename).
      // The encoded payload (version + statsByContext) is unchanged, so the
      // on-disk JSON schema is byte-for-byte what it was before.
      await AtomicConfigStorage(filePath).save(encode(byRole));
      return true;
    } catch (e) {
      commonPrint.log(
        'ChainReliabilityStatsPersistence: failed to save $filePath: $e',
      );
      return false;
    }
  }
}

final chainReliabilityStatsPersistence = ChainReliabilityStatsPersistence();
