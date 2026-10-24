import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source contracts for native behaviour that cannot run in a Dart VM test.
/// These pin the decision points; Android runtime behaviour still needs Gradle
/// compilation and a device.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('PENDING keeps the latest user intent instead of dropping it', () {
    final source = read(
      'android/app/src/main/kotlin/io/fluxora/app/GlobalState.kt',
    );

    expect(source, contains('hasDeferredIntent'));
    expect(source, contains('RunState.PENDING -> hasDeferredIntent = true'));
    expect(source, isNot(contains('RunState.PENDING -> Unit')));
    expect(source, contains('VpnPlugin.isServiceConnected()'));
    expect(source, contains('wasRunningBeforeRestart'));
  });

  test('package update only restores a previously running VPN', () {
    final source = read(
      'android/app/src/main/kotlin/io/fluxora/app/receivers/PackageReplacedReceiver.kt',
    );

    expect(source, contains('wasRunningBeforeRestart()'));
    expect(
      source,
      contains('App updated while VPN was stopped; not starting it'),
    );
  });

  test('TempActivity is no longer exported to other apps', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final tempActivity = RegExp(
      r'<activity\s+android:name="\.TempActivity"[\s\S]*?android:exported="(true|false)"',
    ).firstMatch(manifest);

    expect(tempActivity, isNotNull);
    expect(tempActivity!.group(1), 'false');
  });

  test('unlocked pre-34 tile taps collapse the quick-settings panel', () {
    final source = read(
      'android/app/src/main/kotlin/io/fluxora/app/services/FluxoraTileService.kt',
    );

    expect(source, contains('startActivityAndCollapse(intent)'));
    expect(source, contains('Intent.FLAG_ACTIVITY_NEW_TASK'));
    expect(source, contains('isLocked'));
  });
}
