import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/tabs/week_tab.dart';
import 'package:weather_care/features/home/widgets/week_presentation.dart';
import 'package:weather_care/models/recommendation.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  test('날짜별 결측과 잘못된 숫자를 맑음·0·빈 추천 목록으로 해석하지 않는다', () {
    for (final raw in [
      <String, dynamic>{},
      {
        'weatherLabel': ' ',
        'min': 'NaN',
        'max': double.infinity,
        'recommendations': 'invalid',
      }
    ]) {
      final day = WeeklyForecastItem.fromJson(raw);
      expect(day.weatherLabel, isNull);
      expect(day.min, isNull);
      expect(day.max, isNull);
      expect(day.recommendationsAvailable, isFalse);
    }
    expect(WeeklyWeatherResponse.fromJson({'days': 'invalid'}).days, isEmpty);
  });

  test('숫자형·문자열형 실제 0과 영하기온은 보존하고 뒤집힌 최저·최고는 제외한다', () {
    final day = _day('10', {'min': -3, 'max': '0'});
    expect(weekTemperatureLabel(day, maximum: false), '최저 -3℃');
    expect(weekTemperatureLabel(day, maximum: true), '최고 0℃');
    final inverted = _day('10', {'min': 30, 'max': 20});
    expect(inverted.min, isNull);
    expect(inverted.max, isNull);
    expect(_summary([day]).maximum.value, '0℃');
  });

  test('알 수 없는 날씨와 부분 자료를 비 없음으로 집계하지 않는다', () {
    for (final label in ['정보 없음', '비 자료 없음', '맑음 확인 어려움', 'unknown']) {
      final day =
          _day('10', {'weatherLabel': label, 'weatherDataComplete': true});
      expect(weekWeatherLabel(day), isNull);
      expect(weekPrecipitation(day), isNull);
    }
    expect(weekPrecipitation(_day('10', {'weatherLabel': '맑음'})), isNull);
    expect(
        weekPrecipitation(
            _day('10', {'weatherLabel': '흐림', 'weatherDataComplete': false})),
        isNull);
    expect(
        weekPrecipitation(
            _day('10', {'weatherLabel': '흐림', 'weatherDataComplete': true})),
        isFalse);
  });

  test('빗방울을 포함한 강수 현상은 일부 결측이 있어도 확인된 날로 센다', () {
    for (final label in ['비', '눈', '소나기', '빗방울', '눈날림', '비/눈', '빗방울/눈날림']) {
      expect(
          weekPrecipitation(_day(
              '10', {'weatherLabel': label, 'weatherDataComplete': false})),
          isTrue);
    }
  });

  test('세 지표가 각자 받은 자료의 일수로 집계된다', () {
    final summary = _summary([
      _day('10', {
        'weatherLabel': '비',
        'min': 20,
        'max': '30',
        'recommendations': [_rec('UMBRELLA')]
      }),
      _day('11', {
        'weatherLabel': '맑음',
        'weatherDataComplete': true,
        'recommendations': []
      }),
      _day('12', {'max': 'NaN'}),
    ]);
    expect(summary.precipitation.value, '1일 확인');
    expect(summary.precipitation.detail, '강수 여부 확인 2/3일');
    expect(summary.maximum.value, '30℃');
    expect(summary.maximum.detail, '최고기온 확인 1/3일 중 최고');
    expect(summary.preparations.value, '1일 확인');
    expect(summary.preparations.detail, '준비물 판단 2/3일');
  });

  test('모든 결측·부분 무강수·확인된 무강수를 구분한다', () {
    expect(_summary([_day('10', {})]).precipitation.value, '0일');
    final clear =
        _day('10', {'weatherLabel': '맑음', 'weatherDataComplete': true});
    expect(_summary([clear, _day('11', {})]).precipitation.value, '0일');
    expect(_summary([clear]).precipitation.value, '0일');
  });

  test('날짜 미확인·중복 날짜는 값을 골라 합산하지 않는다', () {
    final summary = _summary([
      _day('10', {'weatherLabel': '비', 'max': 30}),
      _day('10', {'weatherLabel': '눈', 'max': 35}),
      _day(
          '11', {'weatherLabel': '흐림', 'weatherDataComplete': true, 'max': 22}),
      WeeklyForecastItem.fromJson({'weatherLabel': '비', 'max': 99}),
    ]);
    expect(summary.precipitation.value, '0일');
    expect(summary.maximum.value, '22℃');
    expect(summary.maximum.detail, '최고기온 확인 1/1일 중 최고');
    expect(summary.excludedNotice, '요약 제외: 날짜 미확인 1개 · 중복 날짜 1일');
  });

  test('추천 미수신과 명시적 빈 목록은 다르며 알 수 없는 종류를 우산으로 만들지 않는다', () {
    expect(_day('10', {}).recommendationsAvailable, isFalse);
    expect(
        _day('10', {'recommendations': []}).recommendationsAvailable, isTrue);
    final invalid = _day('10', {
      'recommendations': [
        _rec('FUTURE_TYPE'),
        null,
        {'type': 'MASK'}
      ]
    });
    expect(invalid.recommendationsAvailable, isFalse);
    expect(invalid.recommendations, isEmpty);
  });

  test('비활성·중복 추천을 제거한 뒤 활성 추천을 최대 세 개 보존한다', () {
    final day = _day('10', {
      'recommendations': [
        _rec('UMBRELLA', active: false),
        _rec('MASK'),
        _rec('MASK'),
        _rec('WATER'),
        _rec('SUNSCREEN'),
        _rec('OUTERWEAR'),
      ]
    });
    expect(day.recommendationsAvailable, isTrue);
    expect(day.recommendations.map((r) => r.type), [
      RecommendationType.mask,
      RecommendationType.water,
      RecommendationType.sunscreen
    ]);
    final disabled = _day('11', {
      'recommendations': [_rec('UMBRELLA', active: false)]
    });
    expect(_summary([disabled]).preparations.value, '0일');
  });

  test('일부 잘못된 추천이 있어도 유효한 추천은 보존한다', () {
    final day = _day('10', {
      'recommendations': [
        _rec('MASK'),
        {..._rec('WATER'), 'priority': 'high'}
      ]
    });
    expect(day.recommendationsAvailable, isFalse);
    expect(day.recommendations.single.type, RecommendationType.mask);
  });

  test('시간별 최고 포함을 명시하며 값이 없으면 최고를 만들지 않는다', () {
    final day = _day('10', {
      'min': -2.5,
      'max': 0,
      'minTemperatureSource': 'DAILY',
      'maxTemperatureSource': 'HOURLY'
    });
    expect(weekTemperatureLabel(day, maximum: false), '최저 -2.5℃');
    expect(weekTemperatureLabel(day, maximum: true), '시간별 최고 0℃');
    expect(_summary([day]).maximum.detail, contains('시간별 예보 포함'));
    expect(_summary([_day('10', {})]).maximum.value, '자료 없음');
  });

  testWidgets('전부 결측이면 날짜 카드는 유지하고 추가 결측 항목은 비운다', (tester) async {
    await _pump(tester, [_day('10', {})]);
    expect(find.text('날씨 자료 없음'), findsOneWidget);
    expect(find.byKey(const ValueKey('weather-condition-unknown')),
        findsOneWidget);
    expect(find.text('오전 최저'), findsNothing);
    expect(find.text('오후 최고'), findsNothing);
    expect(find.text('준비물 추천 자료 없음'), findsOneWidget);
    expect(find.text('준비물 없음'), findsNothing);
    expect(find.text('0일'), findsOneWidget);
    expect(find.text('예상 강수일'), findsOneWidget);
    expect(find.text('예상 주중 최고기온'), findsOneWidget);
    expect(find.text('예상 준비물'), findsOneWidget);
  });

  testWidgets('빈 추천은 불필요하다는 뜻으로 표시하지 않는다', (tester) async {
    await _pump(tester, [
      _day('10', {'recommendations': []})
    ]);
    expect(find.text('표시할 준비물 추천 없음'), findsOneWidget);
    expect(find.text('준비물 없음'), findsNothing);
  });

  testWidgets('직접 조회에서는 오래된 추천도 노출하지 않고 미지원으로 안내한다', (tester) async {
    await _pump(
        tester,
        [
          _day('10', {
            'recommendations': [_rec('MASK')]
          })
        ],
        server: false);
    expect(find.text('마스크'), findsNothing);
    expect(find.text('미지원'), findsOneWidget);
    expect(find.text('운영 서버 미연결로 준비물 미지원'), findsOneWidget);
  });

  testWidgets('좁은 화면 큰 글씨에 부분 집계·시간별 범위·결측 안내가 넘치지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(
        tester,
        [
          _day('10', {
            'weatherLabel': '비',
            'weatherDataComplete': false,
            'max': 24,
            'maxTemperatureSource': 'HOURLY',
            'recommendations': [_rec('HEAVY_SNOW_CAUTION'), _rec('UNKNOWN')],
          })
        ],
        scale: 2);
    await tester.scrollUntilVisible(find.text('일부 준비물 추천 자료를 확인하기 어려워요'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('일부 시간대 날씨 자료 없음'), findsOneWidget);
    expect(find.text('오전 최저'), findsNothing);
    expect(find.text('오후 최고'), findsOneWidget);
    expect(find.text('24℃'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _rec(String type, {bool active = true}) =>
    {'type': type, 'recommended': active};
WeeklyForecastItem _day(String date, Map<String, dynamic> data) =>
    WeeklyForecastItem.fromJson({
      'forecastDate': '2026-09-$date',
      ...data,
    });
WeekSummaryData _summary(List<WeeklyForecastItem> days) =>
    buildWeekSummary(days, serverFeaturesAvailable: true);

Future<void> _pump(WidgetTester tester, List<WeeklyForecastItem> days,
    {bool server = true, double scale = 1}) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
        body: WeekTab(
            weekly: WeeklyWeatherResponse(days: days),
            serverFeaturesAvailable: server,
            onRefresh: () async {},
            now: () => DateTime.utc(2026, 9, 10))),
  )));
}
