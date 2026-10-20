import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/precipitation.dart';
import '../../../theme/weather_theme.dart';
import '../../../utils/weather_number.dart';
import 'weather_condition_icon.dart';

/// 정량 값과 범위 예보를 구분한다. 범위의 중간값을 실제 값으로 만들지 않는다.
class HourlyChartValue {
  final double lower;
  final double? upper;
  final bool range;
  const HourlyChartValue(this.lower, this.upper, {this.range = false});

  static HourlyChartValue? number(double? value) =>
      value == null || !value.isFinite ? null : HourlyChartValue(value, value);

  static HourlyChartValue? amount(double? value, String? label) {
    if (label != null) {
      final parsed = PrecipitationAmount.parse(label.replaceAll('cm', 'mm'));
      if (parsed != null) {
        return HourlyChartValue(parsed.lower / 1000,
            parsed.upper == null ? null : parsed.upper! / 1000,
            range: parsed.lower != parsed.upper || parsed.upperExclusive);
      }
    }
    return value == null || value < 0 ? null : number(value);
  }
}

class HourlyChartBand {
  final double from;
  final double to;
  final Color color;
  final String label;
  final bool includeUpper;
  const HourlyChartBand(this.from, this.to, this.color, this.label,
      {this.includeUpper = false});
}

class HourlyChartSeries {
  final String id;
  final String title;
  final String unit;
  final List<HourlyChartValue?> values;
  final bool bars;
  final double? fixedMax;
  final List<HourlyChartBand> bands;
  final Color? color;
  final List<String?> labels;
  final bool intervals;

  const HourlyChartSeries({
    required this.id,
    required this.title,
    required this.unit,
    required this.values,
    this.bars = false,
    this.fixedMax,
    this.bands = const [],
    this.color,
    this.labels = const [],
    this.intervals = false,
  });

  (double, double) get bounds {
    final numbers = values.whereType<HourlyChartValue>();
    if (fixedMax != null) return (0, fixedMax!);
    if (unit == '°C') {
      if (numbers.isEmpty) return (-3, 3);
      final low = numbers.map((value) => value.lower).reduce(math.min);
      final high =
          numbers.map((value) => value.upper ?? value.lower).reduce(math.max);
      return (low - 3, high + 3);
    }
    var low = numbers.fold(0.0, (a, b) => math.min(a, b.lower));
    var high = numbers.fold(0.0, (a, b) => math.max(a, b.upper ?? b.lower));
    final padding = math.max((high - low) * .12, high == 0 ? 1.0 : .1);
    if (low < 0) low -= padding;
    high += padding;
    return (low, high);
  }
}

const hourlyChartHeight = 144.0;
const hourlyChartTitleHeight = 30.0;
const hourlyChartGap = 4.0;
const _plotTop = 48.0;
const _plotBottom = 20.0;

double hourlyChartWidth(
        List<int> hours, double pointWidth, List<HourlyChartSeries> series) =>
    (hours.last -
        hours.first +
        1 +
        (series.any((chart) => chart.intervals) ? .5 : 0)) *
    pointWidth;

double hourlyChartY(double value, (double, double) bounds, double height,
        {double bottomPadding = _plotBottom}) =>
    _plotTop +
    (bounds.$2 - value) /
        (bounds.$2 - bounds.$1) *
        (height - _plotTop - bottomPadding);

/// 점 아래 수치가 시간 눈금과 겹치지 않도록 필요한 공간만 남긴다.
double hourlyChartBottomPadding(List<HourlyChartSeries> series,
    (double, double)? bounds, double height, double labelHeight) {
  if (bounds == null) {
    if (series.firstOrNull?.id.endsWith('-amount') ?? false) {
      return labelHeight + 14;
    }
    return series.firstOrNull?.id == 'uv'
        ? math.max(_plotBottom, 44 * math.min(labelHeight / 18, 1.3) / 2 + 4)
        : _plotBottom;
  }
  final values =
      series.expand((chart) => chart.values).whereType<HourlyChartValue>();
  if (values.isEmpty) return _plotBottom;
  final fraction = values
      .map((value) => (value.lower - bounds.$1) / (bounds.$2 - bounds.$1))
      .reduce(math.min)
      .clamp(0.0, 1.0);
  if (fraction >= 1) return _plotBottom;
  return math.max(_plotBottom,
      (labelHeight * 2 + 12 - fraction * (height - _plotTop)) / (1 - fraction));
}

List<double> _axisTicks(HourlyChartSeries series, (double, double) bounds) =>
    series.bands.isEmpty
        ? [
            for (var tick = 0; tick <= 4; tick++)
              bounds.$1 + (bounds.$2 - bounds.$1) * tick / 4
          ]
        : <double>{
            bounds.$1,
            bounds.$2,
            ...series.bands.map((band) => band.to.clamp(bounds.$1, bounds.$2))
          }.toList();

