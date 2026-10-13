import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import 'home_section_header.dart';
import 'weather_condition_icon.dart';

enum _TimelineMetric { weather, precipitation, uv, wind, humidity }

class TimelineSection extends StatefulWidget {
  final List<HourlyWeatherItem> items;

  const TimelineSection({super.key, required this.items});

  @override
  State<TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<TimelineSection> {
  _TimelineMetric _selected = _TimelineMetric.weather;

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: palette.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionHeader(
            icon: Icons.schedule_rounded,
            title: '간단한 타임라인',
            subtitle: '시간별 예보',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 7,
            runSpacing: 0,
            children: [
              for (final metric in _TimelineMetric.values)
                ChoiceChip(
                  key: ValueKey('timeline-filter-${metric.name}'),
                  showCheckmark: false,
                  label: Text(_metricLabel(metric)),
                  selected: _selected == metric,
                  onSelected: (_) => setState(() => _selected = metric),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.items.isEmpty)
            Text('표시할 시간별 예보가 없어요',
                style: Theme.of(context).textTheme.bodyMedium)
          else
            SingleChildScrollView(
              key: const ValueKey('timeline-content'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in widget.items)
                    _TimelinePoint(
                      item: item,
                      metric: _selected,
                      nextDay: widget.items.first.forecastDate != null &&
                          item.forecastDate != null &&
                          item.forecastDate != widget.items.first.forecastDate,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _metricLabel(_TimelineMetric metric) => switch (metric) {
      _TimelineMetric.weather => '날씨',
      _TimelineMetric.precipitation => '강수',
      _TimelineMetric.uv => '자외선',
      _TimelineMetric.wind => '바람',
      _TimelineMetric.humidity => '습도',
    };

class _TimelinePoint extends StatelessWidget {
  final HourlyWeatherItem item;
  final _TimelineMetric metric;
  final bool nextDay;

  const _TimelinePoint({
    required this.item,
    required this.metric,
    required this.nextDay,
  });

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    final (icon, value, secondary) = switch (metric) {
      _TimelineMetric.weather => (
          WeatherConditionIcon(
            condition: item.skyCondition,
            size: 28,
            color: palette.primaryDeep,
          ),
          item.temperature == null
              ? '—'
              : '${item.temperature!.toStringAsFixed(0)}°',
          '',
        ),
      _TimelineMetric.precipitation => (
          Icon(Icons.water_drop_outlined, size: 28, color: palette.primaryDeep),
          item.precipitationProbability == null
              ? '—'
              : '${item.precipitationProbability!.toStringAsFixed(0)}%',
          item.precipitationAmountLabel ??
              (item.precipitationAmount == null
                  ? '—'
                  : '${item.precipitationAmount!.toStringAsFixed(1)}mm'),
        ),
      _TimelineMetric.uv => (
          Icon(Icons.wb_sunny_outlined, size: 28, color: palette.primaryDeep),
          item.uvIndex == null ? '—' : item.uvIndex!.toStringAsFixed(0),
          '',
        ),
      _TimelineMetric.wind => (
          Icon(Icons.air_rounded, size: 28, color: palette.primaryDeep),
          item.windSpeed == null ? '—' : item.windSpeed!.toStringAsFixed(1),
          item.windSpeed == null ? '' : 'm/s',
        ),
      _TimelineMetric.humidity => (
          Icon(Icons.opacity_rounded, size: 28, color: palette.primaryDeep),
          item.humidity == null ? '—' : '${item.humidity!.toStringAsFixed(0)}%',
          '',
        ),
    };

    return SizedBox(
      key: ValueKey('timeline-point-${item.forecastDate ?? ''}-${item.time}'),
      width: 104,
      child: Column(
        children: [
          icon,
          const SizedBox(height: 5),
          Text(value,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  )),
          if (metric == _TimelineMetric.precipitation || metric == _TimelineMetric.wind) ...[
            SizedBox(
              height: 19,
              child: Text(secondary,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  )),
            ),
          ],
          const SizedBox(height: 10),
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
          Text('${nextDay ? '내일 ' : ''}${item.time}시',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w700,
                  )),
        ],
      ),
    );
  }
}
