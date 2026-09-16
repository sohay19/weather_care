import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/detail_tab.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/features/home/tabs/today_tab.dart';
import 'package:weather_care/features/home/tabs/week_tab.dart';
import 'package:weather_care/features/home/widgets/pull_to_refresh_data_hint.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  const incompleteToday = TodayWeatherResponse(
    dataSource: 'test',
    region: WeatherRegion(nx: 60, ny: 121, name: '수원'),
    brief: '일부 자료 확인 중',
    current: CurrentWeather(temperature: 22),
    recommendations: [],
    lifestyleMessages: [],
    timeline: [],
    hourly: [],
  );

  testWidgets('일부 자료가 없으면 각 탭에 아래로 당겨 재요청 안내를 표시한다', (tester) async {
    Future<void> expectHint(Widget child) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
      expect(find.text(PullToRefreshDataHint.message), findsOneWidget);
    }

    await expectHint(TodayTab(
      today: incompleteToday,
      onRefresh: () async {},
    ));
    await expectHint(MainTab(
      today: incompleteToday,
      dateLabel: '9월 16일',
      mood: 'clear',
      serverFeaturesAvailable: true,
      yesterdayComparison: const ComparisonResponse.unavailable(),
      onRefresh: () async {},
      onDetail: (_) {},
    ));
    await expectHint(DetailTab(
      today: incompleteToday,
      recommendations: const [],
      serverFeaturesAvailable: false,
      onRefresh: () async {},
    ));
    await expectHint(WeekTab(
      weekly: const WeeklyWeatherResponse(days: []),
      serverFeaturesAvailable: true,
      onRefresh: () async {},
      now: () => DateTime(2026, 9, 16, 12),
    ));
  });

  testWidgets('Main 최상단 날씨와 Check List 사이에 어제 비교 결과를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const completeToday = TodayWeatherResponse(
      dataSource: 'test',
      region: WeatherRegion(nx: 60, ny: 121, name: '수원'),
      brief: '맑고 포근해요',
      current: CurrentWeather(
        temperature: 22,
        apparentTemperature: 21,
        humidity: 55,
        windSpeed: 2,
        uvIndex: 4,
        pm10: 30,
        pm25: 15,
        sky: '맑음',
      ),
      recommendations: [],
      lifestyleMessages: [],
      timeline: [],
      hourly: [],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MainTab(
          today: completeToday,
          dateLabel: '9월 16일',
          mood: 'clear',
          serverFeaturesAvailable: true,
          yesterdayComparison: const ComparisonResponse(
            comparisonAvailable: true,
            targetDate: '2026-09-15',
            comparison: ComparisonWeatherSnapshot(
              temperature: 20,
              apparentTemperature: 19,
              pm10: 34,
              pm25: 18,
              skyCondition: '구름 많음',
            ),
          ),
          onRefresh: () async {},
          onDetail: (_) {},
        ),
      ),
    ));

    expect(find.text('어제와 비교'), findsOneWidget);
    expect(find.text('기온은 어제보다 2.0℃ 높아요.'), findsOneWidget);
    final top = tester.getTopLeft(
      find.byKey(const ValueKey('main-top-weather-card')),
    );
    final comparison = tester.getTopLeft(
      find.byKey(const ValueKey('yesterday-comparison-card')),
    );
    final checklist = tester.getTopLeft(find.text('Check List'));
    expect(comparison.dy, greaterThan(top.dy));
    expect(comparison.dy, lessThan(checklist.dy));
    expect(find.text(PullToRefreshDataHint.message), findsNothing);
  });
}
