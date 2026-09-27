import 'dart:io' show Platform;

// Flutter's build-mode constants, spelled out here so this file stays free of
// `package:flutter` — `setup.dart` imports it and runs on the plain Dart VM.
// These are the same values `kDebugMode` / `kProfileMode` / `kReleaseMode` use.
const _isProductBuild = bool.fromEnvironment('dart.vm.product');
const _isProfileBuild = bool.fromEnvironment('dart.vm.profile');
const _isDebugBuild = !_isProductBuild && !_isProfileBuild;

const _useDevIdentity = bool.fromEnvironment('APP_DEV');

class AppIdentity {
  /// Explicit dev identity, set by `setup.dart --dev` (`APP_DEV=true`).
  ///
  /// Drives the *app* identity (data dir, service start type, …). Binary naming
  /// uses [usesDevBinaries], which is broader — see there.
  static const isDev = _useDevIdentity;

  /// Whether the native binaries carry the `Dev` infix.
  ///
  /// The desktop platforms do **not** agree on how they choose the name, so this
  /// mirrors each one instead of inventing a new rule:
  ///
  /// | platform | switch | source of truth |
  /// | --- | --- | --- |
  /// | Windows | build configuration | `windows/CMakeLists.txt` → `CONFIGURATIONS Debug` |
  /// | macOS | build configuration | `macos/Runner.xcodeproj` → `FLUXORA_CORE_EXECUTABLE` |
  /// | Linux | `APP_DEV` | `linux/CMakeLists.txt` → `_app_dev_found` |
  ///
  /// `setup.dart --dev` sets `APP_DEV=true`, which satisfies all three.
  ///
  /// Android / HarmonyOS are deliberately excluded: they load `libclash.so` and
  /// have no `Dev`/plain executable split.
  static bool get usesDevBinaries {
    if (isDev) return true;
    if (!_isDebugBuild) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static const productName = 'Fluxora';
  static const devSuffix = '-dev';
  static const packageId = 'io.fluxora.app';

  static const compactName = 'Fluxora';
  static const displayName = 'Fluxora';
  static const mainExecutableName = 'Fluxora';

  /// `FluxoraCore` (profile/release) or `FluxoraDevCore` (debug/dev).
  ///
  /// Same shape as `setup.dart`'s `Build.coreName`
  /// (`Build.identityName` → `'${identityName}Core'`).
  static String get coreExecutableName =>
      usesDevBinaries ? '${compactName}DevCore' : '${compactName}Core';

  static const dataDirName = 'Fluxora';
  static const tunDeviceName = 'Fluxora';
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
}

class WindowsHelperIdentity {
  /// `FluxoraHelperService` (profile/release) or `FluxoraDevHelperService`
  /// (debug/dev).
  ///
  /// Same shape as `setup.dart`'s `Build.helperName`, and the same value
  /// `windows/packaging/exe/package_windows.dart` already uses for
  /// `helperServiceName`.
  ///
  /// Used for **both** the helper executable and the Windows service, so a debug
  /// build neither hijacks nor is shadowed by a production install. The helper
  /// itself detects dev mode from this name containing "Dev"
  /// (`services/helper/src/ops.rs` → `env_contains_dev`).
  static String get serviceName => AppIdentity.usesDevBinaries
      ? '${AppIdentity.compactName}DevHelperService'
      : '${AppIdentity.compactName}HelperService';

  static const pipeName = '\\\\.\\pipe\\${AppIdentity.compactName}.Helper';
}
