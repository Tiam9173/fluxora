import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Cross-component contract for the Aurora shared widgets.
///
/// Written after Phase 03.7 found that `FluxoraStatus` painted its label with
/// `FluxoraColorSet.outline` — a token the palette files under "Lines", i.e. a
/// **border** colour — at 1.1–1.7:1. That made the protocol name on every
/// unselected node row, and the dashboard's "not connected" label, effectively
/// invisible. `FluxoraLatencyBadge` had the same bug for its `untested` "—".
///
/// Nothing caught it because the components had no colour test at all: the
/// existing tests only asserted layout. These assertions are written against the
/// **real** palette (`genColorSchemeProvider`) and the **real** card background
/// (`CommonCard.getBackgroundColor`), so they fail if either side drifts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const surfaces = <String, CommonCardType>{
    'plain card': CommonCardType.plain,
    'filled card': CommonCardType.filled,
  };

  ColorScheme schemeFor(Brightness brightness) {
    final container = ProviderContainer(
      overrides: [
        themeSettingProvider.overrideWith(
          () => _MockThemeSetting(
            ThemeProps(colorSource: ColorSource.fluxora),
          ),
        ),
      ],
    );
    // Disposed synchronously, not via `addTearDown`: the provider tree keeps a
    // timer alive, and the binding asserts `!timersPending` *before* tear-downs
    // run — the same trap as an undisposed `SemanticsHandle`.
    try {
      return container.read(genColorSchemeProvider(brightness));
    } finally {
      container.dispose();
    }
  }

  /// WCAG 2.1 contrast ratio.
  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
  }

  Future<void> pumpInScheme(
    WidgetTester tester,
    ColorScheme scheme,
    Widget child,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, colorScheme: scheme),
        home: Builder(
          builder: (ctx) {
            globalState.theme = CommonTheme.of(ctx, 1.0);
            globalState.measure = Measure.of(ctx, 1.0);
            return Scaffold(body: Center(child: child));
          },
        ),
      ),
    );
    await tester.pump();
  }

  /// The surface a card of [type] paints, resolved through the production code.
  Color cardSurface(BuildContext ctx, CommonCardType type, {bool selected = false}) =>
      CommonCard(
        type: type,
        isSelected: selected,
        child: const SizedBox.shrink(),
      ).getBackgroundColor(ctx, const <WidgetState>{})!;

  group('FluxoraStatus is legible on every card surface', () {
    for (final brightness in Brightness.values) {
      testWidgets('all six states clear 4.5:1 ($brightness)', (tester) async {
        final scheme = schemeFor(brightness);
        await pumpInScheme(
          tester,
          scheme,
          const FluxoraStatus(
            status: FluxoraStatusKind.connected,
            label: 'Trojan',
          ),
        );

        final ctx = tester.element(find.byType(FluxoraStatus));
        for (final type in surfaces.values) {
          for (final selected in [false, true]) {
            final bg = cardSurface(ctx, type, selected: selected);
            for (final kind in FluxoraStatusKind.values) {
              final fg = FluxoraStatus.colorOf(ctx, kind);
              expect(
                contrast(fg, bg),
                greaterThanOrEqualTo(4.5),
                reason:
                    '${kind.name} on ${type.name}'
                    '${selected ? " (selected)" : ""} / $brightness is '
                    '${contrast(fg, bg).toStringAsFixed(2)}:1 — the label is '
                    'body-sized text, so 4.5:1 is its floor',
              );
            }
          }
        }
      });

      testWidgets('the neutral states do not borrow the line role '
          '($brightness)', (tester) async {
        // The precise regression: `outline` is a border colour, and using it for
        // text produced 1.1–1.7:1. Pinned separately so the failure message
        // names the cause instead of just quoting a ratio.
        final scheme = schemeFor(brightness);
        await pumpInScheme(
          tester,
          scheme,
          const FluxoraStatus(status: FluxoraStatusKind.unknown),
        );
        final ctx = tester.element(find.byType(FluxoraStatus));
        final line = FluxoraColorSet.of(brightness).outline;

        for (final kind in [
          FluxoraStatusKind.disconnected,
          FluxoraStatusKind.unknown,
        ]) {
          expect(
            FluxoraStatus.colorOf(ctx, kind),
            isNot(line),
            reason: '${kind.name} must not be painted with `outline`',
          );
          expect(
            FluxoraStatus.colorOf(ctx, kind),
            scheme.onSurfaceVariant,
            reason: 'the muted-but-readable role is onSurfaceVariant',
          );
        }
      });
    }
  });

  group('FluxoraLatencyBadge is legible', () {
    for (final brightness in Brightness.values) {
      testWidgets('every painted tier clears 4.5:1 ($brightness)', (
        tester,
      ) async {
        final scheme = schemeFor(brightness);
        await pumpInScheme(
          tester,
          scheme,
          const FluxoraLatencyBadge(delay: 42),
        );
        final ctx = tester.element(find.byType(FluxoraLatencyBadge));

        for (final type in surfaces.values) {
          final bg = cardSurface(ctx, type);
          for (final tier in FluxoraLatencyTier.values) {
            // `untested` is the one that regressed; `testing` is a spinner state
            // whose text is "…", also painted.
            final fg = FluxoraLatencyBadge.colorOf(ctx, tier);
            expect(
              contrast(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason:
                  '${tier.name} on ${type.name} / $brightness is '
                  '${contrast(fg, bg).toStringAsFixed(2)}:1',
            );
          }
        }
      });

      testWidgets('the untested placeholder is readable ($brightness)', (
        tester,
      ) async {
        // Every node is `untested` until its first delay test, so this is the
        // proxy list's default state rather than an edge case.
        final scheme = schemeFor(brightness);
        await pumpInScheme(tester, scheme, const FluxoraLatencyBadge(delay: null));
        final ctx = tester.element(find.byType(FluxoraLatencyBadge));

        expect(
          FluxoraLatencyBadge.colorOf(ctx, FluxoraLatencyTier.untested),
          scheme.onSurfaceVariant,
        );
        expect(
          FluxoraLatencyBadge.colorOf(ctx, FluxoraLatencyTier.untested),
          isNot(FluxoraColorSet.of(brightness).outline),
        );
      });
    }
  });

  group('FluxoraCard surface hierarchy', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        'plain / filled / selected map to three distinct roles ($brightness)', (
        tester,
      ) async {
        final scheme = schemeFor(brightness);
        await pumpInScheme(
          tester,
          scheme,
          FluxoraCard(child: const Text('card')),
        );
        final ctx = tester.element(find.byType(FluxoraCard));

        final plain = cardSurface(ctx, CommonCardType.plain);
        final filled = cardSurface(ctx, CommonCardType.filled);
        final selected = cardSurface(
          ctx,
          CommonCardType.plain,
          selected: true,
        );

        // The roles are what the palette documents, not incidental hexes.
        expect(plain, scheme.surfaceContainerLow);
        expect(filled, scheme.surfaceContainer);
        expect(selected, scheme.secondaryContainer);

        // And they are three distinct planes, not two names for one colour.
        expect({plain.toARGB32(), filled.toARGB32(), selected.toARGB32()}.length, 3);
      });

      testWidgets('text on every card surface clears 4.5:1 ($brightness)', (
        tester,
      ) async {
        final scheme = schemeFor(brightness);
        await pumpInScheme(
          tester,
          scheme,
          FluxoraCard(child: const Text('card')),
        );
        final ctx = tester.element(find.byType(FluxoraCard));

        for (final type in surfaces.values) {
          for (final selected in [false, true]) {
            final bg = cardSurface(ctx, type, selected: selected);
            expect(
              contrast(scheme.onSurface, bg),
              greaterThanOrEqualTo(4.5),
              reason: 'primary card text on ${type.name} / $brightness',
            );
            expect(
              contrast(scheme.onSurfaceVariant, bg),
              greaterThanOrEqualTo(4.5),
              reason: 'secondary card text on ${type.name} / $brightness',
            );
          }
        }
      });
    }
  });

  group('the fix reaches the real proxy row', () {
    testWidgets('an unselected node shows its protocol legibly', (
      tester,
    ) async {
      // `proxies/card.dart:329-333` maps every unselected node to `unknown`, and
      // passes the protocol as the label — so this is the row the proxy page
      // actually renders, not a synthetic case.
      final scheme = schemeFor(Brightness.dark);
      await pumpInScheme(
        tester,
        scheme,
        const FluxoraProxyTile(
          name: 'Hong Kong 01',
          protocol: 'Trojan',
          status: FluxoraStatusKind.unknown,
          delay: null,
        ),
      );

      final ctx = tester.element(find.byType(FluxoraProxyTile));
      // `FluxoraStatus` renders its label through `EmojiText`, so the colour
      // lives on that widget rather than on an inner `Text`.
      final label = tester
          .widgetList<EmojiText>(find.byType(EmojiText))
          .firstWhere((e) => e.text == 'Trojan');
      final bg = cardSurface(ctx, CommonCardType.plain);

      expect(
        contrast(label.style!.color!, bg),
        greaterThanOrEqualTo(4.5),
        reason: 'the protocol name is the row\'s secondary information; at the '
            'old `outline` colour it was 1.68:1, i.e. unreadable',
      );
    });
  });

  group('cross-surface selection language', () {
    testWidgets('a selected card and the rail tint are close but distinct', (
      tester,
    ) async {
      // Deliberate difference, not drift: the rail/dock/TV paint
      // `selectionTint(primary)` while a card uses the `secondaryContainer`
      // role. Both are teal washes a few units apart, and each surface also
      // carries its own accent (left bar vs. 3 px tick + primary border), so
      // unifying them would buy nothing and cost the role semantics.
      //
      // This pins "close enough to read as one language" so a future palette
      // change cannot silently split them into two different colours.
      final scheme = schemeFor(Brightness.dark);
      await pumpInScheme(
        tester,
        scheme,
        FluxoraCard(child: const Text('card')),
      );
      final ctx = tester.element(find.byType(FluxoraCard));

      final cardSelected = cardSurface(ctx, CommonCardType.plain, selected: true);
      final railTint = Color.alphaBlend(
        FluxoraColorSet.selectionTint(scheme.primary, scheme.brightness),
        scheme.surfaceContainerLow,
      );

      expect(cardSelected, isNot(railTint), reason: 'different roles');
      for (final channel in ['r', 'g', 'b']) {
        final a = _channel(cardSelected, channel);
        final b = _channel(railTint, channel);
        expect(
          (a - b).abs(),
          lessThanOrEqualTo(24),
          reason: '$channel drifts by ${(a - b).abs()} — the two selection '
              'washes no longer read as the same language',
        );
      }
    });
  });
}

double _channel(Color c, String name) {
  final argb = c.toARGB32();
  return switch (name) {
    'r' => ((argb >> 16) & 0xFF).toDouble(),
    'g' => ((argb >> 8) & 0xFF).toDouble(),
    _ => (argb & 0xFF).toDouble(),
  };
}

class _MockThemeSetting extends ThemeSetting {
  _MockThemeSetting(this._props);

  ThemeProps _props;

  @override
  ThemeProps build() => _props;

  @override
  void updateState(ThemeProps Function(ThemeProps state) builder) {
    _props = builder(_props);
    state = _props;
  }

  @override
  void onUpdate(ThemeProps value) => _props = value;
}
