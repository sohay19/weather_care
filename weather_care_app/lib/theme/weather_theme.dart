import 'package:flutter/material.dart';

class WeatherCareTheme {
  static const Color primary = Color(0xFF4E8FD8);
  static const Color primaryDeep = Color(0xFF2F6FBA);
  static const Color primarySoft = Color(0xFFEAF3FD);
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF708090);
  static const Color outline = Color(0xFFE5EAF0);
  static const Color shadow = Color(0x14263238);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primarySoft,
        onPrimaryContainer: primaryDeep,
        secondary: Color(0xFF79A9DC),
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        outline: outline,
        outlineVariant: Color(0xFFF0F3F7),
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadow,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
          side: BorderSide(color: outline),
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          height: 1.22,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: textPrimary),
        bodySmall: TextStyle(fontSize: 12, height: 1.4, color: textSecondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5FA),
        selectedColor: primarySoft,
        labelStyle: const TextStyle(
          color: textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(color: outline, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: Colors.white.withValues(alpha: 0.72),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : outline,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textPrimary,
        textColor: textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  static List<Color> moodColors(String base) {
    final safe = base.toLowerCase();
    return switch (safe) {
      'rain' => const [Color(0xFFEDF3F8), Color(0xFFE5EBF3)],
      'cloudy' => const [Color(0xFFF2F4F7), Color(0xFFE8EDF2)],
      'snow' => const [Color(0xFFF9FCFF), Color(0xFFEAF5FF)],
      'hot' => const [Color(0xFFFFF7E8), Color(0xFFFFF0E6)],
      'cold' => const [Color(0xFFF4FAFF), Color(0xFFE7F2FF)],
      'night' => const [Color(0xFFEEF1F8), Color(0xFFE5E9F3)],
      _ => const [Color(0xFFEAF4FF), Color(0xFFFFF7DF)],
    };
  }

  static BoxDecoration mood(String base, {BorderRadius? borderRadius}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: moodColors(base),
      ),
      borderRadius: borderRadius ?? const BorderRadius.all(Radius.circular(28)),
    );
  }

  static BoxDecoration surfaceDecoration({double radius = 26}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: outline),
      boxShadow: const [
        BoxShadow(color: shadow, blurRadius: 24, offset: Offset(0, 8)),
      ],
    );
  }
}
