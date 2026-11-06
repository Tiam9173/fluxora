import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/helper_auth.dart';
import 'package:fluxora/common/protected_helper.dart';
import 'package:fluxora/common/win32_acl_inspector.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/helper/helper.dart';
import 'package:fluxora/plugins/app.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/input.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:synchronized/synchronized.dart';

class System {
  static System? _instance;

  System._internal();

  factory System() {
    _instance ??= System._internal();
    return _instance!;
  }

  /// Test-only seam pinning the reported platform (production uses
  /// Platform.operatingSystem).
  @visibleForTesting
  static String? platformOverride;

  bool get isDesktop => isWindows || isMacOS || isLinux;

  bool get isWindows =>
      platformOverride == 'windows' ||
      (platformOverride == null && Platform.isWindows);

  bool get isMacOS =>
      platformOverride == 'macos' ||
      (platformOverride == null && Platform.isMacOS);

  bool get isAndroid =>
      platformOverride == 'android' ||
      (platformOverride == null && Platform.isAndroid);

  bool get isLinux =>
      platformOverride == 'linux' ||
      (platformOverride == null && Platform.isLinux);

  Future<int> get version async {
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    return switch (Platform.operatingSystem) {
      'macos' => (deviceInfo as MacOsDeviceInfo).majorVersion,
      'android' => (deviceInfo as AndroidDeviceInfo).version.sdkInt,
      'windows' => (deviceInfo as WindowsDeviceInfo).majorVersion,
      String() => 0,
    };
  }

  static String _shellEscape(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  Future<bool> checkIsAdmin() async {
    final corePath = appPath.corePath;
    if (system.isWindows) {
      if (windows?.isElevated ?? false) {
        return true;
      }
      final result = await windows?.checkService();
      return result == WindowsHelperServiceStatus.running;
    }

    if (system.isMacOS) {
      final result = await Process.run('stat', ['-f', '%Su:%Sg %Sp', corePath]);
      final output = result.stdout.trim();
      final parts = output.split(' ');
      if (parts.length < 2) return false;
      return parts.first.startsWith('root:admin') && parts.last.contains('s');
    }

    if (Platform.isLinux) {
      final result = await Process.run('stat', ['-c', '%U:%G %A', corePath]);
      final output = result.stdout.trim();
      final parts = output.split(' ');
      if (parts.length < 2) return false;
      return parts.first.startsWith('root:') && parts.last.contains('s');
    }

    return true;
  }

  Future<AuthorizeCode> authorizeCore() async {
    if (system.isAndroid) return AuthorizeCode.none;

    if (await checkIsAdmin()) return AuthorizeCode.none;

    if (system.isWindows) {
      if (await windows?._isHelperHealthy() ?? false) return AuthorizeCode.none;
      final result = await windows?.registerService();
      return result == true ? AuthorizeCode.success : AuthorizeCode.error;
    }

    if (system.isMacOS) {
      final corePath = appPath.corePath;
      var quarantineCleared = true;

      final xattrCheck = await Process.run('/usr/bin/xattr', [
        '-p',
        'com.apple.quarantine',
        corePath,
      ]);
      if (xattrCheck.exitCode == 0) {
        final removeResult = await Process.run('/usr/bin/xattr', [
          '-d',
          'com.apple.quarantine',
          corePath,
        ]);
        if (removeResult.exitCode == 0) {
          commonPrint.log(
            'Cleared quarantine attribute from ${AppIdentity.coreExecutableName}',
          );
        } else {
          quarantineCleared = false;
          commonPrint.log(
            'Failed to clear quarantine attribute: ${removeResult.stderr}',
          );
        }
      }

      final escapedPath = _shellEscape(corePath);
      final shell = 'chown root:admin $escapedPath && chmod u+s $escapedPath';
      final result = await Process.run('osascript', [
        '-e',
        'do shell script "$shell" with administrator privileges',
      ]);

      if (result.exitCode != 0) {
        if (!quarantineCleared) {
          globalState.showNotifier(
            'Failed to authorize ${AppIdentity.coreExecutableName}. Try: xattr -dr com.apple.quarantine /Applications/${AppIdentity.mainExecutableName}.app',
          );
        } else {
          globalState.showNotifier(appLocalizations.tunEnableRequireAdmin);
        }
        return AuthorizeCode.error;
      }
      return AuthorizeCode.success;
    }

    if (Platform.isLinux) {
      final escapedCorePath = _shellEscape(appPath.corePath);

      try {
        final pkexecResult = await Process.run('pkexec', [
          'sh',
          '-c',
          'chown root:root $escapedCorePath && chmod u+s $escapedCorePath && sync',
        ]);
        if (pkexecResult.exitCode == 0) {
          return AuthorizeCode.success;
        }
        if (pkexecResult.exitCode != 127) {
          globalState.showNotifier(appLocalizations.tunEnableRequireAdmin);
          return AuthorizeCode.error;
        }
      } catch (e) {
        commonPrint.log('pkexec failed: $e');
      }

      window?.show();
      final shell = Platform.environment['SHELL'] ?? 'bash';
      final password = await globalState.showCommonDialog<String>(
        child: InputDialog(
          obscureText: true,
          title: appLocalizations.pleaseInputAdminPassword,
          value: '',
        ),
      );
      if (password == null || password.isEmpty) {
        globalState.showNotifier(appLocalizations.tunEnableRequireAdmin);
        return AuthorizeCode.error;
      }
      final escapedPassword = _shellEscape(password);
      final result = await Process.run(shell, [
        '-c',
        'echo $escapedPassword | sudo -S chown root:root $escapedCorePath && echo $escapedPassword | sudo -S chmod u+s $escapedCorePath && sync',
      ]);
      if (result.exitCode != 0) {
        globalState.showNotifier(appLocalizations.tunEnableRequireAdmin);
      }
      return result.exitCode == 0 ? AuthorizeCode.success : AuthorizeCode.error;
    }

    return AuthorizeCode.error;
  }

  Future<void> back() async {
    if (system.isAndroid) await app.moveTaskToBack();
    await window?.hide();
  }

  Future<void> exit() async {
    if (system.isAndroid) await SystemNavigator.pop();
    await window?.close();
  }

  Future<void> setProcessPriority(String processName, bool enable) async {
    if (!isWindows) return;

    if (processName == '${AppIdentity.mainExecutableName}.exe') {
      try {
        windows?.setCurrentProcessPriority(enable);
        return;
      } catch (e) {
        commonPrint.log('Failed to set current process priority: $e');
      }
    }

    final result = await Process.run('wmic', [
      'process',
      'where',
      'name="$processName"',
      'call',
      'setpriority',
      enable ? 'above normal' : 'normal',
    ]);

    if (result.exitCode != 0) {
      throw Exception('Failed to set process priority: ${result.stderr}');
    }
  }
}

final system = System();

/// H2-A — how [Windows.registerService] resolved, so callers and tests can tell
/// "we reused it" from "we started it" from "we must not touch it".
///
/// The destructive (re)install sequence is reachable from [notInstalled] only.
/// Every other outcome returns without stopping, deleting or reconfiguring the
/// service — a stopped-but-installed service is started, never rebuilt.
enum HelperStartOutcome {
  /// S2 — installed, running, and answering IPC. Reused as-is.
  reused,

