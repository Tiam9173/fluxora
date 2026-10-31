import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';

/// Log level colours come from the Aurora palette, not from Material constants.
///
/// `LogLevelExt.color` used to return `Colors.grey.shade700 / shade400`,
/// `Color.fromARGB(230, 255, 166, 0)` and `Colors.redAccent`. Those are fixed
/// values: `redAccent` is tuned for a dark surface and goes muddy on the light
/// theme, and the amber never matched the palette's `warning`. The level is now
/// resolved per brightness from `FluxoraColorSet` (semantic roles) and
/// `ColorScheme` (neutral roles).
///
/// These tests drive the same function the two `LogItem` call sites use
/// (`logs.dart:278` payload, `logs.dart:331` detail dialog), so a palette change
/// cannot silently leave the log page on the old constants.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ColorScheme> pumpAndResolve(
    WidgetTester tester,
    LogLevel level,
    void Function(Color? colour) capture, {
    required Brightness brightness,
  }) async {
    late ColorScheme scheme;
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
            scheme = Theme.of(ctx).colorScheme;
            capture(level.colorOf(ctx));
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    return scheme;
  }

  for (final brightness in [Brightness.dark, Brightness.light]) {
    testWidgets('each level resolves to a palette role ($brightness)', (
      tester,
    ) async {
      final palette = FluxoraColorSet.of(brightness);
      Color? captured;

      final scheme = await pumpAndResolve(
        tester,
        LogLevel.error,
        (c) => captured = c,
        brightness: brightness,
      );
      expect(
        captured,
        palette.error,
        reason: 'error logs use the semantic role, not Colors.redAccent',
      );

      await pumpAndResolve(
        tester,
        LogLevel.warning,
        (c) => captured = c,
        brightness: brightness,
      );
      expect(captured, palette.warning);

      await pumpAndResolve(
        tester,
        LogLevel.debug,
        (c) => captured = c,
        brightness: brightness,
      );
      expect(captured, scheme.onSurfaceVariant);

      await pumpAndResolve(
        tester,
        LogLevel.silent,
        (c) => captured = c,
        brightness: brightness,
      );
      expect(captured, scheme.outline);
    });
  }

  testWidgets('info keeps the default text colour', (tester) async {
    Color? captured = Colors.transparent;
    await pumpAndResolve(
      tester,
      LogLevel.info,
      (c) => captured = c,
      brightness: Brightness.dark,
    );

    expect(
      captured,
      isNull,
      reason: 'the normal case reads like body text instead of carrying a colour',
    );
  });

  test('the palette really differs between the two themes', () {
    final dark = FluxoraColorSet.of(Brightness.dark);
    final light = FluxoraColorSet.of(Brightness.light);

    expect(
      dark.error,
      isNot(light.error),
      reason: 'one hardcoded red cannot serve both surfaces — that was the bug',
    );
    expect(dark.warning, isNot(light.warning));
  });
}
