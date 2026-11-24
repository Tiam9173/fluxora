import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/plugins/notification_switch_transport.dart';

void main() {
  test(
    'notification card uses internal actions with exact node names',
    () async {
      final actions = <Map<String, dynamic>>[];
      final handle = switchCardHandler((raw) async {
        final action = jsonDecode(raw) as Map<String, dynamic>;
        actions.add(action);
        return jsonEncode({
          'code': 0,
          'data': switch (action['method']) {
            'getProxies' => {
              'group': {
                'all': ['节点 A+ B'],
              },
            },
            'asyncTestDelay' =>
              '{"name":"节点 A+ B","url":"https://fixture.invalid","value":28}',
            _ => '',
          },
        });
      });
      const group = {'group': '测试 / 策略'};
      const selection = {...group, 'node': '节点 A+ B'};
      expect(jsonDecode((await handle(const MethodCall('groups'))) as String), {
        'group': {
          'all': ['节点 A+ B'],
        },
      });
      expect(await handle(const MethodCall('select', selection)), isNull);
      expect(await handle(const MethodCall('unlock', group)), isNull);
      expect(
        await handle(
          const MethodCall('delay', {
            'node': '节点 A+ B',
            'url': 'https://fixture.invalid',
          }),
        ),
        28,
      );
      expect(actions.map((action) => action['method']), [
        'getProxies',
        'changeProxy',
        'changeProxy',
        'asyncTestDelay',
      ]);
      expect(jsonDecode(actions[1]['data'] as String), {
        'group-name': '测试 / 策略',
        'proxy-name': '节点 A+ B',
        'persist': true,
      });
      expect(jsonDecode(actions[2]['data'] as String)['proxy-name'], '');
      await expectLater(
        handle(const MethodCall('shutdown')),
        throwsA(isA<MissingPluginException>()),
      );
      await expectLater(
        handle(const MethodCall('select', group)),
        throwsA(isA<PlatformException>()),
      );
      expect(actions, hasLength(4));
    },
  );
}