  /// S1 — installed, stopped, identity matched; started and became healthy.
  started,

  /// S0 — `sc query` reported no such service. The caller may run the existing
  /// first-install path, which is the only branch that raises UAC.
  notInstalled,

  /// S4 — installed, but its ImagePath is not the helper this build ships.
  identityConflict,

  /// S3 — installed and running, but IPC did not answer.
  unhealthy,

  /// S8 — installed and stopped, but starting it was denied.
  accessDenied,

  /// S9 — started (or was pending) and never became healthy in time.
  startFailed,

  /// S7 — `sc query` itself failed for a reason other than "no such service".
  queryFailed,
}

/// H2-C — how the helper stop resolved. Only [stopped] means the SCM actually
/// reported `STOPPED`; an IPC acknowledgement alone is [ackOnly].
enum HelperStopOutcome {
  /// SCM reported state 1 (STOPPED) within the bounded wait.
  stopped,

  /// The helper acknowledged `helper.stop_service`, but the service did not
  /// reach STOPPED before the budget ran out. Not a success.
  ackOnly,

  /// The IPC request was refused, threw, or timed out.
  ipcRefused,

  /// `sc query` said there is no such service.
  notInstalled,

  /// `sc query` failed for a reason other than "no such service".
  queryFailed,

  /// The installed service is not this build's helper — left untouched.
  identityConflict,

  /// P9-A — the service is not a `DEMAND_START` service, so it is shared and
  /// SCM-managed: an `AUTO_START` helper is started at boot and reused by every
  /// session, and stopping it on exit is what made the next launch fall back to
  /// the unprotected core. Also returned when the start type cannot be proven
  /// (`sc qc` unreadable, `DISABLED`, unparsable) — fail closed, never stop what
  /// we cannot prove we may stop.
  sharedAutoStart,

  /// B2 — this instance is not responsible for the service being up, so the
  /// stop was never attempted: no IPC, no `sc`. Not a failure.
  notOwned,
}

/// P9-A — how the SCM will bring the helper up.
///
/// Only [demand] is a service an app instance may stop. `AUTO_START` is the
/// shared, boot-managed case the fix exists for; [unknown] covers `DISABLED`
/// and any output that does not prove either.
enum HelperServiceStartType { auto, demand, unknown }

class Windows {
  static Windows? _instance;
  late DynamicLibrary _shell32;

  Windows._internal() {
    _shell32 = DynamicLibrary.open('shell32.dll');
  }

  factory Windows() {
    _instance ??= Windows._internal();
    return _instance!;
  }

  bool get isElevated {
    try {
      final isUserAnAdmin = _shell32
          .lookupFunction<Int32 Function(), int Function()>('IsUserAnAdmin');
      return isUserAnAdmin() != 0;
    } catch (_) {
      return false;
    }
  }

  void setCurrentProcessPriority(bool enable) {
    final kernel32 = DynamicLibrary.open('kernel32.dll');

    final getCurrentProcess = kernel32
        .lookupFunction<IntPtr Function(), int Function()>('GetCurrentProcess');

    final setPriorityClass = kernel32
        .lookupFunction<
          Int32 Function(IntPtr hProcess, Int32 dwPriorityClass),
          int Function(int hProcess, int dwPriorityClass)
        >('SetPriorityClass');

    final setProcessInformation = kernel32
        .lookupFunction<
          Int32 Function(
            IntPtr hProcess,
            Int32 processInformationClass,
            Pointer<Void> processInformation,
            Uint32 processInformationSize,
          ),
          int Function(
            int hProcess,
            int processInformationClass,
            Pointer<Void> processInformation,
            int processInformationSize,
          )
        >('SetProcessInformation');

    final priorityClass = enable ? 0x00008000 : 0x00000020;

    final hProcess = getCurrentProcess();
    final result = setPriorityClass(hProcess, priorityClass);

    if (result == 0) {
      throw Exception('SetPriorityClass failed');
    }

    commonPrint.log(
      'Set current process priority to ${enable ? "above normal" : "normal"}',
    );

    if (enable) {
      final memoryPriorityInfo = calloc<Uint32>();
      try {
        memoryPriorityInfo.value = 5;
        final memoryResult = setProcessInformation(
          hProcess,
          0,
          memoryPriorityInfo.cast<Void>(),
          sizeOf<Uint32>(),
        );
        if (memoryResult == 0) {
          commonPrint.log('Set current process memory priority failed');
        } else {
          commonPrint.log('Set current process memory priority to normal');
        }
      } finally {
        calloc.free(memoryPriorityInfo);
      }
    }
  }

  bool runas(String command, String arguments, {bool showWindow = false}) {
    final commandPtr = command.toNativeUtf16();
    final argumentsPtr = arguments.toNativeUtf16();
    final operationPtr = 'runas'.toNativeUtf16();

    final shellExecute = _shell32
        .lookupFunction<
          Int32 Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            Int32 nShowCmd,
          ),
          int Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            int nShowCmd,
          )
        >('ShellExecuteW');

    // 0 = hide, 1 = show
    final result = shellExecute(
      nullptr,
      operationPtr,
      commandPtr,
      argumentsPtr,
      nullptr,
      showWindow ? 1 : 0,
    );

    calloc.free(commandPtr);
    calloc.free(argumentsPtr);
    calloc.free(operationPtr);

    commonPrint.log('windows runas: [command masked] resultCode:$result');

