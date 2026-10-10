import 'package:flutter/material.dart';

class WeatherCareTheme {
  // 카테고리는 아이콘과 문구로 구분하고, 화면 색상은 이 팔레트 안에서만 사용한다.
  static const double minimumTextScale = 1.1;
  static const double maximumTextScale = 1.3;
  static const String fontSuite = 'SUITE';
  static const String fontChosunSg = 'ChosunSg';
  static const String fontMona = 'Mona';
  static const String fontNeoHyundai = 'NeoHyundai';

  static const Color primary = Color(0xFF5D7F9E);
  static const Color primaryDeep = Color(0xFF3E5F7C);
  static const Color primarySoft = Color(0xFFEAF0F5);
  static const Color primaryBorder = Color(0xFFCEDAE4);
  static const Color background = Color(0xFFF6F7F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF2F4F6);
  static const Color surfaceSubtle = Color(0xFFF8F9FA);
  static const Color textPrimary = Color(0xFF29343D);
  static const Color textSecondary = Color(0xFF63707A);
  static const Color outline = Color(0xFFE2E7EA);
  static const Color shadow = Color(0x1229343D);
  static const Color attention = Color(0xFFB27A3D);
  static const Color attentionDeep = Color(0xFF7E582F);
  static const Color attentionSoft = Color(0xFFFAF3E8);
  static const Color danger = Color(0xFFB4534B);

  static const TextStyle specialLabelStyle = TextStyle(
    fontFamily: fontMona,
    color: primaryDeep,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  static const TextStyle microTextStyle = TextStyle(
    fontFamily: fontChosunSg,
    color: textSecondary,
    fontSize: 10,
    height: 1.4,
  );

  static MediaQueryData scaledMediaQuery(MediaQueryData data) {
    return data.copyWith(
      textScaler: data.textScaler.clamp(
        minScaleFactor: minimumTextScale,
        maxScaleFactor: maximumTextScale,
      ),
    );
  }

  static Widget textScaleBuilder(BuildContext context, Widget? child) {
    return MediaQuery(
      data: scaledMediaQuery(MediaQuery.of(context)),
      child: child ?? const SizedBox.shrink(),
    );
  }

  static WeatherCarePalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<WeatherCarePalette>() ??
        (theme.brightness == Brightness.dark
            ? WeatherCarePalette.dark
            : WeatherCarePalette.light);
  }

  static ThemeData light() => _build(WeatherCarePalette.light);

  static ThemeData dark() => _build(WeatherCarePalette.dark);

  static ThemeData _build(WeatherCarePalette palette) {
    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      extensions: [palette],
      fontFamily: fontSuite,
      colorScheme: ColorScheme(
        brightness: palette.brightness,
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        primaryContainer: palette.primarySoft,
        onPrimaryContainer: palette.primaryDeep,
        secondary: palette.primaryDeep,
        onSecondary: palette.onPrimary,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        onSurfaceVariant: palette.textSecondary,
        surfaceContainerHighest: palette.surfaceMuted,
        error: palette.danger,
        onError: palette.onPrimary,
        outline: palette.outline,
        outlineVariant: palette.surfaceMuted,
      ),
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontNeoHyundai,
          color: palette.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: palette.shadow,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(26)),
          side: BorderSide(color: palette.outline),
        ),
      ),
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontFamily: fontNeoHyundai,
          fontSize: 32,
          height: 1.22,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
          color: palette.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontFamily: fontNeoHyundai,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: palette.textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: fontNeoHyundai,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.35,
          color: palette.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        bodyLarge:
            TextStyle(fontSize: 16, height: 1.5, color: palette.textPrimary),
        bodyMedium:
            TextStyle(fontSize: 14, height: 1.45, color: palette.textPrimary),
        bodySmall: TextStyle(
          fontFamily: fontChosunSg,
          fontSize: 12,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: palette.textSecondary,
        ),
        labelSmall: palette.microTextStyle,
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceMuted,
        selectedColor: palette.primarySoft,
        labelStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      dividerTheme: DividerThemeData(color: palette.outline, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: palette.actionBackground,
          foregroundColor: palette.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.textPrimary,
          backgroundColor: palette.surface.withValues(alpha: 0.72),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.primary
              : palette.outline,
        ),
        thumbColor: WidgetStatePropertyAll(palette.onPrimary),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? palette.primaryDeep
                  : palette.textSecondary,
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w400,
            )),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textPrimary,
        textColor: palette.textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

/// 화면의 Theme에서 얻는 색상. 시스템 모드 전환에도 전역 상태를 사용하지 않는다.
@immutable
class WeatherCarePalette extends ThemeExtension<WeatherCarePalette> {
  final Brightness brightness;
  final Color primary;
  final Color primaryDeep;
  final Color primarySoft;
  final Color primaryBorder;
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color outline;
  final Color shadow;
  final Color attention;
  final Color attentionDeep;
  final Color attentionSoft;
  final Color danger;

