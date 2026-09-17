import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../../../utils/korea_date.dart';
import 'home_section_header.dart';
import 'missing_data_retry.dart';
import 'weather_condition_icon.dart';

class HourlyForecastSection extends StatelessWidget {
  final List<HourlyWeatherItem> items;
  final Future<void> Function()? onRetryMissingData;
  final bool retrying;

  const HourlyForecastSection({
    super.key,
    required this.items,
    this.onRetryMissingData,
    this.retrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = _todayHourlyItems(items);
    final hasMissingData = visibleItems.isEmpty ||
        visibleItems.any(
          (item) =>
              item.time == '--' ||
              item.temperature == null ||
              item.apparentTemperature == null ||
              item.precipitationProbability == null ||
              item.windSpeed == null ||
              item.skyCondition == null,
        );
    return Container(
      key: const ValueKey('today-hourly-forecast-section'),
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionHeader(
            icon: Icons.schedule_rounded,
            title: '시간별 예보',
            subtitle: '기온·체감·강수·바람을 시간별로 비교해요',
          ),
          const SizedBox(height: 8),
          Text(
            '기온·바람은 정시 값, 강수는 시간 구간의 예보예요.\n자외선과 대기질은 자료가 경우에만 표시해요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (visibleItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WeatherCareTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(
                items.isEmpty
                    ? '시간별 예보 자료가 없어 표시하기 어려워요.'
                    : '오늘 표시할 시간별 예보가 없어요.',
                style: const TextStyle(
                  color: WeatherCareTheme.textSecondary,
                ),
              ),
            )
          else
            for (var index = 0; index < visibleItems.length; index++) ...[
              _HourlyRow(
                key: ValueKey('today-hourly-$index'),
                item: visibleItems[index],
                showPoint: visibleItems[index].forecastDate == null ||
                    visibleItems[index].forecastDate ==
                        dateInKorea(DateTime.now()),
              ),
              if (index < visibleItems.length - 1) const SizedBox(height: 9),
            ],
          if (hasMissingData && onRetryMissingData != null) ...[
            const SizedBox(height: 12),
            MissingDataRetry(
              message: '받지 못한 시간별 예보 항목이 있어요.',
              retryKey: 'today-hourly-data-retry',
              onRetry: onRetryMissingData!,
              retrying: retrying,
            ),
          ],
        ],
      ),
    );
  }
}

List<HourlyWeatherItem> _todayHourlyItems(List<HourlyWeatherItem> items) {
  final hasForecastDates = items.any((item) => item.forecastDate != null);
  if (!hasForecastDates) {
    return items.take(24).toList(growable: false);
  }

  final nowInKorea = DateTime.now().toUtc().add(const Duration(hours: 9));
  final today = '${nowInKorea.year.toString().padLeft(4, '0')}-'
      '${nowInKorea.month.toString().padLeft(2, '0')}-'
      '${nowInKorea.day.toString().padLeft(2, '0')}';
  return items
      .where((item) =>
          item.forecastDate == today ||
          (item.precipitationPeriod?.date == today &&
              _hasMeaningfulPrecipitation(item)))
      .toList(growable: false);
}

class _HourlyRow extends StatelessWidget {
  final HourlyWeatherItem item;
  final bool showPoint;

  const _HourlyRow({super.key, required this.item, this.showPoint = true});

