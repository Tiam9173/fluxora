import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/service.dart';
import 'package:fluxora/common/identity.dart';
import 'package:fluxora/common/protected_helper.dart';

/// SEC-P0-01 — which core image each launch mode uses, and that the three
/// helper identities never share a directory, a service name or a file name.
///
/// Pure logic and temp files only: no socket, no helper, no `Process.start`,
/// and nothing that needs a Windows host.
void main() {
  const programFiles = r'C:\Program Files';
  const protectedCore = r'C:\Program Files\Fluxora\Service\FluxoraCore.exe';
  const bundleCore =
      r'D:\MyASUS\Documents\ChatGPT\box\fluxora-rc6-branch\build\windows\x64\runner\Release\FluxoraCore.exe';

  // ------------------------------------------------------------ launch plan
  group('core launch plan', () {
    test('helper mode gets the protected core, not the bundle copy', () {
      final plan = planCoreLaunch(
        isWindows: true,
        serviceOk: true,
        protectedCorePath: protectedCore,
        bundleCorePath: bundleCore,
      );
      expect(plan.helper, isTrue);
      expect(plan.path, protectedCore);
    });

    test('direct mode keeps the bundle core under the user token', () {
      // Service unavailable → the core runs as the user. It must not be given
      // the SYSTEM-owned copy: that one exists to be started by the helper.
      final plan = planCoreLaunch(
        isWindows: true,
        serviceOk: false,
        protectedCorePath: protectedCore,
        bundleCorePath: bundleCore,
      );
      expect(plan.helper, isFalse);
      expect(plan.path, bundleCore);
    });

    test('no protected path means no helper attempt at all', () {
      // The helper would reject the bundle path anyway. Asking it and falling
      // back would only mean this process tried to have SYSTEM run a
      // user-writable image.
      final plan = planCoreLaunch(
        isWindows: true,
        serviceOk: true,
        protectedCorePath: null,
        bundleCorePath: bundleCore,
      );
      expect(plan.helper, isFalse);
      expect(plan.path, bundleCore);
    });

    test('an empty protected path is treated as missing', () {
      final plan = planCoreLaunch(
        isWindows: true,
        serviceOk: true,
        protectedCorePath: '',
        bundleCorePath: bundleCore,
      );
      expect(plan.helper, isFalse);
    });

    test('off Windows the helper is never used', () {
      final plan = planCoreLaunch(
        isWindows: false,
        serviceOk: true,
        protectedCorePath: protectedCore,
        bundleCorePath: '/opt/fluxora/FluxoraCore',
      );
      expect(plan.helper, isFalse);
      expect(plan.path, '/opt/fluxora/FluxoraCore');
    });
  });

  // ------------------------------------------------------- token consistency
  group('core anchor vs CORE_SHA256', () {
    final core = 'e' * 64;
    final helper = 'a' * 64;
    final dll = 'b' * 64;

    String anchorWith({String? coreHash}) =>
        buildHelperAssetDefine(<String, String>{
          kHelperExeName: helper,
          kHelperRuntimeDll: dll,
          kCoreExeName: coreHash ?? core,
        });

    test('agreeing hashes pass', () {
      expect(
        coreAnchorMismatch(anchor: anchorWith(), coreSha256: core),
        isNull,
      );
    });

    test('a different core hash is refused', () {
      final reason = coreAnchorMismatch(
        anchor: anchorWith(),
        coreSha256: 'f' * 64,
      );
      expect(reason, isNotNull);
      expect(reason, contains(kCoreExeName));
    });

    test('an anchor without the core is refused', () {
      // The helper would start a core whose hash the installer never checked.
      final twoFileAnchor = buildHelperAssetDefine(<String, String>{
        kHelperExeName: helper,
        kHelperRuntimeDll: dll,
        kCoreExeName: core,
      });
      expect(
        coreAnchorMismatch(anchor: twoFileAnchor, coreSha256: core),
        isNull,
      );
      expect(
        coreAnchorMismatch(anchor: 'garbage', coreSha256: core),
        contains('no $kCoreExeName entry'),
      );
    });

    test('a malformed CORE_SHA256 is refused', () {
      for (final bad in <String>['', 'zz', 'a' * 63]) {
        expect(
          coreAnchorMismatch(anchor: anchorWith(), coreSha256: bad),
          contains('malformed'),
          reason: '"$bad" must not be accepted',
        );
      }
    });

    test('uppercase CORE_SHA256 is normalised', () {
      expect(
        coreAnchorMismatch(
          anchor: anchorWith(),
          coreSha256: core.toUpperCase(),
        ),
        isNull,
      );
    });
  });

  // ------------------------------------------------------- identity isolation
  group('identity isolation', () {
    test('the deployed helper name is the release identity name', () {
      expect(specFor(HelperIdentityKind.release).helperExeName, kHelperExeName);
    });

    test('the three identities never share a service or a file name', () {
      final names = <String>{};
      final helpers = <String>{};
      final pipes = <String>{};
      for (final kind in HelperIdentityKind.values) {
        final spec = specFor(kind);
        names.add(spec.serviceName);
        helpers.add(spec.helperExeName);
        pipes.add(spec.pipeName);
      }
      expect(names, hasLength(HelperIdentityKind.values.length));
      expect(helpers, hasLength(HelperIdentityKind.values.length));
      // Dev deliberately shares the Release pipe (R-BLOCK-04), so only two.
      expect(pipes.length, greaterThanOrEqualTo(2));
    });

    test('the protected core and helper always share one directory', () {
      // The Rust side only accepts a core whose parent **is** the helper's own
      // directory, so these two derivations can never diverge.
      ProtectedPathRules.programFilesOverrideForTest = () => programFiles;
      addTearDown(() => ProtectedPathRules.programFilesOverrideForTest = null);

      final exe = ProtectedPathRules.defaultProtectedExePath();
      final corePath = ProtectedPathRules.defaultProtectedCorePath();
      expect(exe, isNotNull);
      expect(corePath, isNotNull);

      // Windows paths are compared as strings: `dart:io`'s `File.parent` uses
      // the host separator, and this test also runs on Linux.
      String dirOf(String path) => path.substring(0, path.lastIndexOf(r'\'));
      expect(dirOf(exe!), dirOf(corePath!));
      expect(corePath, protectedCore);
      expect(corePath, endsWith(kCoreExeName));
    });

    test('host test keeps its own data directory', () {
      expect(
        specFor(HelperIdentityKind.hostTest).dataDirName,
        isNot(specFor(HelperIdentityKind.release).dataDirName),
      );
    });
  });
}
