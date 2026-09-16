import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/features/home/tabs/today_tab.dart';
import 'package:weather_care/features/home/widgets/weather_card.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  const today = TodayWeatherResponse(
    dataSource: 'test',
    region: WeatherRegion(nx: 60, ny: 121, name: '수원'),
    brief: '테스트 날씨',
    current: CurrentWeather(temperature: 22),
    recommendations: [],
    lifestyleMessages: [],
    timeline: [],
    hourly: [
      HourlyWeatherItem(
        time: '15',
        temperature: 23,
        precipitationProbability: 0,
        precipitationAmount: 0,
        snowExpected: false,
        snowfallAmount: 0,
        windSpeed: 2,
        skyCondition: '맑음',
      ),
    ],
  );

  testWidgets('Today 광고는 현재 날씨와 시간별 예보 사이에 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayTab(
            today: today,
            onRefresh: () async {},
            advertisement: const SizedBox(
              key: ValueKey('test-today-advertisement'),
              height: 50,
            ),
          ),
        ),
      ),
    );

    final weather = tester.getTopLeft(find.byType(WeatherInfoCard)).dy;
    final advertisement = tester
        .getTopLeft(find.byKey(const ValueKey('test-today-advertisement')))
        .dy;
    final hourly = tester.getTopLeft(find.text('시간별 예보')).dy;
    expect(advertisement, greaterThan(weather));
    expect(advertisement, lessThan(hourly));
  });

  testWidgets('Main 광고는 콘텐츠 제일 하단에 표시한다', (tester) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MainTab(
            today: today,
            dateLabel: '9월 16일 수요일',
            mood: 'clear',
            serverFeaturesAvailable: true,
            onRefresh: () async {},
            onDetail: (_) {},
            advertisement: const SizedBox(
              key: ValueKey('test-main-advertisement'),
              height: 50,
            ),
          ),
        ),
      ),
    );

    final timeline = tester.getTopLeft(find.text('간단한 타임라인')).dy;
    final advertisement = tester
        .getTopLeft(find.byKey(const ValueKey('test-main-advertisement')))
        .dy;
    expect(advertisement, greaterThan(timeline));
  });
}
