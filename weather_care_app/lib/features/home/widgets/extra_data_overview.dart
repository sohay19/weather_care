import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';
import '../../../utils/weather_number.dart';
import 'extra_chip_row.dart';
import 'data_range_tile.dart';

/// 저장된 시각과 값만 그린다. 결측을 0으로 바꾸거나 시각 간격을 균등화하지 않는다.
class ExtraDataOverview extends StatefulWidget {
  final List<Map<String, dynamic>> records;
  final String source;
  final String targetName;
  final String Function(String) labelFor;
  final String Function(String) unitFor;
  final DateTime? Function(Object?) timeFor;
  final String Function(String) timeLabel;
  final Key? currentKey;

  const ExtraDataOverview({
    super.key,
    required this.records,
    required this.source,
    required this.targetName,
    required this.labelFor,
    required this.unitFor,
    required this.timeFor,
    required this.timeLabel,
    this.currentKey,
  });

  @override
  State<ExtraDataOverview> createState() => _ExtraDataOverviewState();
}

class _ExtraDataOverviewState extends State<ExtraDataOverview> {
  String? _metric;
  int? _selected;

  @override
  void didUpdateWidget(covariant ExtraDataOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.records != widget.records) _selected = null;
  }

  Map<String, dynamic> _values(Map<String, dynamic> record) =>
      Map<String, dynamic>.from(record['values'] as Map? ?? {});

  double? _number(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    final records = widget.records
        .where((record) => widget.timeFor(record['time']) != null)
        .toList()
      ..sort((a, b) => widget
          .timeLabel('${a['time']}')
          .compareTo(widget.timeLabel('${b['time']}')));
    final metrics = <String>{};
    for (final record in records) {
      for (final entry in _values(record).entries) {
        if (_number(entry.value) != null &&
            !['latitude', 'longitude', 'currentDirectionDeg']
                .contains(entry.key)) {
          metrics.add(entry.key);
        }
      }
    }
    if (metrics.isEmpty) return const SizedBox.shrink();
    final metric = metrics.contains(_metric) ? _metric! : metrics.first;
    final selected =
        (_selected ?? records.length - 1).clamp(0, records.length - 1);
    final times =
        records.map((record) => widget.timeFor(record['time'])!).toList();
    final values =
        records.map((record) => _number(_values(record)[metric])).toList();
    final known = values.whereType<double>().toList();
    final low = known.reduce(math.min);
    final high = known.reduce(math.max);
    final bars = metric == 'count' || metric == 'rainfallMm';
    final padding =
        math.max((high - low) * .15, math.max(high.abs() * .02, .1));
    final minY = bars ? math.min(0.0, low) : low - padding;
    final maxY = bars ? math.max(1.0, high * 1.15) : high + padding;
    final unit = widget.unitFor(metric);
    final title = widget.labelFor(metric);
    final selectedLabel = widget.timeLabel('${records[selected]['time']}');
    final selectedClock = '${times[selected].hour.toString().padLeft(2, '0')}:'
        '${times[selected].minute.toString().padLeft(2, '0')}';
    const chartHeight = 256.0;
    final forecast = ['KHOA_TIDE_HOURLY', 'KHOA_TIDE_EXTREME', 'KHOA_ROMS']
        .contains(widget.source);
    final connect =
        !bars && widget.source != 'KHOA_TIDE_EXTREME' && metric != 'riskIndex';

    void selectAt(double fraction) {
      final at = times.first.millisecondsSinceEpoch +
          (times.last.millisecondsSinceEpoch -
                  times.first.millisecondsSinceEpoch) *
              fraction.clamp(0, 1);
      var closest = 0;
      for (var i = 1; i < times.length; i++) {
        if ((times[i].millisecondsSinceEpoch - at).abs() <
            (times[closest].millisecondsSinceEpoch - at).abs()) {
          closest = i;
        }
      }
      setState(() => _selected = closest);
    }

    return Container(
      key: const ValueKey('extra-data-overview'),
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.primarySoft, palette.surface]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.primaryBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(forecast ? Icons.insights_rounded : Icons.sensors_rounded,
              color: palette.primaryDeep, size: 19),
          const SizedBox(width: 7),
          Expanded(
              child: Text(widget.targetName,
                  style: TextStyle(
                      color: palette.primaryDeep,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(forecast ? '예측 자료' : '관측 자료',
                  style: TextStyle(color: palette.primaryDeep, fontSize: 11))),
        ]),
        const SizedBox(height: 18),
        ExtraChipRow(children: [
          for (final key in metrics)
            ChoiceChip(
                key: ValueKey('extra-metric-$key'),
                label: Text(widget.labelFor(key),
                    style: const TextStyle(
                        fontFamily: WeatherCareTheme.fontSuite)),
                selectedColor: palette.primaryDeep,
                backgroundColor: palette.surfaceMuted,
                labelStyle: TextStyle(
                    color: metric == key
                        ? palette.onPrimary
                        : palette.textPrimary),
                selected: metric == key,
                showCheckmark: false,
                onSelected: (_) => setState(() => _metric = key)),
        ]),
        const SizedBox(height: 14),
        Container(
            key: const ValueKey('extra-current'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: palette.primarySoft,
                borderRadius: BorderRadius.circular(16)),
            child: Column(
                key: widget.currentKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        flex: 3,
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('${forecast ? '예측' : '관측'} · $title',
                                style:
                                    Theme.of(context).textTheme.titleMedium))),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 2,
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text('기준 시간 · $selectedClock',
                                key: const ValueKey('extra-selected-time'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontSize: 10)))),
                  ]),
                  const SizedBox(height: 4),
                  Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: values[selected] == null
                                ? '자료 없음'
                                : formatWeatherNumber(values[selected]!),
                            style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                fontFamily: WeatherCareTheme.fontSuite)),
                        if (values[selected] != null)
                          TextSpan(
                              text: ' $unit',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500)),
                      ]),
                      key: const ValueKey('extra-selected-value'),
                      style: TextStyle(color: palette.primaryDeep)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: DataRangeTile(
                            label: '최저',
                            value: '${formatWeatherNumber(low)}$unit')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: DataRangeTile(
                            label: '최고',
                            value: '${formatWeatherNumber(high)}$unit')),
                  ]),
                ])),
        const SizedBox(height: 16),
        Text('$title${unit.isEmpty ? '' : ' ($unit)'} · ${known.length}개 시점',
            style: TextStyle(color: palette.textSecondary, fontSize: 11)),
        const SizedBox(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 46,
              height: chartHeight,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatWeatherNumber(maxY),
                        style: TextStyle(
                            color: palette.textSecondary, fontSize: 10)),
                    Text(formatWeatherNumber((minY + maxY) / 2),
                        style: TextStyle(
                            color: palette.textSecondary, fontSize: 10)),
                    Text(formatWeatherNumber(minY),
                        style: TextStyle(
                            color: palette.textSecondary, fontSize: 10)),
                  ])),
          Expanded(
              child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                        onTapDown: (event) => selectAt(
                            event.localPosition.dx / constraints.maxWidth),
                        onHorizontalDragUpdate: (event) => selectAt(
                            event.localPosition.dx / constraints.maxWidth),
                        child: Semantics(
                          image: true,
                          label: '$title 시간별 ${bars ? '막대' : '추이'} 그래프. '
                              '최저 ${formatWeatherNumber(low)}$unit, 최고 ${formatWeatherNumber(high)}$unit. 아래에서 시각을 선택할 수 있어요.',
                          child: CustomPaint(
                              key: ValueKey('extra-chart-$metric'),
                              size: const Size(double.infinity, chartHeight),
                              painter: _ExtraChartPainter(
                                  times: times,
                                  values: values,
                                  minY: minY,
                                  maxY: maxY,
                                  selected: selected,
                                  bars: bars,
                                  connect: connect,
                                  color: palette.primary,
                                  gridColor: palette.primaryBorder,
                                  surface: palette.surface)),
                        ),
                      ))),
        ]),
        const SizedBox(height: 8),
        Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(
                          widget
                              .timeLabel('${records.first['time']}')
                              .replaceFirst(' ', '\n'),
                          key: const ValueKey('extra-chart-start-time'),
                          style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 10,
                              fontFamily: WeatherCareTheme.fontSuite,
                              fontWeight: FontWeight.w800))),
                  if (records.length > 1)
                    Expanded(
                        child: Text(
                            widget
                                .timeLabel('${records.last['time']}')
                                .replaceFirst(' ', '\n'),
                            key: const ValueKey('extra-chart-end-time'),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 10,
                                fontFamily: WeatherCareTheme.fontSuite,
                                fontWeight: FontWeight.w800))),
                ])),
        if (records.length > 1)
          Slider(
            key: const ValueKey('extra-chart-time-slider'),
            value: selected.toDouble(),
            min: 0,
            max: (records.length - 1).toDouble(),
            divisions: records.length - 1,
            label:
                '$selectedLabel · ${values[selected] == null ? '자료 없음' : '${formatWeatherNumber(values[selected]!)}$unit'}',
            onChanged: (value) => setState(() => _selected = value.round()),
          )
        else
          const SizedBox(height: 12),
      ]),
    );
  }
}

