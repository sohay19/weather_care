import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/models/lifestyle_message.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  testWidgets('체크리스트는 발생 가능성과 앱 계산 라벨 없이 내용을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MainTab(
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
            dateLabel: '9월 14일',
            mood: 'cloudy',
            serverFeaturesAvailable: true,
            onRefresh: () async {},
            onDetail: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('수원시 오늘 날씨'), findsOneWidget);
    expect(
      find.text('구름이 많은 날씨예요. 체감 상 조금 덥게 느껴질 수 있어요.'),
      findsOneWidget,
    );
    expect(find.textContaining('예상 체감온도는 24.2℃'), findsNothing);
    expect(find.textContaining('기온·습도·풍속 기준'), findsNothing);
    expect(find.textContaining('발생 가능성'), findsNothing);
    expect(find.textContaining('앱 계산'), findsNothing);
    expect(find.text('아침과 낮의 옷차림이 달라질 수 있어요.'), findsOneWidget);
    expect(find.text('예보 최저·최고기온 차이는 11℃예요.'), findsOneWidget);
    expect(find.textContaining('공식 정보 ·'), findsOneWidget);
  });
}
