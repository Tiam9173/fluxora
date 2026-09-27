import 'package:flutter/widgets.dart';

/// Fluxora spacing scale.
///
/// Source of truth: `D4_BRAND_PROPOSAL.md` §7 (grid) and the D4.1 audit, which
/// found 264 inline `EdgeInsets.*` calls spread over 9 distinct values
/// (2/4/6/8/10/12/16/18/24).
///
/// The scale below is a **4-based ladder** that covers those values. When
/// migrating call sites in D4.5, map legacy values to the nearest token:
///
/// | legacy | token |
/// | --- | --- |
/// | 2 | [xxs] |
/// | 4 | [xs] |
/// | 6 | [sm] (or [xs]) |
/// | 8 | [sm] |
/// | 10 | [md] |
/// | 12 | [md] |
/// | 16 | [lg] |
/// | 18 | [lg] |
/// | 24 | [xl] |
///
/// This is a **definition layer**: it declares values only and does not change
/// any existing call site.
abstract final class FluxoraSpacing {
  // ── Scale ────────────────────────────────────────────────────────────────

  static const none = 0.0;

  /// Hairline separation (dividers, 1px-adjacent gaps).
  static const xxs = 2.0;

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const huge = 64.0;

  // ── Semantic aliases ─────────────────────────────────────────────────────

  /// Outer padding of a page body.
  static const pagePadding = lg;

  /// Inner padding of a card.
  static const cardPadding = md;

  /// Vertical padding of a list row.
  static const listItemPadding = md;

  /// Gap between two stacked sections.
  static const sectionGap = xl;

  /// Gap between inline siblings (icon ↔ label).
  static const inlineGap = sm;

  /// Gap between form fields.
  static const fieldGap = md;

  // ── Common EdgeInsets (const, ready to use) ──────────────────────────────

  static const pageInsets = EdgeInsets.all(pagePadding);
  static const pageInsetsHorizontal = EdgeInsets.symmetric(
    horizontal: pagePadding,
  );
  static const cardInsets = EdgeInsets.all(cardPadding);
  static const cardInsetsHorizontal = EdgeInsets.symmetric(
    horizontal: cardPadding,
  );
  static const listItemInsets = EdgeInsets.symmetric(
    horizontal: pagePadding,
    vertical: listItemPadding,
  );
  static const inlineInsets = EdgeInsets.symmetric(horizontal: inlineGap);
  static const zeroInsets = EdgeInsets.zero;

  /// Horizontal insets used by settings rows (icon + title + trailing).
  static EdgeInsets settingsRowInsets({double scale = 1}) => EdgeInsets.only(
    left: pagePadding * scale,
    right: pagePadding * scale,
    top: listItemPadding * scale,
    bottom: listItemPadding * scale,
  );
}
