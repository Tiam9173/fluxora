import 'dart:convert';
import 'dart:io';

import 'package:fluxora/common/dav_client.dart';
import 'package:fluxora/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// A `207 Multi-Status` body for a directory holding one stored file.
///
/// The collection itself must come **first**: `webdav_client`'s `readDir` runs
/// with `skipSelf: true`, which skips the first entry only if it is a directory
/// and otherwise fails the whole parse. A listing that starts with a file is not
/// accepted, however well-formed it looks.
String _multiStatus(String path, int length) {
  final escaped = const HtmlEscape().convert(path);
  final parent = escaped.substring(0, escaped.lastIndexOf('/') + 1);
  return '''
<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>$parent</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype><d:collection/></d:resourcetype>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>$escaped</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype/>
        <d:getcontentlength>$length</d:getcontentlength>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
</d:multistatus>
''';
}

void main() {
  test('supports servers with multiple WWW-Authenticate headers', () async {
    final backupBytes = utf8.encode('backup-data');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var storedBytes = <int>[];
    var storedPath = '';

    final subscription = server.listen((request) async {
      final authorization = request.headers.value(
        HttpHeaders.authorizationHeader,
      );
      if (authorization == null) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.headers.add(
          HttpHeaders.wwwAuthenticateHeader,
          'Digest realm="DUFS", nonce="test-nonce", qop="auth"',
          preserveHeaderCase: true,
        );
        request.response.headers.add(
          HttpHeaders.wwwAuthenticateHeader,
          'Basic realm="DUFS"',
          preserveHeaderCase: true,
        );
      } else if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
      } else if (request.method == 'MKCOL') {
        request.response.statusCode = HttpStatus.created;
      } else if (request.method == 'PUT') {
        storedBytes = await request.fold<List<int>>(
          <int>[],
          (bytes, chunk) => bytes..addAll(chunk),
        );
        // Remember what landed where: the client lists the directory after
        // uploading to confirm its own write, so the listing has to be real.
        storedPath = request.uri.path;
        request.response.statusCode = HttpStatus.created;
      } else if (request.method == 'PROPFIND') {
        // Directory listing. Only the files this test has actually stored are
        // reported; anything else would be invented state.
        request.response.statusCode = 207;
        request.response.headers.contentType = ContentType(
          'application',
          'xml',
          charset: 'utf-8',
        );
        request.response.write(_multiStatus(storedPath, storedBytes.length));
      } else if (request.method == 'GET') {
        request.response.statusCode = HttpStatus.ok;
        request.response.add(storedBytes);
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    try {
      final client = DAVClient(
        DAV(
          uri: 'http://${server.address.host}:${server.port}',
          user: 'test',
          password: 'password',
        ),
      );

      expect(await client.pingCompleter.future, isTrue);
      expect(await client.backup(backupBytes), isTrue);
      expect(storedBytes, backupBytes);
      expect(await client.recovery(), backupBytes);
    } finally {
      await server.close(force: true);
      await subscription.cancel();
    }
  });

  test('removes WebDAV authorization after a cross-origin redirect', () async {
    final downloadedBytes = utf8.encode('backup-data');
    final storageServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final webDavServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    var storageReceivedAuthorization = false;

    final storageSubscription = storageServer.listen((request) async {
      storageReceivedAuthorization =
          request.headers.value(HttpHeaders.authorizationHeader) != null;
      if (storageReceivedAuthorization) {
        request.response.statusCode = HttpStatus.unauthorized;
      } else {
        request.response.statusCode = HttpStatus.ok;
        request.response.add(downloadedBytes);
      }
      await request.response.close();
    });

    final webDavSubscription = webDavServer.listen((request) async {
      final authorization = request.headers.value(
        HttpHeaders.authorizationHeader,
      );
      if (authorization == null) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.headers.set(
          HttpHeaders.wwwAuthenticateHeader,
          'Basic realm="test"',
        );
      } else if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
      } else if (request.method == 'MKCOL') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
      } else if (request.method == 'GET') {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          'http://${storageServer.address.host}:${storageServer.port}/backup.zip',
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    try {
      final client = DAVClient(
        DAV(
          uri: 'http://${webDavServer.address.host}:${webDavServer.port}',
          user: 'user',
          password: 'password',
        ),
      );

      expect(await client.pingCompleter.future, isTrue);
      expect(await client.recovery(), downloadedBytes);
      expect(storageReceivedAuthorization, isFalse);
    } finally {
      await webDavServer.close(force: true);
      await storageServer.close(force: true);
      await webDavSubscription.cancel();
      await storageSubscription.cancel();
    }
  });
}
