import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/widgets/hourly_forecast_section.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/theme/weather_theme.dart';

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

  test('당일 지난 시간 자료는 미래 예보와 별도로 읽는다', () {
    final response = TodayWeatherResponse.fromJson({
      'hourly': [
        {..._zero, 'time': '16'},
      ],
      'timelineHourly': [
        {..._zero, 'time': '00', 'temperature': 18},
        {..._zero, 'time': '16'},
      ],
    });
    expect(response.hourly.map((item) => item.time), ['16']);
    expect(response.timelineHourly?.map((item) => item.time), ['00', '16']);
    expect(response.withRegionName('서울').timelineHourly?.first.temperature, 18);
    expect(
        TodayWeatherResponse.fromJson({'hourly': []}).timelineHourly, isNull);
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
      '00시',
      '날씨 —',
      '—',
      '(체감 —)',
    ]) {
      expect(
          find.descendant(of: row, matching: find.text(text)), findsOneWidget);
    }
    await _selectHourly(tester, 'precipitation');
    expect(
        find.descendant(of: row, matching: find.text('—')), findsNWidgets(2));
    await _selectHourly(tester, 'wind');
    expect(find.descendant(of: row, matching: find.text('방향 — · —')),
        findsOneWidget);
    for (final text in [
      '맑음',
      '0°C',
      '(체감 0°C)',
      '0%',
      '0mm',
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
    final row = find.byKey(const ValueKey('today-hourly-14'));
    expect(
        find.descendant(of: row, matching: find.text('0°C')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('(체감 0°C)')),
        findsOneWidget);
    await _selectHourly(tester, 'precipitation');
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0mm'), findsOneWidget);
    expect(find.textContaining('신적설'), findsNothing);
    await _selectHourly(tester, 'snowfall');
    expect(find.text('눈 예보 없음'), findsOneWidget);
    expect(find.text('신적설 0cm'), findsOneWidget);
    await _selectHourly(tester, 'wind');
    expect(find.text('약한 바람'), findsOneWidget);
    expect(find.text('방향 — · 0.0m/s'), findsOneWidget);
    await _selectHourly(tester, 'uv');
    expect(find.text('0'), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('—')), findsNothing);
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
    final row = find.byKey(const ValueKey('today-hourly-14'));
    await _selectHourly(tester, 'precipitation');
    expect(
        find.descendant(of: row, matching: find.text('0mm')), findsOneWidget);
    expect(find.text('예상 신적설 0cm'), findsNothing);
    expect(find.text('20%'), findsOneWidget);
  });

  testWidgets('일부 강수자료만 있을 때 다른 값을 보충하지 않는다', (tester) async {
    await _pumpHourly(tester, [
      {'time': '14', 'precipitationAmount': 2.5},
      {'time': '15', 'precipitationProbability': 80, 'snowExpected': true},
    ]);
    await _selectHourly(tester, 'precipitation');
    expect(find.text('2.5mm'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.textContaining('신적설'), findsNothing);
    await _selectHourly(tester, 'snowfall');
    expect(find.text('눈 예상'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('today-hourly-15')),
            matching: find.text('신적설 —')),
        findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.text('0mm'), findsNothing);
    expect(find.text('예상 신적설 0cm'), findsNothing);
    expect(find.text('신적설 —'), findsWidgets);
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
        '1mm 미만',
        '30~50mm',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.textContaining('신적설'), findsNothing);
      await _selectHourly(tester, 'snowfall');
      expect(find.text('신적설 0.5cm 미만'), findsOneWidget);
      expect(find.text('신적설 5cm 이상'), findsOneWidget);
      expect(find.text('1mm'), findsNothing);
      expect(find.text('예상 신적설 0.5cm'), findsNothing);
      expect(find.byKey(const ValueKey('today-hourly-filter-airQuality')),
          findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('빈 시간별 예보도 오늘 00~23시를 결측으로 표시한다', (tester) async {
    await _pumpHourly(tester, []);
    expect(find.byKey(const ValueKey('today-hourly-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-hourly-23')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-hourly-24')), findsNothing);
    expect(find.text('00시'), findsOneWidget);
    expect(find.text('23시'), findsOneWidget);
    expect(find.text('0°C'), findsNothing);
    expect(find.text('타임라인 자료가 없어 표시하기 어려워요.'), findsOneWidget);
  });

  testWidgets('자료가 갱신되면 현재 시간으로 스크롤하고 지난 시간도 볼 수 있다', (tester) async {
    final now = DateTime.parse('2026-10-13T06:30:00Z'); // 한국 15시 30분
    await _pumpHourly(tester, [], now: now, keyPrefix: 'main');
    final timeline = find.byKey(const ValueKey('main-hourly-timeline'));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: timeline, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.pixels, greaterThan(0));

    await _pumpHourly(
        tester,
        [
          {
            ..._zero,
            'time': '00',
            'forecastDate': '2026-10-13',
            'temperature': 18
          },
          {
            ..._zero,
            'time': '01',
            'forecastDate': '2026-10-13',
            'temperature': 17
          },
          {..._zero, 'time': '16', 'forecastDate': '2026-10-13'},
        ],
        now: now,
        keyPrefix: 'main');
    await tester.pump();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(find.byKey(const ValueKey('main-hourly-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('main-hourly-23')), findsOneWidget);
    expect(find.text('18°C'), findsOneWidget);
    expect(find.text('17°C'), findsOneWidget);

    await tester.drag(timeline, const Offset(16 * 120, 0));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, lessThan(15 * 120));
    expect(find.text('00시'), findsOneWidget);
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
      {..._zero, 'time': '17', 'humidity': 80},
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
    expect(find.text('2mm'), findsOneWidget);
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
        'snowfall',
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
    expect(tester.getSize(find.byKey(const ValueKey('today-hourly-0'))).width,
        120);
    final apparent = find.text('(체감 19°C)');
    expect(apparent, findsOneWidget);
    expect(tester.widget<Text>(apparent).style?.fontWeight,
        isNot(FontWeight.w800));

    await _selectHourly(tester, 'precipitation');
    final first = find.byKey(const ValueKey('today-hourly-14'));
    expect(tester.getSize(first).width, 100);
    expect(
        find.descendant(of: first, matching: find.text('10%')), findsOneWidget);
    expect(
        find.descendant(
            of: first,
            matching:
                find.byKey(const ValueKey('today-hourly-precipitation-icon'))),
        findsOneWidget);
    expect(find.descendant(of: first, matching: find.byIcon(Icons.water_drop)),
        findsNothing);
    expect(
        find.descendant(of: first, matching: find.text('0mm')), findsOneWidget);
    final rainIcon = find.descendant(
        of: first,
        matching:
            find.byKey(const ValueKey('today-hourly-precipitation-icon')));
    expect(tester.widget<CustomPaint>(rainIcon).size, const Size(36, 36));
    expect(
        tester
            .getCenter(find.descendant(of: first, matching: find.text('10%')))
            .dy,
        closeTo(tester.getCenter(rainIcon).dy + 6, 1));
    expect(
        tester
            .widget<Text>(
                find.descendant(of: first, matching: find.text('0mm')))
            .style
            ?.fontSize,
        10);

    await _selectHourly(tester, 'uv');
    final lowSun = tester.widget<Icon>(find.descendant(
        of: first, matching: find.byIcon(Icons.wb_sunny_rounded)));
    final highSun = tester.widget<Icon>(find.descendant(
        of: find.byKey(const ValueKey('today-hourly-15')),
        matching: find.byIcon(Icons.wb_sunny_rounded)));
    expect(lowSun.color, isNot(Colors.red));
    expect(highSun.color, Colors.red);
    expect(
        find.descendant(of: first, matching: find.text('2')), findsOneWidget);
    expect(
        find.descendant(of: first, matching: find.text('낮음')), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.descendant(of: first, matching: find.text('낮음')))
            .style
            ?.fontSize,
        10);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('today-hourly-15')),
            matching: find.text('매우 높음')),
        findsOneWidget);
    expect(
        tester
            .widget<Text>(find.descendant(of: first, matching: find.text('2')))
            .style
            ?.fontSize,
        13);
    expect(
        tester.getSize(find.descendant(
            of: first,
            matching: find.byKey(const ValueKey('today-hourly-uv-center')))),
        const Size(22, 22));

    await _selectHourly(tester, 'wind');
    expect(find.descendant(of: first, matching: find.text('약한 바람')),
        findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('동풍 · 0.0m/s')),
        findsOneWidget);
    final windValue = tester
        .widget<Text>(find.descendant(of: first, matching: find.text('약한 바람')));
    final windSpeed = tester.widget<Text>(
        find.descendant(of: first, matching: find.text('동풍 · 0.0m/s')));
    expect(windValue.style?.fontSize,
        Theme.of(tester.element(first)).textTheme.labelMedium?.fontSize);
    expect(windSpeed.style?.fontSize, 10);
    expect(find.descendant(of: first, matching: find.byIcon(Icons.air_rounded)),
        findsOneWidget);
    expect(find.byKey(const ValueKey('today-hourly-wind-direction-icon')),
        findsNothing);

    await _selectHourly(tester, 'humidity');
    expect(
        find.descendant(of: first, matching: find.text('건조')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('today-hourly-15')),
            matching: find.text('습한 편')),
        findsOneWidget);
    expect(
        find.descendant(of: first, matching: find.text('25%')), findsOneWidget);
    final lowHumidity = tester
        .widget<Text>(find.descendant(of: first, matching: find.text('25%')));
    final highHumidity = tester.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('today-hourly-15')),
        matching: find.text('75%')));
    final palette = WeatherCareTheme.of(tester.element(first));
    expect(lowHumidity.style?.color, palette.textPrimary);
    expect(highHumidity.style?.color, palette.onPrimary);
    expect(lowHumidity.style?.fontSize, 10);
    final humidityPaint =
        find.descendant(of: first, matching: find.byType(CustomPaint)).last;
    expect(tester.widget<CustomPaint>(humidityPaint).size, const Size(40, 42));
    expect(
        tester
            .getTopLeft(find.descendant(of: first, matching: find.text('25%')))
            .dy,
        greaterThan(tester.getTopLeft(humidityPaint).dy));
    expect(
        tester
            .getBottomLeft(
                find.descendant(of: first, matching: find.text('25%')))
            .dy,
        lessThan(tester.getBottomLeft(humidityPaint).dy));
    expect(
        tester
            .getTopLeft(find.descendant(
                of: find.byKey(const ValueKey('today-hourly-15')),
                matching: find.text('75%')))
            .dy,
        greaterThan(tester
            .getTopLeft(find.descendant(of: first, matching: find.text('25%')))
            .dy));
    expect(
        find.descendant(
            of: first,
            matching: find.byWidgetPredicate((widget) =>
                widget is Semantics && widget.properties.label == '습도 25% 채움')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('today-hourly-15')),
            matching: find.byWidgetPredicate((widget) =>
                widget is Semantics && widget.properties.label == '습도 75% 채움')),
        findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpHourly(
        tester,
        [
          {..._zero, 'humidity': 75}
        ],
        scale: 2);
    for (final chip in chips.skip(1)) {
      expect(tester.getTopLeft(chip).dy, tester.getTopLeft(chips[0]).dy);
    }
    await _selectHourly(tester, 'humidity');
    expect(find.text('75%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('타임라인 바람 아이콘은 같은 모양으로 풍향에 따라 회전한다', (tester) async {
    await _pumpHourly(tester, [
      for (var index = 0; index < 5; index++)
        {
          ..._zero,
          'time': '${index + 14}',
          'windDirection': [0, 90, 180, 270, null][index],
        },
    ]);
    await _selectHourly(tester, 'wind');

    for (var index = 0; index < 5; index++) {
      final point = find.byKey(ValueKey('today-hourly-${index + 14}'));
      final windIcon = find.descendant(
        of: point,
        matching: find.byKey(const ValueKey('today-hourly-wind-icon')),
      );
      expect(windIcon, findsOneWidget);
      final icon = tester.widget<Icon>(find.descendant(
        of: windIcon,
        matching: find.byIcon(Icons.air_rounded),
      ));
      expect(icon.size, 30);
      final rotation = tester.widget<Transform>(windIcon).transform;
      final expected = switch (index) {
        0 => -1.0,
        2 => 1.0,
        _ => 0.0,
      };
      expect(rotation.entry(1, 0), closeTo(expected, 0.0001));
      if (index == 3) {
        expect(rotation.entry(0, 0), closeTo(-1, 0.0001));
      }
    }
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
    {double scale = 1, DateTime? now, String keyPrefix = 'today'}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: SingleChildScrollView(
          child: HourlyForecastSection(
            keyPrefix: keyPrefix,
            items: TodayWeatherResponse.fromJson({'hourly': hourly}).hourly,
            now: now,
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
