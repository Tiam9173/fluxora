import 'dart:io';

import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/views/proxies/icon_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');

  final store = _MemoryIconCollectionStore();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProvider,
          (_) async => Directory.systemTemp.path,
        );
    await AppLocalizations.load(const Locale('zh', 'CN'));
    await (FontLoader('HarmonyOS_Sans')..addFont(
          rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
  });

  testWidgets('group picker selects an icon and returns its URL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: ThemeData.light().copyWith(
            textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'HarmonyOS_Sans',
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: FluxoraColors.fluxCyan,
              brightness: Brightness.light,
            ),
            extensions: const [
              FluxoraMaterial(style: FluxoraSurfaceStyle.liquid),
            ],
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const ValueKey('open-icon-picker'),
                  onPressed: () async {
                    selected = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Group icon')),
                          body: RepaintBoundary(
                            key: const ValueKey('icon-picker-body'),
                            child: ColoredBox(
                              color: Theme.of(context).colorScheme.surface,
                              child: IconLibraryView(
                                groupName: 'Japan 01',
                                store: store,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Choose'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-icon-picker')));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.text('导入文件'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await captureFlutterFrame(
      tester,
      find.byKey(const ValueKey('icon-picker-body')),
      'build/icon_library/captures/mobile-light.png',
    );
    await tester.tap(find.text('github').first);
    await tester.pump(const Duration(milliseconds: 450));
    expect(selected, 'asset://assets/images/platforms/github.svg');
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow dark layout supports larger text and Qure search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(340, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: ThemeData.dark().copyWith(
            textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'HarmonyOS_Sans',
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: FluxoraColors.fluxCyan,
              brightness: Brightness.dark,
            ),
            extensions: const [
              FluxoraMaterial(style: FluxoraSurfaceStyle.liquid),
            ],
          ),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: Scaffold(
                appBar: AppBar(title: const Text('图标库')),
                body: RepaintBoundary(
                  key: const ValueKey('icon-library-body'),
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: IconLibraryView(groupName: 'Japan 01', store: store),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.text('Qure SVG'));
    await tester.tap(find.text('Qure SVG'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Qure Style SVG'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Japan');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Japan'), findsWidgets);
    expect(find.byType(GridView), findsOneWidget);
    await captureFlutterFrame(
      tester,
      find.byKey(const ValueKey('icon-library-body')),
      'build/icon_library/captures/narrow-dark-large-text.png',
    );
    expect(tester.takeException(), isNull);
  });
}

class _MemoryIconCollectionStore extends IconCollectionStore {
  @override
  Future<List<IconCollection>> load() async => const [];

  @override
  Future<void> save(List<IconCollection> collections) async {}
}
