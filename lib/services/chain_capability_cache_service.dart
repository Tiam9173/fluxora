import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/protocol_capability.dart';

class CapabilityCacheEntry {
  final ProtocolCapabilityProfile profile;
  final DateTime timestamp;

  const CapabilityCacheEntry({required this.profile, required this.timestamp});

  bool get isExpired {
    return DateTime.now().difference(timestamp).inMinutes >= 30; // 30 min TTL
  }
}

class ChainCapabilityCacheService {
  static final Map<String, CapabilityCacheEntry> _cache = {};

  /// P1.4 (G7-B1): upper bound on retained entries.
  ///
  /// The map previously grew without limit — one entry per distinct node config
  /// ever probed, kept for the whole session (`clear()` was the only removal).
  /// Eviction is **capacity-only**: it never changes how a *retained* entry
  /// reads, so the 30-minute TTL and its `expired` evidence semantics are
  /// untouched. `_cache` is a `LinkedHashMap`, so iteration order is insertion
  /// order; [_touch] re-inserts on access, which makes `keys.first` the
  /// least-recently-**used** entry (without [_touch] this would be plain FIFO).
  static const int maxEntries = 512;

  /// Moves [key] to the most-recently-used end of [_cache].
  static void _touch(String key, CapabilityCacheEntry entry) {
    _cache.remove(key);
    _cache[key] = entry;
  }

  /// Drops least-recently-used entries until the cap is respected.
  static void _evictIfNeeded() {
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Keys that are deliberately **NOT** part of a node's identity.
  ///
  ///  * `name` — a rename must keep the same capability entry (the previous key
  ///    already excluded it, on purpose);
  ///  * `dialer-proxy` — chain routing topology, not the node itself: changing
  ///    the chain path must not invalidate every node's capability.
  ///
  /// Applied at the **top level only** — a nested `name`-like key (e.g. inside
  /// `ws-opts` / `grpc-opts`) is part of the transport definition and is kept.
  static const Set<String> _nonIdentityKeys = {'name', 'dialer-proxy'};

  /// Generates a SHA-256 hash representing the immutable identity of the node config.
  ///
  /// **P1.3-B (K4-C2)**: the key is a **canonical fingerprint of the whole
  /// config** minus [_nonIdentityKeys] — not a fixed list of five fields.
  ///
  /// The previous `type|server|port|uuid|password` payload missed `username`,
  /// `cipher`, `alterId`, `flow`, `network` + transport options,
  /// `reality-opts`, `obfs*`, `plugin*`, `preshared-key`,
  /// `client-fingerprint`, … so two genuinely different nodes could hash to the
  /// same key and inherit each other's capability evidence. **Any fixed field
  /// list has the same defect the moment a new protocol field appears** —
  /// hashing the canonical config is structurally complete instead.
  ///
  /// Canonical form: object keys are **sorted at every depth** (two logically
  /// equal configs built in a different insertion order hash identically);
  /// list order is preserved (e.g. `alpn` preference order); scalars are
  /// JSON-encoded so `1` (int) and `'1'` (String) cannot collide.
  static String generateKey(Map<dynamic, dynamic> config) {
    final payload = _canonicalize(config);
    return sha256.convert(utf8.encode(payload)).toString();
  }

  static String _canonicalize(Object? value) {
    final buffer = StringBuffer();
    _writeCanonical(value, buffer, isRoot: true);
    return buffer.toString();
  }

  static void _writeCanonical(
    Object? value,
    StringBuffer out, {
    bool isRoot = false,
  }) {
    if (value is Map) {
      final entries = <MapEntry<String, Object?>>[];
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (isRoot && _nonIdentityKeys.contains(key)) continue;
        entries.add(MapEntry(key, entry.value));
      }
      entries.sort((a, b) => a.key.compareTo(b.key));

      out.write('{');
      for (var i = 0; i < entries.length; i++) {
        if (i > 0) out.write(',');
        out.write(_encodeScalar(entries[i].key));
        out.write(':');
        _writeCanonical(entries[i].value, out);
      }
      out.write('}');
    } else if (value is Iterable) {
      out.write('[');
      var first = true;
      for (final item in value) {
        if (!first) out.write(',');
        first = false;
        _writeCanonical(item, out);
      }
      out.write(']');
    } else {
      out.write(_encodeScalar(value));
    }
  }

  /// JSON-encodes a scalar so `1` (int) and `'1'` (String) cannot collide.
  /// Falls back to the string form for values JSON cannot encode (e.g. a
  /// `DateTime` or a custom object) so [generateKey] never throws on an odd
  /// config.
  static String _encodeScalar(Object? value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return jsonEncode(value.toString());
    }
  }

  /// Retrieves the profile from memory cache.
  /// If expired, returns the profile with `expired` evidence.
  static ProtocolCapabilityProfile? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // P1.4 (G7-B1): mark as most-recently-used. This only reorders the map —
    // the value returned below is unchanged, in particular an expired entry is
    // still returned with `expired` evidence rather than becoming `null`.
    _touch(key, entry);

    if (entry.isExpired) {
      // P1.2-F: the entry timestamp covers the whole snapshot, so expiry marks
      // every dimension — evidence stays per-dimension, the clock does not.
      final p = entry.profile;
      return p.copyWith(
        tcp: p.tcp.copyWith(evidence: CapabilityEvidenceType.expired),
        tls: p.tls.copyWith(evidence: CapabilityEvidenceType.expired),
        udp: p.udp.copyWith(evidence: CapabilityEvidenceType.expired),
      );
    }
    return entry.profile;
  }

  /// Saves the verified profile to memory.
  static void set(
    String key,
    ProtocolCapabilityProfile profile, {
    DateTime? overrideTimestamp,
  }) {
    _cache[key] = CapabilityCacheEntry(
      profile: profile,
      timestamp: overrideTimestamp ?? DateTime.now(),
    );
    // Re-assigning an EXISTING key keeps its original position in a
    // LinkedHashMap, so move it to the MRU end explicitly before evicting.
    _touch(key, _cache[key]!);
    _evictIfNeeded();
  }

  /// Clears the entire cache (useful for testing or hard resets).
  static void clear() {
    _cache.clear();
  }
}
