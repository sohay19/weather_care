import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/briefing_time.dart';
import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../../../utils/korea_date.dart';
import '../weather_labels.dart';
import '../weather_data_phase.dart';
import 'home_section_header.dart';
import 'missing_data_retry.dart';
import 'weather_condition_icon.dart';

enum _HourlyMetric { weather, precipitation, snowfall, uv, wind, humidity }

const _timeLabelHeight = 28.0;
const _timeDotGap = 3.0;

class HourlyForecastSection extends StatefulWidget {
  final String keyPrefix;
  final List<HourlyWeatherItem> items;
  final String? generatedAt;
  final DateTime? receivedAt;
  final DateTime? now;
  final String? targetDate;
  final bool availableOnly;
  final bool inline;
  final WeatherDataPhase dataPhase;
  final Future<void> Function()? onRetryMissingData;
  final bool retrying;

  const HourlyForecastSection({
    super.key,
    this.keyPrefix = 'today',
    required this.items,
    this.generatedAt,
    this.receivedAt,
    this.now,
    this.targetDate,
    this.availableOnly = false,
    this.inline = false,
    this.dataPhase = WeatherDataPhase.ready,
    this.onRetryMissingData,
    this.retrying = false,
  });

  @override
  State<HourlyForecastSection> createState() => _HourlyForecastSectionState();
}

class _HourlyForecastSectionState extends State<HourlyForecastSection> {
  _HourlyMetric _selected = _HourlyMetric.weather;

