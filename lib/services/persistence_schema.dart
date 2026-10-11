/// P2.5-C (CF-2) — the persistence schema-version contract.
///
/// Every chain persistence file carries a top-level `version` key. This is the
/// single place that decides whether a decoded payload may be handed to the
/// current model decoders:
///
///  * [PersistenceSchemaStatus.current]     — `version == currentVersion`;
///  * [PersistenceSchemaStatus.legacy]      — the key is ABSENT → implicitly v1
///    (the shape written before versioning existed) → decoded normally;
///  * [PersistenceSchemaStatus.unsupported] — a HIGHER version (written by a
///    newer build) → **not** decoded;
///  * [PersistenceSchemaStatus.invalid]     — present but not a positive `int`
///    (`"1"`, `null`, `true`, `1.0`, `0`, `-3`) → **not** decoded.
///
/// `unsupported` / `invalid` never mean "delete the file": the payload is
/// skipped so [AtomicConfigStorage] can fall through to `.bak` / orphan `.tmp`.
/// There is deliberately **no fabricated v1 → v2 migration** — the only
/// migration that exists is `legacy (absent) → v1`, which is a no-op decode.
library;

enum PersistenceSchemaStatus { current, legacy, unsupported, invalid }

class PersistenceSchema {
  const PersistenceSchema._();

  /// The only on-disk version this build can decode.
  static const int currentVersion = 1;

  static const String versionKey = 'version';

  /// Classifies a decoded payload. The `version` value genuinely drives the
  /// decision — it is not merely read and then ignored.
  static PersistenceSchemaStatus statusOf(Map<String, dynamic> data) {
    // An absent key means a pre-versioning file, which is implicitly v1.
    if (!data.containsKey(versionKey)) return PersistenceSchemaStatus.legacy;

    final raw = data[versionKey];
    // Present but not a positive int (`"1"`, `null`, `true`, `1.0`) → invalid.
    if (raw is! int) return PersistenceSchemaStatus.invalid;
    if (raw < 1) return PersistenceSchemaStatus.invalid;
    if (raw == currentVersion) return PersistenceSchemaStatus.current;

    // A newer build wrote this; decoding it as v1 could silently corrupt state.
    return PersistenceSchemaStatus.unsupported;
  }

  /// Whether a payload in [status] may be decoded by this build.
  static bool isDecodable(PersistenceSchemaStatus status) =>
      status == PersistenceSchemaStatus.current ||
      status == PersistenceSchemaStatus.legacy;

  /// Acceptance predicate for `AtomicConfigStorage.load(accept: ...)`.
  static bool accepts(Map<String, dynamic> data) => isDecodable(statusOf(data));

  /// Stamps the current version onto a payload about to be written.
  ///
  /// Additive only: every existing top-level key is preserved unchanged, so the
  /// on-disk shape stays backwards-compatible with `legacy` readers.
  static Map<String, dynamic> stamp(Map<String, dynamic> data) => {
    ...data,
    versionKey: currentVersion,
  };
}
