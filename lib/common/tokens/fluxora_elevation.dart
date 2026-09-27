import 'package:flutter/widgets.dart';

import 'fluxora_colors.dart';

/// Fluxora elevation ladder.
///
/// Source of truth: `D4_BRAND_PROPOSAL.md` §8.1 (light: "阴影 极轻, elevation
/// 0–2") and §8.2 (dark: "阴影 极弱 … 改用 Surface 明度差表达层级").
///
/// The numeric ladder is grounded in the D4.1 audit, which found 18 inline
/// `elevation:` call sites using 0 / 2 / 3 / 6 / 10 / 12. Map legacy values to
/// the nearest token when migrating in D4.5:
///
/// | legacy | token |
/// | --- | --- |
/// | 0 | [level0] |
/// | 2 | [level1] |
/// | 3 | [level2] |
/// | 6 | [level3] |
/// | 10 | [level4] (or [level3]) |
/// | 12 | [level4] |
///
/// Two things are declared here:
/// 1. The **numeric** ladder — pass these to `Material(elevation:)`.
/// 2. The **shadow** ladder, per brightness ([light] / [dark]) — because in dark
///    themes shadows barely read, hierarchy is carried by surface brightness
///    instead. See [darkSurface] and [FluxoraShadowSet].
///
/// This is a **definition layer**: it declares values only. Wiring elevation
/// into `ThemeData` (cards, dialogs, sheets) is D4.4 / D4.5.
abstract final class FluxoraElevation {
  // ─────────────────────────────────────────────────────────────────────────
  // Numeric ladder
  // ─────────────────────────────────────────────────────────────────────────

  /// Flat — no lift. Cards at rest use a border instead of a shadow.
  static const level0 = 0.0;

  /// Subtle lift (hover, pressed feedback).
  static const level1 = 2.0;

  /// Raised surface (FAB, elevated button).
  static const level2 = 3.0;

  /// Floating menu / dropdown.
  static const level3 = 6.0;

  /// Overlay — popups, dialogs, modal sheets.
  static const level4 = 12.0;

  /// Top-most — drag preview, transient toast above an overlay.
  static const level5 = 16.0;

  // ─────────────────────────────────────────────────────────────────────────
  // Semantic aliases
  // ─────────────────────────────────────────────────────────────────────────

  /// Flat surface, no shadow.
  static const flat = level0;

  /// A card at rest: no shadow, delineated by `outlineVariant`.
  static const resting = level0;

  /// Hover / press feedback.
  static const hover = level1;

  /// Raised interactive surface (FAB, primary action).
  static const raised = level2;

  /// Popup menu, dropdown, autocomplete list.
  static const menu = level3;

  /// Overlay layer — popup, dialog.
  static const overlay = level4;

  /// Modal layer — dialog, modal bottom sheet.
  static const modal = level4;

  /// Drag preview / top-most transient surface.
  static const drag = level5;

  // ─────────────────────────────────────────────────────────────────────────
  // Shadow ladders
  // ─────────────────────────────────────────────────────────────────────────

