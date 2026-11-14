/// Stable IDs are shared with Android aliases and the asset generator.
abstract final class BrandIcons {
  static const styles = {
    'official': ('官方默认', 'Official'),
    'classic': ('经典', 'Classic'),
    'aqua': ('水色', 'Aqua'),
    'premium': ('高级版', 'Premium'),
    'speed': ('极速', 'Speed'),
    'sky': ('天空', 'Sky'),
    'sunset': ('日落', 'Sunset'),
    'blue_night': ('蓝夜', 'Blue night'),
  };

  // Sampled from the gradient and orbit accents in the bundled icon artwork.
  static const paletteSeeds = {
    'official': 0xFF007AD2,
    'classic': 0xFF0146CA,
    'aqua': 0xFF0195B0,
    'premium': 0xFFE746C1,
    'speed': 0xFF6E44DC,
    'sky': 0xFF78C2F8,
    'sunset': 0xFFF36D69,
    'blue_night': 0xFF01316C,
  };

  static const notificationStyles = {
    'flow': ('轨道 F', 'Orbit F'),
    'plain': ('极简 F', 'Minimal F'),
    'outline': ('线框 F', 'Outline F'),
  };

  static String normalizeNotification(String style) =>
      notificationStyles.containsKey(style) ? style : 'flow';

  static String normalize(String style) =>
      styles.containsKey(style) ? style : 'official';

  static String label(String style, {required bool chinese}) {
    final names = styles[normalize(style)]!;
    return chinese ? names.$1 : names.$2;
  }

  static String asset(String style, bool dark) =>
      'assets/images/brand/brand_${normalize(style)}_${dark ? 'dark' : 'light'}.webp';
}
