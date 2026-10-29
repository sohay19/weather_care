import 'dart:math' as math;
import 'dart:ui' show ClipOp;

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
  final List<double> xOffsets;

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
    this.xOffsets = const [],
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
const detailedHourlyChartHeight = 320.0;
const hourlyChartTitleHeight = 30.0;
const hourlyChartGap = 4.0;
const _plotTop = 48.0;
const _plotBottom = 20.0;

// 상한 없는 신적설은 수직 범위 표시 대신 하한 위치의 점을 사용한다.
bool _snowLowerBoundPoint(HourlyChartSeries chart, HourlyChartValue value) =>
    chart.id == 'snow-amount' && value.range && value.upper == null;

double hourlyChartWidth(
        List<int> hours, double pointWidth, List<HourlyChartSeries> series) =>
    (hours.last -
        hours.first +
        1 +
        (series.any((chart) => chart.intervals) ? .5 : 0)) *
    pointWidth;

double hourlyChartY(double value, (double, double) bounds, double height,
        {double topPadding = _plotTop, double bottomPadding = _plotBottom}) =>
    topPadding +
    (bounds.$2 - value) /
        (bounds.$2 - bounds.$1) *
        (height - topPadding - bottomPadding);

// 점 간격 8 + 날씨 아이콘 24 + 아이콘/수치 간격 10을 확보한다.
double hourlyChartTopPadding((double, double)? bounds, double labelHeight) =>
    bounds == null ? _plotTop : math.max(_plotTop, labelHeight + 42);

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
  final belowHeight = series.length > 1
      ? math.max(labelHeight * 2 + 12, labelHeight + 42)
      : labelHeight * 2 + 12;
  return math.max(
      _plotBottom,
      (belowHeight -
              fraction *
                  (height - hourlyChartTopPadding(bounds, labelHeight))) /
          (1 - fraction));
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
  final double topPadding;
  final double bottomPadding;
  const HourlyChartAxis(
      {super.key,
      required this.series,
      this.title,
      this.height = hourlyChartHeight,
      this.sharedBounds,
      this.right = false,
      this.topPadding = _plotTop,
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
                top: topPadding - hourlyChartTitleHeight - 16,
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
                          topPadding: topPadding,
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
  final bool avoidLineOverlaps;
  const HourlyValueChart(
      {super.key,
      required this.series,
      required this.hours,
      required this.pointWidth,
      this.overlays = const [],
      this.height = hourlyChartHeight,
      this.sharedBounds,
      this.conditions = const [],
      this.avoidLineOverlaps = false,
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
    final temperature = sharedBounds != null && series.unit == '°C';
    final topPadding = hourlyChartTopPadding(sharedBounds, scaledLabelHeight);
    final bottomPadding =
        hourlyChartBottomPadding(all, sharedBounds, height, scaledLabelHeight);
    double x(HourlyChartSeries chart, int index) =>
        (hours[index] -
            hours.first +
            .5 +
            (chart.xOffsets.elementAtOrNull(index) ?? 0)) *
        pointWidth;
    double y(HourlyChartSeries chart, int index) => hourlyChartY(
        chart.values[index]!.upper ?? chart.values[index]!.lower,
        sharedBounds != null && chart.unit == series.unit
            ? sharedBounds!
            : chart.bounds,
        height,
        topPadding: topPadding,
        bottomPadding: bottomPadding);
    final labels = <Widget>[];
    final occupied = <Rect>[];
    final geometry = _ChartGeometry();
    final barRects = <(HourlyChartSeries, int), Rect>{};
    final leaders = <(Offset, Offset, Color)>[];
    final chartWidth = hourlyChartWidth(hours, pointWidth, all);
    final iconRects = <int, Rect>{};
    final barHalfWidth = pointWidth * .28;
    // 페인터와 같은 좌표로 점·선분·범위·막대 전체를 검사한다.
    for (final chart in all) {
      final bounds = sharedBounds != null && chart.unit == series.unit
          ? sharedBounds!
          : chart.bounds;
      double chartY(double value) => hourlyChartY(value, bounds, height,
          topPadding: topPadding, bottomPadding: bottomPadding);
      for (var i = 0; i < chart.values.length; i++) {
        final value = chart.values[i];
        if (value == null) continue;
        final at = Offset(x(chart, i), chartY(value.lower));
        if (value.range && !_snowLowerBoundPoint(chart, value)) {
          geometry.rects.add(Rect.fromLTRB(
              at.dx - 8, chartY(value.upper ?? bounds.$2), at.dx + 8, at.dy));
        } else if (chart.bars) {
          final bar = Rect.fromLTRB(at.dx - barHalfWidth, at.dy,
              at.dx + barHalfWidth, math.max(at.dy + 2, chartY(0)));
          geometry.bars.add(bar);
          barRects[(chart, i)] = bar;
        } else {
          geometry.rects.add(Rect.fromCircle(center: at, radius: 3.5));
          if (i > 0 &&
              (!value.range || _snowLowerBoundPoint(chart, value)) &&
              chart.values[i - 1] != null &&
              (!chart.values[i - 1]!.range ||
                  _snowLowerBoundPoint(chart, chart.values[i - 1]!)) &&
              hours[i] - hours[i - 1] == 1) {
            geometry.lines.add((
              Offset(x(chart, i - 1), chartY(chart.values[i - 1]!.lower)),
              at
            ));
          }
        }
      }
    }

    // 확률은 막대 위에 놓고 충돌할 때만 자기 막대 내부를 찾는다.
    for (final chart in [
      ...all.where((chart) => !chart.bars),
      ...all.where((chart) => chart.bars)
    ]) {
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
              left: x(chart, index) - width / 2,
              top: pointY - badgeHeight / 2,
              width: width,
              height: badgeHeight,
              child: HourlyUvIconValue(
                  value: text,
                  color: textColor,
                  valueKey: ValueKey('hourly-value-${chart.id}-$index'))));
          continue;
        }

        final hasIcon = chart == series &&
            index < conditions.length &&
            conditions[index] != null;
        final iconHeight = hasIcon ? 34.0 : 0.0;
        final groupHeight = scaledLabelHeight + iconHeight;
        final ownBar =
            chart.bars && all.length > 1 ? barRects[(chart, index)] : null;
        final insideOwnBar =
            ownBar != null && ownBar.height >= groupHeight + 12;
        bool? above = chart.bars && !insideOwnBar ? true : null;
        if (temperature) {
          final present =
              all.where((other) => other.values[index] != null).toList()
                ..sort((a, b) {
                  final order = y(a, index).compareTo(y(b, index));
                  return order != 0
                      ? order
                      : all.indexOf(a).compareTo(all.indexOf(b));
                });
          above = present.length > 1 ? chart == present.first : chart == series;
        }
        var top = chart.bars ||
                above == true ||
                (above == null && !chart.id.endsWith('-amount'))
            ? pointY - groupHeight - 8
            : pointY + 8;
        if (avoidLineOverlaps) {
          top = chart == series ? pointY - groupHeight - 8 : pointY + 8;
        }
        final measure = TextPainter(
            text: TextSpan(text: text, style: labelStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context))
          ..layout();
        final width = math.max(
            hasIcon ? 24.0 : 0.0, math.min(pointWidth - 6, measure.width + 2));
        measure.dispose();
        final anchor = Offset(x(chart, index), pointY);
        final group = geometry.place(
            anchor: anchor,
            preferredTop: top,
            labelSize: Size(width, groupHeight),
            above: above,
            allowBarInterior: !chart.bars,
            ownBar: ownBar,
            canvasSize: Size(chartWidth, height),
            pointWidth: pointWidth,
            occupied: occupied);
        occupied.add(group);
        if (hasIcon) {
          iconRects[index] =
              Rect.fromLTWH(group.center.dx - 12, group.top, 24, 24);
        }
        final rect = Rect.fromLTWH(
            group.left, group.top + iconHeight, width, scaledLabelHeight);
        final insideBar = geometry.bars.any((bar) => rect.overlaps(bar));
        top = rect.top;
        final end = Offset(anchor.dx.clamp(rect.left, rect.right),
            anchor.dy.clamp(rect.top, rect.bottom));
        if ((anchor - end).distance > 12) {
          leaders.add((anchor, end, textColor));
        }
        labels.add(Positioned(
          key: ValueKey('hourly-label-${chart.id}-$index'),
          left: rect.left,
          top: top,
          width: width,
          height: scaledLabelHeight,
          child: Center(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(text,
                      key: ValueKey('hourly-value-${chart.id}-$index'),
                      style: labelStyle.copyWith(
                          color: textColor,
                          // 계열 색은 유지하고 글자 둘레만 대비를 높인다.
                          shadows: insideBar
                              ? [
                                  for (final offset in const [
                                    Offset(-1, 0),
                                    Offset(1, 0),
                                    Offset(0, -1),
                                    Offset(0, 1)
                                  ])
                                    Shadow(
                                        color: palette.surface,
                                        blurRadius: 2,
                                        offset: offset)
                                ]
                              : null)))),
        ));
      }
    }
    return Column(children: [
      SizedBox(
          width: hourlyChartWidth(hours, pointWidth, all),
          height: occupied.fold<double>(
              height, (bottom, rect) => math.max(bottom, rect.bottom)),
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
                        topPadding: topPadding,
                        bottomPadding: bottomPadding,
                        leaders: leaders,
                        labelRects: occupied,
                        sharedBounds: sharedBounds,
                        color: palette.primaryDeep,
                        gridColor: palette.primaryBorder))),
            ...labels,
            for (var index = 0; index < conditions.length; index++)
              if (conditions[index] != null && series.values[index] != null)
                Positioned(
                    left: iconRects[index]?.left ?? x(series, index) - 12,
                    top: iconRects[index]?.top ?? y(series, index) - 34,
                    child: IgnorePointer(
                        child: WeatherConditionIcon(
                            condition: conditions[index],
                            size: 24,
                            color: palette.primaryDeep))),
          ])),
    ]);
  }
}