    return result > 32;
  }

  Future<WindowsHelperServiceStatus> checkService() async {
    await HelperAuthManager.ensureAuthKey();
    final result = await _sc(['query', appHelperService]);
    if (result.exitCode != 0) return WindowsHelperServiceStatus.none;

    final output = result.stdout.toString();
    if (!output.contains('RUNNING')) return WindowsHelperServiceStatus.presence;

    return await _pingHelper()
        ? WindowsHelperServiceStatus.running
        : WindowsHelperServiceStatus.presence;
  }

  Future<bool>? _registerServiceInFlight;

  /// B2 — did **this instance** issue the `sc start` that made the helper run?
  ///
  /// [HelperStartOutcome.reused] deliberately does not set this. Finding a
  /// service already running says nothing about who started it — it may be a
  /// previous session, an `auto` boot start, or the installer — and stopping
  /// someone else's service is exactly what this flag exists to prevent.
  static bool _helperStartIssuedByUs = false;

  /// B2 — the service was already running when this instance looked.
  ///
  /// Only the HostTest identity is allowed to act on this, and only while it
  /// holds the per-identity single-instance lock.
  static bool _helperReused = false;

  /// Whether this process holds the per-identity single-instance lock.
  ///
  /// Set by `main()`. Consulted only for the HostTest identity, where a held
  /// lock is what makes "no second instance can share this service" true.
  static bool instanceLockHeld = false;

  /// B2 — drives the ownership rule without going through the SCM.
  @visibleForTesting
  static void markHelperSessionForTest({
    bool startedByUs = false,
    bool reused = false,
    bool lockHeld = false,
  }) {
    _helperStartIssuedByUs = startedByUs;
    _helperReused = reused;
    instanceLockHeld = lockHeld;
  }

  /// Test-only: forces the HostTest ownership rule. `AppIdentity.isHostTest` is
  /// a compile-time constant, so the branch is unreachable from a normal test
  /// run otherwise.
  @visibleForTesting
  static bool? hostTestOverrideForTest;

  @visibleForTesting
  static void resetHelperSessionForTest() {
    _helperStartIssuedByUs = false;
    _helperReused = false;
    instanceLockHeld = false;
    hostTestOverrideForTest = null;
  }

  /// Test-only: replaces every `sc` invocation made by this class, so a test
  /// can drive the real state machine without touching the SCM.
  @visibleForTesting
  static Future<ProcessResult> Function(List<String> args)? scRunnerForTest;

  /// Test-only: replaces the helper IPC ping (the named pipe).
  @visibleForTesting
  static Future<bool> Function()? helperPingOverrideForTest;

  /// Test-only: replaces the destructive (re)install sequence, which otherwise
  /// runs `runas` and raises UAC.
  @visibleForTesting
  static Future<bool> Function()? configureHelperServiceOverrideForTest;

  /// Test-only: replaces the expected helper path used by the identity check.
  /// `appPath` needs `path_provider`, which a plain `test()` cannot serve.
  @visibleForTesting
  static String? helperIdentityPathOverrideForTest;

  /// Test-only: forces the start type the stop gate sees. Stop-mechanics suites
  /// model a `DEMAND_START` service, which is the only kind an instance may
  /// stop; the parse itself is covered by `parseServiceStartType` cases.
  @visibleForTesting
  static HelperServiceStartType? helperStartTypeOverrideForTest;

  /// Test-only: replaces the protected install target.
  ///
  /// SEC-P0-01 — production resolves `%ProgramFiles%\Fluxora\Service\…`. Tests
  /// pin a temp path here so nothing ever writes to Program Files.
  @visibleForTesting
  static String? helperProtectedPathOverrideForTest;

  /// Test-only: replaces the C2 identity check wholesale.
  ///
  /// For stop-mechanics tests only. The check itself is covered by Group A
  /// (`scQcBinaryMatches`) and by T-S2, which drives the real function.
  @visibleForTesting
  static Future<bool> Function()? helperIdentityTrustedOverrideForTest;

  /// Test-only: replaces the protected install **directory** (the deploy
  /// target). Distinct from [helperProtectedPathOverrideForTest], which is the
  /// expected `sc qc` binary path.
  @visibleForTesting
  static String? helperProtectedDirOverrideForTest;

  /// Test-only: replaces the whole deploy step (pre-flight → elevated copy →
  /// post-copy verification), which would otherwise raise UAC.
  @visibleForTesting
  static Future<bool> Function()? deployHelperAssetsOverrideForTest;

  /// Counts how many times this process asked for an elevated helper. Lets a
  /// test assert "no UAC was requested" without faking `runas` itself.
  @visibleForTesting
  static int elevatedHelperCallCountForTest = 0;

  /// Test-only: skips [HelperAuthManager.ensureAuthKey], which reads HKLM and
  /// writes the key file through `path_provider`.
  @visibleForTesting
  static bool skipAuthKeyForTest = false;

  Future<ProcessResult> _sc(List<String> args) {
    final runner = scRunnerForTest;
    if (runner != null) return runner(args);
    return Process.run('sc', args);
  }

  Future<bool> registerService() {
    return _registerServiceInFlight ??= _registerService().whenComplete(
      () => _registerServiceInFlight = null,
    );
  }

  /// H2-A — start-if-needed, never rebuild-if-stopped.
  ///
  /// Before this, *any* failed health check fell through to
  /// [_configureHelperService], which does `sc stop` → `sc delete` →
  /// `sc create` → `reg add` → `sc start` under `runas`. A service that was
  /// merely stopped (the normal state right after an app exit) therefore
  /// triggered a full reinstall and a UAC prompt on every launch.
  ///
  /// Now only [HelperStartOutcome.notInstalled] reaches that path. A stopped
  /// service is started in place; a running-but-unhealthy or
  /// identity-mismatched service is left untouched.
  Future<bool> _registerService() async {
    if (!skipAuthKeyForTest) await HelperAuthManager.ensureAuthKey();

    switch (await _ensureHelperRunning()) {
      case HelperStartOutcome.reused:
      case HelperStartOutcome.started:
        return true;

      case HelperStartOutcome.notInstalled:
        // SEC-P0-01 — nothing may reach SCM until the helper closure has been
        // verified and deployed into the protected directory. A false return
        // here means "no helper service", never "fall back to the writable
        // build directory": the old binPath was the vulnerability.
        final configure = configureHelperServiceOverrideForTest;
        return deployThenConfigure(
          deploy: _deployHelperAssets,
          configure: configure ?? _configureHelperService,
          waitHealthy: _waitForHelperHealthy,
        );

      case HelperStartOutcome.identityConflict:
      case HelperStartOutcome.unhealthy:
      case HelperStartOutcome.accessDenied:
      case HelperStartOutcome.startFailed:
      case HelperStartOutcome.queryFailed:
        return false;
    }
  }

  /// S0–S9. Read-only until the one branch that is allowed to act.
  ///
  /// Exposed for tests so the real state machine can be driven without going
  /// through [HelperAuthManager.ensureAuthKey], which reads HKLM.
  @visibleForTesting
  Future<HelperStartOutcome> ensureHelperRunningForTest() =>
      _ensureHelperRunning();

  Future<HelperStartOutcome> _ensureHelperRunning() async {
    final query = await _sc(['query', appHelperService]);

    if (query.exitCode != 0) {
      // `sc query` exits non-zero when the service is not installed. It also
      // exits non-zero when the SCM itself refuses; treat a recognisable
      // "does not exist" message as S0 and anything else as S7, so a broken
      // SCM never looks like a missing service.
      final text = '${query.stdout}${query.stderr}'.toLowerCase();
      final missing =
          text.contains('does not exist') ||
          text.contains('1060') ||
          text.contains('不存在') ||
          text.contains('指定的服务');
      return missing
          ? HelperStartOutcome.notInstalled
          : HelperStartOutcome.queryFailed;
    }

    final out = query.stdout.toString();

    if (out.contains('RUNNING')) {
      if (await _pingHelper()) {
        // Running, but not because of us — see [_helperStartIssuedByUs].
        _helperReused = true;
        return HelperStartOutcome.reused;
      }
      return HelperStartOutcome.unhealthy;
    }

    if (out.contains('START_PENDING') || out.contains('STOP_PENDING')) {
      // Never treat a transition as "stopped" — that is what used to trigger
      // the rebuild. Wait, bounded, and report honestly if it never lands.
      return await _waitForHelperHealthy()
          ? HelperStartOutcome.started
          : HelperStartOutcome.startFailed;
    }

    // Installed and stopped. Verify it is *our* helper before touching it.
    if (!await _isHelperIdentityTrusted()) {
      return HelperStartOutcome.identityConflict;
    }

    final start = await _sc(['start', appHelperService]);
    if (start.exitCode != 0) {
      final text = '${start.stdout}${start.stderr}'.toLowerCase();
      final denied =
          start.exitCode == 5 ||
          text.contains('access is denied') ||
          text.contains('拒绝访问');
      return denied
          ? HelperStartOutcome.accessDenied
          : HelperStartOutcome.startFailed;
    }

    // The only place ownership is granted: we are the reason it is running.
    _helperStartIssuedByUs = true;

    return await _waitForHelperHealthy()
        ? HelperStartOutcome.started
        : HelperStartOutcome.startFailed;
  }

  /// True only when the installed service points at the helper this build
  /// ships.
  ///
  /// Locale-tolerant on purpose: `sc qc` field labels are translated on
  /// non-English Windows, so this looks for the expected path rather than
  /// parsing a `BINARY_PATH_NAME` line.
  Future<bool> _isHelperIdentityTrusted({String? qcStdout}) async {
    // Narrow seam for stop-mechanics tests: those drive the SCM confirmation
    // path and would otherwise need a `qc` response on every fake runner. The
    // check itself is covered by Group A (`scQcBinaryMatches`) and by T-S2,
    // which drives this function with a real mismatched `qc` payload.
    final override = helperIdentityTrustedOverrideForTest;
    if (override != null) return override();

    // One `sc qc` serves both the identity check and the start-type gate.
    final stdout = qcStdout ?? await _helperQcStdout();
    if (stdout == null) return false;

    // SEC-P0-01 — the trusted path is the **protected** one, not the build
    // directory the helper used to be installed from. A service still pointing
    // at a user-writable directory therefore reads as `identityConflict` and is
    // never started. The existing test seam still wins, so the stop-mechanics
    // suites keep driving this with their own payloads.
    final expected =
        helperIdentityPathOverrideForTest ??
        ProtectedPathRules.defaultProtectedExePath() ??
        '';
    if (expected.isEmpty) return false;

    return scQcBinaryMatches(stdout, expected);
  }

  /// `sc qc` output, or null when the query itself failed.
  Future<String?> _helperQcStdout() async {
    final qc = await _sc(['qc', appHelperService]);
    return qc.exitCode == 0 ? qc.stdout.toString() : null;
  }

  /// True only when `sc qc` output contains [expected] as the service's
  /// **binary path**, compared exactly.
  ///
  /// H2-C replaces the H2-A substring test. That one accepted any output
  /// containing the expected path, so `...\FluxoraHelperService.exe.backup`
  /// (a stale copy, or something an attacker with admin rights planted) read
  /// as trusted and would have been started as LocalSystem.
  ///
  /// Rules:
  ///  * quoted strings are compared whole (that is how `sc create` writes a
  ///    path that contains spaces);
  ///  * bare whitespace tokens are compared only when they end in `.exe`, so
  ///    `...exe.backup` and `--service` are never candidates;
  ///  * anything that cannot be resolved by string comparison alone — an
  ///    unquoted path with spaces, `%VAR%`, `..`, an 8.3 alias, a reparse
  ///    point — simply does not match. Proving those equivalent needs the real
  ///    filesystem, which this check must not touch.
  @visibleForTesting
  static bool scQcBinaryMatches(String stdout, String expected) {
    final want = _normalizeBinaryPath(expected);
    if (want.isEmpty) return false;

    for (final m in RegExp(r'"([^"]+)"').allMatches(stdout)) {
      if (_normalizeBinaryPath(m.group(1)!) == want) return true;
    }

    for (final token in stdout.split(RegExp(r'\s+'))) {
      final t = token.replaceAll('"', '').trim();
      if (t.isEmpty || !t.toLowerCase().endsWith('.exe')) continue;
      if (_normalizeBinaryPath(t) == want) return true;
    }

    return false;
  }

  /// Lower-cases, unifies separators and strips a `\??\` device prefix.
  /// Returns '' when the input is not an `.exe` path, so callers fail closed.
  static String _normalizeBinaryPath(String raw) {
    var s = raw.trim().replaceAll('"', '');
    if (s.toLowerCase().startsWith(r'\??\')) s = s.substring(4);
    s = s.replaceAll('/', r'\').toLowerCase();
    if (!s.endsWith('.exe')) return '';
    return s;
  }

  /// `sc query` prints `STATE : 4  RUNNING`. The field label is localised on
  /// non-English Windows; the number and the English state name are not.
  /// Both must agree, otherwise this returns null and the caller fails closed.
  @visibleForTesting
  static int? parseServiceState(String stdout) {
    const byCode = {
      1: 'STOPPED',
      2: 'START_PENDING',
      3: 'STOP_PENDING',
      4: 'RUNNING',
      5: 'CONTINUE_PENDING',
      6: 'PAUSE_PENDING',
      7: 'PAUSED',
    };
    final m = RegExp(r':\s*([1-7])\s+([A-Z_]{3,})').firstMatch(stdout);
    if (m == null) return null;
    final code = int.parse(m.group(1)!);
    if (byCode[code] != m.group(2)) return null;
    return code;
  }

  /// `sc qc` prints `START_TYPE : 2  AUTO_START`. The numeric field label is
  /// localised on non-English Windows; the value token is not.
  ///
  /// Only the two tokens this decision needs are recognised. `DISABLED`, a
  /// failed `qc`, or anything unrecognised returns [HelperServiceStartType
  /// .unknown] so the caller refuses to stop the service.
  @visibleForTesting
  static HelperServiceStartType parseServiceStartType(String stdout) {
    if (RegExp(r'\bAUTO_START\b').hasMatch(stdout)) {
      return HelperServiceStartType.auto;
    }
    if (RegExp(r'\bDEMAND_START\b').hasMatch(stdout)) {
      return HelperServiceStartType.demand;
    }
    return HelperServiceStartType.unknown;
  }

  /// P9-A — the stop precondition, without touching the SCM.
  ///
  /// Returns `null` when the stop may proceed. An `AUTO_START` helper is shared
  /// and SCM-managed: the SCM starts it at boot and every session reuses it, so
  /// stopping it on exit left the next launch with a service it cannot start
  /// (the interactive user has no SERVICE_START right) and that launch fell back
  /// to the unprotected core. An unprovable start type fails closed for the same
  /// reason.
  @visibleForTesting
  static HelperStopOutcome? helperStopBlockedReason({
    required bool identityTrusted,
    required HelperServiceStartType startType,
  }) {
    if (!identityTrusted) return HelperStopOutcome.identityConflict;
    if (startType != HelperServiceStartType.demand) {
      return HelperStopOutcome.sharedAutoStart;
    }
    return null;
  }

  Future<bool> _isHelperHealthy() async {
    final result = await _sc(['query', appHelperService]);
    if (result.exitCode != 0) return false;

    if (!result.stdout.toString().contains('RUNNING')) return false;

    return _pingHelper();
  }

  Future<bool> _pingHelper() async {
    final override = helperPingOverrideForTest;
    if (override != null) return override();

    // P9 — await the shared computation rather than reading the field. The
    // probe runs from `ClashService`'s constructor, which `preload()` triggers
    // concurrently with `initApp()`, so this used to observe `null` and report
    // "unhealthy" — indistinguishable from a genuine identity mismatch. The
    // app then never used the helper at all.
    final coreSHA256 = await globalState.ensureCoreSha();
    if (coreSHA256 == null || coreSHA256.isEmpty) return false;
    return helperClient.ping(coreSHA256);
  }

  /// SEC-P0-01 — the first-install sequence, with the gates in a fixed order.
  ///
  /// `deploy` covers pre-flight, the elevated copy and the post-copy
  /// verification; it must pass before `configure` (the only function that
  /// writes to the SCM) is even called. Extracted so the ordering can be proven
  /// without constructing [Windows], which needs Windows-only FFI.
  @visibleForTesting
  static Future<bool> deployThenConfigure({
    required Future<bool> Function() deploy,
    required Future<bool> Function() configure,
    required Future<bool> Function() waitHealthy,
  }) async {
    if (!await deploy()) return false;
    if (!await configure()) return false;
    return waitHealthy();
  }

  /// SEC-P0-01 — pre-flight → elevated copy → post-copy verification.
  ///
  /// Returns false on **any** doubt, and the caller then performs no SCM write
  /// at all. Three separate gates, in this order:
  ///
  /// 1. `prepare(copy: false)` — build-provided manifest present, target inside
  ///    `%ProgramFiles%`, existing target directory ACL/owner/reparse safe,
  ///    source assets present and matching the manifest. Nothing is copied yet.
  /// 2. the copy itself, inside the elevated context (Program Files is not
  ///    writable by the interactive user, and must not be).
  /// 3. `verifyDeployed` — what actually landed still hashes to the manifest and
  ///    is still owned by a privileged principal with no write ACE for a
  ///    low-privilege SID.
  ///
  /// The manifest is never recomputed from the files being installed: an
  /// install-time hash of a user-writable file proves nothing about that file.
  Future<bool> _deployHelperAssets() async {
    final override = deployHelperAssetsOverrideForTest;
    if (override != null) return override();

    final targetDir =
        helperProtectedDirOverrideForTest ??
        ProtectedPathRules.defaultProtectedDir();
    if (targetDir == null || targetDir.isEmpty) {
      commonPrint.log(
        'SEC-P0-01: %ProgramFiles% could not be resolved; refusing to deploy',
      );
      return false;
    }

    final sourceDir = appPath.executableDirPath;
    final installer = HelperInstaller(
      inspector: Win32AclInspector(),
      manifest: HelperAssetManifest.fromEnvironment(),
    );

    final pre = await installer.prepare(
      sourceDir: sourceDir,
      targetDir: targetDir,
      copy: false,
    );
    if (!pre.decision.canInstall) {
      commonPrint.log(
        'SEC-P0-01: helper deploy refused before copy '
        '(${pre.decision.rejection.text} at ${pre.failClosedAt})',
      );
      return false;
    }

    if (!await _copyHelperAssetsElevated(sourceDir, targetDir)) {
      commonPrint.log('SEC-P0-01: elevated helper copy did not succeed');
      return false;
    }

    final post = await installer.verifyDeployed(targetDir: targetDir);
    if (!post.decision.canInstall) {
      commonPrint.log(
        'SEC-P0-01: deployed helper failed verification '
        '(${post.decision.rejection.text} at ${post.failClosedAt})',
      );
      return false;
    }

    return true;
  }

  /// The only place that writes into the protected directory, and therefore the
  /// only place that needs elevation.
  ///
  /// `mkdir` is tolerant (the directory usually exists after the first install);
  /// both copies are chained with `&&` so a failed copy stops before anything
  /// else runs. No SCM command is part of this call — that is deliberate, so a
  /// copy that later fails verification cannot have created a service first.
  Future<bool> _copyHelperAssetsElevated(
    String sourceDir,
    String targetDir,
  ) async {
    elevatedHelperCallCountForTest++;

    final command = [
      '/c',
      'if',
      'not',
      'exist',
      '"$targetDir"',
      'mkdir',
      '"$targetDir"',
      '&&',
      for (final name in kHelperAssetNames) ...<String>[
        'copy',
        '/y',
        '"$sourceDir\\$name"',
        '"$targetDir\\$name"',
        '>nul',
        '&&',
      ],
      'exit',
      '0',
    ].join(' ');

    return runas('cmd.exe', command);
  }

  Future<bool> _configureHelperService() async {
    final authKey = HelperAuthManager.getAuthKey();
    if (authKey == null) return false;

    // SEC-P0-01 — the service may only ever point at the protected install
    // directory. The old code used `appPath.helperPath`, i.e. the build folder,
    // whose owner is the interactive user: replacing the EXE (or the
    // `VCRUNTIME140.dll` it loads from the application directory) meant SYSTEM
    // code execution. If the protected path cannot be resolved this fails
    // closed instead of falling back to the writable one.
    final protectedDir =
        helperProtectedDirOverrideForTest ??
        ProtectedPathRules.defaultProtectedDir();
    final binPath =
        helperProtectedPathOverrideForTest ??
        (protectedDir == null || protectedDir.isEmpty
            ? null
            : '$protectedDir\\$kHelperExeName');
    if (binPath == null || binPath.isEmpty) {
      commonPrint.log(
        'SEC-P0-01: no protected helper path available; refusing to install',
      );
      return false;
    }

    final serviceRegistryPath =
        'HKLM\\SYSTEM\\CurrentControlSet\\Services\\$appHelperService';

    final command = [
      '/c',
      'sc',
      'stop',
      appHelperService,
      '>nul',
      '2>&1',
      '&',
      'sc',
      'delete',
      appHelperService,
      '>nul',
      '2>&1',
      '&',
      'sc',
      'create',
      appHelperService,
      'binPath= "$binPath"',
      serviceStartTypeArg,
      '&&',
      'reg',
      'add',
      '"$serviceRegistryPath"',
      '/v',
      'Environment',
      '/t',
      'REG_MULTI_SZ',
      '/d',
      '"HELPER_AUTH_KEY=$authKey\\0HELPER_SERVICE_NAME=$appHelperService\\0HELPER_PIPE_NAME=$helperPipeName"',
      '/f',
      '&&',
      'sc',
      'start',
      appHelperService,
    ].join(' ');

    return runas('cmd.exe', command);
  }

  /// H2-C: `demand` for every identity. Release used to be `auto`, which made
  /// the helper start with Windows even when Fluxora was not running — the
  /// opposite of what a tray exit is supposed to achieve.
  ///
  /// This only affects services created from now on; an already-installed
  /// `auto` service keeps its configuration until a separate migration batch.
  /// Nothing here calls `sc config`.
  @visibleForTesting
  static String get serviceStartTypeArg => 'start= demand';

  Future<bool> _waitForHelperHealthy() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (await _isHelperHealthy()) return true;

      if (attempt > 0 && attempt % 4 == 0) {
        final check = await _sc(['query', appHelperService]);
        final output = check.stdout.toString();
        if (output.contains('STOPPED')) {
          commonPrint.log('Helper service stopped/failed, skipping wait');
          break;
        }
      }
    }

    return false;
  }

  /// Test-only seam: replaces the whole stop sequence so a test never reaches
  /// the helper named pipe or `sc`. Mirrors [AppPath.corePathOverrideForTest].
  @visibleForTesting
  static Future<bool> Function()? stopHelperServiceOverrideForTest;

  /// Test-only: replaces only the IPC `helper.stop_service` call, leaving the
  /// SCM confirmation real (driven through [scRunnerForTest]).
  @visibleForTesting
  static Future<bool> Function()? helperStopIpcOverrideForTest;

  /// Ends the helper service **this instance is responsible for**.
  ///
  /// H1: the helper runs as `LocalSystem`, so a release build cannot stop it
  /// with `sc` — that needs elevation, and the exit path must never raise UAC.
  /// The only non-elevated route is the IPC `helper.stop_service` request: the
  /// helper stops *itself*.
  ///
  /// B2 — the request is now gated. Before this, **any** Fluxora instance that
  /// exited sent the stop, including one that never used the helper at all,
  /// and including one that only found a service someone else had started.
  /// The gate is three independent facts, all required:
  ///
  /// * **C1 identity** — the service name is this build's derived name. True by
  ///   construction (both sides read `WindowsHelperIdentity`), asserted at
  ///   runtime so a future drift fails loudly instead of silently.
  /// * **C2 provenance** — `sc qc` says the installed helper is *this build's*
  ///   binary. Stops us from touching another installation that happens to use
  ///   the same name.
  /// * **C3 session** — the identity-specific ownership rule below.
  /// * **C4 start type** — P9-A: only a `DEMAND_START` service may be stopped.
  ///   `AUTO_START` is shared and SCM-managed, and an unprovable start type
  ///   fails closed. C2 and C4 are answered by the same `sc qc`.
  ///
  /// The real authorisation is the HMAC key (a different identity cannot
  /// authenticate at all), not the session flag; C3 only narrows it further.
  ///
  /// Returns [HelperStopOutcome.stopped] **only** when the SCM confirms state
  /// 1. An IPC acknowledgement alone is [HelperStopOutcome.ackOnly] — H2-C
  /// added the confirmation step because H1 treated the ACK as proof.
  ///
  /// The core is deliberately *not* stopped here: [AppController.handleExit]
  /// shuts the core down first, because the helper may be the process that
  /// owns it.
  Future<HelperStopOutcome> stopHelperService() async {
    final bypass = stopHelperServiceOverrideForTest;
    if (bypass != null) {
      return await bypass()
          ? HelperStopOutcome.stopped
          : HelperStopOutcome.ipcRefused;
    }

    // C3 first: no ownership means no IPC and no `sc` call at all.
    if (!_ownsHelperService()) return HelperStopOutcome.notOwned;

    // C1: compile-time identity. Both sides read the same derived value, so this
    // can only fail if someone hardcodes a service name again.
    if (appHelperService != WindowsHelperIdentity.serviceName) {
      return HelperStopOutcome.identityConflict;
    }

    // C2 + C4 share one `sc qc`: the installed service must be the helper this
    // build ships, and it must be a DEMAND_START service before we may stop it.
    final qcStdout = await _helperQcStdout();
    final identityTrusted = await _isHelperIdentityTrusted(qcStdout: qcStdout);
    final startType =
        helperStartTypeOverrideForTest ?? parseServiceStartType(qcStdout ?? '');
    final blocked = helperStopBlockedReason(
      identityTrusted: identityTrusted,
      startType: startType,
    );
    if (blocked != null) {
      commonPrint.log(
        'Helper stop refused: identity=$identityTrusted '
        'startType=${startType.name}',
      );
      return blocked;
    }

    final ipcOverride = helperStopIpcOverrideForTest;
    final acknowledged = ipcOverride != null
        ? await ipcOverride()
        : await helperClient.stopHelperService();

    if (!acknowledged) {
      // Dev-only fallback: a dev helper can wedge before it answers, and a
      // developer session normally has the rights. Never attempted in release —
      // `sc stop` on a LocalSystem service would raise UAC.
      if (!AppIdentity.isDev) return HelperStopOutcome.ipcRefused;

      final result = await _sc(['stop', appHelperService]);
      if (result.exitCode != 0) return HelperStopOutcome.ipcRefused;
    }

    // LEVEL_2 — the ACK is not proof. Ask the SCM.
    final query = await _sc(['query', appHelperService]);
    if (query.exitCode != 0) {
      final text = '${query.stdout}${query.stderr}'.toLowerCase();
      final missing =
          text.contains('does not exist') ||
          text.contains('1060') ||
          text.contains('不存在') ||
          text.contains('指定的服务');
      return missing
          ? HelperStopOutcome.notInstalled
          : HelperStopOutcome.queryFailed;
    }

    if (parseServiceState(query.stdout.toString()) == 1) {
      return HelperStopOutcome.stopped;
    }

    if (await _waitForServiceStopped()) return HelperStopOutcome.stopped;

    // Acknowledged but never observed stopping. Reported as-is, never as a
    // success — the request may still be in flight inside the transport
    // isolate, and `Future.timeout` does not cancel it.
    return HelperStopOutcome.ackOnly;
  }

  /// B2 — the identity-specific half of the stop gate (C3).
  ///
  /// **Release / Dev**: only a service *this instance* started may be stopped.
  /// A `reused` service is left alone: it may belong to a previous session, an
  /// `auto` boot start, or the installer, and none of those are ours. The cost
  /// is that a crashed session's leftover keeps running until the next
  /// stop/start cycle — accepted, and the reason H2-C moved new installs to
  /// `start= demand`.
  ///
  /// **HostTest**: a dedicated identity whose service can only have been
  /// created for this test, so a `reused` service is still within its own
  /// lifecycle — but only while this process holds the per-identity
  /// single-instance lock, which is what rules out a second HostTest instance
  /// sharing it.
  ///
  /// Known limit, not fixed here: two *Release* instances can still race — the
  /// one that issued `sc start` will stop the service when it exits, even if
  /// the other is still using it. Windows has no single-instance lock in
  /// `main()` today, so this stays OPEN.
  static bool _ownsHelperService() {
    final isHostTest = hostTestOverrideForTest ?? AppIdentity.isHostTest;
    if (isHostTest) {
      return _helperStartIssuedByUs || (_helperReused && instanceLockHeld);
    }
    return _helperStartIssuedByUs;
  }

  /// Bounded SCM poll. 4 × 500 ms sits inside the exit path's budget
  /// (IPC 2 s + this 2 s < the 6 s the controller allows).
  Future<bool> _waitForServiceStopped() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final query = await _sc(['query', appHelperService]);
      if (query.exitCode != 0) continue;
      if (parseServiceState(query.stdout.toString()) == 1) return true;
    }
    return false;
  }

  Future<bool> registerTask(String appName) async {
    final executablePath = Platform.resolvedExecutable;
    final workingDirectory = dirname(executablePath);

    final taskXml =
        '''
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>开机自动启动代理服务</Description>
    <URI>\\$appName</URI>
  </RegistrationInfo>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>6</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>"$executablePath"</Command>
      <WorkingDirectory>$workingDirectory</WorkingDirectory>
    </Exec>
  </Actions>
</Task>''';
    final taskPath = join(await appPath.tempPath, 'task.xml');
    await File(taskPath).create(recursive: true);
    await File(
      taskPath,
    ).writeAsBytes(taskXml.encodeUtf16LeWithBom, flush: true);
    final commandLine = [
      '/Create',
      '/TN',
      appName,
      '/XML',
      '%s',
      '/F',
    ].join(' ');
    return runas('schtasks', commandLine.replaceFirst('%s', taskPath));
  }

  Future<bool> unregisterTask(String appName) async {
    final commandLine = ['/Delete', '/TN', appName, '/F'].join(' ');
    return runas('schtasks', commandLine);
  }
}

