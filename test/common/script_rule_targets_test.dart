import 'dart:io';
import 'package:code_forge/code_forge.dart' show RustLib;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;
import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/enum/enum.dart';
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

class _SubscriptionCore extends Fake implements ClashHandlerInterface {
  @override
  Future<Result> getConfig(String path, {String? ageSecretKey}) async =>
      Result.success(<String, dynamic>{
        'proxy-groups': [
          <String, dynamic>{
            'name': 'Raw subscription',
            'type': 'select',
            'proxies': ['DIRECT'],
          },
        ],
        'rule': ['MATCH,Raw subscription'],
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = File(
    'build/windows/x64/plugins/code_forge/cargokit_build/x86_64-pc-windows-msvc/release/code_forge.dll',
  );
  final available = library.existsSync();
  late ClashHandlerInterface previousCore;
  late Config previousConfig;

  setUpAll(() async {
    PathProviderPlatform.instance = _Paths();
    if (available) {
      await RustLib.init(
        externalLibrary: ExternalLibrary.open(library.absolute.path),
      );
    }
  });
  setUp(() {
    previousCore = clashCore.clashInterface;
    previousConfig = globalState.config;
    clashCore.clashInterface = _SubscriptionCore();
    globalState.config = const Config(
      themeProps: ThemeProps(),
      currentProfileId: 'script-rules',
      profiles: [
        Profile(
          id: 'script-rules',
          label: 'Fixture',
          autoUpdateDuration: Duration(days: 1),
          useScriptOverride: true,
        ),
      ],
      scriptProps: ScriptProps(
        currentId: 'transform',
        scripts: [
          Script(
            id: 'transform',
            label: 'Transform',
            content: '''function main(config) {
          config['proxy-groups'] = [{name:'Script route',type:'select',proxies:['DIRECT']}];
          config.rules = ['MATCH,Script route'];
          return config;
        }''',
          ),
        ],
      ),
    );
  });
  tearDown(() {
    clashCore.clashInterface = previousCore;
    globalState.config = previousConfig;
  });

  test(
    'rule editor gets script-generated targets without replacing editable subscription rules',
    () async {
      final snippet = await globalState.getProfileRuleSnippet('script-rules');
      expect(snippet.proxyGroups.map((g) => g.name), ['Script route']);
      expect(snippet.rule.single.value, 'MATCH,Raw subscription');
    },
    skip: available ? false : 'Native script library unavailable',
  );

  test('disabling script restores subscription targets', () async {
    globalState.config = globalState.config.copyWith(
      profiles: [
        globalState.config.profiles.single.copyWith(useScriptOverride: false),
      ],
    );
    final snippet = await globalState.getProfileRuleSnippet('script-rules');
    expect(snippet.proxyGroups.single.name, 'Raw subscription');
    expect(snippet.rule.single.value, 'MATCH,Raw subscription');
  });

  test(
    'applied aggregate targets are reused instead of evaluating the script again',
    () async {
      final snippet = await globalState.getProfileRuleSnippet(
        'script-rules',
        appliedGroups: [
          const Group(type: GroupType.URLTest, name: 'Applied aggregate route'),
        ],
      );
      expect(snippet.proxyGroups.single.name, 'Applied aggregate route');
      expect(snippet.rule.single.value, 'MATCH,Raw subscription');
    },
  );
}
