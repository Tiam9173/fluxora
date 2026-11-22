import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/controller.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/manager/profile_chain_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/services/atomic_config_storage.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/backup_and_recovery.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
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

class _BackupPicker extends FilePicker {
  _BackupPicker(this.path);
  final String path;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      FilePickerResult([PlatformFile(name: 'backup.zip', size: 0, path: path)]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const script = Script(
    id: 'backup-script',
    label: '分流覆写',
    customOptions: {'filter': true},
  );
  const body = '// 路由\nfunction main(config) { return config; }';
  const chain = ChainProxyConfig(
    enable: true,
    dedicatedGroupName: 'My chain',
    frontHops: ['entry', 'relay'],
    hop2Node: 'exit',
    preventDnsLeak: false,
    landingProxies: [
      LandingProxy(
        id: 'exit-id',
        name: 'exit',
        server: 'exit.example.invalid',
        port: 1080,
        username: 'fixture-user',
        password: 'fixture-password',
      ),
    ],
  );
  const profileChain = ProfileChainConfig(
    profileId: 'subscription',
    preProxy: 'entry',
    landingProxy: 'exit',
  );
  late Directory sandbox;
  late Directory source;
  late Directory target;
  late AppController controller;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
    if (const bool.fromEnvironment('UI_REFINEMENT_CAPTURE')) {
      await (FontLoader('HarmonyOS_Sans')..addFont(
            rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  void useHome(Directory home) {
    appPath.dataDir = Completer<Directory>()..complete(home);
  }

  setUp(() async {
    PathProviderPlatform.instance = _Paths();
    SharedPreferences.setMockInitialValues({});
    await preferences.sharedPreferencesCompleter.future;
    await appPath.dataDir.future;
    sandbox = await Directory.systemTemp.createTemp('fluxora_backup_test_');
    source = await Directory(p.join(sandbox.path, 'source')).create();
    target = await Directory(p.join(sandbox.path, 'target')).create();
    useHome(source);
    System.platformOverride = 'android';
    globalState.config = const Config(themeProps: ThemeProps());
    await chainProxyManager.restoreBackupConfig(chain);
    await profileChainManager.restoreBackupConfig({
      'subscription': profileChain,
    }, merge: false);
  });

  tearDown(() async {
    System.platformOverride = null;
    await sandbox.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            controller = AppController(context, ref);
            return const SizedBox();
          },
        ),
      ),
    );
  }

  testWidgets('Android backup restores scripts and both chains on Windows', (
    tester,
  ) async {
    await mount(tester);
    await tester.runAsync(() async {
      final saved = await script.writeContent(body);
      const profile = Profile(
        id: 'subscription',
        autoUpdateDuration: Duration(days: 1),
      );
      const yaml = 'proxies: []\nrules: ["MATCH,DIRECT"]\n';
      await (await profile.getFile()).writeAsString(yaml);
      globalState.config = globalState.config.copyWith(
        profiles: [profile],
        currentProfileId: profile.id,
        scriptProps: ScriptProps(currentId: saved.id, scripts: [saved]),
      );
      final archive = await controller.backupData();
      expect(globalState.config.scriptProps.currentScript!.content, isEmpty);
      final zip = await File(
        p.join(sandbox.path, 'backup.zip'),
      ).writeAsBytes(archive);
      useHome(target);
      System.platformOverride = 'windows';
      globalState.config = const Config(themeProps: ThemeProps());
      await chainProxyManager.restoreBackupConfig(const ChainProxyConfig());
      await profileChainManager.restoreBackupConfig({}, merge: false);

      expect(
        await controller.recoveryDataFromFile(
          zip.path,
          RecoveryOption.onlyProfiles,
        ),
        isEmpty,
      );
      expect(await (await profile.getFile()).readAsString(), yaml);
      expect(await script.readContent(), isEmpty);
      expect(chainProxyManager.config.enable, isFalse);
      expect(profileChainManager.getChain(profile.id).hasActiveChains, isFalse);
      await profileChainManager.updateChain(
        'local',
        (chain) => chain.copyWith(preProxy: 'local-entry'),
        reloadCore: false,
      );
      expect(
        await controller.recoveryDataFromFile(zip.path, RecoveryOption.all),
        isEmpty,
      );
      final restored =
          (await preferences.getConfig())!.scriptProps.currentScript!;
      expect(restored.id, saved.id);
      expect(restored.customOptions, saved.customOptions);
      expect(restored.content, isEmpty);
      expect(await restored.readContent(), body);
      expect(chainProxyManager.config.toJson(), chain.toJson());
      expect(
        profileChainManager.getChain('subscription').toJson(),
        profileChain.toJson(),
      );
      final disk = await AtomicConfigStorage(
        p.join(target.path, 'chain_proxies.json'),
      ).load();
      expect(ChainProxyConfig.fromJson(disk).toJson(), chain.toJson());
      final profileDisk = await AtomicConfigStorage(
        p.join(target.path, 'profile_chains.json'),
      ).load();
      expect(profileDisk?['subscription'], profileChain.toJson());
      expect(profileChainManager.getChain('local').preProxy, 'local-entry');
    });
  });

  testWidgets('compatible recovery reuses a matching subscription identity', (
    tester,
  ) async {
    await mount(tester);
    await tester.runAsync(() async {
      globalState.appState = AppState(
        viewSize: const Size(800, 600),
        brightness: Brightness.light,
        requests: FixedList(0),
        logs: FixedList(0),
        traffics: FixedList(0),
        version: 1,
        totalTraffic: Traffic(),
        systemUiOverlayStyle: const SystemUiOverlayStyle(),
      );
      const backupProfile = Profile(
        id: 'backup-profile',
        label: 'Backup label',
        url: 'https://example.test/sub?token=a#backup',
        autoUpdateDuration: Duration(days: 1),
      );
      const localProfile = Profile(
        id: 'local-profile',
        label: 'Local label',
        url: 'HTTPS://EXAMPLE.TEST/sub?token=a#local',
        autoUpdateDuration: Duration(days: 1),
      );
      const backupYaml = 'proxies: []\nrules: ["MATCH,PROXY"]\n';
      await (await backupProfile.getFile()).writeAsString(backupYaml);
      globalState.config = globalState.config.copyWith(
        profiles: [backupProfile],
        currentProfileId: backupProfile.id,
      );
      final backupChain = const ProfileChainConfig(
        profileId: 'backup-profile',
        preProxy: 'backup-entry',
      );
      await profileChainManager.restoreBackupConfig({
        backupProfile.id: backupChain,
      }, merge: false);
      final bytes = await controller.backupData();

      useHome(target);
      System.platformOverride = 'windows';
      globalState.config = globalState.config.copyWith(
        profiles: [localProfile],
        currentProfileId: 'keep-current',
      );
      await profileChainManager.restoreBackupConfig({
        localProfile.id: ProfileChainConfig(
          profileId: localProfile.id,
          preProxy: 'local-entry',
        ),
      }, merge: false);

      await controller.recoveryData(bytes, RecoveryOption.all);

      expect(globalState.config.profiles.single.id, localProfile.id);
      expect(globalState.config.profiles.single.label, localProfile.label);
      expect(globalState.config.currentProfileId, localProfile.id);
      expect(
        await File(
          p.join(target.path, 'profiles', 'local-profile.yaml'),
        ).readAsString(),
        backupYaml,
      );
      expect(
        await File(
          p.join(target.path, 'profiles', 'backup-profile.yaml'),
        ).exists(),
        isFalse,
      );
      expect(
        profileChainManager.getChain(localProfile.id).preProxy,
        'backup-entry',
      );
    });
  });

  testWidgets(
    'old marked backups report missing bodies and keep local chains',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        final missing = script.copyWith(digest: body.toMd5());
        final local = await Script.create(
          label: 'Local script',
        ).writeContent(body);
        globalState.config = globalState.config.copyWith(
          scriptProps: ScriptProps(currentId: local.id, scripts: [local]),
        );
        final backup = globalState.config.copyWith(
          scriptProps: ScriptProps(
            currentId: missing.id,
            scripts: [missing, local],
          ),
        );
        final bytes = utf8.encode(jsonEncode(backup));
        final zip = Archive()
          ..addFile(ArchiveFile('.fluxora_marker', 2, [123, 125]))
          ..addFile(ArchiveFile('config.json', bytes.length, bytes));
        final oldBackup = ZipEncoder().encode(zip);

        expect(
          await controller.recoveryData(oldBackup, RecoveryOption.onlyProfiles),
          isEmpty,
        );
        expect(globalState.config.scriptProps.currentScript?.id, local.id);
        expect(await controller.recoveryData(oldBackup, RecoveryOption.all), [
          missing.label,
        ]);
        expect(globalState.config.scriptProps.currentId, isNull);
        expect(globalState.config.scriptProps.scripts.single.id, local.id);
        expect(chainProxyManager.config.toJson(), chain.toJson());
        expect(
          profileChainManager.getChain('subscription').toJson(),
          profileChain.toJson(),
        );
      });
    },
  );

  testWidgets('local recovery dialog reports a missing script body', (
    tester,
  ) async {
    const screen = Key('backup-screen');
    globalState.appState = AppState(
      viewSize: const Size(400, 700),
      brightness: Brightness.light,
      requests: FixedList(0),
      logs: FixedList(0),
      traffics: FixedList(0),
      version: 1,
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    final config = globalState.config.copyWith(
      scriptProps: const ScriptProps(
        currentId: 'backup-script',
        scripts: [script],
      ),
    );
    final file = File(p.join(sandbox.path, 'old.zip'));
    await tester.runAsync(() async {
      final bytes = utf8.encode(jsonEncode(config));
      final zip = Archive()
        ..addFile(ArchiveFile('.fluxora_marker', 2, [123, 125]))
        ..addFile(ArchiveFile('config.json', bytes.length, bytes));
      await file.writeAsBytes(ZipEncoder().encode(zip));
    });
    FilePicker.platform = _BackupPicker(file.path);
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(
          key: screen,
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            theme: ThemeData(fontFamily: 'HarmonyOS_Sans'),
            home: Consumer(
              builder: (context, ref, _) {
                globalState.theme = CommonTheme.of(context, 1);
                globalState.measure = Measure.of(context, 1);
                globalState.appController = AppController(context, ref);
                return const Scaffold(body: BackupAndRecovery());
              },
            ),
          ),
        ),
      ),
    );
    final capture = const bool.fromEnvironment('UI_REFINEMENT_CAPTURE');
    final recovery = find.text(appLocalizations.localRecoveryDesc);
    await tester.ensureVisible(recovery);
    await tester.pumpAndSettle();
    if (capture) {
      await captureFlutterFrame(
        tester,
        find.byKey(screen),
        'build/core-x/delay-diagnostics/backup-screen.png',
      );
    }
    await tester.tap(recovery);
    await tester.pumpAndSettle();
    await tester.tap(find.text(appLocalizations.recoveryAll));
    final warning = find.textContaining('Their contents are missing');
    for (var i = 0; i < 80 && warning.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
    }
    await tester.pumpAndSettle();
    expect(warning, findsOneWidget);
    expect(find.textContaining(script.label), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (capture) {
      await captureFlutterFrame(
        tester,
        find.byKey(screen),
        'build/core-x/delay-diagnostics/backup-missing-script.png',
      );
    }
  });
}