  @override
  Widget build(BuildContext context) {
    final today = widget.targetDate ??
        dateInKorea(responseNow(
          widget.now ?? DateTime.now(),
          generatedAt: widget.generatedAt,
          receivedAt: widget.receivedAt,
        ));
    final hourlyByHour = <int, HourlyWeatherItem>{};
    final precipitationByHour = <int, HourlyWeatherItem>{};
    final snowfallByHour = <int, HourlyWeatherItem>{};
    for (final item in widget.items) {
      final hour = int.tryParse(item.time);
      final isToday = item.forecastDate == today ||
          (widget.targetDate == null && item.forecastDate == null);
      if (isToday && hour != null && hour >= 0 && hour < 24) {
        hourlyByHour.putIfAbsent(hour, () => item);
      }
      final period = item.precipitationPeriod;
      if (period != null && period.date == today) {
        final startHour =
            period.start.toUtc().add(const Duration(hours: 9)).hour;
        final previous = precipitationByHour[startHour];
        if (previous == null ||
            !_hasValue(_HourlyMetric.precipitation, previous)) {
          precipitationByHour[startHour] = item;
        }
        snowfallByHour.putIfAbsent(startHour, () => item);
      } else if (period == null &&
          !widget.availableOnly &&
          isToday &&
          hour != null &&
          hour >= 0 &&
          hour < 24) {
        final previous = precipitationByHour[hour];
        if (previous == null ||
            !_hasValue(_HourlyMetric.precipitation, previous)) {
          precipitationByHour[hour] = item;
        }
        snowfallByHour.putIfAbsent(hour, () => item);
      }
    }
    final emptySlots = [
      for (var hour = 0; hour < 24; hour++)
        HourlyWeatherItem(
          time: hour.toString().padLeft(2, '0'),
          forecastDate: today,
          temperature: null,
          precipitationProbability: null,
          precipitationAmount: null,
          snowExpected: null,
          snowfallAmount: null,
          windSpeed: null,
          skyCondition: null,
        ),
    ];
    Map<int, HourlyWeatherItem> itemsFor(_HourlyMetric metric) =>
        switch (metric) {
          _HourlyMetric.precipitation => precipitationByHour,
          _HourlyMetric.snowfall => snowfallByHour,
          _ => hourlyByHour,
        };
    final availableMetrics = [
      for (final metric in _HourlyMetric.values)
        if (!widget.availableOnly ||
            itemsFor(metric).values.any((item) => _hasValue(metric, item)))
          metric,
    ];
    if (availableMetrics.isEmpty) return const SizedBox.shrink();
    final selected = availableMetrics.contains(_selected)
        ? _selected
        : availableMetrics.first;
    final selectedItems = <HourlyWeatherItem>[];
    for (var hour = 0; hour < 24; hour++) {
      final item = itemsFor(selected)[hour];
      if (widget.availableOnly) {
        if (item != null && _hasValue(selected, item)) selectedItems.add(item);
      } else {
        selectedItems.add(item ?? emptySlots[hour]);
      }
    }
    final hasMissingData = hourlyByHour.isEmpty ||
        hourlyByHour.values.any(
          (item) =>
              item.time == '--' ||
              item.temperature == null ||
              item.displayedApparentTemperature == null ||
              item.precipitationProbability == null ||
              item.windSpeed == null ||
              item.skyCondition == null,
        );
    return Container(
      key: ValueKey(widget.keyPrefix == 'main'
          ? 'main-hourly-timeline-section'
          : widget.inline
              ? '${widget.keyPrefix}-hourly-timeline-section'
              : 'today-hourly-forecast-section'),
      padding: widget.inline
          ? const EdgeInsets.only(top: 12)
          : const EdgeInsets.all(20),
      decoration: widget.inline
          ? null
          : WeatherCareTheme.of(context).surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.inline)
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  key: ValueKey('${widget.keyPrefix}-hourly-title-icon'),
                  size: 18,
                  color: WeatherCareTheme.of(context).primaryDeep,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('시간별 예보',
                      style: Theme.of(context).textTheme.labelLarge),
                ),
              ],
            )
          else
            HomeSectionHeader(
              icon: Icons.schedule_rounded,
              title: '타임라인',
              subtitle: '항목을 선택해 시간별로 비교해요',
              trailing: IconButton(
                key: ValueKey('${widget.keyPrefix}-hourly-info'),
                tooltip: '타임라인 안내',
                onPressed: () => _showHourlyInfo(context),
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 32, height: 32),
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.error_outline_rounded,
                    color: WeatherCareTheme.of(context).primaryDeep),
              ),
            ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            key: ValueKey('${widget.keyPrefix}-hourly-filters'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final metric in availableMetrics)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      key: ValueKey(
                          '${widget.keyPrefix}-hourly-filter-${metric.name}'),
                      showCheckmark: false,
                      label: Text(_metricLabel(metric)),
                      selected: selected == metric,
                      onSelected: (_) => setState(() => _selected = metric),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            key: ValueKey('${widget.keyPrefix}-hourly-timeline'),
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < selectedItems.length; index++)
                  _HourlyPoint(
                    key: ValueKey('${widget.keyPrefix}-hourly-$index'),
                    item: selectedItems[index],
                    metric: selected,
                    dataPhase: widget.dataPhase,
                    today: today,
                  ),
              ],
            ),
          ),
          if (itemsFor(selected).isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WeatherCareTheme.of(context).surfaceMuted,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(
                widget.dataPhase == WeatherDataPhase.loading
                    ? '타임라인을 불러오고 있어요.'
                    : widget.dataPhase == WeatherDataPhase.failed
                        ? '서버에서 타임라인을 불러오지 못했어요.'
                        : widget.items.isEmpty
                            ? '타임라인 자료가 없어 표시하기 어려워요.'
                            : '표시할 타임라인 자료가 없어요.',
                style: TextStyle(
                  color: WeatherCareTheme.of(context).textSecondary,
                ),
              ),
            ),
          ],
          if (hasMissingData &&
              widget.dataPhase != WeatherDataPhase.loading &&
              widget.onRetryMissingData != null) ...[
            const SizedBox(height: 12),
            MissingDataRetry(
              message: widget.dataPhase == WeatherDataPhase.failed
                  ? '서버에서 타임라인 항목을 불러오지 못했어요.'
                  : '받지 못한 타임라인 항목이 있어요.',
              retryKey: '${widget.keyPrefix}-hourly-data-retry',
              onRetry: widget.onRetryMissingData!,
              retrying: widget.retrying,
            ),
          ],
        ],
      ),
    );
  }
}

