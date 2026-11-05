/// SEC-P0-01 — the LocalSystem helper may only run from a protected directory.
///
/// The service used to be installed straight out of the build directory
/// (`appPath.helperPath`), whose owner is the interactive user and which grants
/// `Modify` to several low-privilege principals. Replacing the EXE — or the
/// `VCRUNTIME140.dll` it imports, which Windows resolves from the application
/// directory first — meant SYSTEM code execution from a normal user account.
///
/// This module holds the rules and the verification steps. It performs **no**
/// SCM writes and never touches a real install directory on its own: it decides
/// whether a deployment *would* be safe, and refuses otherwise.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:win32_registry/win32_registry.dart';

/// The helper executable. Installed into the protected directory and used as
/// the service's `ImagePath`.
const String kHelperExeName = 'FluxoraHelperService.exe';

/// The only DLL the helper resolves from the application directory. Everything
/// else it imports is a System32 API set or a KnownDLL.
const String kHelperRuntimeDll = 'vcruntime140.dll';

/// The core image the helper is allowed to start.
///
/// It has to be part of the closure because the helper now refuses to start a
/// core from anywhere but its own (protected) directory — so the verified copy
/// is what actually runs as SYSTEM. Its own import table names only
/// `kernel32.dll`, so it brings no additional DLLs with it.
const String kCoreExeName = 'FluxoraCore.exe';

/// The verified dependency closure of the LocalSystem helper **and** the core it
/// launches.
///
/// Determined by walking the PE import tables, not by looking at filenames:
///
/// * `FluxoraHelperService.exe` imports 12 DLLs; eleven are System32 API sets
///   (`kernel32`, `advapi32`, `ntdll`, `oleaut32`, `bcryptprimitives`,
///   `api-ms-win-crt-*`, `api-ms-win-core-synch-*`). The only one Windows
///   resolves from the application directory is `VCRUNTIME140.dll`.
/// * `vcruntime140.dll` itself imports only `api-ms-win-crt-*` and `kernel32`.
/// * `FluxoraCore.exe` imports only `kernel32.dll`.
/// * `msvcp140.dll` and `vcruntime140_1.dll` are **not** imported by either
///   binary, so they are deliberately not part of the closure — deploying files
///   that nothing loads only widens the surface.
const List<String> kHelperAssetNames = <String>[
  kHelperExeName,
  kHelperRuntimeDll,
  kCoreExeName,
];

/// Default protected location. Must be under `%ProgramFiles%`.
const String kProtectedHelperRelativeDir = r'Fluxora\Service';

/// Why a deployment was refused. `none` means "safe to install".
enum HelperInstallRejection {
  none,
  notWindows,
  pathNotAbsolute,
  pathHasParentTraversal,
  pathOutsideProgramFiles,
  pathIsReparsePoint,
  finalPathDiffers,
  ownerUntrusted,
  aclUnsafe,
  aclUnknown,
  manifestMissing,
  assetMissing,
  hashMismatch,
  copyFailed,
  postCopyMismatch,
  existingUnsafeImagePath,
}

extension HelperInstallRejectionText on HelperInstallRejection {
  /// Stable, loggable text. Never includes file contents or secrets.
  String get text => switch (this) {
    HelperInstallRejection.none => 'ok',
    HelperInstallRejection.notWindows => 'not-windows',
    HelperInstallRejection.pathNotAbsolute => 'path-not-absolute',
    HelperInstallRejection.pathHasParentTraversal =>
      'path-has-parent-traversal',
    HelperInstallRejection.pathOutsideProgramFiles =>
      'path-outside-program-files',
    HelperInstallRejection.pathIsReparsePoint => 'path-is-reparse-point',
    HelperInstallRejection.finalPathDiffers => 'final-path-differs',
    HelperInstallRejection.ownerUntrusted => 'owner-untrusted',
    HelperInstallRejection.aclUnsafe => 'acl-unsafe',
    HelperInstallRejection.aclUnknown => 'acl-unknown',
    HelperInstallRejection.manifestMissing => 'manifest-missing',
    HelperInstallRejection.assetMissing => 'asset-missing',
    HelperInstallRejection.hashMismatch => 'hash-mismatch',
    HelperInstallRejection.copyFailed => 'copy-failed',
    HelperInstallRejection.postCopyMismatch => 'post-copy-mismatch',
    HelperInstallRejection.existingUnsafeImagePath =>
      'existing-unsafe-image-path',
  };
}

