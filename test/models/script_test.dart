import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// Test-only: both are transitive dependencies of `path_provider`. Without a
// working platform the `appPath` singleton throws from `getDownloadsDirectory`
// (macOS-only in the platform interface) the first time it is touched.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:path/path.dart';

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform(this.dir);

  final Directory dir;

  @override
  Future<String?> getTemporaryPath() async => dir.path;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;

  @override
  Future<String?> getLibraryPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getDownloadsPath() async => dir.path;
}

/// P1 ② — script content externalization. The migration, the atomic store and
/// the id-escape guard all live in the model, so they are tested directly;
/// the side files are redirected into a temp dir underneath `appPath`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory home;

  setUpAll(() async {
    home = await Directory.systemTemp.createTemp('fluxora_scripts_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(home);
    // Let the singleton finish its own init (it completes `dataDir` from the
    // platform once), then redirect the directory into the sandbox — replacing
    // it earlier would race the init callback.
    await appPath.dataDir.future;
    appPath.dataDir = Completer<Directory>()..complete(home);
  });

  tearDownAll(() async {
    await home.delete(recursive: true);
  });

  test('legacy inline content moves to files and leaves the config', () async {
    final large = 'x' * 100000;
    final legacy = ScriptProps.fromJson({
      'currentId': 'a',
      'scripts': [
        {
          'id': 'a',
          'label': 'A',
          'content': '// Compatible_With_Fluxora\nfunction main(c){return c}',
        },
        {'id': 'b', 'label': 'B', 'content': large},
      ],
    });

    final props = await legacy.externalize();

    expect(props.currentId, 'a');
    expect(props.scripts.every((script) => script.content.isEmpty), isTrue);
    // The whole point: the config JSON no longer carries the payload.
    expect(json.encode(props).length, lessThan(600));
    expect(props.scripts[0].compatible, isTrue);
    expect(props.scripts[0].isCompatibleWithFluxora, isTrue);
    expect(props.scripts[1].compatible, isFalse);
    expect(props.scripts[1].volatile, isFalse);
    expect(props.scripts[1].digest, large.toMd5());
    expect(await props.scripts[1].readContent(), large);
    // Idempotent: a second migrate is a no-op.
    expect(await props.externalize(), same(props));
  });

  test('saved content is read back and tracked by digest', () async {
    final draft = Script.create(label: 'C');
    final first = await draft.writeContent('function main(c){return c}');
    final second = await first.writeContent('function main(c){return {}}');

    final timed = await Script.create(
      label: 'D',
    ).writeContent('const now = new Date()');

    expect(first.content, isEmpty);
    expect(first.volatile, isFalse);
    expect(timed.volatile, isTrue);
    expect(second.digest, isNot(first.digest));
    expect(await second.readContent(), 'function main(c){return {}}');

    await second.deleteContent();

    expect(
      await File(await appPath.getScriptPath(second.id)).exists(),
      isFalse,
    );
    expect(await second.readContent(), isEmpty);
  });

  test('script ids cannot escape the scripts directory', () async {
    final path = await appPath.getScriptPath('../../outside');

    expect(File(path).parent.path, join(home.path, 'scripts'));
  });
}
