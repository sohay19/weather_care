import 'package:flutter/material.dart';

class WeatherCareTheme {
  // 카테고리는 아이콘과 문구로 구분하고, 화면 색상은 이 팔레트 안에서만 사용한다.
  static const Color primary = Color(0xFF5D7F9E);
  static const Color primaryDeep = Color(0xFF3E5F7C);
  static const Color primarySoft = Color(0xFFEAF0F5);
  static const Color primaryBorder = Color(0xFFCEDAE4);
  static const Color background = Color(0xFFF6F7F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF2F4F6);
  static const Color surfaceSubtle = Color(0xFFF8F9FA);
  static const Color textPrimary = Color(0xFF29343D);
  static const Color textSecondary = Color(0xFF73808A);
  static const Color outline = Color(0xFFE2E7EA);
  static const Color shadow = Color(0x1229343D);
  static const Color attention = Color(0xFFB27A3D);
  static const Color attentionDeep = Color(0xFF7E582F);
  static const Color attentionSoft = Color(0xFFFAF3E8);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primarySoft,
        onPrimaryContainer: primaryDeep,
        secondary: primaryDeep,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        outline: outline,
        outlineVariant: surfaceMuted,
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
        backgroundColor: surfaceMuted,
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
      'rain' => const [Color(0xFFE7EDF2), Color(0xFFDDE7EE)],
      'cloudy' => const [Color(0xFFEDF1F4), Color(0xFFE3E9ED)],
      'snow' => const [Color(0xFFF2F5F7), Color(0xFFE8EEF2)],
      'night' => const [Color(0xFFE7EBF0), Color(0xFFDDE5EB)],
      _ => const [Color(0xFFEAF0F5), Color(0xFFF2F4F6)],
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
