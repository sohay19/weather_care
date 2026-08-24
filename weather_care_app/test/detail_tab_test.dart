import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/detail_tab.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  testWidgets('Detail 타임라인은 하루치인 24시간까지만 표시한다', (tester) async {
    final hourly = List.generate(
      30,
      (index) => HourlyWeatherItem(
        time: (index % 24).toString().padLeft(2, '0'),
        temperature: index.toDouble(),
        apparentTemperature: index.toDouble(),
        precipitationProbability: 0,
        precipitationAmount: 0,
        snowExpected: false,
        snowfallAmount: 0,
        windSpeed: 1,
        skyCondition: '맑음',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetailTab(
            today: TodayWeatherResponse(
              dataSource: 'test',
              region: const WeatherRegion(nx: 60, ny: 121, name: '수원'),
              brief: '테스트',
              current: const CurrentWeather(temperature: 0),
              recommendations: const [],
              lifestyleMessages: const [],
              timeline: const [],
              hourly: hourly,
            ),
            recommendations: const [],
            serverFeaturesAvailable: true,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('detail-hourly-23')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-hourly-24')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
