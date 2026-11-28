import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:code_forge/code_forge.dart' show RustLib;
// ignore: depend_on_referenced_packages
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/core.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/manager/clash_manager.dart';
import 'package:fluxora/views/config/dns.dart';
import 'package:fluxora/views/profiles/profiles.dart';
import 'package:fluxora/views/profiles/aggregate_view.dart';
import 'package:fluxora/views/proxies/proxies.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../support/render_capture.dart';

class _Paths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
  @override
  Future<String?> getDownloadsPath() async => Directory.systemTemp.path;
}

class _Core extends Fake implements ClashHandlerInterface {
  int providerReads = 0;
  @override
  Future<T> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
    FutureOr<T> Function()? onTimeout,
    T? defaultValue,
  }) async {
    if (method != ActionMethod.readProviderNodes) {
      throw StateError('Unexpected action $method');
    }
    providerReads++;
    return Result.success([
          {
            'name': 'remote-$providerReads',
            'type': 'trojan',
            'server': 'tls.example.test',
            'port': 443,
            'password': 'fixture',
            'sni': 'tls.example.test',
            'skip-cert-verify': false,
          },
        ])
        as T;
  }

  @override
  Future<String> validateConfig(String config, {String? ageSecretKey}) async {
    final raw = loadYaml(config);
    final names = {
      for (final item in [...?raw['proxies'], ...?raw['proxy-groups']])
        item['name'],
      'DIRECT',
      'REJECT',
    };
    for (final rule in (raw['rules'] as List? ?? const [])) {
      final target = ParsedRule.parseString(rule as String).ruleTarget;
      if (target != null && !names.contains(target)) return 'missing $target';
    }
    return '';
  }

  @override
  Future<bool> setState(CoreState state) async => true;
  String node = 'A-node';
  bool rejectB = false;
  int emptyReads = 0;
  String groupType = 'Selector';
  String? nativeLock;
  final changes = <ChangeProxyParams>[];
  final setups = <String>[];
  final startedB = Completer<void>();
  Completer<void>? releaseB;
  Completer<void>? pendingSetup;
  int? appliedPort;
  @override
  Future<String> changeProxy(ChangeProxyParams params) async {
    changes.add(params);
    return '';
  }

  final flush = Completer<bool>();
  @override
  Future<bool> forceGc({bool forceFreeOSMemory = false}) async => true;
  @override
  Future<bool> closeConnections() async => true;
  @override
  Future<bool> flushDnsCache() => flush.future;
  @override
  Future<Result> getConfig(String path, {String? ageSecretKey}) async {
    final config =
        jsonDecode(jsonEncode(loadYaml(await File(path).readAsString())))
            as Map<String, dynamic>;
    config['rule'] = config.remove('rules');
    return Result.success(config);
  }

  @override
  Future<String> setupConfig(SetupParams params) async {
    final config = loadYaml(
      await File(await appPath.configFilePath).readAsString(),
    );
    final name = (config['proxies'] as List).first['name'] as String;
    appliedPort = config['mixed-port'] as int?;
    setups.add(name);
    if (releaseB case final release? when name == 'B-node') {
      startedB.complete();
      await release.future;
    }
    if (name == 'B-node' && pendingSetup != null) await pendingSetup!.future;
    if (rejectB && name == 'B-node') {
      throw StateError('Invalid B configuration');
    }
    node = name;
    return '';
  }

  @override
  Future<String> getExternalProviders() async => '[]';
  @override
  Future<String> getMode() async => 'rule';
  @override
  Future<Map> getProxies() async {
    if (emptyReads > 0) {
      emptyReads--;
      return {};
    }
    return {
      'GLOBAL': {
        'name': 'GLOBAL',
        'type': 'Selector',
        'now': 'Select',
        'all': ['Select'],
      },
      'Select': {
        'name': 'Select',
        'type': groupType,
        if (nativeLock != null) 'fixed': nativeLock,
        'now': node,
        'all': [node],
      },
      node: {'name': node, 'type': 'Shadowsocks'},
    };
  }
}

class _Controller extends AppController {
  _Controller(super.context, super.ref);
  Future<void>? lastChange;
  Future<void>? lastApply;
  Future<void>? lastAggregateSave;

  @override
  Future<void> saveAggregate(AggregateProfile aggregate) =>
      lastAggregateSave = super.saveAggregate(aggregate);

  @override
  Future<void> applyProfile({bool silence = false}) {
    return lastApply = super.applyProfile(silence: silence);
  }

  @override
  Future<void> handleChangeProfile({
    bool hardRestart = false,
    required String? previousProfileId,
  }) {
    return lastChange = super.handleChangeProfile(
      hardRestart: hardRestart,
      previousProfileId: previousProfileId,
    );
  }