/// One access-control entry, reduced to what this guard cares about.
///
/// Rights are expressed as booleans so the same shape can come from the Win32
/// inspector or from a test fake without either knowing about the other.
class AclEntry {
  const AclEntry({
    required this.sid,
    required this.allow,
    this.write = false,
    this.modify = false,
    this.delete = false,
    this.writeDac = false,
    this.writeOwner = false,
    this.fullControl = false,
  });

  /// A SID string such as `S-1-5-32-545` (BUILTIN\Users).
  final String sid;
  final bool allow;
  final bool write;
  final bool modify;
  final bool delete;
  final bool writeDac;
  final bool writeOwner;
  final bool fullControl;

  bool get grantsAnyWrite =>
      write || modify || delete || writeDac || writeOwner || fullControl;
}

/// SIDs that must never be able to change a protected executable.
///
/// `S-1-1-0` Everyone, `S-1-5-11` Authenticated Users, `S-1-5-32-545` Users,
/// `S-1-5-4` Interactive, `S-1-5-7` Anonymous, `S-1-2-0` Local,
/// `S-1-5-32-546` Guests, `S-1-5-32-547` Power Users.
const Set<String> kLowPrivilegeSids = <String>{
  'S-1-1-0',
  'S-1-2-0',
  'S-1-5-4',
  'S-1-5-7',
  'S-1-5-11',
  'S-1-5-32-545',
  'S-1-5-32-546',
  'S-1-5-32-547',
};

/// Owners that may legitimately hold a protected executable.
///
/// The owner of an object implicitly holds `WRITE_DAC` and `READ_CONTROL`, so a
/// file whose owner is an ordinary user can be re-ACL'd into a writable state
/// even when the current ACEs look clean. Checking the ACEs alone is therefore
/// not enough — the owner has to be privileged too.
const Set<String> kTrustedOwnerSids = <String>{
  'S-1-5-18', // NT AUTHORITY\SYSTEM
  'S-1-5-32-544', // BUILTIN\Administrators
  // NT SERVICE\TrustedInstaller
  'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464',
};

/// What the guard needs to know about a path on disk.
class PathSecurityFacts {
  const PathSecurityFacts({
    required this.exists,
    required this.isReparsePoint,
    required this.finalPath,
    required this.ownerSid,
    required this.entries,
    this.unknown = false,
  });

  /// Used when inspection failed for any reason. Treated as **unsafe**: a guard
  /// that cannot verify must refuse, never assume.
  const PathSecurityFacts.unknown()
    : exists = false,
      isReparsePoint = true,
      finalPath = '',
      ownerSid = '',
      entries = const <AclEntry>[],
      unknown = true;

  final bool exists;
  final bool isReparsePoint;
  final String finalPath;
  final String ownerSid;
  final List<AclEntry> entries;
  final bool unknown;
}

/// Reads real security facts for a path. The production implementation uses
/// Win32; tests supply a fake so nothing has to touch Program Files.
abstract class AclInspector {
  Future<PathSecurityFacts> inspect(String path);
}

/// Expected hashes for the deployment closure.
///
/// Parsed from `--dart-define=HELPER_ASSET_SHA256=<name>=<hash>,<name>=<hash>`,
/// mirroring how `CORE_SHA256` already works. When the define is absent the
/// guard refuses to install: without a build-provided anchor, any hash computed
/// at install time would come from the same user-writable files it is meant to
/// protect, which proves nothing.
class HelperAssetManifest {
  const HelperAssetManifest(this.hashes);

