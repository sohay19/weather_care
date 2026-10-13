import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/theme/weather_theme.dart';
import 'package:weather_care/services/theme_mode_settings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('신규 설치에 저장된 테마가 없으면 시스템 설정을 따른다', () async {
    await ThemeModeSettings.instance.load();
    expect(ThemeModeSettings.instance.value, ThemeMode.system);
  });

  testWidgets('설정 모드 선택이 즉시 적용·저장되고 시스템 모드에서 기기 설정을 따른다', (tester) async {
    await ThemeModeSettings.instance.load();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeModeSettings.instance,
      builder: (context, mode, _) => MaterialApp(
        theme: WeatherCareTheme.light()
            .copyWith(splashFactory: NoSplash.splashFactory),
        darkTheme: WeatherCareTheme.dark()
            .copyWith(splashFactory: NoSplash.splashFactory),
        themeMode: mode,
        home: const SettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    final lightContext = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(lightContext).brightness, Brightness.light);
    expect(Theme.of(lightContext).scaffoldBackgroundColor,
        WeatherCarePalette.light.background);

    await tester.tap(find.byKey(const ValueKey('theme-mode-menu')));
    await tester.pumpAndSettle();
    expect(find.text('라이트'), findsOneWidget);
    expect(find.text('다크'), findsOneWidget);
    expect(find.text('시스템 설정에 따름'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme-mode-dark')));
    await tester.pumpAndSettle();
    expect(ThemeModeSettings.instance.value, ThemeMode.dark);
    expect(
        Theme.of(tester.element(find.byKey(const ValueKey('theme-mode-dark'))))
            .brightness,
        Brightness.dark);
    await ThemeModeSettings.instance.load();
    expect(ThemeModeSettings.instance.value, ThemeMode.dark);

    await tester.tap(find.byKey(const ValueKey('theme-mode-light')));
    await tester.pumpAndSettle();
    expect(
        Theme.of(tester.element(find.byKey(const ValueKey('theme-mode-light'))))
            .brightness,
        Brightness.light);
    await tester.tap(find.byKey(const ValueKey('theme-mode-system')));
    await tester.pumpAndSettle();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    final darkContext =
        tester.element(find.byKey(const ValueKey('theme-mode-system')));
    expect(Theme.of(darkContext).brightness, Brightness.dark);
    expect(Theme.of(darkContext).scaffoldBackgroundColor,
        WeatherCarePalette.dark.background);
    expect(WeatherCareTheme.of(darkContext).textPrimary,
        WeatherCarePalette.dark.textPrimary);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
        Theme.of(
                tester.element(find.byKey(const ValueKey('theme-mode-system'))))
            .brightness,
        Brightness.light);
    expect(tester.takeException(), isNull);
  });

  testWidgets('어두운 날씨 카드와 경고 지표는 작은 화면·큰 글자에서도 표시된다', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = TodayWeatherResponse.fromJson({
      'region': {'name': '서울시 종로구', 'nx': 60, 'ny': 127},
      'brief': '바람이 강해요. 외출 전 예보를 확인해요.',
      'current': {
        'temperature': 21.4,
        'apparentTemperature': 21.1,
        'skyCondition': '구름많음',
        'humidity': 60,
        'windSpeed': 15,
        'windDirection': 45,
        'uvIndex': 8,
        'pm10': 20,
        'pm25': 10,
        'visibilityMeters': 15000
      },
      'recommendations': [],
      'timeline': [],
      'hourly': [],
    });
    await tester.pumpWidget(MaterialApp(
      theme: WeatherCareTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: Scaffold(
          body: MainTab(
        today: today,
        dateLabel: '10월 10일 토요일',
        mood: 'cloudy',
        serverFeaturesAvailable: true,
        onRefresh: () async {},
        onDetail: (_) {},
      )),
    ));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(MainTab));
    final palette = WeatherCareTheme.of(context);
    expect(palette.moodColors('cloudy').first,
        WeatherCarePalette.dark.primarySoft);
    final weatherCard = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('main-top-weather-card')));
    expect(weatherCard.decoration, palette.surfaceDecoration());
    final windMetric = find.byKey(const ValueKey('main-top-metric-바람'));
    expect(
        tester
            .widget<Icon>(
                find.descendant(of: windMetric, matching: find.byType(Icon)))
            .color,
        palette.danger);
    final uvMetric = find.byKey(const ValueKey('main-top-metric-자외선'));
    expect(
        tester
            .widget<Icon>(
                find.descendant(of: uvMetric, matching: find.byType(Icon)))
            .color,
        palette.danger);
    expect(tester.takeException(), isNull);
  });
}
