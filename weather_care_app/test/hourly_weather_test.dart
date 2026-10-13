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

  test('시간별 기상청 체감온도만 표시한다', () {
    final item = HourlyWeatherItem.fromJson({
      'forecastAt': '2026-09-22T15:00:00+09:00',
      'apparentTemperature': 27.2,
      'kmaApparentTemperature': 26.9,
    });

    expect(item.apparentTemperature, 27.2);
    expect(item.kmaApparentTemperature, 26.9);
    expect(item.displayedApparentTemperature, 26.9);
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
      '날씨 —',
      '—',
      '(체감 —)',
    ]) {
      expect(
          find.descendant(of: row, matching: find.text(text)), findsOneWidget);
    }
    await _selectHourly(tester, 'precipitation');
    expect(find.text('—'), findsOneWidget);
    expect(find.text('강수량 —'), findsOneWidget);
    await _selectHourly(tester, 'wind');
    expect(find.text('방향 —'), findsOneWidget);
    for (final text in [
      '맑음',
      '0°C',
      '(체감 0°C)',
      '0%',
      '강수량 0mm',
      '0.0m/s',
      '눈 없음',
      '체감 미지원'
    ]) {
      expect(find.descendant(of: row, matching: find.text(text)), findsNothing);
    }
    expect(find.textContaining('오류가 있어'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('0도·무풍·자외선 0과 명시된 무강수는 구분해 표시한다', (tester) async {
    await _pumpHourly(tester, [_zero]);
    final row = find.byKey(const ValueKey('today-hourly-0'));
    expect(find.descendant(of: row, matching: find.text('0°C')),
        findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('(체감 0°C)')),
        findsOneWidget);
    await _selectHourly(tester, 'precipitation');
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('강수량 0mm'), findsOneWidget);
    expect(find.textContaining('신적설'), findsNothing);
    await _selectHourly(tester, 'wind');
    expect(find.text('0.0m/s'), findsOneWidget);
    await _selectHourly(tester, 'uv');
    expect(find.text('0'), findsOneWidget);
    expect(find.text('—'), findsNothing);
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
    await _selectHourly(tester, 'precipitation');
    expect(find.descendant(of: row, matching: find.text('강수량 0mm')),
        findsOneWidget);
    expect(find.text('예상 신적설 0cm'), findsNothing);
    expect(find.text('20%'), findsOneWidget);
  });

  testWidgets('일부 강수자료만 있을 때 다른 값을 보충하지 않는다', (tester) async {
    await _pumpHourly(tester, [
      {'time': '14', 'precipitationAmount': 2.5},
      {'time': '15', 'precipitationProbability': 80, 'snowExpected': true},
    ]);
    await _selectHourly(tester, 'precipitation');
    expect(find.text('강수량 2.5mm'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('신적설 —'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.text('강수량 0mm'), findsNothing);
    expect(find.text('예상 신적설 0cm'), findsNothing);
    expect(find.text('강수량 —'), findsOneWidget);
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
      expect(
          find.byKey(const ValueKey('today-hourly-timeline')), findsOneWidget);
      await _selectHourly(tester, 'precipitation');
      for (final text in [
        '80%',
        '강수량 1mm 미만',
        '신적설 0.5cm 미만',
        '강수량 30~50mm',
        '신적설 5cm 이상'
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('강수량 1mm'), findsNothing);
      expect(find.text('예상 신적설 0.5cm'), findsNothing);
      expect(find.byKey(const ValueKey('today-hourly-filter-airQuality')),
          findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('빈 시간별 예보는 0 값의 행을 만들지 않는다', (tester) async {
    await _pumpHourly(tester, []);
    expect(find.byKey(const ValueKey('today-hourly-0')), findsNothing);
    expect(find.text('타임라인 자료가 없어 표시하기 어려워요.'), findsOneWidget);
  });

  testWidgets('선택한 시간별 지표는 가로로 넘기며 바꿔 볼 수 있다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpHourly(tester, [
      {..._zero, 'humidity': 60},
      {
        ..._zero,
        'time': '15',
        'humidity': 70,
        'precipitationProbability': 80,
        'precipitationAmount': 2,
      },
      {..._zero, 'time': '16', 'humidity': 75},
    ]);

    final timeline = find.byKey(const ValueKey('today-hourly-timeline'));
    await _selectHourly(tester, 'humidity');
    expect(find.text('60%'), findsOneWidget);
    await tester.drag(timeline, const Offset(-240, 0));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: timeline, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.pixels, greaterThan(0));
    expect(find.text('15시'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    await _selectHourly(tester, 'precipitation');
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('강수량 2mm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('타임라인 선택 버튼은 한 줄이고 값은 아이콘과 함께 표시한다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpHourly(tester, [
      {
        ..._zero,
        'temperature': 20,
        'apparentTemperature': 19,
        'precipitationProbability': 10,
        'humidity': 25,
        'windDirection': 90,
        'uvIndex': 2
      },
      {..._zero, 'time': '15', 'humidity': 75, 'uvIndex': 9},
    ]);

    final chips = [
      for (final metric in [
        'weather',
        'precipitation',
        'uv',
        'wind',
        'humidity',
      ])
        find.byKey(ValueKey('today-hourly-filter-$metric')),
    ];
    for (final chip in chips.skip(1)) {
      expect(tester.getTopLeft(chip).dy, tester.getTopLeft(chips[0]).dy);
    }
    expect(find.byKey(const ValueKey('today-hourly-filter-airQuality')),
        findsNothing);
    expect(find.text('20°C'), findsOneWidget);
    final apparent = find.text('(체감 19°C)');
    expect(apparent, findsOneWidget);
    expect(tester.widget<Text>(apparent).style?.fontWeight, isNot(FontWeight.w800));

    await _selectHourly(tester, 'precipitation');
    final first = find.byKey(const ValueKey('today-hourly-0'));
    expect(
        find.descendant(of: first, matching: find.text('10%')), findsOneWidget);
    expect(find.descendant(
        of: first,
        matching: find.byKey(const ValueKey('today-hourly-precipitation-icon'))),
        findsOneWidget);
    expect(find.descendant(of: first, matching: find.byIcon(Icons.water_drop)),
        findsNothing);
    expect(find.descendant(of: first, matching: find.text('강수량 0mm')),
        findsOneWidget);

    await _selectHourly(tester, 'uv');
    final lowSun = tester.widget<Icon>(find.descendant(
        of: first, matching: find.byIcon(Icons.wb_sunny_rounded)));
    final highSun = tester.widget<Icon>(find.descendant(
        of: find.byKey(const ValueKey('today-hourly-1')),
        matching: find.byIcon(Icons.wb_sunny_rounded)));
    expect(lowSun.color, isNot(Colors.red));
    expect(highSun.color, Colors.red);
    expect(
        find.descendant(of: first, matching: find.text('2')), findsOneWidget);

    await _selectHourly(tester, 'wind');
    expect(find.descendant(of: first, matching: find.text('0.0m/s')),
        findsOneWidget);
    expect(
        find.descendant(of: first, matching: find.text('동풍')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.byIcon(Icons.air_rounded)),
        findsOneWidget);
    expect(find.byKey(const ValueKey('today-hourly-wind-direction-icon')),
        findsNothing);

    await _selectHourly(tester, 'humidity');
    expect(
        find.descendant(of: first, matching: find.text('25%')), findsOneWidget);
    final lowHumidity = tester.widget<Text>(
        find.descendant(of: first, matching: find.text('25%')));
    final highHumidity = tester.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('today-hourly-1')),
        matching: find.text('75%')));
    expect(lowHumidity.style?.color, isNot(highHumidity.style?.color));
    expect(tester.getCenter(find.descendant(of: first, matching: find.text('25%'))).dy,
        closeTo(tester.getCenter(find.descendant(
                of: first,
                matching: find.byKey(const ValueKey('today-hourly-humidity-icon')))).dy + 5, 2));
    expect(
        find.descendant(
            of: first,
            matching: find.byWidgetPredicate((widget) =>
                widget is Semantics && widget.properties.label == '습도 25% 채움')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('today-hourly-1')),
            matching: find.byWidgetPredicate((widget) =>
                widget is Semantics && widget.properties.label == '습도 75% 채움')),
        findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpHourly(tester, [_zero], scale: 2);
    for (final chip in chips.skip(1)) {
      expect(tester.getTopLeft(chip).dy, tester.getTopLeft(chips[0]).dy);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('타임라인 안내는 느낌표 버튼의 팝업에서만 보인다', (tester) async {
    await _pumpHourly(tester, [_zero]);
    expect(find.textContaining('기온·바람은 정시 값'), findsNothing);
    expect(find.byKey(const ValueKey('today-hourly-visibility-notice')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('today-hourly-info')));
    await tester.pumpAndSettle();
    expect(find.textContaining('기온·바람은 정시 값'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-hourly-visibility-notice')),
        findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-hourly-visibility-notice')),
        findsNothing);
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
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
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

Future<void> _selectHourly(WidgetTester tester, String metric) async {
  final chip = find.byKey(ValueKey('today-hourly-filter-$metric'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}
