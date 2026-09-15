import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/detail_tab.dart';
import 'package:weather_care/models/lifestyle_message.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  testWidgets('Detail 체크리스트는 행동·판단·계산·공식 자료를 한 세트로 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetailTab(
            today: TodayWeatherResponse(
              dataSource: 'test',
              region: const WeatherRegion(nx: 60, ny: 121, name: '수원시'),
              brief: '테스트',
              current: const CurrentWeather(
                temperature: 22,
                apparentTemperature: 24.2,
                apparentTemperatureSource: 'APP_KMA_METHOD_FROM_FORECAST',
                sky: '구름 많음',
              ),
              recommendations: const [],
              lifestyleMessages: [
                LifestyleMessage(
                  type: LifestyleMessageType.largeTemperatureSwing,
                  title: '벗어 들기 쉬운 겉옷을 준비하세요',
                  parts: const [
                    WeatherMessagePart(
                      role: WeatherMessageRole.appSuggestion,
                      text: '벗어 들기 쉬운 겉옷을 준비하세요',
                    ),
                    WeatherMessagePart(
                      role: WeatherMessageRole.internalPossibility,
                      text: '아침과 낮의 옷차림이 달라질 수 있어요.',
                    ),
                    WeatherMessagePart(
                      role: WeatherMessageRole.calculatedFact,
                      text: '예보 최저·최고기온 차이는 11℃예요.',
                    ),
                    WeatherMessagePart(
                      role: WeatherMessageRole.officialFact,
                      text: '기상청 예보를 확인했어요.',
                    ),
                  ],
                ),
              ],
              timeline: const [],
              hourly: const [],
            ),
            recommendations: const [],
            serverFeaturesAvailable: true,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.text('상세 자료'), findsOneWidget);
    expect(find.text('체크할 일'), findsOneWidget);
    expect(find.text('판단 근거'), findsOneWidget);
    expect(find.text('계산 근거'), findsOneWidget);
    expect(find.text('사용한 자료'), findsOneWidget);
    expect(find.text('아침과 낮의 옷차림이 달라질 수 있어요.'), findsOneWidget);
    expect(find.text('예보 최저·최고기온 차이는 11℃예요.'), findsOneWidget);
    expect(find.text('기상청 예보를 확인했어요.'), findsOneWidget);
  });
}