final windows = system.isWindows ? Windows() : null;

class MacOS {
  static MacOS? _instance;
  static const _dnsBackupFileName = 'macos_system_dns_backup.json';
  static const _hijackDns = '223.5.5.5';
  final Lock _dnsLock = Lock();

  MacOS._internal();

  factory MacOS() {
    _instance ??= MacOS._internal();
    return _instance!;
  }

  Future<String?> get defaultServiceName async {
    final result = await Process.run('route', ['-n', 'get', 'default']);
    final output = result.stdout.toString();
    final deviceLine = output
        .split('\n')
        .firstWhere((s) => s.contains('interface:'), orElse: () => '');
    final parts = deviceLine.trim().split(' ');
    if (parts.length != 2) return null;

    final device = parts[1];
    final serviceResult = await Process.run('networksetup', [
      '-listnetworkserviceorder',
    ]);
    final serviceOutput = serviceResult.stdout.toString();
    final currentService = serviceOutput
        .split('\n\n')
        .firstWhere((s) => s.contains('Device: $device'), orElse: () => '');
    if (currentService.isEmpty) return null;

    final serviceNameLine = currentService
        .split('\n')
        .firstWhere(
          (line) => RegExp(r'^\(\d+\).*').hasMatch(line),
          orElse: () => '',
        );
    final match = RegExp(
      r'^\(\d+\)\s+(.+)$',
    ).firstMatch(serviceNameLine.trim());
    return match?.group(1)?.trim();
  }

