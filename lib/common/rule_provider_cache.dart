import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'path.dart';

/// Share rule bytes, never proxy nodes or script results, across subscriptions.
Future<String> prepareRuleProviderCache(
  String profileId,
  Map provider, {
  required String? userAgent,
}) async {
  final legacyPath = await appPath.getProvidersFilePath(
    profileId,
    'rules',
    provider['url'] as String,
  );
  final identity = {...provider}..remove('path');
  final key = sha256
      .convert(utf8.encode(jsonEncode([userAgent, identity])))
      .toString();
  final shared = File(
    p.join(await appPath.profilesPath, 'rule-provider-cache', key),
  );
  File? seed;
  try {
    if (await shared.exists()) return shared.path;
    final legacy = File(legacyPath);
    final stat = await legacy.stat();
    if (stat.type == FileSystemEntityType.file && stat.size > 0) {
      await shared.parent.create(recursive: true);
      seed = File(
        '${shared.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      await legacy.copy(seed.path);
      // Keep the age so the core still refreshes an expired ruleset.
      await seed.setLastModified(stat.modified);
      if (!await shared.exists()) await seed.rename(shared.path);
    }
    return shared.path;
  } on FileSystemException {
    // Cache migration must never prevent applying a working configuration.
    return legacyPath;
  } finally {
    try {
      if (seed != null && await seed.exists()) await seed.delete();
    } on FileSystemException {
      // A leftover seed is never used as a ruleset.
    }
  }
}
