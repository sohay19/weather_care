import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/precipitation.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/features/home/widgets/week_precipitation.dart';
import 'package:weather_care/features/home/tabs/week_tab.dart';

void main() {
  for (final entry in {
    '강수없음': '0mm',
    '0': '0mm',
    '0.0mm': '0mm',
    '1.0mm 미만': '1mm 미만',
    '30.0~50.0mm': '30~50mm',
    '50.0mm 이상': '50mm 이상',
    '2,5mm': '2.5mm',
    '0.125mm': '0.125mm',
  }.entries) {
    test('강수 범위 원형 유지: ${entry.key}', () {
      expect(PrecipitationAmount.parse(entry.key)?.label, entry.value);
    });
  }
  test('결측·오류·단계 코드를 강수량 0 또는 mm로 바꾸지 않는다', () {
    for (final raw in [
      null,
      '',
      ' ',
      '자료없음',
      '적설없음',
      '-1mm',
      'NaNmm',
      'Infinitymm',
      '2',
      '3cm',
      '50~30mm',
      '0mm 미만',
      '1~2mm 이상',
      '예보 3mm 오류',
      '3mm 이상 5mm',
      '3.1234mm'
    ]) {
      expect(PrecipitationAmount.parse(raw), isNull, reason: '$raw');
    }
  });
  test('미만·범위·이상 합산에서 열린 경계와 소수를 보존한다', () {
    String sum(List<String> values) => values
        .map((v) => PrecipitationAmount.parse(v)!)
        .reduce((a, b) => a.plus(b))
        .label;
    expect(sum(['1mm 미만', '1mm 미만']), '2mm 미만');
    expect(sum(['5mm', '1mm 미만']), '5mm 이상 6mm 미만');
    expect(sum(['30~50mm', '1mm 미만']), '30mm 이상 51mm 미만');
    expect(sum(['50mm 이상', '3mm']), '53mm 이상');
    expect(sum(['0.1mm', '0.2mm']), '0.3mm');
    expect(sum(['10~20mm', '30~50mm']), '40~70mm');
  });
  test('날짜·시간 범위와 강수확률 최고값·앱 합산 출처를 표시한다', () {
    final lines = weekPrecipitationLines(_day([
      _hour(10, amount: '2mm', pop: 20),
      _hour(11, amount: '1mm 미만', pop: 70)
    ]));
    expect(lines, contains('9~11시 예보 기준 · 하루 중 일부 시간'));
    expect(lines, contains('시간대별 강수확률 중 최고 70%'));
    expect(lines, contains('예상 누적 강수량 2mm 이상 3mm 미만'));
    expect(lines.join(), contains('하루 전체의 확률이 아니에요'));
    expect(lines.join(), contains('앱에서 합산'));
  });
  test('새해 자정 자료와 UTC 시각을 전날의 23~24시로 표시한다', () {
    for (final at in ['2027-01-01T00:00:00+09:00', '2026-12-31T15:00:00Z']) {
      final lines = weekPrecipitationLines(_day([
        {'forecastAt': at, 'probability': 50, 'amountText': '2mm'},
      ]));
      expect(lines.first, '23~24시 예보 기준 · 하루 중 일부 시간');
      expect(lines, contains('예상 누적 강수량 2mm'));
    }
  });
  test('24개 자료일 때만 하루 전체 구간으로 표시한다', () {
    final lines = weekPrecipitationLines(
        _day(List.generate(24, (i) => _hour(i + 1, amount: '1mm'))));
    expect(lines.first, '0~24시 예보 기준');
    expect(lines, contains('예상 누적 강수량 24mm'));
  });
  test('중간 시간 누락 시 부분합을 전체 예상량으로 표시하지 않는다', () {
    final lines = weekPrecipitationLines(
        _day([_hour(10, amount: '2mm'), _hour(12, amount: '3mm')]));
    expect(lines.join(), contains('강수확률 2/3시간 자료 확인'));
    expect(lines.join(), contains('9~12시 예상 누적량을 계산하기 어려워요'));
    expect(lines.join(), isNot(contains('예상 누적 강수량 5mm')));
  });
  test('강수확률과 강수량의 결측은 독립적으로 처리한다', () {
    final lines = weekPrecipitationLines(_day([
      _hour(10, amount: '2mm', pop: -1),
      _hour(11, amount: '3mm', pop: 101)
    ]));
    expect(lines, contains('강수확률 0/2시간 자료 확인'));
    expect(lines, contains('예상 누적 강수량 5mm'));
    final missingAmount =
        weekPrecipitationLines(_day([_hour(10, amount: '', pop: 70)]));
    expect(missingAmount, contains('시간대별 강수확률 중 최고 70%'));
    expect(missingAmount.join(), contains('계산하기 어려워요'));
  });
  test('날짜 오류·중복·범위 외 시간대는 합계에서 조용히 제외하지 않는다', () {
    for (final hours in [
      [_hour(10), _hour(10)],
      [_hour(10), null],
      [
        {'forecastAt': '2026-12-30T10:00:00+09:00'}
      ],
      [
        {'forecastAt': '2026-12-31T10:00:00'}
      ],
      [
        {'forecastAt': '2026-12-31T24:00:00+09:00'}
      ],
      [
        {'forecastAt': '2026-02-31T10:00:00+09:00'}
      ],
    ]) {
      expect(weekPrecipitationLines(_day(hours)).single, contains('날짜·시간에 오류'));
    }
  });
  test('시간대는 정렬하되 0mm·0%만 있을 때 기본 안내는 생략한다', () {
    expect(weekPrecipitationLines(_day([_hour(11, pop: 0), _hour(10, pop: 0)])),
        isEmpty);
    final lines =
        weekPrecipitationLines(_day([_hour(11, pop: 20), _hour(10, pop: 0)]));
    expect(lines.first, contains('9~11시'));
    expect(lines.join(), isNot(contains('0mm')));
  });
  test('구 API·손상 자료·연장 예보는 0mm로 표시하지 않는다', () {
    for (final value in [
      null,
      {},
      {'kind': 'HOURLY', 'hours': 'bad'},
      {'kind': 'HOURLY', 'hours': List.filled(25, _hour(10))}
    ]) {
      final day = WeeklyForecastItem.fromJson(
          {'forecastDate': '2026-12-31', 'precipitationDetail': value});
      expect(weekPrecipitationLines(day).single, contains('확인하기 어려워요'));
    }
    final day = WeeklyForecastItem.fromJson({
      'forecastDate': '2026-12-31',
      'precipitationDetail': {
        'kind': 'EXTENDED',
        'hours': [],
        'extendedMaxProbability': 60
      },
    });
    expect(weekPrecipitationLines(day), contains('확인된 시간대의 강수확률 중 최고 60%'));
    expect(weekPrecipitationLines(day).last, contains('mm 합계를 계산하지 않아요'));
  });
  test('지난 날은 예보가 아닌 실제 일강수량으로 표시한다', () {
    final wet = WeeklyForecastItem.fromJson({
      'forecastDate': '2026-12-31',
      'precipitationDetail': {
        'kind': 'OBSERVATION',
        'hours': [],
        'observedAmount': 4.5,
      },
    });
    final dry = WeeklyForecastItem.fromJson({
      'forecastDate': '2026-12-31',
      'precipitationDetail': {
        'kind': 'OBSERVATION',
        'hours': [],
        'observedAmount': 0,
      },
    });

    expect(weekPrecipitationLines(wet), ['인근 관측소 실제 일강수량 4.5mm']);
    expect(weekPrecipitationLines(dry), ['인근 관측소에서 강수가 관측되지 않았어요.']);
  });
  testWidgets('강수 표시가 360px·2배 글자에서 넘치지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: Scaffold(
          body: WeekTab(
        weekly: WeeklyWeatherResponse(days: [
          _day([
            _hour(10, amount: '30~50mm', pop: 90),
            _hour(11, amount: '1mm 미만')
          ])
        ]),
        serverFeaturesAvailable: true,
        onRefresh: () async {},
        now: () => DateTime.utc(2026, 12, 31),
      )),
    )));
    await tester.drag(
      find.byKey(const ValueKey('week-tab')),
      const Offset(0, -700),
    );
    await tester.pump();
    expect(find.text('예상 누적 강수량 30mm 이상 51mm 미만'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Map<String, Object?> _hour(int end, {String amount = '강수없음', num? pop = 60}) =>
    {
      'forecastAt': end == 24
          ? '2027-01-01T00:00:00+09:00'
          : '2026-12-31T${end.toString().padLeft(2, '0')}:00:00+09:00',
      'probability': pop,
      'amountText': amount,
    };

WeeklyForecastItem _day(List<Object?> hours) => WeeklyForecastItem.fromJson({
      'forecastDate': '2026-12-31',
      'weatherLabel': '비',
      'min': 1,
      'max': 5,
      'recommendations': [],
      'precipitationDetail': {'kind': 'HOURLY', 'hours': hours},
    });
