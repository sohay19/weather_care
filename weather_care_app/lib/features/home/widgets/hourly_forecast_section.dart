import 'package:flutter/material.dart';

import '../../../models/briefing_time.dart';
import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../../../utils/korea_date.dart';
import '../weather_data_phase.dart';
import 'home_section_header.dart';
import 'missing_data_retry.dart';
import 'weather_condition_icon.dart';

enum _HourlyMetric { weather, precipitation, uv, wind, humidity, airQuality }

class HourlyForecastSection extends StatefulWidget {
  final List<HourlyWeatherItem> items;
  final String? generatedAt;
  final DateTime? receivedAt;
  final DateTime? now;
  final WeatherDataPhase dataPhase;
  final Future<void> Function()? onRetryMissingData;
  final bool retrying;

  const HourlyForecastSection({
    super.key,
    required this.items,
    this.generatedAt,
    this.receivedAt,
    this.now,
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
    final today = dateInKorea(responseNow(
      widget.now ?? DateTime.now(),
      generatedAt: widget.generatedAt,
      receivedAt: widget.receivedAt,
    ));
    final visibleItems = _todayHourlyItems(widget.items, today);
    final selectedItems = _selected == _HourlyMetric.precipitation
        ? visibleItems
        : visibleItems
            .where((item) =>
                item.forecastDate == null || item.forecastDate == today)
            .toList(growable: false);
    final hasMissingData = visibleItems.isEmpty ||
        visibleItems.any(
          (item) =>
              item.time == '--' ||
              item.temperature == null ||
              item.displayedApparentTemperature == null ||
              item.precipitationProbability == null ||
              item.windSpeed == null ||
              item.skyCondition == null,
        );
    return Container(
      key: const ValueKey('today-hourly-forecast-section'),
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.of(context).surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            icon: Icons.schedule_rounded,
            title: '시간별 예보',
            subtitle: '항목을 선택해 시간별로 비교해요',
            trailing: IconButton(
              key: const ValueKey('today-hourly-info'),
              tooltip: '시간별 예보 안내',
              onPressed: () => _showHourlyInfo(context),
              iconSize: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(Icons.error_outline_rounded,
                  color: WeatherCareTheme.of(context).primaryDeep),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 0,
            children: [
              for (final metric in _HourlyMetric.values)
                ChoiceChip(
                  key: ValueKey('today-hourly-filter-${metric.name}'),
                  showCheckmark: false,
                  label: Text(_metricLabel(metric)),
                  selected: _selected == metric,
                  onSelected: (_) => setState(() => _selected = metric),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (selectedItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WeatherCareTheme.of(context).surfaceMuted,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(
                widget.dataPhase == WeatherDataPhase.loading
                    ? '시간별 예보를 불러오고 있어요.'
                    : widget.dataPhase == WeatherDataPhase.failed
                        ? '서버에서 시간별 예보를 불러오지 못했어요.'
                        : widget.items.isEmpty
                            ? '시간별 예보 자료가 없어 표시하기 어려워요.'
                            : '오늘 표시할 시간별 예보가 없어요.',
                style: TextStyle(
                  color: WeatherCareTheme.of(context).textSecondary,
                ),
              ),
            )
          else
            SingleChildScrollView(
              key: const ValueKey('today-hourly-timeline'),
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < selectedItems.length; index++)
                    _HourlyPoint(
                      key: ValueKey('today-hourly-$index'),
                      item: selectedItems[index],
                      metric: _selected,
                      dataPhase: widget.dataPhase,
                      today: today,
                    ),
                ],
              ),
            ),
          if (hasMissingData &&
              widget.dataPhase != WeatherDataPhase.loading &&
              widget.onRetryMissingData != null) ...[
            const SizedBox(height: 12),
            MissingDataRetry(
              message: widget.dataPhase == WeatherDataPhase.failed
                  ? '서버에서 시간별 예보 항목을 불러오지 못했어요.'
                  : '받지 못한 시간별 예보 항목이 있어요.',
              retryKey: 'today-hourly-data-retry',
              onRetry: widget.onRetryMissingData!,
              retrying: widget.retrying,
            ),
          ],
        ],
      ),
    );
  }
}

