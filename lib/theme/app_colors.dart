import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF2EFF7);
  static const Color surface = Color(0xEFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF7F5FA);

  static const Color accent = Color(0xFF8064C8);
  static const Color accentSoft = Color(0xFFB6A4E5);
  static const Color accentWarm = Color(0xFF9679D8);

  static const Color textPrimary = Color(0xFF292536);
  static const Color textSecondary = Color(0xFF827C91);
  static const Color border = Color(0xFFE8E2F0);

  static const Color danger = Color(0xFFD95D70);
  static const Color warning = Color(0xFFE5A13B);
  static const Color success = Color(0xFF279B70);

  static const LinearGradient heroGlow = LinearGradient(
    colors: [
      Color(0x33B6A4E5),
      Color(0x00F2EFF7),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlow = LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF7F5FA),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Premium Glass 2.0 dynamic color palette.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color accent;
  final Color accentSoft;
  final Color accentWarm;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color danger;
  final Color warning;
  final Color success;
  final Color glassOverlay;
  final Color shadow;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.accent,
    required this.accentSoft,
    required this.accentWarm,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.danger,
    required this.warning,
    required this.success,
    required this.glassOverlay,
    required this.shadow,
  });

  static const light = AppPalette(
    background: Color(0xFFF5F3FA),
    surface: Color(0xEFFFFFFF),
    surfaceAlt: Color(0xFFF0EDF7),
    accent: Color(0xFF7656C9),
    accentSoft: Color(0xFFB9A7E8),
    accentWarm: Color(0xFF9275D5),
    textPrimary: Color(0xFF242033),
    textSecondary: Color(0xFF716B80),
    border: Color(0xFFE5E0EF),
    danger: Color(0xFFD9536F),
    warning: Color(0xFFD9912B),
    success: Color(0xFF238B68),
    glassOverlay: Color(0xBFFFFFFF),
    shadow: Color(0x10000000),
  );

  static const dark = AppPalette(
    background: Color(0xFF0D1020),
    surface: Color(0xFF191D30),
    surfaceAlt: Color(0xFF22263B),
    accent: Color(0xFFA78BFA),
    accentSoft: Color(0xFFC4B5FD),
    accentWarm: Color(0xFF9D8CE8),
    textPrimary: Color(0xFFF4F1FF),
    textSecondary: Color(0xFFAAA6BF),
    border: Color(0xFF30344D),
    danger: Color(0xFFFF8295),
    warning: Color(0xFFF3BC65),
    success: Color(0xFF55D6A5),
    glassOverlay: Color(0x1FFFFFFF),
    shadow: Color(0x40000000),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? accent,
    Color? accentSoft,
    Color? accentWarm,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? danger,
    Color? warning,
    Color? success,
    Color? glassOverlay,
    Color? shadow,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentWarm: accentWarm ?? this.accentWarm,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      glassOverlay: glassOverlay ?? this.glassOverlay,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;

    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentWarm: Color.lerp(accentWarm, other.accentWarm, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      glassOverlay: Color.lerp(glassOverlay, other.glassOverlay, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get appPalette => Theme.of(this).extension<AppPalette>()!;
}
