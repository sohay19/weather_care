import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/week_tab.dart';
import 'package:weather_care/features/home/widgets/week_presentation.dart';
import 'package:weather_care/models/precipitation.dart';
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
    expect(find.byKey(const ValueKey('week-past-2026-10-01')), findsNothing);
    await _moveDays(tester, -1);
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
    expect(find.byKey(const ValueKey('week-today-2026-09-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-precipitation-2026-09-10')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('week-snowfall-2026-09-10')), findsOneWidget);
    await _moveDays(tester, 1);
    expect(find.text('9월 11일 (금)'), findsOneWidget);
    expect(find.byKey(const ValueKey('week-today-2026-09-10')), findsNothing);
    expect(find.textContaining('이번주'), findsNothing);
  });

  testWidgets('한국 날짜보다 지난 카드는 지난 날짜로 표시한다', (tester) async {
    await _pump(tester, [_day('2026-09-10'), _day('2026-09-11')],
        now: () => DateTime.parse('2026-09-10T15:00:00Z'));
    await _moveDays(tester, -1);
    expect(find.byKey(const ValueKey('week-past-2026-09-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-past-2026-09-11')), findsNothing);
    expect(find.byKey(const ValueKey('week-today-2026-09-11')), findsNothing);
    await _moveDays(tester, 1);
    expect(find.byKey(const ValueKey('week-today-2026-09-11')), findsOneWidget);
    final badge = find.byKey(const ValueKey('week-today-2026-09-11'));
    final card = find.byKey(const ValueKey('week-day-2026-09-11'));
    expect(tester.getRect(badge).right,
        closeTo(tester.getRect(card).right - 17, 1.1));
  });

  testWidgets('날짜 없는 기존 서버 자료는 주간 슬롯에 임의로 끼워 넣지 않는다', (tester) async {
    await _pump(tester, [_day(null)]);
    expect(find.byKey(const ValueKey('week-today-2026-09-10')), findsOneWidget);
    await _moveDays(tester, -4);
    expect(find.text('9월 6일 (일)'), findsOneWidget);
    expect(find.text('인근 관측소의 실제 일관측 자료가 없어요.'), findsOneWidget);
    await _moveDays(tester, 6);
    expect(find.text('9월 12일 (토)'), findsOneWidget);
    expect(find.text('날짜 확인 어려움'), findsNothing);
  });

  testWidgets('빈 목록도 일~토 자리를 유지하고 정상 날씨를 만들지 않는다', (tester) async {
    await _pump(tester, []);
    expect(find.text('9월 6일~9월 12일 · 일~토'), findsOneWidget);
    await _moveDays(tester, -4);
    expect(find.text('9월 6일 (일)'), findsOneWidget);
    await _moveDays(tester, 6);
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

    await _moveDays(tester, 4);
    expect(find.text('9월 19일 (토)'), findsOneWidget);
    expect(
      find.text('단기·중기예보를 모두 받지 못해 표시할 자료가 없어요.'),
      findsOneWidget,
    );
  });

  testWidgets('지난 날짜의 자료출처는 숨기고 당일 출처만 표시한다', (tester) async {
    await _pump(
      tester,
      [
        _day('2026-09-08', forecastSource: 'KMA_OBSERVATION'),
        _day('2026-09-10', forecastSource: 'KMA_MID_TERM'),
      ],
    );
    expect(find.text('저장된 예보'), findsNothing);
    expect(find.text('중기예보'), findsOneWidget);
    await _moveDays(tester, -2);
    expect(find.text('저장된 예보'), findsNothing);
    expect(find.text('지난 날짜'), findsOneWidget);
  });

  testWidgets('지난 날짜에는 실제 관측을 표시한다', (tester) async {
    final observation = WeeklyForecastItem.fromJson({
      'forecastDate': '2026-09-08',
      'weatherLabel': '비·눈 기록 없음',
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
    await _moveDays(tester, -2);

    expect(find.text('실제 관측'), findsNothing);
    expect(find.text('비·눈 기록 없음'), findsOneWidget);
    expect(find.byKey(const ValueKey('weather-condition-unknown')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('weather-condition-rain')), findsNothing);
    expect(find.textContaining('예보격자 대표점에서 3.2km'), findsNothing);
    expect(find.textContaining('강수 관측 0mm'), findsOneWidget);
    expect(find.text('지난 날은 준비물 추천 대상이 아니에요'), findsNothing);
    expect(find.byKey(const ValueKey('week-past-2026-09-08')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('week-past-2026-09-08')))
          .style
          ?.color,
      WeatherCareTheme.textPrimary,
    );
    expect(find.byType(ColorFiltered), findsNothing);
    final card = tester.widget<Container>(
      find.byKey(const ValueKey('week-day-2026-09-08')),
    );
    expect((card.decoration as BoxDecoration).color,
        WeatherCareTheme.surfaceMuted);
  });

  testWidgets('지난 날짜의 대기질은 저장된 측정소 관측 평균으로 표시한다', (tester) async {
    final observation = WeeklyForecastItem.fromJson({
      'forecastDate': '2026-09-08',
      'weatherLabel': '비·눈 기록 없음',
      'forecastSource': 'KMA_OBSERVATION',
      'historical': true,
      'min': 18,
      'max': 25,
      'averageHumidity': 51,
      'maximumWindSpeed': 5.4,
      'airQualityObservation': {
        'stationName': '구로',
        'observedHours': 20,
        'pm25': 12.5,
        'pm10': 27,
      },
      'recommendations': [],
    });
    await _pump(tester, [observation]);
    await _moveDays(tester, -2);
    expect(find.textContaining('평균 습도 51%'), findsWidgets);
    expect(find.textContaining('최대 풍속 5.4m/s'), findsWidgets);
    expect(find.textContaining('초미세먼지 12.5㎍/㎥'), findsWidgets);
    expect(find.textContaining('주간 예보에서 제공되지 않아요'), findsNothing);
    for (final (label, title) in [
      ('평균 습도 51%', '습도'),
      ('최대 풍속 5.4m/s', '바람'),
      ('초미세먼지 12.5㎍/㎥', '대기질 관측'),
    ]) {
      await tester.ensureVisible(find.textContaining(label));
      await tester.tap(find.textContaining(label));
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.text(title)),
          findsOneWidget);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('지난 날짜에 남은 예보값은 실제 관측으로 표시하지 않는다', (tester) async {
    await _pump(tester, [
      WeeklyForecastItem.fromJson({
        'forecastDate': '2026-09-09',
        'weatherLabel': '맑음',
        'historical': true,
        'min': 10,
        'max': 20,
        'averageHumidity': 63,
        'recommendations': [],
      }),
    ]);
    await _moveDays(tester, -1);
    expect(find.byKey(const ValueKey('week-unavailable-2026-09-09')),
        findsOneWidget);
    expect(find.text('인근 관측소의 실제 일관측 자료가 없어요.'), findsOneWidget);
    expect(find.textContaining('평균 습도 63%'), findsNothing);
  });

  testWidgets('광고는 상단 요약과 한 장의 날짜 카드 사이에 표시한다', (tester) async {
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
    final day =
        tester.getTopLeft(find.byKey(const ValueKey('week-day-2026-09-10'))).dy;
    final heading = find.byKey(const ValueKey('week-selected-date'));
    expect(advertisement, greaterThan(summary));
    expect(advertisement, lessThan(day));
    expect(
        tester.getTopLeft(heading).dy - (advertisement + 50), closeTo(24, 1));
    expect(find.text('5 / 7'), findsNothing);
    expect(tester.widget<Text>(heading).data, '9월 10일 (목)');
    expect(tester.getTopLeft(heading).dy, greaterThan(advertisement));
    expect(tester.getTopLeft(heading).dy, lessThan(day));
    expect(
      tester.getRect(heading).center.dx,
      closeTo(
          tester
              .getRect(find.byKey(const ValueKey('week-day-2026-09-10')))
              .center
              .dx,
          1),
    );
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('week-day-2026-09-10')),
          matching: find.text('9월 10일 (목)'),
        ),
        findsNothing);
  });

  testWidgets('시간 자료가 없으면 기존 일별 칩만 표시한다', (tester) async {
    await _pump(tester, [
      WeeklyForecastItem.fromJson({
        'forecastDate': '2026-09-10',
        'weatherLabel': '맑음',
        'averageHumidity': 63,
        'recommendations': [],
      })
    ]);
    expect(find.textContaining('습도 쾌적'), findsOneWidget);
    expect(find.text('시간별 예보'), findsNothing);
  });

  testWidgets('당일 시간 자료가 있으면 카드 칩 아래에 받은 시각만 표시한다', (tester) async {
    await _pump(
      tester,
      [
        WeeklyForecastItem.fromJson({
          'forecastDate': '2026-09-10',
          'weatherLabel': '맑음',
          'averageHumidity': 63,
          'recommendations': [],
        })
      ],
      timelineHourly: [
        _hourly('2026-09-10', '10'),
        _hourly('2026-09-10', '11'),
      ],
    );
    final section =
        find.byKey(const ValueKey('week-2026-09-10-hourly-timeline-section'));
    expect(section, findsOneWidget);
    expect(find.textContaining('습도 쾌적'), findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('10시')),
        findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('11시')),
        findsOneWidget);
    expect(
        find.descendant(of: section, matching: find.text('12시')), findsNothing);
    expect(find.byKey(const ValueKey('week-2026-09-10-hourly-filter-weather')),
        findsOneWidget);
  });

  testWidgets('시간별 예보는 준비물 아래에 표시한다', (tester) async {
    await _pump(tester, [
      WeeklyForecastItem.fromJson({
        'forecastDate': '2026-09-10',
        'weatherLabel': '비',
        'recommendations': [
          {'type': 'UMBRELLA', 'recommended': true},
        ],
      }),
    ], timelineHourly: [
      _hourly('2026-09-10', '10'),
    ]);

    expect(find.text('우산'), findsOneWidget);
    expect(find.text('시간별 예보'), findsOneWidget);
    final divider =
        find.byKey(const ValueKey('week-hourly-divider-2026-09-10'));
    expect(divider, findsOneWidget);
    expect(
        tester.getTopLeft(divider).dy - tester.getRect(find.text('우산')).bottom,
        greaterThanOrEqualTo(20));
    expect(tester.getTopLeft(find.text('시간별 예보')).dy,
        greaterThan(tester.getTopLeft(divider).dy));
    expect(
      find.byKey(const ValueKey('week-2026-09-10-hourly-title-icon')),
      findsOneWidget,
    );
  });

  testWidgets('시간별 항목이 있어도 일별 칩을 함께 표시한다', (tester) async {
    final day = WeeklyForecastItem.fromJson({
      'forecastDate': '2026-09-10',
      'weatherLabel': '맑음',
      'averageHumidity': 63,
      'maximumWindSpeed': 4.2,
      'maximumUvIndex': 7,
      'snowfallAmount': 0,
      'airQualityForecast': {'pm10Grade': '보통'},
      'recommendations': [],
    });
    await _pump(tester, [
      day
    ], timelineHourly: [
      const HourlyWeatherItem(
        time: '11',
        forecastDate: '2026-09-10',
        temperature: 20,
        precipitationProbability: null,
        precipitationAmount: null,
        snowExpected: false,
        snowfallAmount: 0,
        windSpeed: 2,
        humidity: 63,
        skyCondition: '맑음',
      ),
    ]);

    expect(find.textContaining('습도 쾌적'), findsOneWidget);
    expect(find.textContaining('바람 약간 강한 바람'), findsOneWidget);
    expect(find.textContaining('예상 신적설 0cm'), findsOneWidget);
    expect(find.textContaining('자외선 높음'), findsOneWidget);
    expect(find.textContaining('대기질 보통'), findsOneWidget);
    expect(find.byKey(const ValueKey('week-2026-09-10-hourly-filter-humidity')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('week-2026-09-10-hourly-filter-wind')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('week-2026-09-10-hourly-filter-snowfall')),
        findsNothing);
  });

  testWidgets('시간별 신적설과 자외선이 있어도 일별 행과 칩을 표시한다', (tester) async {
    final day = WeeklyForecastItem.fromJson({
      'forecastDate': '2026-09-10',
      'weatherLabel': '맑음',
      'snowfallAmount': 0,
      'maximumUvIndex': 7,
      'recommendations': [],
    });
    await _pump(tester, [
      day
    ], timelineHourly: [
      HourlyWeatherItem(
        time: '11',
        forecastDate: '2026-09-10',
        precipitationPeriod: PrecipitationPeriod(
          start: DateTime.utc(2026, 9, 10, 2),
          end: DateTime.utc(2026, 9, 10, 3),
        ),
        temperature: 20,
        precipitationProbability: null,
        precipitationAmount: null,
        snowExpected: false,
        snowfallAmount: 0,
        windSpeed: null,
        uvIndex: 6,
        skyCondition: '맑음',
      ),
    ]);

    expect(find.textContaining('예상 신적설 0cm'), findsOneWidget);
    expect(find.textContaining('자외선 높음'), findsOneWidget);
    expect(find.byKey(const ValueKey('week-2026-09-10-hourly-filter-snowfall')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('week-2026-09-10-hourly-filter-uv')),
        findsOneWidget);
  });

  testWidgets('내일 예보는 받은 시간대까지만 표시하고 다른 날짜를 섞지 않는다', (tester) async {
    await _pump(tester, [
      _day('2026-09-11')
    ], hourly: [
      _hourly('2026-09-11', '10'),
      _hourly('2026-09-11', '11'),
      _hourly('2026-09-12', '12'),
    ]);
    await _moveDays(tester, 1);
    final section =
        find.byKey(const ValueKey('week-2026-09-11-hourly-timeline-section'));
    expect(section, findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('10시')),
        findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('11시')),
        findsOneWidget);
    expect(
        find.descendant(of: section, matching: find.text('12시')), findsNothing);
  });

  testWidgets('항목별로 값이 있는 시간만 표시한다', (tester) async {
    await _pump(tester, [
      _day('2026-09-10')
    ], timelineHourly: [
      _hourly('2026-09-10', '10'),
      _hourly('2026-09-10', '11'),
      const HourlyWeatherItem(
        time: '12',
        forecastDate: '2026-09-10',
        temperature: null,
        precipitationProbability: null,
        precipitationAmount: null,
        snowExpected: null,
        snowfallAmount: null,
        windSpeed: null,
        skyCondition: null,
        uvIndex: 6,
      ),
    ]);
    final uvFilter =
        find.byKey(const ValueKey('week-2026-09-10-hourly-filter-uv'));
    await tester.ensureVisible(uvFilter);
    await tester.tap(uvFilter);
    await tester.pumpAndSettle();
    final section =
        find.byKey(const ValueKey('week-2026-09-10-hourly-timeline-section'));
    expect(
        find.descendant(of: section, matching: find.text('10시')), findsNothing);
    expect(find.descendant(of: section, matching: find.text('12시')),
        findsOneWidget);
  });

  testWidgets('오늘 자외선 수치 안쪽은 오늘 카드와 같은 배경색을 쓴다', (tester) async {
    await _pump(tester, [
      _day('2026-09-10')
    ], timelineHourly: [
      const HourlyWeatherItem(
        time: '12',
        forecastDate: '2026-09-10',
        temperature: null,
        precipitationProbability: null,
        precipitationAmount: null,
        snowExpected: null,
        snowfallAmount: null,
        windSpeed: null,
        uvIndex: 3,
        skyCondition: null,
      ),
    ]);
    final uvFilter =
        find.byKey(const ValueKey('week-2026-09-10-hourly-filter-uv'));
    await tester.ensureVisible(uvFilter);
    await tester.tap(uvFilter);
    await tester.pumpAndSettle();
    final center = tester.widget<Container>(
      find.byKey(const ValueKey('today-hourly-uv-center')),
    );
    expect((center.decoration! as BoxDecoration).color,
        WeatherCareTheme.of(tester.element(uvFilter)).primarySoft);
  });

  testWidgets('Week에만 있는 시간별 강수는 강수 타임라인으로 표시한다', (tester) async {
    await _pump(tester, [
      WeeklyForecastItem.fromJson({
        'forecastDate': '2026-09-12',
        'weatherLabel': '비',
        'precipitationDetail': {
          'kind': 'HOURLY',
          'hours': [
            {
              'forecastAt': '2026-09-12T02:00:00Z',
              'probability': 30,
              'amountText': '1mm',
            },
            {
              'forecastAt': '2026-09-12T03:00:00Z',
              'probability': 50,
              'amountText': '2mm',
            },
          ],
        },
        'recommendations': [],
      })
    ]);
    await _moveDays(tester, 2);
    final section =
        find.byKey(const ValueKey('week-2026-09-12-hourly-timeline-section'));
    expect(section, findsOneWidget);
    expect(find.byKey(const ValueKey('week-2026-09-12-hourly-filter-weather')),
        findsNothing);
    expect(
        find.byKey(
            const ValueKey('week-2026-09-12-hourly-filter-precipitation')),
        findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('10~11시')),
        findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('11~12시')),
        findsOneWidget);
  });

  testWidgets('지난 날짜에는 시간별 예보가 남아 있어도 타임라인을 표시하지 않는다', (tester) async {
    await _pump(tester, [
      WeeklyForecastItem.fromJson({
        'forecastDate': '2026-09-09',
        'weatherLabel': '맑음',
        'historical': true,
        'forecastSource': 'KMA_OBSERVATION',
        'averageHumidity': 63,
        'maximumWindSpeed': 4.2,
        'maximumUvIndex': 7,
        'snowfallAmount': 1.2,
        'recommendations': [],
      }),
    ], hourly: [
      _hourly('2026-09-09', '10')
    ]);
    await _moveDays(tester, -1);
    expect(find.text('시간별 예보'), findsNothing);
    expect(find.textContaining('평균 습도 63%'), findsOneWidget);
    expect(find.textContaining('최대 풍속 4.2m/s'), findsOneWidget);
    expect(find.textContaining('최심신적설 1.2cm'), findsOneWidget);
    expect(find.textContaining('자외선 최고 7'), findsOneWidget);
  });

  testWidgets('일별 카드가 비어도 해당 날짜 시간 자료가 있으면 표시한다', (tester) async {
    await _pump(tester, [], timelineHourly: [_hourly('2026-09-10', '10')]);
    expect(find.text('시간별 예보'), findsOneWidget);
    expect(find.text('10시'), findsOneWidget);
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
    expect(find.text('27℃'), findsOneWidget);
    expect(find.textContaining('최저 18℃'), findsOneWidget);
    expect(find.textContaining('최고 27℃'), findsOneWidget);
    expect(find.textContaining('습도 쾌적'), findsOneWidget);
    expect(find.textContaining('바람 약간 강한 바람'), findsOneWidget);
    expect(find.textContaining('예상 신적설 0cm'), findsOneWidget);
    expect(find.textContaining('자외선 높음'), findsOneWidget);
    expect(find.textContaining('대기질 보통·낮음'), findsOneWidget);
    final humidityChip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.textContaining('습도 쾌적'),
        matching: find.byType(ChoiceChip),
      ),
    );
    final humiditySpans =
        ((humidityChip.label as Text).textSpan! as TextSpan).children!;
    expect((humiditySpans[0] as TextSpan).text, '습도 ');
    expect((humiditySpans[1] as TextSpan).text, '쾌적');
    expect(humidityChip.labelStyle?.fontFamily, WeatherCareTheme.fontChosunSg);
    expect(humidityChip.labelStyle?.fontWeight, FontWeight.w400);
    expect(humiditySpans[1].style?.fontWeight, FontWeight.w700);
    expect(humidityChip.elevation, 2);
    expect(humidityChip.side?.width, 1.2);
    expect(find.byIcon(Icons.touch_app_outlined), findsNothing);
    await tester.scrollUntilVisible(find.textContaining('습도 쾌적'), 250);
    await tester.tap(find.textContaining('습도 쾌적'));
    await tester.pumpAndSettle();
    expect(find.text('평균 습도 63%'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    for (final (label, value) in [
      ('바람 약간 강한 바람', '최대 풍속 4.2m/s'),
      ('자외선 높음', '자외선지수 최고 7'),
    ]) {
      await tester.ensureVisible(find.textContaining(label));
      await tester.tap(find.textContaining(label));
      await tester.pumpAndSettle();
      expect(find.text(value), findsOneWidget);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.textContaining('대기질 보통·낮음'));
    await tester.tap(find.textContaining('대기질 보통·낮음'));
    await tester.pumpAndSettle();
    expect(find.textContaining('농도 수치는 주간 예보에서 제공되지 않아요'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('오존'), findsNothing);
  });

  testWidgets('과거 관측 적설은 최심신적설로 표시한다', (tester) async {
    final day = WeeklyForecastItem.fromJson({
      'forecastDate': '2026-10-09',
      'min': 10,
      'max': 20,
      'historical': true,
      'forecastSource': 'KMA_OBSERVATION',
      'snowfallAmount': 1.2,
      'recommendations': [],
    });
    await _pump(tester, [day],
        now: () => DateTime.parse('2026-10-10T01:00:00Z'));
    await _moveDays(tester, -1);
    await tester.scrollUntilVisible(find.textContaining('최심신적설 1.2cm'), 200);
    expect(find.textContaining('강설 관측 · 최심신적설 1.2cm'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('week-snowfall-2026-10-09')), findsOneWidget);
    expect(
        find.ancestor(
            of: find.textContaining('최심신적설 1.2cm'),
            matching: find.byType(ChoiceChip)),
        findsNothing);
    expect(find.textContaining('예상 신적설'), findsNothing);
    expect(find.text('적설량 1.2cm'), findsNothing);
  });

  testWidgets('과거 신적설 미확보는 0cm로 바꾸지 않는다', (tester) async {
    await _pump(
        tester,
        [
          WeeklyForecastItem.fromJson({
            'forecastDate': '2026-10-09',
            'historical': true,
            'forecastSource': 'KMA_OBSERVATION',
            'min': 10,
            'max': 20,
            'observationAvailability': {'snowfallAmount': 'NO_RECORD'},
            'recommendations': [],
          })
        ],
        now: () => DateTime.parse('2026-10-10T01:00:00Z'));
    await _moveDays(tester, -1);
    expect(find.textContaining('최심신적설 자료 없음'), findsOneWidget);
    expect(find.textContaining('최심신적설 0cm'), findsNothing);
    expect(find.textContaining('강수 관측 자료 없음'), findsOneWidget);
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
    expect(find.byKey(const ValueKey('week-past-2026-09-10')), findsNothing);
    expect(find.byKey(const ValueKey('week-today-2026-09-11')), findsOneWidget);
    await _moveDays(tester, -1);
    expect(find.byKey(const ValueKey('week-past-2026-09-10')), findsOneWidget);
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
    expect(find.byKey(const ValueKey('week-past-2026-09-10')), findsNothing);
    expect(find.byKey(const ValueKey('week-past-2026-09-11')), findsNothing);
    expect(find.byKey(const ValueKey('week-today-2026-09-11')), findsOneWidget);
    await _moveDays(tester, -1);
    expect(find.byKey(const ValueKey('week-past-2026-09-10')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('날짜 카드는 한 장씩 버튼과 스와이프로 넘긴다', (tester) async {
    await _pump(tester, [_day('2026-09-10'), _day('2026-09-11')]);
    final cardRect =
        tester.getRect(find.byKey(const ValueKey('week-day-2026-09-10')));
    final previousRect =
        tester.getRect(find.byKey(const ValueKey('week-previous-day')));
    final nextRect =
        tester.getRect(find.byKey(const ValueKey('week-next-day')));
    expect(previousRect.width, 32);
    expect(nextRect.width, 32);
    expect(previousRect.right, lessThan(cardRect.left));
    expect(nextRect.left, greaterThan(cardRect.right));
    expect(previousRect.center.dy, closeTo(cardRect.center.dy, 1));
    expect(find.byKey(const ValueKey('week-day-2026-09-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-day-2026-09-11')), findsNothing);
    await _moveDays(tester, 1);
    expect(find.byKey(const ValueKey('week-day-2026-09-10')), findsNothing);
    expect(find.byKey(const ValueKey('week-day-2026-09-11')), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('week-selected-date')))
            .data,
        '9월 11일 (금)');
    await tester.drag(find.byKey(const ValueKey('week-day-swipe-area')),
        const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('week-day-2026-09-10')), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('week-day-swipe-area')),
        const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('week-day-2026-09-11')), findsOneWidget);
    await _moveDays(tester, -1);
    await _moveDays(tester, -4);
    expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('week-previous-day')))
            .onPressed,
        isNull);
    await _moveDays(tester, 6);
    expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('week-next-day')))
            .onPressed,
        isNull);
  });

  testWidgets('좁은 화면·2배 글씨에서도 날짜·범위·준비물이 넘치지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final weekly = WeeklyWeatherResponse.fromJson({
      'days': [
        {
          'forecastDate': '2026-12-31',
          'weatherLabel': '비와 눈',
          'min': '-15',
          'max': '-5',
          'averageHumidity': 63,
          'maximumWindSpeed': 4.2,
          'maximumUvIndex': 7,
          'snowfallAmount': 1,
          'airQualityForecast': {
            'pm10Grade': '보통',
            'pm25Grade': '낮음',
            'ozoneGrade': '높음',
          },
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
      timelineHourly: [_hourly('2026-12-31', '10')],
    );
    expect(find.text('12월 31일 (목)'), findsOneWidget);
    expect(find.text('많은 눈 대비'), findsOneWidget);
    expect(tester.widget<Text>(find.text('많은 눈 대비')).style?.fontSize, 10);
    expect(tester.takeException(), isNull);
  });
}

