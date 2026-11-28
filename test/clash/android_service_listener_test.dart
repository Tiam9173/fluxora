import 'dart:async';
import 'dart:convert';

import 'package:fluxora/clash/generated/clash_ffi.dart';
import 'package:fluxora/clash/lib.dart';
import 'package:flutter_test/flutter_test.dart';

class _SynchronousStopTrap extends Fake implements ClashFFI {
  @override
  void stopListener() =>
      throw StateError('Synchronous native stop would block');
}

class _ServiceCore extends ClashLibHandler {
  _ServiceCore() : super.withBindings(_SynchronousStopTrap());

  final response = Completer<String>();
  Map<String, dynamic>? request;

  @override
  Future<String> invokeAction(String actionParams, {Duration? timeout}) {
    request = jsonDecode(actionParams) as Map<String, dynamic>;
    return response.future.timeout(timeout!);
  }
}

void main() {
  test(
    'headless listener stop keeps the event loop responsive until ack',
    () async {
      final core = _ServiceCore();
      var completed = false;
      final stopping = core.stopListener().whenComplete(() => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(core.request?['method'], 'stopListener');
      core.response.complete('{"code":0,"data":true}');
      expect(await stopping, isTrue);
    },
  );

  test('headless listener stop retains native failure', () async {
    final core = _ServiceCore();
    core.response.complete('{"code":-1,"data":true}');
    expect(await core.stopListener(), isFalse);
  });

  test(
    'headless listener stop has a bounded wait without a native reply',
    () async {
      final core = _ServiceCore();
      await expectLater(
        core.stopListener().timeout(const Duration(seconds: 4)),
        throwsA(
          isA<TimeoutException>().having(
            (error) => error.duration,
            'native reply deadline',
            const Duration(seconds: 3),
          ),
        ),
      );
    },
  );
}
