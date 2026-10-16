import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/features/home/widgets/hourly_forecast_section.dart';
import 'package:weather_care/features/home/widgets/hourly_value_chart.dart';
import 'package:weather_care/features/home/widgets/weather_condition_icon.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/timeline_order_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TimelineOrderStore.order.value = null;
  });

  test('12~2월은 겨울 순서, 나머지 달은 봄·여름·가을 순서다', () {
    for (var month = 1; month <= 12; month++) {
      expect(
          TimelineOrderStore.defaults(month),
          month == 12 || month <= 2
              ? [
                  'weather',
                  'snowfall',
                  'precipitation',
                  'wind',
                  'humidity',
                  'uv'
                ]
              : [
                  'weather',
                  'precipitation',
                  'humidity',
                  'uv',
                  'wind',
                  'snowfall'
                ]);
    }
  });

  test('손상되거나 중복된 저장 순서는 기본값으로 복구한다', () async {
    for (final saved in [
      <String>[],
      ['uv', 'uv'],
      ['weather', 'precipitation', 'humidity', 'uv', 'wind', 'unknown']
    ]) {
      SharedPreferences.setMockInitialValues(
          {TimelineOrderStore.storageKey: saved});
      await TimelineOrderStore.load();
      expect(TimelineOrderStore.order.value, isNull);
    }
  });

  testWidgets('순서 변경 저장·재진입·겨울 유지·기본 복원이 실제 표시와 저장소에 적용된다', (tester) async {
    await _pump(tester);
    expect(_chipOrder(tester), TimelineOrderStore.defaults(10));
    await tester.tap(find.byKey(const ValueKey('today-hourly-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('기온 아래로'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final custom = [
      'precipitation',
      'weather',
      'humidity',
      'uv',
      'wind',
      'snowfall'
    ];
    expect(_chipOrder(tester), custom);
    expect(
        (await SharedPreferences.getInstance())
            .getStringList(TimelineOrderStore.storageKey),
        custom);

    await tester.pumpWidget(const SizedBox.shrink());
    TimelineOrderStore.order.value = null; // 앱 재시작처럼 저장소에서 다시 읽는다.
    await _pump(tester, month: 12);
    expect(_chipOrder(tester), custom);
    await tester.tap(find.byKey(const ValueKey('today-hourly-order')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('계절별 기본 순서로 복원'));
    await tester.tap(find.text('계절별 기본 순서로 복원'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(_chipOrder(tester), TimelineOrderStore.defaults(12));
    expect(
        (await SharedPreferences.getInstance())
            .containsKey(TimelineOrderStore.storageKey),
        isFalse);
    await _pump(tester, month: 4);
    expect(_chipOrder(tester), TimelineOrderStore.defaults(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('순서 편집 취소는 표시와 저장값을 바꾸지 않는다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('today-hourly-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('기온 아래로'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(_chipOrder(tester), TimelineOrderStore.defaults(10));
    expect(
        (await SharedPreferences.getInstance())
            .containsKey(TimelineOrderStore.storageKey),
        isFalse);
  });

  testWidgets('시간 간격과 결측·기온 음수·체감온도 단독 자료를 유지한다', (tester) async {
    await _pump(tester, availableOnly: true, data: [
      {'time': '08', 'temperature': -7, 'apparentTemperature': -9},
      {'time': '11', 'temperature': null, 'apparentTemperature': -4},
    ]);
    final temperature = _graph(tester, 'temperature');
    expect(temperature.hours, [8, 11]);
    expect(temperature.series.values.map((value) => value?.lower), [-7, null]);
    expect(temperature.series.bounds.$1, lessThan(-7));
    expect(_series(tester, 'apparent').values.last?.lower, -4);
    expect(
        tester
            .widget<CustomPaint>(
                find.byKey(const ValueKey('hourly-chart-temperature')))
            .size
            .width,
        temperature.pointWidth * 4);
  });

  testWidgets('강설은 한 차트에서 양·확률을 구분하고 결측 확률을 만들지 않는다', (tester) async {
    await _pump(tester, data: [
      {
        'time': '08',
        'snowExpected': true,
        'snowfallAmount': 1.2,
        'precipitationProbability': 70
      },
      {
        'time': '09',
        'snowExpected': false,
        'snowfallAmount': 0,
        'precipitationProbability': 90
      },
      {'time': '10', 'snowExpected': true},
      {'time': '11', 'precipitationProbability': 80},
    ]);
    await _select(tester, 'snowfall');
    expect(_graph(tester, 'snow-amount').series.bars, isFalse);
    final probability = _series(tester, 'snow-probability');
    expect(probability.bars, isTrue);
    expect(probability.values.sublist(8, 12).map((value) => value?.lower),
        [70, 0, null, null]);
    expect(find.text('70%'), findsOneWidget);
    expect(find.byType(HourlyValueChart), findsOneWidget);
  });

  test('양의 범위를 중간값으로 바꾸지 않고 경계를 유지한다', () {
    final less = HourlyChartValue.amount(null, '1mm 미만')!;
    expect((less.lower, less.upper, less.range), (0, 1, true));
    final range = HourlyChartValue.amount(null, '30~50mm')!;
    expect((range.lower, range.upper, range.range), (30, 50, true));
    final atLeast = HourlyChartValue.amount(null, '5cm 이상')!;
    expect((atLeast.lower, atLeast.upper, atLeast.range), (5, null, true));
    final zero = HourlyChartValue.amount(null, '0cm')!;
    expect((zero.lower, zero.upper, zero.range), (0, 0, false));
    expect(HourlyChartValue.amount(null, null), isNull);
  });

  testWidgets('명시적으로 잘못된 강수 구간은 그래프에도 수치를 그리지 않는다', (tester) async {
    await _pump(tester, data: [
      {
        'time': '08',
        'precipitationPeriod': {},
        'precipitationProbability': 80,
        'precipitationAmount': 12,
      }
    ]);
    await _select(tester, 'precipitation');
    expect(
        _graph(tester, 'rain-amount')
            .series
            .values
            .whereType<HourlyChartValue>(),
        isEmpty);
    expect(
        _series(tester, 'rain-probability')
            .values
            .whereType<HourlyChartValue>(),
        isEmpty);
    expect(find.text('12mm'), findsNothing);
  });

  test('실제 그림에서도 빠진 시간과 결측 사이를 선으로 연결하지 않는다', () async {
    Future<int> alphaAtMiddle(
        List<int> hours, List<HourlyChartValue?> values) async {
      final recorder = ui.PictureRecorder();
      HourlyValueChartPainter(
        series: HourlyChartSeries(
            id: 'test', title: '검증', unit: '', values: values, fixedMax: 100),
        hours: hours,
        pointWidth: 100,
        color: Colors.black,
        gridColor: Colors.transparent,
      ).paint(Canvas(recorder),
          Size((hours.last - hours.first + 1) * 100, hourlyChartHeight));
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(400, 144);
      final bytes = (await rendered.toByteData())!.buffer.asUint8List();
      final row = hourlyChartY(50, (0.0, 100.0), 144).round();
      final alpha = bytes[(row * 400 + 100) * 4 + 3];
      rendered.dispose();
      picture.dispose();
      return alpha;
    }

    const value = HourlyChartValue(50, 50);
    expect(await alphaAtMiddle([8, 9], [value, value]), greaterThan(0));
    expect(await alphaAtMiddle([8, 11], [value, value]), 0);
    expect(await alphaAtMiddle([8, 9, 10], [value, null, value]), 0);
  });

  testWidgets('순서 변경은 타이틀 아래 왼쪽, 안내 버튼은 같은 행의 오른쪽 끝에 표시한다', (tester) async {
    await _pump(tester);
    final order = find.byKey(const ValueKey('today-hourly-order'));
    final info = find.byKey(const ValueKey('today-hourly-info'));
    expect(tester.getTopLeft(order).dx,
        lessThan(tester.getTopLeft(find.text('타임라인')).dx));
    expect(tester.getTopLeft(order).dy,
        greaterThan(tester.getBottomLeft(find.text('타임라인')).dy));
    expect(tester.getCenter(order).dy, closeTo(tester.getCenter(info).dy, 1));
    expect(
        tester.getTopLeft(info).dx, greaterThan(tester.getTopRight(order).dx));
    final section = tester
        .getRect(find.byKey(const ValueKey('today-hourly-forecast-section')));
    expect(
        section.right - tester.getTopRight(info).dx, inInclusiveRange(8, 20));
    final icon = find.descendant(
        of: info, matching: find.byIcon(Icons.error_outline_rounded));
    expect(
        section.right - tester.getTopRight(icon).dx, inInclusiveRange(8, 20));
  });

  testWidgets('기온·체감은 같은 차트에서 각 점 아래에 수치를 상시 표시한다', (tester) async {
    await _pump(tester, data: [
      {
        'time': '08',
        'temperature': 20,
        'apparentTemperature': 10,
        'skyCondition': '맑음'
      },
      {
        'time': '09',
        'temperature': 22,
        'apparentTemperature': 11,
        'skyCondition': '흐림'
      },
    ]);
    final chart =
        tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
    expect(find.byType(HourlyValueChart), findsOneWidget);
    expect(chart.series.color, isNot(chart.overlays.single.color));
    expect(chart.sharedBounds, isNotNull);
    expect(chart.showValues, isTrue);
    expect(find.text('20°C'), findsOneWidget);
    expect(find.text('10°C'), findsOneWidget);
    final canvas =
        tester.getRect(find.byKey(const ValueKey('hourly-chart-temperature')));
    final painter = _graph(tester, 'temperature');
    final pointY = canvas.top +
        hourlyChartY(20, chart.sharedBounds!, chart.height,
            bottomPadding: painter.bottomPadding);
    final apparentY = canvas.top +
        hourlyChartY(10, chart.sharedBounds!, chart.height,
            bottomPadding: painter.bottomPadding);
    expect(
        tester
            .getTopLeft(
                find.byKey(const ValueKey('hourly-value-temperature-8')))
            .dy,
        greaterThan(pointY));
    expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('hourly-value-apparent-8')))
            .dy,
        greaterThan(apparentY));
    final icon = find.byWidgetPredicate(
        (widget) => widget is WeatherConditionIcon && widget.condition == '맑음');
    expect(pointY - tester.getCenter(icon).dy, inInclusiveRange(10, 40));
    expect(
        find.descendant(
            of: find.byType(HourlyValueChart), matching: find.byType(Tooltip)),
        findsNothing);
  });

  testWidgets('강수량·확률은 한 차트의 다른 색과 좌우 축을 쓰며 수치가 겹치지 않는다', (tester) async {
    await _pump(tester, data: [
      {'time': '08', 'precipitationAmount': 3, 'precipitationProbability': 60},
      {
        'time': '09',
        'precipitationAmount': 0.5,
        'precipitationProbability': 40
      },
    ]);
    await _select(tester, 'precipitation');
    expect(find.byType(HourlyValueChart), findsOneWidget);
    final chart =
        tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
    expect(chart.sharedBounds, isNull); // 단위가 다르므로 각 축으로 읽는다.
    expect(chart.series.color, isNot(chart.overlays.single.color));
    expect(chart.overlays.single.bars, isTrue);
    expect(
        tester
            .widgetList<HourlyChartAxis>(find.byType(HourlyChartAxis))
            .map((axis) => axis.series.unit),
        ['mm', '%']);
    final amount = tester
        .getRect(find.byKey(const ValueKey('hourly-value-rain-amount-9')));
    final probability = tester
        .getRect(find.byKey(const ValueKey('hourly-value-rain-probability-9')));
    expect(amount.overlaps(probability), isFalse);
    expect(find.text('0.5mm'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
  });

  testWidgets('습도·자외선은 높은 차트에 단계 범례와 그래프 수치를 표시한다', (tester) async {
    await _pump(tester, data: [
      {'time': '08', 'humidity': 82, 'uvIndex': 11}
    ]);
    for (final metric in ['humidity', 'uv']) {
      await _select(tester, metric);
      final chart =
          tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
      expect(chart.height, equals(400));
      await tester.tap(find.byKey(ValueKey('$metric-legend-toggle')));
      await tester.pumpAndSettle();
      final axis = find.byType(HourlyChartAxis);
      expect(
          find.descendant(
              of: axis,
              matching:
                  find.textContaining(metric == 'humidity' ? '매우 습함' : '위험')),
          findsNothing);
      expect(
          find.descendant(
              of: find.byType(HourlyChartLegend),
              matching:
                  find.textContaining(metric == 'humidity' ? '매우 습함' : '위험')),
          findsOneWidget);
      final value = find.byKey(ValueKey('hourly-value-$metric-8'));
      expect(value, findsOneWidget);
      final rect = tester.getRect(value);
      final canvas =
          tester.getRect(find.byKey(ValueKey('hourly-chart-$metric')));
      expect(rect.top, greaterThanOrEqualTo(canvas.top));
      expect(rect.bottom, lessThanOrEqualTo(canvas.bottom));
    }
  });

  testWidgets('습도는 큰 막대와 작은 막대 모두 위에 배경 없는 굵은 수치를 표시한다', (tester) async {
    const series = HourlyChartSeries(
        id: 'humidity',
        title: '습도',
        unit: '%',
        bars: true,
        fixedMax: 100,
        values: [HourlyChartValue(85, 85), HourlyChartValue(4, 4)]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
      alignment: Alignment.topLeft,
      child: HourlyValueChart(
          series: series,
          hours: const [8, 9],
          pointWidth: 120,
          height: 420,
          showValues: true),
    ))));
    final canvas =
        tester.getRect(find.byKey(const ValueKey('hourly-chart-humidity')));
    final large = find.byKey(const ValueKey('hourly-value-humidity-0'));
    final small = find.byKey(const ValueKey('hourly-value-humidity-1'));
    expect(tester.getBottomLeft(large).dy,
        lessThan(canvas.top + hourlyChartY(85, series.bounds, 420)));
    expect(tester.getBottomLeft(small).dy,
        lessThan(canvas.top + hourlyChartY(4, series.bounds, 420)));
    expect(tester.widget<Text>(large).style?.fontWeight, FontWeight.w900);
    expect(tester.widget<Text>(small).style?.fontWeight, FontWeight.w900);
    expect(
        find.descendant(
            of: find.byType(HourlyValueChart),
            matching: find.byType(DecoratedBox)),
        findsNothing);
  });

  for (final metric in ['precipitation', 'snowfall']) {
    testWidgets('$metric 확률은 모든 막대 위, 양은 선의 점 아래에 표시한다', (tester) async {
      await _pump(tester, scale: 2, data: [
        {
          'time': '08',
          'precipitationAmount': 3,
          'precipitationProbability': 85,
          'snowfallAmount': 1.5,
          'snowExpected': true
        },
        {
          'time': '09',
          'precipitationAmount': 1,
          'precipitationProbability': 3,
          'snowfallAmount': 0.2,
          'snowExpected': true
        },
        {
          'time': '10',
          'precipitationAmount': 0,
          'precipitationProbability': 0,
          'snowfallAmount': 0,
          'snowExpected': false
        },
        {
          'time': '11',
          'precipitationAmount': 2,
          'precipitationProbability': 100,
          'snowfallAmount': 1,
          'snowExpected': true
        },
      ]);
      await _select(tester, metric);
      expect(find.textContaining('범위 예보는 세로 구간으로 표시'), findsNothing);
      expect(find.textContaining('강설확률은 눈'), findsNothing);
      final prefix = metric == 'precipitation' ? 'rain' : 'snow';
      final chart =
          tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
      expect(chart.overlays.single.bars, isTrue);
      final canvas =
          tester.getRect(find.byKey(ValueKey('hourly-chart-$prefix-amount')));
      final padding = _graph(tester, '$prefix-amount').bottomPadding;
      for (var index = 8; index <= 11; index++) {
        final amount =
            find.byKey(ValueKey('hourly-value-$prefix-amount-$index'));
        final probability =
            find.byKey(ValueKey('hourly-value-$prefix-probability-$index'));
        final amountY = canvas.top +
            hourlyChartY(chart.series.values[index]!.lower, chart.series.bounds,
                chart.height,
                bottomPadding: padding);
        final probabilityY = canvas.top +
            hourlyChartY(chart.overlays.single.values[index]!.lower,
                chart.overlays.single.bounds, chart.height,
                bottomPadding: padding);
        expect(tester.getTopLeft(amount).dy, greaterThan(amountY));
        expect(
            tester.getBottomLeft(amount).dy,
            lessThan(tester
                .getTopLeft(find.byKey(ValueKey('today-hourly-$index')))
                .dy));
        expect(tester.getBottomLeft(probability).dy, lessThan(probabilityY));
        expect(tester.getTopLeft(probability).dy,
            greaterThanOrEqualTo(canvas.top));
        expect(tester.getRect(amount).overlaps(tester.getRect(probability)),
            isFalse);
        expect(tester.widget<Text>(probability).style?.fontWeight,
            FontWeight.w900);
      }
    });
  }

  testWidgets('자외선 수치는 단계색 해 아이콘과 같은 배경 안에 흰색 굵기로 표시한다', (tester) async {
    await _pump(tester, data: [
      for (var index = 0; index < 5; index++)
        {
          'time': '${index + 8}',
          'uvIndex': [2, 5, 7, 10, 11][index]
        }
    ]);
    await _select(tester, 'uv');
    final bands = _series(tester, 'uv').bands;
    for (var index = 0; index < 5; index++) {
      final text = tester
          .widget<Text>(find.byKey(ValueKey('hourly-value-uv-${index + 8}')));
      expect(text.style?.color, Colors.white);
      expect(text.style?.fontWeight, FontWeight.w900);
      final badge = find.ancestor(
          of: find.byKey(ValueKey('hourly-value-uv-${index + 8}')),
          matching: find.byType(HourlyUvIconValue));
      final background = tester.widget<Container>(
          find.descendant(of: badge, matching: find.byType(Container)));
      expect(
          (background.decoration as BoxDecoration).color, bands[index].color);
    }
    expect(find.byType(HourlyUvIconValue), findsNWidgets(5));
    expect(
        find.descendant(
            of: find.byType(HourlyValueChart),
            matching: find.byIcon(Icons.wb_sunny_rounded)),
        findsNWidgets(5));
    for (final badge in tester
        .widgetList<HourlyUvIconValue>(find.byType(HourlyUvIconValue))) {
      final center = tester.getCenter(find.byWidget(badge));
      final value = tester.getCenter(find.byKey(badge.valueKey));
      expect(value.dx, closeTo(center.dx, 1));
      expect(value.dy, closeTo(center.dy, 1));
    }
  });

  testWidgets('차트 좌우 여백·시간 간격을 줄이고 범례 아래와 세로 공간을 넓혔다', (tester) async {
    await _pump(tester, data: [
      {'time': '08', 'temperature': 20, 'apparentTemperature': 20.1},
      {'time': '09', 'temperature': 21, 'apparentTemperature': 21.1},
    ]);
    final chart =
        tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
    expect(chart.height, equals(320));
    expect(chart.pointWidth, lessThan(100));
    final section = tester
        .getRect(find.byKey(const ValueKey('today-hourly-forecast-section')));
    final viewport =
        tester.getRect(find.byKey(const ValueKey('today-hourly-timeline')));
    final canvas =
        tester.getRect(find.byKey(const ValueKey('hourly-chart-temperature')));
    expect(viewport.left - section.left, lessThan(60));
    expect(section.right - viewport.right, lessThan(16));
    expect(canvas.top - tester.getBottomLeft(find.text('체감온도')).dy,
        greaterThanOrEqualTo(32));
    final actual = tester
        .getRect(find.byKey(const ValueKey('hourly-value-temperature-8')));
    final apparent =
        tester.getRect(find.byKey(const ValueKey('hourly-value-apparent-8')));
    expect(actual.overlaps(apparent), isFalse);
  });

  testWidgets('2배 글씨의 영하·0도에서도 점 아래 두 온도가 겹치거나 시간 눈금에 닿지 않는다', (tester) async {
    await _pump(tester, scale: 2, data: [
      {'time': '08', 'temperature': 0, 'apparentTemperature': 0},
      {'time': '09', 'temperature': -10, 'apparentTemperature': -10},
    ]);
    for (final hour in [8, 9]) {
      final actual = tester
          .getRect(find.byKey(ValueKey('hourly-value-temperature-$hour')));
      final apparent =
          tester.getRect(find.byKey(ValueKey('hourly-value-apparent-$hour')));
      final clock = tester.getRect(find.byKey(ValueKey('today-hourly-$hour')));
      expect(actual.overlaps(apparent), isFalse);
      expect(apparent.bottom, lessThan(clock.top));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('범례 펼치기 글자의 위쪽 위치는 일반 범례와 같다', (tester) async {
    for (final scale in [1.0, 2.0]) {
      await _pump(tester, scale: scale, data: [
        {'time': '11', 'temperature': 20, 'humidity': 65, 'uvIndex': 5}
      ]);
      await _select(tester, 'weather');
      final legend = find.byType(HourlyChartLegend);
      final expectedTop = tester.getTopLeft(find.text('기온').last).dy -
          tester.getTopLeft(legend).dy;
      for (final metric in ['humidity', 'uv']) {
        await _select(tester, metric);
        final text =
            find.text(metric == 'humidity' ? '습도 범례 펼치기' : '자외선 범례 펼치기');
        expect(tester.getTopLeft(text).dy - tester.getTopLeft(legend).dy,
            closeTo(expectedTop, .1));
      }
    }
  });

  testWidgets('습도 0~100의 모든 단계에서 수치는 막대 위에 단계색으로 표시한다', (tester) async {
    await _pump(tester, scale: 2, data: [
      for (var index = 0; index < 6; index++)
        {
          'time': '${index + 8}',
          'humidity': [0, 25, 60, 75, 90, 100][index]
        }
    ]);
    await _select(tester, 'humidity');
    final series = _series(tester, 'humidity');
    final graph = _graph(tester, 'humidity');
    final canvas =
        tester.getRect(find.byKey(const ValueKey('hourly-chart-humidity')));
    final chart =
        tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
    for (var hour = 8; hour <= 13; hour++) {
      final finder = find.byKey(ValueKey('hourly-value-humidity-$hour'));
      final text = tester.widget<Text>(finder);
      final value = series.values[hour]!.lower;
      final band = series.bands.firstWhere((band) =>
          value >= band.from &&
          (band.includeUpper ? value <= band.to : value < band.to));
      expect(text.style?.color, band.color);
      expect(
          tester.getBottomLeft(finder).dy,
          lessThan(canvas.top +
              hourlyChartY(value, series.bounds, chart.height,
                  bottomPadding: graph.bottomPadding)));
      expect(tester.getTopLeft(finder).dy, greaterThanOrEqualTo(canvas.top));
    }
  });

  for (final height in [450.0, 700.0]) {
    for (final inline in [false, true]) {
      testWidgets('박스 하단 정렬 우선·칩 노출은 다음 순위: 높이 $height Week $inline',
          (tester) async {
        tester.view.physicalSize = Size(390, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
          bottomNavigationBar:
              const SizedBox(key: ValueKey('test-navigation'), height: 80),
          body: SingleChildScrollView(
              controller: controller,
              child: Column(children: [
                const SizedBox(height: 1000),
                HourlyForecastSection(
                    inline: inline,
                    now: DateTime.utc(2026, 10, 16, 2),
                    items: [
                      HourlyWeatherItem.fromJson({
                        'time': '11',
                        'temperature': 20,
                        'humidity': 65,
                        'windSpeed': 2
                      })
                    ]),
                const SizedBox(height: 800),
              ])),
        )));
        await tester.pumpAndSettle();
        void select(String name) => tester
            .widget<ChoiceChip>(
                find.byKey(ValueKey('today-hourly-filter-$name')))
            .onSelected!(true);
        final section = find.byKey(ValueKey(inline
            ? 'today-hourly-timeline-section'
            : 'today-hourly-forecast-section'));
        final chips = find.byKey(const ValueKey('today-hourly-filters'));
        final navigationTop =
            tester.getTopLeft(find.byKey(const ValueKey('test-navigation'))).dy;
        for (final metric in ['humidity', 'wind', 'humidity']) {
          controller.jumpTo(1000);
          select(metric);
          await tester.pumpAndSettle();
          final chipsTop = tester.getTopLeft(chips).dy;
          final boxBottom = tester.getBottomLeft(section).dy;
          expect(boxBottom, closeTo(navigationTop, .1));
          if (metric == 'humidity' && height == 450) {
            expect(chipsTop, lessThan(0));
          } else {
            expect(chipsTop, greaterThanOrEqualTo(-.1));
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  testWidgets('현재 정시만 강조하고 11시59분에서 12시로 변경되며 미래 Week는 강조하지 않는다',
      (tester) async {
    for (final inline in [false, true]) {
      Future<void> show(String time, {String date = '2026-10-16'}) async {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
          child: HourlyForecastSection(
            targetDate: date,
            inline: inline,
            availableOnly: inline,
            now: DateTime.parse('2026-10-16T$time+09:00'),
            items: [
              for (var hour = 10; hour <= 12; hour++)
                HourlyWeatherItem.fromJson({
                  'forecastAt': '${date}T$hour:00:00+09:00',
                  'precipitationPeriod': {
                    'start': '${date}T${hour - 1}:00:00+09:00',
                    'end': '${date}T$hour:00:00+09:00'
                  },
                  'temperature': 20,
                  'humidity': 65,
                  'uvIndex': 5,
                  'windSpeed': 2,
                  'precipitationProbability': 60,
                  'precipitationAmount': 1,
                  'snowExpected': true,
                  'snowfallAmount': .5,
                })
            ],
          ),
        ))));
        await tester.pumpAndSettle();
      }

      for (final time in ['11:00:00', '11:59:59', '12:00:00']) {
        await show(time);
        for (final metric in TimelineOrderStore.metrics) {
          await _select(tester, metric);
          final current = find.byKey(const ValueKey('hourly-current-time'));
          expect(current, findsOneWidget);
          expect(
              find.descendant(
                  of: current, matching: find.text('${time.substring(0, 2)}시')),
              findsOneWidget);
          if (inline) {
            final title = find.text('시간별 예보');
            final chips = find.byKey(const ValueKey('today-hourly-filters'));
            expect(tester.getTopLeft(chips).dy - tester.getBottomLeft(title).dy,
                greaterThanOrEqualTo(20));
          }
        }
      }
      await show('11:30:00', date: '2026-10-17');
      expect(find.byKey(const ValueKey('hourly-current-time')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  for (final metric in [
    'weather',
    'precipitation',
    'snowfall',
    'humidity',
    'uv'
  ]) {
    testWidgets('$metric 차트를 드래그해도 범례와 세로축은 고정된다', (tester) async {
      await _pump(tester, data: [
        for (var hour = 0; hour < 24; hour++)
          {
            'time': '$hour',
            'temperature': 20,
            'apparentTemperature': 21,
            'precipitationAmount': 1,
            'precipitationProbability': 60,
            'snowExpected': true,
            'snowfallAmount': 0.5,
            'humidity': 65,
            'uvIndex': 5,
          }
      ]);
      await _select(tester, metric);
      final timeline = find.byKey(const ValueKey('today-hourly-timeline'));
      final legend = find.byType(HourlyChartLegend);
      expect(find.descendant(of: timeline, matching: legend), findsNothing);
      final chart =
          tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
      final paint = find.byKey(ValueKey('hourly-chart-${chart.series.id}'));
      final axis = find.byType(HourlyChartAxis).first;
      final beforeLegend = tester.getTopLeft(legend).dx;
      final beforeChart = tester.getTopLeft(paint).dx;
      final beforeAxis = tester.getTopLeft(axis).dx;
      final viewport = tester.getRect(timeline);
      await tester.dragFrom(
          Offset(viewport.center.dx, viewport.top + 80), const Offset(-90, 0));
      await tester.pumpAndSettle();
      final movedLegend = beforeLegend - tester.getTopLeft(legend).dx;
      final movedChart = beforeChart - tester.getTopLeft(paint).dx;
      expect(movedLegend, closeTo(0, .1));
      expect(movedChart, greaterThan(20));
      expect(tester.getTopLeft(axis).dx, beforeAxis);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('칩과 범례 간격을 넓히고 축 제목·단위와 시간 눈금을 그래프에 가깝게 배치한다', (tester) async {
    await _pump(tester, data: [
      {
        'time': '08',
        'temperature': 20,
        'apparentTemperature': 21,
        'precipitationAmount': 1,
        'precipitationProbability': 60,
        'humidity': 65,
        'uvIndex': 5
      }
    ]);
    for (final metric in ['weather', 'precipitation', 'humidity', 'uv']) {
      await _select(tester, metric);
      final filter =
          tester.getRect(find.byKey(const ValueKey('today-hourly-filters')));
      final legend = tester.getRect(find.byType(HourlyChartLegend));
      expect(legend.top - filter.bottom, greaterThanOrEqualTo(28));
      final chart =
          tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
      final painter = _graph(tester, chart.series.id);
      final canvas = tester
          .getRect(find.byKey(ValueKey('hourly-chart-${chart.series.id}')));
      final axis = find.byType(HourlyChartAxis).first;
      final bounds = chart.sharedBounds ?? chart.series.bounds;
      final top = canvas.top +
          hourlyChartY(bounds.$2, bounds, chart.height,
              bottomPadding: painter.bottomPadding);
      final bottom = canvas.top +
          hourlyChartY(bounds.$1, bounds, chart.height,
              bottomPadding: painter.bottomPadding);
      final title = find.descendant(
          of: axis,
          matching: find.byWidgetPredicate(
              (widget) => widget is Text && widget.data!.contains('\n')));
      expect(top - tester.getBottomLeft(title).dy, inInclusiveRange(0, 16));
      for (final number in tester.widgetList<Text>(
          find.descendant(of: axis, matching: find.byType(Text)))) {
        if (number.data!.contains('\n')) continue;
        final tick = find.descendant(of: axis, matching: find.byWidget(number));
        expect(tester.getRect(title).overlaps(tester.getRect(tick)), isFalse);
      }
      final clock =
          tester.getRect(find.byKey(const ValueKey('today-hourly-8')));
      expect(
          clock.top - bottom, lessThanOrEqualTo(metric == 'weather' ? 56 : 44));
      expect(tester.getSize(axis).width, lessThanOrEqualTo(44));
    }
  });

  testWidgets('시각 자료가 한 건이어도 단계 범례를 세로로 펼치고 접을 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, availableOnly: true, data: [
      {'time': '08', 'uvIndex': 5}
    ]);
    final toggle = find.byKey(const ValueKey('uv-legend-toggle'));
    expect(find.textContaining('낮음 ·'), findsNothing);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final texts = [
      for (final band in _series(tester, 'uv').bands) find.text(band.label)
    ];
    for (var index = 1; index < texts.length; index++) {
      expect(tester.getTopLeft(texts[index]).dy,
          greaterThan(tester.getBottomLeft(texts[index - 1]).dy));
      expect(tester.getTopLeft(texts[index]).dx,
          closeTo(tester.getTopLeft(texts[0]).dx, .1));
    }
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.textContaining('낮음 ·'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('단계 범례는 큰 글씨에서도 세로로 펼쳐지고 항목 전환 때 접힌 상태로 시작한다', (tester) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, scale: 2, data: [
      {'time': '08', 'humidity': 65, 'uvIndex': 8}
    ]);
    for (final metric in ['humidity', 'uv']) {
      await _select(tester, metric);
      final toggle = find.byKey(ValueKey('$metric-legend-toggle'));
      final bands = _series(tester, metric).bands;
      expect(find.text(bands.first.label), findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final legend = tester.getRect(find.byType(HourlyChartLegend));
      Rect? previous;
      for (final band in bands) {
        final rect = tester.getRect(find.text(band.label));
        expect(rect.right, lessThanOrEqualTo(legend.right + .1));
        if (previous != null) expect(rect.top, greaterThan(previous.bottom));
        previous = rect;
      }
      expect(tester.takeException(), isNull);
    }
    await _select(tester, 'humidity');
    expect(find.textContaining('건조 ·'), findsNothing);
  });

  testWidgets('세로축 수치는 12 크기와 오른쪽 6 여백을 갖고 보통 기온의 시간 눈금도 가까워졌다',
      (tester) async {
    await _pump(tester, data: [
      {
        'time': '08',
        'temperature': 20,
        'apparentTemperature': 21,
        'humidity': 65
      }
    ]);
    for (final metric in ['weather', 'humidity']) {
      await _select(tester, metric);
      final chart =
          tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
      final axis = find.byType(HourlyChartAxis).first;
      final axisRect = tester.getRect(axis);
      for (final text in tester.widgetList<Text>(
          find.descendant(of: axis, matching: find.byType(Text)))) {
        if (text.data!.contains('\n')) continue;
        expect(text.style?.fontSize, 12);
        expect(axisRect.right - tester.getTopRight(find.byWidget(text)).dx,
            greaterThanOrEqualTo(5.9));
      }
      final painter = _graph(tester, chart.series.id);
      expect(painter.bottomPadding, 20);
      final canvas = tester
          .getRect(find.byKey(ValueKey('hourly-chart-${chart.series.id}')));
      final clock =
          tester.getRect(find.byKey(const ValueKey('today-hourly-8')));
      expect(clock.top - (canvas.bottom - painter.bottomPadding),
          lessThanOrEqualTo(25));
    }
  });

  testWidgets('Week에는 타임라인 조작 버튼이 없고 Main의 현재 계절·저장 순서를 함께 적용한다',
      (tester) async {
    HourlyWeatherItem item(String date) => HourlyWeatherItem.fromJson({
          'forecastAt': '${date}T15:00:00+09:00',
          'precipitationPeriod': {
            'start': '${date}T14:00:00+09:00',
            'end': '${date}T15:00:00+09:00'
          },
          'temperature': 20,
          'apparentTemperature': 21,
          'precipitationAmount': 1,
          'precipitationProbability': 60,
          'snowExpected': true,
          'snowfallAmount': 0.5,
          'humidity': 65,
          'uvIndex': 5,
          'windSpeed': 2,
        });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
      HourlyForecastSection(
          keyPrefix: 'main',
          items: [item('2026-10-16')],
          now: DateTime.utc(2026, 10, 16, 6)),
      HourlyForecastSection(
          keyPrefix: 'week-check',
          items: [item('2026-12-01')],
          now: DateTime.utc(2026, 10, 16, 6),
          targetDate: '2026-12-01',
          inline: true,
          availableOnly: true),
    ])))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-hourly-order')), findsOneWidget);
    expect(find.byKey(const ValueKey('main-hourly-info')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-check-hourly-order')), findsNothing);
    expect(find.byKey(const ValueKey('week-check-hourly-info')), findsNothing);
    List<String> order(String prefix) => tester
        .widgetList<ChoiceChip>(find.descendant(
            of: find.byKey(ValueKey('$prefix-hourly-filters')),
            matching: find.byType(ChoiceChip)))
        .map((chip) =>
            (chip.key! as ValueKey<String>).value.split('-filter-').last)
        .toList();
    expect(order('main'), TimelineOrderStore.defaults(10));
    expect(order('week-check'), order('main'));
    const custom = [
      'uv',
      'wind',
      'humidity',
      'snowfall',
      'precipitation',
      'weather'
    ];
    await TimelineOrderStore.save(custom);
    await tester.pumpAndSettle();
    expect(order('main'), custom);
    expect(order('week-check'), custom);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('320px·$scale배 글씨에서 모든 지표와 순서 편집에 레이아웃 오류가 없다', (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, scale: scale, data: [
        {
          'time': '08',
          'temperature': -4,
          'apparentTemperature': -8,
          'precipitationAmountRange': {'type': 'RANGE', 'min': 30, 'max': 50},
          'precipitationProbability': 70,
          'snowExpected': true,
          'snowfallAmountRange': {'type': 'AT_LEAST', 'min': 5, 'unit': 'CM'},
          'humidity': 85,
          'uvIndex': 12,
          'windSpeed': 15,
        }
      ]);
      for (final metric in TimelineOrderStore.metrics) {
        await _select(tester, metric);
        expect(tester.takeException(), isNull);
      }
      await tester
          .ensureVisible(find.byKey(const ValueKey('today-hourly-order')));
      await tester.tap(find.byKey(const ValueKey('today-hourly-order')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

List<String> _chipOrder(WidgetTester tester) => tester
    .widgetList<ChoiceChip>(find.byType(ChoiceChip))
    .map((chip) => (chip.key! as ValueKey<String>).value.split('-filter-').last)
    .toList();

HourlyValueChartPainter _graph(WidgetTester tester, String id) => tester
    .widget<CustomPaint>(find.byKey(ValueKey('hourly-chart-$id')))
    .painter! as HourlyValueChartPainter;

Future<void> _select(WidgetTester tester, String metric) async {
  final chip = find.byKey(ValueKey('today-hourly-filter-$metric'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester,
    {int month = 10,
    double scale = 1,
    bool availableOnly = false,
    List<Map<String, dynamic>> data = const []}) async {
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data:
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
        body: SingleChildScrollView(
            child: HourlyForecastSection(
      items: data.map(HourlyWeatherItem.fromJson).toList(),
      now: DateTime.utc(2026, month, 16),
      availableOnly: availableOnly,
    ))),
  ));
  await tester.pumpAndSettle();
}

HourlyChartSeries _series(WidgetTester tester, String id) => tester
    .widgetList<HourlyValueChart>(find.byType(HourlyValueChart))
    .expand((chart) => [chart.series, ...chart.overlays])
    .singleWhere((chart) => chart.id == id);
