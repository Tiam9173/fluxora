import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:fluxora/plugins/app.dart';
import 'package:fluxora/plugins/clipboard_ext.dart';
import 'package:fluxora/plugins/service.dart' show Service;
import 'package:fluxora/plugins/tile.dart';
import 'package:fluxora/plugins/vpn.dart';
import 'package:fluxora/state.dart';
import 'package:code_forge/code_forge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synchronized/synchronized.dart';

import 'application.dart';
import 'clash/core.dart';
import 'clash/lib.dart';
import 'common/common.dart';
import 'common/external_control.dart';
import 'common/network_matcher.dart';
import 'models/models.dart';
import 'services/network_fingerprint_provider.dart';

ReceivePort? _serviceReceiverPort;
ReceivePort? _messageReceiverPort;

Future<void> main(List<String> args) async {
  globalState.isService = false;
  WidgetsFlutterBinding.ensureInitialized();

  // Portable builds must not write the plugin's default settings file
  // (`%APPDATA%\Fluxora\Fluxora\shared_preferences.json`): the Windows store
  // resolves that through the Known Folder API, which neither the `.portable`
  // marker nor the `APPDATA` variable can redirect. Swapping the store is the
  // only seam, and it has to happen before the first read of preferences —
  // `SharedPreferences` caches the store's contents on first access.
  //
  // On a normal install this returns immediately without touching anything.
  // Control commands come first: `--exit` / `--restart` are addressed to an
  // instance that is already running, so they must not be blocked by — or take
  // part in — the single-instance guard below.
  if (system.isDesktop &&
      (args.contains('--exit') || args.contains('--restart'))) {
    final command = args.contains('--exit') ? 'exit' : 'restart';
    await _sendControlCommand(command);
    exit(0);
  }

  // R-MULTI — one instance per identity on every desktop platform.
  //
  // Order matters: this runs before the portable-prefs swap, the proxy
  // reconciliation and the core, so a second instance cannot touch the shared
  // profile or the system proxy on its way out.
  if (system.isDesktop) await _enforceSingleInstance();

  await installPortablePrefsStore();

  // B3 — a crash can leave the system proxy pointing at a port that no longer
  // exists. Reconcile before anything reads or writes it, and before the first
  // frame's `ProxyManager` runs. Cheap when there is nothing to reconcile: one
  // file existence check.
  await ProxyOwnership.reconcileOnStart();

  // P2.2: start the network-context fingerprint before any reliability sample
  // can be recorded, so the first real event already lands in the correct
  // `statsByContext` bucket. Best-effort — a connectivity failure falls back to
  // `unknown_default` and must never block app startup.
  try {
    networkFingerprintProvider.start();
  } catch (e) {
    commonPrint.log('Failed to start network fingerprint provider: $e');
  }

  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  final version = await system.version;

  // A core that cannot bind its control socket used to leave `preload()` waiting
  // forever, so `runApp()` below never ran and the window stayed blank. Since
  // R7-15.1 the waiters fail fast, but an uncaught throw here would still skip
  // `runApp()` — so the failure is captured, logged with its stack, and shown in
  // the UI once the first frame is up.
  final startupError = await runStartupTasks(
    initApp: () => globalState.initApp(version),
    preload: () => clashCore.preload(),
  );

  try {
    await uiManager.initializeUI();
  } catch (e) {
    commonPrint.log('Failed to initialize UI: $e');
  }

  await _runApp(startupError: startupError);
}

/// Runs the two futures that must both succeed before the UI comes up.
///
/// Returns `null` on success and the error on failure — it **never rethrows**,
/// which is what lets `main()` reach `_runApp()` instead of dying before
/// `runApp()` and leaving a blank window. The exception *and* its stack are
/// logged here; only the exception is handed to the UI.
///
/// Extracted from `main()` so the failure path can be tested without launching
/// the app.
Future<Object?> runStartupTasks({
  required Future<void> Function() initApp,
  required Future<bool> Function() preload,
}) async {
  try {
    await Future.wait([initApp(), preload()]);
    return null;
  } catch (e, st) {
    commonPrint.log('Core startup failed: $e\n$st');
    return e;
  }
}