  final Map<String, String> hashes;

  bool get isEmpty => hashes.isEmpty;

  /// Reads the compile-time define. Returns an empty manifest when it is absent.
  factory HelperAssetManifest.fromEnvironment() {
    const raw = String.fromEnvironment('HELPER_ASSET_SHA256');
    return HelperAssetManifest.parse(raw);
  }

  /// Parses `name=hash` pairs separated by commas. Malformed entries are dropped
  /// rather than guessed at — a partial manifest then fails the asset check.
  factory HelperAssetManifest.parse(String raw) {
    final map = <String, String>{};
    for (final part in raw.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0 || eq == trimmed.length - 1) continue;
      final name = trimmed.substring(0, eq).trim();
      final hash = trimmed.substring(eq + 1).trim().toLowerCase();
      if (name.isEmpty || !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) continue;
      map[name] = hash;
    }
    return HelperAssetManifest(map);
  }

  /// Every expected asset must be present, and no extras are accepted.
  bool coversExactly(Iterable<String> required) {
    final want = required.toSet();
    return want.isNotEmpty &&
        hashes.length == want.length &&
        want.every(hashes.containsKey);
  }
}

/// The decision the guard reaches, plus the reason and the file plan.
class HelperInstallDecision {
  const HelperInstallDecision({
    required this.rejection,
    required this.targetDir,
    required this.assets,
    this.canInstall = false,
  });

  final HelperInstallRejection rejection;
  final String targetDir;
  final List<String> assets;
  final bool canInstall;

  bool get safe => rejection == HelperInstallRejection.none && canInstall;

  @override
  String toString() =>
      'HelperInstallDecision(${rejection.text}, canInstall=$canInstall, '
      'target="$targetDir")';
}

/// Parses an `sc qc` `BINARY_PATH_NAME` value and answers "is this exactly the
/// path we expect?".
///
/// The previous check compared only the file name, so a service pointing at
/// `C:\Users\…\build\…\FluxoraHelperService.exe` looked identical to a correct
/// one. Quoting, arguments, short (8.3) names, `\\?\` prefixes and case all
/// have to be normalised before comparing — and anything that cannot be parsed
/// unambiguously is treated as a mismatch.
class ImagePathMatcher {
  /// Strips surrounding quotes, an NT path prefix and any trailing arguments.
  ///
  /// Returns null for anything that cannot be reduced to one unambiguous
  /// executable path — the caller then treats it as a mismatch.
  static String? normalise(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;

    // Quoted form: "C:\path\app.exe" [args]
    if (value.startsWith('"')) {
      final close = value.indexOf('"', 1);
      if (close < 0) return null; // unbalanced quote — refuse to guess
      value = value.substring(1, close);
    } else {
      // Unquoted with arguments: cut at the last `.exe`. Only a whitespace
      // boundary may follow it — `app.exe.backup` is a *different file*, and
      // truncating it to `app.exe` would report a planted copy as trusted.
      final lower = value.toLowerCase();
      final exeIdx = lower.lastIndexOf('.exe');
      if (exeIdx >= 0) {
        final after = exeIdx + 4;
        final rest = value.substring(after);
        if (rest.isNotEmpty && rest[0] != ' ' && rest[0] != '\t') return null;
        value = value.substring(0, after);
      }
    }

    value = value.trim();
    // `\\?\` (Win32 long path) and `\??\` (raw NT object prefix) both name the
    // same file; leaving either in place would make an equal path compare as
    // different.
    for (final prefix in const <String>['\\\\?\\', '\\??\\']) {
      if (value.startsWith(prefix)) {
        value = value.substring(prefix.length);
        break;
      }
    }
    if (value.isEmpty) return null;

    return value.replaceAll('/', r'\');
  }

  /// True when [actual] names exactly [expected] (case-insensitive, as NTFS).
  static bool matches(String expected, String actual) {
    final a = normalise(expected);
    final b = normalise(actual);
    if (a == null || b == null) return false;
    return a.toLowerCase() == b.toLowerCase();
  }
}

/// Path rules that need no I/O: absolute, inside Program Files, no `..`.
class ProtectedPathRules {
  const ProtectedPathRules._();