  @override
  Widget build(BuildContext context) {
    final period = item.precipitationPeriod;
    final showPrecipitation = !item.precipitationPeriodProvided ||
        period?.date == dateInKorea(DateTime.now());
    final rainAmount = item.precipitationAmountLabel ??
        (item.precipitationAmount == null
            ? null
            : '${_amountNumber(item.precipitationAmount!)}mm');
    final snowAmount = item.snowfallAmountLabel ??
        (item.snowfallAmount == null
            ? null
            : '${_amountNumber(item.snowfallAmount!)}cm');
    final showRain = (item.precipitationProbability ?? 0) > 0 ||
        _hasPositiveAmount(rainAmount, 'mm');
    final showSnow =
        item.snowExpected == true || _hasPositiveAmount(snowAmount, 'cm');
    final missing = [
      if (showPrecipitation && item.precipitationProbability == null) '강수확률',
      if (showPrecipitation && rainAmount == null) '강수량',
      if (showPrecipitation && snowAmount == null) '쌓일 눈',
      if (showPoint && item.windSpeed == null) '풍속',
    ];
    final hour = int.tryParse(item.time);
    final timeLabel = hour != null && hour >= 0 && hour < 24
        ? '${hour.toString().padLeft(2, '0')}시'
        : '시각 자료 없음';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WeatherCareTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WeatherCareTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showPoint) ...[
            Row(
              children: [
                Flexible(
                  child: Text(
                    timeLabel,
                    style: const TextStyle(
                      color: WeatherCareTheme.primaryDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.temperature == null
                              ? '예상 기온 자료 없음'
                              : '예상 기온 ${item.temperature!.toStringAsFixed(0)}℃',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.apparentTemperature == null
                              ? '예상 체감 자료 없음'
                              : '예상 체감 ${item.apparentTemperature!.toStringAsFixed(0)}℃',
                          style: const TextStyle(
                            color: WeatherCareTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!item.precipitationPeriodProvided) ...[
              Row(
                children: [
                  WeatherConditionIcon(
                    condition: item.skyCondition,
                    size: 19,
                    color: WeatherCareTheme.textSecondary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item.skyCondition ?? '날씨 자료 없음',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (showPoint) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (item.windSpeed != null)
                  _MetricChip(
                    icon: Icons.air_rounded,
                    label: '바람 ${item.windSpeed!.toStringAsFixed(1)}m/s',
                  ),
                if (item.uvIndex != null)
                  _MetricChip(
                    icon: Icons.wb_sunny_outlined,
                    label: '자외선 ${item.uvIndex!.toStringAsFixed(0)}',
                  ),
                if (item.pm25 != null)
                  _MetricChip(
                    icon: Icons.grain_rounded,
                    label: '초미세먼지 ${item.pm25}㎍/㎥',
                  ),
                if (item.pm10 != null)
                  _MetricChip(
                    icon: Icons.grain_rounded,
                    label: '미세먼지 ${item.pm10}㎍/㎥',
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (showPrecipitation && (showRain || showSnow)) ...[
            Text(
              period == null ? '강수 적용 구간 미확인' : '${period.label} 강수 예보',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: WeatherCareTheme.primaryDeep,
              ),
            ),
            if (period != null) Text(item.skyCondition ?? '날씨 자료 없음'),
            const SizedBox(height: 8),
          ],
          if (item.precipitationPeriodProvided && period == null)
            const Text('강수 적용 구간을 확인하기 어려워요'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (showPrecipitation &&
                  showRain &&
                  item.precipitationProbability != null)
                _MetricChip(
                  icon: Icons.water_drop_outlined,
                  label:
                      '강수확률 ${item.precipitationProbability!.toStringAsFixed(0)}%',
                ),
              if (showPrecipitation && _hasPositiveAmount(rainAmount, 'mm'))
                _MetricChip(
                  icon: Icons.water_drop_outlined,
                  label: '강수량 $rainAmount',
                ),
              if (showPrecipitation && showSnow)
                _MetricChip(
                  icon: Icons.ac_unit_rounded,
                  label: _hasPositiveAmount(snowAmount, 'cm')
                      ? '쌓일 눈 $snowAmount'
                      : '눈이 예보됐어요',
                ),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '자료 없음: ${missing.join(' · ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WeatherCareTheme.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

String _amountNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

// 명시된 무강수·무적설은 반복 노출하지 않되, 미만·범위 예보는 보존한다.
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

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: WeatherCareTheme.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: WeatherCareTheme.microTextStyle.copyWith(
                color: WeatherCareTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
