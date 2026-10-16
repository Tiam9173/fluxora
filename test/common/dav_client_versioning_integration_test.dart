import 'dart:convert';
import 'dart:io';

import 'package:fluxora/common/dav_client.dart';
import 'package:fluxora/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// item 6 (Bettbox 1.19.3) — WebDAV backup versioning, end to end.
///
/// The pure rules are covered in `dav_client_versions_test.dart`. This file
/// exercises the parts that only exist against a server: choosing a free name
/// from a live listing, confirming a write landed, the prune that follows it,
/// and what happens when the server refuses.
///
/// The fake server keeps files in memory and implements exactly the verbs the
/// client uses. It is deliberately not a WebDAV implementation — it is a
/// recorder of what the client asked for and when.
class FakeWebDavServer {
  FakeWebDavServer._(this._server);

  final HttpServer _server;
  final Map<String, List<int>> files = {};

  /// Set to make the next `PUT` fail, simulating a server that refuses writes.
  bool failWrites = false;

  /// Set to make `DELETE` fail, simulating a prune that cannot complete.
  bool failDeletes = false;

  /// Every method+path the client asked for, in order — lets a test assert on
  /// *when* the prune happened relative to the write.
  final List<String> calls = [];

  int get deleteCount => calls.where((c) => c.startsWith('DELETE ')).length;

  static Future<FakeWebDavServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeWebDavServer._(server);
    server.listen(fake._handle);
    return fake;
  }

  String get uri => 'http://${_server.address.host}:${_server.port}';

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    calls.add('${request.method} $path');

    if (request.headers.value(HttpHeaders.authorizationHeader) == null) {
      // The client only sends credentials after being challenged, so a bare 401
      // is not enough — the `WWW-Authenticate` headers are what trigger the
      // retry.
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.add(
        HttpHeaders.wwwAuthenticateHeader,
        'Digest realm="Test", nonce="test-nonce", qop="auth"',
        preserveHeaderCase: true,
      );
      request.response.headers.add(
        HttpHeaders.wwwAuthenticateHeader,
        'Basic realm="Test"',
        preserveHeaderCase: true,
      );
      await request.response.close();
      return;
    }

    switch (request.method) {
      case 'OPTIONS':
        request.response.statusCode = HttpStatus.ok;
      case 'MKCOL':
        request.response.statusCode = HttpStatus.created;
      case 'PUT':
        if (failWrites) {
          request.response.statusCode = HttpStatus.internalServerError;
        } else {
          files[path] = await request.fold<List<int>>(
            <int>[],
            (bytes, chunk) => bytes..addAll(chunk),
          );
          request.response.statusCode = HttpStatus.created;
        }
      case 'DELETE':
        if (failDeletes) {
          request.response.statusCode = HttpStatus.internalServerError;
        } else {
          files.remove(path);
          request.response.statusCode = HttpStatus.noContent;
        }
      case 'GET':
        final body = files[path];
        if (body == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.statusCode = HttpStatus.ok;
          request.response.add(body);
        }
      case 'PROPFIND':
        request.response.statusCode = 207;
        request.response.headers.contentType = ContentType(
          'application',
          'xml',
          charset: 'utf-8',
        );
        request.response.write(_multiStatus(path));
      default:
        request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  }

  /// A listing of the requested directory.
  ///
  /// The collection entry comes **first**: `webdav_client`'s `readDir` runs with
  /// `skipSelf: true`, which skips the first entry only when it is a directory
  /// and otherwise fails the entire parse.
  String _multiStatus(String requestPath) {
    final prefix = requestPath.endsWith('/')
        ? requestPath
        : '$requestPath/';
    final buffer = StringBuffer(
      '<?xml version="1.0" encoding="utf-8"?>\n<d:multistatus xmlns:d="DAV:">\n'
      '<d:response><d:href>$prefix</d:href><d:propstat><d:prop>'
      '<d:resourcetype><d:collection/></d:resourcetype>'
      '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>\n',
    );
    files.forEach((path, bytes) {
      if (!path.startsWith(prefix)) return;
      buffer.write(
        '<d:response><d:href>$path</d:href><d:propstat><d:prop>'
        '<d:resourcetype/>'
        '<d:getcontentlength>${bytes.length}</d:getcontentlength>'
        '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>\n',
      );
    });
    buffer.write('</d:multistatus>');
    return buffer.toString();
  }

  /// The stored payloads, decoded. Asserting on these rather than on raw byte
  /// lists keeps the comparison meaningful: `List<int>` equality is identity
  /// based, so `contains(bytes)` would silently never match.
  Set<String> payloads() =>
      files.values.map((b) => utf8.decode(b)).toSet();

  /// Names of the stored backups, ignoring the directory entry.
  List<String> backupNames() {
    return files.keys
        .map((p) => p.split('/').last)
        .where((n) => n.toLowerCase().endsWith('.zip'))
        .toList();
  }
}