class _ExtraChartPainter extends CustomPainter {
  final List<DateTime> times;
  final List<double?> values;
  final double minY, maxY;
  final int selected;
  final bool bars, connect;
  final Color color, gridColor, surface;

  _ExtraChartPainter(
      {required this.times,
      required this.values,
      required this.minY,
      required this.maxY,
      required this.selected,
      required this.bars,
      required this.connect,
      required this.color,
      required this.gridColor,
      required this.surface});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 7.0;
    final span =
        times.last.millisecondsSinceEpoch - times.first.millisecondsSinceEpoch;
    double x(int i) => span == 0
        ? size.width / 2
        : inset +
            (times[i].millisecondsSinceEpoch -
                    times.first.millisecondsSinceEpoch) /
                span *
                (size.width - inset * 2);
    double y(double value) =>
        inset + (maxY - value) / (maxY - minY) * (size.height - inset * 2);
    final grid = Paint()
      ..color = gridColor.withValues(alpha: .6)
      ..strokeWidth = 1;
    for (final value in [minY, (minY + maxY) / 2, maxY]) {
      canvas.drawLine(Offset(0, y(value)), Offset(size.width, y(value)), grid);
    }
    final intervals = <int>[
      for (var i = 1; i < times.length; i++)
        if (times[i].isAfter(times[i - 1]))
          times[i].difference(times[i - 1]).inMilliseconds
    ]..sort();
    final typicalGap =
        intervals.isEmpty ? 0 : intervals[(intervals.length - 1) ~/ 2];
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final barWidth =
        math.min(14.0, (size.width - inset * 2) / (times.length * 1.5));
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) continue;
      final point = Offset(x(i), y(value));
      if (bars) {
        final zero = y(0);
        if (value == 0) {
          canvas.drawCircle(Offset(x(i), zero), 2, stroke);
        } else {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTRB(x(i) - barWidth / 2, math.min(point.dy, zero),
                      x(i) + barWidth / 2, math.max(point.dy, zero)),
                  const Radius.circular(3)),
              Paint()
                ..color = color.withValues(alpha: i == selected ? 1 : .45));
        }
      } else {
        if (connect &&
            i > 0 &&
            values[i - 1] != null &&
            times[i].difference(times[i - 1]).inMilliseconds <=
                typicalGap * 1.5) {
          canvas.drawLine(Offset(x(i - 1), y(values[i - 1]!)), point, stroke);
        }
        canvas.drawCircle(point, i == selected ? 4 : 2.5, stroke);
      }
      if (i == selected) {
        canvas.drawCircle(
            point, 8, Paint()..color = color.withValues(alpha: .18));
        canvas.drawCircle(point, 4, Paint()..color = surface);
        canvas.drawCircle(point, 2.5, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ExtraChartPainter oldDelegate) =>
      oldDelegate.times != times ||
      oldDelegate.values != values ||
      oldDelegate.selected != selected ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.surface != surface ||
      oldDelegate.bars != bars ||
      oldDelegate.connect != connect ||
      oldDelegate.minY != minY ||
      oldDelegate.maxY != maxY;
}