Future<void> _sendControlCommand(String command) async {
  for (int i = 0; i < 5; i++) {
    try {
      await ExternalControl.sendCommand(command);
      commonPrint.log('Sent $command command to running instance');
      return;
    } catch (e) {
      if (i == 4) {
        commonPrint.log('Failed to send $command command: $e');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
}

/// R-MULTI — what the single-instance guard decided.
enum SingleInstanceDecision {
  /// We hold the lock; this is the only instance.
  start,

  /// Another instance answered its control channel and was asked to show.
  surfacedExisting,

  /// The lock is taken but nothing answered: refuse to start (fail-closed).
  blocked,
}

/// How many times the single-instance lock is retried before the control
/// channel is consulted at all.
///
/// 20 x 100 ms is a hard bound that still covers a controlled restart: the
/// outgoing process was measured gone 486 ms after `--restart`, and this budget
/// only has to outlast its teardown. A cold start exits the loop on the first
/// attempt, so it never pays this.
const int kSingleInstanceAcquireAttempts = 20;

/// Delay between single-instance lock attempts. See
/// [kSingleInstanceAcquireAttempts].
const Duration kSingleInstanceAcquireDelay = Duration(milliseconds: 100);

/// The decision itself, with the side effects removed so it can be tested.
///
/// P9-B2 — **lock first.**
///
/// The lock is the only authoritative answer to "am I the only instance". The
/// control channel is a convenience layered on top of it, and reading it first
/// was what cost every start three seconds: a port file left behind by a crash
/// or by a restart points at a dead port, and on this platform connecting to a
/// dead loopback port takes ~2 s before the 1 s Dart timeout even fires.
///
/// A free lock therefore starts immediately, without ever touching the port
/// file. The bounded acquire retry covers the one case where "taken" does not
/// mean "another instance": a controlled restart, where the outgoing process is
/// still inside its teardown when the successor runs. The final acquire after
/// the probe covers the tail of that same race — if the probe could not raise
/// anyone, the holder may simply have finished exiting while we asked.
Future<SingleInstanceDecision> resolveSingleInstance({
  required Future<bool> Function() acquire,
  required Future<bool> Function() probe,
  int acquireAttempts = kSingleInstanceAcquireAttempts,
  Duration acquireDelay = kSingleInstanceAcquireDelay,
  int probeAttempts = 3,
  Duration probeDelay = const Duration(milliseconds: 200),
}) async {
  // Phase 1 — bounded lock attempts. First success wins outright: no probe, no
  // port-file read, no timeout. Never unbounded.
  for (var attempt = 0; attempt < acquireAttempts; attempt++) {
    if (await acquire()) return SingleInstanceDecision.start;
    if (attempt == acquireAttempts - 1) break;
    if (acquireDelay > Duration.zero) {
      await Future<void>.delayed(acquireDelay);
    }
  }

  // Phase 2 — the lock is held, so someone owns this profile. Ask it to show.
  //
  // A probe that **returns false** has a definitive answer ("nothing is
  // running"), so it is never retried: retrying only adds latency. A probe that
  // **throws** only says "could not tell", which is worth a bounded retry.
  var running = false;
  for (var attempt = 0; attempt < probeAttempts; attempt++) {
    try {
      running = await probe();
      break;
    } catch (_) {
      if (attempt == probeAttempts - 1) break;
      if (probeDelay > Duration.zero) await Future<void>.delayed(probeDelay);
    }
  }
  if (running) return SingleInstanceDecision.surfacedExisting;

  // Phase 3 — nothing answered, but the lock was taken. The holder may have
  // finished exiting while we were probing, so re-check it once before giving
  // up. Starting without the lock would mean two processes writing one profile,
  // and claiming the wake-up worked would be a lie — so neither.
  if (await acquire()) return SingleInstanceDecision.start;

  return SingleInstanceDecision.blocked;
}

/// R-MULTI — one instance per identity, on every desktop platform.
///
/// Runs before the portable-prefs swap, the proxy reconciliation and the core,
/// so a second instance cannot touch the shared profile or the system proxy on
/// its way out. A cold start now pays exactly one non-blocking lock attempt and
/// never opens a socket at all (P9-B2).
Future<void> _enforceSingleInstance() async {
  final decision = await resolveSingleInstance(
    probe: _probeRunningInstance,
    acquire: singleInstanceLock.acquire,
  );

  switch (decision) {
    case SingleInstanceDecision.start:
      // Only a lock holder may stop the helper on exit (B2 ownership rule), and
      // only a lock holder proves there is no second HostTest instance.
      Windows.instanceLockHeld = true;
      return;
    case SingleInstanceDecision.surfacedExisting:
      commonPrint.log(
        'SingleInstance: another instance answered; asked it to show',
      );
      exit(0);
    case SingleInstanceDecision.blocked:
      commonPrint.log(
        'SingleInstance: lock unavailable and no instance answered; '
        'refusing to start',
      );
      exit(1);
  }
}

/// Asks the running instance to come to the front, and reports what that meant.
///
/// N5 — the three outcomes are genuinely different and are no longer collapsed
/// into one opaque failure:
///
/// * `notRunning` — no control channel at all. A cold start; retrying would
///   only add latency, so this is `false` and [resolveSingleInstance] moves on.
/// * `unreachable` — a channel exists but did not answer. Rethrown so the
///   resolver retries, bounded.
/// * `rejected` — the peer answered and refused (no window yet, show failed).
///   An instance **is** running, so this returns `true`: starting a second one
///   would be worse than a window that did not come forward.
Future<bool> _probeRunningInstance() async {
  try {
    await ExternalControl.sendCommand('show', requireAck: true);
    return true;
  } on ExternalControlException catch (e) {
    switch (e.failure) {
      case ExternalControlFailure.notRunning:
        return false;
      case ExternalControlFailure.unreachable:
        rethrow;
      case ExternalControlFailure.rejected:
        commonPrint.log(
          'ExternalControl: an instance answered but could not show: '
          '${e.detail}',
        );
        return true;
    }
  }
}

Future<void> _runApp({Object? startupError}) async {
  try {
    await RustLib.init();
  } catch (e) {
    commonPrint.log('Failed to initialize code_forge RustLib: $e');
  }

  if (system.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      commonPrint.log('Failed to set high refresh rate: $e');
    }
  }
  await android?.init();

  await window?.init();
  if (system.isWindows) {
    clipboardExt.init();
  }
  HttpOverrides.global = FluxoraHttpOverrides();
  runApp(ProviderScope(child: const Application()));

  if (startupError != null) {
    // Deferred to the first frame: `navigatorKey` has no context before it, so
    // `showNotifier` would silently do nothing. The raw exception is appended
    // rather than swallowed — the log in `main()` carries the stack.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      globalState.showNotifier(
        '${appLocalizations.ipCheckCoreNotReady}: $startupError',
      );
    });
  }
}

