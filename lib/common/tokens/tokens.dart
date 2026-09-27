/// Fluxora Design Token layer.
///
/// Definition-only tokens introduced in D4.3 and integrated into the theme
/// system in D4.4. Source of truth: `D4_BRAND_PROPOSAL.md`.
///
/// | file | tokens |
/// | --- | --- |
/// | `fluxora_colors.dart` | brand / neutral / status raw values + per-brightness semantic roles |
/// | `fluxora_typography.dart` | 6 text levels, 3 weights, monospaced numeric variants |
/// | `fluxora_spacing.dart` | 4-based spacing scale + `EdgeInsets` |
/// | `fluxora_radius.dart` | corner radius scale + `BorderRadius` |
/// | `fluxora_elevation.dart` | elevation ladder, shadow ladders, dark surface ladder |
/// | `fluxora_motion.dart` | durations, curves, reduced-motion resolution |
///
/// These files declare values only — they never read `ThemeData`,
/// `ThemeManager` or `BuildContext`.
library;

export 'fluxora_colors.dart';
export 'fluxora_elevation.dart';
export 'fluxora_motion.dart';
export 'fluxora_radius.dart';
export 'fluxora_spacing.dart';
export 'fluxora_typography.dart';
