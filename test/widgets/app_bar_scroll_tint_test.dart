import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';

/// What the page toolbar paints, before and after content scrolls under it.
///
/// ## Root cause of the three-round disagreement (resolved 2026-10-29)
///
/// Material 3 gives `AppBar` `scrolledUnderElevation: 3` and swaps its
/// background to `colorScheme.surfaceContainer`. That part was always right.
/// But `Material` also paints
/// `ElevationOverlay.applySurfaceTint(color, surfaceTintColor, elevation)`
/// (`material.dart:512`), and M3 defaults `AppBar.surfaceTintColor` to
/// `colorScheme.surfaceTint` — **not** transparent, as three earlier audits
/// assumed. So the painted pixels were
/// `applySurfaceTint(#18223A, #81D5CB, 3)` = **#203045**: a seed-derived teal
/// that no Aurora token defines.
///
/// That is why the numbers would not reconcile — the widget property read
/// `#18223A` (a palette role) while the screenshot showed a tinted value. The
/// palette was never wrong; an overlay sat on top of it.
///
/// `CommonScaffold` now pins `surfaceTintColor: Colors.transparent`, which makes
/// `applySurfaceTint` a no-op, so the bar paints exactly the role it asks for.
/// These tests pin both halves: the role, and the absence of the overlay that
/// used to repaint it.
///
/// | brightness | at rest (`surface`) | scrolled under (`surfaceContainer`) |
/// | ---------- | ------------------- | ----------------------------------- |
/// | light      | `#F6F9FB`           | `#EFF3F6`                           |
/// | dark       | `#0C1222`           | `#18223A`                           |
///
/// **Still open**: a real window sampled `#1D3247` where the overlay formula
/// gives `#203045` — ±3 per channel, with green/blue matching elevation 4 and
/// red matching nothing. Resolving that needs one more GUI sample, blocked on
/// the helper-service issue. It does not affect the fix: with the tint removed
/// the painted colour is the role exactly, whatever the overlay's rounding.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  ColorScheme schemeFor(Brightness brightness) {
    final container = ProviderContainer(
      overrides: [
        themeSettingProvider.overrideWith(
          () => _MockThemeSetting(ThemeProps(colorSource: ColorSource.fluxora)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(genColorSchemeProvider(brightness));
  }

  setUp(() {
    globalState.appState = AppState(
      viewSize: const Size(1200, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      pageLabel: PageLabel.dashboard,
    );
  });

  Widget seedGlobals(Widget child) {
    return Builder(
      builder: (ctx) {
        globalState.theme = CommonTheme.of(ctx, 1.0);
        globalState.measure = Measure.of(ctx, 1.0);
        return child;
      },
    );
  }

  Future<void> pumpScaffold(WidgetTester tester, ColorScheme scheme) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: scheme),
          home: seedGlobals(
            CommonScaffold(
              title: 'toolbar',
              body: generateListView([
                for (var i = 0; i < 40; i++)
                  ListTile(title: Text('row-$i')),
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The toolbar's own `Material` — the one carrying the background.
  ///
  /// `AppBar` renders exactly one `Material` with a colour; the ink materials
  /// inside the leading/action buttons have none of their own.
  Material barMaterial(WidgetTester tester) {
    final materials = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(Material),
          ),
        )
        .where((m) => m.color != null)
        .toList();
    expect(materials, hasLength(1), reason: 'one background material');
    return materials.single;
  }

  Future<void> scrollUnder(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('the toolbar follows the surface ladder ($brightness)', (
      tester,
    ) async {
      final scheme = schemeFor(brightness);
      final palette = FluxoraColorSet.of(brightness);
      await pumpScaffold(tester, scheme);

      expect(
        barMaterial(tester).color,
        scheme.surface,
        reason: 'at rest the toolbar sits on the page surface',
      );

      await scrollUnder(tester);

      final scrolled = barMaterial(tester);
      expect(
        scrolled.color,
        scheme.surfaceContainer,
        reason:
            'scrolled under, Material swaps the bar to `surfaceContainer` — one '
            'step above the page, one below the rail',
      );
      expect(
        scrolled.color,
        palette.surfaceContainer,
        reason: 'and that value must be the palette role',
      );
    });

    testWidgets('the toolbar switches the surface tint off ($brightness)', (
      tester,
    ) async {
      final scheme = schemeFor(brightness);
      await pumpScaffold(tester, scheme);
      await scrollUnder(tester);

      final scrolled = barMaterial(tester);
      expect(
        scrolled.elevation,
        3,
        reason: 'M3 still raises the bar while content is under it',
      );
      expect(
        scrolled.surfaceTintColor,
        Colors.transparent,
        reason:
            'with a non-transparent tint, `Material` repaints this elevation-3 '
            'surface with a seed-derived teal instead of the palette role',
      );
    });
  }

  test('the overlay this pin removes is not a palette role', () {
    // Documents *why* the pin exists, in numbers rather than prose: in both
    // themes the default tint would move the toolbar off the palette.
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final scheme = schemeFor(brightness);
      final painted = ElevationOverlay.applySurfaceTint(
        scheme.surfaceContainer,
        scheme.surfaceTint,
        3,
      );
      expect(
        painted,
        isNot(scheme.surfaceContainer),
        reason:
            'if this ever stops differing, the tint default changed and the '
            'pin can be revisited ($brightness)',
      );
    }
  });
}

class _MockThemeSetting extends ThemeSetting {
  ThemeProps _current;
  _MockThemeSetting(this._current);

  @override
  ThemeProps build() => _current;

  @override
  void updateState(ThemeProps Function(ThemeProps state) builder) {
    _current = builder(_current);
    state = _current;
  }

  @override
  void onUpdate(ThemeProps value) {
    _current = value;
  }
}
