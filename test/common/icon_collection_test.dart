import 'dart:convert';
import 'dart:io';

import 'package:fluxora/common/icon_collection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const manifest = '''
{"name":"Test set","description":"local test","icons":[
 {"name":"Tokyo.svg","url":"https://icons.example/tokyo.svg"},
 {"name":"Duplicate","url":"https://icons.example/tokyo.svg"}
]}
''';

  test('parses Qure format, removes duplicate URLs and keeps attribution', () {
    final collection = IconCollection.parse(
      manifest,
      source: IconCollection.qureSource,
    );
    expect(collection.name, 'Test set');
    expect(collection.description, 'local test');
    expect(collection.source, IconCollection.qureSource);
    expect(collection.icons, hasLength(1));
    expect(collection.icons.single.label, 'Tokyo');
  });

  test(
    'rejects unsupported URLs, userinfo, malformed entries and large input',
    () {
      for (final url in [
        'file:///etc/passwd',
        'https://user:secret@icons.example/a.svg',
        'javascript:alert(1)',
      ]) {
        final content = jsonEncode({
          'name': 'bad',
          'icons': [
            {'name': 'x', 'url': url},
          ],
        });
        expect(() => IconCollection.parse(content), throwsFormatException);
      }
      expect(
        () => IconCollection.parse('x' * (IconCollection.maxBytes + 1)),
        throwsFormatException,
      );
      expect(
        () => IconCollection.parse('{"name":"bad","icons":[{}]}'),
        throwsFormatException,
      );
    },
  );

  test('collection store round trips and removes deleted sets', () async {
    final root = await Directory.systemTemp.createTemp('fluxora-icons-');
    addTearDown(() => root.delete(recursive: true));
    final store = IconCollectionStore(directory: root);
    final first = IconCollection.parse(manifest);
    final second = IconCollection.parse(
      manifest.replaceAll('Test set', 'Second'),
    );
    await store.save([first, second]);
    expect((await store.load()).map((set) => set.name), ['Test set', 'Second']);
    await store.save([second]);
    expect((await store.load()).map((set) => set.name), ['Second']);
    await expectLater(
      store.save(
        List.generate(
          IconCollectionStore.maxCollections + 1,
          (index) => IconCollection(name: 'Set $index', icons: first.icons),
        ),
      ),
      throwsFormatException,
    );
    await expectLater(store.save([second, second]), throwsFormatException);
  });

  test(
    'bundled Qure manifest is parseable and remains lazy metadata',
    () async {
      final content = await File(
        'assets/data/qure_icon_set.json',
      ).readAsString();
      final collection = IconCollection.parse(
        content,
        source: IconCollection.qureSource,
      );
      expect(collection.name, 'Qure-Style-SVG');
      expect(collection.icons, hasLength(2370));
      expect(
        collection.icons.every((icon) => icon.url.startsWith('https://')),
        isTrue,
      );
    },
  );

  test('exact group rule wins before broad rules and can be removed', () {
    final rules = setGroupIcon(
      const {'(?i)Japan': 'broad.svg', 'literal': 'other.svg'},
      'Japan (01)*',
      'selected.svg',
    );
    expect(rules.keys.first, r'^Japan \(01\)\*$');
    expect(rules.values.first, 'selected.svg');
    expect(rules['(?i)Japan'], 'broad.svg');
    expect(setGroupIcon(rules, 'Japan (01)*', ''), {
      '(?i)Japan': 'broad.svg',
      'literal': 'other.svg',
    });
  });
}
