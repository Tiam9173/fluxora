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
  /// against the existing 20/18 radii used by `CommonCard` and the call sites
  /// that still pass an explicit radius.
  static const card = lg;

  /// Buttons. Material 3 buttons default to `StadiumBorder` (a pill) and no
  /// button theme overrides that shape, so [full] is the honest alias for the
  /// default. Reach for an explicit radius only where a component deliberately
  /// needs a rounded rectangle — e.g. the 12 px action button in
  /// `warp_view.dart`.
  static const button = full;

  /// Chips, badges and tags. `ChipThemeData.shape` is [lg] (16) in both
  /// brightnesses and `CommonChip` inherits it, so chips here are rounded
  /// rectangles rather than pills. A component may override this when a
  /// different radius is intentional.
  static const chip = lg;

  /// Dialogs. The dialog theme uses [xl] (24) in both brightnesses —
  /// deliberately tighter than the Material 3 default of 28, matching the
  /// app's denser surfaces.
  static const dialog = xl;

  /// Bottom sheets. 28 is the design value both themes set explicitly on the
  /// sheet surface (and it is also Flutter's Material 3 bottom-sheet default),
  /// so it sits off the 4-based scale on purpose — do not round it to [xl] (24).
  /// The legacy `28 → [xl]` mapping in the header applies to ad-hoc call sites,
  /// never to the sheet surface itself. Side sheets are square by design and do
  /// not use this token.
  static const sheet = 28.0;

  /// Compact input fields — the editor's find / replace bar only.
  ///
  /// Not the standard field radius. Those fields are 36 px tall
  /// (`SizedBox(height: 36)`) with `isDense: true` and 10/8 content padding, so
  /// they take a proportionally smaller corner than a form field. The standard
  /// radius lives in the global `inputDecorationTheme` (18 px,
  /// `application.dart`) and is deliberately not aliased here: 18 px on a 36 px
  /// box would clamp to a pill.
  static const inputCompact = sm;

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
  static const buttonAll = fullAll;
  static const dialogAll = xlAll;
  static const sheetAll = BorderRadius.all(Radius.circular(sheet));

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
