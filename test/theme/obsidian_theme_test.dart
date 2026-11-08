import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/models/models.dart';

void main() {
  for (final brightness in Brightness.values) {
    test(
      'obsidian surfaces keep readable text and custom accent $brightness',
      () {
        final scheme = fluxoraSchemeFromSeed(
          brightness: brightness,
          seed: Colors.blue,
          variant: DynamicSchemeVariant.tonalSpot,
          followSeed: true,
          visualStyle: FluxoraVisualStyle.obsidian,
        );
        final custom = fluxoraSchemeFromSeed(
          brightness: brightness,
          seed: Colors.blue,
          variant: DynamicSchemeVariant.tonalSpot,
          followSeed: true,
        );
        expect(scheme.primary, custom.primary);
        for (final background in [
          scheme.surface,
          scheme.surfaceContainer,
          scheme.surfaceContainerHighest,
        ]) {
          for (final foreground in [
            scheme.onSurface,
            scheme.onSurfaceVariant,
          ]) {
            final a = foreground.computeLuminance(),
                b = background.computeLuminance();
            expect(
              (math.max(a, b) + .05) / (math.min(a, b) + .05),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
        final reduced = fluxoraMaterialTheme(
          ThemeData(colorScheme: scheme),
          FluxoraSurfaceStyle.reduced,
          visualStyle: FluxoraVisualStyle.obsidian,
        ).extension<FluxoraMaterial>()!;
        expect(reduced.isObsidian, isTrue);
        expect(reduced.blurEnabled, isFalse);
      },
    );
  }
  test(
    'obsidian preference round trips and older themes retain the default',
    () {
      const props = ThemeProps(visualStyle: FluxoraVisualStyle.obsidian);
      expect(ThemeProps.fromJson(jsonDecode(jsonEncode(props))), props);
      expect(
        ThemeProps.safeFromJson({}).visualStyle,
        FluxoraVisualStyle.fluxora,
      );
      expect(
        ThemeProps.safeFromJson({'visualStyle': 'future-style'}).visualStyle,
        FluxoraVisualStyle.fluxora,
      );
    },
  );
}