DAVClient clientFor(FakeWebDavServer server) {
  return DAVClient(
    DAV(uri: server.uri, user: 'test', password: 'password'),
  );
}

void main() {
  late FakeWebDavServer server;
  late DAVClient client;

  setUp(() async {
    server = await FakeWebDavServer.start();
    client = clientFor(server);
    await client.pingCompleter.future;
  });

  tearDown(() async {
    await server.close();
  });

  test('a second backup in the same second does not overwrite the first', () async {
    final first = utf8.encode('first');
    final second = utf8.encode('second');

    // Back to back: these land in the same second, which is exactly the case the
    // collision suffix exists for.
    expect(await client.backup(first), isTrue);
    expect(await client.backup(second), isTrue);

    expect(server.backupNames(), hasLength(2));
    // Both payloads must still be on the server — neither was clobbered.
    expect(server.payloads(), containsAll(['first', 'second']));
  });

  test('keeps only the newest 10 versions', () async {
    for (var i = 0; i < 12; i++) {
      expect(await client.backup(utf8.encode('payload-$i')), isTrue);
    }

    final entries = await client.getBackupEntries();
    final versioned = entries.where((e) => e.isVersioned).toList();
    expect(versioned, hasLength(10));

    // The newest payload survived, the oldest two did not.
    expect(server.payloads(), contains('payload-11'));
    expect(server.payloads(), isNot(contains('payload-0')));
  });

  test('a legacy backup is listed, restorable, and never pruned', () async {
    // A server that has been in use before versioning existed. The name is the
    // client's own configured one — anything else would be an unrecognised file
    // rather than the legacy backup, and correctly ignored.
    final legacyPath = '/Fluxora/${client.fileName}';
    final legacyBytes = utf8.encode('legacy');
    server.files[legacyPath] = legacyBytes;

    for (var i = 0; i < 12; i++) {
      await client.backup(utf8.encode('payload-$i'));
    }

    // Still there after 12 backups and the prunes that followed them.
    expect(server.files[legacyPath], legacyBytes);

    // Visible as a distinct kind, and last in the list.
    final entries = await client.getBackupEntries();
    final legacy = entries.where((e) => e.kind == BackupKind.legacy).toList();
    expect(legacy, hasLength(1));
    expect(entries.last.kind, BackupKind.legacy);

    // And restorable by name.
    expect(await client.recovery(client.fileName), legacyBytes);
  });

  test('the legacy backup does not consume one of the 10 slots', () async {
    server.files['/Fluxora/${client.fileName}'] = utf8.encode('legacy');

    for (var i = 0; i < 10; i++) {
      await client.backup(utf8.encode('payload-$i'));
    }

    final versioned = (await client.getBackupEntries())
        .where((e) => e.isVersioned)
        .toList();
    // Exactly 10 versioned backups, all of them retained.
    expect(versioned, hasLength(10));
    expect(server.payloads(), contains('payload-0'));
  });

  test('a failed upload prunes nothing', () async {
    for (var i = 0; i < 11; i++) {
      await client.backup(utf8.encode('payload-$i'));
    }
    final deletesBefore = server.deleteCount;

    server.failWrites = true;
    await expectLater(client.backup(utf8.encode('nope')), throwsA(anything));

    // No prune may have run: the backup it would have been cleaning up after
    // never succeeded.
    expect(server.deleteCount, deletesBefore);
    expect(server.payloads(), isNot(contains('nope')));
  });

  test('a failed prune keeps the new backup and the backup still succeeds', () async {
    for (var i = 0; i < 11; i++) {
      await client.backup(utf8.encode('payload-$i'));
    }

    server.failDeletes = true;
    final result = await client.backup(utf8.encode('payload-final'));

    // The upload succeeded, so the caller is told so…
    expect(result, isTrue);
    // …and the payload is on the server despite the prune failing.
    expect(server.payloads(), contains('payload-final'));
  });

  test('the prune runs after the write, not before', () async {
    for (var i = 0; i < 11; i++) {
      await client.backup(utf8.encode('payload-$i'));
    }
    server.calls.clear();

    await client.backup(utf8.encode('payload-last'));

    final firstPut = server.calls.indexWhere((c) => c.startsWith('PUT '));
    final firstDelete = server.calls.indexWhere((c) => c.startsWith('DELETE '));
    expect(firstPut, isNonNegative);
    // Cleanup only after the new version is confirmed on the server.
    if (firstDelete != -1) expect(firstPut, lessThan(firstDelete));
  });

  test('the version the caller picks is the one downloaded', () async {
    await client.backup(utf8.encode('older'));
    await client.backup(utf8.encode('newer'));

    final entries = await client.getBackupEntries();
    final oldest = entries.last;
    final body = await client.recovery(oldest.name);

    // Recovery used the requested name rather than defaulting to something else.
    expect(body, utf8.encode('older'));
    expect(server.calls.last, 'GET /Fluxora/${oldest.name}');
  });
}
