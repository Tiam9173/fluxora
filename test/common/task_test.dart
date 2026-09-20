import 'dart:io';

import 'package:bett_box/common/task.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('YAML encoder', () {
    test('serializes sniffer config without toString fallback', () async {
      const sniffer = Sniffer();
      final map = <String, dynamic>{
        'sniffer': sniffer.toJson(),
      };

      final yaml = await encodeYamlTask(map);

      expect(yaml, isNot(contains('SnifferConfig')));
      expect(yaml, contains('HTTP:'));
      expect(yaml, contains('ports:'));
      expect(yaml, contains('- "80"'));

      final dynamic parsed = loadYaml(yaml);
      expect(parsed['sniffer']['sniff']['HTTP']['ports'], contains('80'));
    });

    test('serializes fallback-filter without toString fallback', () async {
      const dns = Dns();
      final map = <String, dynamic>{
        'dns': dns.toJson(),
      };

      final yaml = await encodeYamlTask(map);

      expect(yaml, isNot(contains('FallbackFilter')));
      expect(yaml, contains('fallback-filter:'));
      expect(yaml, contains('geoip-code: CN'));

      final dynamic parsed = loadYaml(yaml);
      expect(parsed['dns']['fallback-filter']['geoip-code'], 'CN');
    });

    test('handles LITES.yaml patch without errors', () async {
      final litesFile = File(r'D:\Bettbox\LITES.yaml');
      if (!await litesFile.exists()) return;

      final content = await litesFile.readAsString();
      final normalized =
          content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final dynamic raw = loadYaml(normalized);

      dynamic deepConvert(dynamic value) {
        if (value is YamlMap || value is Map) {
          return (value as Map).map(
            (k, v) => MapEntry(k.toString(), deepConvert(v)),
          );
        }
        if (value is YamlList || value is List) {
          return (value as Iterable).map(deepConvert).toList();
        }
        return value;
      }

      final map = deepConvert(raw) as Map<String, dynamic>;
      const sniffer = Sniffer();
      map['sniffer'] = sniffer.toJson();
      const dns = Dns();
      map['dns'] = dns.toJson();

      final yaml = await encodeYamlTask(map);

      expect(yaml, isNot(contains('SnifferConfig')));
      expect(yaml, isNot(contains('FallbackFilter')));

      final dynamic reparsed = loadYaml(yaml);
      expect(reparsed['sniffer']['sniff']['HTTP'], isNotNull);
    });

    test('escapes control characters and non-printable bytes', () async {
      final map = <String, dynamic>{
        'simple': 'normal text',
        'with-esc': 'Hong Kong \x1b[31mNode\x1b[0m',
        'with-null': 'pass\x00word',
        'with-bell': 'alert\x07sound',
        'with-del': 'delete\x7fchar',
        'with-c1': 'c1\x80code\x9fend',
        'with-emoji': 'US 🇺🇸 Fast 🚀',
      };

      final yaml = await encodeYamlTask(map);

      for (final rawByte in [
        0x00,
        0x07,
        0x08,
        0x0B,
        0x0C,
        0x1B,
        0x7F,
        0x80,
        0x9F,
      ]) {
        expect(yaml.contains(String.fromCharCode(rawByte)), isFalse);
      }

      expect(yaml, contains(r'\e'));
      expect(yaml, contains(r'\0'));
      expect(yaml, contains(r'\a'));
      expect(yaml, contains(r'\x7f'));
      expect(yaml, contains(r'\u0080'));
      expect(yaml, contains(r'\u009f'));
      expect(yaml, contains('🇺🇸'));
      expect(yaml, contains('🚀'));

      final dynamic parsed = loadYaml(yaml);
      expect(parsed['simple'], 'normal text');
      expect(parsed['with-emoji'], 'US 🇺🇸 Fast 🚀');
    });
  });
}
