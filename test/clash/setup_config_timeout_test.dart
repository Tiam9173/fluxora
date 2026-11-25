import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';

class _UnresponsiveCore extends ClashHandlerInterface {
  _UnresponsiveCore([this.expectedMethod = ActionMethod.setupConfig]);
  final ActionMethod expectedMethod;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();

  @override
  void sendMessage(String message) {}

  @override
  Future<T> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
    FutureOr<T> Function()? onTimeout,
    T? defaultValue,
  }) async {
    expect(method, expectedMethod);
    return await onTimeout!();
  }
}

class _BrokenTransportCore extends ClashHandlerInterface {
  @override
  bool get hasLiveProcess => true;

  @override
  Future<bool> preload() async => true;

  @override
  void sendMessage(String message) => throw StateError('IPC unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test(
    'missing subscription read acknowledgement is not an empty valid config',
    () async {
      await expectLater(
        _UnresponsiveCore(
          ActionMethod.getConfig,
        ).getConfig('isolated-fixture.yaml'),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
  test(
    'missing setup acknowledgement is an error, never empty success',
    () async {
      await expectLater(
        _UnresponsiveCore().setupConfig(
          const SetupParams(
            selectedMap: {},
            testUrl: 'https://example.invalid',
          ),
        ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test(
    'IPC send failures reach the request without waiting for its timeout',
    () async {
      await expectLater(
        _BrokenTransportCore().getConfig('isolated-fixture.yaml'),
        throwsA(isA<StateError>()),
      );
    },
  );
}
