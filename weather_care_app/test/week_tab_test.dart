import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/week_tab.dart';
import 'package:weather_care/features/home/widgets/week_presentation.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/theme/weather_theme.dart';
import 'package:weather_care/utils/korea_date.dart';

void main() {
  testWidgets('Week에는 현재 관측 가시거리를 표시하지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekTab(
            weekly: const WeeklyWeatherResponse(days: []),
            serverFeaturesAvailable: true,
            onRefresh: () async {},
            now: () => DateTime.utc(2026, 9, 21),
          ),
        ),
      ),
    );

    expect(find.textContaining('가시거리'), findsNothing);
    expect(
        find.byKey(const ValueKey('visibility-forecast-limit')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('API의 달력 날짜와 기존 요일을 독립적으로 보존한다', () {
    final weekly = WeeklyWeatherResponse.fromJson({
      'days': [
        {'date': '목', 'forecastDate': '2026-09-10'},
        {'date': '금'},
      ],
    });
    expect(weekly.days.first.date, '목');
    expect(weekly.days.first.forecastDate, '2026-09-10');
    expect(weekly.days.last.forecastDate, isNull);
  });

  testWidgets('기기 날짜가 하루 느려도 주간 응답의 오늘을 선택한다', (tester) async {
    final receivedAt = DateTime.parse('2026-10-01T10:00:00Z');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WeekTab(
          weekly: WeeklyWeatherResponse(
            days: [_day('2026-10-01'), _day('2026-10-02')],
            generatedAt: '2026-10-02T02:00:00Z',
            receivedAt: receivedAt,
          ),
          serverFeaturesAvailable: true,
          onRefresh: () async {},
          now: () => receivedAt,
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('week-today-2026-10-02')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-past-2026-10-01')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('잘못된 날짜·요일·시각을 날짜로 추정하거나 보정하지 않는다', () {
    for (final value in [
      null,
      '',
      '금',
      '2026-02-30',
      '2026-13-01',
      '2026-09-10T00:00:00Z',
      '20260910'
    ]) {
      expect(parseForecastDate(value), isNull, reason: '$value');
      expect(weekDayLabel(_day(value)), '날짜 확인 어려움');
    }
    expect(weekDayLabel(_day('2028-02-29')), '2월 29일 (화)');
  });

  test('실제 날짜 범위와 제공 일수만 표시한다', () {
    expect(weekPeriodLabel([_day('2026-09-10'), _day('2026-09-11')]),
        '9월 10일~9월 11일 · 2일 예보');
    expect(weekPeriodLabel([_day('2026-09-11')]), '9월 11일 · 1일 예보');
    expect(weekPeriodLabel([_day('2026-12-31'), _day('2027-01-01')]),
        '2026년 12월 31일~2027년 1월 1일 · 2일 예보');
  });

  test('중간 결측·중복·순서 뒤바뀜·날짜 누락을 임의의 연속 예보로 만들지 않는다', () {
    expect(
        weekPeriodLabel([
          _day('2026-10-02'),
          _day('2026-09-30'),
          _day('2026-09-30'),
          _day(null),
        ]),
        '9월 30일~10월 2일 · 기간 내 2일 자료 · 날짜 미확인 1개');
    expect(weekPeriodLabel([_day(null)]), '날짜 정보가 없어 예보 기간을 확인하기 어려워요');
  });

  test('현재 한국 날짜가 포함된 주를 일요일부터 토요일까지 고정한다', () {
    final days = currentCalendarWeek(
      [
        _day('2026-09-10'),
        _day('2026-09-12'),
        _day('2026-09-13'),
      ],
      DateTime.parse('2026-09-10T01:00:00Z'),
    );

    expect(days.map((day) => calendarDayLabel(day.date)), [
      '9월 6일 (일)',
      '9월 7일 (월)',
      '9월 8일 (화)',
      '9월 9일 (수)',
      '9월 10일 (목)',
      '9월 11일 (금)',
      '9월 12일 (토)',
    ]);
    expect(days.map((day) => day.forecast != null), [
      false,
      false,
      false,
      false,
      true,
      false,
      true,
    ]);
    expect(calendarWeekPeriodLabel(days), '9월 6일~9월 12일 · 일~토');
  });

  testWidgets('첫 예보가 내일이어도 오늘을 포함한 일~토 자리를 유지한다', (tester) async {
    await _pump(tester, [_day('2026-09-11')]);
    expect(find.text('이번 주'), findsOneWidget);
    expect(find.text('9월 11일 (금)'), findsOneWidget);
    expect(find.byKey(const ValueKey('week-today-2026-09-10')), findsOneWidget);
    expect(find.textContaining('이번주'), findsNothing);
  });

  testWidgets('한국 날짜보다 지난 카드는 지난 날짜로 표시한다', (tester) async {
    await _pump(tester, [_day('2026-09-10'), _day('2026-09-11')],
        now: () => DateTime.parse('2026-09-10T15:00:00Z'));
    expect(find.byKey(const ValueKey('week-past-2026-09-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-past-2026-09-11')), findsNothing);
    expect(find.byKey(const ValueKey('week-today-2026-09-11')), findsOneWidget);
    for (final date in ['2026-09-10', '2026-09-11']) {
      final badge = find.byKey(ValueKey(
        date == '2026-09-11' ? 'week-today-$date' : 'week-past-$date',
      ));
      final card = find.byKey(ValueKey('week-day-$date'));
      expect(
        tester.getRect(badge).right,
        closeTo(tester.getRect(card).right - 17, 1.1),
      );
    }
  });

  testWidgets('날짜 없는 기존 서버 자료는 주간 슬롯에 임의로 끼워 넣지 않는다', (tester) async {
    await _pump(tester, [_day(null)]);
    expect(find.text('9월 6일 (일)'), findsOneWidget);
    expect(find.text('9월 12일 (토)'), findsOneWidget);
    expect(find.byKey(const ValueKey('week-today-2026-09-10')), findsOneWidget);
    expect(find.text('날짜 확인 어려움'), findsNothing);
  });

  testWidgets('빈 목록도 일~토 자리를 유지하고 정상 날씨를 만들지 않는다', (tester) async {
    await _pump(tester, []);
    expect(find.text('9월 6일~9월 12일 · 일~토'), findsOneWidget);
    expect(find.text('9월 6일 (일)'), findsOneWidget);
    expect(find.text('9월 12일 (토)'), findsOneWidget);
    expect(find.text('주간 날씨 요약'), findsNothing);
    expect(find.text('0일'), findsNothing);
    expect(find.text('준비물 없음'), findsNothing);
  });

  testWidgets('중기예보까지 실패한 미래 날짜를 구분해 안내한다', (tester) async {
    await _pump(
      tester,
      [],
      now: () => DateTime.parse('2026-09-15T03:00:00Z'),
    );

    expect(find.text('9월 19일 (토)'), findsOneWidget);
    expect(
      find.text('단기·중기예보를 모두 받지 못해 표시할 자료가 없어요.'),
      findsOneWidget,
    );
  });

  testWidgets('지난 예보와 중기예보의 출처를 카드에 표시한다', (tester) async {
    await _pump(
      tester,
      [
        _day('2026-09-08', historical: true),
        _day('2026-09-10', forecastSource: 'KMA_MID_TERM'),
      ],
    );
    expect(find.text('저장된 예보'), findsOneWidget);
    expect(find.text('중기예보'), findsOneWidget);
    expect(find.text('지난 날짜'), findsNWidgets(4));
  });

  testWidgets('지난 날의 실제 관측을 저장된 예보와 구분한다', (tester) async {
    final observation = WeeklyForecastItem.fromJson({
      'forecastDate': '2026-09-08',
      'weatherLabel': '강수 관측 없음',
      'forecastSource': 'KMA_OBSERVATION',
      'historical': true,
      'min': 18,
      'max': 25,
      'observationDistanceKm': 3.2,
      'recommendations': [],
      'precipitationDetail': {
        'kind': 'OBSERVATION',
        'hours': [],
        'observedAmount': 0,
      },
    });
    await _pump(tester, [observation]);

    expect(find.text('실제 관측'), findsOneWidget);
    expect(find.textContaining('예보격자 대표점에서 3.2km'), findsOneWidget);
    expect(find.text('강수 관측'), findsOneWidget);
    expect(find.text('지난 날은 준비물 추천 대상이 아니에요'), findsOneWidget);
    expect(find.byKey(const ValueKey('week-past-2026-09-08')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('week-past-2026-09-08')))
          .style
          ?.color,
      WeatherCareTheme.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('실제 관측')).style?.color,
      WeatherCareTheme.textPrimary,
    );
    expect(find.byType(ColorFiltered), findsNothing);
    final card = tester.widget<Container>(
      find.byKey(const ValueKey('week-day-2026-09-08')),
    );
    expect((card.decoration as BoxDecoration).color,
        WeatherCareTheme.surfaceMuted);
  });

  testWidgets('전달된 광고 영역은 주간 요약과 날짜 카드 사이에만 표시한다', (tester) async {
    await _pump(
      tester,
      [_day('2026-09-10')],
      advertisement: const SizedBox(
        key: ValueKey('test-week-advertisement'),
        height: 50,
      ),
    );

    final summary = tester.getTopLeft(find.text('주간 날씨 요약')).dy;
    final advertisement = tester
        .getTopLeft(find.byKey(const ValueKey('test-week-advertisement')))
        .dy;
    final day = tester.getTopLeft(find.text('9월 10일 (목)')).dy;
    expect(advertisement, greaterThan(summary));
    expect(advertisement, lessThan(day));
  });

  testWidgets('온도와 날짜별 추가 자료를 값이 있는 항목만 표시한다', (tester) async {
    final day = WeeklyForecastItem.fromJson({
      'forecastDate': '2026-09-10',
      'weatherLabel': '맑음',
      'min': 18,
      'max': 27,
      'averageHumidity': 63,
      'maximumWindSpeed': 4.2,
      'maximumUvIndex': 7,
      'snowfallAmount': 0,
      'airQualityForecast': {
        'pm10Grade': '보통',
        'pm25Grade': '낮음',
        'confidence': '높음',
      },
      'recommendations': [],
    });

    await _pump(tester, [day]);

    expect(find.text('최저'), findsOneWidget);
    expect(find.text('18℃'), findsOneWidget);
    expect(find.text('최고'), findsOneWidget);
    expect(find.text('27℃'), findsNWidgets(2));
    expect(find.text('평균 습도 63%'), findsOneWidget);
    expect(find.text('최대 풍속 4.2m/s'), findsOneWidget);
    expect(find.text('예상 신적설 0cm'), findsOneWidget);
    expect(find.text('자외선 최고 7'), findsOneWidget);
    expect(find.text('미세먼지 보통 · 초미세먼지 낮음 · 신뢰도 높음'), findsOneWidget);
    expect(find.textContaining('오존'), findsNothing);
  });

  for (final source in ['historical', 'KMA_OBSERVATION']) {
    testWidgets('과거 적설은 $source 근거로 최심신적설을 표시한다', (tester) async {
      final day = WeeklyForecastItem.fromJson({
        'forecastDate': '2026-10-09',
        'min': 10,
        'max': 20,
        'historical': source == 'historical',
        if (source == 'KMA_OBSERVATION') 'forecastSource': source,
        'snowfallAmount': 1.2,
        'recommendations': [],
      });
      await _pump(tester, [day],
          now: () => DateTime.parse('2026-10-10T01:00:00Z'));
      await tester.scrollUntilVisible(find.text('최심신적설 1.2cm'), 200);
      expect(find.text('최심신적설 1.2cm'), findsOneWidget);
      expect(find.textContaining('예상 신적설'), findsNothing);
      expect(find.text('적설량 1.2cm'), findsNothing);
    });
  }

  testWidgets('과거 신적설 미확보는 0cm로 바꾸지 않는다', (tester) async {
    await _pump(
        tester,
        [
          WeeklyForecastItem.fromJson({
            'forecastDate': '2026-10-09',
            'historical': true,
            'min': 10,
            'max': 20,
            'observationAvailability': {'snowfallAmount': 'NO_RECORD'},
            'recommendations': [],
          })
        ],
        now: () => DateTime.parse('2026-10-10T01:00:00Z'));
    expect(find.textContaining('최심신적설'), findsNothing);
    expect(find.textContaining('예상 신적설'), findsNothing);
  });

  testWidgets('자정에는 자료를 다시 받지 않아도 오늘 배지가 바뀐다', (tester) async {
    var now = DateTime.parse('2026-09-10T14:59:59Z');
    await _pump(tester, [_day('2026-09-10'), _day('2026-09-11')],
        now: () => now);
    expect(find.byKey(const ValueKey('week-today-2026-09-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-past-2026-09-10')), findsNothing);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('week-past-2026-09-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-today-2026-09-11')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('백그라운드 복귀 시 날짜를 다시 확인한다', (tester) async {
    var now = DateTime.parse('2026-09-10T01:00:00Z');
    await _pump(tester, [_day('2026-09-10'), _day('2026-09-11')],
        now: () => now);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(days: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('week-past-2026-09-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-past-2026-09-11')), findsNothing);
    expect(find.byKey(const ValueKey('week-today-2026-09-11')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('좁은 화면·2배 글씨에서도 날짜·범위·준비물이 넘치지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final weekly = WeeklyWeatherResponse.fromJson({
      'days': [
        {
          'forecastDate': '2026-12-31',
          'weatherLabel': '비와 눈',
          'min': '-15',
          'max': '-5',
          'recommendations': [
            {'type': 'HEAVY_SNOW_CAUTION', 'recommended': true},
            {'type': 'UMBRELLA', 'recommended': true},
            {'type': 'OUTERWEAR', 'recommended': true},
          ],
        },
        {'forecastDate': '2027-01-01', 'weatherLabel': '맑음'}
      ],
    });
    await _pump(
      tester,
      weekly.days,
      textScale: 2,
      now: () => DateTime.parse('2026-12-31T01:00:00Z'),
    );
    expect(find.text('12월 31일 (목)'), findsOneWidget);
    expect(find.text('많은 눈 대비'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

WeeklyForecastItem _day(
  String? date, {
  bool historical = false,
  String? forecastSource,
}) =>
    WeeklyForecastItem(
      date: '금',
      forecastDate: date,
      weatherLabel: '비',
      min: 20,
      max: 25,
      historical: historical,
      forecastSource: forecastSource,
      recommendations: const [],
    );

Future<void> _pump(
  WidgetTester tester,
  List<WeeklyForecastItem> days, {
  DateTime Function()? now,
  double textScale = 1,
  Widget? advertisement,
}) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
          body: WeekTab(
        weekly: WeeklyWeatherResponse(days: days),
        serverFeaturesAvailable: true,
        now: now ?? () => DateTime.parse('2026-09-10T01:00:00Z'),
        onRefresh: () async {},
        advertisement: advertisement,
      )),
    ),
  ));
}