/// 세로축은 가로 스크롤 밖에 두어 어느 시각에서도 수치를 읽을 수 있다.
class HourlyChartAxis extends StatelessWidget {
  final HourlyChartSeries series;
  final String? title;
  final double height;
  final (double, double)? sharedBounds;
  final bool right;
  final double bottomPadding;
  const HourlyChartAxis(
      {super.key,
      required this.series,
      this.title,
      this.height = hourlyChartHeight,
      this.sharedBounds,
      this.right = false,
      this.bottomPadding = _plotBottom});

  @override
  Widget build(BuildContext context) {
    final bounds = sharedBounds ?? series.bounds;
    final ticks = _axisTicks(series, bounds);
    final palette = WeatherCareTheme.of(context);
    Widget fit(String text, {Color? color, bool bold = false}) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: right ? Alignment.centerLeft : Alignment.centerRight,
        child: Text(text,
            maxLines: 1,
            style: TextStyle(
                fontFamily: WeatherCareTheme.fontSuite,
                fontSize: 12,
                color: color ?? palette.textSecondary,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400)));
    return Column(children: [
      SizedBox(
          height: height,
          child: Stack(children: [
            Positioned(
                top: _plotTop - hourlyChartTitleHeight - 16,
                left: 0,
                right: 0,
                height: hourlyChartTitleHeight,
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomCenter,
                    child: Text(
                        '${title ?? (sharedBounds != null ? '온도' : right ? '확률' : series.title)}\n${series.unit}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: WeatherCareTheme.fontSuite,
                            fontSize: 10,
                            height: 1.2,
                            color: series.color ?? palette.textPrimary,
                            fontWeight: FontWeight.w700)))),
            for (final value in ticks)
              Positioned(
                  top: hourlyChartY(value, bounds, height,
                          bottomPadding: bottomPadding) -
                      12,
                  left: right ? 6 : 0,
                  right: 6,
                  child: SizedBox(
                      height: 24, child: fit(formatWeatherNumber(value)))),
          ])),
      const SizedBox(height: hourlyChartGap),
    ]);
  }
}

class HourlyChartLegend extends StatefulWidget {
  final List<HourlyChartSeries> series;
  const HourlyChartLegend({super.key, required this.series});
  @override
  State<HourlyChartLegend> createState() => _HourlyChartLegendState();
}

class _HourlyChartLegendState extends State<HourlyChartLegend> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        fontFamily: WeatherCareTheme.fontSuite,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0);
    final palette = WeatherCareTheme.of(context);
    final bands = widget.series.expand((chart) => chart.bands).toList();
    if (bands.isNotEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextButton.icon(
          key: ValueKey('${widget.series.first.id}-legend-toggle'),
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(
              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 16),
          label: Text(
              '${widget.series.first.title} 범례 ${_expanded ? '접기' : '펼치기'}',
              style: style),
        ),
        if (_expanded)
          for (final band in bands)
            Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(children: [
                  Container(width: 10, height: 10, color: band.color),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(band.label,
                          style: style.copyWith(color: palette.textPrimary))),
                ])),
      ]);
    }
    return Wrap(spacing: 16, runSpacing: 8, children: [
      for (final chart in widget.series)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(chart.bars ? Icons.bar_chart_rounded : Icons.show_chart_rounded,
              size: 16, color: chart.color ?? palette.primaryDeep),
          const SizedBox(width: 4),
          Text(chart.title,
              style: style.copyWith(color: chart.color ?? palette.primaryDeep)),
        ]),
    ]);
  }
}

class HourlyUvIconValue extends StatelessWidget {
  final String value;
  final Color color;
  final Key valueKey;
  const HourlyUvIconValue(
      {super.key,
      required this.value,
      required this.color,
      required this.valueKey});
  @override
  Widget build(BuildContext context) {
    final scale = math.min(MediaQuery.textScalerOf(context).scale(1), 1.3);
    return Semantics(
        label: '자외선지수 $value',
        child: Stack(alignment: Alignment.center, children: [
          Icon(Icons.wb_sunny_rounded, size: 40 * scale, color: color),
          Container(
              width: 22 * scale,
              height: 22 * scale,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          SizedBox(
              width: 22 * scale,
              height: 20 * scale,
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      key: valueKey,
                      style: TextStyle(
                          fontFamily: WeatherCareTheme.fontSuite,
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900)))),
        ]));
  }
}

