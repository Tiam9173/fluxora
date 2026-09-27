import 'package:flutter/widgets.dart';

/// Fluxora corner radius scale.
///
/// Source of truth: `D4_BRAND_PROPOSAL.md` §7. The D4.1 audit found 94 inline
/// `BorderRadius.circular(...)` calls spread over **16 distinct values**
/// (2 / 2.5 / 3 / 4 / 6 / 8 / 10 / 12 / 14 / 16 / 18 / 20 / 24 / 28 / 36).
///
/// The scale below collapses that set. When migrating call sites in D4.5, map
/// legacy values to the nearest token:
///
/// | legacy | token |
/// | --- | --- |
/// | 2 / 2.5 / 3 / 4 | [xs] |
/// | 6 / 8 / 10 | [sm] |
/// | 12 / 14 | [md] |
/// | 16 / 18 | [lg] |
/// | 20 / 24 / 28 | [xl] |
/// | 36 | [xxl] |
///
/// This is a **definition layer**: it declares values only and does not change
/// any existing call site.
abstract final class FluxoraRadius {
  // ── Scale ────────────────────────────────────────────────────────────────

  static const none = 0.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 36.0;

  /// Fully rounded (pill). Large enough to always clamp to half the shortest
  /// side for any realistic widget size.
  static const full = 999.0;

  // ── Semantic aliases ─────────────────────────────────────────────────────

  /// Cards, panels, containers.
  ///
  /// Set to [lg] (16) by the D4.6 decision — the earlier [md] (12) was too tight
  /// against the existing 20/18 radii used by `CommonCard` /
  /// `generateSectionV2`.
  static const card = lg;

  /// Buttons, inputs, icon buttons.
  static const button = sm;

  /// Chips, badges, tags.
  static const chip = full;

  /// Dialogs.
  static const dialog = lg;

  /// Bottom sheets and side sheets.
  static const sheet = lg;

  /// Text fields and search bars.
  static const input = sm;

  /// Rounded-square icons and thumbnails.
  static const icon = sm;

  /// Small badges and status pills.
  static const badge = xs;

  /// Avatars and circular nodes.
  static const avatar = full;

  // ── Common BorderRadius (const, ready to use) ────────────────────────────

  static const zero = BorderRadius.zero;
  static const xsAll = BorderRadius.all(Radius.circular(xs));
  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));
  static const fullAll = BorderRadius.all(Radius.circular(full));

  static const cardAll = lgAll;
  static const buttonAll = smAll;
  static const dialogAll = lgAll;
  static const sheetAll = lgAll;

  /// Top-only rounding, used by sheets and anchored panels.
  static const sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );

  /// Vertical rounding used by grouped list blocks.
  static const groupTop = BorderRadius.vertical(top: Radius.circular(card));
  static const groupBottom = BorderRadius.vertical(
    bottom: Radius.circular(card),
  );
}