  /// Test-only: replaces the registry lookup that resolves `%ProgramFiles%`.
  static String? Function()? programFilesOverrideForTest;

  /// Resolves `%ProgramFiles%` from the **machine registry**, not the
  /// environment.
  ///
  /// `Platform.environment['ProgramFiles']` is whatever the launching process
  /// put there — an attacker who can set that variable before starting Fluxora
  /// would otherwise choose the "protected" directory themselves. The registry
  /// value under `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion` can only be
  /// changed by an administrator.
  ///
  /// Returns null when it cannot be read; every caller treats that as "no
  /// trusted path exists" and fails closed.
  static String? programFilesDir() {
    final override = programFilesOverrideForTest;
    if (override != null) return override();

    if (!Platform.isWindows) return null;
    RegistryKey? key;
    try {
      key = Registry.openPath(
        RegistryHive.localMachine,
        path: r'SOFTWARE\Microsoft\Windows\CurrentVersion',
        desiredAccessRights: AccessRights.readOnly,
      );
      final value = key.getStringValue('ProgramFilesDir');
      if (value == null || value.trim().isEmpty) return null;
      return value.trim().replaceAll('/', r'\');
    } catch (_) {
      return null;
    } finally {
      key?.close();
    }
  }

  /// `%ProgramFiles%\Fluxora\Service`
  static String? defaultProtectedDir() {
    final root = programFilesDir();
    if (root == null) return null;
    return '$root\\$kProtectedHelperRelativeDir';
  }

  /// `%ProgramFiles%\Fluxora\Service\FluxoraHelperService.exe`
  ///
  /// Returns null when `%ProgramFiles%` cannot be resolved, which callers must
  /// treat as "no trusted path exists" and fail closed.
  static String? defaultProtectedExePath() {
    final dir = defaultProtectedDir();
    if (dir == null) return null;
    return '$dir\\$kHelperExeName';
  }

  /// `%ProgramFiles%\Fluxora\Service\FluxoraCore.exe`
  ///
  /// The helper only starts a core from its own directory, so this is the path
  /// it is given once the deployment has put a verified copy there.
  static String? defaultProtectedCorePath() {
    final dir = defaultProtectedDir();
    if (dir == null) return null;
    return '$dir\\$kCoreExeName';
  }

  /// Pure lexical check — no filesystem access, so it is identical on every OS
  /// and safe to unit test anywhere.
  static HelperInstallRejection checkLexical(
    String path, {
    String? programFiles,
  }) {
    if (path.trim().isEmpty) return HelperInstallRejection.pathNotAbsolute;

    final normalised = path.replaceAll('/', r'\');
    final isAbsolute =
        RegExp(r'^[A-Za-z]:\\').hasMatch(normalised) ||
        normalised.startsWith(r'\\');
    if (!isAbsolute) return HelperInstallRejection.pathNotAbsolute;

    final segments = normalised.split(r'\');
    if (segments.contains('..')) {
      return HelperInstallRejection.pathHasParentTraversal;
    }

    final root = programFiles;
    if (root == null) return HelperInstallRejection.pathOutsideProgramFiles;
    final rootNorm = root.replaceAll('/', r'\').toLowerCase();
    if (!normalised.toLowerCase().startsWith('$rootNorm\\')) {
      return HelperInstallRejection.pathOutsideProgramFiles;
    }
    return HelperInstallRejection.none;
  }
}

/// What the caller gets back from [HelperInstaller.prepare].
class HelperInstallOutcome {
  const HelperInstallOutcome(this.decision, {this.failClosedAt});

  final HelperInstallDecision decision;

  /// Set when verification stopped early. Never null when [decision] is unsafe.
  final String? failClosedAt;
}

/// Copies the helper closure into a protected directory after verifying it.
///
/// Deliberately does **no** SCM work: it produces a verified directory, and the
/// service configuration step (a separate, authorised action) points at it.
class HelperInstaller {
  HelperInstaller({
    required this.inspector,
    required this.manifest,
    this.hashFile = _defaultHashFile,
    this.copyFile = _defaultCopyFile,
    this.fileExists = _defaultFileExists,
    this.now = DateTime.now,
  });

  final AclInspector inspector;
  final HelperAssetManifest manifest;
  final Future<String> Function(File file) hashFile;
  final Future<void> Function(File from, File to) copyFile;

  /// Existence probe. Injectable so the whole verification sequence can be
  /// driven by fakes — the ordering (source exists → hashed → copied → hashed
  /// again → ACL-checked) is what the tests assert, and none of it should need
  /// a writable copy of Program Files.
  final Future<bool> Function(String path) fileExists;
  final DateTime Function() now;

  static Future<bool> _defaultFileExists(String path) => File(path).exists();

  static Future<String> _defaultHashFile(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static Future<void> _defaultCopyFile(File from, File to) async {
    await to.parent.create(recursive: true);
    await from.copy(to.path);
  }

  /// Verifies the source closure and the target location, then copies.
  ///
  /// Every failure path returns an unsafe decision; nothing is copied unless
  /// both the path rules and every hash pass.
  ///
  /// With `copy: false` the method stops after the source hashes and reports
  /// "cleared for deployment" without touching the target directory. That is
  /// how the elevated copy is kept separate: the caller copies from an elevated
  /// context and then calls [verifyDeployed] to prove what actually landed.
  Future<HelperInstallOutcome> prepare({
    required String sourceDir,
    required String targetDir,
    String? programFiles,
    bool isWindows = true,
    bool copy = true,
  }) async {
    HelperInstallOutcome refuse(HelperInstallRejection why, {String? at}) =>
        HelperInstallOutcome(
          HelperInstallDecision(
            rejection: why,
            targetDir: targetDir,
            assets: kHelperAssetNames,
          ),
          failClosedAt: at ?? why.text,
        );

    if (!isWindows) return refuse(HelperInstallRejection.notWindows);

    final lexical = ProtectedPathRules.checkLexical(
      targetDir,
      programFiles: programFiles ?? ProtectedPathRules.programFilesDir(),
    );
    if (lexical != HelperInstallRejection.none) return refuse(lexical);

    // No build-provided anchor ⇒ nothing can be proven ⇒ refuse.
    if (manifest.isEmpty || !manifest.coversExactly(kHelperAssetNames)) {
      return refuse(HelperInstallRejection.manifestMissing);
    }

    // Target directory, when it already exists, must itself be protected.
    final targetFacts = await inspector.inspect(targetDir);
    if (targetFacts.unknown) return refuse(HelperInstallRejection.aclUnknown);
    if (targetFacts.exists) {
      final targetVerdict = _judge(targetFacts, targetDir);
      if (targetVerdict != HelperInstallRejection.none) {
        return refuse(targetVerdict);
      }
    }

    // Source files: existence + hash, before anything is copied.
    final sourceFiles = <String, File>{};
    for (final name in kHelperAssetNames) {
      final file = File('$sourceDir${Platform.pathSeparator}$name');
      if (!await fileExists(file.path)) {
        return refuse(HelperInstallRejection.assetMissing, at: 'source:$name');
      }
      sourceFiles[name] = file;
    }

    for (final name in kHelperAssetNames) {
      final actual = await hashFile(sourceFiles[name]!);
      if (actual.toLowerCase() != manifest.hashes[name]) {
        return refuse(HelperInstallRejection.hashMismatch, at: 'source:$name');
      }
    }

    // Pre-flight only. The caller copies from an elevated context and must then
    // call [verifyDeployed] — the source being good says nothing about what
    // landed in the target directory.
    if (!copy) {
      return HelperInstallOutcome(
        HelperInstallDecision(
          rejection: HelperInstallRejection.none,
          targetDir: targetDir,
          assets: kHelperAssetNames,
          canInstall: true,
        ),
      );
    }

    // Copy, then verify again — a copy that was tampered with in flight must not
    // be reported as a success.
    final copied = <String, File>{};
    for (final name in kHelperAssetNames) {
      final destination = File('$targetDir${Platform.pathSeparator}$name');
      try {
        await copyFile(sourceFiles[name]!, destination);
      } catch (_) {
        return refuse(HelperInstallRejection.copyFailed, at: 'copy:$name');
      }
      copied[name] = destination;
    }

    for (final name in kHelperAssetNames) {
      if (!await fileExists(copied[name]!.path)) {
        return refuse(
          HelperInstallRejection.postCopyMismatch,
          at: 'target:$name',
        );
      }
      final actual = await hashFile(copied[name]!);
      if (actual.toLowerCase() != manifest.hashes[name]) {
        return refuse(
          HelperInstallRejection.postCopyMismatch,
          at: 'target:$name',
        );
      }
    }

    // The deployed binaries must not be writable by a low-privilege principal.
    for (final name in kHelperAssetNames) {
      final facts = await inspector.inspect(copied[name]!.path);
      if (facts.unknown) return refuse(HelperInstallRejection.aclUnknown);
      final verdict = _judge(facts, copied[name]!.path);
      if (verdict != HelperInstallRejection.none) {
        return refuse(verdict, at: 'acl:$name');
      }
    }

    return HelperInstallOutcome(
      HelperInstallDecision(
        rejection: HelperInstallRejection.none,
        targetDir: targetDir,
        assets: kHelperAssetNames,
        canInstall: true,
      ),
    );
  }

  /// Verifies what is **already** in the target directory.
  ///
  /// Runs after the elevated copy, and re-checks everything that matters: the
  /// directory is still the protected one, every asset is present, every hash
  /// still matches the build-provided manifest, and no low-privilege principal
  /// can rewrite them. A copy that was redirected, truncated or replaced in
  /// flight has to fail here — otherwise the caller would go on to create a
  /// LocalSystem service pointing at it.
  Future<HelperInstallOutcome> verifyDeployed({
    required String targetDir,
    String? programFiles,
    bool isWindows = true,
  }) async {
    HelperInstallOutcome refuse(HelperInstallRejection why, {String? at}) =>
        HelperInstallOutcome(
          HelperInstallDecision(
            rejection: why,
            targetDir: targetDir,
            assets: kHelperAssetNames,
          ),
          failClosedAt: at ?? why.text,
        );

    if (!isWindows) return refuse(HelperInstallRejection.notWindows);

    final lexical = ProtectedPathRules.checkLexical(
      targetDir,
      programFiles: programFiles ?? ProtectedPathRules.programFilesDir(),
    );
    if (lexical != HelperInstallRejection.none) return refuse(lexical);

    if (manifest.isEmpty || !manifest.coversExactly(kHelperAssetNames)) {
      return refuse(HelperInstallRejection.manifestMissing);
    }

    final targetFacts = await inspector.inspect(targetDir);
    if (targetFacts.unknown) return refuse(HelperInstallRejection.aclUnknown);
    if (!targetFacts.exists) {
      return refuse(HelperInstallRejection.assetMissing, at: 'target-dir');
    }
    final targetVerdict = _judge(targetFacts, targetDir);
    if (targetVerdict != HelperInstallRejection.none) {
      return refuse(targetVerdict);
    }

    for (final name in kHelperAssetNames) {
      final deployed = File('$targetDir${Platform.pathSeparator}$name');
      if (!await fileExists(deployed.path)) {
        return refuse(HelperInstallRejection.assetMissing, at: 'target:$name');
      }
      final actual = await hashFile(deployed);
      if (actual.toLowerCase() != manifest.hashes[name]) {
        return refuse(
          HelperInstallRejection.postCopyMismatch,
          at: 'target:$name',
        );
      }
      final facts = await inspector.inspect(deployed.path);
      if (facts.unknown) return refuse(HelperInstallRejection.aclUnknown);
      final verdict = _judge(facts, deployed.path);
      if (verdict != HelperInstallRejection.none) {
        return refuse(verdict, at: 'acl:$name');
      }
    }

    return HelperInstallOutcome(
      HelperInstallDecision(
        rejection: HelperInstallRejection.none,
        targetDir: targetDir,
        assets: kHelperAssetNames,
        canInstall: true,
      ),
    );
  }

  /// A path is safe only when it exists, is not a reparse point, resolves to
  /// exactly the path we asked about, is owned by a privileged principal, and
  /// grants no write-class right to a low-privilege SID.
  HelperInstallRejection _judge(PathSecurityFacts facts, String expectedPath) {
    if (facts.unknown) return HelperInstallRejection.aclUnknown;
    if (facts.isReparsePoint) return HelperInstallRejection.pathIsReparsePoint;
    if (facts.finalPath.isNotEmpty) {
      final resolved = facts.finalPath.replaceAll('/', r'\').toLowerCase();
      final expected = expectedPath.replaceAll('/', r'\').toLowerCase();
      if (resolved != expected) {
        return HelperInstallRejection.finalPathDiffers;
      }
    }
    // An unverifiable owner is treated as untrusted: the owner can always
    // rewrite the DACL, so "no write ACE today" proves nothing on its own.
    if (!kTrustedOwnerSids.contains(facts.ownerSid)) {
      return HelperInstallRejection.ownerUntrusted;
    }
    for (final entry in facts.entries) {
      if (!entry.allow) continue;
      if (!kLowPrivilegeSids.contains(entry.sid)) continue;
      if (entry.grantsAnyWrite) return HelperInstallRejection.aclUnsafe;
    }
    return HelperInstallRejection.none;
  }
}

/// Decides what to do with an already-installed service.
enum HelperMigrationAction {
  /// Nothing installed — a fresh install is required.
  install,

  /// Installed, but pointing somewhere unsafe — must be migrated.
  migrate,

  /// Installed at the protected path — leave it alone.
  keep,

  /// Installed somewhere else entirely — never touch it.
  identityConflict,
}

/// Pure decision function for the migration step.
///
/// A service that is merely *running* is never assumed to be migrated: only an
/// ImagePath that matches the protected target counts.
class HelperMigrationPolicy {
  const HelperMigrationPolicy._();

  static HelperMigrationAction decide({
    required bool installed,
    required String? imagePath,
    required String protectedExePath,
    String? programFiles,
  }) {
    if (!installed) return HelperMigrationAction.install;

    if (ImagePathMatcher.matches(protectedExePath, imagePath ?? '')) {
      return HelperMigrationAction.keep;
    }

    final normalised = ImagePathMatcher.normalise(imagePath ?? '');
    if (normalised == null) return HelperMigrationAction.identityConflict;

    final lexical = ProtectedPathRules.checkLexical(
      normalised,
      programFiles: programFiles ?? ProtectedPathRules.programFilesDir(),
    );
    // Somewhere outside Program Files: it may be a stale build directory we own
    // (migrate) — but an unreadable path is never silently replaced.
    return lexical == HelperInstallRejection.pathOutsideProgramFiles
        ? HelperMigrationAction.migrate
        : HelperMigrationAction.identityConflict;
  }
}

/// Encodes a manifest for logging without leaking anything sensitive.
String describeManifest(HelperAssetManifest manifest) =>
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'assets': manifest.hashes.keys.toList()..sort(),
      'complete': manifest.coversExactly(kHelperAssetNames),
    });

// ---------------------------------------------------------------------------
// Build-side helpers
//
// These run in the trusted build (CI or `dart setup.dart`), never at install
// time. Their whole purpose is to turn "the files we just built" into an anchor
// the installed app can compare against, and to fail the build when the two
// disagree.
// ---------------------------------------------------------------------------

final RegExp _sha256Hex = RegExp(r'^[0-9a-f]{64}$');

/// Formats measured hashes into the `HELPER_ASSET_SHA256` define value.
///
/// Throws [ArgumentError] when a closure member is missing, its hash is
/// malformed, or the map carries an asset that is not part of the closure.
/// A partial anchor is worse than none: it would silently drop the DLL.
String buildHelperAssetDefine(Map<String, String> hashes) {
  if (hashes.length != kHelperAssetNames.length) {
    throw ArgumentError(
      'helper asset closure mismatch: expected ${kHelperAssetNames.length} '
      'entries, got ${hashes.length}',
    );
  }
  final parts = <String>[];
  for (final name in kHelperAssetNames) {
    final hash = hashes[name]?.toLowerCase();
    if (hash == null || !_sha256Hex.hasMatch(hash)) {
      throw ArgumentError('missing or malformed sha256 for "$name"');
    }
    parts.add('$name=$hash');
  }
  return parts.join(',');
}

/// Hashes one file, failing closed when it is not there.
Future<String> sha256OfFile(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw FileSystemException('helper asset missing', path);
  }
  return (await sha256.bind(file.openRead()).first).toString();
}

/// Hashes every closure member inside [dir].
///
/// Throws [FileSystemException] when one is missing — the build must stop rather
/// than ship a bundle whose anchor does not describe it.
Future<Map<String, String>> hashHelperAssetsIn(String dir) async {
  final out = <String, String>{};
  for (final name in kHelperAssetNames) {
    out[name] = await sha256OfFile('$dir${Platform.pathSeparator}$name');
  }
  return out;
}

/// Null when [dir] matches [manifestText]; otherwise a human-readable reason.
///
/// This is the post-build consistency gate: it compares what packaging actually
/// produced against the anchor that was compiled into the app.
Future<String?> checkHelperAssetsAgainstManifest({
  required String dir,
  required String manifestText,
}) async {
  final expected = HelperAssetManifest.parse(manifestText);
  if (expected.isEmpty || !expected.coversExactly(kHelperAssetNames)) {
    return 'anchor is empty or incomplete';
  }
  final Map<String, String> actual;
  try {
    actual = await hashHelperAssetsIn(dir);
  } on FileSystemException catch (e) {
    return '${e.message}: ${e.path}';
  }
  for (final name in kHelperAssetNames) {
    if (actual[name] != expected.hashes[name]) {
      return '$name mismatch: anchor=${expected.hashes[name]} '
          'bundle=${actual[name]}';
    }
  }
  return null;
}

/// The core entry in [anchor] must equal the `CORE_SHA256` compiled into the app.
///
/// The helper's `TOKEN` and the app's `CORE_SHA256` are both produced from the
/// same `FluxoraCore.exe` in the same build, so all three have to agree. If they
/// do not, the install would accept a core that the helper then refuses to
/// start — or, worse, two different images would be described as one.
///
/// Null when they agree; otherwise the reason.
String? coreAnchorMismatch({
  required String anchor,
  required String coreSha256,
}) {
  final expected = coreSha256.trim().toLowerCase();
  if (!_sha256Hex.hasMatch(expected)) {
    return 'CORE_SHA256 is missing or malformed';
  }
  final inAnchor = HelperAssetManifest.parse(anchor).hashes[kCoreExeName];
  if (inAnchor == null) return 'anchor has no $kCoreExeName entry';
  if (inAnchor != expected) {
    return '$kCoreExeName anchor=$inAnchor but CORE_SHA256=$expected';
  }
  return null;
}
