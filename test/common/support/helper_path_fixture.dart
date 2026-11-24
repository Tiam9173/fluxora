import 'dart:io';

// Test-only: path_provider_platform_interface is a transitive dependency.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class HelperPathProviderFixture {
  HelperPathProviderFixture._(this.directory, this._previous);

  final Directory directory;
  final PathProviderPlatform _previous;

  static Future<HelperPathProviderFixture> install() async {
    final directory = await Directory.systemTemp.createTemp(
      'fluxora_helper_path_',
    );
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(directory);
    return HelperPathProviderFixture._(directory, previous);
  }

  Future<void> dispose() async {
    PathProviderPlatform.instance = _previous;
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// Registers the fixture for suites that manage their setup through hooks.
void useHelperPathFixture() {
  late HelperPathProviderFixture fixture;
  setUpAll(() async {
    fixture = await HelperPathProviderFixture.install();
  });
  tearDownAll(() => fixture.dispose());
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.directory);

  final Directory directory;

  @override
  Future<String?> getTemporaryPath() async => directory.path;

  @override
  Future<String?> getApplicationSupportPath() async => directory.path;

  @override
  Future<String?> getLibraryPath() async => directory.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => directory.path;

  @override
  Future<String?> getApplicationCachePath() async => directory.path;

  @override
  Future<String?> getExternalStoragePath() async => directory.path;

  @override
  Future<List<String>?> getExternalCachePaths() async => [directory.path];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [directory.path];

  @override
  Future<String?> getDownloadsPath() async => directory.path;
}