bool _hasValue(_HourlyMetric metric, HourlyWeatherItem item) =>
    switch (metric) {
      _HourlyMetric.weather =>
        item.skyCondition != null || item.temperature != null,
      _HourlyMetric.precipitation => item.precipitationProbability != null ||
          item.precipitationAmount != null ||
          item.precipitationAmountLabel != null,
      _HourlyMetric.snowfall => item.snowExpected != null ||
          item.snowfallAmount != null ||
          item.snowfallAmountLabel != null,
      _HourlyMetric.uv => item.uvIndex != null,
      _HourlyMetric.wind => item.windSpeed != null,
      _HourlyMetric.humidity => item.humidity != null,
    };

void _showHourlyInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('타임라인 안내'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '기온·바람은 정시 값, 강수와 강설은 직전 1시간 구간의 예보예요. 강설의 신적설은 새로 쌓일 눈의 깊이이며 현재 쌓인 눈의 전체 깊이가 아니에요.\n자외선은 자료가 있는 경우에만 표시해요. 자외선지수 0도 실제 값이며, 자료가 없으면 —로 표시해요.'),
            SizedBox(height: 8),
            Text(
              '가시거리는 현재 관측자료만 제공돼 시간별 예보에는 표시하지 않아요.',
              key: ValueKey('today-hourly-visibility-notice'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

String _metricLabel(_HourlyMetric metric) => switch (metric) {
      _HourlyMetric.weather => '날씨',
      _HourlyMetric.precipitation => '강수',
      _HourlyMetric.snowfall => '강설',
      _HourlyMetric.uv => '자외선',
      _HourlyMetric.wind => '바람',
      _HourlyMetric.humidity => '습도',
    };

class _HourlyPoint extends StatelessWidget {
  final HourlyWeatherItem item;
  final _HourlyMetric metric;
  final WeatherDataPhase dataPhase;
  final String today;

  const _HourlyPoint({
    super.key,
    required this.item,
    required this.metric,
    required this.dataPhase,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    final period = item.precipitationPeriod;
    final precipitationValid = !item.precipitationPeriodProvided ||
        (period != null && period.date.compareTo(today) >= 0);
    final hour = int.tryParse(item.time);
    final isPrecipitationPeriod = metric == _HourlyMetric.precipitation ||
        metric == _HourlyMetric.snowfall;
    final labelDate = isPrecipitationPeriod && period != null
        ? period.date
        : item.forecastDate;
    final dayPrefix =
        labelDate != null && labelDate.compareTo(today) > 0 ? '내일 ' : '';
    final timeLabel =
        isPrecipitationPeriod && period != null && precipitationValid
            ? '$dayPrefix${period.label}'
            : hour != null && hour >= 0 && hour < 24
                ? '$dayPrefix${hour.toString().padLeft(2, '0')}시'
                : '시각 ${dataPhase.missingText()}';
    final visual = switch (metric) {
      _HourlyMetric.weather => WeatherConditionIcon(
          condition: item.skyCondition,
          size: 28,
          color: palette.primaryDeep,
        ),
      _HourlyMetric.precipitation => _MetricIconValue(
          icon: Icons.water_drop,
          color: palette.primaryDeep,
          solidDrop: true,
          value: precipitationValid && item.precipitationProbability != null
              ? '${item.precipitationProbability!.toStringAsFixed(0)}%'
              : '—',
          semanticLabel:
              precipitationValid && item.precipitationProbability != null
                  ? '강수확률 ${item.precipitationProbability!.toStringAsFixed(0)}%'
                  : '강수확률 자료 없음',
        ),
      _HourlyMetric.snowfall => Icon(
          Icons.ac_unit_rounded,
          size: 32,
          color: palette.primaryDeep,
          semanticLabel: '강설 예보',
        ),
      _HourlyMetric.uv => _MetricIconValue(
          icon: Icons.wb_sunny_rounded,
          color: _uvColor(item.uvIndex, palette),
          value: item.uvIndex?.toStringAsFixed(0) ?? '—',
          semanticLabel: item.uvIndex == null
              ? '자외선지수 자료 없음'
              : '자외선지수 ${item.uvIndex!.toStringAsFixed(0)}',
          sun: true,
        ),
      _HourlyMetric.wind => Transform.rotate(
          key: const ValueKey('today-hourly-wind-icon'),
          angle: ((item.windDirection ?? 90) - 90) * math.pi / 180,
          child: Icon(Icons.air_rounded, size: 30, color: palette.primaryDeep),
        ),
      _HourlyMetric.humidity => _HumidityCup(
          key: const ValueKey('today-hourly-humidity-icon'),
          humidity: item.humidity,
          color: palette.primaryDeep,
          background: palette.surfaceMuted,
        ),
    };
    final rainAmount = item.precipitationAmountLabel ??
        (item.precipitationAmount == null
            ? null
            : '${_amountNumber(item.precipitationAmount!)}mm');
    final snowAmount = item.snowfallAmountLabel ??
        (item.snowfallAmount == null
            ? null
            : '${_amountNumber(item.snowfallAmount!)}cm');
    final values = switch (metric) {
      _HourlyMetric.weather => [
          item.temperature == null
              ? '—'
              : '${item.temperature!.toStringAsFixed(0)}°C',
          '(체감 ${item.displayedApparentTemperature == null ? '—' : '${item.displayedApparentTemperature!.toStringAsFixed(0)}°C'})',
          if (item.skyCondition == null) '날씨 —',
        ],
      _HourlyMetric.precipitation => precipitationValid
          ? [
              rainAmount ?? '—',
            ]
          : ['강수 구간 —'],
      _HourlyMetric.snowfall => precipitationValid
          ? [
              item.snowExpected == true
                  ? '눈 예상'
                  : item.snowExpected == false
                      ? '눈 예보 없음'
                      : '눈 예보 —',
              '신적설 ${snowAmount ?? '—'}',
            ]
          : ['강설 구간 —'],
      _HourlyMetric.uv => [uvDescription(item.uvIndex) ?? '—'],
      _HourlyMetric.wind => [
          windDescription(item.windSpeed) ?? '—',
          '${_windDirectionLabel(item.windDirection)} · ${item.windSpeed == null ? '—' : '${item.windSpeed!.toStringAsFixed(1)}m/s'}',
        ],
      _HourlyMetric.humidity => [humidityDescription(item.humidity) ?? '—'],
    };

    return SizedBox(
      width: MediaQuery.textScalerOf(context)
          .scale(metric == _HourlyMetric.weather ? 120 : 100),
      child: Column(
        children: [
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(_timeLabelHeight),
            child: Center(
              child: Text(
                timeLabel,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: _timeDotGap),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(height: 2, color: palette.primaryBorder),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: palette.primaryDeep,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(height: 44, child: Center(child: visual)),
          const SizedBox(height: 3),
          for (var index = 0; index < values.length; index++)
            Text(
              values[index],
              textAlign: TextAlign.center,
              maxLines: 1,
              style: index == 0 &&
                      metric != _HourlyMetric.precipitation &&
                      metric != _HourlyMetric.uv
                  ? Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                      )
                  : Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        fontSize: 10,
                      ),
            ),
        ],
      ),
    );
  }
}

class _MetricIconValue extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String semanticLabel;
  final bool sun;
  final bool solidDrop;

  const _MetricIconValue({
    required this.icon,
    required this.color,
    required this.value,
    required this.semanticLabel,
    this.sun = false,
    this.solidDrop = false,
  });

  @override
  Widget build(BuildContext context) => Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: 52,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (solidDrop)
              CustomPaint(
                key: const ValueKey('today-hourly-precipitation-icon'),
                size: const Size(36, 36),
                painter: _SolidDropPainter(color),
              )
            else
              Icon(icon, size: 40, color: color),
            if (sun)
              Container(
                key: const ValueKey('today-hourly-uv-center'),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: WeatherCareTheme.of(context).surface,
                  shape: BoxShape.circle,
                ),
              ),
            Transform.translate(
              offset: Offset(0, sun ? 0 : 6),
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: sun ? color : WeatherCareTheme.of(context).onPrimary,
                  fontSize: sun ? 13 : 9,
                  fontWeight: sun ? FontWeight.w900 : FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ));
}