/// 같은 단위는 같은 축, 양과 확률은 좌우 축을 사용한다.
class HourlyValueChart extends StatelessWidget {
  final HourlyChartSeries series;
  final List<HourlyChartSeries> overlays;
  final List<int> hours;
  final double pointWidth;
  final double height;
  final (double, double)? sharedBounds;
  final List<String?> conditions;
  final bool showValues;
  const HourlyValueChart(
      {super.key,
      required this.series,
      required this.hours,
      required this.pointWidth,
      this.overlays = const [],
      this.height = hourlyChartHeight,
      this.sharedBounds,
      this.conditions = const [],
      this.showValues = false});

  @override
  Widget build(BuildContext context) {
    final all = [series, ...overlays];
    final palette = WeatherCareTheme.of(context);
    final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(18);
    final labelStyle = TextStyle(
        fontFamily: WeatherCareTheme.fontSuite,
        fontSize: 12,
        fontWeight: FontWeight.w900);
    final temperature = sharedBounds != null;
    final bottomPadding =
        hourlyChartBottomPadding(all, sharedBounds, height, scaledLabelHeight);
    double x(int index) => (hours[index] - hours.first + .5) * pointWidth;
    double y(HourlyChartSeries chart, int index) => hourlyChartY(
        chart.values[index]!.upper ?? chart.values[index]!.lower,
        sharedBounds ?? chart.bounds,
        height,
        bottomPadding: bottomPadding);
    final labels = <Widget>[];
    final primaryTops = <int, double>{};
    for (final chart in all) {
      for (var index = 0; index < chart.values.length; index++) {
        final value = chart.values[index];
        if (!showValues || value == null) continue;
        final text = chart.labels.isNotEmpty
            ? chart.labels[index]!
            : '${formatWeatherNumber(value.lower)}${chart.unit == '지수' ? '' : chart.unit}';
        final bandColor = chart.bands
            .where((band) =>
                value.lower >= band.from &&
                (band.includeUpper
                    ? value.lower <= band.to
                    : value.lower < band.to))
            .firstOrNull
            ?.color;
        final textColor = bandColor ?? chart.color ?? palette.primaryDeep;
        final pointY = y(chart, index);
        if (chart.id == 'uv') {
          final scale =
              math.min(MediaQuery.textScalerOf(context).scale(1), 1.3);
          final width = 52 * scale;
          final badgeHeight = 44 * scale;
          labels.add(Positioned(
              key: ValueKey('hourly-label-${chart.id}-$index'),
              left: x(index) - width / 2,
              top: pointY - badgeHeight / 2,
              width: width,
              height: badgeHeight,
              child: HourlyUvIconValue(
                  value: text,
                  color: textColor,
                  valueKey: ValueKey('hourly-value-${chart.id}-$index'))));
          continue;
        }

        var top = temperature || chart.id.endsWith('-amount')
            ? pointY + 7
            : pointY - scaledLabelHeight - 6;
        final primaryTop = primaryTops[index];
        if (chart != series &&
            primaryTop != null &&
            (top - primaryTop).abs() < scaledLabelHeight + 4) {
          if (temperature) {
            top = math.max(top, primaryTop + scaledLabelHeight + 4);
          } else {
            top = math.min(pointY - scaledLabelHeight - 6,
                primaryTop - scaledLabelHeight - 4);
          }
        }
        top = top.clamp(0, height - scaledLabelHeight);
        if (chart == series) primaryTops[index] = top;
        final width = pointWidth - 6;
        labels.add(Positioned(
          key: ValueKey('hourly-label-${chart.id}-$index'),
          left: x(index) - width / 2,
          top: top,
          width: width,
          height: scaledLabelHeight,
          child: Center(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(text,
                      key: ValueKey('hourly-value-${chart.id}-$index'),
                      style: labelStyle.copyWith(color: textColor)))),
        ));
      }
    }
    return Column(children: [
      SizedBox(
          width: hourlyChartWidth(hours, pointWidth, all),
          height: height,
          child: Stack(clipBehavior: Clip.none, children: [
            Semantics(
                label:
                    '${all.map((chart) => chart.title).join('·')} 시간별 그래프, 가로축 시간',
                child: CustomPaint(
                    key: ValueKey('hourly-chart-${series.id}'),
                    size:
                        Size(hourlyChartWidth(hours, pointWidth, all), height),
                    painter: HourlyValueChartPainter(
                        series: series,
                        overlays: overlays,
                        hours: hours,
                        pointWidth: pointWidth,
                        bottomPadding: bottomPadding,
                        sharedBounds: sharedBounds,
                        color: palette.primaryDeep,
                        gridColor: palette.primaryBorder))),
            ...labels,
            for (var index = 0; index < conditions.length; index++)
              if (conditions[index] != null && series.values[index] != null)
                Positioned(
                    left: x(index) - 12,
                    top: y(series, index) - 34,
                    child: IgnorePointer(
                        child: WeatherConditionIcon(
                            condition: conditions[index],
                            size: 24,
                            color: palette.primaryDeep))),
          ])),
    ]);
  }
}

