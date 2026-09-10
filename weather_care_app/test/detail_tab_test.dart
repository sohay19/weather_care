import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/detail_tab.dart';
import 'package:weather_care/models/lifestyle_message.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/notification_destination.dart';

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
    expect(find.text('눈 없음'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('알림 주제의 근거를 앞에 배치하고 화면 안으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final messages = [
      ...List.generate(
        5,
        (index) => LifestyleMessage(
          type: LifestyleMessageType.strongSunExposure,
          title: '다른 근거 $index',
        ),
      ),
      LifestyleMessage(
        type: LifestyleMessageType.commuteRouteCaution,
        title: '출퇴근 경로 행동',
        description: '도로 통제 가능성을 확인해요',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetailTab(
            today: TodayWeatherResponse(
              dataSource: 'test',
              region: const WeatherRegion(nx: 60, ny: 127, name: '서울'),
              brief: '테스트',
              current: const CurrentWeather(temperature: 20),
              recommendations: const [],
              lifestyleMessages: messages,
              timeline: const [],
              hourly: const [],
            ),
            recommendations: const [],
            serverFeaturesAvailable: true,
            focusTopic: NotificationTopic.commute,
            onRefresh: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final focused = find.byKey(const ValueKey('detail-focused-evidence'));
    expect(focused, findsOneWidget);
    expect(find.text('알림에서 확인한 항목'), findsOneWidget);
    expect(find.text('출퇴근 경로 행동'), findsOneWidget);
    expect(tester.getTopLeft(focused).dy, inInclusiveRange(0, 600));
  });

  test('알림 주제는 관련 생활근거 유형에 연결된다', () {
    expect(
      lifestyleTypesForNotificationTopic(NotificationTopic.precipitation),
      containsAll({
        LifestyleMessageType.rainGearUseful,
        LifestyleMessageType.wetRoadCaution,
      }),
    );
    expect(
      lifestyleTypesForNotificationTopic(NotificationTopic.uv),
      containsAll({
        LifestyleMessageType.strongSunExposure,
        LifestyleMessageType.sunscreenUseful,
      }),
    );
    expect(
      lifestyleTypesForNotificationTopic(NotificationTopic.commute),
      contains(LifestyleMessageType.commuteRouteCaution),
    );
    expect(
      lifestyleTypesForNotificationTopic(NotificationTopic.overview),
      isEmpty,
    );
  });
}

String _isoDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