class _SolidDropPainter extends CustomPainter {
  final Color color;

  const _SolidDropPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_dropPath(size), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SolidDropPainter oldDelegate) =>
      color != oldDelegate.color;
}

Color _uvColor(double? index, WeatherCarePalette palette) => switch (index) {
      null || < 3 => palette.primaryDeep,
      < 6 => Colors.orange,
      < 8 => Colors.deepOrange,
      < 11 => Colors.red,
      _ => Colors.red.shade900,
    };

String _windDirectionLabel(double? direction) {
  if (direction == null) return '방향 —';
  const labels = ['북', '북동', '동', '남동', '남', '남서', '서', '북서'];
  final normalized = ((direction % 360) + 360) % 360;
  return '${labels[((normalized + 22.5) ~/ 45) % labels.length]}풍';
}

class _HumidityCup extends StatelessWidget {
  final double? humidity;
  final Color color;
  final Color background;

  const _HumidityCup({
    super.key,
    required this.humidity,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final isFilledLabel = humidity != null && humidity! > 49;
    return Semantics(
      label: humidity == null
          ? '습도 자료 없음'
          : '습도 ${humidity!.toStringAsFixed(0)}% 채움',
      excludeSemantics: true,
      child: SizedBox(
        width: 40,
        height: 42,
        child: Stack(
          children: [
            CustomPaint(
              size: const Size(40, 42),
              painter: _HumidityCupPainter(
                fill: (humidity ?? 0).clamp(0, 100) / 100,
                color: color,
                background: background,
              ),
            ),
            Positioned(
              top: isFilledLabel ? 23 : 11,
              left: 4,
              right: 4,
              height: 12,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  humidity == null ? '—' : '${humidity!.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isFilledLabel
                        ? WeatherCareTheme.of(context).onPrimary
                        : WeatherCareTheme.of(context).textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HumidityCupPainter extends CustomPainter {
  final double fill;
  final Color color;
  final Color background;

  const _HumidityCupPainter({
    required this.fill,
    required this.color,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cup = Path()
      ..moveTo(w * .1, h * .1)
      ..lineTo(w * .25, h * .9)
      ..quadraticBezierTo(w * .5, h * .98, w * .75, h * .9)
      ..lineTo(w * .9, h * .1)
      ..close();
    canvas.drawPath(cup, Paint()..color = background);
    canvas.save();
    canvas.clipPath(cup);
    canvas.drawRect(
      Rect.fromLTWH(0, h * (1 - fill), w, h * fill),
      Paint()..color = color,
    );
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(w * .1, h * .1)
        ..lineTo(w * .25, h * .9)
        ..quadraticBezierTo(w * .5, h * .98, w * .75, h * .9)
        ..lineTo(w * .9, h * .1),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawOval(
      Rect.fromLTWH(w * .1, 0, w * .8, h * .2),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_HumidityCupPainter oldDelegate) =>
      fill != oldDelegate.fill ||
      color != oldDelegate.color ||
      background != oldDelegate.background;
}

Path _dropPath(Size size) {
  final w = size.width;
  final h = size.height;
  return Path()
    ..moveTo(w / 2, 1)
    ..cubicTo(w * .72, h * .24, w * .95, h * .52, w * .95, h * .68)
    ..cubicTo(w * .95, h * 1.08, w * .05, h * 1.08, w * .05, h * .68)
    ..cubicTo(w * .05, h * .52, w * .28, h * .24, w / 2, 1)
    ..close();
}

String _amountNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