class HourlyValueChartPainter extends CustomPainter {
  final HourlyChartSeries series;
  final List<HourlyChartSeries> overlays;
  final List<int> hours;
  final double pointWidth;
  final Color color;
  final Color gridColor;
  final (double, double)? sharedBounds;
  final double bottomPadding;
  const HourlyValueChartPainter(
      {required this.series,
      required this.hours,
      required this.pointWidth,
      required this.color,
      required this.gridColor,
      this.overlays = const [],
      this.sharedBounds,
      this.bottomPadding = _plotBottom});

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = sharedBounds ?? series.bounds;
    double y(double value) =>
        hourlyChartY(value, bounds, size.height, bottomPadding: bottomPadding);
    double x(int index) => (hours[index] - hours.first + .5) * pointWidth;
    for (final band in series.bands) {
      canvas.drawRect(
          Rect.fromLTRB(0, y(band.to.clamp(bounds.$1, bounds.$2)), size.width,
              y(band.from.clamp(bounds.$1, bounds.$2))),
          Paint()..color = band.color.withValues(alpha: .16));
    }
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = .7;
    for (final value in _axisTicks(series, bounds)) {
      final at = y(value);
      canvas.drawLine(Offset(0, at), Offset(size.width, at), grid);
    }
    final intervalTimeline =
        [series, ...overlays].any((chart) => chart.intervals);
    for (var hour = hours.first;
        hour <= hours.last + (intervalTimeline ? 1 : 0);
        hour++) {
      final at =
          (hour - hours.first + (intervalTimeline ? 0 : .5)) * pointWidth;
      canvas.drawLine(
          Offset(at, _plotTop), Offset(at, size.height - bottomPadding), grid);
    }
    // 확률 막대를 먼저 그리고 정량 선을 위에 올린다.
    final charts = [
      ...overlays.where((chart) => chart.bars),
      series,
      ...overlays.where((chart) => !chart.bars)
    ];
    for (final chart in charts) {
      final chartBounds = sharedBounds ?? chart.bounds;
      double chartY(double value) =>
          hourlyChartY(value, chartBounds, size.height,
              bottomPadding: bottomPadding);
      final chartColor = chart.color ?? color;
      final stroke = Paint()
        ..color = chartColor
        ..strokeWidth = 2.5;
      Offset? previous;
      int? previousHour;
      for (var index = 0; index < chart.values.length; index++) {
        final value = chart.values[index];
        if (value == null) {
          previous = null;
          previousHour = null;
          continue;
        }
        final at = Offset(x(index), chartY(value.lower));
        if (value.range) {
          previous = null;
          previousHour = null;
          final top = chartY(value.upper ?? chartBounds.$2);
          canvas.drawRect(Rect.fromLTRB(at.dx - 8, top, at.dx + 8, at.dy),
              Paint()..color = chartColor.withValues(alpha: .25));
          canvas.drawLine(Offset(at.dx, top), at, stroke);
          canvas.drawLine(
              Offset(at.dx - 6, at.dy), Offset(at.dx + 6, at.dy), stroke);
          canvas.drawLine(
              Offset(at.dx - 6, top), Offset(at.dx + 6, top), stroke);
        } else if (chart.bars) {
          final barColor = chart.bands
                  .where((band) =>
                      value.lower >= band.from &&
                      (band.includeUpper
                          ? value.lower <= band.to
                          : value.lower < band.to))
                  .firstOrNull
                  ?.color ??
              chartColor;
          canvas.drawRect(
              Rect.fromLTRB(at.dx - pointWidth * .28, at.dy,
                  at.dx + pointWidth * .28, math.max(at.dy + 2, chartY(0))),
              Paint()
                ..color =
                    barColor.withValues(alpha: overlays.isEmpty ? 1 : .65));
        } else {
          if (previous != null && hours[index] - previousHour! == 1) {
            canvas.drawLine(previous, at, stroke);
          }
          canvas.drawCircle(at, 3.5, Paint()..color = chartColor);
          previous = at;
          previousHour = hours[index];
        }
      }
    }
  }

  @override
  bool shouldRepaint(HourlyValueChartPainter oldDelegate) =>
      series != oldDelegate.series ||
      overlays != oldDelegate.overlays ||
      hours != oldDelegate.hours ||
      pointWidth != oldDelegate.pointWidth ||
      color != oldDelegate.color ||
      gridColor != oldDelegate.gridColor ||
      sharedBounds != oldDelegate.sharedBounds ||
      bottomPadding != oldDelegate.bottomPadding;
}
