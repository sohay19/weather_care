import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/widgets/hourly_forecast_section.dart';
import 'package:weather_care/models/precipitation.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/utils/korea_date.dart';

void main() {
  test('기온은 정시를 유지하고 강수는 이전 1시간을 UTC/KST 모두 같은 값으로 읽는다', () {
    final first = HourlyWeatherItem.fromJson(_slot('2026-12-31', 15));
    final second = HourlyWeatherItem.fromJson({
      ..._slot('2026-12-31', 15),
      'forecastAt': '2026-12-31T06:00:00Z',
      'precipitationPeriod': {
        'start': '2026-12-31T05:00:00.000Z',
        'end': '2026-12-31T06:00:00Z'
      }
    });
    expect(first.time, '15');
    expect(first.temperature, 22);
    expect(first.precipitationPeriod?.label, '14~15시');
    expect(second.precipitationPeriod?.start, first.precipitationPeriod?.start);
    expect(second.time, first.time);
  });

  test('연도 경계 00시 강수는 전날 23~24시에 속한다', () {
    final item = HourlyWeatherItem.fromJson(_slot('2027-01-01', 0));
    expect(item.forecastDate, '2027-01-01');
    expect(item.precipitationPeriod?.date, '2026-12-31');
    expect(item.precipitationPeriod?.label, '23~24시');
  });

  test('잘못된 날짜·무시간대·3시간·불일치 종료 시각은 1시간으로 추정하지 않는다', () {
    const at = '2026-09-10T15:00:00+09:00';
    for (final period in [
      null,
      {},
      {'start': '2026-09-10T14:00:00', 'end': at},
      {'start': '2026-09-10T12:00:00+09:00', 'end': at},
      {
        'start': '2026-09-10T13:00:00+09:00',
        'end': '2026-09-10T14:00:00+09:00'
      },
      {'start': '2026-02-30T14:00:00+09:00', 'end': at},
    ]) {
      expect(PrecipitationPeriod.fromJson(period, at), isNull);
    }
    final legacy = HourlyWeatherItem.fromJson(
        {'forecastAt': at, 'precipitationAmount': 3});
    expect(legacy.precipitationPeriodProvided, isFalse);
    expect(legacy.precipitationPeriod, isNull);
    expect(legacy.precipitationAmount, 3);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('좁은 화면 배율 $scale 에서 정시/강수 구간·범위값을 따로 표시한다', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, [_slot(dateInKorea(DateTime.now()), 15)],
          scale: scale);
      expect(find.text('15시'), findsOneWidget);
      expect(find.text('14~15시 강수 예보'), findsOneWidget);
      expect(find.text('예상 기온 22℃'), findsOneWidget);
      expect(find.text('예상 체감 22℃'), findsOneWidget);
      expect(find.text('정시 예보'), findsNothing);
      expect(find.text('강수량 1mm 미만'), findsOneWidget);
      expect(find.text('바람 2.0m/s'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('오늘의 마지막 강수 구간은 유지하되 내일 00시의 기온은 섞지 않는다', (tester) async {
    final now = DateTime.now();
    final today = dateInKorea(now);
    final tomorrow = dateInKorea(now.add(const Duration(days: 1)));
    await _pump(tester, [
      _slot(today, 23),
      {..._slot(tomorrow, 0), 'temperature': 99}
    ]);
    expect(find.text('23시'), findsOneWidget);
    expect(find.text('23~24시 강수 예보'), findsOneWidget);
    expect(find.text('00시'), findsNothing);
    expect(find.text('예상 기온 99℃'), findsNothing);
    expect(find.text('바람 2.0m/s'), findsOneWidget);
  });

  testWidgets('내일 00시가 명시적인 무강수이면 빈 23~24시 행을 만들지 않는다', (tester) async {
    final now = DateTime.now();
    final today = dateInKorea(now);
    final tomorrow = dateInKorea(now.add(const Duration(days: 1)));
    await _pump(tester, [
      _slot(today, 23),
      {
        ..._slot(tomorrow, 0),
        'precipitationProbability': 0,
        'precipitationAmountRange': {
          'type': 'NONE',
          'min': 0,
          'max': 0,
          'unit': 'MM'
        },
        'skyCondition': '맑음'
      }
    ]);
    expect(find.text('23시'), findsOneWidget);
    expect(find.text('23~24시 강수 예보'), findsNothing);
    expect(find.text('00시'), findsNothing);
  });

  testWidgets('오늘 00시 기온은 표시해도 어제 23~24시 강수는 오늘에 섞지 않는다', (tester) async {
    await _pump(tester, [_slot(dateInKorea(DateTime.now()), 0)]);
    expect(find.text('00시'), findsOneWidget);
    expect(find.text('예상 기온 22℃'), findsOneWidget);
    expect(find.text('23~24시 강수 예보'), findsNothing);
    expect(find.text('강수량 1mm 미만'), findsNothing);
  });

  testWidgets('구간을 모르는 새 응답은 강수 코드값을 mm로 노출하지 않는다', (tester) async {
    await _pump(tester, [
      {..._slot(dateInKorea(DateTime.now()), 15), 'precipitationPeriod': null}
    ]);
    expect(find.text('강수 적용 구간을 확인하기 어려워요'), findsOneWidget);
    expect(find.text('강수량 1mm 미만'), findsNothing);
    expect(find.text('예상 기온 22℃'), findsOneWidget);
  });
}

Map<String, dynamic> _slot(String date, int hour) {
  final at = '$date' 'T${hour.toString().padLeft(2, '0')}:00:00+09:00';
  return {
    'forecastAt': at,
    'temperature': 22,
    'apparentTemperature': 22,
    'precipitationPeriod': {
      'start': DateTime.parse(at)
          .subtract(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
      'end': at
    },
    'precipitationProbability': 80,
    'precipitationAmount': 0,
    'precipitationAmountRange': {
      'type': 'LESS_THAN',
      'min': 0,
      'max': 1,
      'unit': 'MM'
    },
    'snowExpected': false,
    'snowfallAmount': 0,
    'windSpeed': 2,
    'skyCondition': '비'
  };
}

Future<void> _pump(WidgetTester tester, List<Map<String, dynamic>> hourly,
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
  ))));
}
