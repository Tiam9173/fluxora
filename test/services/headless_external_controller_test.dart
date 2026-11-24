import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final allowLan in [false, true]) {
    test('proxy allow-lan=$allowLan does not change the controller bind', () {
      for (final configured in ExternalControllerStatus.values) {
        final rawConfig = <String, dynamic>{
          'allow-lan': allowLan,
          'external-controller': '0.0.0.0:9090',
          'secret': 'profile-secret',
        };
        final result = applyExternalControllerConfig(
          rawConfig,
          configured: configured,
          forceLoopback: true,
          sessionController: '127.0.0.1:19091',
        );

        expect(result, (endpoint: '127.0.0.1:19091', secret: 'profile-secret'));
        expect(rawConfig['external-controller'], result.endpoint);
        expect(rawConfig['secret'], result.secret);
        expect(rawConfig['allow-lan'], allowLan);
      }
    });
  }

  test('controller settings and native clients share the effective secret', () {
    final rawConfig = <String, dynamic>{'secret': 'profile-secret'};
    final result = applyExternalControllerConfig(
      rawConfig,
      configured: ExternalControllerStatus.open,
      forceLoopback: false,
      configuredSecret: 'app-secret',
    );

    expect(result.endpoint, ExternalControllerStatus.open.value);
    expect(result.secret, 'app-secret');
    expect(rawConfig['secret'], result.secret);
  });

  test(
    'disabled controller clears a profile endpoint even with LAN enabled',
    () {
      final rawConfig = <String, dynamic>{
        'allow-lan': true,
        'external-controller': '0.0.0.0:9090',
      };
      final result = applyExternalControllerConfig(
        rawConfig,
        configured: ExternalControllerStatus.close,
        forceLoopback: false,
        sessionController: '127.0.0.1:19091',
      );

      expect(result, (endpoint: '', secret: ''));
      expect(rawConfig['external-controller'], isEmpty);
    },
  );

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
