import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/detail_tab.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/features/home/tabs/today_tab.dart';
import 'package:weather_care/features/home/tabs/week_tab.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/recommendation.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/theme/weather_theme.dart';

final _recommendations = <WeatherRecommendation>[
  WeatherRecommendation(
    type: RecommendationType.umbrella,
    recommended: true,
    priority: 90,
    title: '우산',
    description: '오후부터 비가 올 가능성이 높아요.',
    notificationEligible: true,
  ),
  WeatherRecommendation(
    type: RecommendationType.sunscreen,
    recommended: true,
    priority: 70,
    title: '선크림',
    description: '한낮 자외선이 강해요.',
    notificationEligible: true,
  ),
];

final _today = TodayWeatherResponse(
  dataSource: 'test',
  region: WeatherRegion(nx: 60, ny: 121, name: '서울특별시 종로구'),
  brief: '오후부터 비가 내려요. 외출할 때 작은 우산을 챙겨요.',
  current: const CurrentWeather(
    temperature: 23.4,
    apparentTemperature: 25.1,
    humidity: 72,
    windSpeed: 3.7,
    uvIndex: 7,
    pm10: 42,
    pm25: 22,
    sky: '구름 많음',
  ),
  recommendations: _recommendations,
  lifestyleMessages: [],
  timeline: [
    TimelineItem(
      timeLabel: '12',
      stateLabel: '구름이 많고 자외선이 강해요',
      detail: '예상기온 25℃ · 강수확률 20%',
      recommendations: _recommendations,
    ),
    TimelineItem(
      timeLabel: '18',
      stateLabel: '퇴근길에는 비가 올 수 있어요',
      detail: '예상기온 21℃ · 강수확률 70%',
      recommendations: _recommendations,
    ),
  ],
  hourly: [
    const HourlyWeatherItem(
      time: '12',
      temperature: 25,
      apparentTemperature: 27,
      precipitationProbability: 20,
      precipitationAmount: 0,
      snowExpected: false,
      snowfallAmount: 0,
      windSpeed: 2.3,
      uvIndex: 7,
      pm10: 42,
      pm25: 22,
      skyCondition: '구름 많음',
    ),
    const HourlyWeatherItem(
      time: '18',
      temperature: 21,
      apparentTemperature: 21,
      precipitationProbability: 70,
      precipitationAmount: 3,
      snowExpected: false,
      snowfallAmount: 0,
      windSpeed: 3.7,
      uvIndex: 1,
      pm10: 35,
      pm25: 18,
      skyCondition: '비',
    ),
  ],
);

final _weekly = WeeklyWeatherResponse(
  days: List.generate(
    7,
    (index) => WeeklyForecastItem(
      date: '9월 ${18 + index}일',
      forecastDate: '2026-09-${(18 + index).toString().padLeft(2, '0')}',
      weatherLabel: index.isEven ? '구름 많음' : '비',
      weatherDataComplete: true,
      min: 17 + index.toDouble(),
      max: 25 + index.toDouble(),
      recommendations:
          index.isEven ? _recommendations : const <WeatherRecommendation>[],
    ),
  ),
);

void main() {
  final screens = <String, Widget Function()>{
    'main': () => MainTab(
          today: _today,
          dateLabel: '9월 18일 금요일',
          mood: 'cloudy',
          serverFeaturesAvailable: true,
          onRefresh: () async {},
          onDetail: (_) {},
        ),
    'today': () => TodayTab(today: _today, onRefresh: () async {}),
    'detail': () => DetailTab(
          today: _today,
          recommendations: _recommendations,
          serverFeaturesAvailable: true,
          onRefresh: () async {},
        ),
    'week': () => WeekTab(
          weekly: _weekly,
          serverFeaturesAvailable: true,
          onRefresh: () async {},
          now: () => DateTime(2026, 9, 18),
        ),
    'setting': () => const SettingsScreen(embedded: true),
  };

  for (final entry in screens.entries) {
    testWidgets('320x568·1.3 ${entry.key} 시각 점검', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final screen = entry.value();
      await tester.pumpWidget(_shell(screen));
      await tester.pump();
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(screen.runtimeType)),
        ).scale(10),
        13,
      );
      expect(tester.takeException(), isNull, reason: entry.key);

      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        for (var index = 0; index < 5; index++) {
          await tester.drag(scrollable.first, const Offset(0, -400));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${entry.key} $index');
        }
      }
    });
  }
}

Widget _shell(Widget screen) {
  return MaterialApp(
    theme: WeatherCareTheme.light(),
    builder: WeatherCareTheme.textScaleBuilder,
    home: Scaffold(
      body: SafeArea(child: screen),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        height: 74,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.query_stats), label: 'Detail'),
          NavigationDestination(icon: Icon(Icons.home), label: 'Main'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month), label: 'Week'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Setting'),
        ],
      ),
    ),
  );
}
