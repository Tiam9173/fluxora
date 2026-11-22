import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'path.dart' show appPath;
import 'http.dart' show FluxoraHttpOverrides;
import '../state.dart' show globalState;

/// The icon-set JSON format used by Qure and user-created collections.
class IconCollection {
  static const maxBytes = 2 * 1024 * 1024;
  static const maxIcons = 10000;
  static const qureSource = 'https://github.com/aaANDkk/Qure_Style_SVG';

  const IconCollection({
    required this.name,
    required this.icons,
    this.description = '',
    this.source = '',
  });

  final String name, description, source;
  final List<CollectionIcon> icons;

  static bool isWebUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  static IconCollection parse(String content, {String source = ''}) {
    if (utf8.encode(content).length > maxBytes) {
      throw const FormatException('Icon collection exceeds 2 MiB');
    }
    final json = jsonDecode(content);
    if (json is! Map<String, dynamic> ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty ||
        (json['name'] as String).length > 128 ||
        json['icons'] is! List) {
      throw const FormatException('Expected {name, icons: [{name, url}]}');
    }
    final entries = json['icons'] as List;
    if (entries.isEmpty || entries.length > maxIcons) {
      throw const FormatException('Expected 1–10000 icons');
    }
    final seen = <String>{};
    final icons = <CollectionIcon>[];
    for (final item in entries) {
      if (item is! Map || item['name'] is! String || item['url'] is! String) {
        throw const FormatException('Each icon needs a name and URL');
      }
      final name = (item['name'] as String).trim();
      final url = (item['url'] as String).trim();
      if (name.isEmpty ||
          name.length > 256 ||
          url.length > 4096 ||
          !isWebUrl(url)) {
        throw const FormatException('Invalid icon name or HTTP(S) URL');
      }
      if (seen.add(url)) icons.add(CollectionIcon(name: name, url: url));
    }
    return IconCollection(
      name: (json['name'] as String).trim(),
      description: json['description'] is String ? json['description'] : '',
      source: source.isNotEmpty
          ? source
          : (json['source'] is String ? json['source'] : ''),
      icons: List.unmodifiable(icons),
    );
  }

  Map<String, Object> toJson() => {
    'name': name,
    'description': description,
    'source': source,
    'icons': [
      for (final icon in icons) {'name': icon.name, 'url': icon.url},
    ],
  };

  static Future<IconCollection> download(String url) async {
    if (!isWebUrl(url)) throw const FormatException('Expected an HTTP(S) URL');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    client.findProxy = (uri) {
      client.userAgent = globalState.ua;
      return FluxoraHttpOverrides.handleFindProxy(uri);
    };
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      if (response.contentLength > maxBytes) {
        throw const FormatException('Icon collection exceeds 2 MiB');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('Icon collection exceeds 2 MiB');
        }
        bytes.add(chunk);
      }
      return parse(utf8.decode(bytes.takeBytes()), source: url);
    } finally {
      client.close(force: true);
    }
  }
}

class CollectionIcon {
  const CollectionIcon({required this.name, required this.url});
  final String name, url;
  String get label => name.replaceFirst(
    RegExp(r'\.(svg|png|webp|jpe?g)$', caseSensitive: false),
    '',
  );
}

/// Loaded only when the library opens, never as part of app startup.
class IconCollectionStore {
  static const maxCollections = 8;
  static const maxTotalBytes = 8 * 1024 * 1024;

  IconCollectionStore({Directory? directory}) : _directory = directory;
  final Directory? _directory;

  Future<Directory> get directory async =>
      _directory ??
      Directory(path.join(await appPath.homeDirPath, 'icon-sets'));

  Future<List<IconCollection>> load() async {
    final dir = await directory;
    if (!await dir.exists()) return const [];
    final files = await dir
        .list()
        .where((file) => file is File && file.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return [
      for (final file in files) IconCollection.parse(await file.readAsString()),
    ];
  }

  Future<void> save(List<IconCollection> collections) async {
    if (collections.length > maxCollections) {
      throw const FormatException('At most 8 imported collections');
    }
    final encoded = <(String, String)>[];
    final names = <String>{};
    var totalBytes = 0;
    for (final collection in collections) {
      if (!names.add(collection.name)) {
        throw const FormatException('Collection names must be unique');
      }
      final content = jsonEncode(collection.toJson());
      final bytes = utf8.encode(content).length;
      if (bytes > IconCollection.maxBytes) {
        throw const FormatException('Icon collection exceeds 2 MiB');
      }
      totalBytes += bytes;
      encoded.add((collection.name, content));
    }
    if (totalBytes > maxTotalBytes) {
      throw const FormatException('Imported collections exceed 8 MiB');
    }
    final dir = await directory;
    await dir.create(recursive: true);
    final targetNames = <String>{};
    for (var index = 0; index < encoded.length; index++) {
      final (name, content) = encoded[index];
      final order = index.toString().padLeft(2, '0');
      final filename = '$order-${sha256.convert(utf8.encode(name))}.json';
      targetNames.add(filename);
      final target = File(path.join(dir.path, filename));
      final temporary = File('${target.path}.tmp');
      await temporary.writeAsString(content, flush: true);
      try {
        await temporary.rename(target.path);
      } on FileSystemException {
        final backup = File('${target.path}.bak');
        if (await target.exists()) await target.rename(backup.path);
        try {
          await temporary.rename(target.path);
          if (await backup.exists()) await backup.delete();
        } catch (_) {
          if (await backup.exists() && !await target.exists()) {
            await backup.rename(target.path);
          }
          rethrow;
        }
      }
    }
    await for (final file in dir.list()) {
      if (file is File &&
          file.path.endsWith('.json') &&
          !targetNames.contains(path.basename(file.path))) {
        await file.delete();
      }
    }
  }
}

/// Exact overrides win over existing broad regex rules without replacing them.
Map<String, String> setGroupIcon(
  Map<String, String> current,
  String group,
  String url,
) {
  final key = '^${RegExp.escape(group)}\$';
  return {
    if (url.isNotEmpty) key: url,
    for (final entry in current.entries)
      if (entry.key != key) entry.key: entry.value,
  };
}
