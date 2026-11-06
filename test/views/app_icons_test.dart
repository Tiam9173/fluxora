import 'dart:async';
import 'dart:convert';

import 'package:fluxora/common/brand_icons.dart';
import 'package:fluxora/common/constant.dart';
import 'package:fluxora/common/preferences.dart';
import 'package:fluxora/common/system.dart';
import 'package:fluxora/common/utils.dart';
import 'package:fluxora/models/config.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late SharedPreferences store;
  late List<MethodCall> calls;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await preferences.sharedPreferencesCompleter.future;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await SharedPreferences.getInstance();
    preferences.sharedPreferencesCompleter = Completer<SharedPreferences?>()
      ..complete(store);
    globalState.config = const Config(
      themeProps: ThemeProps(themeMode: ThemeMode.dark),
    );
    System.platformOverride = 'windows';
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getLauncherIcon') {
        return {'style': 'official', 'useDarkIcon': false};
      }
      return true;
    });
  });

  tearDown(() {
    System.platformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<ProviderContainer> show(
    WidgetTester tester, {
    double scale = 1,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(body: AppIconsView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> apply(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('apply-icon'));
    await tester.ensureVisible(button);
    await tester.runAsync(() async {
      await tester.tap(button);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
  }

  test('old configurations keep their dark flag and default to official', () {
    final old = ThemeProps.safeFromJson({'useDarkIcon': true});
    expect(old.appIconStyle, 'official');
    expect(old.useDarkIcon, isTrue);
    expect(BrandIcons.normalize('../../custom'), 'official');
    for (final style in BrandIcons.styles.keys) {
      for (final dark in [false, true]) {
        final props = ThemeProps(appIconStyle: style, useDarkIcon: dark);
        final restored = ThemeProps.fromJson(jsonDecode(jsonEncode(props)));
        expect(restored, props);
      }
    }
  });

  testWidgets(
    'preview is independent, desktop apply persists, reopening restores',
    (tester) async {
      final container = await show(tester);
      await tester.tap(find.byKey(const ValueKey('icon-style-premium')));
      await tester.tap(find.byKey(const ValueKey('icon-mode-true')));
      await tester.pumpAndSettle();
      expect(container.read(themeSettingProvider).appIconStyle, 'official');
      expect(store.getString(configKey), isNull);
      expect(calls, isEmpty);
      await apply(tester);
      expect(container.read(themeSettingProvider).appIconStyle, 'premium');
      expect(container.read(themeSettingProvider).useDarkIcon, isTrue);
      expect(container.read(themeSettingProvider).themeMode, ThemeMode.dark);
      final saved =
          jsonDecode(store.getString(configKey)!) as Map<String, dynamic>;
      expect(saved['themeProps']['appIconStyle'], 'premium');
      expect(saved['themeProps']['useDarkIcon'], isTrue);
      expect(
        calls,
        isEmpty,
        reason: 'Desktop must never claim to change a system icon',
      );
      await tester.pumpWidget(const SizedBox());
      await show(tester);
      expect(find.text('Current: Premium · Dark'), findsOneWidget);
    },
  );

  testWidgets(
    '320px and double text scale keeps all eight options accessible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, scale: 2);
      for (final style in BrandIcons.styles.keys) {
        expect(find.byKey(ValueKey('icon-style-$style')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Android queries real alias before enabling apply', (
    tester,
  ) async {
    System.platformOverride = 'android';
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return {'style': 'blue_night', 'useDarkIcon': true};
    });
    final container = await show(tester);
    expect(container.read(themeSettingProvider).appIconStyle, 'blue_night');
    expect(find.text('Current: Blue night · Dark'), findsOneWidget);
    expect(calls.map((c) => c.method), ['getLauncherIcon']);
  });

  testWidgets('Android native success saves only after explicit apply', (
    tester,
  ) async {
    System.platformOverride = 'android';
    final container = await show(tester);
    await tester.tap(find.byKey(const ValueKey('icon-style-classic')));
    await tester.pumpAndSettle();
    await apply(tester);
    expect(container.read(themeSettingProvider).appIconStyle, 'classic');
    expect(calls.last.method, 'setLauncherIcon');
    expect(calls.last.arguments, {'style': 'classic', 'useDarkIcon': false});
    expect(
      jsonDecode(store.getString(configKey)!)['themeProps']['appIconStyle'],
      'classic',
    );
  });

  testWidgets(
    'Android rejection leaves current and saved selection unchanged',
    (tester) async {
      System.platformOverride = 'android';
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getLauncherIcon') {
          return {'style': 'official', 'useDarkIcon': false};
        }
        throw PlatformException(code: 'ICON_CHANGE_FAILED');
      });
      final container = await show(tester);
      await tester.tap(find.byKey(const ValueKey('icon-style-aqua')));
      await tester.pumpAndSettle();
      await apply(tester);
      expect(container.read(themeSettingProvider).appIconStyle, 'official');
      expect(store.getString(configKey), isNull);
      expect(find.textContaining('Icon setting failed'), findsOneWidget);
    },
  );

  testWidgets('failed persistence rolls native selection back', (tester) async {
    System.platformOverride = 'android';
    final container = await show(tester);
    await tester.runAsync(() async {
      preferences.sharedPreferencesCompleter = Completer<SharedPreferences?>()
        ..complete(null);
    });
    await tester.tap(find.byKey(const ValueKey('icon-style-speed')));
    await tester.pumpAndSettle();
    await apply(tester);
    final changes = calls.where((c) => c.method == 'setLauncherIcon').toList();
    expect(changes.map((c) => (c.arguments as Map)['style']), [
      'speed',
      'official',
    ]);
    expect(container.read(themeSettingProvider).appIconStyle, 'official');
    expect(find.textContaining('Unable to save'), findsOneWidget);
  });

  testWidgets('unreadable Android selection disables apply and offers retry', (
    tester,
  ) async {
    System.platformOverride = 'android';
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'QUERY_FAILED'),
    );
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('icon-style-classic')));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('apply-icon')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Last saved: Official · Light'), findsOneWidget);
    expect(find.text('Retry reading system icon'), findsOneWidget);
  });

  testWidgets('a failed rollback displays the actual system choice', (
    tester,
  ) async {
    System.platformOverride = 'android';
    var actual = 'official';
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getLauncherIcon') {
        return {'style': actual, 'useDarkIcon': false};
      }
      final requested = (call.arguments as Map)['style'] as String;
      if (requested == 'official') {
        throw PlatformException(code: 'ROLLBACK_FAILED');
      }
      actual = requested;
      return true;
    });
    final container = await show(tester);
    await tester.runAsync(() async {
      preferences.sharedPreferencesCompleter = Completer<SharedPreferences?>()
        ..complete(null);
    });
    await tester.tap(find.byKey(const ValueKey('icon-style-aqua')));
    await tester.pumpAndSettle();
    await apply(tester);
    expect(container.read(themeSettingProvider).appIconStyle, 'aqua');
    expect(find.text('Current: Aqua · Light'), findsOneWidget);
    expect(find.textContaining('ROLLBACK_FAILED'), findsOneWidget);
    expect(store.getString(configKey), isNull);
  });

  test('tray paths use dedicated alpha icons on all desktop platforms', () {
    for (final platform in ['windows', 'linux', 'macos']) {
      System.platformOverride = platform;
      final suffix = platform == 'windows' ? 'ico' : 'png';
      for (final active in [true, false]) {
        final file = utils.getTrayIconPath(
          brightness: Brightness.dark,
          isStart: active,
        );
        expect(file, endsWith('.$suffix'));
        expect(file, isNot('assets/images/icon.png'));
        expect(file, isNot('assets/images/icon_light.png'));
        if (!active) expect(file, contains('stopped'));
      }
    }
    System.platformOverride = 'windows';
    expect(
      utils.getTrayIconPath(
        brightness: Brightness.dark,
        isStart: true,
        invertTrayIcon: true,
      ),
      'assets/images/icon_black.ico',
    );
  });
}
