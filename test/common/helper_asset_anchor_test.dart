import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/protected_helper.dart';
import 'package:fluxora/common/system.dart';
import 'package:yaml/yaml.dart';

/// SEC-P0-01 — the build-side trust anchor, the bundle consistency gate, and
/// the order in which the deploy gates run.
///
/// Everything here is pure logic, temp files, or a parsed workflow file. No SCM
/// call, no Program Files write, no elevated process — and nothing that needs
/// Windows FFI, so this file runs on Linux CI.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fluxora_anchor_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// Writes both closure members with distinct content and returns their real
  /// hashes, exactly as the build would measure them.
  Future<Map<String, String>> writeAssets(Directory dir) async {
    final out = <String, String>{};
    for (final name in kHelperAssetNames) {
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      await file.writeAsString('content-of-$name');
      out[name] = await sha256OfFile(file.path);
    }
    return out;
  }

  // ------------------------------------------------------------- build anchor
  group('build anchor', () {
    test('a complete measurement becomes the define value', () async {
      final hashes = await writeAssets(tmp);
      final define = buildHelperAssetDefine(hashes);

      expect(
        define,
        contains('FluxoraHelperService.exe=${hashes[kHelperAssetNames[0]]}'),
      );
      expect(
        define,
        contains('vcruntime140.dll=${hashes[kHelperAssetNames[1]]}'),
      );

      // The app parses it back into exactly the same map.
      final parsed = HelperAssetManifest.parse(define);
      expect(parsed.coversExactly(kHelperAssetNames), isTrue);
      expect(parsed.hashes, hashes);
    });

    test('a missing DLL hash is refused, not silently dropped', () {
      // The classic mistake: anchor the EXE only. A partial anchor would leave
      // vcruntime140.dll unverified — and that is the file that gets loaded into
      // a LocalSystem process.
      expect(
        () => buildHelperAssetDefine(<String, String>{
          kHelperAssetNames[0]: 'a' * 64,
        }),
        throwsArgumentError,
      );
    });

    test('a malformed hash is refused', () {
      for (final bad in <String>['', 'zz', 'A' * 63, 'g' * 64, 'a' * 65]) {
        expect(
          () => buildHelperAssetDefine(<String, String>{
            kHelperAssetNames[0]: 'a' * 64,
            kHelperAssetNames[1]: bad,
            kHelperAssetNames[2]: 'c' * 64,
          }),
          throwsArgumentError,
          reason: 'hash "$bad" must not be accepted',
        );
      }
    });

    test('an unexpected extra asset is refused', () {
      expect(
        () => buildHelperAssetDefine(<String, String>{
          kHelperAssetNames[0]: 'a' * 64,
          kHelperAssetNames[1]: 'b' * 64,
          kHelperAssetNames[2]: 'c' * 64,
          'msvcp140.dll': 'd' * 64,
        }),
        throwsArgumentError,
      );
    });

    test('uppercase hex is normalised, not rejected', () {
      final define = buildHelperAssetDefine(<String, String>{
        for (final name in kHelperAssetNames) name: 'A' * 64,
      });
      expect(define, contains('=${'a' * 64}'));
    });

    test('no compile-time anchor exists in a plain test build', () {
      // Documents the fail-closed default: without the CI define, an install
      // cannot proceed. `prepare()` then returns manifestMissing.
      expect(HelperAssetManifest.fromEnvironment().isEmpty, isTrue);
    });
  });

  // -------------------------------------------------- bundle consistency gate
  group('bundle consistency', () {
    test('a bundle that matches the anchor passes', () async {
      final define = buildHelperAssetDefine(await writeAssets(tmp));
      expect(
        await checkHelperAssetsAgainstManifest(
          dir: tmp.path,
          manifestText: define,
        ),
        isNull,
      );
    });

    test('a rewritten helper fails with the asset named', () async {
      final define = buildHelperAssetDefine(await writeAssets(tmp));
      await File(
        '${tmp.path}${Platform.pathSeparator}${kHelperAssetNames.first}',
      ).writeAsString('tampered');

      final problem = await checkHelperAssetsAgainstManifest(
        dir: tmp.path,
        manifestText: define,
      );
      expect(problem, isNotNull);
      expect(problem, contains(kHelperAssetNames.first));
      expect(problem, contains('mismatch'));
    });

    test('a rewritten DLL fails', () async {
      final define = buildHelperAssetDefine(await writeAssets(tmp));
      await File(
        '${tmp.path}${Platform.pathSeparator}${kHelperAssetNames[1]}',
      ).writeAsString('tampered');

      final problem = await checkHelperAssetsAgainstManifest(
        dir: tmp.path,
        manifestText: define,
      );
      expect(problem, contains(kHelperAssetNames[1]));
    });

    test('a missing asset fails instead of throwing', () async {
      final define = buildHelperAssetDefine(await writeAssets(tmp));
      await File(
        '${tmp.path}${Platform.pathSeparator}${kHelperAssetNames[1]}',
      ).delete();

      final problem = await checkHelperAssetsAgainstManifest(
        dir: tmp.path,
        manifestText: define,
      );
      expect(problem, isNotNull);
      expect(problem, contains('missing'));
    });

    test('an empty or partial anchor fails', () async {
      for (final anchor in <String>[
        '',
        'FluxoraHelperService.exe=${'a' * 64}',
        'garbage',
      ]) {
        expect(
          await checkHelperAssetsAgainstManifest(
            dir: tmp.path,
            manifestText: anchor,
          ),
          isNotNull,
          reason: 'anchor "$anchor" must not verify a bundle',
        );
      }
    });
  });

  // ------------------------------------------------------ deploy gate ordering
  group('deploy gate ordering', () {
    test('a failed deploy never reaches the SCM stage', () async {
      var configureCalls = 0;
      var healthyCalls = 0;

      final result = await Windows.deployThenConfigure(
        deploy: () async => false,
        configure: () async {
          configureCalls++;
          return true;
        },
        waitHealthy: () async {
          healthyCalls++;
          return true;
        },
      );

      expect(result, isFalse);
      expect(
        configureCalls,
        0,
        reason: 'no SCM write without a verified deploy',
      );
      expect(healthyCalls, 0);
    });

    test('a failed configure never reports a healthy helper', () async {
      var healthyCalls = 0;
      final result = await Windows.deployThenConfigure(
        deploy: () async => true,
        configure: () async => false,
        waitHealthy: () async {
          healthyCalls++;
          return true;
        },
      );

      expect(result, isFalse);
      expect(healthyCalls, 0);
    });

    test('deploy → configure → health, in that order', () async {
      final order = <String>[];
      final result = await Windows.deployThenConfigure(
        deploy: () async {
          order.add('deploy');
          return true;
        },
        configure: () async {
          order.add('configure');
          return true;
        },
        waitHealthy: () async {
          order.add('healthy');
          return true;
        },
      );

      expect(result, isTrue);
      expect(order, <String>['deploy', 'configure', 'healthy']);
    });
  });

  // ------------------------------------------------------- workflow structure
  group('build workflow', () {
    late YamlMap workflow;

    setUpAll(() {
      workflow =
          loadYaml(File('.github/workflows/build.yaml').readAsStringSync())
              as YamlMap;
    });

    /// Every step of every job, flattened, keeping declaration order.
    List<Map<dynamic, dynamic>> allSteps() {
      final out = <Map<dynamic, dynamic>>[];
      final jobs = workflow['jobs'] as YamlMap;
      for (final job in jobs.values) {
        final steps = (job as YamlMap)['steps'];
        if (steps is YamlList) {
          for (final step in steps) {
            out.add((step as YamlMap).cast<dynamic, dynamic>());
          }
        }
      }
      return out;
    }

    int indexOfStep(String name) =>
        allSteps().indexWhere((s) => s['name'] == name);

    test('the anchor is computed after signing and before the app build', () {
      final compute = indexOfStep('Compute helper asset anchor (Windows)');
      final build = indexOfStep('Build Fluxora (Windows)');
      final sign = indexOfStep('Sign HelperService (Windows)');

      expect(compute, greaterThanOrEqualTo(0), reason: 'anchor step missing');
      expect(build, greaterThanOrEqualTo(0));
      expect(sign, greaterThanOrEqualTo(0));
      // Signing rewrites the binary, so hashing before it would anchor the
      // wrong bytes.
      expect(
        compute,
        greaterThan(sign),
        reason: 'the anchor must be measured after the helper is signed',
      );
      expect(
        compute,
        lessThan(build),
        reason: 'the anchor has to exist before it is compiled in',
      );
    });

    test('the anchor is exported and compiled into the app', () {
      final steps = allSteps();
      final compute =
          steps[indexOfStep('Compute helper asset anchor (Windows)')];
      final build = steps[indexOfStep('Build Fluxora (Windows)')];

      expect('${compute['run']}', contains('GITHUB_ENV'));
      expect('${compute['run']}', contains('helper-manifest'));
      expect('${build['run']}', contains('--dart-define=HELPER_ASSET_SHA256='));
      // Building without the anchor must fail rather than ship an app that can
      // never install its helper.
      expect('${build['run']}', contains('refusing to build'));
    });

    test('the packaged bundle is checked against the anchor', () {
      final verify = indexOfStep('Verify helper asset consistency (Windows)');
      expect(verify, greaterThanOrEqualTo(0), reason: 'verify step missing');
      expect(
        verify,
        greaterThan(indexOfStep('Build Fluxora (Windows)')),
        reason: 'consistency can only be checked once the bundle exists',
      );
      expect('${allSteps()[verify]['run']}', contains('--verify-dir'));
      expect('${allSteps()[verify]['run']}', contains('exit 1'));
    });

    test('the vcruntime source is the resolved package, not a path guess', () {
      final compute =
          allSteps()[indexOfStep('Compute helper asset anchor (Windows)')];
      final run = '${compute['run']}';
      expect(run, contains('package_config.json'));
      expect(run, contains('vclibs'));
      expect(run, contains('vcruntime140.dll'));
    });
  });
}
