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
