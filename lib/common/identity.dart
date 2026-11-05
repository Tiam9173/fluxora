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

  /// Whether this build is the isolated host-test identity.
  ///
  /// Used for the two things that must never be shared with a real install: the
  /// data directory (already derived) and the single-instance lock that makes
  /// the helper-stop ownership rule sound.
  static bool get isHostTest =>
      WindowsHelperIdentity.kind == HelperIdentityKind.hostTest;

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

  /// Where this build keeps its data (`%APPDATA%\<name>` on Windows).
  ///
  /// Not a constant any more: a HostTest build must not share the Release
  /// profile — the helper auth key file, the single-instance lock and the
  /// persisted proxy-ownership state all live under this directory. The
  /// Release and Dev values are unchanged (`Fluxora`).
  static String get dataDirName => WindowsHelperIdentity.spec.dataDirName;

  static const tunDeviceName = 'Fluxora';
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
}

class WindowsHelperIdentity {
  /// Release pipe name, kept `const` so [NamedPipeHelperTransport] can use it as
  /// a const default parameter. Production never relies on that default — see
  /// `helper.dart`'s `_createHelperTransport`, which passes the derived name.
  static const releasePipeName = r'\\.\pipe\Fluxora.Helper';

  /// The identity this build talks to, resolved from `HELPER_IDENTITY` first and
  /// the historical [AppIdentity.usesDevBinaries] rule second.
  static HelperIdentityKind get kind => resolveHelperIdentity(
    raw: const String.fromEnvironment('HELPER_IDENTITY'),
    usesDevBinaries: AppIdentity.usesDevBinaries,
  );

  /// The four values that must move together. Every other accessor reads this,
  /// so the service name, the pipe, the helper executable and the data
  /// directory can never drift apart.
  static HelperIdentitySpec get spec => specFor(kind);

  /// `FluxoraHelperService` (release), `FluxoraDevHelperService` (dev) or
  /// `FluxoraHostTestHelperService` (host test).
  ///
  /// Same shape as `setup.dart`'s `Build.helperName`, and the same value
  /// `windows/packaging/exe/package_windows.dart` already uses for
  /// `helperServiceName`.
  ///
  /// Used for **both** the helper executable and the Windows service, so a debug
  /// build neither hijacks nor is shadowed by a production install. The helper
  /// itself detects dev mode from this name containing "Dev"
  /// (`services/helper/src/ops.rs` → `env_contains_dev`) — which is why the
  /// HostTest name deliberately does **not** contain it.
  static String get serviceName => spec.serviceName;

  /// The named pipe this build talks to.
  ///
  /// Dev still shares the Release pipe. That is a known defect, deliberately
  /// left alone here: changing it would alter debug-build behaviour and is a
  /// separate decision (`R-BLOCK-04`). `test/common/helper_identity_test.dart`
  /// asserts the current fact so a future fix has to be explicit.
  static String get pipeName => spec.pipeName;
}

/// Which helper identity a build uses.
enum HelperIdentityKind { release, dev, hostTest }

/// The four values that have to stay in sync for one helper identity.
class HelperIdentitySpec {
  const HelperIdentitySpec({
    required this.serviceName,
    required this.pipeName,
    required this.helperExeName,
    required this.dataDirName,
  });

  final String serviceName;
  final String pipeName;
  final String helperExeName;
  final String dataDirName;
}

const _releaseHelperIdentity = HelperIdentitySpec(
  serviceName: '${AppIdentity.compactName}HelperService',
  pipeName: WindowsHelperIdentity.releasePipeName,
  helperExeName: '${AppIdentity.compactName}HelperService.exe',
  dataDirName: 'Fluxora',
);

const _devHelperIdentity = HelperIdentitySpec(
  serviceName: '${AppIdentity.compactName}DevHelperService',
  // Shares the Release pipe on purpose — see [WindowsHelperIdentity.pipeName].
  pipeName: WindowsHelperIdentity.releasePipeName,
  helperExeName: '${AppIdentity.compactName}DevHelperService.exe',
  dataDirName: 'Fluxora',
);

const _hostTestHelperIdentity = HelperIdentitySpec(
  serviceName: '${AppIdentity.compactName}HostTestHelperService',
  pipeName: r'\\.\pipe\Fluxora.HostTest.Helper',
  helperExeName: '${AppIdentity.compactName}HostTestHelperService.exe',
  // Separate profile: helper auth key, lock file and proxy-ownership state all
  // live under the data directory, and a host test must not touch the real one.
  dataDirName: '${AppIdentity.compactName}HostTest',
);

/// Pure, total, side-effect free. The single entry point for tests.
HelperIdentitySpec specFor(HelperIdentityKind kind) => switch (kind) {
  HelperIdentityKind.release => _releaseHelperIdentity,
  HelperIdentityKind.dev => _devHelperIdentity,
  HelperIdentityKind.hostTest => _hostTestHelperIdentity,
};

/// Parses an explicit `HELPER_IDENTITY` token.
///
/// Returns `null` when the token is empty (not specified). **Throws** for a
/// non-empty token it does not recognise: a typo must fail loudly rather than
/// silently select the Release service, which is exactly the fallback this
/// whole change exists to prevent.
HelperIdentityKind? parseIdentityToken(String raw) {
  final normalized = raw.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  if (normalized.isEmpty) return null;
  switch (normalized) {
    case 'hosttest':
      return HelperIdentityKind.hostTest;
    case 'dev':
      return HelperIdentityKind.dev;
    case 'release':
    case 'prod':
    case 'production':
      return HelperIdentityKind.release;
  }
  throw ArgumentError.value(
    raw,
    'HELPER_IDENTITY',
    'Unrecognised helper identity. Use "hosttest", "dev" or "release".',
  );
}

/// Resolution order, which is the contract:
///
/// 1. An explicit `HELPER_IDENTITY` token wins — and `hosttest` is checked
///    before anything else, so a host-test build can never fall back to the Dev
///    or Release identity.
/// 2. Otherwise the historical [AppIdentity.usesDevBinaries] rule decides, so a
///    debug build keeps selecting Dev without any new flag being set.
HelperIdentityKind resolveHelperIdentity({
  required String raw,
  required bool usesDevBinaries,
}) =>
    parseIdentityToken(raw) ??
    (usesDevBinaries ? HelperIdentityKind.dev : HelperIdentityKind.release);
