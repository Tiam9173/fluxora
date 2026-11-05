import 'dart:convert';
import 'dart:io';

import 'package:fluxora/common/protected_helper.dart';
import 'package:fluxora/common/win32_acl_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

/// SEC-P0-01 — the LocalSystem helper must only ever run from a protected
/// directory.
///
/// Everything here is pure logic, fakes, or temp directories. No SCM call, no
/// Program Files write, no real helper process.
void main() {
  const programFiles = r'C:\Program Files';
  const protectedDir = r'C:\Program Files\Fluxora\Service';
  const protectedExe =
      r'C:\Program Files\Fluxora\Service\FluxoraHelperService.exe';
  const buildDir =
      r'D:\MyASUS\Documents\ChatGPT\box\fluxora-rc6-branch\build\windows\x64\runner\Release';

  // ---------------------------------------------------------------- group 1
  group('1 — protected path rules', () {
    test('the documented install directory is accepted', () {
      expect(
        ProtectedPathRules.checkLexical(
          protectedDir,
          programFiles: programFiles,
        ),
        HelperInstallRejection.none,
      );
      expect(
        ProtectedPathRules.checkLexical(
          protectedExe,
          programFiles: programFiles,
        ),
        HelperInstallRejection.none,
      );
    });

    test('the build directory the helper used to live in is rejected', () {
      expect(
        ProtectedPathRules.checkLexical(buildDir, programFiles: programFiles),
        HelperInstallRejection.pathOutsideProgramFiles,
      );
    });

    test('user-writable roots are rejected', () {
      for (final path in <String>[
        r'C:\Users\someone\AppData\Roaming\Fluxora\Service',
        r'C:\Users\someone\AppData\Local\Temp\Fluxora',
        r'D:\Fluxora\Service',
      ]) {
        expect(
          ProtectedPathRules.checkLexical(path, programFiles: programFiles),
          HelperInstallRejection.pathOutsideProgramFiles,
          reason: path,
        );
      }
    });

    test('relative paths and parent traversal are rejected', () {
      expect(
        ProtectedPathRules.checkLexical(
          r'Fluxora\Service',
          programFiles: programFiles,
        ),
        HelperInstallRejection.pathNotAbsolute,
      );
      expect(
        ProtectedPathRules.checkLexical(
          r'C:\Program Files\Fluxora\..\..\Users\public',
          programFiles: programFiles,
        ),
        HelperInstallRejection.pathHasParentTraversal,
      );
      expect(
        ProtectedPathRules.checkLexical('', programFiles: programFiles),
        HelperInstallRejection.pathNotAbsolute,
      );
    });

    test('a path that only shares a prefix with Program Files is rejected', () {
      // "C:\Program Files Evil\..." must not pass a naive startsWith check.
      expect(
        ProtectedPathRules.checkLexical(
          r'C:\Program Files Evil\Fluxora\Service',
          programFiles: programFiles,
        ),
        HelperInstallRejection.pathOutsideProgramFiles,
      );
    });

    test('an unknown %ProgramFiles% fails closed', () {
      expect(
        ProtectedPathRules.checkLexical(protectedDir),
        HelperInstallRejection.pathOutsideProgramFiles,
      );
    });

    test('the protected core path sits beside the helper', () {
      ProtectedPathRules.programFilesOverrideForTest = () => programFiles;
      addTearDown(() => ProtectedPathRules.programFilesOverrideForTest = null);

      expect(ProtectedPathRules.defaultProtectedExePath(), protectedExe);
      expect(
        ProtectedPathRules.defaultProtectedCorePath(),
        '$protectedDir\\$kCoreExeName',
      );
    });

    test('without %ProgramFiles% there is no protected core path at all', () {
      ProtectedPathRules.programFilesOverrideForTest = () => null;
      addTearDown(() => ProtectedPathRules.programFilesOverrideForTest = null);

      expect(ProtectedPathRules.defaultProtectedDir(), isNull);
      expect(ProtectedPathRules.defaultProtectedExePath(), isNull);
      expect(ProtectedPathRules.defaultProtectedCorePath(), isNull);
    });
  });

  // ---------------------------------------------------------------- group 2
  group('2 — ACL and owner', () {
    test('only SYSTEM and Administrators may hold write rights', () async {
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir))
        ..set(protectedExe, _facts(protectedExe));
      final outcome = await _prepare(
        inspector: inspector,
        manifest: _manifestFor('aa'),
      );
      expect(outcome.decision.safe, isTrue, reason: '$outcome.decision');
    });

    test('BUILTIN\\Users with Modify makes the target unsafe', () async {
      final inspector = _FakeInspector()
        ..set(
          protectedDir,
          _facts(
            protectedDir,
            extra: const [
              AclEntry(sid: 'S-1-5-32-545', allow: true, modify: true),
            ],
          ),
        )
        ..set(protectedExe, _facts(protectedExe));
      final outcome = await _prepare(
        inspector: inspector,
        manifest: _manifestFor('aa'),
      );
      expect(outcome.decision.canInstall, isFalse);
      expect(outcome.decision.rejection, HelperInstallRejection.aclUnsafe);
    });

    test('WriteDac alone is enough to reject', () async {
      // WriteDac lets the holder re-ACL the file even without Write, so it is
      // treated as a write-class right.
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir))
        ..set(
          protectedExe,
          _facts(
            protectedExe,
            extra: const [
              AclEntry(sid: 'S-1-5-11', allow: true, writeDac: true),
            ],
          ),
        );
      final outcome = await _prepare(
        inspector: inspector,
        manifest: _manifestFor('aa'),
      );
      expect(outcome.decision.rejection, HelperInstallRejection.aclUnsafe);
    });

    test('WriteOwner alone is enough to reject', () async {
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir))
        ..set(
          protectedExe,
          _facts(
            protectedExe,
            extra: const [
              AclEntry(sid: 'S-1-5-4', allow: true, writeOwner: true),
            ],
          ),
        );
      final outcome = await _prepare(
        inspector: inspector,
        manifest: _manifestFor('aa'),
      );
      expect(outcome.decision.rejection, HelperInstallRejection.aclUnsafe);
    });

    test(
      'a deny entry for a low-privilege SID is not treated as a grant',
      () async {
        final inspector = _FakeInspector()
          ..set(protectedDir, _facts(protectedDir))
          ..set(
            protectedExe,
            _facts(
              protectedExe,
              extra: const [
                AclEntry(sid: 'S-1-5-32-545', allow: false, fullControl: true),
              ],
            ),
          );
        final outcome = await _prepare(
          inspector: inspector,
          manifest: _manifestFor('aa'),
        );
        expect(outcome.decision.safe, isTrue);
      },
    );

    test('an inspection failure is unsafe, never "fine"', () async {
      final inspector = _FakeInspector()
        ..defaultSafe = false
        ..set(protectedDir, _facts(protectedDir));
      // The deployed assets are deliberately not configured → unknown facts.
      final outcome = await _prepare(
        inspector: inspector,
        manifest: _manifestFor('aa'),
      );
      expect(outcome.decision.canInstall, isFalse);
      expect(outcome.decision.rejection, HelperInstallRejection.aclUnknown);
    });

    test('an owner that is not SYSTEM or Administrators is refused', () async {
      // The owner implicitly holds WRITE_DAC, so clean ACEs prove nothing when
      // the owner is an ordinary user.
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir))
        ..set(
          protectedExe,
          _facts(
            protectedExe,
            ownerSid: 'S-1-5-21-1111111111-2222222222-3333333333-1001',
          ),
        );
      final outcome = await _prepare(
        inspector: inspector,
        manifest: _manifestFor('aa'),
      );
      expect(outcome.decision.rejection, HelperInstallRejection.ownerUntrusted);
    });

    test('CreateFiles on the directory counts as a write grant', () {
      // Windows often reports granular rights instead of `Modify`; "Write"
      // never appears, yet the holder can drop a planted EXE into the folder.
      final facts = Win32AclInspector.factsFromJson(
        jsonDecode('''
        {"exists":true,"isReparse":false,"finalPath":"C:\\\\Program Files\\\\Fluxora\\\\Service",
         "ownerSid":"S-1-5-32-544",
         "aces":[
           {"sid":"S-1-5-32-545","allow":true,"rights":"CreateFiles, Synchronize"}
         ]}
        ''')
            as Map<dynamic, dynamic>,
      );
      expect(facts.entries.single.write, isTrue);
      expect(facts.entries.single.grantsAnyWrite, isTrue);
    });

    test('the Win32 JSON mapping keeps SIDs and rights apart', () {
      final facts = Win32AclInspector.factsFromJson(
        jsonDecode('''
        {"exists":true,"isReparse":false,"finalPath":"C:\\\\Program Files\\\\Fluxora\\\\Service",
         "ownerSid":"S-1-5-32-544",
         "aces":[
           {"sid":"S-1-5-18","allow":true,"rights":"FullControl"},
           {"sid":"S-1-5-32-545","allow":true,"rights":"ReadAndExecute, Synchronize"},
           {"sid":"S-1-5-11","allow":true,"rights":"WriteDac, Synchronize"}
         ]}
        ''')
            as Map<dynamic, dynamic>,
      );
      expect(facts.ownerSid, 'S-1-5-32-544');
      expect(facts.entries, hasLength(3));
      // "ReadAndExecute" must not be read as a write grant.
      expect(facts.entries[1].grantsAnyWrite, isFalse);
      // "WriteDac" must not be read as a plain Write, but must still count.
      expect(facts.entries[2].write, isFalse);
      expect(facts.entries[2].writeDac, isTrue);
      expect(facts.entries[2].grantsAnyWrite, isTrue);
    });
  });

  // ---------------------------------------------------------------- group 3
  group('3 — reparse points and final path', () {
    test('a reparse point on the target directory is refused', () async {
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir, reparse: true))
        ..set(protectedExe, _facts(protectedExe));
      final outcome = await _prepare(
        inspector: inspector,
        manifest: _manifestFor('aa'),
      );
      expect(
        outcome.decision.rejection,
        HelperInstallRejection.pathIsReparsePoint,
      );
    });

    test('a reparse point on a deployed asset is refused', () async {
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir))
        ..set(protectedExe, _facts(protectedExe, reparse: true));
      final outcome = await _prepare(
        inspector: inspector,
        manifest: _manifestFor('aa'),
      );
      expect(
        outcome.decision.rejection,
        HelperInstallRejection.pathIsReparsePoint,
      );
    });

    test(
      'a resolved path that differs from the requested one is refused',
      () async {
        // e.g. a junction inside Program Files pointing at %TEMP%.
        final inspector = _FakeInspector()
          ..set(
            protectedDir,
            _facts(
              protectedDir,
              finalPath: r'C:\Users\someone\AppData\Local\Temp\x',
            ),
          )
          ..set(protectedExe, _facts(protectedExe));
        final outcome = await _prepare(
          inspector: inspector,
          manifest: _manifestFor('aa'),
        );
        expect(
          outcome.decision.rejection,
          HelperInstallRejection.finalPathDiffers,
        );
      },
    );
  });

  // ---------------------------------------------------------------- group 4
  group('4 — helper EXE and DLL integrity', () {
    test('the closure is helper + vcruntime140 + core, nothing else', () {
      // Verified from the PE import tables: the helper needs vcruntime140.dll
      // from its own directory, the core needs nothing outside System32, and
      // msvcp140.dll / vcruntime140_1.dll are imported by neither.
      expect(kHelperAssetNames, <String>[
        kHelperExeName,
        kHelperRuntimeDll,
        kCoreExeName,
      ]);
      expect(kHelperAssetNames, hasLength(3));
      expect(kHelperAssetNames.contains('msvcp140.dll'), isFalse);
      expect(kHelperAssetNames.contains('vcruntime140_1.dll'), isFalse);
    });

    test('the core is part of the closure, not an afterthought', () {
      // The helper refuses to start a core from outside its own directory, so
      // the verified copy has to be deployed there — which means the anchor has
      // to describe it.
      expect(kHelperAssetNames, contains(kCoreExeName));
      expect(kHelperAssetNames.indexOf(kHelperExeName), 0);
    });

    test('a missing trust anchor blocks the install', () async {
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir))
        ..set(protectedExe, _facts(protectedExe));
      final outcome = await _prepare(
        inspector: inspector,
        manifest: const HelperAssetManifest(<String, String>{}),
      );
      expect(outcome.decision.canInstall, isFalse);
      expect(
        outcome.decision.rejection,
        HelperInstallRejection.manifestMissing,
      );
    });

    test('verifying the EXE but not the DLL fails', () async {
      // The classic mistake: the manifest covers only the executable.
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir))
        ..set(protectedExe, _facts(protectedExe));
      final outcome = await _prepare(
        inspector: inspector,
        manifest: HelperAssetManifest.parse(
          'FluxoraHelperService.exe=${_hashOf('aa')}',
        ),
      );
      expect(outcome.decision.canInstall, isFalse);
      expect(
        outcome.decision.rejection,
        HelperInstallRejection.manifestMissing,
      );
    });

    test('a source hash mismatch stops before anything is copied', () async {
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir))
        ..set(protectedExe, _facts(protectedExe));
      var copies = 0;
      final outcome =
          await HelperInstaller(
            inspector: inspector,
            manifest: _manifestFor('aa'),
            hashFile: (file) async => file.path.endsWith('vcruntime140.dll')
                ? _hashOf('bb')
                : _hashOf('aa'),
            copyFile: (from, to) async {
              copies++;
            },
            fileExists: (path) async => true,
          ).prepare(
            sourceDir: '/tmp/source',
            targetDir: protectedDir,
            programFiles: programFiles,
          );
      expect(outcome.decision.rejection, HelperInstallRejection.hashMismatch);
      expect(
        copies,
        0,
        reason: 'nothing may be copied from an unverified source',
      );
    });

    test('a post-copy mismatch is not reported as success', () async {
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir))
        ..set(protectedExe, _facts(protectedExe));
      final outcome =
          await HelperInstaller(
            inspector: inspector,
            manifest: _manifestFor('aa'),
            hashFile: (file) async => file.path.startsWith('/tmp/source')
                ? _hashOf('aa')
                : _hashOf('zz'),
            copyFile: (from, to) async {},
            fileExists: (path) async => true,
          ).prepare(
            sourceDir: '/tmp/source',
            targetDir: protectedDir,
            programFiles: programFiles,
          );
      expect(
        outcome.decision.rejection,
        HelperInstallRejection.postCopyMismatch,
      );
    });

    test('a missing asset is refused', () async {
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir))
        ..set(protectedExe, _facts(protectedExe));
      final outcome =
          await HelperInstaller(
            inspector: inspector,
            manifest: _manifestFor('aa'),
            hashFile: (file) async => _hashOf('aa'),
            copyFile: (from, to) async {},
            // Nothing exists on disk — the source check must be what stops it.
            fileExists: (path) async => false,
          ).prepare(
            sourceDir: '/nonexistent/source/dir',
            targetDir: protectedDir,
            programFiles: programFiles,
          );
      expect(outcome.decision.rejection, HelperInstallRejection.assetMissing);
    });

    test(
      'all three assets must be present before anything is installed',
      () async {
        final inspector = _FakeInspector()
          ..set(protectedDir, _facts(protectedDir));
        final outcome = await _prepare(
          inspector: inspector,
          manifest: _manifestFor('aa'),
        );
        expect(outcome.decision.safe, isTrue);
        expect(outcome.decision.assets, kHelperAssetNames);
        expect(outcome.decision.assets, hasLength(3));
        expect(outcome.decision.assets, contains(kCoreExeName));
      },
    );

    test('a missing core stops the install before any copy', () async {
      // The core is what the helper runs as SYSTEM, so its absence has to stop
      // the deployment — not produce a directory that "looks installed".
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir));
      var copies = 0;
      final outcome =
          await HelperInstaller(
            inspector: inspector,
            manifest: _manifestFor('aa'),
            hashFile: (file) async => _hashOf('aa'),
            copyFile: (from, to) async {
              copies++;
            },
            fileExists: (path) async => !path.endsWith(kCoreExeName),
          ).prepare(
            sourceDir: '/tmp/source',
            targetDir: protectedDir,
            programFiles: programFiles,
          );

      expect(outcome.decision.rejection, HelperInstallRejection.assetMissing);
      expect(outcome.decision.canInstall, isFalse);
      expect(outcome.failClosedAt, contains(kCoreExeName));
      expect(copies, 0, reason: 'nothing may be copied from an incomplete set');
    });

    test('a core whose hash differs from the anchor is refused', () async {
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir));
      var copies = 0;
      final outcome =
          await HelperInstaller(
            inspector: inspector,
            manifest: _manifestFor('aa'),
            hashFile: (file) async => file.path.endsWith(kCoreExeName)
                ? _hashOf('zz')
                : _hashOf('aa'),
            copyFile: (from, to) async {
              copies++;
            },
            fileExists: (path) async => true,
          ).prepare(
            sourceDir: '/tmp/source',
            targetDir: protectedDir,
            programFiles: programFiles,
          );

      expect(outcome.decision.rejection, HelperInstallRejection.hashMismatch);
      expect(outcome.failClosedAt, contains(kCoreExeName));
      expect(copies, 0);
    });

    test('manifest parsing rejects malformed and short hashes', () {
      final manifest = HelperAssetManifest.parse(
        'a.exe=zzz,b.exe=${_hashOf('aa')},=deadbeef,c.exe',
      );
      expect(manifest.hashes.keys, <String>['b.exe']);
      expect(manifest.coversExactly(kHelperAssetNames), isFalse);
    });
  });

  // ---------------------------------------------------------------- group 5
  group('5 — SCM ImagePath parsing', () {
    test('quoted and unquoted forms both match', () {
      expect(ImagePathMatcher.matches(protectedExe, '"$protectedExe"'), isTrue);
      expect(ImagePathMatcher.matches(protectedExe, protectedExe), isTrue);
    });

    test('a trailing argument does not hide the real path', () {
      expect(
        ImagePathMatcher.matches(protectedExe, '"$protectedExe" --service'),
        isTrue,
      );
      expect(
        ImagePathMatcher.matches(protectedExe, '$protectedExe --service'),
        isTrue,
      );
    });

    test(
      'case and separator differences are tolerated, path differences are not',
      () {
        expect(
          ImagePathMatcher.matches(
            protectedExe,
            r'c:\program files\fluxora\service\FLUXORAHELPERSERVICE.EXE',
          ),
          isTrue,
        );
        expect(
          ImagePathMatcher.matches(
            protectedExe,
            r'C:/Program Files/Fluxora/Service/FluxoraHelperService.exe',
          ),
          isTrue,
        );
        expect(
          ImagePathMatcher.matches(
            protectedExe,
            r'C:\Program Files\Fluxora\Service\FluxoraHelperService.exe.backup',
          ),
          isFalse,
        );
        expect(
          ImagePathMatcher.matches(
            protectedExe,
            r'C:\Program Files\Fluxora\Service',
          ),
          isFalse,
        );
      },
    );

    test('the device prefix is stripped', () {
      expect(
        ImagePathMatcher.matches(
          protectedExe,
          r'\??\C:\Program Files\Fluxora\Service\FluxoraHelperService.exe',
        ),
        isTrue,
      );
    });

    test('an unbalanced quote is never guessed at', () {
      expect(ImagePathMatcher.normalise('"$protectedExe'), isNull);
      expect(ImagePathMatcher.matches(protectedExe, '"$protectedExe'), isFalse);
    });

    test('a service still pointing at the build directory does not match', () {
      expect(
        ImagePathMatcher.matches(
          protectedExe,
          r'D:\MyASUS\Documents\ChatGPT\box\fluxora-rc6-branch\build\windows\x64\runner\Release\FluxoraHelperService.exe',
        ),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------- group 6
  group('6 — install and migration decision', () {
    test('nothing installed ⇒ install', () {
      expect(
        HelperMigrationPolicy.decide(
          installed: false,
          imagePath: null,
          protectedExePath: protectedExe,
          programFiles: programFiles,
        ),
        HelperMigrationAction.install,
      );
    });

    test('already at the protected path ⇒ keep, even if running', () {
      expect(
        HelperMigrationPolicy.decide(
          installed: true,
          imagePath: '"$protectedExe"',
          protectedExePath: protectedExe,
          programFiles: programFiles,
        ),
        HelperMigrationAction.keep,
      );
    });

    test('pointing at the build directory ⇒ migrate', () {
      expect(
        HelperMigrationPolicy.decide(
          installed: true,
          imagePath:
              r'"D:\MyASUS\Documents\ChatGPT\box\fluxora-rc6-branch\build\windows\x64\runner\Release\FluxoraHelperService.exe"',
          protectedExePath: protectedExe,
          programFiles: programFiles,
        ),
        HelperMigrationAction.migrate,
      );
    });

    test('an existing unsafe ImagePath is never treated as migrated', () {
      // The service being installed and running says nothing about where it
      // runs from — this is the check that used to be skipped.
      final action = HelperMigrationPolicy.decide(
        installed: true,
        imagePath:
            r'C:\Users\someone\AppData\Local\Temp\FluxoraHelperService.exe',
        protectedExePath: protectedExe,
        programFiles: programFiles,
      );
      expect(action, HelperMigrationAction.migrate);
      expect(action, isNot(HelperMigrationAction.keep));
    });

    test(
      'an unparseable ImagePath is an identity conflict, not a migration',
      () {
        expect(
          HelperMigrationPolicy.decide(
            installed: true,
            imagePath: '"unbalanced',
            protectedExePath: protectedExe,
            programFiles: programFiles,
          ),
          HelperMigrationAction.identityConflict,
        );
      },
    );

    test('a different protected file is an identity conflict', () {
      expect(
        HelperMigrationPolicy.decide(
          installed: true,
          imagePath: r'C:\Program Files\Other\thing.exe',
          protectedExePath: protectedExe,
          programFiles: programFiles,
        ),
        HelperMigrationAction.identityConflict,
      );
    });
  });

  // ---------------------------------------------------------------- group 7
  group('7 — failure, rollback and fail-closed', () {
    test('a copy failure stops the deployment', () async {
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir))
        ..set(protectedExe, _facts(protectedExe));
      final outcome =
          await HelperInstaller(
            inspector: inspector,
            manifest: _manifestFor('aa'),
            hashFile: (file) async => _hashOf('aa'),
            copyFile: (from, to) async =>
                throw const FileSystemException('denied'),
            fileExists: (path) async => true,
          ).prepare(
            sourceDir: '/tmp/source',
            targetDir: protectedDir,
            programFiles: programFiles,
          );
      expect(outcome.decision.canInstall, isFalse);
      expect(outcome.decision.rejection, HelperInstallRejection.copyFailed);
      expect(outcome.failClosedAt, contains('copy:'));
    });

    test('a non-Windows host refuses before touching anything', () async {
      final inspector = _FakeInspector();
      final outcome =
          await HelperInstaller(
            inspector: inspector,
            manifest: _manifestFor('aa'),
          ).prepare(
            sourceDir: '/tmp/source',
            targetDir: protectedDir,
            programFiles: programFiles,
            isWindows: false,
          );
      expect(outcome.decision.rejection, HelperInstallRejection.notWindows);
      expect(outcome.decision.canInstall, isFalse);
    });

    test('an unsafe target path is refused before any inspection', () async {
      final inspector = _FakeInspector();
      final outcome =
          await HelperInstaller(
            inspector: inspector,
            manifest: _manifestFor('aa'),
          ).prepare(
            sourceDir: '/tmp/source',
            targetDir: r'D:\build\Release',
            programFiles: programFiles,
          );
      expect(
        outcome.decision.rejection,
        HelperInstallRejection.pathOutsideProgramFiles,
      );
      // Nothing was inspected, so nothing could have been copied.
      expect(inspector.inspected, isEmpty);
    });

    test('no decision ever reports success without canInstall', () async {
      final inspector = _FakeInspector()
        ..set(protectedDir, _facts(protectedDir, reparse: true));
      final outcome = await _prepare(
        inspector: inspector,
        manifest: _manifestFor('aa'),
      );
      expect(outcome.decision.safe, isFalse);
      expect(outcome.decision.canInstall, isFalse);
      expect(outcome.failClosedAt, isNotNull);
    });

    test('the module never shells out to sc', () async {
      // Structural guarantee: nothing in this module can perform an SCM write,
      // because it has no process runner at all. The only injection points are
      // the inspector, the hasher and the copier.
      final source = await File(
        'lib/common/protected_helper.dart',
      ).readAsString();
      expect(source.contains("'sc'"), isFalse);
      expect(source.contains('Process.run'), isFalse);
      expect(source.contains('Process.start'), isFalse);
    });
  });
}

// -------------------------------------------------------------------- helpers

String _hashOf(String seed) =>
    (seed * 32).substring(0, 64).padRight(64, '0').toLowerCase();

HelperAssetManifest _manifestFor(String seed) {
  final hash = _hashOf(seed);
  return HelperAssetManifest(<String, String>{
    for (final name in kHelperAssetNames) name: hash,
  });
}

PathSecurityFacts _facts(
  String path, {
  bool reparse = false,
  String? finalPath,
  String ownerSid = 'S-1-5-32-544',
  List<AclEntry> extra = const <AclEntry>[],
}) => PathSecurityFacts(
  exists: true,
  isReparsePoint: reparse,
  finalPath: finalPath ?? path,
  ownerSid: ownerSid,
  entries: <AclEntry>[
    const AclEntry(sid: 'S-1-5-18', allow: true, fullControl: true),
    const AclEntry(sid: 'S-1-5-32-544', allow: true, fullControl: true),
    ...extra,
  ],
);

class _FakeInspector implements AclInspector {
  final Map<String, PathSecurityFacts> _byPath = <String, PathSecurityFacts>{};
  final List<String> inspected = <String>[];

  /// When true (the default) any path that was not explicitly configured is
  /// reported as a safe protected object. Tests that need "inspection failed"
  /// semantics switch this off.
  bool defaultSafe = true;

  /// Keys are normalised the same way lookups are, because the installer joins
  /// `targetDir` with [Platform.pathSeparator] — on a POSIX host that produces
  /// `…\Service/FluxoraHelperService.exe` for a Windows-style directory.
  static String _norm(String path) => path.replaceAll('/', r'\').toLowerCase();

  void set(String path, PathSecurityFacts facts) =>
      _byPath[_norm(path)] = facts;

  @override
  Future<PathSecurityFacts> inspect(String path) async {
    inspected.add(path);
    final exact = _byPath[_norm(path)];
    if (exact != null) return exact;
    if (!defaultSafe) return const PathSecurityFacts.unknown();
    // Safe facts whose `finalPath` is the path actually asked about, so the
    // "resolved path must equal the requested path" rule still applies.
    return _facts(path);
  }
}

Future<HelperInstallOutcome> _prepare({
  required AclInspector inspector,
  required HelperAssetManifest manifest,
  Future<bool> Function(String path)? fileExists,
}) =>
    HelperInstaller(
      inspector: inspector,
      manifest: manifest,
      hashFile: (file) async => _hashOf('aa'),
      copyFile: (from, to) async {},
      fileExists: fileExists ?? ((path) async => true),
    ).prepare(
      sourceDir: '/tmp/source',
      targetDir: r'C:\Program Files\Fluxora\Service',
      programFiles: r'C:\Program Files',
    );