@pragma('vm:entry-point')
Future<void> _service(List<String> flags) async {
  globalState.isService = true;
  WidgetsFlutterBinding.ensureInitialized();

  // Same reason as `main()`: this is a second entry point into the same
  // process image, and `globalState.init()` below reads preferences. Without
  // this, a service-mode launch in a portable directory would fall back to the
  // plugin's `%APPDATA%` store and write the developer's real settings file.
  await installPortablePrefsStore();

  await globalState.init();

  {
    final quickStart = flags.contains('quick');
    final bootStart = flags.contains('boot');
    final clashLibHandler = ClashLibHandler();
    final smartAutoStopLock = Lock();

    Future<void> checkSmartAutoStop() async {
      try {
        final vpnProps = globalState.config.vpnProps;
        if (!vpnProps.smartAutoStop) return;
        final networks = vpnProps.smartAutoStopNetworks;
        if (networks.isEmpty) return;

        await smartAutoStopLock.synchronized(() async {
          final isSmartStopped = await vpn?.isSmartStopped() ?? false;
          final candidateIps =
              await vpn?.getLocalIpAddresses() ?? const <String>[];
          final candidateGateways =
              await vpn?.getLocalGateways() ?? const <String>[];
          if (candidateIps.isEmpty && candidateGateways.isEmpty) return;

          final shouldStop =
              candidateIps.any((ip) => NetworkMatcher.matchAny(ip, networks)) ||
              candidateGateways.any(
                (gw) => NetworkMatcher.matchAnyGateway(gw, networks),
              );

          if (shouldStop && !isSmartStopped) {
            final isRunning = await vpn?.getStatus() ?? false;
            if (isRunning) {
              await vpn?.setSmartStopped(true);
              await vpn?.smartStop();
            }
          } else if (!shouldStop && isSmartStopped) {
            await vpn?.setSmartStopped(false);
            await vpn?.smartResume(clashLibHandler.getAndroidVpnOptions());
          }
        });
      } catch (e) {
        commonPrint.log('Smart auto stop check failed: $e');
      }
    }

    tile?.addListener(
      _TileListenerWithService(
        onStart: () async {
          await app.tip(appLocalizations.startVpn);
          try {
            if (!await clashLibHandler.startListener()) {
              throw StateError(appLocalizations.checkError);
            }
            if (!await Service().waitForVpnStart(
              options: clashLibHandler.getAndroidVpnOptions(),
            )) {
              throw StateError(appLocalizations.networkErrorRetryLater);
            }
          } catch (error) {
            await globalState.handleStop();
            await vpn?.stop();
            await app.tip(error.formatError);
          }
        },
        onStop: () async {
          await app.tip(appLocalizations.stopVpn);
          await clashLibHandler.stopListener();
          await vpn?.stop();
        },
        onReconnectIpc: () {
          commonPrint.log(
            'Service: reconnectIpc requested, re-establishing IPC',
          );
          _handleMainIpc(clashLibHandler);
        },
      ),
    );

    vpn?.addListener(
      _VpnListenerWithService(
        onDnsChanged: (String dns) {
          clashLibHandler.updateDns(dns);
        },
        onNetworkChanged: checkSmartAutoStop,
      ),
    );

    if (!quickStart && !bootStart) {
      _handleMainIpc(clashLibHandler);
      _startNotificationSpeedLoop(clashLibHandler);
      return;
    }

    if (bootStart && !globalState.config.appSetting.autoRun) {
      commonPrint.log(
        'Silent boot detected, but autoRun is disabled. Staying idle.',
      );
      _handleMainIpc(clashLibHandler);
      return;
    }

    commonPrint.log('Executing ${bootStart ? "boot" : "quick"} start sequence');
    // Arm before the asynchronous start so an early UI launch cannot race the
    // marker. Consumption still requires the service to actually be running.
    if (globalState.config.appSetting.smartDelayLaunch) {
      unawaited(preferences.markPendingAutoDelayTest());
    }
    await ClashCore.initGeo();
    app.tip(appLocalizations.startVpn);
    final homeDirPath = await appPath.homeDirPath;
    final version = await system.version;
    final clashConfig = globalState.config.patchClashConfig.copyWith.tun(
      enable: false,
    );

    Future(() async {
      try {
        final params = await globalState.getSetupParams(
          pathConfig: clashConfig,
        );
        final profileId = globalState.config.currentProfileId;
        if (profileId == null) {
          // headless 引擎没有任何界面，静默 return 等于"磁贴按了没反应"。
          // 至少要让用户知道为什么没起来。
          await app.tip('Quick start failed: no profile selected');
          await vpn?.stop();
          return;
        }
        final res = await clashLibHandler.quickStart(
          InitParams(homeDir: homeDirPath, version: version),
          params,
          globalState.getCoreState(),
        );
        commonPrint.log(res);
        if (res.isNotEmpty) {
          commonPrint.log('QuickStart failed with error: $res');
          await app.tip('Quick start failed: $res');
          await vpn?.stop();
          return;
        }
        if (!await clashLibHandler.startListener()) {
          throw StateError(appLocalizations.checkError);
        }
        if (!await Service().waitForVpnStart(
          options: clashLibHandler.getAndroidVpnOptions(),
        )) {
          throw StateError(appLocalizations.networkErrorRetryLater);
        }
        Future.delayed(const Duration(seconds: 2), checkSmartAutoStop);

        if (globalState.config.appSetting.openLogs) {
          await clashLibHandler.invokeAction(
            '{"id": "quickStartLog", "method": "startLog"}',
          );
        } else {
          await clashLibHandler.invokeAction(
            '{"id": "quickStopLog", "method": "stopLog"}',
          );
        }

        // item 6 — the speed notification is driven from the *service*
        // isolate, the way FlClash does it: the UI isolate is paused once
        // Android backgrounds the app, which is exactly when the notification
        // matters. This isolate owns the core (`clashLibHandler`), so the tick
        // costs one direct FFI call and no IPC round-trip.
        _startNotificationSpeedLoop(clashLibHandler);
      } catch (e) {
        commonPrint.log('Fatal error during service background start: $e');
        await app.tip('Quick start failed: $e');
        await clashLibHandler.stopListener();
        await vpn?.stop();
      }
    });
  }
}

