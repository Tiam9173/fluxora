import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/plugins/service.dart';
import 'package:fluxora/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('service');
  bool? mockStatusResult;
  bool shouldThrow = false;
  int methodCallCount = 0;
  Completer<void>? firstStatus;

  setUp(() {
    System.platformOverride = 'android';
    globalState.testStartTimeOverride = DateTime.now();
    globalState.appState = AppState(
      brightness: Brightness.light,
      version: 1,
      viewSize: Size.zero,
      requests: FixedList(100),
      logs: FixedList(100),
      traffics: FixedList(30),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    globalState.startTime = null;
    mockStatusResult = null;
    shouldThrow = false;
    methodCallCount = 0;
    firstStatus = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'startVpn') return true;
          if (call.method == 'status') {
            methodCallCount++;
            if (firstStatus?.isCompleted == false) firstStatus!.complete();
            if (shouldThrow) {
              throw PlatformException(code: 'ERROR', message: 'Test Exception');
            }
            return mockStatusResult;
          }
          return null;
        });
  });

  tearDown(() {
    System.platformOverride = null;
    globalState.testStartTimeOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    globalState.stopUpdateTasks();
  });

  test(
    'start waits for native readiness after accepting the request',
    () async {
      System.platformOverride = 'windows';
      firstStatus = Completer<void>();
      var completed = false;
      final pending = Service()
          .waitForVpnStart(pollInterval: const Duration(milliseconds: 5))
          .whenComplete(() => completed = true);
      await firstStatus!.future;
      expect(completed, isFalse);
      mockStatusResult = true;
      expect(await pending, isTrue);
      expect(methodCallCount, greaterThan(1));
    },
  );

  test('cancellation returns without waiting for native readiness', () async {
    System.platformOverride = 'windows';
    firstStatus = Completer<void>();
    final cancel = Completer<void>();
    final pending = Service().waitForVpnStart(cancellation: cancel.future);
    await firstStatus!.future;
    cancel.complete();
    expect(await pending, isFalse);
  });

  // A. VPN Status true
  test('A. syncs VPN runtime state when native status is true', () async {
    mockStatusResult = true;

    expect(globalState.appState.runTime, isNull);
    expect(globalState.startTime, isNull);

    await globalState.testSyncVpnState();

    expect(methodCallCount, greaterThan(0));
    expect(globalState.appState.runTime, 0);
    expect(globalState.startTime, isNotNull);
  });

  // B. VPN Status false
  test('B. clears VPN runtime state when native status is false', () async {
    // Set initial flutter state to running
    globalState.appState = globalState.appState.copyWith(runTime: 100);
    globalState.startTime = DateTime.now();

    mockStatusResult = false;

    await globalState.testSyncVpnState();

    expect(methodCallCount, greaterThan(0));
    expect(globalState.appState.runTime, isNull);
    expect(globalState.startTime, isNull);
  });

  // C. VPN Status null
  test('C. handles null native VPN status (fallback to false)', () async {
    // Set initial flutter state to running
    globalState.appState = globalState.appState.copyWith(runTime: 100);
    globalState.startTime = DateTime.now();

    mockStatusResult = null; // null from MethodChannel

    await globalState.testSyncVpnState();

    expect(methodCallCount, greaterThan(0));
    // Null defaults to false, so it clears the state
    expect(globalState.appState.runTime, isNull);
    expect(globalState.startTime, isNull);
  });

  // D. VPN Status exception
  test('D. preserves state when native status throws', () async {
    // Set initial flutter state to running
    globalState.appState = globalState.appState.copyWith(runTime: 100);
    final initialStartTime = DateTime.now();
    globalState.startTime = initialStartTime;

    shouldThrow = true;

    await globalState.testSyncVpnState();

    expect(methodCallCount, greaterThan(0));
    // Error is caught, state is preserved
    expect(globalState.appState.runTime, 100);
    expect(globalState.startTime, initialStartTime);
  });

  // E. Non-Android
  test('E. returns early on non-Android platforms', () async {
    System.platformOverride = 'windows'; // Bypass Android check

    // Set initial flutter state to running
    globalState.appState = globalState.appState.copyWith(runTime: 100);

    await globalState.testSyncVpnState();

    // Method channel should never be called
    expect(methodCallCount, 0);
    // State is unchanged
    expect(globalState.appState.runTime, 100);
  });
}
