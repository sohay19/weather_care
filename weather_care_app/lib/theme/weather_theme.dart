import 'package:flutter/material.dart';

class WeatherCareTheme {
  static const Color primary = Color(0xFF4E8FD8);
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF708090);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: primary,
        surface: surface,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0.5,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 15, color: textPrimary),
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.all(const Color(0xFFEEF3FA)),
        labelStyle: const TextStyle(color: textPrimary),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  static BoxDecoration mood(String base, {bool withAccent = false}) {
    final safe = base.toLowerCase();
    final colors = switch (safe) {
      'rain' => const [Color(0xFFEDF3F8), Color(0xFFE5EBF3)],
      'snow' => const [Color(0xFFF9FCFF), Color(0xFFEAF5FF)],
      'hot' => const [Color(0xFFFFF7E8), Color(0xFFFFF0E6)],
      'cold' => const [Color(0xFFF4FAFF), Color(0xFFE7F2FF)],
      'night' => const [Color(0xFFEEF1F8), Color(0xFFE5E9F3)],
      _ => const [Color(0xFFEAF4FF), Color(0xFFFFF7DF)],
    };
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      borderRadius: const BorderRadius.all(Radius.circular(24)),
    );
  }
}

