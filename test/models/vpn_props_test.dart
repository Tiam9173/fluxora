import 'dart:convert';

import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VpnProps 托盘点击行为', () {
    test('默认保留托盘增强关闭，左键显示面板、右键显示菜单', () {
      const props = VpnProps();

      expect(props.trayEnhancement, isFalse);
      expect(props.trayLeftClickBehavior, TrayClickBehavior.showPanel);
      expect(props.trayRightClickBehavior, TrayClickBehavior.showMenu);
    });

    test('序列化后能够独立恢复左右键设置及托盘增强设置', () {
      const props = VpnProps(
        trayEnhancement: true,
        trayLeftClickBehavior: TrayClickBehavior.showMenu,
        trayRightClickBehavior: TrayClickBehavior.showPanel,
      );

      final restored = VpnProps.fromJson(
        jsonDecode(jsonEncode(props.toJson())) as Map<String, dynamic>,
      );

      expect(restored.trayEnhancement, isTrue);
      expect(restored.trayLeftClickBehavior, TrayClickBehavior.showMenu);
      expect(restored.trayRightClickBehavior, TrayClickBehavior.showPanel);
    });
  });

  group('VpnProps 端口避让通知', () {
    test('默认关闭——避让本身静默生效，不弹提示', () {
      const props = VpnProps();

      // 避让开关默认是开的（否则端口被占内核直接起不来），但「告诉用户」
      // 默认是关的：普通用户不需要知道会话换了端口。
      expect(props.portFallback, isTrue);
      expect(props.controllerPortFallback, isTrue);
      expect(props.portFallbackNotice, isFalse);
    });

    test('打开后能序列化并恢复', () {
      const props = VpnProps(portFallbackNotice: true);

      final restored = VpnProps.fromJson(
        jsonDecode(jsonEncode(props.toJson())) as Map<String, dynamic>,
      );

      expect(restored.portFallbackNotice, isTrue);
    });

    test('旧配置文件没有这个字段时回落到默认关，而不是读崩', () {
      final restored = VpnProps.fromJson(<String, dynamic>{'enable': true});

      expect(restored.portFallbackNotice, isFalse);
    });
  });
}