/// 수치는 같은 시간 열 안에서만 옮긴다. 배경으로 그래프를 지우지 않는다.
class _ChartGeometry {
  final rects = <Rect>[];
  final bars = <Rect>[];
  final lines = <(Offset, Offset)>[];

  bool clear(Rect rect, {required bool allowBarInterior, Rect? ownBar}) {
    final padded = rect.inflate(4);
    return (allowBarInterior ||
            bars.every(
                (bar) => identical(bar, ownBar) || !padded.overlaps(bar))) &&
        rects.every((obstacle) => !padded.overlaps(obstacle)) &&
        lines.every((line) => !_crosses(padded, line.$1, line.$2));
  }

  static bool _crosses(Rect rect, Offset a, Offset b) {
    if (math.max(a.dx, b.dx) < rect.left ||
        math.min(a.dx, b.dx) > rect.right ||
        math.max(a.dy, b.dy) < rect.top ||
        math.min(a.dy, b.dy) > rect.bottom) {
      return false;
    }
    var start = 0.0, end = 1.0;
    for (final axis in [
      (a.dx, b.dx - a.dx, rect.left, rect.right),
      (a.dy, b.dy - a.dy, rect.top, rect.bottom)
    ]) {
      if (axis.$2.abs() < .0001) {
        if (axis.$1 < axis.$3 || axis.$1 > axis.$4) return false;
      } else {
        final first = (axis.$3 - axis.$1) / axis.$2;
        final last = (axis.$4 - axis.$1) / axis.$2;
        start = math.max(start, math.min(first, last));
        end = math.min(end, math.max(first, last));
        if (start > end) return false;
      }
    }
    return true;
  }