  @override
  void addCheckIpNumDebounce() {}
  @override
  void scheduleIdleGc({Duration delay = const Duration(seconds: 2)}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const scriptDll = String.fromEnvironment('SCRIPT_DLL');
  setUpAll(() async {
    if (scriptDll.isNotEmpty) {
      await RustLib.init(externalLibrary: ExternalLibrary.open(scriptDll));
    }
    if (scriptDll.isNotEmpty ||
        const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final font = File('C:/Windows/Fonts/msyh.ttc');
      if (await font.exists()) {
        await (FontLoader('ScriptFixture')..addFont(
              font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            ))
            .load();
      }
    }
  });
  late _Core core;
  late ClashHandlerInterface original;
  late WidgetRef ref;
  late _Controller controller;
  const profiles = [
    Profile(
      id: 'switch-A',
      label: 'A',
      url: 'https://example.invalid/A',
      autoUpdateDuration: Duration(days: 1),
    ),
    Profile(
      id: 'switch-B',
      label: 'B',
      url: 'https://example.invalid/B',
      autoUpdateDuration: Duration(days: 1),
    ),
  ];
  final thirdProfile = profiles.first.copyWith(id: 'switch-C', label: 'C');

  setUp(() async {
    PathProviderPlatform.instance = _Paths();
    original = clashCore.clashInterface;
    core = _Core();
    clashCore.clashInterface = core;
    System.platformOverride = 'android';
    await AppLocalizations.load(const Locale('en'));
    SharedPreferences.setMockInitialValues({});
    await preferences.sharedPreferencesCompleter.future;
    globalState.config = Config(
      themeProps: const ThemeProps(),
      profiles: profiles,
      currentProfileId: profiles.first.id,
      vpnProps: const VpnProps(
        portFallback: false,
        controllerPortFallback: false,
      ),
    );
    globalState.appState = AppState(
      viewSize: const Size(390, 844),
      brightness: Brightness.dark,
      version: 1,
      requests: FixedList(10),
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    for (final profile in [...profiles, thirdProfile]) {
      await (await profile.getFile()).writeAsString('''
proxies:
  - {name: ${profile.label}-node, type: ss, server: example.invalid, port: 443, cipher: aes-128-gcm, password: fixture}
proxy-groups:
  - {name: Select, type: select, proxies: [${profile.label}-node]}
rules: ['MATCH,Select']
''');
    }
  });
  tearDown(() {
    if (!core.flush.isCompleted) core.flush.complete(true);
    clashCore.clashInterface = original;
    System.platformOverride = null;
    globalState.startTime = null;
  });

  testWidgets('node import repairs the default target in an existing group', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final profile = profiles.first;
      final file = await profile.getFile();
      await file.writeAsString('''
proxies:
  - {name: Existing, type: trojan, server: edge.example, port: 443, password: fixture}
proxy-groups:
  - {name: Select, type: select, proxies: [Existing]}
''');
      await ManualProxyHelper.addOrUpdateProxiesToProfile(profile, [
        {
          'name': 'Imported',
          'type': 'ss',
          'server': 'new.example',
          'port': 443,
          'cipher': 'aes-128-gcm',
          'password': 'fixture',
        },
      ]);
      final output = loadYaml(await file.readAsString());
      expect(output['rules'], ['MATCH,PROXY']);
      expect((output['proxy-groups'] as List).last['proxies'], [
        'Existing',
        'Imported',
      ]);
    });
  });

  testWidgets(
    'runtime repairs cached PROXY rules without changing subscription',
    (tester) async {
      await tester.runAsync(() async {
        final file = await profiles.first.getFile();
        final source = (await file.readAsString()).replaceFirst(
          'MATCH,Select',
          'MATCH,PROXY',
        );
        await file.writeAsString(source);
        final output = await globalState.patchRawConfig(
          patchConfig: globalState.config.patchClashConfig,
        );
        expect(output['rules'], ['MATCH,PROXY']);
        expect((output['proxy-groups'] as List).last, {
          'name': 'PROXY',
          'type': 'select',
          'proxies': ['A-node'],
        });
        expect(await file.readAsString(), source);
      });
    },
  );

  testWidgets(
    'subscription validation repairs PROXY and retains other errors',
    (tester) async {
      await tester.runAsync(() async {
        final profile = profiles.first;
        final file = await profile.getFile();
        final original = await file.readAsString();
        final imported = original.replaceFirst('MATCH,Select', 'MATCH,PROXY');
        await profile.saveFile(Uint8List.fromList(utf8.encode(imported)));
        final raw = loadYaml(await file.readAsString());
        expect((raw['proxy-groups'] as List).last['name'], 'PROXY');
        expect(raw['rules'], ['MATCH,PROXY']);
        expect(raw['proxies'][0]['server'], 'example.invalid');
        await profile.saveFileWithString(imported);
        final accepted = await file.readAsString();
        await expectLater(
          profile.saveFileWithString(
            imported.replaceAll('MATCH,PROXY', 'MATCH,Unknown'),
          ),
          throwsA('missing Unknown'),
        );
        expect(await file.readAsString(), accepted);
      });
    },
  );

  for (final overrideDns in [false, true]) {
    for (final scriptEnabled in [false, true]) {
      testWidgets(
        'strict private DNS survives generation: override=$overrideDns script=$scriptEnabled',
        (tester) async {
          const host = 'resolver.private.example';
          const channel = MethodChannel('service');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async =>
                call.method == 'getPrivateDnsServerName' ? host : null,
          );
          addTearDown(() {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel,
              null,
            );
            globalState.androidPrivateDnsServerName = null;
          });
          globalState.config = globalState.config.copyWith(
            overrideDns: overrideDns,
            scriptProps: scriptEnabled
                ? const ScriptProps(
                    currentId: 'dns-script',
                    scripts: [
                      Script(
                        id: 'dns-script',
                        label: 'DNS fixture',
                        content: '''
function main(c) {
  c.dns = {enable: true, 'default-nameserver': ['192.0.2.53'],
    nameserver: ['system'], 'nameserver-policy': {'geosite:private': ['system']}};
  c.rules = ['MATCH,Select'];
  return c;
}
''',
                      ),
                    ],
                  )
                : const ScriptProps(),
          );
          await tester.runAsync(() async {
            final output = await globalState.patchRawConfig(
              patchConfig: globalState.config.patchClashConfig,
            );
            final dns = output['dns'] as Map;
            expect(dns['nameserver'], ['tls://$host:853#DIRECT']);
            final policy = dns['nameserver-policy'] as Map;
            expect(policy.keys.first, host);
            expect(policy[host], isNot(contains('tls://$host:853#DIRECT')));
            expect(output['rules'], [
              'AND,((DOMAIN,$host),(NETWORK,TCP),(DST-PORT,853)),DIRECT',
              'MATCH,Select',
            ]);
            expect(output['proxies'][0]['server'], 'example.invalid');
            expect(output['proxies'][0]['skip-cert-verify'], isNull);
          });
        },
        skip: scriptEnabled && scriptDll.isEmpty,
      );
    }
  }

  for (final scenario in ['phone', 'desktop', 'missing']) {
    testWidgets(
      'aggregate management preserves the active profile: $scenario',
      (tester) async {
        final desktop = scenario == 'desktop';
        final missing = scenario == 'missing';
        System.platformOverride = desktop ? 'windows' : 'android';
        await AppLocalizations.load(const Locale('zh', 'CN'));
        tester.view.physicalSize = Size(
          desktop ? 1024 : (missing ? 320 : 390),
          844,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        globalState.config = globalState.config
            .copyWith(
              aggregates: [
                AggregateProfile(
                  id: 'work',
                  name: '办公与旅行',
                  baseProfileId: missing ? 'missing-source' : profiles.first.id,
                  memberIds: [profiles.last.id, if (missing) 'missing-member'],
                ),
              ],
            )
            .withAggregateProfiles();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              navigatorKey: globalState.navigatorKey,
              theme: ThemeData(
                fontFamily: 'HarmonyOS_Sans',
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xff4269d2),
                  brightness: desktop ? Brightness.light : Brightness.dark,
                ),
              ),
              home: Consumer(
                builder: (context, r, _) {
                  ref = r;
                  controller = _Controller(context, ref);
                  globalState.appController = controller;
                  return RepaintBoundary(
                    key: boundary,
                    child: Scaffold(
                      appBar: AppBar(title: const Text('管理聚合')),
                      body: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(missing ? 1.3 : 1),
                        ),
                        child: const AggregateView(aggregateId: 'work'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        // Let the real profile-file reads finish before checking the controls.
        await tester.runAsync(() async {
          for (var attempt = 0; attempt < 100; attempt++) {
            final refresh = tester.widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == appLocalizations.refresh,
              ),
            );
            if (refresh.onPressed != null) return;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
          }
          fail('aggregate member statistics did not finish');
        });
        await tester.pumpAndSettle();
        if (missing) {
          expect(
            find.text(appLocalizations.aggregateSourceMissing),
            findsWidgets,
          );
        }
        if (const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
          await captureFlutterFrame(
            tester,
            find.byKey(boundary),
            'build/feedback-20261127/aggregate-management-$scenario.png',
          );
        }
        await tester.tap(find.byTooltip(appLocalizations.aggregateRename));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(TextField),
          ),
          '出行配置',
        );
        await tester.runAsync(() async {
          await tester.tap(find.text(appLocalizations.save));
          await controller.lastAggregateSave!.timeout(
            const Duration(seconds: 3),
          );
        });
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(globalState.config.aggregates.single.name, '出行配置');
        expect(ref.read(currentProfileIdProvider), profiles.first.id);
        await tester.ensureVisible(
          find.text(appLocalizations.aggregateFullMerge),
        );
        await tester.runAsync(() async {
          await tester.tap(find.text(appLocalizations.aggregateFullMerge));
          for (var attempt = 0; attempt < 100; attempt++) {
            if ((await preferences.getConfig())?.aggregates.single.mode ==
                AggregateMode.full) {
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          fail('aggregate merge mode was not persisted');
        });
        await tester.pumpAndSettle();
        expect(globalState.config.aggregates.single.mode, AggregateMode.full);
        expect(ref.read(currentProfileIdProvider), profiles.first.id);
        final member = find.byKey(ValueKey(profiles.last.id));
        await tester.scrollUntilVisible(
          member,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.runAsync(() async {
          await tester.tap(
            find.descendant(of: member, matching: find.byType(Switch)),
          );
          await controller.lastAggregateSave!.timeout(
            const Duration(seconds: 3),
          );
        });
        await tester.pumpAndSettle();
        expect(
          globalState.config.aggregates.single.memberIds,
          isNot(contains(profiles.last.id)),
        );
        expect(
          globalState.config.profiles.getProfile(profiles.last.id)!.url,
          profiles.last.url,
        );
        expect(ref.read(currentProfileIdProvider), profiles.first.id);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  for (final scripted in [false, true]) {
    testWidgets(
      'provider aggregate refreshes without stale member cache: script=$scripted',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, r, _) {
                globalState.appController = _Controller(context, r);
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.runAsync(() async {
          final member = profiles.last.copyWith(
            scriptId: scripted ? 'provider-script' : null,
          );
          globalState.config = globalState.config
              .copyWith(
                profiles: [profiles.first, member],
                aggregates: const [
                  AggregateProfile(
                    id: 'provider-work',
                    name: 'Providers',
                    baseProfileId: 'switch-A',
                    memberIds: ['switch-B'],
                    mode: AggregateMode.full,
                  ),
                ],
                scriptProps: scripted
                    ? const ScriptProps(
                        scripts: [
                          Script(
                            id: 'provider-script',
                            label: 'Provider script',
                            content:
                                "function main(c) { if (!c.proxies || !c.proxies.length) throw new Error('no proxy nodes'); return c; }",
                          ),
                        ],
                      )
                    : const ScriptProps(),
              )
              .withAggregateProfiles();
          globalState.config = globalState.config.copyWith(
            currentProfileId: globalState.config.aggregates.single.profileId,
          );
          final file = await member.getFile();
          const source = '''
proxy-providers:
  remote: {type: http, url: 'https://fixture.invalid/provider', path: ./fixture.yaml}
proxy-groups:
  - {name: Remote, type: select, use: [remote]}
rules: ['MATCH,Remote']
''';
          await file.writeAsString(source);
          for (var version = 1; version <= 2; version++) {
            final output = await globalState.patchRawConfig(
              patchConfig: globalState.config.patchClashConfig,
            );
            final nodes = (output['proxies'] as List)
                .where((n) => n['type'] == 'trojan')
                .toList();
            expect(nodes, hasLength(1));
            expect(nodes.single['name'], '[B] remote-$version');
            expect(nodes.single['server'], 'tls.example.test');
            expect(nodes.single['sni'], 'tls.example.test');
            expect(nodes.single['skip-cert-verify'], false);
            final group = (output['proxy-groups'] as List).firstWhere(
              (g) => g['name'] == '[B] Remote',
            );
            expect(group['proxies'], ['[B] remote-$version']);
            expect(group.containsKey('use'), false);
            expect(core.providerReads, version);
          }
          expect(await file.readAsString(), source);
        });
      },
      skip: scripted && scriptDll.isEmpty,
    );
  }

  for (final platform in ['android', 'windows']) {
    testWidgets(
      'aggregate switches independently and preserves source profiles on $platform',
      (tester) async {
        System.platformOverride = platform;
        globalState.config = globalState.config
            .copyWith(
              currentProfileId: profiles.last.id,
              aggregates: const [
                AggregateProfile(
                  id: 'work',
                  name: 'Work',
                  baseProfileId: 'switch-A',
                  memberIds: ['switch-B'],
                  mode: AggregateMode.full,
                ),
              ],
            )
            .withAggregateProfiles();
        final aggregateId = globalState.config.aggregates.single.profileId!;
        final container = ProviderContainer();
        addTearDown(container.dispose);
        var bound = false;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: globalState.navigatorKey,
              home: ClashManager(
                child: Consumer(
                  builder: (context, r, _) {
                    if (!bound) {
                      ref = r;
                      controller = _Controller(context, ref);
                      globalState.appController = controller;
                      bound = true;
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          final original = await (await profiles.first.getFile())
              .readAsString();
          await controller.applyProfile(silence: true);
          expect(core.node, 'B-node');
          await controller.selectAggregate('work');
          container.read(needSetupProvider);
          await controller.lastChange!.timeout(const Duration(seconds: 5));
          expect(core.node, 'A-node');
          expect(globalState.config.currentProfileId, aggregateId);
          final snapshot = loadYaml(
            await File(
              await appPath.getProfilePath(aggregateId),
            ).readAsString(),
          );
          expect(
            (snapshot['proxies'] as List).map((p) => p['name']),
            containsAll(['A-node', '[B] B-node']),
          );
          controller.updateCurrentSelectedMap('Select', '[B] B-node');
          expect(
            globalState.config.profiles.getProfile('switch-A')!.selectedMap,
            isEmpty,
          );
          expect(
            globalState.config.currentProfile!.selectedMap['Select'],
            '[B] B-node',
          );
          // Source deletion must not leave a selectable aggregate with dangling
          // references or remove the YAML used by the running configuration.
          for (final source in profiles) {
            await controller.deleteProfile(source.id);
            expect(
              globalState.config.profiles.getProfile(source.id),
              isNotNull,
            );
            expect(await (await source.getFile()).exists(), isTrue);
          }
          expect(globalState.config.currentProfileId, aggregateId);
          // Updating a member refreshes the independent runtime configuration.
          final memberFile = await profiles.last.getFile();
          await memberFile.writeAsString(
            (await memberFile.readAsString()).replaceAll('B-node', 'B-updated'),
          );
          controller.setProfileAndAutoApply(profiles.last);
          await Future<void>.delayed(const Duration(milliseconds: 700));
          await controller.lastApply!.timeout(const Duration(seconds: 5));
          final refreshed = loadYaml(
            await File(
              await appPath.getProfilePath(aggregateId),
            ).readAsString(),
          );
          expect(
            (refreshed['proxies'] as List).map((p) => p['name']),
            contains('[B] B-updated'),
          );
          await controller.selectProfile('switch-A');
          container.read(needSetupProvider);
          await controller.lastChange!.timeout(const Duration(seconds: 5));
          expect(globalState.config.currentAggregateId, isNull);
          final standalone = loadYaml(
            await File(await appPath.configFilePath).readAsString(),
          );
          expect((standalone['proxies'] as List).map((p) => p['name']), [
            'A-node',
          ]);
          expect(
            await (await profiles.first.getFile()).readAsString(),
            original,
          );
          expect(
            globalState.config.profiles.getProfile('switch-A')!.url,
            profiles.first.url,
          );
          // Editing another aggregate must not change the live selection.
          await controller.saveAggregate(
            globalState.config.aggregates.single.copyWith(name: 'Renamed'),
          );
          expect(ref.read(currentProfileIdProvider), 'switch-A');
          expect(globalState.config.currentAggregate, isNull);
          expect(
            globalState.config.profiles.getProfile(aggregateId)!.label,
            'Renamed',
          );

          // A missing base is a visible error and uses the normal rollback.
          await controller.saveAggregate(
            globalState.config.aggregates.single.copyWith(
              baseProfileId: 'missing-source',
            ),
          );
          await controller.selectAggregate('work');
          container.read(needSetupProvider);
          await controller.lastChange!.timeout(const Duration(seconds: 5));
          expect(ref.read(currentProfileIdProvider), 'switch-A');
          expect(globalState.config.currentAggregate, isNull);
          expect(core.node, 'A-node');
          // The live manager also observes the rollback selection. Drain its
          // queued application before disposing the provider scope.
          container.read(needSetupProvider);
          await controller.lastChange!.timeout(const Duration(seconds: 5));
          // Removing the generated profile preserves both source subscriptions.
          await controller.deleteProfile(aggregateId);
          expect(globalState.config.aggregates, isEmpty);
          expect(
            globalState.config.profiles.map((p) => p.id),
            profiles.map((p) => p.id),
          );
          expect(
            await (await profiles.first.getFile()).readAsString(),
            original,
          );
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  for (final platform in ['android', 'windows']) {
    testWidgets('native script profile switching on $platform', (tester) async {
      System.platformOverride = platform;
      tester.view.physicalSize = platform == 'android'
          ? const Size(390, 844)
          : const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final script = const Script(id: 'native', label: 'Native fixture')
          .copyWith(
            content: '''
async function main(c) {
  c.proxies.forEach(p => p.name += ' · script');
  c['proxy-groups'] = [{name:'Select',type:'select',proxies:c.proxies.map(p=>p.name)}];
  c['rule-providers'] = {common: {type:'http',url:'http://127.0.0.1:1/rules.yaml',behavior:'domain',format:'yaml',interval:86400}};
  c.rules = ['RULE-SET,common,DIRECT','MATCH,Select'];
  return c;
}
''',
          );
      globalState.config = globalState.config.copyWith(
        scriptProps: ScriptProps(currentId: script.id, scripts: [script]),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            theme: ThemeData(
              fontFamily: 'ScriptFixture',
              brightness: platform == 'android'
                  ? Brightness.dark
                  : Brightness.light,
            ),
            home: Consumer(
              builder: (context, r, _) {
                globalState.measure = Measure.of(context, 1);
                ref = r;
                controller = _Controller(context, ref);
                globalState.appController = controller;
                return RepaintBoundary(
                  key: boundary,
                  child: ProviderScope(
                    overrides: [queryProvider.overrideWith(() => Query())],
                    child: const ProxiesView(),
                  ),
                );
              },
            ),
          ),
        ),
      );
      final paths = <String>[];
      for (final id in ['switch-A', 'switch-B', 'switch-A']) {
        await tester.runAsync(() async {
          ref.read(currentProfileIdProvider.notifier).value = id;
          await controller.applyProfile(silence: true);
          final config = loadYaml(
            await File(await appPath.configFilePath).readAsString(),
          );
          paths.add(config['rule-providers']['common']['path'] as String);
          final output = File('build/script-loading/$id.json');
          await output.parent.create(recursive: true);
          await output.writeAsString(jsonEncode(config));
        });
        await tester.pumpAndSettle();
        final expected = id.endsWith('A')
            ? 'A-node · script'
            : 'B-node · script';
        expect(find.text(expected), findsWidgets);
        expect(ref.read(groupsProvider).last.all.single.name, expected);
      }
      expect(paths.toSet(), hasLength(1));
      await captureFlutterFrame(
        tester,
        find.byKey(boundary),
        'build/script-loading/script-switch-$platform.png',
      );
      core.emptyReads = 4;
      await tester.runAsync(() => controller.applyProfile(silence: true));
      await tester.pump();
      expect(find.text('A-node · script'), findsWidgets);
      await captureFlutterFrame(
        tester,
        find.byKey(boundary),
        'build/script-loading/transient-empty-$platform.png',
      );
      await tester.runAsync(() => controller.updateGroups());
      expect(ref.read(groupsProvider).last.all.single.name, 'A-node · script');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }, skip: scriptDll.isEmpty);
  }

  testWidgets(
    'private DNS refresh applies changes once and retries failed reloads',
    (tester) async {
      String? privateHost = 'first.private.example';
      const channel = MethodChannel('service');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        return call.method == 'getPrivateDnsServerName' ? privateHost : null;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        globalState.androidPrivateDnsServerName = null;
      });
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                controller = _Controller(context, ref);
                globalState.appController = controller;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        globalState.androidPrivateDnsServerName = 'previous.private.example';
        globalState.startTime = DateTime.now().subtract(
          const Duration(seconds: 1),
        );
        await controller.refreshAndroidPrivateDnsOnNetworkChanged();
        expect(core.setups, ['A-node']);
        final generated = loadYaml(
          await File(await appPath.configFilePath).readAsString(),
        );
        expect(generated['dns']['nameserver'], [
          'tls://first.private.example:853#DIRECT',
        ]);
        await controller.refreshAndroidPrivateDnsOnNetworkChanged();
        privateHost = null;
        await controller.refreshAndroidPrivateDnsOnNetworkChanged();
        expect(core.setups, ['A-node']);
        expect(
          globalState.androidPrivateDnsServerName,
          'first.private.example',
        );

        ref.read(currentProfileIdProvider.notifier).value = profiles.last.id;
        core.rejectB = true;
        privateHost = 'second.private.example';
        await controller.refreshAndroidPrivateDnsOnNetworkChanged();
        expect(
          globalState.androidPrivateDnsServerName,
          'first.private.example',
        );
        core.rejectB = false;
        await controller.refreshAndroidPrivateDnsOnNetworkChanged();
        expect(core.setups, ['A-node', 'B-node', 'B-node']);
        expect(
          globalState.androidPrivateDnsServerName,
          'second.private.example',
        );
        final updated = loadYaml(
          await File(await appPath.configFilePath).readAsString(),
        );
        expect(updated['dns']['nameserver'], [
          'tls://second.private.example:853#DIRECT',
        ]);
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  for (final warm in [false, true]) {
    testWidgets(
      'port collision checks preserve a live listener and cover cold start warm=$warm',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              navigatorKey: globalState.navigatorKey,
              home: Consumer(
                builder: (context, r, _) {
                  ref = r;
                  controller = _Controller(context, ref);
                  globalState.appController = controller;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        final fallbackState = ref.listenManual(
          mixedPortFallbackProvider,
          (_, _) {},
        );
        addTearDown(fallbackState.close);
        await tester.runAsync(() async {
          final listener = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          try {
            ref
                .read(patchClashConfigProvider.notifier)
                .updateState(
                  (config) => config.copyWith(mixedPort: listener.port),
                );
            if (warm) await controller.applyProfile(silence: true);
            globalState.startTime = DateTime.now().subtract(
              const Duration(seconds: 1),
            );
            ref
                .read(vpnSettingProvider.notifier)
                .updateState(
                  (settings) => settings.copyWith(portFallback: true),
                );
            await controller.applyProfile(silence: true);
            expect(core.appliedPort == listener.port, warm);
            if (warm) {
              expect(ref.read(mixedPortFallbackProvider), isNull);
            } else {
              expect(ref.read(mixedPortFallbackProvider), core.appliedPort);
            }
          } finally {
            await listener.close();
          }
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  for (final platform in ['android', 'windows', 'linux', 'macos']) {
    testWidgets('DNS override respects node resolver settings on $platform', (
      tester,
    ) async {
      System.platformOverride = platform;
      await tester.runAsync(() async {
        final file = await profiles.first.getFile();
        await file.writeAsString('''
dns:
  enable: true
  nameserver: [223.5.5.5]
  proxy-server-nameserver: [223.5.5.5, 119.29.29.29]
  fallback: [1.1.1.1]
  fallback-filter: {geosite: [gfw]}
''', mode: FileMode.append);
      });
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                controller = _Controller(context, ref);
                globalState.appController = controller;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final enabled in [false, true]) {
          globalState.config = globalState.config.copyWith(
            overrideDns: enabled,
          );
          await controller.applyProfile(silence: true);
          final output = loadYaml(
            await File(await appPath.configFilePath).readAsString(),
          );
          expect(
            output['dns']['proxy-server-nameserver'],
            enabled
                ? const Dns().proxyServerNameserver
                : ['223.5.5.5', '119.29.29.29'],
          );
          if (!enabled) {
            expect(output['dns']['fallback-filter']['geosite'], ['gfw']);
          }
        }
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'profile selection refreshes the scoped proxy page on $platform',
      (tester) async {
        System.platformOverride = platform;
        final container = await tester.runAsync(
          () async => ProviderContainer(),
        );
        addTearDown(container!.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: globalState.navigatorKey,
              home: ClashManager(
                child: Consumer(
                  builder: (context, r, _) {
                    globalState.measure = Measure.of(context, 1);
                    ref = r;
                    controller = _Controller(context, ref);
                    globalState.appController = controller;
                    return ProviderScope(
                      overrides: [queryProvider.overrideWith(() => Query())],
                      child: const ProxiesView(),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() => controller.applyProfile(silence: true));
        await tester.pumpAndSettle();
        expect(find.text('A-node'), findsWidgets);
        await tester.runAsync(() async {
          container.read(currentProfileIdProvider.notifier).value =
              profiles.last.id;
          container.read(needSetupProvider);
          expect(controller.lastChange, isNotNull);
          await controller.lastChange!.timeout(const Duration(seconds: 3));
        });
        await tester.pumpAndSettle();
        expect(core.node, 'B-node');
        expect(find.text('B-node'), findsWidgets);
        expect(find.text('A-node'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  testWidgets(
    'a slow profile remains pending and the latest selection is applied next',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var bound = false;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            home: ClashManager(
              child: Consumer(
                builder: (context, r, _) {
                  if (!bound) {
                    ref = r;
                    controller = _Controller(context, ref);
                    globalState.appController = controller;
                    bound = true;
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await controller.applyProfile(silence: true);
        core.pendingSetup = Completer<void>();
        await controller.selectProfile(profiles.last.id);
        container.read(needSetupProvider);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(container.read(pendingProfileIdProvider), profiles.last.id);
        expect(core.node, 'A-node');
        final nextSelection = controller.selectProfile(profiles.first.id);
        expect(container.read(pendingProfileIdProvider), profiles.first.id);
        core.pendingSetup!.complete();
        await controller.lastChange!.timeout(const Duration(seconds: 3));
        await nextSelection;
        container.read(needSetupProvider);
        await controller.lastChange!.timeout(const Duration(seconds: 3));
        expect(core.node, 'A-node');
        expect(container.read(groupsProvider).last.all.single.name, 'A-node');
        expect(container.read(pendingProfileIdProvider), isNull);
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('profile cards accept the latest choice while B is applying', (
    tester,
  ) async {
    const cards = Key('profile-cards');
    if (const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
      await (FontLoader('HarmonyOS_Sans')..addFont(
            rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
    globalState.config = globalState.config.copyWith(
      profiles: [...profiles, thirdProfile],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: globalState.navigatorKey,
          theme: ThemeData(fontFamily: 'HarmonyOS_Sans'),
          home: ClashManager(
            child: Consumer(
              builder: (context, r, _) {
                globalState.measure = Measure.of(context, 1);
                ref = r;
                controller = _Controller(context, ref);
                globalState.appController = controller;
                return ProviderScope(
                  overrides: [queryProvider.overrideWith(() => Query())],
                  child: const RepaintBoundary(
                    key: cards,
                    child: ProfilesView(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => controller.applyProfile(silence: true));
    await tester.pumpAndSettle();

    Future<void> capture(String state) async {
      if (const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
        await captureFlutterFrame(
          tester,
          find.byKey(cards),
          'build/core-x/delay-diagnostics/profile-selection-$state.png',
        );
      }
    }

    await capture('ready');
    core.releaseB = Completer<void>();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Key(profiles.last.id)).last);
      await core.startedB.future.timeout(const Duration(seconds: 3));
    });
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(Key(profiles.first.id)).last);
      await tester.tap(find.byKey(Key(thirdProfile.id)).last);
    });
    await tester.pump();
    expect(ref.read(currentProfileIdProvider), profiles.last.id);
    expect(ref.read(pendingProfileIdProvider), thirdProfile.id);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CircularProgressIndicator &&
            widget.semanticsLabel == 'Configuration queued',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 240));
    await capture('pending');
    await tester.runAsync(() async {
      final applied = Completer<void>();
      final listener = ref.listenManual(groupsProvider, (_, groups) {
        if (!applied.isCompleted &&
            groups.any((group) => group.now == 'C-node')) {
          applied.complete();
        }
      });
      try {
        core.releaseB!.complete();
        await applied.future.timeout(const Duration(seconds: 3));
        await controller.lastChange;
      } finally {
        listener.close();
      }
    });
    await tester.pumpAndSettle();
    expect(ref.read(currentProfileIdProvider), thirdProfile.id);
    expect(ref.read(pendingProfileIdProvider), isNull);
    expect(core.setups, ['A-node', 'B-node', 'C-node']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'automatic groups reflect native locks and release without reasserting stale choices',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                controller = _Controller(context, ref);
                globalState.appController = controller;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await controller.applyProfile(silence: true);
        for (final type in ['URLTest', 'Fallback']) {
          core.groupType = type;
          core.nativeLock = core.node;
          await controller.updateGroups();
          expect(ref.read(selectedMapProvider)['Select'], core.node);
          core.nativeLock = '';
          await controller.updateGroups();
          expect(ref.read(selectedMapProvider).containsKey('Select'), isFalse);
        }
        expect(core.changes, isEmpty);
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );
  testWidgets(
    'switch publishes B nodes even when old DNS flush never answers',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                controller = _Controller(context, ref);
                globalState.appController = controller;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await controller.applyProfile(silence: true);
        expect(ref.read(groupsProvider).last.all.single.name, 'A-node');
        const measured = Delay(
          url: 'https://example.invalid/delay',
          name: 'A-node',
          value: 65,
        );
        controller.setDelay(measured);
        controller.setDelay(measured.copyWith(name: 'removed-node'));
        await controller.applyProfile(silence: true);
        controller.setDelay(measured.copyWith(value: -1), background: true);
        expect(ref.read(delayDataSourceProvider)[measured.url], {'A-node': 65});

        ref.read(currentProfileIdProvider.notifier).value = profiles.last.id;
        final change = controller.handleChangeProfile(
          previousProfileId: profiles.first.id,
        );
        await change.timeout(const Duration(seconds: 3));
        expect(ref.read(groupsProvider).last.all.single.name, 'B-node');
        expect(ref.read(delayDataSourceProvider)[measured.url], isNull);
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );
  testWidgets(
    'a rejected subscription restores A and B can be retried without restarting',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                controller = _Controller(context, ref);
                globalState.appController = controller;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await controller.applyProfile(silence: true);
        core.rejectB = true;
        ref.read(currentProfileIdProvider.notifier).value = profiles.last.id;
        await controller.handleChangeProfile(
          previousProfileId: profiles.first.id,
        );
        expect(ref.read(currentProfileIdProvider), profiles.first.id);
        expect(ref.read(groupsProvider).last.all.single.name, 'A-node');
        core.rejectB = false;
        ref.read(currentProfileIdProvider.notifier).value = profiles.last.id;
        await controller.handleChangeProfile(
          previousProfileId: profiles.first.id,
        );
        expect(ref.read(groupsProvider).last.all.single.name, 'B-node');
      });
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'transient empty group reads after switching do not leave A forever',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            home: Consumer(
              builder: (context, r, _) {
                ref = r;
                controller = _Controller(context, ref);
                globalState.appController = controller;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await controller.applyProfile(silence: true);
        core.emptyReads = 4;
        ref.read(currentProfileIdProvider.notifier).value = profiles.last.id;
        await controller.handleChangeProfile(
          previousProfileId: profiles.first.id,
        );
        expect(ref.read(groupsProvider).last.all.single.name, 'A-node');
        await Future<void>.delayed(const Duration(milliseconds: 4200));
        expect(ref.read(groupsProvider).last.all.single.name, 'B-node');
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('DNS override applies without entering profile restart', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ClashManager(
            child: Consumer(
              builder: (context, ref, _) {
                controller = _Controller(context, ref);
                globalState.appController = controller;
                return const Scaffold(body: OverrideItem());
              },
            ),
          ),
        ),
      ),
    );
    final toggle = find.byType(Switch);
    final before = tester.widget<Switch>(toggle).value;
    await tester.runAsync(() async {
      await tester.tap(toggle);
      container.read(needSetupProvider);
      await controller.lastApply!.timeout(const Duration(seconds: 3));
    });
    await tester.pump();
    expect(tester.widget<Switch>(toggle).value, !before);
    expect(controller.lastChange, isNull);
    expect(container.read(isRestartingCoreProvider), isFalse);
    expect(core.setups, ['A-node']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'profile selection through the live manager refreshes the scoped proxy page',
    (tester) async {
      final container = await tester.runAsync(() async => ProviderContainer());
      addTearDown(container!.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            home: ClashManager(
              child: Consumer(
                builder: (context, r, _) {
                  globalState.measure = Measure.of(context, 1);
                  ref = r;
                  controller = _Controller(context, ref);
                  globalState.appController = controller;
                  return ProviderScope(
                    overrides: [queryProvider.overrideWith(() => Query())],
                    child: const ProxiesView(),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => controller.applyProfile(silence: true));
      await tester.pumpAndSettle();
      expect(find.text('A-node'), findsWidgets);
      await tester.runAsync(() async {
        container.read(currentProfileIdProvider.notifier).value =
            profiles.last.id;
        container.read(needSetupProvider);
        expect(controller.lastChange, isNotNull);
        await controller.lastChange!.timeout(const Duration(seconds: 3));
      });
      await tester.pumpAndSettle();
      expect(core.node, 'B-node');
      expect(find.text('B-node'), findsWidgets);
      expect(find.text('A-node'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );
}
