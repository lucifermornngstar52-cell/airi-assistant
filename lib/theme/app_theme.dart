import 'package:flutter/material.dart';

class AppTheme {
  // Цвета из скрина — тёмная тема
  static const bgColor       = Color(0xFF1A1A1A);
  static const cardColor     = Color(0xFF242424);
  static const cardBorder    = Color(0xFF2E2E2E);
  static const textPrimary   = Color(0xFFE8E8E8);
  static const textSecondary = Color(0xFF888888);
  static const accentBlue    = Color(0xFF4A9EFF);
  static const accentPurple  = Color(0xFF8B6EFF);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgColor,
    colorScheme: const ColorScheme.dark(
      surface: cardColor,
      primary: accentBlue,
      secondary: accentPurple,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bgColor,
      elevation: 0,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardTheme(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: cardBorder, width: 0.5),
      ),
    ),
    fontFamily: 'sans-serif',
  );

  // ── AikaTheme-совместимые алиасы ──────────────────────────────
  static const Color neonBlue = Color(0xFF00D4FF);
  static const Color neonPurple = Color(0xFF9D4EDD);
  static const Color neonPink = Color(0xFFFF006E);
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color surface = Color(0xFF0D1120);
  static const Color background = Color(0xFF080B14);
  static const Color card = Color(0xFF111827);
  static const Color userBubble = Color(0xFF1C1E2A);
  static const Color aikaBubble = Color(0xFF0D1F3C);
}
