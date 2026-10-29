import 'package:weather_care/features/home/widgets/hourly_value_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/widgets/hourly_forecast_section.dart';
import 'package:weather_care/models/precipitation.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/utils/korea_date.dart';

void main() {
  for (final inline in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('양·확률은 구간 중앙, 구간 시간은 숨기고 자정·누락 시간 유지: Week $inline 배율 $scale',
          (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: SingleChildScrollView(
                        child: HourlyForecastSection(
                            targetDate: '2026-12-31',
                            now: DateTime.parse('2026-12-31T14:00:00+09:00'),
                            inline: inline,
                            availableOnly: inline,
                            items: [
                          for (final slot in [
                            _slot('2026-12-31', 15),
                            _slot('2026-12-31', 17),
                            _slot('2027-01-01', 0),
                          ])
                            HourlyWeatherItem.fromJson(slot),
                        ]))))));
        for (final metric in ['precipitation', 'snowfall']) {
          await _selectHourly(tester, metric);
          final chart =
              tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
          final id = metric == 'precipitation' ? 'rain' : 'snow';
          final probability = _series(tester, '$id-probability');
          final index = inline ? 0 : 14;
          final last = inline ? 2 : 23;
          expect(probability.intervals, isTrue);
          expect(chart.series.intervals, isTrue);
          final amountRect = tester
              .getRect(find.byKey(ValueKey('hourly-value-$id-amount-$index')));
          final probabilityRect = tester.getRect(
              find.byKey(ValueKey('hourly-value-$id-probability-$index')));
          final paintFinder = find.byKey(ValueKey('hourly-chart-$id-amount'));
          final origin = tester.getTopLeft(paintFinder);
          final painter = tester.widget<CustomPaint>(paintFinder).painter!
              as HourlyValueChartPainter;
          final anchorX = origin.dx +
              (chart.hours[index] - chart.hours.first + .5) * chart.pointWidth;
          for (final rect in [amountRect, probabilityRect]) {
            expect((rect.center.dx - anchorX).abs(),
                lessThanOrEqualTo(chart.pointWidth / 2));
            if ((rect.center.dx - anchorX).abs() > 1) {
              expect(
                  painter.leaders.any((leader) =>
                      (leader.$1.dx + origin.dx - anchorX).abs() < .1),
                  isTrue);
            }
          }
          final point = find.byKey(ValueKey('today-hourly-$index'));
          final clock = find.descendant(
              of: point,
              matching: find.byKey(const ValueKey('hourly-probability-time')));
          expect(tester.widget<Text>(clock).data, '15시');
          expect(tester.getCenter(clock).dx,
              closeTo(anchorX + chart.pointWidth / 2, .1));
          expect(find.text('14~15시'), findsNothing);
          final midnight = find.descendant(
              of: find.byKey(ValueKey('today-hourly-$last')),
              matching: find.byKey(const ValueKey('hourly-probability-time')));
          expect(tester.widget<Text>(midnight).data, '24시');
          expect(find.text('23~24시'), findsNothing);
          expect(find.text('24시'), findsOneWidget);
          expect(chart.hours.last - chart.hours.first, inline ? 9 : 23);
          final canvas =
              tester.getRect(find.byKey(ValueKey('hourly-chart-$id-amount')));
          final lastLabel = tester.getRect(
              find.byKey(ValueKey('hourly-value-$id-probability-$last')));
          expect(lastLabel.right, lessThanOrEqualTo(canvas.right));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

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
      expect(
          _series(tester, 'temperature')
              .values
              .whereType<HourlyChartValue>()
              .map((value) => value.lower),
          contains(22));
      expect(
          _series(tester, 'apparent')
              .values
              .whereType<HourlyChartValue>()
              .map((value) => value.lower),
          contains(22));
      expect(find.text('정시 예보'), findsNothing);
      await _selectHourly(tester, 'precipitation');
      expect(find.text('14~15시'), findsNothing);
      expect(find.text('15시'), findsOneWidget);
      expect(find.text('1mm 미만'), findsOneWidget);
      await _selectHourly(tester, 'wind');
      expect(find.text('방향 — · 2.0m/s'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('오늘의 마지막 강수 구간은 유지하고 내일 기온은 제외한다', (tester) async {
    final now = DateTime.now();
    final today = dateInKorea(now);
    final tomorrow = dateInKorea(now.add(const Duration(days: 1)));
    await _pump(tester, [
      _slot(today, 23),
      {..._slot(tomorrow, 0), 'temperature': 99}
    ]);
    expect(find.text('23시'), findsOneWidget);
    expect(find.text('00시'), findsOneWidget);
    expect(find.text('내일 00시'), findsNothing);
    expect(find.text('99°C'), findsNothing);
    expect(
        _series(tester, 'apparent')
            .values
            .whereType<HourlyChartValue>()
            .map((value) => value.lower),
        contains(22));
    await _selectHourly(tester, 'precipitation');
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('today-hourly-23')),
            matching: find.text('24시')),
        findsOneWidget);
    await _selectHourly(tester, 'wind');
    expect(find.text('방향 — · 2.0m/s'), findsOneWidget);
  });

  testWidgets('내일 00시만 있어도 오늘 마지막 강수 구간을 표시한다', (tester) async {
    final tomorrow = dateInKorea(DateTime.now().add(const Duration(days: 1)));
    await _pump(tester, [_slot(tomorrow, 0)]);
    expect(find.text('내일 00시'), findsNothing);
    expect(
        _series(tester, 'temperature')
            .values
            .whereType<HourlyChartValue>()
            .map((value) => value.lower),
        isNot(contains(22)));
    expect(
        _series(tester, 'apparent')
            .values
            .whereType<HourlyChartValue>()
            .map((value) => value.lower),
        isNot(contains(22)));
    expect(find.byKey(const ValueKey('today-hourly-23')), findsOneWidget);
    await _selectHourly(tester, 'precipitation');
    expect(find.text('23~24시'), findsNothing);
    expect(find.text('24시'), findsOneWidget);
    expect(find.text('1mm 미만'), findsOneWidget);
    await _selectHourly(tester, 'snowfall');
    expect(find.text('23~24시'), findsNothing);
    expect(find.text('24시'), findsOneWidget);
    expect(find.text('0cm'), findsOneWidget);
  });

  testWidgets('24개 정시 뒤의 오늘 마지막 강수 구간도 강수 항목에 남긴다', (tester) async {
    final now = DateTime.now();
    final today = dateInKorea(now);
    final tomorrow = dateInKorea(now.add(const Duration(days: 1)));
    await _pump(tester, [
      for (var hour = 0; hour < 24; hour++) _slot(today, hour),
      _slot(tomorrow, 0),
    ]);
    expect(find.byKey(const ValueKey('today-hourly-24')), findsNothing);
    await _selectHourly(tester, 'precipitation');
    expect(find.byKey(const ValueKey('today-hourly-24')), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('today-hourly-23')),
            matching: find.text('24시')),
        findsOneWidget);
  });

  testWidgets('내일 00시가 명시적인 무강수이면 23~24시를 0으로 표시한다', (tester) async {
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
    await _selectHourly(tester, 'precipitation');
    expect(find.text('23~24시'), findsNothing);
    expect(find.text('24시'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('00시'), findsOneWidget);
  });

  testWidgets('Main으로 옮긴 타임라인도 오늘 마지막 강수 구간을 유지한다', (tester) async {
    final now = DateTime.now();
    final today = dateInKorea(now);
    final tomorrow = dateInKorea(now.add(const Duration(days: 1)));
    final hourly = TodayWeatherResponse.fromJson({
      'hourly': [
        for (var hour = 0; hour < 24; hour++) _slot(today, hour),
        _slot(tomorrow, 0),
      ],
    }).hourly;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(
        body: HourlyForecastSection(items: hourly, now: now, keyPrefix: 'main'),
      ),
    ));
    expect(find.byKey(const ValueKey('main-hourly-24')), findsNothing);
    tester
        .widget<ChoiceChip>(
            find.byKey(const ValueKey('main-hourly-filter-precipitation')))
        .onSelected!(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-hourly-24')), findsNothing);
    expect(find.byKey(const ValueKey('main-hourly-23')), findsOneWidget);
    expect(find.text('23~24시'), findsNothing);
    expect(find.text('24시'), findsOneWidget);
    expect(find.text('1mm 미만'), findsNWidgets(24));
  });

  testWidgets('오늘 00시 기온은 표시해도 어제 23~24시 강수는 오늘에 섞지 않는다', (tester) async {
    await _pump(tester, [_slot(dateInKorea(DateTime.now()), 0)]);
    expect(find.text('00시'), findsOneWidget);
    expect(
        _series(tester, 'temperature')
            .values
            .whereType<HourlyChartValue>()
            .map((value) => value.lower),
        contains(22));
    expect(
        _series(tester, 'apparent')
            .values
            .whereType<HourlyChartValue>()
            .map((value) => value.lower),
        contains(22));
    await _selectHourly(tester, 'precipitation');
    expect(find.text('23~24시'), findsNothing);
    expect(find.text('1mm 미만'), findsNothing);
  });

  testWidgets('기기 날짜가 하루 느려도 응답 시각의 오늘 예보를 표시한다', (tester) async {
    final receivedAt = DateTime.parse('2026-10-01T10:00:00Z');
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(
        body: HourlyForecastSection(
          items: [
            HourlyWeatherItem.fromJson(_slot('2026-10-01', 15)),
            HourlyWeatherItem.fromJson(_slot('2026-10-02', 15)),
          ],
          generatedAt: '2026-10-02T02:00:00Z',
          receivedAt: receivedAt,
          now: receivedAt,
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('today-hourly-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-hourly-23')), findsOneWidget);
    expect(_series(tester, 'temperature').values[15]?.lower, 22);
    await _selectHourly(tester, 'precipitation');
    expect(find.text('14~15시'), findsNothing);
    expect(find.text('15시'), findsOneWidget);
  });

  testWidgets('구간을 모르는 새 응답은 강수 코드값을 mm로 노출하지 않는다', (tester) async {
    await _pump(tester, [
      {..._slot(dateInKorea(DateTime.now()), 15), 'precipitationPeriod': null}
    ]);
    expect(
        _series(tester, 'temperature')
            .values
            .whereType<HourlyChartValue>()
            .map((value) => value.lower),
        contains(22));
    expect(
        _series(tester, 'apparent')
            .values
            .whereType<HourlyChartValue>()
            .map((value) => value.lower),
        contains(22));
    await _selectHourly(tester, 'precipitation');
    expect(find.text('강수 구간 —'), findsOneWidget);
    expect(find.text('1mm 미만'), findsNothing);
    await _selectHourly(tester, 'snowfall');
    expect(find.text('강설 구간 —'), findsOneWidget);
    expect(find.text('0cm'), findsNothing);
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
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
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

Future<void> _selectHourly(WidgetTester tester, String metric) async {
  final chip = find.byKey(ValueKey('today-hourly-filter-$metric'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

HourlyChartSeries _series(WidgetTester tester, String id) => tester
    .widgetList<HourlyValueChart>(find.byType(HourlyValueChart))
    .expand((chart) => [chart.series, ...chart.overlays])
    .singleWhere((chart) => chart.id == id);
