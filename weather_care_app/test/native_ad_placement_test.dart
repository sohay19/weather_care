import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/features/home/tabs/extra_tab.dart';
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

  testWidgets('Today 광고는 현재 날씨 카드 아래에 표시한다', (tester) async {
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

    final weather = tester.getBottomLeft(find.byType(WeatherInfoCard)).dy;
    final advertisement = tester
        .getTopLeft(find.byKey(const ValueKey('test-today-advertisement')))
        .dy;
    expect(advertisement, greaterThan(weather));
    expect(find.text('타임라인'), findsNothing);
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

    final future = tester
        .getTopLeft(find.byKey(const ValueKey('main-hourly-timeline-section')))
        .dy;
    final advertisement = tester
        .getTopLeft(find.byKey(const ValueKey('test-main-advertisement')))
        .dy;
    expect(advertisement, greaterThan(future));
  });

  testWidgets('심화날씨 광고는 바다·하천 콘텐츠 아래 맨 마지막에 표시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ExtraTab(
          client: null,
          grid: null,
          active: true,
          advertisement: SizedBox(
            key: ValueKey('test-extra-advertisement'),
            height: 50,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final advertisement =
        find.byKey(const ValueKey('test-extra-advertisement'));
    await tester.ensureVisible(advertisement);
    expect(find.text('심화 날씨 정보'), findsOneWidget);
    expect(find.text('ADVANCED'), findsOneWidget);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect((list.childrenDelegate as SliverChildListDelegate).children.last.key,
        const ValueKey('test-extra-advertisement'));
    expect(
        tester.getTopLeft(advertisement).dy,
        greaterThan(tester
            .getBottomLeft(find.byKey(const ValueKey('extra-water-box')))
            .dy));
    expect(tester.takeException(), isNull);
  });
}