WeeklyForecastItem _day(
  String? date, {
  String? forecastSource,
}) =>
    WeeklyForecastItem(
      date: '금',
      forecastDate: date,
      weatherLabel: '비',
      min: 20,
      max: 25,
      forecastSource: forecastSource,
      recommendations: const [],
    );

HourlyWeatherItem _hourly(String date, String hour) => HourlyWeatherItem(
      time: hour,
      forecastDate: date,
      temperature: 20,
      precipitationProbability: 30,
      precipitationAmount: 1,
      snowExpected: false,
      snowfallAmount: 0,
      windSpeed: 2,
      skyCondition: '맑음',
    );

Future<void> _moveDays(WidgetTester tester, int count) async {
  final key = ValueKey(count < 0 ? 'week-previous-day' : 'week-next-day');
  for (var index = 0; index < count.abs(); index++) {
    final arrow = find.byKey(key);
    await tester.ensureVisible(arrow);
    await tester.tap(arrow);
    await tester.pumpAndSettle();
  }
}

Future<void> _pump(
  WidgetTester tester,
  List<WeeklyForecastItem> days, {
  DateTime Function()? now,
  double textScale = 1,
  Widget? advertisement,
  List<HourlyWeatherItem> hourly = const [],
  List<HourlyWeatherItem> timelineHourly = const [],
}) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
          body: WeekTab(
        weekly: WeeklyWeatherResponse(days: days),
        serverFeaturesAvailable: true,
        now: now ?? () => DateTime.parse('2026-09-10T01:00:00Z'),
        onRefresh: () async {},
        advertisement: advertisement,
        hourly: hourly,
        timelineHourly: timelineHourly,
      )),
    ),
  ));
}
