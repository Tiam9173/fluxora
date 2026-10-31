import 'package:flutter/material.dart';

/// Fluxora typography scale — 6 levels, 3 weights.
///
/// Source of truth: `D4_BRAND_PROPOSAL.md` §9.
///
/// | level | size / line-height | weight | letter-spacing | usage |
/// | --- | --- | --- | --- | --- |
/// | [display] | 32 / 40 | 600 | -0.5 | About-page wordmark, empty-state hero |
/// | [headline] | 24 / 32 | 600 | -0.25 | Page title |
/// | [title] | 18 / 24 | 600 | 0 | Section / card title |
/// | [body] | 14 / 20 | 400 | 0.15 | Body copy (**baseline**) |
/// | [label] | 12 / 16 | 500 | 0.4 | Buttons, tags, secondary info |
/// | [caption] | 11 / 14 | 400 | 0.4 | Helper text, timestamps |
///
/// **Font family is intentionally never set.** Every style leaves `fontFamily`
/// null so it inherits `ThemeData.fontFamily` (the platform default, or
/// `HarmonyOS_Sans` when `ThemeProps.useHarmonyFont` is enabled). §9 is explicit
/// that Fluxora defines *levels only* and does not change the existing fonts.
///
/// Two rules from §9 are encoded here:
/// 1. Only three weights exist ([regular] / [medium] / [semibold]).
/// 2. Numeric read-outs (latency, speed, traffic) use a monospaced family so
///    values do not jitter while ticking — see [mono] and the `numeric*` styles.
///
/// Scaling is **not** handled here: the app already clamps `TextScaler` to
/// `minTextScale..maxTextScale` (0.8–1.4) in `ThemeManager`. These styles are
/// plain sizes and scale with it automatically.
///
/// This is a **definition layer**: it declares values only. Applying these to
/// `ThemeData.textTheme` is D4.4 Theme Integration.
abstract final class FluxoraTypography {
  // ─────────────────────────────────────────────────────────────────────────
  // Weights — the only three that may be used (§9 principle 1)
  // ─────────────────────────────────────────────────────────────────────────

  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semibold = FontWeight.w600;

  // ─────────────────────────────────────────────────────────────────────────
  // Font families
  // ─────────────────────────────────────────────────────────────────────────

  /// Mirrors `FontFamily.jetBrainsMono.value` (`lib/enum/enum.dart`) and the
  /// `JetBrainsMono` family declared in `pubspec.yaml`.
  ///
  /// Declared locally on purpose: importing `enum.dart` would drag the whole
  /// widget tree into the token layer, which must stay dependency-free.
  static const monoFontFamily = 'JetBrainsMono';

  // ─────────────────────────────────────────────────────────────────────────
  // Levels
  // ─────────────────────────────────────────────────────────────────────────

  /// 32 / 40 · 600 · -0.5
  static const display = TextStyle(
    fontSize: 32,
    height: 1.25,
    fontWeight: semibold,
    letterSpacing: -0.5,
  );

  /// 24 / 32 · 600 · -0.25
  static const headline = TextStyle(
    fontSize: 24,
    height: 1.33,
    fontWeight: semibold,
    letterSpacing: -0.25,
  );

  /// 18 / 24 · 600 · 0
  static const title = TextStyle(
    fontSize: 18,
    height: 1.33,
    fontWeight: semibold,
    letterSpacing: 0,
  );

  /// 14 / 20 · 400 · 0.15 — the baseline body style.
  static const body = TextStyle(
    fontSize: 14,
    height: 1.43,
    fontWeight: regular,
    letterSpacing: 0.15,
  );

  /// 12 / 16 · 500 · 0.4
  static const label = TextStyle(
    fontSize: 12,
    height: 1.33,
    fontWeight: medium,
    letterSpacing: 0.4,
  );

  /// 11 / 14 · 400 · 0.4
  static const caption = TextStyle(
    fontSize: 11,
    height: 1.27,
    fontWeight: regular,
    letterSpacing: 0.4,
  );

