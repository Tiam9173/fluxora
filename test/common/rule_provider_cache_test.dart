import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Paths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
  @override
  Future<String?> getDownloadsPath() async => Directory.systemTemp.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const provider = {
    'type': 'http',
    'url': 'https://rules.invalid/domain.yaml',
    'behavior': 'domain',
    'format': 'yaml',
    'interval': 86400,
  };
  Future<String> prepare(String id, Map value, {String? ua}) =>
      prepareRuleProviderCache(id, value, userAgent: ua);

  setUpAll(() async {
    PathProviderPlatform.instance = _Paths();
    await appPath.dataDir.future;
  });

  test(
    'identical rules share a cache across profiles without mutating input',
    () async {
      final a = await prepare('A', {...provider, 'path': 'old/A'});
      final b = await prepare('B', {...provider, 'path': 'old/B'});
      expect(a, b);
      expect(provider, isNot(contains('path')));
      for (final entry in {
        'url': 'https://rules.invalid/other.yaml',
        'behavior': 'classical',
        'format': 'mrs',
        'interval': 3600,
        'header': {
          'Authorization': ['Bearer private'],
        },
        'proxy': 'My group',
        'size-limit': 1000,
      }.entries) {
        expect(
          await prepare('A', {...provider, entry.key: entry.value}),
          isNot(a),
        );
      }
      expect(await prepare('A', provider, ua: 'different agent'), isNot(a));
      expect(a, isNot(contains('https:')));
    },
  );

  test(
    'legacy cache migrates with its age and never overwrites a shared file',
    () async {
      final value = {...provider, 'url': 'https://rules.invalid/migrate.yaml'};
      final oldPath = await appPath.getProvidersFilePath(
        'legacy',
        'rules',
        value['url'] as String,
      );
      final old = File(oldPath);
      await old.parent.create(recursive: true);
      await old.writeAsString('payload: [example.com]');
      final age = DateTime.now().subtract(const Duration(days: 3));
      await old.setLastModified(age);
      final path = await prepare('legacy', value);
      final shared = File(path);
      expect(await shared.readAsString(), await old.readAsString());
      expect(
        (await shared.lastModified()).difference(age).inSeconds.abs(),
        lessThan(2),
      );
      await old.writeAsString('payload: [changed.invalid]');
      expect(await prepare('legacy', value), path);
      expect(await shared.readAsString(), 'payload: [example.com]');
      expect(await prepare('another-profile', value), path);
      expect(
        (await shared.parent.list().toList()).where(
          (e) => e.path.endsWith('.tmp'),
        ),
        isEmpty,
      );
      await shared.delete();
      await old.delete();
    },
  );

  test('migration failure keeps the original cache usable', () async {
    final value = {...provider, 'url': 'https://rules.invalid/blocked.yaml'};
    final path = await prepare('blocked', value);
    await Directory(path).create(recursive: true);
    final oldPath = await appPath.getProvidersFilePath(
      'blocked',
      'rules',
      value['url'] as String,
    );
    final old = File(oldPath);
    await old.parent.create(recursive: true);
    await old.writeAsString('payload: [example.com]');
    expect(await prepare('blocked', value), oldPath);
    expect(await old.readAsString(), 'payload: [example.com]');
    await Directory(path).delete();
    await old.delete();
  });
}
