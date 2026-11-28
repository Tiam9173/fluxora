import 'package:archive/archive_io.dart';
import 'package:fluxora/models/profile.dart';
import 'package:path/path.dart' as p;

/// Resolves backup profile IDs without collapsing distinct subscriptions.
class ProfileRecoveryPlan {
  ProfileRecoveryPlan._(this.profiles, this._targetIds);

  final List<Profile> profiles;
  final Map<String, String> _targetIds;

  factory ProfileRecoveryPlan.exact(List<Profile> incoming) {
    _validateUniqueProfileIds(incoming);
    return ProfileRecoveryPlan._(List.unmodifiable(incoming), {
      for (final profile in incoming) profile.id: profile.id,
    });
  }

  factory ProfileRecoveryPlan.compatible(
    List<Profile> incoming,
    List<Profile> local, {
    Map<String, String> generatedProfileIds = const {},
  }) {
    _validateUniqueProfileIds(incoming);

    final localById = {for (final profile in local) profile.id: profile};
    final reservedIds = incoming.map((profile) => profile.id).toSet();
    final localBySource = <String, List<Profile>>{};
    for (final profile in local) {
      final source = _subscriptionSource(profile);
      if (source != null && !reservedIds.contains(profile.id)) {
        localBySource.putIfAbsent(source, () => []).add(profile);
      }
    }

    final targetIds = <String, String>{};
    final restored = <String, Profile>{};
    for (final profile in incoming) {
      final generatedId = generatedProfileIds[profile.id];
      final generated = localById[generatedId];
      if (generatedId != null &&
          (profile.url.isNotEmpty ||
              generated == null ||
              generated.url.isNotEmpty ||
              (generatedId != profile.id &&
                  reservedIds.contains(generatedId)) ||
              restored.containsKey(generatedId))) {
        throw const FormatException('Conflicting aggregate profile identity');
      }
      final candidates = localById.containsKey(profile.id)
          ? null
          : localBySource[_subscriptionSource(profile)];
      final match =
          generated ??
          (candidates == null || candidates.isEmpty
              ? null
              : candidates.removeAt(0));
      final targetId = match?.id ?? profile.id;
      targetIds[profile.id] = targetId;
      restored[targetId] = match == null
          ? profile
          : profile.copyWith(id: targetId, label: match.label);
    }
    return ProfileRecoveryPlan._(
      List.unmodifiable(restored.values),
      Map.unmodifiable(targetIds),
    );
  }

  String? targetId(String? sourceId) =>
      sourceId == null ? null : (_targetIds[sourceId] ?? sourceId);

  ArchiveFile remapArchiveFile(ArchiveFile file) {
    final normalized = p.posix.normalize(file.name.replaceAll(r'\', '/'));
    if (!p.posix.isWithin('profiles', normalized)) return file;
    final parts = normalized.split('/');
    final sourceId = switch (parts) {
      ['profiles', final name] when name.endsWith('.yaml') => name.substring(
        0,
        name.length - 5,
      ),
      ['profiles', final name] when name.endsWith('.yml') => name.substring(
        0,
        name.length - 4,
      ),
      ['profiles', 'providers', final id, ...] => id,
      _ => null,
    };
    if (sourceId == null) return file;
    final target = targetId(sourceId);
    if (target == null || target == sourceId) return file;
    final targetName = switch (parts) {
      ['profiles', final name] => 'profiles/$target${p.posix.extension(name)}',
      ['profiles', 'providers', _, ...] => [
        'profiles',
        'providers',
        target,
        ...parts.skip(3),
      ].join('/'),
      _ => normalized,
    };
    return ArchiveFile.bytes(targetName, file.content);
  }

  static String? _subscriptionSource(Profile profile) {
    final uri = Uri.tryParse(profile.url.trim());
    if (uri == null ||
        !(uri.isScheme('https') || uri.isScheme('http')) ||
        uri.host.isEmpty) {
      return null;
    }
    return uri.removeFragment().toString();
  }

  static void _validateUniqueProfileIds(List<Profile> profiles) {
    final ids = <String>{};
    for (final profile in profiles) {
      if (!ids.add(profile.id)) {
        throw FormatException('Duplicate profile ID in backup: ${profile.id}');
      }
    }
  }
}
