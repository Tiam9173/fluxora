// `Tristate` lives in `dart:ui`'s semantics library and is not re-exported.
import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Behaviour of the settings rows — the three things the layout tests in
/// `settings_rows_test.dart` deliberately do not cover.
///
/// Each `ListItem` variant decides its own interactivity, and they differ:
///
/// | constructor | disabled when | tap opens |
/// | --- | --- | --- |
/// | `.switchItem` | `SwitchDelegate.onChanged == null` | toggles inline |
/// | `.input` | `InputDelegate.onChanged == null` | `InputDialog` |
/// | `.options` | never — `OptionsDelegate.onChanged` is non-nullable | choice sheet |
///
/// `.options` is therefore **not** a disabled control, which is the mistake the
/// first attempt at these tests made.
///
/// Covered here: the disabled contract for both interactive variants, the
/// "one tap = one update" contract, and the accessibility side of disabled
/// (a dimmed row that still announces itself as enabled is worse than no
/// styling at all).
///
/// **Not covered yet** (attempted, assertions were wrong, removed rather than
/// loosened): the `InputDialog` submit/validation round-trip — driving the
/// dialog needs its own `TextEditingController` interaction and a settled route
/// pop, which is a separate harness.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  setUp(() {
    globalState.appState = AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.tools,
    );
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF29D6C7),
            brightness: Brightness.dark,
          ),
        ),
        home: Builder(
          builder: (ctx) {
            globalState.theme = CommonTheme.of(ctx, 1.0);
            globalState.measure = Measure.of(ctx, 1.0);
            return Scaffold(body: ListView(children: [child]));
          },
        ),
      ),
    );
    await tester.pump();
  }

  group('disabled state', () {
    testWidgets('a null switch callback disables the row', (tester) async {
      await pump(
        tester,
        ListItem.switchItem(
          title: const Text('allowLan'),
          delegate: const SwitchDelegate(value: false),
        ),
      );

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(
        tile.enabled,
        isFalse,
        reason: 'SwitchDelegate.onChanged == null ⇒ the row is not operable',
      );
      expect(tile.onTap, isNull);

      // The switch itself is inert too: `Switch.onChanged` is the same callback.
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);
    });

    testWidgets('a null input callback disables the row and opens nothing', (
      tester,
    ) async {
      await pump(
        tester,
        ListItem.input(
          title: const Text('keepAliveInterval'),
          delegate: const InputDelegate(
            title: 'keepAliveInterval',
            value: '10',
            onChanged: null,
          ),
        ),
      );

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.enabled, isFalse);

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(
        find.byType(InputDialog),
        findsNothing,
        reason: 'a disabled row must not open the editor',
      );
    });

    testWidgets('a live callback enables the row and fires exactly once', (
      tester,
    ) async {
      var toggles = 0;
      await pump(
        tester,
        ListItem.switchItem(
          title: const Text('allowLan'),
          delegate: SwitchDelegate(
            value: false,
            onChanged: (_) => toggles++,
          ),
        ),
      );

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.enabled, isTrue);

      await tester.tap(find.byType(ListTile));
      await tester.pump();
      expect(toggles, 1, reason: 'one tap, one update — no double dispatch');

      // Tapping the switch itself goes through the same callback.
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(toggles, 2);
    });
  });

  group('accessibility', () {
    /// The row's semantics, with the exact flags measured from a live render —
    /// `SemanticsFlags` only exposes `isEnabled` / `isButton` / `isToggled`, and
    /// `matchesSemantics` would need the full flag set guessed right.
    SemanticsData dataOf(WidgetTester tester) =>
        tester.getSemantics(find.byType(ListTile)).getSemanticsData();

    testWidgets('a disabled row announces itself as disabled', (tester) async {
      // Dimming alone is not a state: a screen reader has to be told too.
      // Disposed inline, not via `addTearDown`: the framework verifies that no
      // `SemanticsHandle` is left open *before* tear-downs run.
      final handle = tester.ensureSemantics();

      await pump(
        tester,
        ListItem.switchItem(
          title: const Text('allowLan'),
          delegate: const SwitchDelegate(value: true),
        ),
      );

      final data = dataOf(tester);
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.label, contains('allowLan'));
      handle.dispose();
    });

    testWidgets('a live row is enabled and exposes a tap action', (
      tester,
    ) async {
      // Disposed inline, not via `addTearDown`: the framework verifies that no
      // `SemanticsHandle` is left open *before* tear-downs run.
      final handle = tester.ensureSemantics();

      await pump(
        tester,
        ListItem.switchItem(
          title: const Text('allowLan'),
          delegate: SwitchDelegate(value: true, onChanged: (_) {}),
        ),
      );

      final data = dataOf(tester);
      expect(data.flagsCollection.isEnabled, Tristate.isTrue);
      expect(data.flagsCollection.isButton, isTrue);
      // `actions` is a bitmask, not a collection.
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(
        data.hasAction(SemanticsAction.focus),
        isTrue,
        reason: 'the row has to be reachable from the keyboard',
      );
      handle.dispose();
    });

    testWidgets('a disabled input row keeps its label readable', (
      tester,
    ) async {
      // Disposed inline, not via `addTearDown`: the framework verifies that no
      // `SemanticsHandle` is left open *before* tear-downs run.
      final handle = tester.ensureSemantics();

      await pump(
        tester,
        ListItem.input(
          title: const Text('keepAliveInterval'),
          delegate: const InputDelegate(
            title: 'keepAliveInterval',
            value: '10',
            onChanged: null,
          ),
        ),
      );

      final data = dataOf(tester);
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(
        data.label,
        contains('keepAliveInterval'),
        reason: 'the setting still has to be identifiable when it is read-only',
      );
      handle.dispose();
    });
  });

  group('keyboard focus', () {
    /// Whether the currently focused widget lives inside the settings row.
    bool focusIsInsideRow() {
      final ctx = FocusManager.instance.primaryFocus?.context;
      return ctx?.findAncestorWidgetOfExactType<ListTile>() != null;
    }

    testWidgets('Tab reaches a live row', (tester) async {
      await pump(
        tester,
        ListItem.switchItem(
          title: const Text('allowLan'),
          delegate: SwitchDelegate(value: true, onChanged: (_) {}),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        focusIsInsideRow(),
        isTrue,
        reason: 'a live setting must be operable without a mouse',
      );
    });

    testWidgets('Tab skips a disabled row', (tester) async {
      await pump(
        tester,
        ListItem.switchItem(
          title: const Text('allowLan'),
          delegate: const SwitchDelegate(value: true),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        focusIsInsideRow(),
        isFalse,
        reason: 'focusing a row that cannot be changed is a dead end',
      );
      // The row's own ink response agrees.
      expect(
        tester.widget<InkWell>(find.byType(InkWell).first).canRequestFocus,
        isFalse,
      );
    });
  });
}
