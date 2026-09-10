import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/recommendation_bag_section.dart';
import '../widgets/server_feature_unavailable_card.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/timeline_section.dart';

class TodayTab extends StatelessWidget {
  final TodayWeatherResponse today;
  final List<WeatherRecommendation> recommendations;
  final bool serverFeaturesAvailable;
  final Future<void> Function() onRefresh;
  final ValueChanged<RecommendationType> onDetail;

  const TodayTab({
    super.key,
    required this.today,
    required this.recommendations,
    required this.serverFeaturesAvailable,
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
            subtitle: '오늘의 준비물과 시간대별 안내',
            icon: Icons.work_outline_rounded,
          ),
          const SizedBox(height: 18),
          if (serverFeaturesAvailable)
            RecommendationBagSection(
              regionName: today.region.name,
              recommendations: recommendations,
              onDetail: onDetail,
            )
          else
            const ServerFeatureUnavailableCard(
              icon: Icons.work_outline_rounded,
              title: 'Check List',
            ),
          const SizedBox(height: 16),
          if (serverFeaturesAvailable)
            TimelineSection(
              items: today.timeline,
              onDetail: onDetail,
            )
          else
            const ServerFeatureUnavailableCard(
              icon: Icons.schedule_rounded,
              title: '간단한 타임라인',
            ),
        ],
      ),
    );
  }
}
