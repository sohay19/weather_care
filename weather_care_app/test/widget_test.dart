import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/app.dart';
import 'package:weather_care/features/home/widgets/recommendation_bag_section.dart';
import 'package:weather_care/features/home/widgets/timeline_section.dart';
import 'package:weather_care/features/home/widgets/weather_card.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/recommendation.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/theme/recommendation_theme.dart';
import 'package:weather_care/theme/weather_theme.dart';

void main() {
  test('recommendation categories share one color palette', () {
    expect(
      RecommendationType.values.map((type) => type.accentColor).toSet(),
      {WeatherCareTheme.primaryDeep},
    );
    expect(
      RecommendationType.values.map((type) => type.softColor).toSet(),
      {WeatherCareTheme.primarySoft},
    );
  });

  test('theme maps the four font roles', () {
    final theme = WeatherCareTheme.light();

    expect(theme.textTheme.bodyMedium?.fontFamily, WeatherCareTheme.fontSuite);
    expect(
      theme.textTheme.bodySmall?.fontFamily,
      WeatherCareTheme.fontChosunCentennial,
    );
    expect(
      theme.textTheme.headlineSmall?.fontFamily,
      WeatherCareTheme.fontNeoHyundai,
    );
    expect(
      WeatherCareTheme.specialLabelStyle.fontFamily,
      WeatherCareTheme.fontMona,
    );
  });

  testWidgets('WeatherCareApp starts', (tester) async {
    await tester.pumpWidget(const WeatherCareApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .debugShowCheckedModeBanner,
      isFalse,
    );
  });

  testWidgets('temperature values include the Celsius unit', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeatherInfoCard(
            current: CurrentWeather(
              temperature: 29,
              apparentTemperature: 32.7,
            ),
          ),
        ),
      ),
    );

    expect(find.text('29.0°C'), findsOneWidget);
    expect(find.text('32.7°C'), findsOneWidget);
  });

  testWidgets('five tabs start on a non-scrollable Main screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WeatherCareApp());
    await tester.pump();

    final navigation = tester.widget<NavigationBar>(
      find.byKey(const ValueKey('main-bottom-navigation')),
    );
    expect(navigation.selectedIndex, 2);
    expect(
      navigation.destinations
          .whereType<NavigationDestination>()
          .map((destination) => destination.label),
      ['Today', 'Detail', 'Main', 'Week', 'Setting'],
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('main-tab')),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Today'));
    await tester.pump();
    expect(
      tester
          .widget<NavigationBar>(
            find.byKey(const ValueKey('main-bottom-navigation')),
          )
          .selectedIndex,
      0,
    );
    expect(find.byKey(const ValueKey('today-tab')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recommendation chip supports selection and details',
      (tester) async {
    RecommendationType? openedDetail;
    final recommendation = WeatherRecommendation(
      type: RecommendationType.umbrella,
      recommended: true,
      priority: 90,
      title: '우산이 필요해요',
      description: '오후에 비가 와요.',
      notificationEligible: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecommendationBagSection(
            regionName: '수원',
            recommendations: [recommendation],
            onDetail: (type) => openedDetail = type,
          ),
        ),
      ),
    );

    final bagItem = find.byKey(const ValueKey('bag-item-umbrella'));
    expect(bagItem, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(bagItem);
    await tester.pump();
    expect(find.text('챙겼어요'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bag-detail-umbrella')));
    await tester.pump();
    expect(openedDetail, RecommendationType.umbrella);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline keeps labels readable on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recommendations = [
      RecommendationType.sunscreen,
      RecommendationType.parasol,
      RecommendationType.water,
    ]
        .map(
          (type) => WeatherRecommendation(
            type: type,
            recommended: true,
            priority: 70,
            title: type.title,
            description: '추천 설명',
            notificationEligible: true,
          ),
        )
        .toList();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TimelineSection(
              items: [
                TimelineItem(
                  timeLabel: '12',
                  stateLabel: '점심 무렵',
                  detail: '햇볕이 강하고 체감온도가 높아요.',
                  recommendations: recommendations,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('점심 무렵')).height, lessThan(40));
  });

  testWidgets('settings shows the KMA API notice at the bottom',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('날씨 정보는 기상청 공식 API를 사용합니다.'), findsOneWidget);
  });
}
