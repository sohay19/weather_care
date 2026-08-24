import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/detail_tab.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  testWidgets('Detail 타임라인은 한국시간 오늘 23시까지만 표시한다', (tester) async {
    final nowInKorea = DateTime.now().toUtc().add(const Duration(hours: 9));
    final today = _isoDate(nowInKorea);
    final tomorrow = _isoDate(nowInKorea.add(const Duration(days: 1)));
    final hourly = [
      ...List.generate(
        6,
        (index) => HourlyWeatherItem(
          time: (index + 18).toString().padLeft(2, '0'),
          forecastDate: today,
          temperature: index.toDouble(),
          apparentTemperature: index.toDouble(),
          precipitationProbability: 0,
          precipitationAmount: 0,
          snowExpected: false,
          snowfallAmount: 0,
          windSpeed: 1,
          skyCondition: '맑음',
        ),
      ),
      ...List.generate(
        24,
        (index) => HourlyWeatherItem(
          time: index.toString().padLeft(2, '0'),
          forecastDate: tomorrow,
          temperature: (index + 100).toDouble(),
          apparentTemperature: (index + 100).toDouble(),
          precipitationProbability: 0,
          precipitationAmount: 0,
          snowExpected: false,
          snowfallAmount: 0,
          windSpeed: 1,
          skyCondition: '맑음',
        ),
      ),
    ];

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

    expect(find.byKey(const ValueKey('detail-hourly-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-hourly-6')), findsNothing);
    expect(find.text('23시'), findsOneWidget);
    expect(find.text('00시'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

String _isoDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
