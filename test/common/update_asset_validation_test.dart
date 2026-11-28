import 'package:fluxora/common/request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> asset({
    String url =
        'https://github.com/Tiam9173/fluxora/releases/download/v1.2.3/Fluxora-android-arm64.apk',
    String name = 'Fluxora-android-arm64.apk',
    String? digest,
    int size = 1024,
  }) => {
    'browser_download_url': url,
    'name': name,
    'digest': digest ?? 'sha256:${List.filled(64, 'a').join()}',
    'size': size,
  };

  test('accepts a complete official release asset', () {
    final value = asset();

    expect(
      validateGithubReleaseAsset(
        value,
        assetSuffix: 'android-arm64.apk',
        releaseTag: 'v1.2.3',
      ),
      same(value),
    );
  });

  test('rejects non-GitHub and non-HTTPS downloads', () {
    for (final url in [
      'http://github.com/Tiam9173/fluxora/releases/download/v1.2.3/app.apk',
      'https://github.com.evil.example/Tiam9173/fluxora/app.apk',
      'https://github.com/attacker/fluxora/releases/download/v1.2.3/Fluxora-android-arm64.apk',
    ]) {
      expect(
        () => validateGithubReleaseAsset(asset(url: url)),
        throwsFormatException,
      );
    }
  });

  test('rejects assets from another release tag', () {
    expect(
      () => validateGithubReleaseAsset(asset(), releaseTag: 'v9.9.9'),
      throwsFormatException,
    );
  });

  test('rejects unsafe names, wrong package variants, and invalid digests', () {
    for (final value in [
      asset(name: '../Fluxora.apk'),
      asset(name: 'Fluxora-windows-setup.exe'),
      asset(digest: 'sha256:abc'),
    ]) {
      expect(
        () => validateGithubReleaseAsset(
          value,
          assetSuffix: 'android-arm64.apk',
          releaseTag: 'v1.2.3',
        ),
        throwsFormatException,
      );
    }
  });

  test('rejects empty or unexpectedly large packages', () {
    for (final size in [0, 512 * 1024 * 1024 + 1]) {
      expect(
        () => validateGithubReleaseAsset(asset(size: size)),
        throwsFormatException,
      );
    }
  });
}
