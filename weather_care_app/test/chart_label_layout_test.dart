import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/widgets/hourly_value_chart.dart';
import 'package:weather_care/features/home/widgets/weather_condition_icon.dart';
import 'package:weather_care/theme/weather_theme.dart';

const _capture = bool.fromEnvironment('CAPTURE_CHART_LABELS');
const _output = String.fromEnvironment('CHART_LABEL_OUTPUT',
    defaultValue: 'docs/chart-snow-connected-20261029');

HourlyChartSeries _series(
        String id, String title, String unit, List<double?> values, Color color,
        {bool bars = false, List<double> offsets = const []}) =>
    HourlyChartSeries(
        id: id,
        title: title,
        unit: unit,
        color: color,
        bars: bars,
        fixedMax: unit == '%' ? 100 : null,
        xOffsets: offsets,
        values: values.map(HourlyChartValue.number).toList());

void main() {
  setUpAll(() async {
    // 예시와 충돌 검사 모두 제품의 한글 글꼴로 수행한다.
    for (final family in ['SUITE', 'Ahem']) {
      final loader = FontLoader(family);
      for (final name in ['Regular', 'Bold', 'Heavy']) {
        loader.addFont(Future.value(ByteData.sublistView(
            File('assets/fonts/SUITE-$name.ttf').readAsBytesSync())));
      }
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  const blue = Color(0xFFB1CCE1);
  const purple = Color(0xFFBFA6E8);
  const orange = Color(0xFFFFC078);
  final examples = [
    (
      '01-rain-peaks',
      '① 강수 · 급경사와 0mm',
      '첨부 사례처럼 확률 60%와 강수량 0·1·2mm가 함께 표시될 때',
      [
        _series('rain-amount', '강수량', 'mm', [1, 0, 0, 2], blue),
        _series('rain-probability', '강수확률', '%', [60, 60, 60, 60], purple,
            bars: true),
      ],
      null,
      <String?>[],
    ),
    (
      '02-rain-extremes',
      '② 강수 · 막대 끝과 선이 만날 때',
      '0%·100%와 근접한 두 수치도 생략하지 않고 빈 공간에 표시',
      [
        _series('rain-amount', '강수량', 'mm', [0, 10, 6.7, 10], blue),
        _series('rain-probability', '강수확률', '%', [0, 90, 60, 100], purple,
            bars: true),
      ],
      null,
      <String?>[],
    ),
    (
      '03-snow-ranges',
      '③ 강설 · 지난 관측과 미래 예보',
      '19시 기준 · 지난 시각은 관측 적설량, 앞으로는 신적설 예보',
      [
        const HourlyChartSeries(
            id: 'snow-amount',
            title: '신적설',
            unit: 'cm',
            color: blue,
            values: [
              null,
              null,
              HourlyChartValue(0, 0),
              HourlyChartValue(2, null, range: true)
            ],
            labels: [
              null,
              null,
              '0cm',
              '2cm 이상'
            ]),
        _series('snow-depth', '현재 적설량', 'cm', [1, 3, null, null], orange,
            offsets: [-.25, -.1, 0, 0]),
        _series('snow-probability', '강설확률', '%', [null, null, 0, 100], purple,
            bars: true),
      ],
      (0.0, 4.0),
      <String?>[],
    ),
    (
      '04-temperature-crossing',
      '④ 기온 · 교차·동일 값·영하',
      '같은 값의 두 수치와 날씨 아이콘도 서로 겹치지 않게 표시',
      [
        _series('temperature', '기온', '°C', [-10, 20, 0, -10], blue),
        _series('apparent', '체감온도', '°C', [-10, 19, 0, -12], orange),
      ],
      (-15.0, 23.0),
      <String?>['눈', '맑음', '흐림', '눈'],
    ),
    (
      '05-humidity',
      '⑤ 막대 · 최저·최고·큰 글씨',
      '2배 글씨에서도 0%·1%·99%·100%를 막대와 분리해 표시',
      [
        _series('humidity', '습도', '%', [0, 1, 99, 100], blue, bars: true)
      ],
      null,
      <String?>[],
    ),
  ];

  for (final example in examples) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${example.$2} · $scale배 충돌 검사', (tester) async {
        final boundary = GlobalKey();
        await _pump(tester, example.$4,
            bounds: example.$5,
            conditions: example.$6,
            scale: scale,
            title: example.$2,
            description: example.$3,
            boundary: boundary);
        _verify(tester);
        if (_capture && scale == (example.$1 == '05-humidity' ? 2 : 1)) {
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final dir = Directory(_output)..createSync(recursive: true);
            File('${dir.path}/${example.$1}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }

  testWidgets('꺾은선 수치는 막대 안에서도 점 가까이 표시하고 대비를 높인다', (tester) async {
    await _pump(tester, [
      _series('rain-amount', '강수량', 'mm', [1, 0, 0, 2], blue),
      _series('rain-probability', '강수확률', '%', [60, 60, 60, 60], purple,
          bars: true),
    ]);
    _verify(tester);
    final paintFinder = find.byKey(const ValueKey('hourly-chart-rain-amount'));
    final painter = tester.widget<CustomPaint>(paintFinder).painter!
        as HourlyValueChartPainter;
    final origin = tester.getTopLeft(paintFinder);
    final height = tester.getSize(paintFinder).height;
    final amount = tester
        .getRect(find.byKey(const ValueKey('hourly-label-rain-amount-0')))
        .shift(-origin);
    final pointY = hourlyChartY(1, painter.series.bounds, height,
        topPadding: painter.topPadding, bottomPadding: painter.bottomPadding);
    final barTop = hourlyChartY(60, painter.overlays.single.bounds, height,
        topPadding: painter.topPadding, bottomPadding: painter.bottomPadding);
    expect(amount.center.dx, closeTo(painter.pointWidth / 2, .1));
    expect((amount.center.dy - pointY).abs(), lessThan(30));
    expect(amount.top, greaterThan(barTop));
    final text = tester
        .widget<Text>(find.byKey(const ValueKey('hourly-value-rain-amount-0')));
    expect(text.style!.shadows, isNotEmpty);
  });

  testWidgets('동일한 최댓값의 세 계열도 모두 표시한다', (tester) async {
    await _pump(
        tester,
        [
          _series('snow-amount', '신적설', 'cm', [10, 10, 10], blue),
          _series('snow-depth', '현재 적설량', 'cm', [10, 10, 10], orange),
          _series('snow-probability', '강설확률', '%', [100, 100, 100], purple,
              bars: true),
        ],
        bounds: (0, 11.2),
        scale: 2);
    _verify(tester);
  });

  testWidgets('확률은 막대 위를 유지하고 선과 겹치는 경우만 내부로 옮긴다', (tester) async {
    await _pump(tester, [
      _series('rain-amount', '강수량', 'mm', [1, 0, 0, 2], blue),
      _series('rain-probability', '강수확률', '%', [60, 60, 60, 60], purple,
          bars: true),
    ]);
    _verify(tester);
    final paintFinder = find.byKey(const ValueKey('hourly-chart-rain-amount'));
    final painter = tester.widget<CustomPaint>(paintFinder).painter!
        as HourlyValueChartPainter;
    final origin = tester.getTopLeft(paintFinder);
    final height = tester.getSize(paintFinder).height;
    final top = hourlyChartY(60, painter.overlays.single.bounds, height,
        topPadding: painter.topPadding, bottomPadding: painter.bottomPadding);
    for (var i = 0; i < 4; i++) {
      final value = tester
          .getRect(find.byKey(ValueKey('hourly-label-rain-probability-$i')))
          .shift(-origin);
      if (i < 3) {
        expect(value.bottom, lessThan(top));
      } else {
        expect(value.top, greaterThanOrEqualTo(top));
      }
      expect(value.bottom, lessThanOrEqualTo(height - painter.bottomPadding));
      expect(
          (value.center.dx - (i + .5) * painter.pointWidth).abs(), lessThan(1));
    }
  });

  testWidgets('2cm 이상 신적설은 2cm의 점만 그리고 위쪽 범위 선은 그리지 않는다', (tester) async {
    const chart = HourlyChartSeries(
        id: 'snow-amount',
        title: '신적설',
        unit: 'cm',
        values: [HourlyChartValue(2, null, range: true)]);
    const painter = HourlyValueChartPainter(
        series: chart,
        hours: [20],
        pointWidth: 72,
        color: Color(0xFF00AAFF),
        gridColor: Colors.transparent,
        sharedBounds: (0, 4));
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(72, 320));
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(72, 320);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final pointY = hourlyChartY(2, (0, 4), 320).round();
      expect(bytes.getUint8((pointY * 72 + 36) * 4 + 3), greaterThan(200));
      for (var y = 0; y < 320; y++) {
        if ((y - pointY).abs() <= 5) continue;
        expect(bytes.getUint8((y * 72 + 36) * 4 + 3), 0,
            reason: '$y 높이에 선이 없어야 함');
      }
      image.dispose();
    });
    picture.dispose();
  });

  testWidgets('연속한 신적설 0cm와 2cm 이상 하한 점 사이를 연결한다', (tester) async {
    const chart = HourlyChartSeries(
        id: 'snow-amount',
        title: '신적설',
        unit: 'cm',
        values: [
          HourlyChartValue(0, 0),
          HourlyChartValue(2, null, range: true)
        ]);
    const painter = HourlyValueChartPainter(
        series: chart,
        hours: [19, 20],
        pointWidth: 72,
        color: Color(0xFF00AAFF),
        gridColor: Colors.transparent,
        sharedBounds: (0, 4));
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(144, 320));
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(144, 320);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final middleY = hourlyChartY(1, (0, 4), 320).round();
      expect(bytes.getUint8((middleY * 144 + 72) * 4 + 3), greaterThan(200));
      expect(bytes.getUint8((70 * 144 + 108) * 4 + 3), 0);
      image.dispose();
    });
    picture.dispose();
  });

  testWidgets('공간이 부족해도 수치를 생략하거나 다른 수치 위에 겹치지 않는다', (tester) async {
    await _pump(tester, [
      for (var i = 0; i < 6; i++)
        _series('bar-$i', '계열 $i', '%', [100, 100], purple, bars: true),
    ]);
    _verify(tester, allowFooter: true);
    expect(find.byKey(const ValueKey('hourly-value-bar-5-1')), findsOneWidget);
  });

  testWidgets('무작위 24시간·세 계열·결측·불규칙 관측 시각 충돌 검사', (tester) async {
    final random = math.Random(29);
    for (var attempt = 0; attempt < 16; attempt++) {
      final scale = attempt.isEven ? 1.0 : 2.0;
      final all = [
        _series('snow-amount', '신적설', 'cm',
            List.generate(24, (_) => random.nextInt(8).toDouble()), blue),
        _series(
            'snow-depth',
            '현재 적설량',
            'cm',
            List.generate(24,
                (_) => random.nextBool() ? null : random.nextInt(8).toDouble()),
            orange,
            offsets: List.generate(24, (_) => random.nextDouble() - .5)),
        _series('snow-probability', '강설확률', '%',
            List.generate(24, (_) => random.nextInt(101).toDouble()), purple,
            bars: true),
      ];
      await _pump(tester, all, bounds: (0, 8), scale: scale);
      _verify(tester);
    }
  });
}

