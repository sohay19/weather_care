import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../weather_labels.dart';
import '../widgets/recommendation_bag_section.dart';
import '../widgets/server_feature_unavailable_card.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/timeline_section.dart';
import '../widgets/weather_condition_icon.dart';
import '../widgets/weather_brief_text.dart';

class MainTab extends StatelessWidget {
  final TodayWeatherResponse today;
  final String dateLabel;
  final String mood;
  final bool serverFeaturesAvailable;
  final bool detailsLoading;
  final Future<void> Function() onRefresh;
  final ValueChanged<RecommendationType> onDetail;

  const MainTab({
    super.key,
    required this.today,
    required this.dateLabel,
    required this.mood,
    required this.serverFeaturesAvailable,
    this.detailsLoading = false,
    required this.onRefresh,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: WeatherCareTheme.primary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          return CustomScrollView(
            key: const ValueKey('main-tab'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  compact ? 8 : 12,
                  16,
                  24,
                ),
                sliver: SliverList.list(
                  children: [
                    TabPageHeader(
                      eyebrow: dateLabel,
                      title: '${today.region.name} 지금 날씨',
                      subtitle: '화면을 아래로 당기면 최신 날씨 정보를 가져와요',
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    _TopWeatherCard(
                      today: today,
                      mood: mood,
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    if (detailsLoading)
                      const _ProgressiveLoadingCard(
                        icon: Icons.playlist_add_check_rounded,
                        title: 'Check List를 불러오고 있어요',
                      )
                    else if (serverFeaturesAvailable)
                      RecommendationBagSection(
                        regionName: today.region.name,
                        recommendations: today.recommendations,
                        onDetail: onDetail,
                      )
                    else
                      const ServerFeatureUnavailableCard(
                        icon: Icons.playlist_add_check_rounded,
                        title: 'Check List',
                      ),
                    SizedBox(height: compact ? 10 : 14),
                    if (detailsLoading)
                      const _ProgressiveLoadingCard(
                        icon: Icons.schedule_rounded,
                        title: '시간별 자료를 불러오고 있어요',
                      )
                    else if (serverFeaturesAvailable)
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
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressiveLoadingCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ProgressiveLoadingCard({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Row(
        children: [
          Icon(icon, color: WeatherCareTheme.primaryDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }
}

class _TopWeatherCard extends StatelessWidget {
  final TodayWeatherResponse today;
  final String mood;
  final bool compact;

  const _TopWeatherCard({
    required this.today,
    required this.mood,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final current = today.current;
    final apparentTemperature = current.apparentTemperature;
    final fineDustValue = current.pm25 ?? current.pm10;
    final usesPm25 = current.pm25 != null;
    final feelingStyle = TextStyle(
      color: WeatherCareTheme.textPrimary,
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w600,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 13 : 16),
      decoration: WeatherCareTheme.mood(mood),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WeatherBriefText(
            text: today.brief,
            expiresAt: today.briefExpiresAt,
            style: TextStyle(
              fontFamily: WeatherCareTheme.fontNeoHyundai,
              color: WeatherCareTheme.textPrimary,
              fontSize: compact ? 21 : 23,
              height: 1.24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.45,
            ),
          ),
          SizedBox(height: compact ? 22 : 28),
          FittedBox(
            key: const ValueKey('main-apparent-temperature-row'),
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  forecastTemperatureLabel(current.forecastAt),
                  style: const TextStyle(
                    color: WeatherCareTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  current.temperature == null
                      ? '자료 없음'
                      : '${current.temperature!.toStringAsFixed(1)}℃',
                  style: const TextStyle(
                    color: WeatherCareTheme.primaryDeep,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  '예상 체감온도',
                  style: TextStyle(
                    color: WeatherCareTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  apparentTemperature == null
                      ? '자료 없음'
                      : '${apparentTemperature.toStringAsFixed(1)}℃',
                  style: const TextStyle(
                    color: WeatherCareTheme.primaryDeep,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Row(
            key: const ValueKey('main-weather-feeling'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _weatherSummaryMessage(
                    sky: current.sky,
                    apparentTemperature: apparentTemperature,
                  ),
                  style: feelingStyle,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: WeatherConditionIcon(
                  condition: current.sky,
                  color: WeatherCareTheme.textPrimary,
                  size: compact ? 20 : 23,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Container(
            padding: EdgeInsets.symmetric(vertical: compact ? 7 : 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                _TopMetric(
                  icon: Icons.water_drop_outlined,
                  label: '습도',
                  value: current.humidity == null
                      ? '--'
                      : '${current.humidity!.toStringAsFixed(0)}%',
                  state: _humidityState(current.humidity),
                ),
                _TopMetric(
                  icon: Icons.air_rounded,
                  label: '풍속',
                  value: current.windSpeed == null
                      ? '--'
                      : '${current.windSpeed!.toStringAsFixed(1)}m/s',
                  state: _windState(current.windSpeed),
                ),
                _TopMetric(
                  icon: Icons.wb_sunny_outlined,
                  label: '자외선',
                  value: current.uvIndex?.toStringAsFixed(0) ?? '--',
                  state: _uvState(current.uvIndex),
                ),
                _TopMetric(
                  icon: Icons.grain_rounded,
                  label: usesPm25 ? '초미세먼지' : '미세먼지',
                  value: fineDustValue == null ? '--' : '$fineDustValue㎍',
                  state: usesPm25
                      ? _pm25State(current.pm25)
                      : _pm10State(current.pm10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final _MetricState state;

  const _TopMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label $value, ${state.label}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: state.color),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: state.color,
                fontSize: 10.5,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WeatherCareTheme.microTextStyle.copyWith(fontSize: 8.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricState {
  final String label;
  final Color color;

  const _MetricState(this.label, this.color);
}

const _unavailableMetric =
    _MetricState('정보 없음', WeatherCareTheme.textSecondary);

_MetricState _humidityState(double? value) => value == null
    ? _unavailableMetric
    : const _MetricState('실외 상대습도', WeatherCareTheme.primaryDeep);

_MetricState _windState(double? value) {
  if (value == null) return _unavailableMetric;
  if (value < 4) {
    return const _MetricState('약한 바람', WeatherCareTheme.primaryDeep);
  }
  if (value < 9) {
    return const _MetricState('약간 강한 바람', WeatherCareTheme.primaryDeep);
  }
  if (value < 14) {
    return const _MetricState('강한 바람', WeatherCareTheme.attentionDeep);
  }
  return const _MetricState('매우 강한 바람', WeatherCareTheme.danger);
}

_MetricState _uvState(double? value) {
  if (value == null) return _unavailableMetric;
  if (value <= 2) {
    return const _MetricState('낮음', WeatherCareTheme.primaryDeep);
  }
  if (value <= 5) {
    return const _MetricState('보통', WeatherCareTheme.primaryDeep);
  }
  if (value <= 7) {
    return const _MetricState('높음', WeatherCareTheme.attentionDeep);
  }
  if (value <= 10) {
    return const _MetricState('매우 높음', WeatherCareTheme.danger);
  }
  return const _MetricState('위험', WeatherCareTheme.danger);
}

_MetricState _pm25State(int? value) {
  if (value == null) return _unavailableMetric;
  if (value <= 15) {
    return const _MetricState('좋음', WeatherCareTheme.primaryDeep);
  }
  if (value <= 35) {
    return const _MetricState('보통', WeatherCareTheme.primaryDeep);
  }
  if (value <= 75) {
    return const _MetricState('나쁨', WeatherCareTheme.attentionDeep);
  }
  return const _MetricState('매우 나쁨', WeatherCareTheme.danger);
}

_MetricState _pm10State(int? value) {
  if (value == null) return _unavailableMetric;
  if (value <= 30) {
    return const _MetricState('좋음', WeatherCareTheme.primaryDeep);
  }
  if (value <= 80) {
    return const _MetricState('보통', WeatherCareTheme.primaryDeep);
  }
  if (value <= 150) {
    return const _MetricState('나쁨', WeatherCareTheme.attentionDeep);
  }
  return const _MetricState('매우 나쁨', WeatherCareTheme.danger);
}

String _weatherExpression(String? sky) {
  final value = sky ?? '';
  if (value.contains('비')) return '비가 내리는 날씨예요.';
  if (value.contains('눈')) return '눈이 내리는 날씨예요.';
  if (value.contains('흐림') || value.contains('구름')) {
    return '구름이 많은 날씨예요.';
  }
  if (value.contains('맑음')) return '맑은 하늘이 이어지는 날씨예요.';
  return '하늘 상태 자료가 없어 날씨를 확인하기 어려워요.';
}

String _weatherSummaryMessage({
  required String? sky,
  required double? apparentTemperature,
}) {
  final weatherExpression = _weatherExpression(sky);
  if (apparentTemperature == null) {
    return '$weatherExpression 체감 정보는 계산조건이 맞을 때 표시해요.';
  }

  final feeling = switch (_apparentTemperatureLabel(apparentTemperature)) {
    '위험한 더위' => '위험할 만큼 매우 덥게',
    '더위 경계' => '매우 덥게',
    '더위 주의' => '더위가 강하게',
    '더움' => '꽤 덥게',
    '조금 더움' => '조금 덥게',
    '선선한 편' => '선선하게',
    '쌀쌀한 편' => '쌀쌀하게',
    _ => '춥게',
  };
  return '$weatherExpression 체감 상 $feeling 느껴질 수 있어요.';
}

String _apparentTemperatureLabel(double temperature) {
  if (temperature >= 38) return '위험한 더위';
  if (temperature >= 35) return '더위 경계';
  if (temperature >= 33) return '더위 주의';
  if (temperature >= 28) return '더움';
  if (temperature >= 20) return '조금 더움';
  if (temperature >= 10) return '선선한 편';
  if (temperature >= 0) return '쌀쌀한 편';
  return '추운 날씨';
}