  /// Every level, in descending size order. Handy for audits and for D4.4 when
  /// building `TextTheme`.
  static const levels = <TextStyle>[display, headline, title, body, label, caption];

  // ─────────────────────────────────────────────────────────────────────────
  // Numeric (monospaced) variants — §9 principle 3
  // ─────────────────────────────────────────────────────────────────────────

  /// Re-casts any level onto the monospaced family, keeping size / weight /
  /// spacing. Use for latency, speed, traffic and any value that updates live.
  static TextStyle mono(TextStyle base) =>
      base.copyWith(fontFamily: monoFontFamily);

  /// `title`'s size (18 px) on the monospaced family, at the **numeric weight**
  /// [medium] rather than `title`'s [semibold].
  ///
  /// The lighter weight is deliberate for live read-outs: latency, speed and
  /// traffic values update continuously, and w600 at 18 px reads heavier than
  /// the surrounding chrome. This is therefore *not* `mono(title)` — see
  /// [numericBody] and [numericLabel], which are exact mono recasts of their
  /// levels.
  static const numericTitle = TextStyle(
    fontSize: 18,
    height: 1.33,
    fontWeight: medium,
    letterSpacing: 0,
    fontFamily: monoFontFamily,
  );

  /// `body` on the monospaced family.
  static const numericBody = TextStyle(
    fontSize: 14,
    height: 1.43,
    fontWeight: regular,
    letterSpacing: 0.15,
    fontFamily: monoFontFamily,
  );

  /// `label` on the monospaced family.
  static const numericLabel = TextStyle(
    fontSize: 12,
    height: 1.33,
    fontWeight: medium,
    letterSpacing: 0.4,
    fontFamily: monoFontFamily,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Material TextTheme mapping (input for D4.4 — not applied here)
  // ─────────────────────────────────────────────────────────────────────────

  /// Maps the six Fluxora levels onto Material's `TextTheme` slots.
  ///
  /// All colours stay null so the resulting theme inherits them from
  /// `ColorScheme` / `ThemeData`. This is a pure mapping helper: D4.3 does not
  /// install it anywhere.
  static TextTheme textTheme() => const TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: headline,
    headlineLarge: headline,
    headlineMedium: headline,
    headlineSmall: title,
    titleLarge: title,
    titleMedium: title,
    titleSmall: label,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: label,
    labelMedium: label,
    labelSmall: caption,
  );
}

/// Size-only companion to [FluxoraTypography].
///
/// The six levels are **composite** styles (size + weight + letter-spacing), so
/// swapping a bare `TextStyle(fontSize: 13)` for one of them re-typesets the
/// text: weight and tracking change too. That is why the Phase 01-C audit
/// concluded the levels cannot be migrated mechanically, and why 39 % of the
/// codebase's font sizes sit outside the scale.
///
/// This class names those sizes **without** carrying weight or tracking. A call
/// site that says `fontSize: FluxoraFontSize.compact` renders exactly what
/// `fontSize: 13` rendered — same double, same layout — but the number now has
/// one definition, so a future scale change is a single edit.
///
/// Scope, measured on 2026-10-28:
///
/// | token | size | what it is used for |
/// | --- | --- | --- |
/// | [micro] | 10 | badges, tags, dense chain labels |
/// | [compact] | 13 | compact body copy, setting rows, dense info values |
/// | [section] | 15 | section titles inside cards and dialogs — sits between |
/// |         |    | [FluxoraTypography.body] (14) and `.title` (18) |
///
/// Deliberately **not** included: 6, 7, 9, 9.5, 11.5, 16, 18, 20, 24, 32 — each
/// appears once or twice and carries no shared meaning yet.
abstract final class FluxoraFontSize {
  /// 10 px — badges, tags, dense chain labels.
  static const micro = 10.0;

  /// 13 px — compact body copy, setting rows, dense info values.
  static const compact = 13.0;

  /// 15 px — section titles inside cards and dialogs.
  static const section = 15.0;
}