Future<void> _pump(WidgetTester tester, List<HourlyChartSeries> all,
    {(double, double)? bounds,
    List<String?> conditions = const [],
    double scale = 1,
    String title = '',
    String description = '',
    GlobalKey? boundary}) async {
  final panelWidth = 72 * scale * all.first.values.length +
      (all.any((chart) => chart.bars) && !all.first.bars ? 88 : 44) +
      32;
  tester.view.physicalSize = Size(math.min(panelWidth, 800), 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final hours = List.generate(all.first.values.length, (i) => 17 + i);
  final width = 72 * scale;
  final height = 320.0 * math.min(scale, 1.3);
  final top = hourlyChartTopPadding(bounds, 18 * scale);
  final bottom = hourlyChartBottomPadding(all, bounds, height, 18 * scale);
  await tester.pumpWidget(MaterialApp(
      theme: WeatherCareTheme.dark(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(
          body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                  key: boundary,
                  child: Container(
                      width: math.min(panelWidth, 800),
                      padding: const EdgeInsets.all(16),
                      color: WeatherCarePalette.dark.surface,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'SUITE',
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text(description,
                                style: const TextStyle(
                                    fontSize: 12, fontFamily: 'SUITE')),
                            const SizedBox(height: 18),
                            HourlyChartLegend(series: all),
                            const SizedBox(height: 12),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                      width: 44,
                                      child: HourlyChartAxis(
                                          series: all.first,
                                          title: all.first.unit == 'cm'
                                              ? '적설량'
                                              : null,
                                          sharedBounds: bounds,
                                          height: height,
                                          topPadding: top,
                                          bottomPadding: bottom)),
                                  Expanded(
                                      child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Column(children: [
                                            HourlyValueChart(
                                                series: all.first,
                                                overlays: all.skip(1).toList(),
                                                hours: hours,
                                                pointWidth: width,
                                                height: height,
                                                sharedBounds: bounds,
                                                conditions: conditions,
                                                showValues: true),
                                            Row(children: [
                                              for (final hour in hours)
                                                SizedBox(
                                                    width: width,
                                                    child: Center(
                                                        child: Text('$hour시',
                                                            style:
                                                                const TextStyle(
                                                                    fontFamily:
                                                                        'SUITE',
                                                                    fontSize:
                                                                        12))))
                                            ]),
                                          ]))),
                                  if (all.any((chart) => chart.bars) &&
                                      !all.first.bars)
                                    SizedBox(
                                        width: 44,
                                        child: HourlyChartAxis(
                                            series: all.last,
                                            right: true,
                                            height: height,
                                            topPadding: top,
                                            bottomPadding: bottom)),
                                ]),
                            const SizedBox(height: 12),
                          ])))))));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void _verify(WidgetTester tester, {bool allowFooter = false}) {
  final chart = tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
  final paint = find.byKey(ValueKey('hourly-chart-${chart.series.id}'));
  final painter =
      tester.widget<CustomPaint>(paint).painter! as HourlyValueChartPainter;
  final origin = tester.getTopLeft(paint);
  final size = tester.getSize(paint);
  final labels = <Rect>[];
  final barLabels = <(HourlyChartSeries, int, Rect)>[];
  for (final series in [chart.series, ...chart.overlays]) {
    for (var i = 0; i < series.values.length; i++) {
      if (series.values[i] == null) continue;
      final rect = tester
          .getRect(find.byKey(ValueKey('hourly-label-${series.id}-$i')))
          .shift(-origin);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(
          rect.bottom,
          lessThanOrEqualTo(allowFooter
              ? tester.getSize(find.byType(HourlyValueChart)).height
              : size.height));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      for (final other in labels) {
        expect(rect.inflate(1).overlaps(other), isFalse,
            reason: '${series.id}-$i');
      }
      labels.add(rect);
      if (series.bars) barLabels.add((series, i, rect));
    }
  }
  for (final icon in find.byType(WeatherConditionIcon).evaluate()) {
    final rect = tester.getRect(find.byWidget(icon.widget)).shift(-origin);
    for (final label in labels) {
      expect(rect.overlaps(label), isFalse);
    }
    labels.add(rect);
  }
  for (final series in [chart.series, ...chart.overlays]) {
    final bounds =
        chart.sharedBounds != null && series.unit == chart.series.unit
            ? chart.sharedBounds!
            : series.bounds;
    double y(double value) => hourlyChartY(value, bounds, size.height,
        topPadding: painter.topPadding, bottomPadding: painter.bottomPadding);
    Offset point(int i, double value) => Offset(
        (chart.hours[i] -
                chart.hours.first +
                .5 +
                (series.xOffsets.elementAtOrNull(i) ?? 0)) *
            chart.pointWidth,
        y(value));
    for (var i = 0; i < series.values.length; i++) {
      final value = series.values[i];
      if (value == null) continue;
      final at = point(i, value.lower);
      if (series.bars ||
          value.range && !(series.id == 'snow-amount' && value.upper == null)) {
        final obstacle = value.range
            ? Rect.fromLTRB(
                at.dx - 8, y(value.upper ?? bounds.$2), at.dx + 8, at.dy)
            : Rect.fromLTRB(at.dx - painter.barHalfWidth, at.dy,
                at.dx + painter.barHalfWidth, math.max(at.dy + 2, y(0)));
        final protectedLabels = value.range
            ? labels
            : [
                for (final label in barLabels)
                  if (label.$1 != series || label.$2 != i) label.$3
              ];
        for (final label in protectedLabels) {
          expect(label.inflate(1).overlaps(obstacle), isFalse,
              reason: '${series.id}-$i 막대/범위를 수치가 가림');
        }
      } else {
        final next = i + 1 < series.values.length &&
                series.values[i + 1] != null &&
                (!series.values[i + 1]!.range ||
                    series.id == 'snow-amount' &&
                        series.values[i + 1]!.upper == null) &&
                chart.hours[i + 1] - chart.hours[i] == 1
            ? point(i + 1, series.values[i + 1]!.lower)
            : at;
        for (var sample = 0; sample <= 160; sample++) {
          final position = Offset.lerp(at, next, sample / 160)!;
          for (final label in labels) {
            expect(label.inflate(2).contains(position), isFalse,
                reason: '${series.id}-$i 선분/점을 수치가 가림: $label / $position');
          }
        }
      }
    }
  }
}
