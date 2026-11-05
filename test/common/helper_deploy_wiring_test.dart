import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/system.dart';

/// SEC-P0-01 — the deploy step wired into the first-install path.
///
/// These drive the real `Windows.registerService()` / `_deployHelperAssets()`.
/// Every system touch is replaced:
///   · `sc`                 → [Windows.scRunnerForTest]
///   · helper IPC           → [Windows.helperPingOverrideForTest]
///   · elevated copy + SCM  → [Windows.deployHelperAssetsOverrideForTest] /
///                            [Windows.configureHelperServiceOverrideForTest]
///
/// The one case that deliberately uses the **real** deploy step is "no anchor",
/// because the whole point is that it refuses before anything external happens:
/// no `runas`, no `sc create`.
void main() {
  // Windows-only: `Windows()` loads shell32.dll through FFI, which cannot be
  // resolved off Windows. Same guard as the other helper suites — nothing is
  // relaxed, the file simply does not apply elsewhere.
  if (!Platform.isWindows) {
    test(
      'Windows-only suite',
      () {},
      skip: 'requires Windows FFI (shell32.dll) and the SCM helper service',
    );
    return;
  }

  TestWidgetsFlutterBinding.ensureInitialized();

  ProcessResult sc(int exitCode, String stdout, [String stderr = '']) =>
      ProcessResult(0, exitCode, stdout, stderr);

  late List<List<String>> scCalls;

  setUp(() {
    scCalls = <List<String>>[];
    Windows.scRunnerForTest = null;
    Windows.helperPingOverrideForTest = null;
    Windows.configureHelperServiceOverrideForTest = null;
    Windows.deployHelperAssetsOverrideForTest = null;
    Windows.helperIdentityPathOverrideForTest = null;
    Windows.helperProtectedDirOverrideForTest = null;
    Windows.helperProtectedPathOverrideForTest = null;
    Windows.skipAuthKeyForTest = true;
    Windows.elevatedHelperCallCountForTest = 0;
  });

  tearDown(() {
    Windows.scRunnerForTest = null;
    Windows.helperPingOverrideForTest = null;
    Windows.configureHelperServiceOverrideForTest = null;
    Windows.deployHelperAssetsOverrideForTest = null;
    Windows.helperIdentityPathOverrideForTest = null;
    Windows.helperProtectedDirOverrideForTest = null;
    Windows.helperProtectedPathOverrideForTest = null;
    Windows.skipAuthKeyForTest = false;
    Windows.elevatedHelperCallCountForTest = 0;
  });

  void fakeSc(ProcessResult Function(List<String> args) handler) {
    Windows.scRunnerForTest = (args) async {
      scCalls.add(args);
      return handler(args);
    };
  }

  List<String> scVerbs() =>
      scCalls.where((c) => c.isNotEmpty).map((c) => c.first).toList();

  test(
    'without a build anchor nothing is deployed and nothing is created',
    () async {
      // `sc query` reports 1060 = no such service, so this is the first-install
      // branch — the only one that could ever write to the SCM.
      fakeSc(
        (args) => args.first == 'query'
            ? sc(
                1060,
                '',
                'The specified service does not exist as an installed service.',
              )
            : sc(0, ''),
      );

      var configureCalls = 0;
      Windows.configureHelperServiceOverrideForTest = () async {
        configureCalls++;
        return true;
      };

      // No override: the real `_deployHelperAssets()` runs. In a test build there
      // is no `--dart-define=HELPER_ASSET_SHA256`, so it must refuse.
      final ok = await Windows().registerService();

      expect(ok, isFalse);
      expect(
        configureCalls,
        0,
        reason: 'SCM must not run without a verified deploy',
      );
      expect(
        Windows.elevatedHelperCallCountForTest,
        0,
        reason: 'no UAC before the anchor is proven',
      );
      expect(scVerbs(), isNot(contains('create')));
      expect(scVerbs(), isNot(contains('delete')));
      expect(scVerbs(), isNot(contains('start')));
    },
  );

  test('a failed deploy never reaches the SCM stage', () async {
    fakeSc((args) => args.first == 'query' ? sc(1060, '', '1060') : sc(0, ''));

    Windows.deployHelperAssetsOverrideForTest = () async => false;
    var configureCalls = 0;
    Windows.configureHelperServiceOverrideForTest = () async {
      configureCalls++;
      return true;
    };

    expect(await Windows().registerService(), isFalse);
    expect(configureCalls, 0);
    expect(scVerbs(), isNot(contains('create')));
  });

  test(
    'a verified deploy reaches configure exactly once, then health',
    () async {
      fakeSc(
        (args) => args.first == 'query' ? sc(1060, '', '1060') : sc(0, ''),
      );

      var deployCalls = 0;
      var configureCalls = 0;
      var pingCalls = 0;

      Windows.deployHelperAssetsOverrideForTest = () async {
        deployCalls++;
        return true;
      };
      Windows.configureHelperServiceOverrideForTest = () async {
        configureCalls++;
        return true;
      };
      Windows.helperPingOverrideForTest = () async {
        pingCalls++;
        return true;
      };

      expect(await Windows().registerService(), isTrue);
      expect(deployCalls, 1);
      expect(configureCalls, 1);
      expect(pingCalls, greaterThanOrEqualTo(1));
    },
  );

  test('a service pointing at the build directory is never started', () async {
    // Installed, stopped, but its ImagePath is the writable build folder — the
    // exact configuration SEC-P0-01 exists to stop using.
    fakeSc((args) {
      if (args.first == 'query') return sc(0, 'STATE : 1  STOPPED');
      if (args.first == 'qc') {
        return sc(
          0,
          'BINARY_PATH_NAME   : '
          r'"D:\build\Release\FluxoraHelperService.exe"',
        );
      }
      return sc(0, '');
    });

    Windows.helperIdentityPathOverrideForTest =
        r'C:\Program Files\Fluxora\Service\FluxoraHelperService.exe';

    var deployCalls = 0;
    var configureCalls = 0;
    Windows.deployHelperAssetsOverrideForTest = () async {
      deployCalls++;
      return true;
    };
    Windows.configureHelperServiceOverrideForTest = () async {
      configureCalls++;
      return true;
    };

    expect(await Windows().registerService(), isFalse);
    expect(deployCalls, 0, reason: 'an identity conflict is not a reinstall');
    expect(configureCalls, 0);
    expect(scVerbs(), isNot(contains('start')));
    expect(scVerbs(), isNot(contains('delete')));
  });
}
