import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/features/home/tabs/today_tab.dart';
import 'package:weather_care/features/home/tabs/week_tab.dart';
import 'package:weather_care/features/home/widgets/hourly_value_chart.dart';
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
    expect(find.text('받지 못한 타임라인 항목이 있어요.'), findsNothing);
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
    await tester.dragUntilVisible(
      find.text('받지 못한 타임라인 항목이 있어요.'),
      find.byKey(const ValueKey('main-tab')),
      const Offset(0, -300),
    );
    expect(find.text('받지 못한 타임라인 항목이 있어요.'), findsOneWidget);
    expect(find.text(removedHint), findsNothing);
    await tester.dragUntilVisible(
      find.text('어제와 비교'),
      find.byKey(const ValueKey('main-tab')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('받지 못한 자료: 어제와 같은 시각의 관측값'), findsOneWidget);
    expect(find.text(removedHint), findsNothing);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TodayTab(
          today: incompleteToday,
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

  testWidgets('Main은 Today 선택형 타임라인을 표시한다', (tester) async {
    const today = TodayWeatherResponse(
      dataSource: 'test',
      generatedAt: '2026-10-01T00:00:00Z',
      region: WeatherRegion(nx: 57, ny: 124, name: '시흥시'),
      brief: '맑아요',
      current: CurrentWeather(temperature: 19),
      recommendations: [],
      lifestyleMessages: [],
      timeline: [],
      hourly: [
        HourlyWeatherItem(
          time: '10',
          temperature: 19,
          apparentTemperature: 14.4,
          precipitationProbability: 40,
          precipitationAmount: 1,
          snowExpected: false,
          snowfallAmount: 0,
          windSpeed: 2,
          skyCondition: '맑음',
        ),
        HourlyWeatherItem(
          time: '11',
          temperature: 20,
          apparentTemperature: 18,
          precipitationProbability: 60,
          precipitationAmount: 2,
          snowExpected: false,
          snowfallAmount: 0,
          windSpeed: 2,
          skyCondition: '비',
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(
        body: MainTab(
          today: today,
          dateLabel: '10월 1일',
          mood: 'clear',
          serverFeaturesAvailable: true,
          yesterdayComparison: const ComparisonResponse.unavailable(),
          onRefresh: () async {},
          onDetail: (_) {},
        ),
      ),
    ));

    final card = find.byKey(const ValueKey('main-hourly-timeline-section'));
    await tester.dragUntilVisible(
      card,
      find.byKey(const ValueKey('main-tab')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey('main-hourly-10'));
    final second = find.byKey(const ValueKey('main-hourly-11'));
    final weatherChart = tester.widget<HourlyValueChart>(
        find.descendant(of: card, matching: find.byType(HourlyValueChart)));
    final ten = weatherChart.hours.indexOf(10);
    expect(weatherChart.conditions[ten], '맑음');
    expect(weatherChart.series.values[ten]?.lower, 19);
    expect(weatherChart.overlays.single.values[ten]?.lower, 14.4);
    expect(tester.getRect(first).right, tester.getRect(second).left);
    expect(tester.getSize(first).width, 80);
    expect(
        find.byKey(const ValueKey('main-hourly-weather-band')), findsNothing);
    for (final metric in [
      'weather',
      'precipitation',
      'uv',
      'wind',
      'humidity'
    ]) {
      expect(
          find.byKey(ValueKey('main-hourly-filter-$metric')), findsOneWidget);
    }
    tester
        .widget<ChoiceChip>(
            find.byKey(const ValueKey('main-hourly-filter-precipitation')))
        .onSelected!(true);
    await tester.pumpAndSettle();
    final rainChart = tester.widget<HourlyValueChart>(
        find.descendant(of: card, matching: find.byType(HourlyValueChart)));
    expect(rainChart.series.id, 'rain-amount');
    expect(rainChart.series.values[rainChart.hours.indexOf(10)]?.lower, 1);
    expect(rainChart.overlays.single.id, 'rain-probability');
    expect(rainChart.overlays.single.values[rainChart.hours.indexOf(10)]?.lower,
        40);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Main은 Check List 다음 날씨 카드 안에 어제 비교를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(320, 1800);
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
      generatedAt: '2026-09-16T00:00:00Z',
      hourly: [
        HourlyWeatherItem(
          time: '11',
          temperature: 23,
          apparentTemperature: 22.5,
          precipitationProbability: 40,
          precipitationAmount: 1,
          snowExpected: false,
          snowfallAmount: 0,
          windSpeed: 3.2,
          skyCondition: '맑음',
        )
      ],
      recommendations: [],
      lifestyleMessages: [],
      timeline: [],
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
    expect(find.text('예상 기온'), findsNothing);
    expect(find.text('22.0℃'), findsOneWidget);
    expect(find.text('현재 체감온도'), findsOneWidget);
    expect(find.text('예상 체감온도'), findsNothing);
    expect(find.text('21.5℃'), findsOneWidget);
    final futureCard =
        find.byKey(const ValueKey('main-hourly-timeline-section'));
    expect(find.descendant(of: futureCard, matching: find.text('11시')),
        findsOneWidget);
    expect(find.descendant(of: futureCard, matching: find.text('23°C')),
        findsOneWidget);
    final chart = tester.widget<HourlyValueChart>(find.descendant(
        of: futureCard, matching: find.byType(HourlyValueChart)));
    expect(chart.overlays.single.values[chart.hours.indexOf(11)]?.lower, 22.5);
    expect(
      find.text('맑은 하늘이 이어지는 날씨예요.'),
      findsOneWidget,
    );
    final currentWeatherRow = tester.getRect(
      find.byKey(const ValueKey('main-current-forecast-row')),
    );
    expect(
      tester
          .getBottomLeft(find.byKey(const ValueKey('main-weather-feeling')))
          .dy,
      lessThan(currentWeatherRow.top),
    );
    final forecastWeatherRow = tester.getRect(futureCard);
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
    expect(find.text('어제 20.0℃'), findsOneWidget);
    expect(find.text('어제 19.5℃'), findsOneWidget);
    final temperatureRow =
        find.byKey(const ValueKey('yesterday-comparison-row-기온은'));
    expect(tester.getRect(find.text('어제 20.0℃')).right,
        closeTo(tester.getRect(temperatureRow).right, 1));
    expect(find.textContaining('오늘 예보 22.3℃ · 어제 실황'), findsNothing);
    final topCard = find.byKey(const ValueKey('main-top-weather-card'));
    expect(
      find.descendant(of: topCard, matching: find.text('22.3℃')),
      findsNothing,
    );
    final comparisonCard = find.text('어제와 비교');
    final top = tester.getTopLeft(topCard);
    final comparison = tester.getTopLeft(comparisonCard);
    final checklist = tester.getTopLeft(find.text('Check List'));
    final future = tester.getTopLeft(futureCard);
    expect(
      find.ancestor(of: comparisonCard, matching: topCard),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: futureCard, matching: topCard),
      findsNothing,
    );
    expect(checklist.dy, lessThan(top.dy));
    expect(comparison.dy, greaterThan(top.dy));
    expect(future.dy, greaterThan(comparison.dy));

    for (final text in [
      '오전 10시 기준, 다음 시간 기온 예보를 어제 실황과 비교해요',
      '하늘 상태는 오늘 맑음, 어제 구름 많음이었어요.',
      '기온은 어제보다 2.3℃ 높아요.',
      '어제 20.0℃',
    ]) {
      final widget = tester.widget<Text>(find.text(text));
      expect(widget.maxLines, 1);
      expect(widget.softWrap, isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('카드의 새로고침 버튼은 해당 자료 콜백만 실행한다', (tester) async {
    var todayRetries = 0;
    var comparisonRetries = 0;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
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
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
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
      find.text('어제와 비교'),
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
