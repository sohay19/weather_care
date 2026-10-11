import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/app.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/theme/weather_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('앱은 시스템 모드를 지정하고 실행 중 변경에 맞춰 설정 화면을 갱신한다', (tester) async {
    final app = const WeatherCareApp().build(tester.element(find.byType(View)));
    expect((app as MaterialApp).themeMode, ThemeMode.system);
    expect(app.darkTheme?.brightness, Brightness.dark);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(MaterialApp(
      theme: app.theme,
      darkTheme: app.darkTheme,
      themeMode: app.themeMode,
      home: const SettingsScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('system-theme-status')), findsNothing);
    final lightContext = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(lightContext).brightness, Brightness.light);
    expect(Theme.of(lightContext).scaffoldBackgroundColor,
        WeatherCarePalette.light.background);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    final darkContext = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(darkContext).brightness, Brightness.dark);
    expect(Theme.of(darkContext).scaffoldBackgroundColor,
        WeatherCarePalette.dark.background);
    expect(WeatherCareTheme.of(darkContext).textPrimary,
        WeatherCarePalette.dark.textPrimary);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
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
    final weatherCard = tester
        .widgetList<Container>(find.byType(Container))
        .where((widget) =>
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).gradient != null)
        .first;
    expect(
        ((weatherCard.decoration as BoxDecoration).gradient as LinearGradient)
            .colors
            .first,
        palette.primarySoft);
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
