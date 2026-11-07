import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/core.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Paths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
  @override
  Future<String?> getDownloadsPath() async => Directory.systemTemp.path;
}

class _Core extends Fake implements ClashHandlerInterface {
  String node = 'A-node';
  bool rejectB = false;
  int emptyReads = 0;
  final flush = Completer<bool>();
  @override
  Future<bool> forceGc({bool forceFreeOSMemory = false}) async => true;
  @override
  Future<bool> closeConnections() async => true;
  @override
  Future<bool> flushDnsCache() => flush.future;
  @override
  Future<Result> getConfig(String path, {String? ageSecretKey}) async {
    final config = Map<String, dynamic>.from(
      loadYaml(await File(path).readAsString()),
    );
    config['rule'] = config.remove('rules');
    return Result.success(config);
  }

  @override
  Future<String> setupConfig(SetupParams params) async {
    final config = loadYaml(
      await File(await appPath.configFilePath).readAsString(),
    );
    final name = (config['proxies'] as List).first['name'] as String;
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
        'type': 'Selector',
        'now': node,
        'all': [node],
      },
      node: {'name': node, 'type': 'Shadowsocks'},
    };
  }
}

class _Controller extends AppController {
  _Controller(super.context, super.ref);
  @override
  void addCheckIpNumDebounce() {}
  @override
  void scheduleIdleGc({Duration delay = const Duration(seconds: 2)}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Core core;
  late ClashHandlerInterface original;
  late WidgetRef ref;
  late AppController controller;
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
    for (final profile in profiles) {
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
  });

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
        ref.read(currentProfileIdProvider.notifier).value = profiles.last.id;
        final change = controller.handleChangeProfile(
          previousProfileId: profiles.first.id,
        );
        await change.timeout(const Duration(seconds: 3));
        expect(ref.read(groupsProvider).last.all.single.name, 'B-node');
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
}