  Future<List<String>?> get systemDns async {
    final deviceServiceName = await defaultServiceName;
    if (deviceServiceName == null) return null;
    return _getSystemDns(deviceServiceName);
  }

  Future<List<String>?> _getSystemDns(String serviceName) async {
    final result = await Process.run('networksetup', [
      '-getdnsservers',
      serviceName,
    ]);
    if (result.exitCode != 0) {
      commonPrint.log(
        'Failed to get macOS system DNS: ${result.stderr.toString().trim()}',
      );
      return null;
    }
    final output = result.stdout.toString().trim();
    return output.startsWith("There aren't any DNS Servers set on")
        ? []
        : output.split('\n');
  }

  Future<void> updateDns(bool restore) {
    return _dnsLock.synchronized(() async {
      if (restore) {
        await _restoreDns();
      } else {
        await _setDns();
      }
    });
  }

  Future<void> _setDns() async {
    // Restore a previous managed value first so repeated enable operations never
    // overwrite the real system DNS backup with Fluxora's own hijack DNS.
    if (!await _restoreDns()) return;

    final serviceName = await defaultServiceName;
    if (serviceName == null) return;

    final currentDns = await _getSystemDns(serviceName);
    if (currentDns == null || currentDns.contains(_hijackDns)) return;

    final backup = jsonEncode({
      'serviceName': serviceName,
      'servers': currentDns,
    });
    try {
      final backupFile = await _dnsBackupFile;
      await backupFile.parent.create(recursive: true);
      final temporaryFile = File('${backupFile.path}.tmp');
      await temporaryFile.writeAsString(backup, flush: true);
      await temporaryFile.rename(backupFile.path);
    } catch (e) {
      commonPrint.log('Failed to persist the original macOS system DNS: $e');
      return;
    }

    final result = await Process.run('networksetup', [
      '-setdnsservers',
      serviceName,
      ...currentDns,
      _hijackDns,
    ]);
    if (result.exitCode != 0) {
      commonPrint.log(
        'Failed to set macOS system DNS: ${result.stderr.toString().trim()}',
      );
    }
  }

