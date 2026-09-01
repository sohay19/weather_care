import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../models/lifestyle_message.dart';
import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/home_section_header.dart';
import '../widgets/server_feature_unavailable_card.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/weather_card.dart';
import '../widgets/weather_condition_icon.dart';

class DetailTab extends StatelessWidget {
  final TodayWeatherResponse today;
  final List<WeatherRecommendation> recommendations;
  final bool serverFeaturesAvailable;
  final Future<void> Function() onRefresh;

  const DetailTab({
    super.key,
    required this.today,
    required this.recommendations,
    required this.serverFeaturesAvailable,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: WeatherCareTheme.primary,
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey('detail-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TabPageHeader(
            eyebrow: 'DETAIL',
            title: '날씨 자세히보기',
            subtitle: '상세한 날씨 정보를 확인해요',
            icon: Icons.query_stats_rounded,
          ),
          const SizedBox(height: 18),
          WeatherInfoCard(current: today.current),
          const SizedBox(height: 16),
          if (serverFeaturesAvailable)
            _RecommendationEvidence(
              today: today,
            )
          else
            const ServerFeatureUnavailableCard(
              icon: Icons.fact_check_outlined,
              title: '챙길 이유',
            ),
          const SizedBox(height: 16),
          _HourlyForecastCard(items: today.hourly),
        ],
      ),
    );
  }
}

class _RecommendationEvidence extends StatelessWidget {
  final TodayWeatherResponse today;

  const _RecommendationEvidence({
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final items = today.lifestyleMessages.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionHeader(
            title: '근거와 자료',
            subtitle: '추천 뒤에 공식 정보와 자료 상태를 확인해요',
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(
              '현재 조건에서는 별도 준비물 추천이 없어요.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: WeatherCareTheme.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.fact_check_outlined,
                      size: 19,
                      color: WeatherCareTheme.primaryDeep,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[index].title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        for (final part in items[index].parts.skip(1)) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${part.role.label} · ${part.text}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (index < items.length - 1) ...[
                const SizedBox(height: 11),
                const Divider(height: 1),
                const SizedBox(height: 11),
              ],
            ],
        ],
      ),
    );
  }
}

class _HourlyForecastCard extends StatelessWidget {
  final List<HourlyWeatherItem> items;

  const _HourlyForecastCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final visibleItems = _todayHourlyItems(items);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionHeader(
            icon: Icons.schedule_rounded,
            title: '타임라인',
            subtitle: '온도·체감·강수·자외선·대기질을 비교해요',
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
                    ? '서버에서 시간별 예보를 받으면 이곳에 표시해요.'
                    : '오늘 표시할 시간별 예보가 없어요.',
                style: const TextStyle(
                  color: WeatherCareTheme.textSecondary,
                ),
              ),
            )
          else
            for (var index = 0; index < visibleItems.length; index++) ...[
              _HourlyRow(
                key: ValueKey('detail-hourly-$index'),
                item: visibleItems[index],
              ),
              if (index < visibleItems.length - 1) const SizedBox(height: 9),
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
      .where((item) => item.forecastDate == today)
      .toList(growable: false);
}

class _HourlyRow extends StatelessWidget {
  final HourlyWeatherItem item;

  const _HourlyRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WeatherCareTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: WeatherCareTheme.outline,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  '${item.time}시',
                  style: const TextStyle(
                    color: WeatherCareTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              WeatherConditionIcon(
                condition: item.skyCondition,
                size: 19,
                color: WeatherCareTheme.textSecondary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  item.skyCondition,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${item.temperature.toStringAsFixed(0)}℃',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 7),
              Text(
                item.apparentTemperature == null
                    ? '체감 미지원'
                    : '예상 체감 ${item.apparentTemperature!.toStringAsFixed(0)}℃',
                style: const TextStyle(
                  color: WeatherCareTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (item.precipitationProbability > 0 ||
                  item.precipitationAmount > 0)
                _MetricChip(
                  icon: Icons.water_drop_outlined,
                  label: '강수확률 '
                      '${item.precipitationProbability.toStringAsFixed(0)}%'
                      '${item.precipitationAmountLabel == null ? '' : ' · ${item.precipitationAmountLabel}'}',
                ),
              if (item.snowExpected)
                _MetricChip(
                  icon: Icons.ac_unit_rounded,
                  label: item.snowfallAmountLabel == null
                      ? '눈이 예보됐어요'
                      : '눈 예상 · ${item.snowfallAmountLabel}',
                ),
              _MetricChip(
                icon: Icons.air_rounded,
                label: '바람 ${item.windSpeed.toStringAsFixed(1)}m/s',
              ),
              if (item.uvIndex != null)
                _MetricChip(
                  icon: Icons.wb_sunny_outlined,
                  label: '자외선 ${item.uvIndex!.toStringAsFixed(0)}',
                ),
              if (item.pm25 != null || item.pm10 != null)
                _MetricChip(
                  icon: Icons.grain_rounded,
                  label: item.pm25 != null
                      ? '초미세먼지 ${item.pm25}㎍/㎥'
                      : '미세먼지 ${item.pm10}㎍/㎥',
                ),
            ],
          ),
        ],
      ),
    );
  }
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
          Text(
            label,
            style: WeatherCareTheme.microTextStyle.copyWith(
              color: WeatherCareTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
