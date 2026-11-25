import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/controller.dart';

void main() {
  test('resumes a VPN interrupted by an app update without auto-run', () {
    expect(
      shouldStartAfterAppRecovery(
        hasProfile: true,
        isRunning: false,
        autoRun: false,
        needsRecovery: true,
      ),
      isTrue,
    );
  });

  test('does not resume a stopped VPN without auto-run or recovery', () {
    expect(
      shouldStartAfterAppRecovery(
        hasProfile: true,
        isRunning: false,
        autoRun: false,
        needsRecovery: false,
      ),
      isFalse,
    );
  });

  test('does not start without a selected profile', () {
    expect(
      shouldStartAfterAppRecovery(
        hasProfile: false,
        isRunning: false,
        autoRun: true,
        needsRecovery: true,
      ),
      isFalse,
    );
  });
}