  Future<bool> _restoreDns() async {
    final backupFile = await _dnsBackupFile;
    if (!await backupFile.exists()) return true;

    try {
      final rawBackup = await backupFile.readAsString();
      final decodedBackup = jsonDecode(rawBackup);
      if (decodedBackup is! Map) {
        throw const FormatException('Invalid macOS system DNS backup');
      }
      final backup = Map<String, dynamic>.from(decodedBackup);
      final serviceName = backup['serviceName'] as String?;
      final servers = (backup['servers'] as List?)
          ?.whereType<String>()
          .toList();
      if (serviceName == null || serviceName.isEmpty || servers == null) {
        throw const FormatException('Invalid macOS system DNS backup');
      }

      final result = await Process.run('networksetup', [
        '-setdnsservers',
        serviceName,
        if (servers.isNotEmpty) ...servers,
        if (servers.isEmpty) 'Empty',
      ]);
      if (result.exitCode != 0) {
        commonPrint.log(
          'Failed to restore macOS system DNS: '
          '${result.stderr.toString().trim()}',
        );
        return false;
      }
      await backupFile.delete();
      return true;
    } catch (e) {
      commonPrint.log('Failed to read macOS system DNS backup: $e');
      return false;
    }
  }

  Future<File> get _dnsBackupFile async {
    return File(join(await appPath.homeDirPath, _dnsBackupFileName));
  }
}

