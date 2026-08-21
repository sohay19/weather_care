import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../models/weather.dart';
import '../../../theme/recommendation_theme.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/weather_condition_icon.dart';

class WeekTab extends StatelessWidget {
  final WeeklyWeatherResponse weekly;
  final bool serverFeaturesAvailable;
  final Future<void> Function() onRefresh;

  const WeekTab({
    super.key,
    required this.weekly,
    required this.serverFeaturesAvailable,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: WeatherCareTheme.primary,
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey('week-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TabPageHeader(
            eyebrow: 'WEEK',
            title: '이번주 날씨',
            subtitle: '한 주의 날씨와 준비물을 미리 살펴봐요',
            icon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: 18),
          _WeekSummary(
            days: weekly.days,
            serverFeaturesAvailable: serverFeaturesAvailable,
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < weekly.days.length; index++) ...[
            _WeekDayCard(
              day: weekly.days[index],
              isToday: index == 0,
              serverFeaturesAvailable: serverFeaturesAvailable,
            ),
            if (index < weekly.days.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _WeekSummary extends StatelessWidget {
  final List<WeeklyForecastItem> days;
  final bool serverFeaturesAvailable;

  const _WeekSummary({
    required this.days,
    required this.serverFeaturesAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final precipitationDays =
        days.where((day) => _isPrecipitationWeather(day.weatherLabel)).length;
    final prepDays = days.where((day) => day.recommendations.isNotEmpty).length;
    final maxTemperature = days
        .map((day) => double.tryParse(day.max))
        .whereType<double>()
        .fold<double?>(
            null, (max, value) => max == null || value > max ? value : max);

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: WeatherCareTheme.mood('clear'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 주 한눈에',
            style: TextStyle(
              fontFamily: WeatherCareTheme.fontNeoHyundai,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '비 오는 날과 준비물이 필요한 날을 먼저 확인하세요.',
            style: WeatherCareTheme.microTextStyle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _SummaryMetric(
                icon: const WeatherConditionIcon(
                  condition: '비/눈',
                  size: 21,
                  color: WeatherCareTheme.primaryDeep,
                ),
                label: '비/눈 예보',
                value: '$precipitationDays일',
              ),
              _SummaryMetric(
                icon: const Icon(
                  Icons.device_thermostat_rounded,
                  color: WeatherCareTheme.primaryDeep,
                  size: 19,
                ),
                label: '최고 기온',
                value: maxTemperature == null
                    ? '--'
                    : '${maxTemperature.toStringAsFixed(0)}°C',
              ),
              _SummaryMetric(
                icon: const Icon(
                  Icons.work_outline_rounded,
                  color: WeatherCareTheme.primaryDeep,
                  size: 19,
                ),
                label: '준비물',
                value: serverFeaturesAvailable ? '$prepDays일' : '미지원',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final Widget icon;
  final String label;
  final String value;

  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            icon,
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(
              label,
              style: WeatherCareTheme.microTextStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDayCard extends StatelessWidget {
  final WeeklyForecastItem day;
  final bool isToday;
  final bool serverFeaturesAvailable;

  const _WeekDayCard({
    required this.day,
    required this.isToday,
    required this.serverFeaturesAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isToday ? WeatherCareTheme.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isToday
              ? WeatherCareTheme.primaryBorder
              : WeatherCareTheme.outline,
        ),
        boxShadow: const [
          BoxShadow(
            color: WeatherCareTheme.shadow,
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 43,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.date,
                  style: TextStyle(
                    color: isToday
                        ? WeatherCareTheme.primaryDeep
                        : WeatherCareTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (isToday)
                  Text(
                    '오늘',
                    style: WeatherCareTheme.specialLabelStyle.copyWith(
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              shape: BoxShape.circle,
            ),
            child: WeatherConditionIcon(
              condition: day.weatherLabel,
              color: WeatherCareTheme.primaryDeep,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.weatherLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (day.recommendations.isEmpty)
                  Text(
                    serverFeaturesAvailable ? '준비물 없음' : '운영 서버 미연결로 준비물 미지원',
                    style:
                        WeatherCareTheme.microTextStyle.copyWith(fontSize: 11),
                  )
                else
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final recommendation in day.recommendations.take(3))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: recommendation.type.softColor,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                recommendation.type.icon,
                                size: 12,
                                color: recommendation.type.accentColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                recommendation.type.label,
                                style: const TextStyle(
                                  fontFamily: WeatherCareTheme.fontMona,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: WeatherCareTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              children: [
                TextSpan(text: '${day.min}°C'),
                const TextSpan(
                  text: ' / ',
                  style: TextStyle(color: WeatherCareTheme.textSecondary),
                ),
                TextSpan(
                  text: '${day.max}°C',
                  style: const TextStyle(color: WeatherCareTheme.primaryDeep),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isPrecipitationWeather(String label) {
  return label.contains('비') || label.contains('소나기') || label.contains('눈');
}
