import 'dart:convert';
import 'dart:io';
import 'package:code_forge/code_forge.dart' show RustLib;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;
import 'package:fluxora/common/js_runtime_manager.dart';
import 'package:fluxora/common/provider_script.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const dll = String.fromEnvironment('SCRIPT_DLL');
  const reference = String.fromEnvironment('PROVIDER_SCRIPT_REFERENCE');
  const referenceConfig = String.fromEnvironment('PROVIDER_CONFIG_REFERENCE');
  final available = dll.isNotEmpty && File(dll).existsSync();
  setUpAll(() async {
    if (available) {
      await RustLib.init(externalLibrary: ExternalLibrary.open(dll));
    }
  });
  final nodes = [
    {
      'name': '香港 HK 01',
      'type': 'trojan',
      'server': 'tls.example.test',
      'port': 443,
      'password': 'fixture',
      'sni': 'tls.example.test',
      'skip-cert-verify': false,
    },
    {
      'name': '新加坡 SG 02',
      'type': 'ss',
      'server': 'ss.example.test',
      'port': 443,
      'cipher': 'aes-128-gcm',
      'password': 'fixture',
    },
  ];
  test(
    'native runtime receives provider nodes without altering source',
    () async {
      final config = <String, dynamic>{
        'proxy-providers': {
          'fixture': {'type': 'inline', 'payload': nodes},
        },
      };
      const script = '''function main(config) {
      if (!config.proxies || !config.proxies.length) throw new Error('no proxy nodes');
      return {proxies:config.proxies, 'proxy-groups':[{name:'PROXY',type:'select',proxies:config.proxies.map(p=>p.name)}]};
    }''';
      final output = await evaluateProviderScript(
        config,
        (input) => JavaScriptRuntimeManager.evaluateScript(script, input),
        (_) async => nodes,
      );
      expect(output['proxies'], hasLength(2));
      expect((output['proxies'] as List).first['sni'], 'tls.example.test');
      expect(config.containsKey('proxies'), false);
    },
    skip: !available,
  );

  test(
    'user reference script supports provider-only subscription structure',
    () async {
      final config =
          jsonDecode(await File(referenceConfig).readAsString())
              as Map<String, dynamic>;
      final script = await File(reference).readAsString();
      final output = await evaluateProviderScript(
        config,
        (input) => JavaScriptRuntimeManager.evaluateScript(script, input),
        (_) async => nodes,
      );
      final proxies = output['proxies'] as List;
      expect(proxies.where((p) => p['type'] != 'direct'), hasLength(2));
      expect(proxies.where((p) => p['type'] == 'direct'), hasLength(5));
      final groups = output['proxy-groups'] as List;
      final valid = {
        'DIRECT',
        'REJECT',
        'REJECT-DROP',
        'PASS',
        'COMPATIBLE',
        ...proxies.map((p) => p['name']),
        ...groups.map((g) => g['name']),
      };
      for (final group in groups) {
        for (final member in group['proxies'] as List? ?? []) {
          expect(
            valid.contains(member),
            true,
            reason: 'group ${group['name']} refers to missing node $member',
          );
        }
      }
      expect(proxies.first['server'], 'tls.example.test');
      expect(proxies.first['sni'], 'tls.example.test');
      expect(proxies.first['skip-cert-verify'], isNot(true));
    },
    skip: !available || reference.isEmpty || referenceConfig.isEmpty,
  );
}
