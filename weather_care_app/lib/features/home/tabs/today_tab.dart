import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/hourly_forecast_section.dart';
import '../widgets/pull_to_refresh_data_hint.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/weather_card.dart';

class TodayTab extends StatelessWidget {
  final TodayWeatherResponse today;
  final Future<void> Function() onRefresh;
  final Widget? advertisement;

  const TodayTab({
    super.key,
    required this.today,
    required this.onRefresh,
    this.advertisement,
  });

  @override
  Widget build(BuildContext context) {
    final showRefreshHint = _todayHasMissingData(today);
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
            WeatherInfoCard(current: today.current),
            const SizedBox(height: 16),
            if (advertisement != null) ...[
              advertisement!,
              const SizedBox(height: 16),
            ],
            HourlyForecastSection(items: today.hourly),
            if (showRefreshHint) ...[
              const SizedBox(height: 16),
              const PullToRefreshDataHint(),
            ],
          ],
        ),
      ),
    );
  }
}

bool _todayHasMissingData(TodayWeatherResponse today) {
  final current = today.current;
  if (current.temperature == null ||
      current.apparentTemperature == null ||
      current.humidity == null ||
      current.windSpeed == null ||
      current.uvIndex == null ||
      current.pm10 == null ||
      current.pm25 == null ||
      current.sky == null ||
      today.hourly.isEmpty) {
    return true;
  }
  return today.hourly.any(
    (item) =>
        item.time == '--' ||
        item.temperature == null ||
        item.apparentTemperature == null ||
        item.precipitationProbability == null ||
        item.windSpeed == null ||
        item.skyCondition == null,
  );
}