Timer? _notificationSpeedTimer;
int _notificationSpeedSeq = 0;

/// Replaces the notification text with live up/down speeds every second.
///
/// Started only on the service start paths; the service process dies with the
/// VPN, so the timer needs no explicit teardown. Each tick re-reads the
/// setting, so toggling the switch takes effect without a restart.
void _startNotificationSpeedLoop(ClashLibHandler clashLibHandler) {
  _notificationSpeedTimer?.cancel();
  final config = globalState.config;
  final settings = config.vpnProps;
  final profile = config.profiles
      .where((profile) => profile.id == config.currentProfileId)
      .firstOrNull;
  unawaited(
    vpn?.setNotificationDetails(
      profileName: profile?.label ?? profile?.id ?? '',
      showProfile: settings.notificationShowProfile,
      showNode: settings.notificationShowNode,
      showSpeed: settings.networkSpeedNotification,
      initial: true,
    ),
  );

  var updating = false;
  _notificationSpeedTimer = Timer.periodic(const Duration(seconds: 1), (
    timer,
  ) async {
    if (updating) return;
    updating = true;
    try {
      if (await vpn?.getNotificationSpeedEnabled() != true || !timer.isActive) {
        return;
      }
      final raw = await clashLibHandler.invokeActionData(
        '{"id": "serviceSpeed${_notificationSpeedSeq++}", "method": "getTraffic"}',
      );
      if (raw == null || raw.isEmpty || !timer.isActive) return;
      final traffic = Traffic.fromMap(json.decode(raw));
      await vpn?.updateNotificationSpeed(traffic.toSpeedText());
    } catch (e) {
      commonPrint.log('Service speed notification update failed: $e');
    } finally {
      updating = false;
    }
  });
}