/// Linux 上的系统 DNS 管理。
///
/// 走 systemd-resolved 的 `resolvectl`：主流发行版默认就是它，而且支持
/// **按链路**设置并 `revert` 回原状，不像直接改 /etc/resolv.conf 那样既需要
/// root、又会被各种工具覆盖回去。
///
/// 这里**刻意不用** `nmcli device modify` + `nmcli device reapply`：`reapply`
/// 不会重跑 DHCP，在 NetworkManager + iwd 的 DHCP 链路上会把物理网卡的 DNS 和
/// resolved 的 default-route 标志一起清空，用户看到的是"开 TUN 就整机断网，
/// 关掉也不恢复"（上游 Bettbox #598）。`resolvectl dns` 只动这一条链路的
/// resolver 列表，不碰 DHCP、不碰 default-route，坏掉时也只是回到原来的解析器。
///
/// 没有 `resolvectl` 的系统（非 systemd）报告"不支持"，界面上把开关置灰，
/// 而不是假装设置成功。
class LinuxSystemDns {
  static LinuxSystemDns? _instance;
  static const _hijackDns = '223.5.5.5';
  static const _backupFileName = 'linux_system_dns_backup.json';
  final Lock _lock = Lock();

  LinuxSystemDns._internal();

  factory LinuxSystemDns() {
    _instance ??= LinuxSystemDns._internal();
    return _instance!;
  }

