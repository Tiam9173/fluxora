import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:fluxora/common/brand_icons.dart';
import 'package:fluxora/common/constant.dart';
import 'package:fluxora/common/preferences.dart';
import 'package:fluxora/common/system.dart';
import 'package:fluxora/common/utils.dart';
import 'package:fluxora/models/config.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/app_icons.dart';
import 'package:fluxora/views/about.dart';
import 'package:fluxora/widgets/app_brand_icon.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/render_capture.dart';

class _IconPicker extends FilePicker {
  String? path;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final selected = path;
    return selected == null
        ? null
        : FilePickerResult([
            PlatformFile(name: 'selected', size: 0, path: selected),
          ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late SharedPreferences store;
  late List<MethodCall> calls;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
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
    ProviderContainer? scope,
  }) async {
    final container = scope ?? ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (_, child) => RepaintBoundary(
            key: const ValueKey('icon-overlay-capture'),
            child: child,
          ),
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'HarmonyOS_Sans',
          ),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const RepaintBoundary(
              key: ValueKey('icon-settings-capture'),
              child: Scaffold(body: AppIconsView()),
            ),
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

  testWidgets('custom icon validates input, persists and restores the preset', (
    tester,
  ) async {
    final files = _IconPicker()..path = BrandIcons.asset('sunset', false);
    FilePicker.platform = files;
    final imported = await tester.runAsync(() async {
      final storeContainer = ProviderContainer();
      try {
        await storeContainer.read(customAppIconProvider.future);
        final icons = storeContainer.read(customAppIconProvider.notifier);
        await icons.pick();
        final imported = storeContainer
            .read(customAppIconProvider)
            .asData
            ?.value;
        files.path = 'pubspec.yaml';
        await expectLater(icons.pick(), throwsA(anything));
        expect(
          storeContainer.read(customAppIconProvider).asData?.value,
          imported,
        );
        return imported;
      } finally {
        storeContainer.dispose();
      }
    });
    expect(imported, isNotNull);
    final container = ProviderContainer();
    final restored = await tester.runAsync(
      () => container.read(customAppIconProvider.future),
    );
    expect(restored, imported);
    await show(tester, scope: container);
    expect(find.byKey(const ValueKey('remove-app-icon')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is ResizeImage &&
            (widget.image as ResizeImage).imageProvider is MemoryImage,
      ),
      findsOneWidget,
    );
    if (const bool.fromEnvironment('AURORA_CAPTURE')) {
      await tester.runAsync(() async {
        for (final element in tester.elementList(find.byType(Image))) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pump();
      await captureFlutterFrame(
        tester,
        find.byKey(const ValueKey('icon-settings-capture')),
        'build/aurora_refresh/captures/custom-app-icon.png',
      );
    }

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('remove-app-icon')));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(store.containsKey(customSidebarIconKey), isFalse);
    expect(container.read(customAppIconProvider).asData?.value, isNull);
  });

  test(
    'notification styles round-trip without changing app or page appearance',
    () {
      expect(ThemeProps.safeFromJson({}).notificationIconStyle, 'flow');
      for (final style in BrandIcons.notificationStyles.keys) {
        final props = const ThemeProps(
          appIconStyle: 'sunset',
          useDarkIcon: true,
          themeMode: ThemeMode.light,
        ).copyWith(notificationIconStyle: style);
        final restored = ThemeProps.fromJson(jsonDecode(jsonEncode(props)));
        expect(restored.notificationIconStyle, style);
        expect(restored.appIconStyle, 'sunset');
        expect(restored.themeMode, ThemeMode.light);
      }
    },
  );

