import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../models/weather.dart';
import '../../../theme/recommendation_theme.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/home_section_header.dart';
import '../widgets/server_feature_unavailable_card.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/weather_card.dart';

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
            title: '상세 날씨',
            subtitle: '추천을 만든 시간별 근거를 숫자로 확인해요',
            icon: Icons.query_stats_rounded,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 18),
          WeatherInfoCard(current: today.current),
          const SizedBox(height: 16),
          if (serverFeaturesAvailable)
            _RecommendationEvidence(recommendations: recommendations)
          else
            const ServerFeatureUnavailableCard(
              icon: Icons.fact_check_outlined,
              title: '오늘의 판단 근거',
            ),
          const SizedBox(height: 16),
          _HourlyForecastCard(items: today.hourly),
        ],
      ),
    );
  }
}

class _RecommendationEvidence extends StatelessWidget {
  final List<WeatherRecommendation> recommendations;

  const _RecommendationEvidence({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    final items = recommendations.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionHeader(
            icon: Icons.fact_check_outlined,
            title: '오늘의 판단 근거',
            subtitle: '서버가 선택한 추천과 이유를 그대로 보여줘요',
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
                      color: items[index].type.softColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      items[index].type.icon,
                      size: 19,
                      color: items[index].type.accentColor,
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
                        Text(
                          items[index].description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionHeader(
            icon: Icons.schedule_rounded,
            title: '시간대별 상세',
            subtitle: '온도·체감·비·눈·바람을 한 줄로 비교해요',
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Text(
                '서버에서 시간별 예보를 받으면 이곳에 표시해요.',
                style: TextStyle(color: WeatherCareTheme.textSecondary),
              ),
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              _HourlyRow(item: items[index]),
              if (index < items.length - 1) const SizedBox(height: 9),
            ],
        ],
      ),
    );
  }
}

class _HourlyRow extends StatelessWidget {
  final HourlyWeatherItem item;

  const _HourlyRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isRainy = item.precipitationProbability >= 40;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRainy ? const Color(0xFFEDF5FD) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRainy ? const Color(0xFFD4E6F8) : const Color(0xFFEDF1F5),
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
              Icon(
                _iconFor(item.skyCondition),
                size: 19,
                color: isRainy
                    ? WeatherCareTheme.primaryDeep
                    : WeatherCareTheme.textSecondary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  item.skyCondition,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${item.temperature.toStringAsFixed(0)}°',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 7),
              Text(
                item.apparentTemperature == null
                    ? '체감 미지원'
                    : '체감 ${item.apparentTemperature!.toStringAsFixed(0)}°',
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
              _MetricChip(
                icon: Icons.water_drop_outlined,
                label:
                    '비 ${item.precipitationProbability.toStringAsFixed(0)}% · ${item.precipitationAmount.toStringAsFixed(1)}mm',
              ),
              _MetricChip(
                icon: Icons.ac_unit_rounded,
                label:
                    '눈 ${item.snowProbability.toStringAsFixed(0)}% · ${item.snowfallAmount.toStringAsFixed(1)}cm',
              ),
              _MetricChip(
                icon: Icons.air_rounded,
                label: '바람 ${item.windSpeed.toStringAsFixed(1)}m/s',
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
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

IconData _iconFor(String sky) {
  if (sky.contains('비')) return Icons.umbrella_outlined;
  if (sky.contains('눈')) return Icons.ac_unit_rounded;
  if (sky.contains('흐림') || sky.contains('구름')) return Icons.cloud_outlined;
  return Icons.wb_sunny_outlined;
}
