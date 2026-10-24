import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('headless default forceLoopback resolves without AppController', () {
    expect(globalState.hasAppController, isFalse);
    expect(globalState.sessionExternalController, isNull);

    final value = resolveExternalControllerValue(
      configured: ExternalControllerStatus.close,
      forceLoopback: true,
      sessionController: globalState.sessionExternalController,
    );

    expect(value, ExternalControllerStatus.open.value);
  });

  test('UI session fallback endpoint is preserved', () {
    final value = resolveExternalControllerValue(
      configured: ExternalControllerStatus.open,
      forceLoopback: true,
      sessionController: '127.0.0.1:19091',
    );

    expect(value, '127.0.0.1:19091');
  });

  test('closed controller stays closed when forceLoopback is disabled', () {
    final value = resolveExternalControllerValue(
      configured: ExternalControllerStatus.close,
      forceLoopback: false,
    );

    expect(value, ExternalControllerStatus.close.value);
  });

  test('headless forceLoopback also overrides a closed configured value', () {
    final value = resolveExternalControllerValue(
      configured: ExternalControllerStatus.close,
      forceLoopback: true,
    );

    expect(value, ExternalControllerStatus.open.value);
  });
}
