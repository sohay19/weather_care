import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/recommendation_bag_section.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/timeline_section.dart';

class TodayTab extends StatelessWidget {
  final TodayWeatherResponse today;
  final List<WeatherRecommendation> recommendations;
  final Future<void> Function() onRefresh;
  final ValueChanged<RecommendationType> onDetail;

  const TodayTab({
    super.key,
    required this.today,
    required this.recommendations,
    required this.onRefresh,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: WeatherCareTheme.primary,
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey('today-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TabPageHeader(
            eyebrow: 'TODAY',
            title: '오늘을 챙겨요',
            subtitle: '${today.region.name}의 준비물과 생활 시점 안내',
            icon: Icons.work_outline_rounded,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 18),
          _TodayBriefCard(
            brief: today.brief,
            recommendationCount: recommendations.length,
          ),
          const SizedBox(height: 16),
          RecommendationBagSection(
            regionName: today.region.name,
            recommendations: recommendations,
            onDetail: onDetail,
          ),
          const SizedBox(height: 16),
          TimelineSection(items: today.timeline),
        ],
      ),
    );
  }
}

class _TodayBriefCard extends StatelessWidget {
  final String brief;
  final int recommendationCount;

  const _TodayBriefCard({
    required this.brief,
    required this.recommendationCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFB56A32),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brief,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  recommendationCount == 0
                      ? '오늘은 특별한 준비물이 없어요.'
                      : '챙길 항목 $recommendationCount개를 먼저 확인하세요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
