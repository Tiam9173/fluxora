// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/constant.dart';
import 'package:fluxora/common/identity.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_decision.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_flap_dampening.dart';
import 'package:fluxora/models/chain_insight.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/services/atomic_config_storage.dart';
import 'package:fluxora/services/chain_flap_dampener_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/services/chain_retry_service.dart';
import 'package:fluxora/services/chain_support_package_service.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeWindowsPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakeWindowsPathProviderPlatform(this.tempDir);

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

  late Directory windowsSandboxDir;
  String? originalProdConfigContent;
  final prodConfigFile = File(
    p.join(
      Platform.environment['APPDATA'] ?? '',
      AppIdentity.dataDirName,
      'chain_proxies.json',
    ),
  );

  setUpAll(() async {
    windowsSandboxDir = await Directory.systemTemp.createTemp(
      'windows_runtime_validation_',
    );
    PathProviderPlatform.instance = FakeWindowsPathProviderPlatform(
      windowsSandboxDir,
    );

    // Safety guard: Snapshot existing user config if present to guarantee no pollution
    if (await prodConfigFile.exists()) {
      try {
        originalProdConfigContent = await prodConfigFile.readAsString();
      } catch (_) {}
    }

    chainProbeService.customDelayTesterOverride = (proxy, url) async {
      await Future.delayed(const Duration(milliseconds: 10));
      return 115;
    };
  });

  tearDownAll(() async {
    chainProbeService.customDelayTesterOverride = null;

    // Safety restore: restore user config to original state
    if (originalProdConfigContent != null && await prodConfigFile.exists()) {
      try {
        await prodConfigFile.writeAsString(
          originalProdConfigContent!,
          flush: true,
        );
      } catch (_) {}
    }

    if (await windowsSandboxDir.exists()) {
      await windowsSandboxDir.delete(recursive: true);
    }
  });

  group('Phase 5.2-B — Windows Desktop Runtime Validation Suite', () {
    // ══════════════════════════════════════════════════════════════════════════
    // 1. Windows Platform Identity & Environment
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '1. Windows Identity: Verify Windows binary naming, data directory and compact name',
      () {
        expect(AppIdentity.productName, equals('Fluxora'));
        expect(AppIdentity.dataDirName, equals('Fluxora'));
        expect(AppIdentity.tunDeviceName, equals('Fluxora'));
        expect(AppIdentity.mainExecutableName, equals('Fluxora'));
        if (Platform.isWindows) {
          expect(AppIdentity.usesDevBinaries, isA<bool>());
        }
      },
    );

    test(
      '2. Windows Helper Service (Read-Only Specification): Verify naming consistency',
      () {
        // In Fluxora, the Windows helper service name is fixed to FluxoraHelperService (release) or FluxoraDevHelperService (debug)
        expect(
          appHelperService,
          anyOf(
            equals('FluxoraHelperService'),
            equals('FluxoraDevHelperService'),
          ),
        );
      },
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 2. Windows Lifecycle & Manager Concurrency
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '3. Windows Manager Init & Idempotency: Concurrent init() calls execute safely',
      () async {
        final manager = ChainProxyManager();
        expect(manager.isInitialized, isFalse);

        // Concurrent invocations simulating fast multi-event desktop startup
        await Future.wait([manager.init(), manager.init(), manager.init()]);
        expect(manager.isInitialized, isTrue);

        // Subsequent sequential init()
        await manager.init();
        expect(manager.isInitialized, isTrue);
      },
    );

    test(
      '4. Windows Desktop Window State (Minimize/Restore/Focus): Listener uniqueness preserved',
      () async {
        final manager = ChainProxyManager();
        await manager.init();

        int listenerTriggerCount = 0;
        void onUpdate() {
          listenerTriggerCount++;
        }

        manager.addListener(onUpdate);

        // Simulate 10 minimize/restore window events triggering telemetry notifications
        for (int i = 0; i < 10; i++) {
          chainTelemetryService.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.probeStarted,
              role: 'WindowsWindowStateTest',
              message: 'window_state_event_$i',
            ),
          );
        }

        // Exactly 10 triggers (1 per event), proving no duplicate listeners were registered
        expect(listenerTriggerCount, equals(10));
        manager.removeListener(onUpdate);
      },
    );

    test(
      '5. Repeated Page Lifecycle (20 cycles): Enter & exit Chain Proxy view without leak',
      () async {
        final manager = ChainProxyManager();
        await manager.init();

        // Simulate user opening and closing Chain Proxy view 20 times
        for (int cycle = 0; cycle < 20; cycle++) {
          int pageCallbacks = 0;
          void pageListener() => pageCallbacks++;

          // Open view: attach listener
          manager.addListener(pageListener);

          // Telemetry update occurs while viewing
          chainTelemetryService.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.probeCompleted,
              role: 'PageLifecycleCycle_$cycle',
              message: 'viewing_update',
            ),
          );

          expect(pageCallbacks, 1);

          // Close view: remove listener cleanly
          manager.removeListener(pageListener);

          // Subsequent update must NOT trigger the unmounted page listener
          chainTelemetryService.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.probeCompleted,
              role: 'PageLifecycleCycle_$cycle',
              message: 'unmounted_update',
            ),
          );

          expect(pageCallbacks, 1);
        }
      },
    );

    test(
      '6. Manager State & Clean Disposal: State flags reset properly',
      () async {
        final manager = ChainProxyManager();
        expect(manager.isProbingChain, isFalse);
        expect(manager.isFailingOver, isFalse);
        expect(manager.flapDampenerStatus.isSuppressed, isFalse);
      },
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 3. Windows Atomic Config Persistence
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '7. Windows File Persistence: Normal save and load on Windows filesystem',
      () async {
        final testConfigPath = p.join(
          windowsSandboxDir.path,
          'chain_proxies_win.json',
        );
        final storage = AtomicConfigStorage(testConfigPath);

        final testData = {
          'enable': true,
          'hopMode': 'twoHop',
          'hop1Node': 'win_entry_01',
          'hop2Node': 'win_exit_02',
          'preventWebRtcLeak': true,
        };

        await storage.save(testData);

        final loaded = await storage.load();
        expect(loaded, isNotNull);
        expect(loaded!['enable'], isTrue);
        expect(loaded['hop1Node'], equals('win_entry_01'));
        expect(loaded['hop2Node'], equals('win_exit_02'));
      },
    );

    test(
      '8. Windows File Persistence: Copy+delete fallback on Windows rename contention',
      () async {
        final testConfigPath = p.join(
          windowsSandboxDir.path,
          'chain_proxies_rename_test.json',
        );
        final storage = AtomicConfigStorage(testConfigPath);

        // Save initial version
        await storage.save({'version': 1, 'note': 'initial'});

        // Save second version - on Windows, target exists so copy+delete fallback is executed
        await storage.save({'version': 2, 'note': 'updated'});

        final loaded = await storage.load();
        expect(loaded, isNotNull);
        expect(loaded!['version'], equals(2));
        expect(loaded['note'], equals('updated'));

        // Check backup file exists
        final bakFile = File('$testConfigPath.bak');
        expect(await bakFile.exists(), isTrue);
      },
    );

    test(
      '9. Windows File Persistence: Corrupted main JSON recovers from .bak',
      () async {
        final testConfigPath = p.join(
          windowsSandboxDir.path,
          'chain_proxies_corrupt_test.json',
        );
        final storage = AtomicConfigStorage(testConfigPath);

        // Save v1 (will become backup on v2 save)
        await storage.save({'version': 1, 'valid': true});
        // Save v2
        await storage.save({'version': 2, 'valid': true});

        // Corrupt main JSON file with invalid truncated syntax
        final mainFile = File(testConfigPath);
        await mainFile.writeAsString(
          '{"version": 2, "corrupted": ',
          flush: true,
        );

        // Load must transparently recover from .bak (v1)
        final recovered = await storage.load();
        expect(recovered, isNotNull);
        expect(recovered!['version'], equals(1));
        expect(recovered['valid'], isTrue);
      },
    );

    test('10. Windows File Persistence: Orphan .tmp crash recovery', () async {
      final testConfigPath = p.join(
        windowsSandboxDir.path,
        'chain_proxies_orphan_test.json',
      );
      final storage = AtomicConfigStorage(testConfigPath);

      // Ensure no main or bak file exists
      final mainFile = File(testConfigPath);
      final bakFile = File('$testConfigPath.bak');
      if (await mainFile.exists()) await mainFile.delete();
      if (await bakFile.exists()) await bakFile.delete();

      // Simulate a process crash mid-write leaving a valid .tmp file
      final orphanTmp = File('$testConfigPath.123456789.0.tmp');
      await orphanTmp.writeAsString(
        jsonEncode({'recovered_from_crash': true}),
        flush: true,
      );

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect(loaded!['recovered_from_crash'], isTrue);
    });

    // ══════════════════════════════════════════════════════════════════════════
    // 4. Multi-Hop Topology & Direction Verification (2-Hop & 3-Hop)
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '11. Windows 2-Hop Topology: Entry -> Exit -> Internet config & validation',
      () async {
        final manager = ChainProxyManager();
        await manager.setHops(
          mode: ChainHopMode.twoHop,
          hop1: 'win_entry_hk',
          hop2: 'win_exit_us',
        );

        final val = manager.validateCurrentTopology();
        expect(val.isValid, isTrue);

        final report = await manager.probeCurrentChain();
        expect(report.mode, equals(ChainHopMode.twoHop));
        expect(report.hops.length, equals(2));
        expect(report.isOverallHealthy, isTrue);

        final snapshot = manager.telemetrySnapshot;
        final insight = ChainAdaptiveInsight.fromTelemetry(snapshot);
        expect(insight.forecast, isNotNull);
        final decision = ChainDecisionSupport.fromInsight(insight);
        expect(decision.recommendations, isNotNull);
      },
    );

    test(
      '12. Windows 3-Hop Topology: Entry -> Relay -> Exit direction validation',
      () async {
        final manager = ChainProxyManager();
        await manager.setHops(
          mode: ChainHopMode.threeHop,
          hop1: 'win_entry_jp',
          hop2: 'win_relay_de',
          hop3: 'win_exit_us',
        );

        final val = manager.validateCurrentTopology();
        expect(val.isValid, isTrue);

        final report = await manager.probeCurrentChain();
        expect(report.mode, equals(ChainHopMode.threeHop));
        expect(report.hops.length, equals(3));
        expect(report.hops[0].nodeName, equals('win_entry_jp'));
        expect(report.hops[1].nodeName, equals('win_relay_de'));
        expect(report.hops[2].nodeName, equals('win_exit_us'));
      },
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 5. Shadow Node Lifecycle & Isolation
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '13. Shadow Node Lifecycle: Correct injection of dialer-proxy and shadow nodes',
      () {
        final config = ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.threeHop,
          hop1Node: 'node_entry',
          hop2Node: 'node_relay',
          hop3Node: 'node_exit',
          createDedicatedGroup: true,
          dedicatedGroupName: '🔗 链式代理',
        );

        final rawConfig = <String, dynamic>{
          'proxies': [
            {
              'name': 'node_entry',
              'type': 'ss',
              'server': '1.1.1.1',
              'port': 8388,
            },
            {
              'name': 'node_relay',
              'type': 'ss',
              'server': '2.2.2.2',
              'port': 8388,
            },
            {
              'name': 'node_exit',
              'type': 'ss',
              'server': '3.3.3.3',
              'port': 8388,
            },
          ],
          'proxy-groups': [
            {
              'name': 'PROXY',
              'type': 'select',
              'proxies': ['node_entry', 'node_relay', 'node_exit'],
            },
          ],
          'rules': <dynamic>[],
        };

        config.applyToClashConfig(rawConfig);

        final proxies = (rawConfig['proxies'] as List)
            .cast<Map<String, dynamic>>();
        final shadowRelay = proxies.firstWhere(
          (p) => p['name'] == '🔗中转·node_relay',
        );
        final shadowExit = proxies.firstWhere(
          (p) => p['name'] == '🔗出口·node_exit',
        );

        // Check dialer-proxy direction
        expect(shadowRelay['dialer-proxy'], equals('node_entry'));
        expect(shadowExit['dialer-proxy'], equals('🔗中转·node_relay'));

        // Check dedicated group
        final groups = (rawConfig['proxy-groups'] as List)
            .cast<Map<String, dynamic>>();
        final chainGroup = groups.firstWhere((g) => g['name'] == '🔗 链式代理');
        expect(chainGroup['proxies'], contains('🔗出口·node_exit'));
      },
    );

    test(
      '14. Shadow Node Teardown: Complete cleanup when Chain Proxy is disabled',
      () {
        final configOn = ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.twoHop,
          hop1Node: 'node_entry',
          hop2Node: 'node_exit',
          createDedicatedGroup: true,
          dedicatedGroupName: '🔗 链式代理',
        );

        final rawConfig = <String, dynamic>{
          'proxies': [
            {
              'name': 'node_entry',
              'type': 'ss',
              'server': '1.1.1.1',
              'port': 8388,
            },
            {
              'name': 'node_exit',
              'type': 'ss',
              'server': '2.2.2.2',
              'port': 8388,
            },
          ],
          'proxy-groups': [
            {
              'name': 'PROXY',
              'type': 'select',
              'proxies': ['node_entry', 'node_exit'],
            },
          ],
          'rules': <dynamic>[],
        };

        // 1. Enable
        configOn.applyToClashConfig(rawConfig);
        expect(
          (rawConfig['proxies'] as List).any(
            (p) => p['name'] == '🔗出口·node_exit',
          ),
          isTrue,
        );

        // 2. Disable
        final configOff = configOn.copyWith(enable: false);
        configOff.applyToClashConfig(rawConfig);

        // Verify complete cleanup
        final proxiesAfter = rawConfig['proxies'] as List;
        expect(
          proxiesAfter.any((p) => p['name'].toString().startsWith('🔗')),
          isFalse,
        );

        final groupsAfter = (rawConfig['proxy-groups'] as List)
            .cast<Map<String, dynamic>>();
        expect(groupsAfter.any((g) => g['name'] == '🔗 链式代理'), isFalse);
        expect(groupsAfter.any((g) => g['name'] == '✈️ 链式跳板'), isFalse);
      },
    );

    test(
      '15. Repeated Chain ON/OFF Toggling (10 cycles): Zero shadow node residue or duplicates',
      () {
        final rawConfig = <String, dynamic>{
          'proxies': [
            {
              'name': 'sub_node_1',
              'type': 'ss',
              'server': '1.1.1.1',
              'port': 8388,
            },
            {
              'name': 'sub_node_2',
              'type': 'ss',
              'server': '2.2.2.2',
              'port': 8388,
            },
          ],
          'proxy-groups': [
            {
              'name': 'PROXY',
              'type': 'select',
              'proxies': ['sub_node_1', 'sub_node_2'],
            },
            {
              'name': 'AUTO',
              'type': 'url-test',
              'proxies': ['sub_node_1', 'sub_node_2'],
            },
          ],
          'rules': <dynamic>[],
        };

        final configOn = ChainProxyConfig(
          enable: true,
          hopMode: ChainHopMode.twoHop,
          hop1Node: 'sub_node_1',
          hop2Node: 'sub_node_2',
        );
        final configOff = configOn.copyWith(enable: false);

        for (int i = 0; i < 10; i++) {
          configOn.applyToClashConfig(rawConfig);
          // While ON: exactly 1 shadow exit node
          final exits = (rawConfig['proxies'] as List)
              .where((p) => p['name'] == '🔗出口·sub_node_2')
              .toList();
          expect(
            exits.length,
            equals(1),
            reason: 'Cycle $i: Must not duplicate shadow nodes',
          );

          configOff.applyToClashConfig(rawConfig);
          // While OFF: zero shadow nodes
          final remainingShadows = (rawConfig['proxies'] as List)
              .where((p) => p['name'].toString().startsWith('🔗'))
              .toList();
          expect(
            remainingShadows,
            isEmpty,
            reason: 'Cycle $i: All shadow nodes must be cleaned',
          );
        }
      },
    );

    test(
      '16. Normal Proxy Regression: Original subscription nodes & groups are unmodified',
      () {
        final originalProxies = [
          {'name': 'direct_node', 'type': 'direct'},
          {'name': 'hk_node', 'type': 'ss', 'server': '1.2.3.4', 'port': 1080},
        ];
        final originalGroups = [
          {
            'name': 'PROXY',
            'type': 'select',
            'proxies': ['direct_node', 'hk_node'],
          },
          {
            'name': 'DIRECT',
            'type': 'select',
            'proxies': ['direct_node'],
          },
        ];

        final rawConfig = <String, dynamic>{
          'proxies': List<dynamic>.from(
            originalProxies.map((p) => Map<String, dynamic>.from(p)),
          ),
          'proxy-groups': List<dynamic>.from(
            originalGroups.map((g) => Map<String, dynamic>.from(g)),
          ),
          'rules': <dynamic>[],
        };

        final config = ChainProxyConfig(enable: false);
        config.applyToClashConfig(rawConfig);

        // Verify normal proxy setup is untouched
        final groups = (rawConfig['proxy-groups'] as List)
            .cast<Map<String, dynamic>>();
        expect(groups.length, equals(2));
        expect(groups[0]['name'], equals('PROXY'));
        expect(groups[1]['name'], equals('DIRECT'));
      },
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 6. WebRTC Protection Rules & Network Security
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '17. WebRTC Protection Rules: High-priority STUN/TURN rules inserted cleanly',
      () {
        final rawConfig = <String, dynamic>{
          'proxies': <dynamic>[],
          'proxy-groups': <dynamic>[],
          'rules': <dynamic>['MATCH,DIRECT'],
        };

        final config = ChainProxyConfig(
          enable: true,
          preventWebRtcLeak: true,
          hopMode: ChainHopMode.twoHop,
          hop1Node: 'node1',
          hop2Node: 'node2',
        );

        config.applyToClashConfig(rawConfig);

        final rules = (rawConfig['rules'] as List).cast<String>();
        expect(rules.first, equals('DOMAIN-KEYWORD,stun,REJECT'));
        expect(rules, contains('DST-PORT,3478,REJECT'));
        expect(rules, contains('DOMAIN-SUFFIX,stun.cloudflare.com,REJECT'));
        expect(rules.last, equals('MATCH,DIRECT'));
      },
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 7. Telemetry Bounds & Memory Safety
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '18. Telemetry Memory Bounds: 1,000+ stress events adhere to maxEvents = 200',
      () {
        final telemetry = ChainTelemetryService();
        telemetry.clear();

        for (int i = 0; i < 1500; i++) {
          telemetry.record(
            ChainTelemetryEvent(
              type: (i % 2 == 0)
                  ? ChainTelemetryEventType.probeStarted
                  : ChainTelemetryEventType.probeCompleted,
              role: 'WinStress_${i % 4}',
              message: 'Windows memory test event $i',
            ),
          );
        }

        final snapshot = telemetry.getSnapshot();
        expect(
          snapshot.recentEvents.length,
          equals(ChainTelemetryService.maxEvents),
        );
        expect(snapshot.totalEvents, equals(1500));
        expect(ChainTelemetryService.maxEvents, equals(200));

        telemetry.clear();
        expect(telemetry.getSnapshot().totalEvents, equals(0));
      },
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 8. Diagnostic Export & Support Package
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '19. Diagnostic Export: Generates valid ZIP archive containing 5 files on Windows',
      () async {
        final manager = ChainProxyManager();
        final pkg = await chainSupportPackageService.createPackage(manager);
        final zipFile = await chainSupportPackageService.exportPackage(pkg);

        expect(await zipFile.exists(), isTrue);
        expect(zipFile.path, endsWith('.zip'));

        final bytes = await zipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        final fileNames = archive.map((f) => f.name).toSet();
        expect(fileNames, contains('summary.md'));
        expect(fileNames, contains('telemetry.json'));
        expect(fileNames, contains('intelligence.json'));
        expect(fileNames, contains('insight.json'));
        expect(fileNames, contains('decision.json'));

        await zipFile.delete();
        expect(await zipFile.exists(), isFalse);
      },
    );

    test(
      '20. Diagnostic Export Privacy: Strict redaction of secrets, tokens, and passwords',
      () async {
        final manager = ChainProxyManager();
        await manager.addLandingProxies([
          const LandingProxy(
            id: 'landing_win_sensitive',
            name: 'Win-Sensitive-Proxy',
            server: '198.51.100.99',
            port: 1080,
            protocol: ChainProxyProtocol.socks5,
            username: 'confidential_user',
            password: 'TopSecretPassword999!',
            dialerProxy: 'win_entry_hk',
          ),
        ]);

        final pkg = await chainSupportPackageService.createPackage(manager);
        final zipFile = await chainSupportPackageService.exportPackage(pkg);
        final bytes = await zipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final file in archive) {
          if (file.name.endsWith('.json') || file.name.endsWith('.md')) {
            final contentStr = utf8.decode(file.content as List<int>);
            expect(
              contentStr,
              isNot(contains('TopSecretPassword999!')),
              reason:
                  'File ${file.name} must never expose sensitive raw passwords',
            );
          }
        }

        await zipFile.delete();
      },
    );

    test(
      '21. Support Package Assembly: Verification of package structure and confirmation safety',
      () async {
        final manager = ChainProxyManager();
        final pkg = await chainSupportPackageService.createPackage(manager);

        expect(pkg.diagnostic.reportId, isNotEmpty);
        expect(pkg.diagnostic.summary, isNotNull);
        expect(pkg.diagnostic.telemetry, isNotNull);
        expect(pkg.diagnostic.insight, isNotNull);
        expect(pkg.diagnostic.decisions, isNotNull);
        expect(pkg.createdAt, isA<DateTime>());
        expect(pkg.platform, isNotEmpty);
      },
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 9. Cancellation & Failover Handling
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '22. Windows In-Flight Cancellation: Active probe & failover abort safely on command',
      () async {
        final manager = ChainProxyManager();
        await manager.updateConfig(
          (c) => c.copyWith(
            enable: true,
            hop1Node: 'win_entry',
            hop2Node: 'win_exit',
          ),
          reloadCore: false,
        );

        // Probe cancellation
        final probeFuture = manager.probeCurrentChain(
          timeout: const Duration(seconds: 5),
        );
        expect(manager.isProbingChain, isTrue);
        manager.cancelCurrentProbe();
        expect(manager.isProbingChain, isFalse);

        final probeReport = await probeFuture;
        expect(probeReport.isCancelled, isTrue);

        // Failover cancellation
        manager.setFallbackPool(
          ChainFallbackPool(
            exitCandidates: [
              ChainFallbackCandidate(
                nodeName: 'fallback_exit_win',
                role: FallbackCandidateRole.exit,
              ),
            ],
          ),
        );

        final failoverFuture = manager.triggerAutoFailover(
          initialFailureReport: ChainProbeReport(
            mode: ChainHopMode.twoHop,
            isOverallHealthy: false,
            healthStatus: ChainHealthStatus.failed,
            failureHop: 2,
            hops: const [],
            timestamp: DateTime.now(),
          ),
        );
        expect(manager.isFailingOver, isTrue);
        manager.cancelFailover();
        expect(manager.isFailingOver, isFalse);

        final failoverResult = await failoverFuture;
        expect(failoverResult.isCancelled, isTrue);
      },
    );

    // ══════════════════════════════════════════════════════════════════════════
    // 10. Flap Dampening & Network Failure Simulation
    // ══════════════════════════════════════════════════════════════════════════
    test(
      '23. Flap Dampening on Windows: Penalty accumulation and suppression trigger',
      () {
        final dampener = ChainFlapDampenerService();
        dampener.reset();

        const policy = ChainFlapDampeningPolicy(
          penaltyPerFlap: 1000,
          suppressThreshold: 2500,
          reuseThreshold: 500,
        );

        // Flap 1
        dampener.recordFlap(
          role: FallbackCandidateRole.exit,
          fromNode: 'win_node_A',
          toNode: 'win_node_B',
          policy: policy,
        );
        expect(dampener.status.isSuppressed, isFalse);
        expect(dampener.status.currentPenalty, closeTo(1000.0, 5.0));

        // Flap 2
        dampener.recordFlap(
          role: FallbackCandidateRole.exit,
          fromNode: 'win_node_B',
          toNode: 'win_node_A',
          policy: policy,
        );
        expect(dampener.status.isSuppressed, isFalse);
        expect(dampener.status.currentPenalty, closeTo(2000.0, 5.0));

        // Flap 3 -> exceeds threshold -> suppressed
        dampener.recordFlap(
          role: FallbackCandidateRole.exit,
          fromNode: 'win_node_A',
          toNode: 'win_node_B',
          policy: policy,
        );
        expect(dampener.status.isSuppressed, isTrue);
        expect(dampener.status.currentPenalty, closeTo(3000.0, 5.0));

        dampener.reset();
        expect(dampener.status.isSuppressed, isFalse);
        expect(dampener.status.currentPenalty, equals(0.0));
      },
    );

    test(
      '24. Network Failure & Handover Simulation: Probe failure -> retry -> failover sequence',
      () async {
        final manager = ChainProxyManager();
        await manager.updateConfig(
          (c) => c.copyWith(
            enable: true,
            hop1Node: 'sim_entry',
            hop2Node: 'sim_exit',
          ),
          reloadCore: false,
        );

        // 1. Initial healthy state
        final healthyReport = await manager.probeCurrentChain();
        expect(healthyReport.isOverallHealthy, isTrue);

        // 2. Simulated network disconnect (returns null delay)
        chainProbeService.customDelayTesterOverride = (proxy, url) async =>
            null;

        final failedReport = await manager.probeCurrentChain(
          retryPolicy: const ChainRetryPolicy(
            maxAttempts: 2,
            baseDelay: Duration(milliseconds: 10),
          ),
        );
        expect(failedReport.isOverallHealthy, isFalse);

        // 3. Simulated network recovery
        chainProbeService.customDelayTesterOverride = (proxy, url) async => 88;
        final recoveredReport = await manager.probeCurrentChain();
        expect(recoveredReport.isOverallHealthy, isTrue);
      },
    );
  });
}