void _handleMainIpc(ClashLibHandler clashLibHandler) {
  final sendPort = IsolateNameServer.lookupPortByName(mainIsolate);
  if (sendPort == null) {
    commonPrint.log('Service: mainIsolate sendPort not found, IPC unavailable');
    return;
  }

  _serviceReceiverPort?.close();
  _messageReceiverPort?.close();

  _serviceReceiverPort = ReceivePort();
  _serviceReceiverPort!.listen((message) async {
    final res = await clashLibHandler.invokeAction(message);
    _safeSend(sendPort, res);
  });
  _safeSend(sendPort, _serviceReceiverPort!.sendPort);

  _messageReceiverPort = ReceivePort();
  clashLibHandler.attachMessagePort(_messageReceiverPort!.sendPort.nativePort);
  _messageReceiverPort!.listen((message) {
    _safeSend(sendPort, message);
  });

}

void _safeSend(SendPort sendPort, dynamic message) {
  try {
    sendPort.send(message);
  } catch (e) {
    commonPrint.log('Service: IPC send failed: $e');
    final retryPort = IsolateNameServer.lookupPortByName(mainIsolate);
    if (retryPort != null) {
      try {
        retryPort.send(message);
      } catch (_) {}
    }
  }
}

@immutable
class _TileListenerWithService with TileListener {
  final Function() _onStart;
  final Function() _onStop;
  final Function() _onReconnectIpc;

  const _TileListenerWithService({
    required Function() onStart,
    required Function() onStop,
    required Function() onReconnectIpc,
  }) : _onStart = onStart,
       _onStop = onStop,
       _onReconnectIpc = onReconnectIpc;

  @override
  void onStart() => _onStart();

  @override
  void onStop() => _onStop();

  @override
  void onReconnectIpc() => _onReconnectIpc();
}

@immutable
class _VpnListenerWithService with VpnListener {
  final Function(String dns) _onDnsChanged;
  final Function() _onNetworkChanged;

  const _VpnListenerWithService({
    required Function(String dns) onDnsChanged,
    required Function() onNetworkChanged,
  }) : _onDnsChanged = onDnsChanged,
       _onNetworkChanged = onNetworkChanged;

  @override
  void onDnsChanged(String dns) {
    super.onDnsChanged(dns);
    _onDnsChanged(dns);
  }

  @override
  void onNetworkChanged() {
    super.onNetworkChanged();
    _onNetworkChanged();
  }
}
