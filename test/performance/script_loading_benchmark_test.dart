// Run explicitly with --dart-define=SCRIPT_LOADING_BENCH=true.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:code_forge/code_forge.dart' as script;
// ignore: depend_on_referenced_packages
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/js_runtime_manager.dart';

void main() {
  test(
    'script input serialization and actual native evaluation',
    () async {
      final dll = const String.fromEnvironment('SCRIPT_DLL');
      await script.RustLib.init(externalLibrary: ExternalLibrary.open(dll));
      final rows = <Map<String, Object>>[];
      for (final count in [20, 1000, 10000]) {
        final config = <String, dynamic>{
          'proxies': [
            for (var i = 0; i < count; i++)
              {
                'name': '节点 $i',
                'type': 'ss',
                'server': 'node$i.invalid',
                'port': 443,
                'cipher': 'aes-128-gcm',
                'password': 'fixture',
              },
          ],
          'rules': [
            for (var i = 0; i < count * 10; i++)
              'DOMAIN-SUFFIX,example$i.invalid,DIRECT',
          ],
        };
        for (final offload in [false, true, true, false]) {
          var longestGap = 0;
          var previous = DateTime.now();
          final ticker = Timer.periodic(const Duration(milliseconds: 1), (_) {
            final now = DateTime.now();
            final gap = now.difference(previous).inMicroseconds;
            if (gap > longestGap) longestGap = gap;
            previous = now;
          });
          await Future<void>.delayed(const Duration(milliseconds: 5));
          final elapsed = Stopwatch()..start();
          for (var i = 0; i < 12; i++) {
            final output = offload
                ? await compute(jsonEncode, config)
                : jsonEncode(config);
            expect(output, isNotEmpty);
            await Future<void>.delayed(Duration.zero);
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
          ticker.cancel();
          rows.add({
            'nodes': count,
            'offload': offload,
            'encode_us': elapsed.elapsedMicroseconds / 12,
            'longest_ui_gap_us': longestGap,
          });
        }
        final timer = Stopwatch()..start();
        for (var i = 0; i < 3; i++) {
          final result = await JavaScriptRuntimeManager.evaluateScript(
            'async function main(c, o) { c.marker = o.enabled; c["proxy-groups"] = [{name:"Select",type:"select",proxies:c.proxies.map(p=>p.name)}]; return c; }',
            config,
            customOptions: {'enabled': true},
          );
          expect(result['marker'], true);
          expect((result['proxies'] as List).length, count);
          expect((result['rules'] as List).length, count * 10);
        }
        rows.add({
          'nodes': count,
          'native_complete_us': timer.elapsedMicroseconds / 3,
        });
      }
      final output = File('build/script-loading/codec-results.json');
      await output.parent.create(recursive: true);
      await output.writeAsString(
        const JsonEncoder.withIndent('  ').convert(rows),
      );
      // ignore: avoid_print
      print(jsonEncode(rows));
    },
    skip: !const bool.fromEnvironment('SCRIPT_LOADING_BENCH'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
