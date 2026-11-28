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
    expect(
      source,
      contains('PENDING still unresolved after retries; force stopping VPN'),
    );
    expect(source, contains('VpnPlugin.handleStop(force = true)'));
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
    expect(source, isNot(contains('Build.VERSION.SDK_INT')));
    expect(source, contains('VpnService.prepare(context) != null'));
    expect(source, contains('GlobalState.handleStart(skipDebounce = true)'));
    expect(
      source.indexOf('VpnService.prepare(context)'),
      lessThan(source.indexOf('GlobalState.handleStart(')),
    );
  });

  test('Android update packages use the system-confirmed install session', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final plugin = read(
      'android/app/src/main/kotlin/io/fluxora/app/plugins/AppPlugin.kt',
    );
    final receiver = read(
      'android/app/src/main/kotlin/io/fluxora/app/receivers/ApkInstallStatusReceiver.kt',
    );

    expect(manifest, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
    expect(plugin, contains('canRequestPackageInstalls()'));
    expect(
      plugin,
      contains('PackageInstaller.SessionParams.MODE_FULL_INSTALL'),
    );
    expect(plugin, contains('session.commit(callback.intentSender)'));
    expect(receiver, contains('STATUS_PENDING_USER_ACTION'));
    expect(receiver, contains('context.startActivity(confirmation)'));
  });

  test('normal app exit stops Android VPN before shutting down the core', () {
    final controller = read('lib/controller.dart');
    final start = controller.indexOf('List<TeardownStep> _teardownSteps()');
    final end = controller.indexOf('Future<void> handleExit()', start);
    final teardown = controller.substring(start, end);
    final vpnStop = teardown.indexOf("'android-vpn-service'");
    final coreStop = teardown.indexOf("'core-shutdown'");

    expect(vpnStop, greaterThanOrEqualTo(0));
    expect(coreStop, greaterThan(vpnStop));
    expect(teardown, contains('if (!system.isAndroid) return;'));
    expect(teardown, contains('keepOnRestart: true'));
    expect(teardown, contains('stopVpn().timeout('));
  });

  test(
    'Android removes the VPN only when its activity is actually finishing',
    () {
      final plugin = read(
        'android/app/src/main/kotlin/io/fluxora/app/plugins/AppPlugin.kt',
      );
      final android = read('lib/common/android.dart');

      expect(
        plugin,
        contains(
          'channel.invokeMethod("exit", activityRef?.get()?.isFinishing == true)',
        ),
      );
      expect(android, contains('(activityFinishing) async'));
      expect(android, contains('if (activityFinishing)'));
      expect(android, contains('handleExit()'));
    },
  );

  test('TempActivity is no longer exported to other apps', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final tempActivity = RegExp(
      r'<activity\s+android:name="\.TempActivity"[\s\S]*?android:exported="(true|false)"',
    ).firstMatch(manifest);

    expect(tempActivity, isNotNull);
    expect(tempActivity!.group(1), 'false');
  });

  test(
    'private DNS stays out of network diagnostics and clears with callback',
    () {
      final source = read(
        'android/app/src/main/kotlin/io/fluxora/app/plugins/VpnPlugin.kt',
      );

      expect(source, isNot(contains('"privateDnsServerName" to')));
      expect(source, contains('networkPrivateDnsMap.clear()'));
      expect(source, contains('linkProperties.privateDnsServerName?.trim()'));
      expect(
        source,
        contains('(previous != null || privateDnsServerName.isNotEmpty())'),
      );
    },
  );

  test('unlocked pre-34 tile taps collapse the quick-settings panel', () {
    final source = read(
      'android/app/src/main/kotlin/io/fluxora/app/services/FluxoraTileService.kt',
    );

    expect(source, contains('startActivityAndCollapse(intent)'));
    expect(source, contains('Intent.FLAG_ACTIVITY_NEW_TASK'));
    expect(source, contains('isLocked'));
  });

  test('private DNS changes reach the UI without a headless UI controller', () {
    final native = read(
      'android/app/src/main/kotlin/io/fluxora/app/plugins/VpnPlugin.kt',
    );
    final changed = native.substring(
      native.indexOf('override fun onLinkPropertiesChanged'),
      native.indexOf('private val request ='),
    );
    expect(changed, contains('ServicePlugin.notifyNetworkChanged()'));
    final main = read('lib/main.dart');
    final service = main.substring(main.indexOf('Future<void> _service('));
    expect(service, isNot(contains('globalState.appController')));
    final controller = read('lib/controller.dart');
    expect(controller, contains("if (method == 'networkChanged')"));
    expect(
      controller,
      contains('await refreshAndroidPrivateDnsOnNetworkChanged()'),
    );
  });
}
