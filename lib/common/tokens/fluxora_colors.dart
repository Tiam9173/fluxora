import 'package:flutter/material.dart';

/// Fluxora raw palette — brightness-agnostic brand, neutral and status colors.
///
/// Source of truth: `D4_BRAND_PROPOSAL.md` §3.
/// Brand values are reused verbatim from the existing Fluxora mark
/// (`assets/images/fluxora_mark.svg`) so the identity stays consistent.
///
/// This is a **definition layer**: it declares values only. Wiring these into
/// `ThemeData` / `ColorScheme` is D4.4 Theme Integration.
abstract final class FluxoraColors {
  // ─────────────────────────────────────────────────────────────────────────
  // Brand
  // ─────────────────────────────────────────────────────────────────────────

  /// Brand primary — "Flux Cyan". Carried over from the Fluxora mark.
  static const fluxCyan = Color(0xFF29D6C7);

  /// Brand secondary — "Aurora Blue". Fills the hue gap between cyan and violet.
  static const auroraBlue = Color(0xFF4C8DFF);

  /// Brand accent / tertiary — "Flow Violet". Carried over from the mark node.
  static const flowViolet = Color(0xFF7C75FF);

  // ─────────────────────────────────────────────────────────────────────────
  // Neutral (Slate family — matches the values already used across the app)
  // ─────────────────────────────────────────────────────────────────────────

  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral10 = Color(0xFFF6F9FB);
  static const neutral20 = Color(0xFFEFF3F6);
  static const neutral30 = Color(0xFFE2E8ED);
  static const neutral40 = Color(0xFFCBD5E1);
  static const neutral50 = Color(0xFF94A3B8);
  static const neutral60 = Color(0xFF64748B);
  static const neutral70 = Color(0xFF475569);
  static const neutral80 = Color(0xFF334155);
  static const neutral90 = Color(0xFF1E293B);
  static const neutral100 = Color(0xFF0A0F1A);

  /// Deep Space — dark background, carried over from the mark background.
  static const deepSpace = Color(0xFF0C1222);

  // ─────────────────────────────────────────────────────────────────────────
  // Status (raw)
  // ─────────────────────────────────────────────────────────────────────────

  /// Reused from the existing `mediaUnlockGreen`.
  static const success = Color(0xFF10B981);

  /// Reused from the existing `mediaUnlockOrange`.
  static const warning = Color(0xFFF59E0B);

  static const error = Color(0xFFE5484D);

  /// Same hue family as [auroraBlue] — keeps the palette coherent.
  static const info = Color(0xFF4C8DFF);

  // ─────────────────────────────────────────────────────────────────────────
  // Semantic sets (per brightness)
  // ─────────────────────────────────────────────────────────────────────────

  /// Light semantic colors. Access as `FluxoraColors.light.primary`.
  static const light = FluxoraColorSet(
    brightness: Brightness.light,
    primary: Color(0xFF006A63),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF71F8E8),
    onPrimaryContainer: Color(0xFF00201D),
    secondary: Color(0xFF1B5FC4),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD9E2FF),
    onSecondaryContainer: Color(0xFF001A41),
    tertiary: Color(0xFF5A52D5),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE3DFFF),
    onTertiaryContainer: Color(0xFF170065),
    background: Color(0xFFF6F9FB),
    onBackground: Color(0xFF1E293B),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1E293B),
    surfaceContainer: Color(0xFFEFF3F6),
    surfaceContainerHigh: Color(0xFFE2E8ED),
    surfaceContainerHighest: Color(0xFFDCE3E9),
    outline: Color(0xFFCBD5E1),
    outlineVariant: Color(0xFFE2E8ED),
    success: Color(0xFF006D4B),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFF8A5300),
    onWarning: Color(0xFFFFFFFF),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    info: Color(0xFF1B5FC4),
    onInfo: Color(0xFFFFFFFF),
  );

  /// Dark semantic colors. Access as `FluxoraColors.dark.primary`.
  ///
  /// Dark surfaces deliberately use a navy ladder instead of pure black:
  /// background `#0C1222` → surface `#121A2B` → container `#18223A`
  /// → containerHigh `#1F2A44`. Pure black stays a user opt-in
  /// (`ThemeProps.pureBlack`) and is intentionally not represented here.
  static const dark = FluxoraColorSet(
    brightness: Brightness.dark,
    primary: Color(0xFF4FDBCC),
    onPrimary: Color(0xFF003731),
    primaryContainer: Color(0xFF00504A),
    onPrimaryContainer: Color(0xFF71F8E8),
    secondary: Color(0xFFA9C7FF),
    onSecondary: Color(0xFF002E6B),
    secondaryContainer: Color(0xFF00458F),
    onSecondaryContainer: Color(0xFFD9E2FF),
    tertiary: Color(0xFFC6BFFF),
    onTertiary: Color(0xFF2B1F86),
    tertiaryContainer: Color(0xFF4239AC),
    onTertiaryContainer: Color(0xFFE3DFFF),
    background: Color(0xFF0C1222),
    onBackground: Color(0xFFF1F5F9),
    surface: Color(0xFF121A2B),
    onSurface: Color(0xFFF1F5F9),
    surfaceContainer: Color(0xFF18223A),
    surfaceContainerHigh: Color(0xFF1F2A44),
    surfaceContainerHighest: Color(0xFF26334F),
    outline: Color(0xFF334155),
    outlineVariant: Color(0xFF243049),
    success: Color(0xFF5CDBA0),
    onSuccess: Color(0xFF003824),
    warning: Color(0xFFFFB951),
    onWarning: Color(0xFF462A00),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    info: Color(0xFFA9C7FF),
    onInfo: Color(0xFF002E6B),
  );
}

/// Immutable semantic color set for one [Brightness].
///
/// Provides role-based accessors (`primary`, `surface`, `outline`, …) so call
/// sites never need to know raw hex values or Material tonal indices.
@immutable
class FluxoraColorSet {
  final Brightness brightness;

  // Brand roles
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;

  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;

  // Base surfaces
  final Color background;
  final Color onBackground;
  final Color surface;
  final Color onSurface;

  /// The dark-mode elevation ladder. In dark themes hierarchy is expressed by
  /// surface brightness rather than by drop shadows.
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;

  // Lines
  final Color outline;
  final Color outlineVariant;

  // Status
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color error;
  final Color onError;
  final Color info;
  final Color onInfo;

  const FluxoraColorSet({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.outline,
    required this.outlineVariant,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.error,
    required this.onError,
    required this.info,
    required this.onInfo,
  });

  /// Convenience lookup for the set matching a [Brightness].
  static FluxoraColorSet of(Brightness brightness) =>
      brightness == Brightness.dark ? FluxoraColors.dark : FluxoraColors.light;
}
