import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/app.dart';
import 'package:weather_care/features/home/tabs/main_tab.dart';
import 'package:weather_care/features/home/widgets/tab_page_header.dart';
import 'package:weather_care/features/home/widgets/recommendation_bag_section.dart';
import 'package:weather_care/features/home/widgets/server_connection_failure_dialog.dart';
import 'package:weather_care/features/home/widgets/timeline_section.dart';
import 'package:weather_care/features/home/widgets/weather_card.dart';
import 'package:weather_care/features/home/widgets/weather_condition_icon.dart';
import 'package:weather_care/features/settings/settings_screen.dart';
import 'package:weather_care/models/lifestyle_message.dart';
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
      WeatherCareTheme.fontChosunSg,
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

  test('lifestyle messages parse the server importance score', () {
    final message = LifestyleMessage.fromJson({
      'type': 'RAIN_GEAR_USEFUL',
      'title': '작은 우산을 챙겨요',
      'score': 87,
    });

    expect(message.type, LifestyleMessageType.rainGearUseful);
    expect(message.score, 87);
  });

  test('시간별 예보는 자외선과 미세먼지 값을 보존한다', () {
    final item = HourlyWeatherItem.fromJson({
      'time': '12',
      'temperature': 31,
      'precipitationProbability': 20,
      'precipitationAmount': 0,
      'snowExpected': false,
      'snowfallAmount': 0,
      'windSpeed': 2,
      'skyCondition': '구름 많음',
      'uvIndex': 7,
      'pm10': 52,
      'pm25': 31,
    });

    expect(item.uvIndex, 7);
    expect(item.pm10, 52);
    expect(item.pm25, 31);
  });

  test('주간 예보는 대표 준비물을 최대 3개까지 보존한다', () {
    final recommendations = [
      'UMBRELLA',
      'OUTERWEAR',
      'MASK',
      'WATER',
    ]
        .map(
          (type) => {
            'type': type,
            'recommended': true,
            'priority': 70,
            'title': type,
            'description': '설명',
            'notificationEligible': true,
          },
        )
        .toList();
    final weekly = WeeklyWeatherResponse.fromJson({
      'days': [
        {
          'date': '금',
          'weatherLabel': '비',
          'min': '22',
          'max': '28',
          'recommendations': recommendations,
        },
      ],
    });

    expect(weekly.days.single.recommendations, hasLength(3));
  });

  test('체감 문구는 한국인 PT 구간과 기상청 위험값을 함께 사용한다', () {
    expect(apparentTemperatureLabel(20), '조금 더움');
    expect(apparentTemperatureLabel(31.4), '더움');
    expect(apparentTemperatureLabel(33), '더위 주의');
    expect(apparentTemperatureLabel(35), '더위 경계');
    expect(apparentTemperatureLabel(38), '위험한 더위');
  });

  test('날씨 상태는 비·구름 많음·흐림을 서로 다른 아이콘으로 구분한다', () {
    expect(weatherConditionKind('비'), WeatherConditionKind.rain);
    expect(
      weatherConditionKind('구름 많음'),
      WeatherConditionKind.partlyCloudy,
    );
    expect(weatherConditionKind('흐림'), WeatherConditionKind.overcast);
    expect(
      weatherConditionKind('구름 많음'),
      isNot(weatherConditionKind('흐림')),
    );
  });

  test('서버의 서로 다른 날씨 상태는 각각 고유한 아이콘 종류로 해석한다', () {
    const serverConditions = [
      '맑음',
      '구름 많음',
      '흐림',
      '비',
      '비/눈',
      '눈',
      '소나기',
      '빗방울',
      '빗방울/눈날림',
      '눈날림',
    ];

    final kinds = serverConditions.map(weatherConditionKind).toSet();

    expect(kinds, hasLength(serverConditions.length));
    expect(weatherConditionKind('이슬비'), WeatherConditionKind.drizzle);
    expect(weatherConditionKind('가랑비'), WeatherConditionKind.drizzle);
  });

  testWidgets('비 날씨 아이콘은 우산 대신 구름과 빗방울을 사용한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WeatherConditionIcon(condition: '비'),
      ),
    );

    expect(
      find.byKey(const ValueKey('weather-condition-rain')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.cloud_rounded), findsOneWidget);
    expect(find.byIcon(Icons.water_drop_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.umbrella_outlined), findsNothing);
  });

  testWidgets('조합 날씨 아이콘은 큰 부모 안에서도 지정 크기의 한 위젯을 유지한다', (tester) async {
    const conditions = [
      '구름 많음',
      '흐림',
      '빗방울',
      '비',
      '소나기',
      '빗방울/눈날림',
      '비/눈',
      '눈날림',
      '눈',
    ];

    for (final condition in conditions) {
      final kind = weatherConditionKind(condition);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 42,
              child: WeatherConditionIcon(
                condition: condition,
                size: 21,
              ),
            ),
          ),
        ),
      );

      final glyph = find.byKey(ValueKey('weather-condition-${kind.name}'));
      final glyphRect = tester.getRect(glyph);
      final icons = find.descendant(of: glyph, matching: find.byType(Icon));

      expect(tester.getSize(glyph), const Size.square(21));
      expect(icons, findsWidgets);
      for (var index = 0; index < icons.evaluate().length; index++) {
        final iconRect = tester.getRect(icons.at(index));
        expect(
          glyphRect.inflate(1).contains(iconRect.topLeft),
          isTrue,
          reason: '$condition 아이콘 $index의 시작점이 조합 위젯 밖에 있어요: $iconRect',
        );
        expect(
          glyphRect.inflate(1).contains(iconRect.bottomRight),
          isTrue,
          reason: '$condition 아이콘 $index의 끝점이 조합 위젯 밖에 있어요: $iconRect',
        );
      }
    }
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
              humidity: 72,
              uvIndex: 7,
              pm25: 41,
              sky: '구름 많음',
            ),
          ),
        ),
      ),
    );

    expect(find.text('29.0°C'), findsOneWidget);
    expect(find.text('32.7°C'), findsOneWidget);
    expect(find.text('미세먼지'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('weather-metric-체감')),
    );
    await tester.pumpAndSettle();
    expect(find.text('체감온도 기준'), findsOneWidget);
    expect(find.textContaining('33°C부터 더위 주의'), findsOneWidget);
  });

  testWidgets('five tabs start on a pull-to-refresh Main screen',
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
      findsOneWidget,
    );
    for (final destination
        in navigation.destinations.whereType<NavigationDestination>()) {
      expect(
        (destination.icon as Icon).color,
        WeatherCareTheme.textSecondary,
      );
      expect(
        (destination.selectedIcon! as Icon).color,
        WeatherCareTheme.textSecondary,
      );
    }
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

  testWidgets('Main uses the compact weather and three-row TODO layout',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var refreshCount = 0;
    const brief = '햇살이 잠시 쉬어가는 차분한 하루가 될 것 같아요.';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MainTab(
            today: const TodayWeatherResponse(
              dataSource: 'test',
              region: WeatherRegion(nx: 60, ny: 121, name: '수원'),
              brief: brief,
              current: CurrentWeather(
                temperature: 22.4,
                apparentTemperature: 21.8,
                humidity: 60,
                windSpeed: 2.1,
                pm25: 76,
                sky: '구름 많음',
              ),
              recommendations: [],
              lifestyleMessages: [],
              timeline: [],
              hourly: [],
            ),
            dateLabel: '8월 21일 금요일',
            mood: 'cloudy',
            serverFeaturesAvailable: true,
            onRefresh: () async => refreshCount++,
          ),
        ),
      ),
    );

    expect(find.text('수원이라면 확인하세요'), findsOneWidget);
    expect(find.text('Check List'), findsOneWidget);
    expect(find.text('오늘 날씨에 체크해야할 일들이에요'), findsOneWidget);
    expect(find.text('시간대별 흐름 확인하기'), findsOneWidget);
    expect(find.text('물 한 모금 챙기기'), findsOneWidget);
    expect(find.text('여유 있게 움직이기'), findsOneWidget);
    expect(find.text('초미세먼지'), findsOneWidget);
    expect(find.text('76㎍'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('76㎍')).style?.color,
      WeatherCareTheme.danger,
    );
    expect(find.byTooltip('날씨 새로고침'), findsNothing);
    expect(tester.widget<Text>(find.text(brief)).maxLines, 3);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const ValueKey('main-tab')),
      const Offset(0, 320),
    );
    await tester.pumpAndSettle();

    expect(refreshCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carry TODO backgrounds reflect the server score',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MainTab(
            today: TodayWeatherResponse(
              dataSource: 'test',
              region: const WeatherRegion(nx: 60, ny: 121, name: '수원'),
              brief: '가방 속 준비물이 발걸음을 가볍게 해줄 거예요.',
              current: const CurrentWeather(temperature: 22),
              recommendations: const [],
              lifestyleMessages: [
                LifestyleMessage(
                  type: LifestyleMessageType.rainGearUseful,
                  title: '작은 우산을 챙겨요',
                  score: 90,
                ),
                LifestyleMessage(
                  type: LifestyleMessageType.outerwearUseful,
                  title: '가벼운 겉옷을 챙겨요',
                  score: 70,
                ),
                LifestyleMessage(
                  type: LifestyleMessageType.laundryGood,
                  title: '빨래를 널어보세요',
                  score: 95,
                ),
              ],
              timeline: const [],
              hourly: const [],
            ),
            dateLabel: '8월 21일 금요일',
            mood: 'cloudy',
            serverFeaturesAvailable: true,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    BoxDecoration decorationFor(String title) {
      final card = tester.widget<Container>(
        find.byKey(ValueKey('main-todo-$title')),
      );
      return card.decoration! as BoxDecoration;
    }

    expect(
      decorationFor('작은 우산을 챙겨요').color,
      WeatherCareTheme.attentionSoft,
    );
    expect(
      decorationFor('가벼운 겉옷을 챙겨요').color,
      WeatherCareTheme.primarySoft,
    );
    expect(
      decorationFor('빨래를 널어보세요').color,
      WeatherCareTheme.surfaceMuted,
    );
    expect(decorationFor('작은 우산을 챙겨요').border, isNull);
    expect(decorationFor('가벼운 겉옷을 챙겨요').border, isNull);
    expect(decorationFor('빨래를 널어보세요').border, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('server failure dialog recommends retry before direct forecast',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ServerConnectionFailureDialog()),
    );

    expect(find.text('운영 서버에 연결하지 못했어요'), findsOneWidget);
    expect(find.textContaining('운영 서버 연결을 먼저 다시 시도'), findsOneWidget);
    expect(find.text('단기예보만 보기'), findsOneWidget);
    expect(find.text('운영 서버 다시 시도'), findsOneWidget);
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

  testWidgets('settings disables notification time and shows all data sources',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('notification-time-control')),
          )
          .opacity,
      0.46,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    expect(find.text('폭우 주의'), findsOneWidget);
    expect(find.text('폭염 주의'), findsOneWidget);
    expect(find.text('한파 주의'), findsOneWidget);
    expect(find.text('소나기·약한 비 주의'), findsOneWidget);
    expect(
      find.text('날씨·자외선은 기상청, 미세먼지는 에어코리아 공식 API를 사용합니다.'),
      findsOneWidget,
    );
  });

  testWidgets('embedded Setting uses the common tab page header',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SettingsScreen(embedded: true)),
      ),
    );

    expect(find.byType(TabPageHeader), findsOneWidget);
    expect(find.text('SETTING'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);
    expect(
      find.text('내 위치와 필요한 알림만 편안하게 맞춰보세요.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
