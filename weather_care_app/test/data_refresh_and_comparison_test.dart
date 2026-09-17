import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/detail_tab.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/features/home/tabs/today_tab.dart';
import 'package:weather_care/features/home/tabs/week_tab.dart';
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

  testWidgets('일부 자료가 없으면 별도 공통 안내 없이 해당 카드 안에 항목을 표시한다', (tester) async {
    const removedHint = '옆의 새로고침 아이콘을 누르거나 화면을 아래로 당기면 데이터를 다시 요청할 수 있어요.';

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TodayTab(
          today: incompleteToday,
          onRefresh: () async {},
          onRetryData: () async {},
        ),
      ),
    ));
    expect(find.textContaining('받지 못한 현재 날씨:'), findsOneWidget);
    expect(find.text('받지 못한 시간별 예보 항목이 있어요.'), findsOneWidget);
    expect(find.text(removedHint), findsNothing);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MainTab(
          today: incompleteToday,
          dateLabel: '9월 16일',
          mood: 'clear',
          serverFeaturesAvailable: true,
          yesterdayComparison: const ComparisonResponse.unavailable(),
          onRefresh: () async {},
          onRetryData: () async {},
          onRetryComparison: () async {},
          onDetail: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('받지 못한 현재 날씨:'), findsOneWidget);
    expect(find.text('받지 못한 자료: 어제와 같은 시각의 관측값'), findsOneWidget);
    expect(find.text(removedHint), findsNothing);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DetailTab(
          today: incompleteToday,
          recommendations: const [],
          serverFeaturesAvailable: false,
          onRefresh: () async {},
          onRetryData: () async {},
        ),
      ),
    ));
    expect(find.text('근거와 자료 자료를 받지 못했어요.'), findsOneWidget);
    expect(find.text(removedHint), findsNothing);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WeekTab(
          weekly: const WeeklyWeatherResponse(days: []),
          serverFeaturesAvailable: true,
          onRefresh: () async {},
          onRetryData: () async {},
          now: () => DateTime(2026, 9, 16, 12),
        ),
      ),
    ));
    expect(find.text('받지 못한 항목: 이 날짜의 날씨'), findsWidgets);
    expect(find.text(removedHint), findsNothing);
  });

  testWidgets('Main 최상단 날씨와 어제 비교 결과를 하나의 카드에 표시한다', (tester) async {
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
            current: ComparisonWeatherSnapshot(
              temperature: 22,
              apparentTemperature: 21,
              pm10: 30,
              pm25: 15,
              skyCondition: '맑음',
            ),
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
    final topCard = find.byKey(const ValueKey('main-top-weather-card'));
    final comparisonCard =
        find.byKey(const ValueKey('yesterday-comparison-card'));
    final top = tester.getTopLeft(topCard);
    final comparison = tester.getTopLeft(comparisonCard);
    final checklist = tester.getTopLeft(find.text('Check List'));
    expect(
      find.ancestor(of: comparisonCard, matching: topCard),
      findsOneWidget,
    );
    expect(comparison.dy, greaterThan(top.dy));
    expect(comparison.dy, lessThan(checklist.dy));
  });

  testWidgets('카드의 새로고침 버튼은 해당 자료 콜백만 실행한다', (tester) async {
    var todayRetries = 0;
    var comparisonRetries = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TodayTab(
          today: incompleteToday,
          onRefresh: () async {},
          onRetryData: () async => todayRetries += 1,
        ),
      ),
    ));
    final todayRetry = find.byKey(const ValueKey('today-current-data-retry'));
    await tester.ensureVisible(todayRetry);
    await tester.tap(todayRetry);
    await tester.pump();
    expect(todayRetries, 1);
    expect(comparisonRetries, 0);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MainTab(
          today: incompleteToday,
          dateLabel: '9월 16일',
          mood: 'clear',
          serverFeaturesAvailable: true,
          yesterdayComparison: const ComparisonResponse.unavailable(),
          onRefresh: () async {},
          onRetryData: () async => todayRetries += 1,
          onRetryComparison: () async => comparisonRetries += 1,
          onDetail: (_) {},
        ),
      ),
    ));
    await tester.tap(
      find.byKey(const ValueKey('yesterday-comparison-retry')),
    );
    await tester.pump();
    expect(todayRetries, 1);
    expect(comparisonRetries, 1);
  });
}
