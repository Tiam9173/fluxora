import 'dart:convert';

import 'package:fluxora/clash/lib.dart';
import 'package:fluxora/common/constant.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:flutter/services.dart';

Future<Object?> Function(MethodCall) switchCardHandler(
  Future<String> Function(String) invokeAction, {
  int Function()? testTimeoutMillis,
}) {
  var sequence = 0;
  Future<String> invoke(
    ActionMethod method, [
    Map<String, Object>? data,
  ]) async {
    final raw = await invokeAction(
      jsonEncode(
        Action(
          method: method,
          id: 'notification-card-${sequence++}',
          data: data == null ? null : jsonEncode(data),
        ),
      ),
    );
    final result = decodeActionResultData(raw);
    if (result == null) {
      throw PlatformException(code: 'CORE_UNAVAILABLE');
    }
    return result;
  }

  return (call) async {
    final args = call.arguments;
    String? argument(String key) {
      final value = args is Map ? args[key] : null;
      return value is String ? value : null;
    }

    switch (call.method) {
      case 'groups':
        final proxies =
            jsonDecode(await invoke(ActionMethod.getProxies)) as Map;
        final providers =
            jsonDecode(await invoke(ActionMethod.getExternalProviders)) as List;
        final ambiguousNames = <String>{};
        for (final provider in providers.whereType<Map>()) {
          for (final proxy
              in (provider['proxies'] as List? ?? []).whereType<Map>()) {
            final name = proxy['name'];
            if (name is! String) continue;
            if (proxies.containsKey(name)) {
              ambiguousNames.add(name);
            } else {
              proxies[name] = proxy;
            }
          }
        }
        // 同名节点的历史无法按组归属；等待带分组的实际测速结果。
        for (final name in ambiguousNames) {
          if (proxies[name] case final Map detail) {
            proxies[name] = {...detail, 'history': []};
          }
        }
        return jsonEncode(proxies);
      case 'select':
      case 'unlock':
        final name = call.method == 'select' ? argument('node') : '';
        final group = argument('group');
        if (group == null ||
            group.isEmpty ||
            name == null ||
            (call.method == 'select' && name.isEmpty)) {
          throw PlatformException(code: 'INVALID_SELECTION');
        }
        final message = await invoke(ActionMethod.changeProxy, {
          'group-name': group,
          'proxy-name': name,
          'persist': true,
        });
        if (message.isNotEmpty) {
          throw PlatformException(code: 'SELECT_FAILED', message: message);
        }
        return null;
      case 'delay':
        final name = argument('node');
        final url = argument('url');
        if (name == null || name.isEmpty || url == null) {
          throw PlatformException(code: 'INVALID_TEST');
        }
        final result = await invoke(ActionMethod.asyncTestDelay, {
          'proxy-name': name,
          'test-url': url,
          'group-name': ?argument('group'),
          'timeout':
              testTimeoutMillis?.call() ?? delayTestTimeout.inMilliseconds,
        });
        return Delay.fromJson(
              jsonDecode(result) as Map<String, dynamic>,
            ).value ??
            -1;
      default:
        throw MissingPluginException();
    }
  };
}
