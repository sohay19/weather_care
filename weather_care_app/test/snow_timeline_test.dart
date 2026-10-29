import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/features/home/widgets/hourly_forecast_section.dart';
import 'package:weather_care/features/home/widgets/hourly_value_chart.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/timeline_order_store.dart';
import 'package:weather_care/theme/weather_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TimelineOrderStore.order.value = null;
  });

  test('현재 적설 이력은 유효한 0을 보존하고 잘못된 값은 제외한다', () {
    final response = TodayWeatherResponse.fromJson({
      'current': {},
      'snowDepthHistory': [
        {
          'observedAt': '2026-10-26T10:20:00+09:00',
          'depthCm': 0,
          'stationId': '108'
        },
        {'observedAt': 'invalid', 'depthCm': 2, 'stationId': '108'},
        {
          'observedAt': '2026-10-26T10:20:00+09:00',
          'depthCm': -1,
          'stationId': '108'
        },
      ],
    });
    expect(response.snowDepthHistory.single.depthCm, 0);
    expect(response.withRegionName('서울').snowDepthHistory,
        response.snowDepthHistory);
    expect(TodayWeatherResponse.fromJson({'current': {}}).snowDepthHistory,
        isEmpty);
  });

  testWidgets('관측을 해당 시각에만 표시하고 다른 날짜·미래·관측소를 섞지 않는다', (tester) async {
    await pumpSnow(tester, [
      observation(8, 10, 2),
      observation(9, 20, 0),
      observation(9, 45, 1),
      observation(13, 0, 99),
      observation(7, 0, 8, station: 'other'),
    ]);
    final chart =
        tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
    final depth =
        chart.overlays.singleWhere((series) => series.id == 'snow-depth');
    expect(
        depth.values.whereType<HourlyChartValue>().map((value) => value.lower),
        [2, 1]);
    expect(depth.values[10], isNull);
    expect(depth.values[13], isNull);
    expect(depth.xOffsets[9], closeTo(.25, .001));
    expect(chart.overlays.last.id, 'snow-probability');
    expect(chart.overlays.last.bounds, (0.0, 100.0));
    expect(depth.color, isNot(chart.series.color));
    expect(find.text('현재 적설량'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Week는 신적설 결측 시각에도 실제 적설 관측을 표시한다', (tester) async {
    await pumpSnow(tester, [observation(7, 10, 0)], availableOnly: true);
    final chart =
        tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
    final depth =
        chart.overlays.singleWhere((series) => series.id == 'snow-depth');
    final index = chart.hours.indexOf(7);
    expect(index, greaterThanOrEqualTo(0));
    expect(chart.series.values[index], isNull);
    expect(depth.values[index]!.lower, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('이력이 없는 서버의 현재 관측은 한 점만 표시하고 오래되면 제외한다', (tester) async {
    for (final hour in [11, 7]) {
      await pumpSnow(tester, [],
          currentSnow: CurrentWeather(
            temperature: null,
            snowDepthCm: 0,
            snowDepthStatus: 'AVAILABLE',
            snowDepthObservedAt:
                '2026-10-26T${hour.toString().padLeft(2, '0')}:20:00+09:00',
            snowDepthStationName: '서울 관측소',
          ));
      final chart =
          tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
      final depth =
          chart.overlays.singleWhere((series) => series.id == 'snow-depth');
      expect(depth.values.whereType<HourlyChartValue>().length,
          hour == 11 ? 1 : 0);
    }
  });

  for (final inline in [false, true]) {
    testWidgets('과거·진행 중 구간은 관측만, 미래 구간은 예보만 표시: Week $inline', (tester) async {
      await pumpSnow(
          tester,
          [
            observation(11, 50, 2),
            observation(12, 10, 3),
            observation(13, 0, 99)
          ],
          availableOnly: inline,
          now: DateTime.parse('2026-10-26T12:30:00+09:00'));
      final chart =
          tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
      final depth = chart.overlays.first;
      final probability = chart.overlays.last;
      for (var i = 0; i < chart.hours.length; i++) {
        final hour = chart.hours[i];
        if (hour <= 12) {
          expect(chart.series.values[i], isNull);
          expect(probability.values[i], isNull);
          expect(
              depth.values[i]?.lower,
              hour == 11
                  ? 2
                  : hour == 12
                      ? 3
                      : null);
        } else {
          expect(depth.values[i], isNull);
        }
      }
      expect(chart.series.values[chart.hours.indexOf(13)]?.lower, 3);
      expect(probability.values[chart.hours.indexOf(13)]?.lower, 80);
      expect(find.byKey(const ValueKey('hourly-value-snow-amount-10')),
          findsNothing);
    });
  }

  testWidgets('정시가 지나면 해당 구간 예보를 숨기고 실제 관측으로 바꾼다', (tester) async {
    for (final time in ['12:59:59', '13:00:00', '13:00:01']) {
      await pumpSnow(tester, [observation(13, 0, 2)],
          now: DateTime.parse('2026-10-26T$time+09:00'));
      final chart =
          tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
      expect(chart.series.values[13]?.lower, time == '13:00:01' ? null : 3);
      expect(chart.overlays.first.values[13]?.lower,
          time == '12:59:59' ? null : 2);
    }
  });

  testWidgets('다음 날에는 신적설 예보만 표시하고 오늘 관측을 복사하지 않는다', (tester) async {
    await pumpSnow(tester, [observation(8, 0, 99)], targetDate: '2026-10-27');
    final chart =
        tester.widget<HourlyValueChart>(find.byType(HourlyValueChart));
    expect(chart.series.values[8]?.lower, 1);
    expect(chart.overlays.first.values.whereType<HourlyChartValue>(), isEmpty);
  });

  for (final scale in [1.0, 2.0]) {
    for (final dark in [false, true]) {
      testWidgets('강설 과거 관측·미래 예보는 ${dark ? '다크' : '라이트'} $scale배에서 겹치지 않는다',
          (tester) async {
        for (final depths in [
          [0.0, 0.0, 0.0],
          [5.0, 2.0, .5],
          [100.0, 1.0, 10.0],
          [1.0, 3.0, 1.0]
        ]) {
          await pumpSnow(
              tester,
              [
                for (var i = 0; i < 3; i++)
                  observation(8 + i, i * 20, depths[i])
              ],
              scale: scale,
              dark: dark);
          final paintFinder =
              find.byKey(const ValueKey('hourly-chart-snow-amount'));
          final painter = tester.widget<CustomPaint>(paintFinder).painter!
              as HourlyValueChartPainter;
          final origin = tester.getTopLeft(paintFinder);
          final labelRects = <Rect>[];
          for (final id in ['snow-amount', 'snow-depth', 'snow-probability']) {
            for (var i = 8; i < 15; i++) {
              final finder = find.byKey(ValueKey('hourly-label-$id-$i'));
              if (finder.evaluate().isEmpty) continue;
              final rect = tester.getRect(finder).shift(-origin);
              for (final other in labelRects) {
                expect(rect.overlaps(other), isFalse,
                    reason: '$id-$i 수치 겹침: $rect / $other');
              }
              expect(rect.top, greaterThanOrEqualTo(0));
              expect(rect.bottom,
                  lessThanOrEqualTo(tester.getSize(paintFinder).height + .1));
              labelRects.add(rect);
            }
          }
          for (final line in [
            painter.series,
            ...painter.overlays.where((series) => !series.bars)
          ]) {
            Offset point(int i) => Offset(
                (painter.hours[i] -
                        painter.hours.first +
                        .5 +
                        (line.xOffsets.elementAtOrNull(i) ?? 0)) *
                    painter.pointWidth,
                hourlyChartY(line.values[i]!.upper ?? line.values[i]!.lower,
                    painter.sharedBounds!, tester.getSize(paintFinder).height,
                    topPadding: painter.topPadding,
                    bottomPadding: painter.bottomPadding));
            for (var i = 8; i < 15; i++) {
              if (line.values[i] == null) continue;
              final a = point(i),
                  b = i < 14 && line.values[i + 1] != null ? point(i + 1) : a;
              for (var sample = 0; sample <= 40; sample++) {
                final at = Offset.lerp(a, b, sample / 40)!;
                expect(labelRects.any((rect) => rect.inflate(1).contains(at)),
                    isFalse,
                    reason: '${line.id} 선을 수치가 가림: $at');
              }
            }
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}

SnowDepthObservation observation(int hour, int minute, double value,
        {String station = '108'}) =>
    SnowDepthObservation(
        observedAt: DateTime.utc(2026, 10, 25, 15)
            .add(Duration(hours: hour, minutes: minute)),
        depthCm: value,
        stationId: station,
        stationName: '서울 관측소');

Future<void> pumpSnow(WidgetTester tester, List<SnowDepthObservation> history,
    {double scale = 1,
    bool dark = false,
    bool availableOnly = false,
    DateTime? now,
    String targetDate = '2026-10-26',
    CurrentWeather? currentSnow}) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: dark ? WeatherCareTheme.dark() : WeatherCareTheme.light(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(
          body: SingleChildScrollView(
              child: HourlyForecastSection(
        items: [
          for (final i in [8, 9, 10, 12, 13, 14])
            HourlyWeatherItem.fromJson({
              'time': '$i',
              'forecastDate': targetDate,
              'forecastAt':
                  '${targetDate}T${(i + 1).toString().padLeft(2, '0')}:00:00+09:00',
              'precipitationPeriod': {
                'start':
                    '${targetDate}T${i.toString().padLeft(2, '0')}:00:00+09:00',
                'end':
                    '${targetDate}T${(i + 1).toString().padLeft(2, '0')}:00:00+09:00',
              },
              'snowExpected': true,
              'snowfallAmount': [1.0, 3.0, 1.0][i >= 12 ? i - 12 : i - 8],
              'precipitationProbability': [
                30,
                80,
                50
              ][i >= 12 ? i - 12 : i - 8],
            })
        ],
        snowDepthHistory: history,
        currentSnow: currentSnow,
        availableOnly: availableOnly,
        targetDate: targetDate,
        now: now ?? DateTime.utc(2026, 10, 26, 3),
      )))));
  await tester.pumpAndSettle();
  final chip = find.byKey(const ValueKey('today-hourly-filter-snowfall'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}
