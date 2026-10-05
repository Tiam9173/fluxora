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

  /// Generates a SHA-256 hash representing the immutable identity of the node config.
  /// If host, port, protocol, password, or uuid changes, the hash changes,
  /// guaranteeing automatic invalidation of stale cache data.
  static String generateKey(Map<dynamic, dynamic> config) {
    final type = config['type']?.toString() ?? '';
    final server = config['server']?.toString() ?? '';
    final port = config['port']?.toString() ?? '';
    final uuid = config['uuid']?.toString() ?? '';
    final password = config['password']?.toString() ?? '';

    final payload = '$type|$server|$port|$uuid|$password';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Retrieves the profile from memory cache.
  /// If expired, returns the profile with `expired` evidence.
  static ProtocolCapabilityProfile? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      return entry.profile.copyWith(evidence: CapabilityEvidenceType.expired);
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
  }

  /// Clears the entire cache (useful for testing or hard resets).
  static void clear() {
    _cache.clear();
  }
}
