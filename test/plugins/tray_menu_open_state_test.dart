import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/src/tray_manager.dart';

void main() {
  test('keeps root menu open while a submenu closes', () {
    final state = TrayMenuOpenState();

    state.open();
    state.open();
    state.close();

    expect(state.isOpen, isTrue);
    expect(state.depth, 1);

    state.close();
    expect(state.isOpen, isFalse);
    expect(state.depth, 0);
  });

  test('does not underflow on an unmatched close event', () {
    final state = TrayMenuOpenState();

    state.close();

    expect(state.isOpen, isFalse);
    expect(state.depth, 0);
  });

  test(
    'quick node switching stays in the tray and does not show the window',
    () {
      final tray = File('lib/common/tray.dart').readAsStringSync();
      final manager = File('lib/manager/tray_manager.dart').readAsStringSync();

      expect(tray, contains('appLocalizations.quickSwitch'));
      expect(tray, contains('MenuItem.submenu'));
      expect(manager, contains('popUpContextMenu(bringAppToFront: false)'));
    },
  );
}
