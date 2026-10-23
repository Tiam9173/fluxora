// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/models.dart';

import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/services/atomic_config_storage.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_support_package_service.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeAndroidPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakeAndroidPathProviderPlatform(this.tempDir);

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;

  @override
  Future<String?> getApplicationSupportPath() async => tempDir.path;

  @override
  Future<String?> getLibraryPath() async => tempDir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;

  @override
  Future<String?> getExternalStoragePath() async => tempDir.path;

  @override
  Future<List<String>?> getExternalCachePaths() async => [tempDir.path];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [tempDir.path];

  @override
  Future<String?> getDownloadsPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory androidSandboxDir;

  setUpAll(() async {
    androidSandboxDir = await Directory.systemTemp.createTemp(
      'android_runtime_validation_',
    );
    PathProviderPlatform.instance = FakeAndroidPathProviderPlatform(
      androidSandboxDir,
    );
    chainProbeService.customDelayTesterOverride = (proxy, url) async {
      await Future.delayed(const Duration(milliseconds: 10));
      return 120;
    };
    // This suite drives `updateConfig` / `setHops`, which reload the running
    // core. The real reload path reaches `AppController.updateGroups` →
    // `clashCore` → `ClashService`, which tries to spawn the desktop core
    // binary (`FluxoraDevCore.exe`) — absent in a unit-test environment, so the
    // reload would throw a ProcessException. The core reload is irrelevant to
    // what this suite validates, so it is stubbed out for the whole file.
    ChainProxyManager.coreConfigReloadOverride = () async {};
  });

  tearDownAll(() async {
    chainProbeService.customDelayTesterOverride = null;
    ChainProxyManager.coreConfigReloadOverride = null;
    if (await androidSandboxDir.exists()) {
      await androidSandboxDir.delete(recursive: true);
    }
  });

  group('Phase 5.2-A — Android Runtime Validation Suite', () {
    // ══════════════════════════════════════════════════════════════════════════
    // 1. Android Manifest, Permissions, Components & Build Config Validation
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '1. AndroidManifest.xml: Verify essential permissions & services for Chain Proxy',
      () async {
        final manifestFile = File('android/app/src/main/AndroidManifest.xml');
        expect(
          await manifestFile.exists(),
          isTrue,
          reason: 'AndroidManifest.xml must exist',
        );

        final content = await manifestFile.readAsString();

        // Required Android permissions
        expect(content, contains('android.permission.INTERNET'));
        expect(content, contains('android.permission.FOREGROUND_SERVICE'));
        expect(
          content,
          contains('android.permission.FOREGROUND_SERVICE_SPECIAL_USE'),
        );
        expect(content, contains('android.permission.POST_NOTIFICATIONS'));
        expect(content, contains('android.permission.ACCESS_NETWORK_STATE'));
        expect(
          content,
          contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
        );

        // Core Services & Receivers
        expect(content, contains('.services.FluxoraVpnService'));
        expect(content, contains('.services.FluxoraService'));
        expect(content, contains('.services.FluxoraTileService'));
        expect(content, contains('.FilesProvider'));
        expect(content, contains('.receivers.BootReceiver'));
      },
    );

    test(
      '2. Android build.gradle.kts: Verify SDK versions, packaging and signing security',
      () async {
        final buildGradle = File('android/app/build.gradle.kts');
        expect(await buildGradle.exists(), isTrue);

        final content = await buildGradle.readAsString();

        // SDK versions & compatibility
        expect(content, contains('compileSdk = 36'));
        expect(content, contains('minSdk = 26'));
        expect(content, contains('targetSdk = 36'));
        expect(content, contains('useLegacyPackaging = true'));
        expect(content, contains('JavaVersion.VERSION_17'));

        // Security requirement: release signing guard must be enforced
        expect(content, contains('Android Release Signing Error'));
        expect(
          content,
          contains('Fallback to debug signing is strictly prohibited'),
        );
      },
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 2. Chain Proxy Lifecycle on Android (App Launch, Cold Start, Idempotence)
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '3. App Launch & Cold Start: Init loads config, attaches listeners once without re-entrancy',
      () async {
        final manager = ChainProxyManager();
        await manager.init();
        expect(manager.isInitialized, isTrue);

        await Future.wait([manager.init(), manager.init(), manager.init()]);
        expect(manager.isInitialized, isTrue);

        int notifyCount = 0;
        void listener() {
          notifyCount++;
        }

        manager.addListener(listener);

        chainTelemetryService.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeStarted,
            role: 'AndroidInitTest',
            message: 'single_event',
          ),
        );

        expect(
          notifyCount,
          1,
          reason: 'Named listener ensures no duplicate notifications',
        );
        manager.removeListener(listener);
      },
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 3. Android Background & Lifecycle State Switch
    // ══════════════════════════════════════════════════════════════════════════

    // ══════════════════════════════════════════════════════════════════════════
    // 4. Android Network State Changes (WiFi -> Mobile -> WiFi, Online/Offline)
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '5. Network State Change Case A: WiFi to Cellular handover simulation',
      () async {
        final manager = ChainProxyManager();
        await manager.updateConfig(
          (c) => c.copyWith(
            enable: true,
            hop1Node: 'node_wifi_1',
            hop2Node: 'node_wifi_2',
          ),
          reloadCore: false,
        );

        // First probe on WiFi succeeds
        final reportWiFi = await manager.probeCurrentChain();
        expect(reportWiFi.isOverallHealthy, isTrue);

        // Network handover simulation: Temporary transient error on mobile data
        chainProbeService.customDelayTesterOverride = (proxy, url) async {
          return null; // Interface switched, packets dropped
        };

        final reportHandover = await manager.probeCurrentChain(
          retryPolicy: const ChainRetryPolicy(
            maxAttempts: 2,
            baseDelay: Duration(milliseconds: 10),
          ),
        );
        expect(reportHandover.isOverallHealthy, isFalse);

        // Restored connectivity on mobile data
        chainProbeService.customDelayTesterOverride = (proxy, url) async {
          return 95;
        };

        final reportRestored = await manager.probeCurrentChain();
        expect(reportRestored.isOverallHealthy, isTrue);
      },
    );


    // ══════════════════════════════════════════════════════════════════════════
    // 5. Chain Proxy Multi-Hop Test (2-Hop and 3-Hop on Android)
    // ══════════════════════════════════════════════════════════════════════════


    // ══════════════════════════════════════════════════════════════════════════
    // 6. Flap Dampening Android Stress Test
    // ══════════════════════════════════════════════════════════════════════════

    // ══════════════════════════════════════════════════════════════════════════
    // 7. Telemetry Memory Bounds Validation (10,000 events stress test)
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '10. Telemetry Memory Validation: 10,000 events enforce strict bounds (maxEvents=200)',
      () {
        final telemetry = ChainTelemetryService();
        telemetry.clear();

        for (int i = 0; i < 10000; i++) {
          telemetry.record(
            ChainTelemetryEvent(
              type: (i % 2 == 0)
                  ? ChainTelemetryEventType.probeStarted
                  : ChainTelemetryEventType.probeCompleted,
              role: 'StressNode_${i % 5}',
              message: 'Android stress event iteration $i',
            ),
          );
        }

        final snapshot = telemetry.getSnapshot();
        expect(
          snapshot.recentEvents.length,
          equals(ChainTelemetryService.maxEvents),
        );
        expect(snapshot.totalEvents, equals(10000));

        // Clean up
        telemetry.clear();
        expect(telemetry.getSnapshot().totalEvents, 0);
        expect(telemetry.getSnapshot().recentEvents, isEmpty);
      },
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 8. Diagnostic Export Android Validation & Privacy Redaction
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '11. Diagnostic Export: Generates ZIP package with sensitive data redacted',
      () async {
        final manager = ChainProxyManager();

        // Configure a landing proxy with credentials
        await manager.addLandingProxies([
          const LandingProxy(
            id: 'test_residential_01',
            name: 'US-Residential-BrightData',
            server: '198.51.100.10',
            port: 1080,
            protocol: ChainProxyProtocol.socks5,
            username: 'customer-zone123-session-abcdef',
            password: 'super_secret_password_123',
            dialerProxy: 'airport_hop1',
          ),
        ]);

        final pkg = await chainSupportPackageService.createPackage(manager);
        final zipFile = await chainSupportPackageService.exportPackage(pkg);

        expect(await zipFile.exists(), isTrue);
        expect(zipFile.path, endsWith('.zip'));

        // Inspect ZIP contents
        final bytes = await zipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        final fileNames = archive.map((f) => f.name).toSet();
        expect(fileNames, contains('summary.md'));
        expect(fileNames, contains('telemetry.json'));
        expect(fileNames, contains('intelligence.json'));
        expect(fileNames, contains('insight.json'));
        expect(fileNames, contains('decision.json'));

        // Check for sensitive password redaction across all JSON files
        for (final file in archive) {
          if (file.name.endsWith('.json') || file.name.endsWith('.md')) {
            final contentStr = utf8.decode(file.content as List<int>);
            expect(
              contentStr,
              isNot(contains('super_secret_password_123')),
              reason: 'File ${file.name} must NOT leak raw proxy passwords',
            );
          }
        }

        // Cleanup
        await zipFile.delete();
        expect(await zipFile.exists(), isFalse);
      },
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 9. Atomic Config Persistence on Android Storage
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '12. Atomic Config Persistence: Normal save/load, .bak recovery, and orphan .tmp resolution',
      () async {
        final configFilePath = p.join(
          androidSandboxDir.path,
          'chain_proxies_test.json',
        );
        final storage = AtomicConfigStorage(configFilePath);

        // 1. Normal save & load
        final validConfig = {
          'enable': true,
          'hopMode': 'twoHop',
          'hop1Node': 'entry_A',
          'hop2Node': 'exit_B',
        };
        await storage.save(validConfig);

        final loaded = await storage.load();
        expect(loaded, isNotNull);
        expect(loaded!['enable'], isTrue);
        expect(loaded['hop1Node'], equals('entry_A'));

        // 2. Corrupted JSON triggers .bak fallback
        final validConfigV2 = {
          'enable': true,
          'hopMode': 'twoHop',
          'hop1Node': 'entry_A_v2',
          'hop2Node': 'exit_B_v2',
        };
        await storage.save(validConfigV2); // Now .bak has validConfig

        // Corrupt primary file with garbage bytes
        final primaryFile = File(configFilePath);
        await primaryFile.writeAsString(
          '{{CORRUPTED_JSON_DATA_EOF_ERROR}}',
          flush: true,
        );

        // Loading should recover from backup
        final recovered = await storage.load();
        expect(recovered, isNotNull);
        expect(recovered!['hop1Node'], equals('entry_A'));

        // 3. Orphan .tmp recovery (when both primary and .bak are missing/corrupted)
        await primaryFile.delete();
        final backupFile = File('$configFilePath.bak');
        if (await backupFile.exists()) {
          await backupFile.delete();
        }

        final orphanTmp = File('$configFilePath.9999.888.tmp');
        await orphanTmp.writeAsString(
          jsonEncode({'recoveredFromTmp': true}),
          flush: true,
        );

        final tmpRecovered = await storage.load();
        expect(tmpRecovered, isNotNull);
        expect(tmpRecovered!['recoveredFromTmp'], isTrue);
      },
    );
  });
}
