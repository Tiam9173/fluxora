import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';

/// The three row shapes every settings sub-page is built from.
///
/// `lib/views/config/*` never lays out its own controls — it composes
/// `ListItem.switchItem` / `.input` / `.options`, and `ListItem` decides the
/// layout, the disabled state and the edit affordance:
///
/// | delegate | what the row does |
/// | --- | --- |
/// | `SwitchDelegate` | toggles inline; `onChanged == null` ⇒ row disabled |
/// | `InputDelegate` | opens `InputDialog` (validator runs **there**), then calls `onChanged` |
/// | `OptionsDelegate` | opens a choice sheet |
///
/// What is covered here: the row at a **narrow window with 2.0× text**, both
/// themes — the responsive risk flagged in Phase 03.6 round 1.
///
/// What is **not** covered by a test yet (verified by reading the code, not by
/// assertion): the disabled contract (`enabled: inputDelegate.onChanged != null`
/// at `list.dart:387`, `enabled: switchDelegate.onChanged != null` at `:433`)
/// and the input validation (`InputDialog` + `validator` at `list.dart:391-399`,
/// which is what keeps `int.parse` in `KeepAliveIntervalItem.onChanged` safe —
/// `onChanged` only runs after the dialog returns a validated string).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const longTitle = '允许局域网连接（Allow LAN connections from other devices）';
  const longDesc = '开启后，同一网段内的其他设备可以通过本机代理端口访问网络，请确认网络环境可信。';

  void seed({Size size = const Size(400, 800)}) {
    globalState.appState = AppState(
      viewSize: size,
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.tools,
    );
  }

  Future<void> pumpRows(
    WidgetTester tester, {
    required Size size,
    required double scale,
    Brightness brightness = Brightness.dark,
    required Widget child,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    seed(size: size);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF29D6C7),
            brightness: brightness,
          ),
        ),
        home: Builder(
          builder: (ctx) {
            globalState.theme = CommonTheme.of(ctx, scale);
            globalState.measure = Measure.of(ctx, scale);
            return MediaQuery(
              data: MediaQuery.of(ctx).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(body: ListView(children: [child])),
            );
          },
        ),
      ),
    );
    await tester.pump();
  }

  Widget allThreeRows({ValueChanged<bool>? onSwitch, ValueChanged<String?>? onInput}) {
    return Column(
      children: [
        ListItem.switchItem(
          title: const Text(longTitle),
          subtitle: const Text(longDesc),
          delegate: SwitchDelegate(value: true, onChanged: onSwitch),
        ),
        ListItem.input(
          title: const Text(longTitle),
          delegate: InputDelegate(
            title: longTitle,
            value: '192.168.100.200:65535',
            onChanged: onInput,
          ),
        ),
        ListItem<int>.options(
          title: const Text(longTitle),
          delegate: OptionsDelegate<int>(
            title: longTitle,
            options: const [1, 2, 3],
            value: 1,
            onChanged: (_) {},
            textBuilder: (v) => 'option-$v',
          ),
        ),
      ],
    );
  }

  group('narrow window at 2.0x', () {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      testWidgets('the rows wrap instead of overflowing ($brightness)', (
        tester,
      ) async {
        await pumpRows(
          tester,
          size: const Size(320, 640),
          scale: 2.0,
          brightness: brightness,
          child: allThreeRows(),
        );

        expect(
          tester.takeException(),
          isNull,
          reason:
              'long bilingual titles + a long description must wrap, not '
              'overflow, at 320 px and 2.0x',
        );

        // Each row grew to fit its wrapped text rather than clipping it.
        for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
          expect(tile.title, isNotNull);
        }
        final tileHeight = tester.getRect(find.byType(ListTile).first).height;
        expect(tileHeight, greaterThan(56), reason: 'the row wrapped to 2+ lines');
      });
    }
  });
}
