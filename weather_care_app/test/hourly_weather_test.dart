import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/widgets/hourly_forecast_section.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  test('시간별 결측은 0·맑음·눈 없음으로 대체하지 않는다', () {
    final item = HourlyWeatherItem.fromJson({});
    expect(item.temperature, isNull);
    expect(item.apparentTemperature, isNull);
    expect(item.precipitationProbability, isNull);
    expect(item.precipitationAmount, isNull);
    expect(item.snowExpected, isNull);
    expect(item.snowfallAmount, isNull);
    expect(item.windSpeed, isNull);
    expect(item.skyCondition, isNull);
    expect(item.time, '--');
    expect(item.forecastDate, isNull);
  });

  test('실제 0과 명시된 눈 없음은 유지한다', () {
    final item = HourlyWeatherItem.fromJson(_zero);
    expect(item.temperature, 0);
    expect(item.apparentTemperature, 0);
    expect(item.precipitationProbability, 0);
    expect(item.precipitationAmount, 0);
    expect(item.snowExpected, isFalse);
    expect(item.snowfallAmount, 0);
    expect(item.windSpeed, 0);
    expect(item.skyCondition, '맑음');
    expect(item.uvIndex, 0);
    expect(item.pm25, 0);
    expect(item.pm10, 0);
  });

  test('잘못된 숫자와 빈 하늘 상태를 표시 가능한 값으로 바꾸지 않는다', () {
    final item = HourlyWeatherItem.fromJson({
      'temperature': 'unknown',
      'apparentTemperature': double.nan,
      'precipitationProbability': double.infinity,
      'precipitationAmount': '--',
      'snowExpected': 'unknown',
      'snowfallAmount': double.nan,
      'windSpeed': double.infinity,
      'uvIndex': '--',
      'pm25': double.nan,
      'skyCondition': ' ',
    });
    expect(item.temperature, isNull);
    expect(item.apparentTemperature, isNull);
    expect(item.precipitationProbability, isNull);
    expect(item.precipitationAmount, isNull);
    expect(item.snowExpected, isNull);
    expect(item.snowfallAmount, isNull);
    expect(item.windSpeed, isNull);
    expect(item.uvIndex, isNull);
    expect(item.pm25, isNull);
    expect(item.skyCondition, isNull);
  });

  test('시간별 예보 날짜와 시각은 UTC 날짜 경계에서도 한국시간으로 해석한다', () {
    for (final stamp in [
      '2026-09-10T15:00:00Z',
      '2026-09-11T00:00:00+09:00',
      '2026-09-11T00:00:00',
    ]) {
      final item = HourlyWeatherItem.fromJson({'forecastAt': stamp});
      expect(item.forecastDate, '2026-09-11');
      expect(item.time, '00');
    }
  });

  testWidgets('자료가 빠진 시간대도 유지하며 없는 값과 원인을 만들지 않는다', (tester) async {
    await _pumpHourly(tester, [{}]);
    final row = find.byKey(const ValueKey('today-hourly-0'));
    expect(row, findsOneWidget);
    for (final text in [
      '시각 자료 없음',
      '날씨 자료 없음',
      '예상 기온 자료 없음',
      '예상 체감 자료 없음',
      '자료 없음: 강수확률 · 강수량 · 쌓일 눈 · 풍속',
    ]) {
      expect(
          find.descendant(of: row, matching: find.text(text)), findsOneWidget);
    }
    for (final text in [
      '맑음',
      '예상 기온 0℃',
      '강수확률 0%',
      '강수량 0mm',
      '바람 0.0m/s',
      '눈 없음',
      '체감 미지원'
    ]) {
      expect(find.descendant(of: row, matching: find.text(text)), findsNothing);
    }
    expect(find.textContaining('오류가 있어'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('0도·무풍·대기질 0은 표시하고 무강수·무적설은 반복하지 않는다', (tester) async {
    await _pumpHourly(tester, [_zero]);
    final row = find.byKey(const ValueKey('today-hourly-0'));
    for (final text in [
      '예상 기온 0℃',
      '예상 체감 0℃',
      '바람 0.0m/s',
      '자외선 0',
      '초미세먼지 0㎍/㎥',
      '미세먼지 0㎍/㎥'
    ]) {
      expect(
          find.descendant(of: row, matching: find.text(text)), findsOneWidget);
    }
    expect(find.descendant(of: row, matching: find.textContaining('자료 없음')),
        findsNothing);
    expect(find.text('강수확률 0%'), findsNothing);
    expect(find.text('강수량 0mm'), findsNothing);
    expect(find.text('쌓일 눈 0cm'), findsNothing);
    expect(
      tester.getCenter(find.text('예상 기온 0℃')).dy,
      tester.getCenter(find.text('예상 체감 0℃')).dy,
    );
  });

  testWidgets('명시된 NONE 범위는 수치 필드가 없어도 결측으로 안내하지 않는다', (tester) async {
    await _pumpHourly(tester, [
      {
        ..._zero,
        'precipitationProbability': 20,
        'precipitationAmount': null,
        'snowfallAmount': null,
        'precipitationAmountRange': {'type': 'NONE', 'min': 0, 'max': 0},
        'snowfallAmountRange': {
          'type': 'NONE',
          'min': 0,
          'max': 0,
          'unit': 'CM'
        },
      }
    ]);
    final row = find.byKey(const ValueKey('today-hourly-0'));
    expect(find.descendant(of: row, matching: find.textContaining('자료 없음')),
        findsNothing);
    expect(find.text('강수량 0mm'), findsNothing);
    expect(find.text('쌓일 눈 0cm'), findsNothing);
    expect(find.text('강수확률 20%'), findsOneWidget);
  });

  testWidgets('일부 강수자료만 있을 때 다른 값을 보충하지 않는다', (tester) async {
    await _pumpHourly(tester, [
      {'time': '14', 'precipitationAmount': 2.5},
      {'time': '15', 'precipitationProbability': 80, 'snowExpected': true},
    ]);
    expect(find.text('강수량 2.5mm'), findsOneWidget);
    expect(find.text('강수확률 80%'), findsOneWidget);
    expect(find.text('눈이 예보됐어요'), findsOneWidget);
    expect(find.text('강수확률 0%'), findsNothing);
    expect(find.text('강수량 0mm'), findsNothing);
    expect(find.text('쌓일 눈 0cm'), findsNothing);
    expect(find.text('자료 없음: 강수량 · 쌓일 눈 · 풍속'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('360px·$scale배 글씨에서 강수 범위와 모든 지표를 잘리지 않게 표시한다', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpHourly(
          tester,
          [
            {
              ..._zero,
              'skyCondition': '빗방울/눈날림',
              'precipitationProbability': 80,
              'precipitationAmountRange': {
                'type': 'LESS_THAN',
                'min': 0,
                'max': 1
              },
              'snowfallAmountRange': {
                'type': 'LESS_THAN',
                'min': 0,
                'max': 0.5,
                'unit': 'CM'
              },
            },
            {
              'time': '15',
              'precipitationAmountRange': {
                'type': 'RANGE',
                'min': 30,
                'max': 50
              },
              'snowfallAmountRange': {
                'type': 'AT_LEAST',
                'min': 5,
                'unit': 'CM'
              },
            },
          ],
          scale: scale);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('today-hourly-0')),
        400,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      for (final text in [
        '강수확률 80%',
        '강수량 1mm 미만',
        '쌓일 눈 0.5cm 미만',
        '초미세먼지 0㎍/㎥',
        '미세먼지 0㎍/㎥',
        '강수량 30~50mm',
        '쌓일 눈 5cm 이상'
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('강수량 1mm'), findsNothing);
      expect(find.text('쌓일 눈 0.5cm'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('빈 시간별 예보는 0 값의 행을 만들지 않는다', (tester) async {
    await _pumpHourly(tester, []);
    expect(find.byKey(const ValueKey('today-hourly-0')), findsNothing);
    expect(find.text('시간별 예보 자료가 없어 표시하기 어려워요.'), findsOneWidget);
  });
}

const _zero = <String, dynamic>{
  'time': '14',
  'temperature': 0,
  'apparentTemperature': 0,
  'precipitationProbability': 0,
  'precipitationAmount': 0,
  'snowExpected': false,
  'snowfallAmount': 0,
  'windSpeed': 0,
  'uvIndex': 0,
  'pm10': 0,
  'pm25': 0,
  'skyCondition': '맑음',
};

Future<void> _pumpHourly(WidgetTester tester, List<Map<String, dynamic>> hourly,
    {double scale = 1}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: SingleChildScrollView(
          child: HourlyForecastSection(
            items: TodayWeatherResponse.fromJson({'hourly': hourly}).hourly,
          ),
        ),
      ),
    ),
  ));
}