  testWidgets('import crops the artwork before sending it to the launcher', (
    tester,
  ) async {
    System.platformOverride = 'android';
    FilePicker.platform = _IconPicker()
      ..path = BrandIcons.asset('sunset', false);
    final container = ProviderContainer();
    await tester.runAsync(() => container.read(customAppIconProvider.future));
    await show(tester, scale: 1.5, scope: container);
    final import = find.byKey(const ValueKey('import-app-icon'));
    await tester.ensureVisible(import);
    await tester.runAsync(() async {
      await tester.tap(import);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('Crop icon'), findsOneWidget);
    final zoom = find.byType(Slider).first;
    await tester.ensureVisible(zoom);
    await tester.tapAt(tester.getCenter(zoom) + const Offset(30, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(3));
    if (const bool.fromEnvironment('AURORA_CAPTURE')) {
      await captureFlutterFrame(
        tester,
        find.byKey(const ValueKey('icon-overlay-capture')),
        'build/aurora_refresh/captures/app-icon-crop.png',
      );
    }
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    final bytes = container.read(customAppIconProvider).asData?.value;
    expect(bytes, isNotNull);
    final size = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes!);
      final image = (await codec.getNextFrame()).image;
      final size = (image.width, image.height);
      image.dispose();
      codec.dispose();
      return size;
    });
    expect(size?.$1, size?.$2);
    final pin = find.byKey(const ValueKey('pin-custom-icon'));
    await tester.ensureVisible(pin);
    await tester.tap(pin);
    await tester.pumpAndSettle();
    expect(calls.last.method, 'syncCustomShortcut');
    expect(calls.last.arguments, {'bytes': bytes, 'pin': true});
  });

  testWidgets('notification selection updates native icon and saved choice', (
    tester,
  ) async {
    System.platformOverride = 'android';
    final container = await show(tester);
    final outline = find.byKey(const ValueKey('notification-icon-outline'));
    await tester.ensureVisible(outline);
    await tester.runAsync(() async {
      await tester.tap(outline);
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(
      container.read(themeSettingProvider).notificationIconStyle,
      'outline',
    );
    expect(
      calls.where((c) => c.method == 'setNotificationIconStyle').last.arguments,
      {'style': 'outline'},
    );
    expect(container.read(themeSettingProvider).appIconStyle, 'official');
  });

  testWidgets('leaving the picker during apply still keeps the saved choice', (
    tester,
  ) async {
    System.platformOverride = 'android';
    final pending = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getLauncherIcon') {
        return {'style': 'official', 'useDarkIcon': false};
      }
      if (call.method == 'setNotificationIconStyle') return pending.future;
      return true;
    });
    final container = await show(tester);
    final outline = find.byKey(const ValueKey('notification-icon-outline'));
    await tester.ensureVisible(outline);
    await tester.tap(outline);
    await tester.pump();
    expect(tester.widget<ChoiceChip>(outline).selected, isTrue);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.descendant(
        of: outline,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      pending.complete(true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(
      container.read(themeSettingProvider).notificationIconStyle,
      'outline',
    );
    expect(
      jsonDecode(
        store.getString(configKey)!,
      )['themeProps']['notificationIconStyle'],
      'outline',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a native notification failure keeps the previous choice', (
    tester,
  ) async {
    System.platformOverride = 'android';
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getLauncherIcon') {
        return {'style': 'official', 'useDarkIcon': false};
      }
      if (call.method == 'setNotificationIconStyle') return false;
      return true;
    });
    final container = await show(tester);
    final plain = find.byKey(const ValueKey('notification-icon-plain'));
    await tester.ensureVisible(plain);
    await tester.tap(plain);
    await tester.pumpAndSettle();
    expect(container.read(themeSettingProvider).notificationIconStyle, 'flow');
    expect(
      find.textContaining('Notification icon update failed'),
      findsOneWidget,
    );
  });

  testWidgets('About follows the selected app artwork immediately', (
    tester,
  ) async {
    globalState.packageInfo = PackageInfo(
      appName: 'Fluxora',
      packageName: 'io.fluxora.app',
      version: '1.1.2-rc.2',
      buildNumber: '2026110602',
    );
    final container = await show(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AboutView())),
      ),
    );
    await tester.pumpAndSettle();
    for (final dark in [true, false]) {
      container
          .read(themeSettingProvider.notifier)
          .updateState(
            (s) => s.copyWith(appIconStyle: 'sunset', useDarkIcon: dark),
          );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is ResizeImage &&
              ((widget.image as ResizeImage).imageProvider as AssetImage)
                      .assetName ==
                  BrandIcons.asset('sunset', dark),
        ),
        findsOneWidget,
      );
    }
  });

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