void _showHourlyInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('시간별 예보 안내'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('기온·바람은 정시 값, 강수는 시간 구간의 예보예요.\n자외선과 대기질은 자료가 있는 경우에만 표시해요.'),
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
      _HourlyMetric.uv => '자외선',
      _HourlyMetric.wind => '바람',
      _HourlyMetric.humidity => '습도',
      _HourlyMetric.airQuality => '대기질',
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
        (period != null && period.date == today);
    final hour = int.tryParse(item.time);
    final timeLabel = metric == _HourlyMetric.precipitation &&
            period != null &&
            period.date == today
        ? period.label
        : hour != null && hour >= 0 && hour < 24
            ? '${hour.toString().padLeft(2, '0')}시'
            : '시각 ${dataPhase.missingText()}';
    final icon = switch (metric) {
      _HourlyMetric.weather => WeatherConditionIcon(
          condition: item.skyCondition,
          size: 28,
          color: palette.primaryDeep,
        ),
      _HourlyMetric.precipitation =>
        Icon(Icons.water_drop_outlined, size: 28, color: palette.primaryDeep),
      _HourlyMetric.uv =>
        Icon(Icons.wb_sunny_outlined, size: 28, color: palette.primaryDeep),
      _HourlyMetric.wind =>
        Icon(Icons.air_rounded, size: 28, color: palette.primaryDeep),
      _HourlyMetric.humidity =>
        Icon(Icons.opacity_rounded, size: 28, color: palette.primaryDeep),
      _HourlyMetric.airQuality =>
        Icon(Icons.grain_rounded, size: 28, color: palette.primaryDeep),
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
              ? '기온 —'
              : '기온 ${item.temperature!.toStringAsFixed(0)}℃',
          item.displayedApparentTemperature == null
              ? '체감 —'
              : '체감 ${item.displayedApparentTemperature!.toStringAsFixed(0)}℃',
          if (item.skyCondition == null) '날씨 —',
        ],
      _HourlyMetric.precipitation => precipitationValid
          ? [
              item.precipitationProbability == null
                  ? '강수확률 —'
                  : '강수확률 ${item.precipitationProbability!.toStringAsFixed(0)}%',
              '강수량 ${rainAmount ?? '—'}',
              if (item.snowExpected == true ||
                  _hasPositiveAmount(snowAmount, 'cm'))
                '신적설 ${snowAmount ?? '—'}',
            ]
          : ['강수 구간 —'],
      _HourlyMetric.uv => [
          item.uvIndex == null
              ? '자외선 —'
              : '자외선 ${item.uvIndex!.toStringAsFixed(0)}',
        ],
      _HourlyMetric.wind => [
          item.windSpeed == null
              ? '바람 —'
              : '바람 ${item.windSpeed!.toStringAsFixed(1)}m/s',
        ],
      _HourlyMetric.humidity => [
          item.humidity == null
              ? '습도 —'
              : '습도 ${item.humidity!.toStringAsFixed(0)}%',
        ],
      _HourlyMetric.airQuality => [
          '미세먼지 ${item.pm10 == null ? '—' : '${item.pm10}㎍/㎥'}',
          '초미세먼지 ${item.pm25 == null ? '—' : '${item.pm25}㎍/㎥'}',
        ],
    };

    return SizedBox(
      width: 150,
      child: Column(
        children: [
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(32),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          icon,
          const SizedBox(height: 5),
          for (var index = 0; index < values.length; index++)
            Text(
              values[index],
              textAlign: TextAlign.center,
              maxLines: 2,
              style: index == 0
                  ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                      )
                  : Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
            ),
        ],
      ),
    );
  }
}

String _amountNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

bool _hasPositiveAmount(String? label, String unit) =>
    label != null && label != '0$unit' && label != '0.0$unit';

bool _hasMeaningfulPrecipitation(HourlyWeatherItem item) {
  final rainAmount = item.precipitationAmountLabel ??
      (item.precipitationAmount == null
          ? null
          : '${_amountNumber(item.precipitationAmount!)}mm');
  final snowAmount = item.snowfallAmountLabel ??
      (item.snowfallAmount == null
          ? null
          : '${_amountNumber(item.snowfallAmount!)}cm');
  return (item.precipitationProbability ?? 0) > 0 ||
      item.snowExpected == true ||
      _hasPositiveAmount(rainAmount, 'mm') ||
      _hasPositiveAmount(snowAmount, 'cm');
}

List<HourlyWeatherItem> _todayHourlyItems(
    List<HourlyWeatherItem> items, String today) {
  final hasForecastDates = items.any((item) => item.forecastDate != null);
  if (!hasForecastDates) {
    return items.take(24).toList(growable: false);
  }

  return items
      .where((item) =>
          item.forecastDate == today ||
          (item.precipitationPeriod?.date == today &&
              _hasMeaningfulPrecipitation(item)))
      .toList(growable: false);
}
