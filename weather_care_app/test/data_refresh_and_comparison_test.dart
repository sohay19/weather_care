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
    expect(find.textContaining('받지 못한 날씨 자료:'), findsOneWidget);
    expect(find.text(removedHint), findsNothing);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('yesterday-comparison-card')),
      find.byKey(const ValueKey('main-tab')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
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

  testWidgets('Main 카드를 날씨, Check List, 어제 비교, 예상 순서로 표시한다', (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const completeToday = TodayWeatherResponse(
      dataSource: 'test',
      region: WeatherRegion(nx: 60, ny: 121, name: '수원'),
      brief: '맑고 포근해요',
      current: CurrentWeather(
        temperature: 22,
        forecastAt: '2026-09-16T10:00:00+09:00',
        apparentTemperature: 21.5,
        humidity: 55,
        windSpeed: 2,
        uvIndex: 4,
        pm10: 30,
        pm25: 15,
        sky: '맑음',
      ),
      nextForecast: CurrentWeather(
        temperature: 23,
        forecastAt: '2026-09-16T11:00:00+09:00',
        apparentTemperature: 22.5,
        humidity: 64,
        windSpeed: 3.2,
        uvIndex: 5,
        pm25ForecastGrade: '보통',
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
              temperature: 22.25,
              apparentTemperature: 22.14,
              pm10: 30,
              pm25: 15,
              skyCondition: '맑음',
            ),
            comparison: ComparisonWeatherSnapshot(
              temperature: 20,
              apparentTemperature: 19.5,
              pm10: 34,
              pm25: 18,
              skyCondition: '구름 많음',
            ),
            basis: ComparisonBasis(
              provider: 'KMA_FORECAST_VS_ULTRA_SHORT_OBSERVATION',
              gridX: 57,
              gridY: 124,
              currentForecastAt: '2026-09-16T10:00:00+09:00',
              comparisonObservedAt: '2026-09-15T10:00:00+09:00',
            ),
          ),
          onRefresh: () async {},
          onDetail: (_) {},
        ),
      ),
    ));

    expect(
      find.text('하늘·기온·습도·바람은 오전 10시 단기예보 기준'),
      findsNothing,
    );
    expect(find.text('현재 기온'), findsOneWidget);
    expect(find.text('예상 기온'), findsOneWidget);
    expect(find.text('22.0℃'), findsOneWidget);
    expect(find.text('현재 체감온도'), findsOneWidget);
    expect(find.text('예상 체감온도'), findsOneWidget);
    expect(find.text('21.5℃'), findsOneWidget);
    expect(find.text('오전 11시의 기온과 체감온도를 예상해요'), findsOneWidget);
    expect(find.text('23.0℃'), findsOneWidget);
    expect(find.text('22.5℃'), findsOneWidget);
    final futureCard = find.byKey(const ValueKey('main-future-weather-card'));
    expect(
      find.descendant(of: futureCard, matching: find.text('64%')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: futureCard, matching: find.text('3.2m/s')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: futureCard, matching: find.text('5')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: futureCard, matching: find.text('보통')),
      findsOneWidget,
    );
    expect(
      find.text(
        '맑은 하늘이 이어지는 날씨예요. 실제 기온보다 0.5℃ 낮지만, 체감 상 조금 덥게 느껴질 수 있어요.',
      ),
      findsOneWidget,
    );
    final currentWeatherRow = tester.getRect(
      find.byKey(const ValueKey('main-current-forecast-row')),
    );
    final forecastWeatherRow = tester.getRect(
      find.byKey(const ValueKey('main-apparent-temperature-row')),
    );
    expect(forecastWeatherRow.top, greaterThan(currentWeatherRow.bottom));
    expect(find.text('어제와 비교'), findsOneWidget);
    expect(
      find.text('오전 10시 기준, 다음 시간 기온 예보를 어제 실황과 비교해요'),
      findsOneWidget,
    );
    expect(
      find.text('선택 격자 57/124'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('yesterday-comparison-basis')),
      findsNothing,
    );
    expect(
      find.text('기온은 어제보다 2.3℃ 높아요.'),
      findsOneWidget,
    );
    final topCard = find.byKey(const ValueKey('main-top-weather-card'));
    expect(
      find.descendant(of: topCard, matching: find.text('22.3℃')),
      findsNothing,
    );
    final comparisonCard =
        find.byKey(const ValueKey('yesterday-comparison-card'));
    final top = tester.getTopLeft(topCard);
    final comparison = tester.getTopLeft(comparisonCard);
    final checklist = tester.getTopLeft(find.text('Check List'));
    final future = tester.getTopLeft(futureCard);
    final topDecoration =
        tester.widget<AnimatedContainer>(topCard).decoration as BoxDecoration;
    final futureDecoration =
        tester.widget<Container>(futureCard).decoration as BoxDecoration;
    expect(
      (futureDecoration.gradient as LinearGradient).colors,
      (topDecoration.gradient as LinearGradient).colors,
    );
    expect(
      find.ancestor(of: comparisonCard, matching: topCard),
      findsNothing,
    );
    expect(
      find.ancestor(of: futureCard, matching: topCard),
      findsNothing,
    );
    expect(checklist.dy, greaterThan(top.dy));
    expect(comparison.dy, greaterThan(checklist.dy));
    expect(future.dy, greaterThan(comparison.dy));
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
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('yesterday-comparison-card')),
      find.byKey(const ValueKey('main-tab')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('yesterday-comparison-retry')),
    );
    await tester.pump();
    expect(todayRetries, 1);
    expect(comparisonRetries, 1);
  });
}