  /// 默认路由所在的网卡。`resolvectl` 是按链路设置的，不指定链路就没法改。
  Future<String?> get defaultInterface async {
    try {
      final result = await Process.run('ip', ['route', 'show', 'default']);
      if (result.exitCode != 0) return null;
      final line = result.stdout
          .toString()
          .split('\n')
          .firstWhere((l) => l.contains(' dev '), orElse: () => '');
      return RegExp(r'dev\s+(\S+)').firstMatch(line)?.group(1);
    } catch (e) {
      commonPrint.log('Failed to read the default route: $e');
      return null;
    }
  }

  /// 当前环境能不能管 DNS。非 systemd 的系统返回 false。
  Future<bool> get isSupported async {
    try {
      final result = await Process.run('sh', ['-c', 'command -v resolvectl']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// 链路是否还存在。
  ///
  /// 备份里记的是**网卡名**，而网卡会变：Wi-Fi 换有线、USB 网卡拔掉、systemd
  /// 给无线链路改名（`wlp3s0` → `wlan0`）。对一条已经不存在的链路执行
  /// `resolvectl dns <old> ...` 必然失败，而 [_setDns] 在开头就把还原当成前置
  /// 条件——一次失败会让「自动设置系统 DNS」永久变成空操作，直到有人手动删掉
  /// 备份文件。所以这里先判断链路在不在。
  Future<bool> _linkExists(String iface) async {
    try {
      final result = await Process.run('ip', ['link', 'show', iface]);
      return result.exitCode == 0;
    } catch (e) {
      commonPrint.log('Failed to probe the link $iface: $e');
      // 探测不了不代表链路没了；宁可保持原来的失败行为，也不要假装还原成功。
      return true;
    }
  }

  Future<void> updateDns(bool restore) {
    return _lock.synchronized(() async {
      if (restore) {
        await _restoreDns();
      } else {
        await _setDns();
      }
    });
  }

  Future<List<String>?> _currentDns(String iface) async {
    try {
      final result = await Process.run('resolvectl', ['dns', iface]);
      if (result.exitCode != 0) return null;
      return parseDnsOutput(result.stdout.toString(), iface);
    } catch (e) {
      commonPrint.log('Failed to read the Linux system DNS: $e');
      return null;
    }
  }

  /// 解析 `resolvectl dns <iface>` 的输出，抽成纯函数方便测试。
  ///
  /// 输出形如：
  /// ```
  /// Global: 8.8.8.8
  /// Link 2 (wlan0): 192.168.1.1 223.5.5.5
  /// ```
  /// 找不到对应链路返回 null，和"这条链路本来就没有 DNS"（空列表）区分开。
  @visibleForTesting
  static List<String>? parseDnsOutput(String output, String iface) {
    final line = output
        .split('\n')
        .firstWhere((l) => l.contains('($iface)'), orElse: () => '');
    if (line.isEmpty) return null;
    final colon = line.indexOf(':');
    if (colon < 0) return null;
    return line
        .substring(colon + 1)
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _setDns() async {
    // 先还原一次：重复开启时不能把 Fluxora 自己写进去的值当成"原始 DNS"存下来。
    if (!await _restoreDns()) return;

    final iface = await defaultInterface;
    if (iface == null) {
      commonPrint.log('Linux DNS: no default interface, skipping');
      return;
    }
    final current = await _currentDns(iface);
    if (current == null || current.contains(_hijackDns)) return;

    try {
      final backupFile = await _dnsBackupFile;
      await backupFile.parent.create(recursive: true);
      final temporaryFile = File('${backupFile.path}.tmp');
      await temporaryFile.writeAsString(
        jsonEncode({'interface': iface, 'servers': current}),
        flush: true,
      );
      await temporaryFile.rename(backupFile.path);
    } catch (e) {
      commonPrint.log('Failed to persist the original Linux system DNS: $e');
      return;
    }

    final result = await Process.run('resolvectl', [
      'dns',
      iface,
      ...current,
      _hijackDns,
    ]);
    if (result.exitCode != 0) {
      commonPrint.log(
        'Failed to set the Linux system DNS: '
        '${result.stderr.toString().trim()}',
      );
      return;
    }
    await Process.run('resolvectl', ['flush-caches']);
  }

  Future<bool> _restoreDns() async {
    final backupFile = await _dnsBackupFile;
    if (!await backupFile.exists()) return true;

    try {
      final decoded = jsonDecode(await backupFile.readAsString());
      if (decoded is! Map) {
        throw const FormatException('Invalid Linux system DNS backup');
      }
      final backup = Map<String, dynamic>.from(decoded);
      final iface = backup['interface'] as String?;
      final servers = (backup['servers'] as List?)
          ?.whereType<String>()
          .toList();
      if (iface == null || iface.isEmpty || servers == null) {
        throw const FormatException('Invalid Linux system DNS backup');
      }

      // 链路已经没了：没有东西可还原，直接丢弃这份备份。留着它只会让下一次
      // [_setDns] 永远卡在还原这一步。
      if (!await _linkExists(iface)) {
        commonPrint.log(
          'Linux DNS: link $iface no longer exists, discarding the backup',
        );
        await backupFile.delete();
        return true;
      }

      // 原本没有 DNS 就 revert 回链路默认，而不是塞一个空列表进去。
      final result = servers.isEmpty
          ? await Process.run('resolvectl', ['revert', iface])
          : await Process.run('resolvectl', ['dns', iface, ...servers]);
      if (result.exitCode != 0) {
        commonPrint.log(
          'Failed to restore the Linux system DNS: '
          '${result.stderr.toString().trim()}',
        );
        return false;
      }
      await backupFile.delete();
      return true;
    } catch (e) {
      commonPrint.log('Failed to read the Linux system DNS backup: $e');
      return false;
    }
  }

  Future<File> get _dnsBackupFile async {
    return File(join(await appPath.homeDirPath, _backupFileName));
  }
}

final linuxSystemDns = system.isLinux ? LinuxSystemDns() : null;

final macOS = system.isMacOS ? MacOS() : null;
