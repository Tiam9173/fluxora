import 'package:fluxora/common/identity.dart';
import 'package:flutter_test/flutter_test.dart';

/// B1 — helper identity derivation.
///
/// Pure functions only: nothing here opens a named pipe, reads the auth key,
/// touches the registry or talks to the SCM. The live getters resolve through
/// the test VM's own build mode, so every assertion that has to be independent
/// of that goes through [specFor] / [resolveHelperIdentity] instead.
void main() {
  group('T-I1 — release identity', () {
    test('four fields are exact', () {
      final spec = specFor(HelperIdentityKind.release);

      expect(spec.serviceName, 'FluxoraHelperService');
      expect(spec.pipeName, r'\\.\pipe\Fluxora.Helper');
      expect(spec.helperExeName, 'FluxoraHelperService.exe');
      expect(spec.dataDirName, 'Fluxora');
    });

    test('pipe name matches the historical literal exactly', () {
      // The installed service's Environment already contains this string
      // (`system.dart` → `reg add ... HELPER_PIPE_NAME=`). One changed
      // character and every existing install loses its helper.
      expect(
        specFor(HelperIdentityKind.release).pipeName,
        '\\\\.\\pipe\\Fluxora.Helper',
      );
    });
  });

  group('T-I2 — host test identity', () {
    test('four fields are exact', () {
      final spec = specFor(HelperIdentityKind.hostTest);

      expect(spec.serviceName, 'FluxoraHostTestHelperService');
      expect(spec.pipeName, r'\\.\pipe\Fluxora.HostTest.Helper');
      expect(spec.helperExeName, 'FluxoraHostTestHelperService.exe');
      expect(spec.dataDirName, 'FluxoraHostTest');
    });

    test('all four values are isolated from release', () {
      final host = specFor(HelperIdentityKind.hostTest);
      final release = specFor(HelperIdentityKind.release);

      expect(host.serviceName, isNot(release.serviceName));
      expect(host.pipeName, isNot(release.pipeName));
      expect(host.helperExeName, isNot(release.helperExeName));
      expect(host.dataDirName, isNot(release.dataDirName));
    });

    test('service name does not contain "Dev"', () {
      // `services/helper/src/ops.rs` → `env_contains_dev("HELPER_SERVICE_NAME")`
      // makes a dev helper exit as soon as its core exits. A host test wants the
      // release lifecycle, so the name must not carry that marker.
      expect(
        specFor(HelperIdentityKind.hostTest).serviceName.toLowerCase(),
        isNot(contains('dev')),
      );
    });
  });

  group('T-I3 — dev identity', () {
    test('keeps the historical service name, data dir and shared pipe', () {
      final dev = specFor(HelperIdentityKind.dev);

      expect(dev.serviceName, 'FluxoraDevHelperService');
      expect(dev.dataDirName, 'Fluxora');
      // Known defect, asserted on purpose: Dev and Release share one pipe.
      // Fixing it (R-BLOCK-04) must make this line fail so the change is
      // deliberate rather than accidental.
      expect(dev.pipeName, specFor(HelperIdentityKind.release).pipeName);
    });
  });

  group('T-I4 — identity parsing boundaries', () {
    test('empty token means "not specified"', () {
      expect(parseIdentityToken(''), isNull);
      expect(parseIdentityToken('   '), isNull);
      expect(parseIdentityToken('--'), isNull);
    });

    test('recognised tokens, including separator and case variants', () {
      expect(parseIdentityToken('dev'), HelperIdentityKind.dev);
      expect(parseIdentityToken('HOSTTEST'), HelperIdentityKind.hostTest);
      expect(parseIdentityToken('host-test'), HelperIdentityKind.hostTest);
      expect(parseIdentityToken('host_test'), HelperIdentityKind.hostTest);
      expect(parseIdentityToken('release'), HelperIdentityKind.release);
      expect(parseIdentityToken('prod'), HelperIdentityKind.release);
    });

    test('unknown token throws instead of falling back to release', () {
      // The whole point of the change: a typo must not silently select the
      // production service.
      expect(() => parseIdentityToken('hosttset'), throwsArgumentError);
      expect(() => parseIdentityToken('devv'), throwsArgumentError);
    });

    test('host test wins over the dev-binary fallback', () {
      expect(
        resolveHelperIdentity(raw: 'hosttest', usesDevBinaries: true),
        HelperIdentityKind.hostTest,
      );
      expect(
        resolveHelperIdentity(raw: 'HOST-TEST', usesDevBinaries: true),
        HelperIdentityKind.hostTest,
      );
    });

    test('an explicit dev token works without usesDevBinaries', () {
      expect(
        resolveHelperIdentity(raw: 'dev', usesDevBinaries: false),
        HelperIdentityKind.dev,
      );
    });

    test('no token keeps the historical usesDevBinaries rule', () {
      // Dev compatibility regression: a debug build with no new flag set must
      // still resolve to Dev, exactly as before this change.
      expect(
        resolveHelperIdentity(raw: '', usesDevBinaries: true),
        HelperIdentityKind.dev,
      );
      expect(
        resolveHelperIdentity(raw: '', usesDevBinaries: false),
        HelperIdentityKind.release,
      );
    });
  });

  group('T-R1 — release compatibility regression', () {
    test('the live data directory is still Fluxora', () {
      // Guards `test/services/windows_runtime_validation_test.dart:118` and, more
      // importantly, the real `%APPDATA%\Fluxora` profile.
      expect(AppIdentity.dataDirName, 'Fluxora');
      expect(specFor(HelperIdentityKind.release).dataDirName, 'Fluxora');
      expect(specFor(HelperIdentityKind.dev).dataDirName, 'Fluxora');
    });

    test('release names still derive from compactName', () {
      final spec = specFor(HelperIdentityKind.release);
      expect(spec.serviceName, '${AppIdentity.compactName}HelperService');
      expect(spec.helperExeName, '${AppIdentity.compactName}HelperService.exe');
      expect(
        spec.pipeName,
        '\\\\.\\pipe\\${AppIdentity.compactName}.Helper',
      );
    });

    test('the live helper service name follows the live kind', () {
      // Whatever the test VM's build mode is, the live getters must agree with
      // the pure resolver — otherwise production and tests disagree about which
      // service is being addressed.
      final live = WindowsHelperIdentity.kind;
      expect(WindowsHelperIdentity.serviceName, specFor(live).serviceName);
      expect(WindowsHelperIdentity.pipeName, specFor(live).pipeName);
      expect(AppIdentity.dataDirName, specFor(live).dataDirName);
    });

    test('core executable naming is untouched by this change', () {
      // Deliberately still driven by `usesDevBinaries`, not by the helper
      // identity: a host test reuses the release core so the helper's baked
      // TOKEN still matches it.
      final expected = AppIdentity.usesDevBinaries
          ? 'FluxoraDevCore'
          : 'FluxoraCore';
      expect(AppIdentity.coreExecutableName, expected);
    });
  });
}
