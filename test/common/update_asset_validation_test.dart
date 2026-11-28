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

  test('selects a native Linux package for known distributions', () {
    expect(
      resolveLinuxUpdateAssetSuffix('ID=ubuntu\nID_LIKE=debian', 'amd64'),
      'linux-amd64.deb',
    );
    expect(
      resolveLinuxUpdateAssetSuffix('ID=fedora\nID_LIKE="rhel"', 'amd64'),
      'linux-amd64.rpm',
    );
    expect(
      resolveLinuxUpdateAssetSuffix('ID=opensuse-leap', 'amd64'),
      'linux-amd64.rpm',
    );
    expect(
      resolveLinuxUpdateAssetSuffix('ID=debian', 'arm64'),
      'linux-arm64.deb',
    );
  });

  test('uses portable Linux package only where it is published', () {
    expect(
      resolveLinuxUpdateAssetSuffix('ID=arch', 'amd64'),
      'linux-amd64.AppImage',
    );
    expect(resolveLinuxUpdateAssetSuffix('ID=arch', 'arm64'), isNull);
    expect(resolveLinuxUpdateAssetSuffix('ID=ubuntu', 'x64'), isNull);
  });

  test('accepts a compatible build only for macOS and Linux assets', () {
    expect(
      matchesGithubReleaseAssetSuffix(
        'Fluxora-1.2.3-macos-amd64-compatible.dmg',
        'macos-amd64.dmg',
      ),
      isTrue,
    );
    expect(
      matchesGithubReleaseAssetSuffix(
        'Fluxora-1.2.3-linux-amd64-compatible.AppImage',
        'linux-amd64.AppImage',
      ),
      isTrue,
    );
    expect(
      matchesGithubReleaseAssetSuffix(
        'Fluxora-1.2.3-windows-amd64-compatible-setup.exe',
        'windows-amd64-setup.exe',
      ),
      isFalse,
    );
  });
}