  const WeatherCarePalette({
    required this.brightness,
    required this.primary,
    required this.primaryDeep,
    required this.primarySoft,
    required this.primaryBorder,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.shadow,
    required this.attention,
    required this.attentionDeep,
    required this.attentionSoft,
    required this.danger,
  });

  static const light = WeatherCarePalette(
    brightness: Brightness.light,
    primary: Color(0xFF5D7F9E),
    primaryDeep: Color(0xFF3E5F7C),
    primarySoft: Color(0xFFEAF0F5),
    primaryBorder: Color(0xFFCEDAE4),
    background: Color(0xFFF6F7F8),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF2F4F6),
    surfaceSubtle: Color(0xFFF8F9FA),
    textPrimary: Color(0xFF29343D),
    textSecondary: Color(0xFF63707A),
    outline: Color(0xFFE2E7EA),
    shadow: Color(0x1229343D),
    attention: Color(0xFFB27A3D),
    attentionDeep: Color(0xFF7E582F),
    attentionSoft: Color(0xFFFAF3E8),
    danger: Color(0xFFB4534B),
  );

  static const dark = WeatherCarePalette(
    brightness: Brightness.dark,
    primary: Color(0xFF9DBDD8),
    primaryDeep: Color(0xFFB7D0E5),
    primarySoft: Color(0xFF253747),
    primaryBorder: Color(0xFF40566A),
    background: Color(0xFF141B22),
    surface: Color(0xFF1D2731),
    surfaceMuted: Color(0xFF26323E),
    surfaceSubtle: Color(0xFF202B36),
    textPrimary: Color(0xFFEDF2F6),
    textSecondary: Color(0xFFAAB7C3),
    outline: Color(0xFF34424F),
    shadow: Color(0x26000000),
    attention: Color(0xFFE6B879),
    attentionDeep: Color(0xFFE6B879),
    attentionSoft: Color(0xFF372C20),
    danger: Color(0xFFF0A39B),
  );

  Color get onPrimary =>
      brightness == Brightness.dark ? const Color(0xFF172736) : Colors.white;
  Color get actionBackground =>
      brightness == Brightness.dark ? primary : primaryDeep;

  TextStyle get specialLabelStyle =>
      WeatherCareTheme.specialLabelStyle.copyWith(color: primaryDeep);
  TextStyle get microTextStyle =>
      WeatherCareTheme.microTextStyle.copyWith(color: textSecondary);

  List<Color> moodColors(String base) {
    if (brightness == Brightness.dark) {
      return switch (base.toLowerCase()) {
        'rain' => [primarySoft, const Color(0xFF1E2C39)],
        'snow' => [const Color(0xFF293B4A), const Color(0xFF22323F)],
        'night' => [const Color(0xFF202D3A), const Color(0xFF19232E)],
        _ => [primarySoft, const Color(0xFF1F2D3A)],
      };
    }
    return WeatherCareTheme.moodColors(base);
  }

  BoxDecoration mood(String base, {BorderRadius? borderRadius}) =>
      BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: moodColors(base)),
        borderRadius:
            borderRadius ?? const BorderRadius.all(Radius.circular(28)),
      );

  BoxDecoration surfaceDecoration({double radius = 26}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: outline),
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8))
        ],
      );

  @override
  WeatherCarePalette copyWith({
    Brightness? brightness,
    Color? primary,
    Color? primaryDeep,
    Color? primarySoft,
    Color? primaryBorder,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? outline,
    Color? shadow,
    Color? attention,
    Color? attentionDeep,
    Color? attentionSoft,
    Color? danger,
  }) =>
      WeatherCarePalette(
        brightness: brightness ?? this.brightness,
        primary: primary ?? this.primary,
        primaryDeep: primaryDeep ?? this.primaryDeep,
        primarySoft: primarySoft ?? this.primarySoft,
        primaryBorder: primaryBorder ?? this.primaryBorder,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceMuted: surfaceMuted ?? this.surfaceMuted,
        surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        outline: outline ?? this.outline,
        shadow: shadow ?? this.shadow,
        attention: attention ?? this.attention,
        attentionDeep: attentionDeep ?? this.attentionDeep,
        attentionSoft: attentionSoft ?? this.attentionSoft,
        danger: danger ?? this.danger,
      );

  @override
  WeatherCarePalette lerp(covariant WeatherCarePalette? other, double t) {
    if (other == null) return this;
    return WeatherCarePalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDeep: Color.lerp(primaryDeep, other.primaryDeep, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primaryBorder: Color.lerp(primaryBorder, other.primaryBorder, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
      attentionDeep: Color.lerp(attentionDeep, other.attentionDeep, t)!,
      attentionSoft: Color.lerp(attentionSoft, other.attentionSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
