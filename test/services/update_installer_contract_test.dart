import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'desktop updates hand verified packages to the native system opener',
    () {
      final source = File(
        'lib/views/about/update_install_dialog.dart',
      ).readAsStringSync();

      expect(source, contains('system.isMacOS || system.isLinux'));
      expect(source, contains("system.isMacOS ? 'open' : 'xdg-open'"));
      expect(source, contains("Process.run('chmod', ['u+x', installer.path])"));
      expect(source, contains('windows?.runas(installer.path'));
      expect(source, contains('app.installApk(installer.path)'));
    },
  );
}
