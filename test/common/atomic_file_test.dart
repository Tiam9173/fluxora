import 'dart:io';

import 'package:fluxora/common/atomic_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('replaces an existing config without leaving staging files', () async {
    final root = await Directory.systemTemp.createTemp('fluxora-atomic-');
    addTearDown(() => root.delete(recursive: true));
    final target = File(p.join(root.path, 'profiles', 'active.yaml'));
    await target.parent.create(recursive: true);
    await target.writeAsString('old: complete\n');

    await writeTextAtomically(target, 'new: complete\n');

    expect(await target.readAsString(), 'new: complete\n');
    expect(
      await target.parent
          .list()
          .where(
            (entry) => p.basename(entry.path).startsWith('.fluxora-write-'),
          )
          .toList(),
      isEmpty,
    );
  });

  test('failed replacement preserves the previous file', () async {
    final root = await Directory.systemTemp.createTemp('fluxora-atomic-');
    addTearDown(() => root.delete(recursive: true));
    final target = File(p.join(root.path, 'profiles', 'blocked.yaml'));
    await target.parent.create(recursive: true);
    await target.writeAsString('last-good: true\n');

    await expectLater(
      writeTextAtomically(File(target.parent.path), 'replacement: true\n'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await target.readAsString(), 'last-good: true\n');
  });
}
