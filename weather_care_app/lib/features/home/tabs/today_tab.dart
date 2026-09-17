import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/hourly_forecast_section.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/weather_card.dart';

class TodayTab extends StatelessWidget {
  final TodayWeatherResponse today;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onRetryData;
  final bool retrying;
  final Widget? advertisement;

  const TodayTab({
    super.key,
    required this.today,
    required this.onRefresh,
    this.onRetryData,
    this.retrying = false,
    this.advertisement,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: WeatherCareTheme.primary,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        key: const ValueKey('today-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabPageHeader(
              eyebrow: 'TODAY',
              title: '오늘 하루',
              subtitle: '현재 상태와 시간별 예보를 함께 보여드려요',
              icon: Icons.schedule_rounded,
            ),
            const SizedBox(height: 18),
            WeatherInfoCard(
              current: today.current,
              onRetryMissingData: onRetryData,
              retrying: retrying,
            ),
            const SizedBox(height: 16),
            if (advertisement != null) ...[
              advertisement!,
              const SizedBox(height: 16),
            ],
            HourlyForecastSection(
              items: today.hourly,
              onRetryMissingData: onRetryData,
              retrying: retrying,
            ),
          ],
        ),
      ),
    );
  }
}