  /// Light-theme shadows. Kept deliberately soft (§8.1: "极轻").
  static const light = FluxoraShadowSet(
    brightness: Brightness.light,
    level0: <BoxShadow>[],
    level1: <BoxShadow>[
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
    ],
    level2: <BoxShadow>[
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 8,
        offset: Offset(0, 2),
        spreadRadius: -1,
      ),
    ],
    level3: <BoxShadow>[
      BoxShadow(
        color: Color(0x1F000000),
        blurRadius: 16,
        offset: Offset(0, 4),
        spreadRadius: -2,
      ),
    ],
    level4: <BoxShadow>[
      BoxShadow(
        color: Color(0x24000000),
        blurRadius: 24,
        offset: Offset(0, 8),
        spreadRadius: -4,
      ),
    ],
    level5: <BoxShadow>[
      BoxShadow(
        color: Color(0x29000000),
        blurRadius: 32,
        offset: Offset(0, 12),
        spreadRadius: -6,
      ),
    ],
  );

  /// Dark-theme shadows.
  ///
  /// A black shadow over a navy surface is close to invisible, so the low levels
  /// carry **no** shadow at all — hierarchy is expressed by surface brightness
  /// ([darkSurface]). Only the floating layers ([level3] and above) keep a faint
  /// shadow, because they sit above the whole surface ladder and still benefit
  /// from a soft scrim-like edge.
  static const dark = FluxoraShadowSet(
    brightness: Brightness.dark,
    level0: <BoxShadow>[],
    level1: <BoxShadow>[],
    level2: <BoxShadow>[],
    level3: <BoxShadow>[
      BoxShadow(
        color: Color(0x33000000),
        blurRadius: 16,
        offset: Offset(0, 4),
        spreadRadius: -2,
      ),
    ],
    level4: <BoxShadow>[
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 24,
        offset: Offset(0, 8),
        spreadRadius: -4,
      ),
    ],
    level5: <BoxShadow>[
      BoxShadow(
        color: Color(0x4D000000),
        blurRadius: 32,
        offset: Offset(0, 12),
        spreadRadius: -6,
      ),
    ],
  );

  /// Shadow set for a [Brightness].
  static FluxoraShadowSet of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  // ─────────────────────────────────────────────────────────────────────────
  // Dark-mode surface ladder (the shadow substitute)
  // ─────────────────────────────────────────────────────────────────────────

  /// The surface a layer at [level] should sit on in **dark** themes.
  ///
  /// §8.2 requires dark hierarchy to come from surface *brightness* rather than
  /// shadow. This maps the elevation ladder onto the surface-container ladder
  /// declared in [FluxoraColorSet]:
  ///
  /// `surface #121A2B → surfaceContainer #18223A → surfaceContainerHigh #1F2A44
  /// → surfaceContainerHighest #26334F`.
  ///
  /// In light themes prefer [of] shadows; this helper exists for the dark path
  /// (and stays harmless if called with a light set).
  static Color darkSurface(FluxoraColorSet colors, double level) {
    if (level <= level1) return colors.surface;
    if (level <= level2) return colors.surfaceContainer;
    if (level <= level3) return colors.surfaceContainerHigh;
    return colors.surfaceContainerHighest;
  }
}

/// Shadow ladder for one [Brightness].
///
/// Holds a `List<BoxShadow>` per elevation level plus semantic aliases. All
/// fields are const so a set can be declared as a compile-time constant.
@immutable
class FluxoraShadowSet {
  final Brightness brightness;

  final List<BoxShadow> level0;
  final List<BoxShadow> level1;
  final List<BoxShadow> level2;
  final List<BoxShadow> level3;
  final List<BoxShadow> level4;
  final List<BoxShadow> level5;

  const FluxoraShadowSet({
    required this.brightness,
    required this.level0,
    required this.level1,
    required this.level2,
    required this.level3,
    required this.level4,
    required this.level5,
  });

  // ── Semantic aliases ─────────────────────────────────────────────────────

  List<BoxShadow> get flat => level0;
  List<BoxShadow> get resting => level0;
  List<BoxShadow> get hover => level1;
  List<BoxShadow> get raised => level2;
  List<BoxShadow> get menu => level3;
  List<BoxShadow> get overlay => level4;
  List<BoxShadow> get modal => level4;
  List<BoxShadow> get drag => level5;

  /// Shadow list for a numeric elevation level.
  List<BoxShadow> byLevel(double level) {
    if (level <= FluxoraElevation.level0) return level0;
    if (level <= FluxoraElevation.level1) return level1;
    if (level <= FluxoraElevation.level2) return level2;
    if (level <= FluxoraElevation.level3) return level3;
    if (level <= FluxoraElevation.level4) return level4;
    return level5;
  }
}