  Rect place({
    required Offset anchor,
    required double preferredTop,
    required Size labelSize,
    required Size canvasSize,
    required double pointWidth,
    required List<Rect> occupied,
    bool? above,
    bool allowBarInterior = false,
    Rect? ownBar,
  }) {
    Rect rectAt(double dx, double top) => Rect.fromLTWH(
        (anchor.dx + dx - labelSize.width / 2)
            .clamp(0, canvasSize.width - labelSize.width),
        top,
        labelSize.width,
        labelSize.height);
    bool fits(Rect rect) =>
        rect.top >= 0 &&
        rect.bottom <= canvasSize.height &&
        (above == null ||
            (above ? rect.bottom < anchor.dy - 4 : rect.top > anchor.dy + 4)) &&
        (ownBar == null ||
            !rect.overlaps(ownBar) ||
            ownBar.contains(rect.topLeft) &&
                ownBar.contains(rect.bottomRight)) &&
        clear(rect, allowBarInterior: allowBarInterior, ownBar: ownBar) &&
        occupied.every((other) => !rect.inflate(3).overlaps(other));

    final preferred = rectAt(0, preferredTop);
    if ((preferred.center - anchor).distance <= labelSize.height / 2 + 12 &&
        fits(preferred)) {
      return preferred;
    }
    Rect? best;
    Rect? bestInside;
    var bestDistance = double.infinity;
    var bestInsideDistance = double.infinity;
    // 작은 가로 이동으로 막대를 피할 수 있으면 멀리 위아래로 보내지 않는다.
    for (final dx in [
      0.0,
      -pointWidth * .25,
      pointWidth * .25,
      -pointWidth * .46,
      pointWidth * .46
    ]) {
      for (var top = 0.0;
          top <= canvasSize.height - labelSize.height;
          top += 2) {
        final rect = rectAt(dx, top);
        final distance = (rect.center - anchor).distanceSquared +
            (top - preferredTop).abs() * 2;
        final inside = ownBar != null &&
            ownBar.contains(rect.topLeft) &&
            ownBar.contains(rect.bottomRight);
        if (distance >= bestDistance &&
            (!inside || distance >= bestInsideDistance)) {
          continue;
        }
        if (!fits(rect)) continue;
        if (distance < bestDistance) {
          best = rect;
          bestDistance = distance;
        }
        if (inside && distance < bestInsideDistance) {
          bestInside = rect;
          bestInsideDistance = distance;
        }
      }
    }
    if (bestInside != null) return bestInside;
    if (best != null) return best;
    // 열 안이 모두 찬 경우 같은 시각 아래에 공간을 추가한다. 값을 숨기거나
    // 기존 그래프 위에 강제로 겹쳐 그리지 않고 연결선으로 원점을 표시한다.
    var footer = rectAt(0, canvasSize.height + 4);
    while (occupied.any((other) => footer.inflate(3).overlaps(other))) {
      footer = footer.shift(Offset(0, labelSize.height + 6));
    }
    return footer;
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
  final double topPadding;
  final double bottomPadding;
  final List<(Offset, Offset, Color)> leaders;
  final List<Rect> labelRects;
  const HourlyValueChartPainter(
      {required this.series,
      required this.hours,
      required this.pointWidth,
      required this.color,
      required this.gridColor,
      this.overlays = const [],
      this.sharedBounds,
      this.leaders = const [],
      this.labelRects = const [],
      this.topPadding = _plotTop,
      this.bottomPadding = _plotBottom});

  double get barHalfWidth => pointWidth * .28;

  @override
  void paint(Canvas canvas, Size size) {
    // 안내선은 원본 그래프 뒤에 그려 선·점·막대를 가리지 않는다.
    canvas.save();
    for (final rect in labelRects) {
      canvas.clipRect(rect.inflate(2), clipOp: ClipOp.difference);
    }
    for (final leader in leaders) {
      final delta = leader.$2 - leader.$1;
      final distance = delta.distance;
      final paint = Paint()
        ..color = leader.$3.withValues(alpha: .65)
        ..strokeWidth = 1;
      for (var start = 4.0; start < distance; start += 5) {
        canvas.drawLine(
            leader.$1 + delta * (start / distance),
            leader.$1 + delta * (math.min(start + 2, distance) / distance),
            paint);
      }
    }
    canvas.restore();
    final bounds = sharedBounds ?? series.bounds;
    double y(double value) => hourlyChartY(value, bounds, size.height,
        topPadding: topPadding, bottomPadding: bottomPadding);
    double x(HourlyChartSeries chart, int index) =>
        (hours[index] -
            hours.first +
            .5 +
            (chart.xOffsets.elementAtOrNull(index) ?? 0)) *
        pointWidth;
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
      canvas.drawLine(Offset(at, topPadding),
          Offset(at, size.height - bottomPadding), grid);
    }
    // 확률 막대를 먼저 그리고 정량 선을 위에 올린다.
    final charts = [
      ...overlays.where((chart) => chart.bars),
      series,
      ...overlays.where((chart) => !chart.bars)
    ];
    for (final chart in charts) {
      final chartBounds = sharedBounds != null && chart.unit == series.unit
          ? sharedBounds!
          : chart.bounds;
      double chartY(double value) =>
          hourlyChartY(value, chartBounds, size.height,
              topPadding: topPadding, bottomPadding: bottomPadding);
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
        final at = Offset(x(chart, index), chartY(value.lower));
        if (value.range && !_snowLowerBoundPoint(chart, value)) {
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
              Rect.fromLTRB(at.dx - barHalfWidth, at.dy, at.dx + barHalfWidth,
                  math.max(at.dy + 2, chartY(0))),
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
      topPadding != oldDelegate.topPadding ||
      bottomPadding != oldDelegate.bottomPadding ||
      leaders != oldDelegate.leaders ||
      labelRects != oldDelegate.labelRects;
}
