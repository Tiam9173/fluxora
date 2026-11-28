import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/plugins/notification_switch_transport.dart';

void main() {
  test(
    'duplicate provider names do not display another source history',
    () async {
      final handle = switchCardHandler((raw) async {
        final action = jsonDecode(raw) as Map;
        return jsonEncode({
          'code': 0,
          'data': switch (action['method']) {
            'getProxies' => {
              'Group': {
                'all': ['same'],
              },
            },
            'getExternalProviders' => jsonEncode([
              {
                'proxies': [
                  {
                    'name': 'same',
                    'history': [
                      {'delay': 22},
                    ],
                  },
                ],
              },
              {
                'proxies': [
                  {
                    'name': 'same',
                    'history': [
                      {'delay': 900},
                    ],
                  },
                ],
              },
            ]),
            _ => throw StateError('unexpected action'),
          },
        });
      });
      final result = jsonDecode(
        await handle(const MethodCall('groups')) as String,
      );
      expect(result['same']['history'], isEmpty);
      expect(result['Group']['all'], ['same']);
    },
  );

  test(
    'notification test respects the configured application timeout',
    () async {
      final handle = switchCardHandler((raw) async {
        final action = jsonDecode(raw) as Map;
        expect(jsonDecode(action['data'] as String)['timeout'], 20000);
        return jsonEncode({
          'code': 0,
          'data': jsonEncode({
            'name': 'node',
            'value': -1,
            'url': 'https://fixture.invalid',
          }),
        });
      }, testTimeoutMillis: () => 20000);
      expect(
        await handle(
          const MethodCall('delay', {
            'node': 'node',
            'url': 'https://fixture.invalid',
          }),
        ),
        -1,
      );
    },
  );

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
            'getExternalProviders' =>
              '[{"proxies":[{"name":"节点 A+ B","history":[{"delay":28}]}]}]',
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
        '节点 A+ B': {
          'name': '节点 A+ B',
          'history': [
            {'delay': 28},
          ],
        },
      });
      expect(await handle(const MethodCall('select', selection)), isNull);
      expect(await handle(const MethodCall('unlock', group)), isNull);
      expect(
        await handle(
          const MethodCall('delay', {
            'node': '节点 A+ B',
            'group': '测试 / 策略',
            'url': 'https://fixture.invalid',
          }),
        ),
        28,
      );
      expect(actions.map((action) => action['method']), [
        'getProxies',
        'getExternalProviders',
        'changeProxy',
        'changeProxy',
        'asyncTestDelay',
      ]);
      expect(jsonDecode(actions[2]['data'] as String), {
        'group-name': '测试 / 策略',
        'proxy-name': '节点 A+ B',
        'persist': true,
      });
      expect(jsonDecode(actions[3]['data'] as String)['proxy-name'], '');
      expect(jsonDecode(actions[4]['data'] as String)['timeout'], 10000);
      expect(jsonDecode(actions[4]['data'] as String)['group-name'], '测试 / 策略');
      await expectLater(
        handle(const MethodCall('shutdown')),
        throwsA(isA<MissingPluginException>()),
      );
      await expectLater(
        handle(const MethodCall('select', group)),
        throwsA(isA<PlatformException>()),
      );
      expect(actions, hasLength(5));
    },
  );
}
