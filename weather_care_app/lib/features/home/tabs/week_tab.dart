import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../models/weather.dart';
import '../../../theme/recommendation_theme.dart';
import '../../../theme/weather_theme.dart';
import '../../../utils/korea_date.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/weather_condition_icon.dart';
import '../widgets/week_presentation.dart';

class WeekTab extends StatefulWidget {
  final WeeklyWeatherResponse weekly;
  final bool serverFeaturesAvailable;
  final Future<void> Function() onRefresh;
  final DateTime Function()? now;

  const WeekTab({
    super.key,
    required this.weekly,
    required this.serverFeaturesAvailable,
    required this.onRefresh,
    this.now,
  });

  @override
  State<WeekTab> createState() => _WeekTabState();
}

class _WeekTabState extends State<WeekTab> with WidgetsBindingObserver {
  Timer? _midnightTimer;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    _midnightTimer = Timer(untilKoreaMidnight(_now()), () {
      if (!mounted) return;
      setState(() {});
      _scheduleMidnight();
    });
  }

  @override
  void didUpdateWidget(covariant WeekTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleMidnight();
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekly = widget.weekly;
    final today = dateInKorea(_now());
    return RefreshIndicator(
      color: WeatherCareTheme.primary,
      onRefresh: widget.onRefresh,
      child: ListView(
        key: const ValueKey('week-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TabPageHeader(
            eyebrow: 'WEEK',
            title: '날짜별 날씨',
            subtitle: weekPeriodLabel(weekly.days),
            icon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: 18),
          if (weekly.days.isNotEmpty)
            _WeekSummary(
              days: weekly.days,
              serverFeaturesAvailable: widget.serverFeaturesAvailable,
            )
          else
            const Text('자료를 받아오면 해당 날짜의 날씨와 준비물을 표시해요.'),
          const SizedBox(height: 16),
          for (var index = 0; index < weekly.days.length; index++) ...[
            _WeekDayCard(
              day: weekly.days[index],
              isToday: weekly.days[index].forecastDate == today,
              serverFeaturesAvailable: widget.serverFeaturesAvailable,
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
    final summary = buildWeekSummary(days,
        serverFeaturesAvailable: serverFeaturesAvailable);

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: WeatherCareTheme.mood('clear'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '제공된 예보 요약',
            style: TextStyle(
              fontFamily: WeatherCareTheme.fontNeoHyundai,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '받은 예보와 표시할 준비물 추천을 기준으로 집계해요.',
            style: WeatherCareTheme.microTextStyle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 15),
          LayoutBuilder(builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
            final columns =
                (constraints.maxWidth / (110 * scale)).floor().clamp(1, 3);
            final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
            final metrics = [
              _SummaryMetric(
                key: const ValueKey('week-summary-precipitation'),
                icon: const WeatherConditionIcon(
                  condition: '비/눈',
                  size: 21,
                  color: WeatherCareTheme.primaryDeep,
                ),
                label: '비/눈 예보',
                metric: summary.precipitation,
              ),
              _SummaryMetric(
                key: const ValueKey('week-summary-temperature'),
                icon: const Icon(
                  Icons.device_thermostat_rounded,
                  color: WeatherCareTheme.primaryDeep,
                  size: 19,
                ),
                label: '확인된 최고기온',
                metric: summary.maximum,
              ),
              _SummaryMetric(
                key: const ValueKey('week-summary-preparations'),
                icon: const Icon(
                  Icons.work_outline_rounded,
                  color: WeatherCareTheme.primaryDeep,
                  size: 19,
                ),
                label: '준비물 추천',
                metric: summary.preparations,
              ),
            ];
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final metric in metrics)
                SizedBox(width: width, child: metric),
            ]);
          }),
          if (summary.excludedNotice != null) ...[
            const SizedBox(height: 8),
            Text(summary.excludedNotice!,
                style: WeatherCareTheme.microTextStyle),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final Widget icon;
  final String label;
  final WeekSummaryMetric metric;

  const _SummaryMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          icon,
          const SizedBox(height: 5),
          Text(metric.value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: WeatherCareTheme.microTextStyle,
          ),
          const SizedBox(height: 4),
          Text(metric.detail,
              textAlign: TextAlign.center,
              style: WeatherCareTheme.microTextStyle.copyWith(fontSize: 10)),
        ],
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
    final weatherLabel = weekWeatherLabel(day);
    final recommendations = serverFeaturesAvailable
        ? weekRecommendations(day)
        : <WeatherRecommendation>[];
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                weekDayLabel(day),
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
                  key: ValueKey('week-today-${day.forecastDate}'),
                  style: WeatherCareTheme.specialLabelStyle.copyWith(
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
              child: WeatherConditionIcon(
                condition: weatherLabel,
                color: WeatherCareTheme.primaryDeep,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                weatherLabel ?? '날씨 자료 없음',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ]),
          if (weatherLabel != null && day.weatherDataComplete == false)
            Text('일부 시간대 날씨 자료 없음', style: WeatherCareTheme.microTextStyle),
          const SizedBox(height: 6),
          Text(
            '${weekTemperatureLabel(day, maximum: false)} · ${weekTemperatureLabel(day, maximum: true)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (day.minTemperatureSource == 'HOURLY' ||
              day.maxTemperatureSource == 'HOURLY')
            Text('시간별 최저·최고는 받은 시간대만 비교한 값이에요.',
                style: WeatherCareTheme.microTextStyle),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recommendations.isEmpty)
                Text(
                  !serverFeaturesAvailable
                      ? '운영 서버 미연결로 준비물 미지원'
                      : day.recommendationsAvailable
                          ? '표시할 준비물 추천 없음'
                          : '준비물 추천 자료 없음',
                  style: WeatherCareTheme.microTextStyle.copyWith(fontSize: 11),
                )
              else
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final recommendation in recommendations)
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
                            Flexible(
                                child: Text(
                              recommendation.type.label,
                              style: const TextStyle(
                                fontFamily: WeatherCareTheme.fontMona,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            )),
                          ],
                        ),
                      ),
                  ],
                ),
              if (recommendations.isNotEmpty && !day.recommendationsAvailable)
                Text('일부 준비물 추천 자료를 확인하기 어려워요',
                    style: WeatherCareTheme.microTextStyle),
            ],
          ),
        ],
      ),
    );
  }
}
