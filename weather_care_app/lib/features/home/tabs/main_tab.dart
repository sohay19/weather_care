import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../weather_labels.dart';
import '../widgets/missing_data_retry.dart';
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
  final ComparisonResponse? yesterdayComparison;
  final bool comparisonLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onRetryData;
  final Future<void> Function()? onRetryComparison;
  final bool retryingData;
  final ValueChanged<RecommendationType> onDetail;
  final Widget? advertisement;
  final int metricColumns;

  const MainTab({
    super.key,
    required this.today,
    required this.dateLabel,
    required this.mood,
    required this.serverFeaturesAvailable,
    this.detailsLoading = false,
    this.yesterdayComparison,
    this.comparisonLoading = false,
    required this.onRefresh,
    this.onRetryData,
    this.onRetryComparison,
    this.retryingData = false,
    required this.onDetail,
    this.advertisement,
    this.metricColumns = 2,
  }) : assert(metricColumns == 2 || metricColumns == 3);

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
                      title: '${today.region.name} 날씨',
                      subtitle: '화면을 아래로 당기면 최신 날씨 정보를 가져와요',
                    ),
                    SizedBox(height: compact ? 20 : 24),
                    _TopWeatherCard(
                      today: today,
                      mood: mood,
                      compact: compact,
                      comparison: yesterdayComparison,
                      comparisonLoading: comparisonLoading,
                      onRetry: onRetryData,
                      retrying: retryingData,
                      metricColumns: metricColumns,
                    ),
                    SizedBox(height: compact ? 12 : 16),
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
                      ServerFeatureUnavailableCard(
                        icon: Icons.playlist_add_check_rounded,
                        title: 'Check List',
                        onRetry: onRetryData,
                        retrying: retryingData,
                      ),
                    SizedBox(height: compact ? 12 : 16),
                    _YesterdayComparisonSection(
                      comparison: yesterdayComparison,
                      loading: comparisonLoading,
                      onRetry: onRetryComparison,
                    ),
                    SizedBox(height: compact ? 12 : 16),
                    _TodayFutureSection(
                      today: today,
                      current: today.current,
                      mood: mood,
                    ),
                    SizedBox(height: compact ? 12 : 16),
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
                      ServerFeatureUnavailableCard(
                        icon: Icons.schedule_rounded,
                        title: '간단한 타임라인',
                        onRetry: onRetryData,
                        retrying: retryingData,
                      ),
                    if (advertisement != null) ...[
                      SizedBox(height: compact ? 12 : 16),
                      advertisement!,
                    ],
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

class _TodaySection extends StatelessWidget {
  final TodayWeatherResponse today;
  final CurrentWeather current;
  final ComparisonResponse? comparison;
  final bool loading;
  final int metricColumns;

  const _TodaySection({
    required this.today,
    required this.current,
    required this.comparison,
    required this.loading,
    required this.metricColumns,
  });

  @override
  Widget build(BuildContext context) {
    final observedCurrent =
        comparison?.comparisonAvailable == true ? comparison?.current : null;
    final feelingTemperature =
        observedCurrent?.temperature ?? current.temperature;
    final feelingApparentTemperature =
        observedCurrent?.apparentTemperature ?? current.apparentTemperature;
    final feelingSky = observedCurrent?.skyCondition ?? current.sky;
    final feelingStyle = TextStyle(
      color: WeatherCareTheme.textPrimary,
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w600,
    );
    final airQualityState = _airQualityState(current.pm10, current.pm25);
    return Column(
      children: [
        const Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: WeatherCareTheme.primaryDeep,
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                '지금 날씨',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        _TemperatureLine(
          lineKey: const ValueKey('main-current-observation-row'),
          temperatureLabel: '현재 기온',
          temperature: observedCurrent?.temperature,
          apparentLabel: '현재 체감온도',
          apparentTemperature: observedCurrent?.apparentTemperature,
          loading: loading,
        ),
        const SizedBox(height: 13),
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 10),
          child: Row(
            key: const ValueKey('main-weather-feeling'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _weatherSummaryMessage(
                    sky: feelingSky,
                    temperature: feelingTemperature,
                    apparentTemperature: feelingApparentTemperature,
                  ),
                  style: feelingStyle,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: WeatherConditionIcon(
                  condition: feelingSky,
                  color: WeatherCareTheme.textPrimary,
                  size: 25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(15),
          ),
          child: _TopMetricGrid(
            columns: metricColumns,
            metrics: [
              _TopMetric(
                key: const ValueKey('main-top-metric-자외선'),
                icon: Icons.wb_sunny_outlined,
                label: '자외선',
                value: current.uvIndex?.toStringAsFixed(0) ?? '--',
                state: _uvState(current.uvIndex),
              ),
              _TopMetric(
                key: const ValueKey('main-top-metric-대기질'),
                icon: Icons.eco_outlined,
                label: '대기질',
                value: airQualityState == _unavailableMetric
                    ? '--'
                    : airQualityState.label,
                state: airQualityState,
              ),
              _TopMetric(
                key: const ValueKey('main-top-metric-가시거리'),
                icon: Icons.visibility_outlined,
                label: '가시거리',
                value: _visibilityValue(current.visibilityMeters),
                state: _visibilityState(current.visibilityMeters),
              ),
              _TopMetric(
                key: const ValueKey('main-top-metric-습도'),
                icon: Icons.water_drop_outlined,
                label: '습도',
                value: current.humidity == null
                    ? '--'
                    : '${current.humidity!.toStringAsFixed(0)}%',
                state: _humidityState(current.humidity),
              ),
              _TopMetric(
                key: const ValueKey('main-top-metric-바람'),
                icon: Icons.air_rounded,
                label: '바람',
                value: _windValue(
                  current.windDirection,
                  current.windSpeed,
                ),
                state: _windState(current.windSpeed),
              ),
              _TopMetric(
                key: const ValueKey('main-top-metric-일출·일몰'),
                icon: Icons.wb_twilight_rounded,
                label: '일출·일몰',
                value: _sunTimesValue(today.sunriseAt, today.sunsetAt),
                state: _sunState(
                  today.sunriseAt,
                  today.sunsetAt,
                  today.generatedAt,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _YesterdayComparisonSection extends StatelessWidget {
  final ComparisonResponse? comparison;
  final bool loading;
  final Future<void> Function()? onRetry;

  const _YesterdayComparisonSection({
    required this.comparison,
    required this.loading,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final current = comparison?.current;
    final previous = comparison?.comparison;
    final metrics = current == null || previous == null
        ? const <_ComparisonMetricData>[]
        : [
            _ComparisonMetricData(
              subject: '기온은',
              current: current.temperature,
              previous: previous.temperature,
              unit: '℃',
              fractionDigits: 1,
            ),
            _ComparisonMetricData(
              subject: '체감온도는',
              current: current.apparentTemperature,
              previous: previous.apparentTemperature,
              unit: '℃',
              fractionDigits: 1,
            ),
            if (current.pm25 != null && previous.pm25 != null)
              _ComparisonMetricData(
                subject: '초미세먼지는',
                current: current.pm25?.toDouble(),
                previous: previous.pm25?.toDouble(),
                unit: '㎍/㎥',
                fractionDigits: 0,
              )
            else if (current.pm10 != null && previous.pm10 != null)
              _ComparisonMetricData(
                subject: '미세먼지는',
                current: current.pm10?.toDouble(),
                previous: previous.pm10?.toDouble(),
                unit: '㎍/㎥',
                fractionDigits: 0,
              ),
          ].where((metric) => metric.isComparable).toList(growable: false);
    final skyComparable =
        current?.skyCondition != null && previous?.skyCondition != null;
    final available = _hasUsableComparison(comparison);
    final basis = comparison?.basis;

    return Container(
      key: const ValueKey('yesterday-comparison-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.compare_arrows_rounded,
                size: 21,
                color: WeatherCareTheme.primaryDeep,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  '어제와 비교',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            basis?.provider == 'KMA_ASOS'
                ? '현재 관측값과 어제 같은 시각 관측값을 비교해요'
                : '같은 지역의 같은 기준시각 자료만 비교해요',
            style: TextStyle(
              color: WeatherCareTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          if (loading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 10),
            const Text('어제 날씨를 확인하고 있어요.'),
          ] else if (!available) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '받지 못한 자료: 어제와 같은 시각의 관측값',
                  ),
                ),
                if (onRetry != null)
                  IconButton(
                    key: const ValueKey('yesterday-comparison-retry'),
                    tooltip: '어제 비교 자료만 다시 요청',
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints.tightFor(width: 36, height: 36),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    color: WeatherCareTheme.primaryDeep,
                  ),
              ],
            ),
          ] else ...[
            if (skyComparable)
              Text(
                '하늘 상태는 오늘 ${current!.skyCondition}, 어제 ${previous!.skyCondition}였어요.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            if (skyComparable && metrics.isNotEmpty) const SizedBox(height: 10),
            for (var index = 0; index < metrics.length; index++) ...[
              _ComparisonMetric(metric: metrics[index]),
              if (index < metrics.length - 1) const SizedBox(height: 9),
            ],
          ],
        ],
      ),
    );
  }
}

class _TodayFutureSection extends StatelessWidget {
  final TodayWeatherResponse today;
  final CurrentWeather current;
  final String mood;

  const _TodayFutureSection({
    required this.today,
    required this.current,
    required this.mood,
  });

  @override
  Widget build(BuildContext context) {
    final nextForecast = today.nextForecast ?? current;
    final forecastAirQuality = nextForecast.pm25ForecastGrade;
    final airQualityState = forecastAirQuality == null
        ? _airQualityState(nextForecast.pm10, nextForecast.pm25)
        : _pm25ForecastState(forecastAirQuality);
    return Container(
      key: const ValueKey('main-future-weather-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.mood(mood),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.question_mark_outlined,
                size: 18,
                color: WeatherCareTheme.primaryDeep,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '미래 예상 날씨',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${forecastTemperatureLabel(nextForecast.forecastAt)}의 기온과 체감온도를 예상해요',
            style: TextStyle(
              color: WeatherCareTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          _TemperatureLine(
            lineKey: const ValueKey('main-apparent-temperature-row'),
            temperatureLabel: '예상 기온',
            temperature: nextForecast.temperature,
            apparentLabel: '예상 체감온도',
            apparentTemperature: nextForecast.apparentTemperature,
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                _TopMetric(
                  icon: Icons.water_drop_outlined,
                  label: '습도',
                  value: nextForecast.humidity == null
                      ? '--'
                      : '${nextForecast.humidity!.toStringAsFixed(0)}%',
                  state: _humidityState(nextForecast.humidity),
                ),
                _TopMetric(
                  icon: Icons.air_rounded,
                  label: '바람',
                  value: _windValue(
                    nextForecast.windDirection,
                    nextForecast.windSpeed,
                  ),
                  state: _windState(nextForecast.windSpeed),
                ),
                _TopMetric(
                  icon: Icons.wb_sunny_outlined,
                  label: '자외선',
                  value: nextForecast.uvIndex?.toStringAsFixed(0) ?? '--',
                  state: _uvState(nextForecast.uvIndex),
                ),
                _TopMetric(
                  icon: Icons.eco_outlined,
                  label: '대기질',
                  value: airQualityState == _unavailableMetric
                      ? '--'
                      : airQualityState.label,
                  state: airQualityState,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonMetric extends StatelessWidget {
  final _ComparisonMetricData metric;

  const _ComparisonMetric({required this.metric});

  @override
  Widget build(BuildContext context) {
    final difference = metric.current! - metric.previous!;
    final same = difference.abs() < (metric.fractionDigits == 0 ? 0.5 : 0.05);
    final change = same
        ? '어제와 같아요'
        : '어제보다 ${difference.abs().toStringAsFixed(metric.fractionDigits)}${metric.unit} '
            '${difference > 0 ? '높아요' : '낮아요'}';
    String value(double value) =>
        '${value.toStringAsFixed(metric.fractionDigits)}${metric.unit}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: WeatherCareTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${metric.subject} $change.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '오늘 ${value(metric.current!)} · 어제 ${value(metric.previous!)}',
                  style: WeatherCareTheme.microTextStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonMetricData {
  final String subject;
  final double? current;
  final double? previous;
  final String unit;
  final int fractionDigits;

  const _ComparisonMetricData({
    this.subject = '기온은',
    required this.current,
    required this.previous,
    required this.unit,
    required this.fractionDigits,
  });

  bool get isComparable => current != null && previous != null;
}

bool _hasUsableComparison(
  ComparisonResponse? response,
) {
  final current = response?.current;
  final previous = response?.comparison;
  if (response?.comparisonAvailable != true ||
      current == null ||
      previous == null) {
    return false;
  }
  return (current.temperature != null && previous.temperature != null) ||
      (current.apparentTemperature != null &&
          previous.apparentTemperature != null) ||
      (current.pm10 != null && previous.pm10 != null) ||
      (current.pm25 != null && previous.pm25 != null) ||
      (current.skyCondition != null && previous.skyCondition != null);
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
  final ComparisonResponse? comparison;
  final bool comparisonLoading;
  final Future<void> Function()? onRetry;
  final bool retrying;
  final int metricColumns;

  const _TopWeatherCard({
    required this.today,
    required this.mood,
    required this.compact,
    this.comparison,
    this.comparisonLoading = false,
    this.onRetry,
    this.retrying = false,
    required this.metricColumns,
  });
  @override
  Widget build(BuildContext context) {
    final current = today.current;
    final missing = <String>[
      if (current.temperature == null) '예상 기온',
      if (current.apparentTemperature == null) '체감온도',
      if (current.sky == null) '하늘 상태',
      if (current.humidity == null) '습도',
      if (current.windSpeed == null) '바람',
      if (current.uvIndex == null) '자외선',
      if (current.pm25 == null && current.pm10 == null) '대기질',
      if (current.visibilityMeters == null) '가시거리',
      if (today.sunriseAt == null || today.sunsetAt == null) '일출·일몰',
    ];

    return AnimatedContainer(
      key: const ValueKey('main-top-weather-card'),
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
          _TodaySection(
            today: today,
            current: current,
            comparison: comparison,
            loading: comparisonLoading,
            metricColumns: metricColumns,
          ),
          if (missing.isNotEmpty && onRetry != null) ...[
            SizedBox(height: compact ? 8 : 10),
            MissingDataRetry(
              message: '받지 못한 현재 날씨: ${missing.join(' · ')}',
              retryKey: 'main-current-data-retry',
              onRetry: onRetry!,
              retrying: retrying,
            ),
          ],
        ],
      ),
    );
  }
}

class _TemperatureLine extends StatelessWidget {
  final Key lineKey;
  final String temperatureLabel;
  final double? temperature;
  final String apparentLabel;
  final double? apparentTemperature;
  final bool loading;

  const _TemperatureLine({
    required this.lineKey,
    required this.temperatureLabel,
    required this.temperature,
    required this.apparentLabel,
    required this.apparentTemperature,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: WeatherCareTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(13),
      ),
      child: FittedBox(
        key: lineKey,
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TemperatureLabel(temperatureLabel),
            const SizedBox(width: 8),
            _TemperatureValue(value: temperature, loading: loading),
            const SizedBox(width: 16),
            _TemperatureLabel(apparentLabel),
            const SizedBox(width: 8),
            _TemperatureValue(value: apparentTemperature, loading: loading),
          ],
        ),
      ),
    );
  }
}

class _TemperatureLabel extends StatelessWidget {
  final String text;

  const _TemperatureLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: WeatherCareTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TemperatureValue extends StatelessWidget {
  final double? value;
  final bool loading;

  const _TemperatureValue({required this.value, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Text(
      value == null
          ? loading
              ? '확인 중'
              : '자료 없음'
          : '${value!.toStringAsFixed(1)}℃',
      style: const TextStyle(
        color: WeatherCareTheme.primaryDeep,
        fontSize: 16,
        fontWeight: FontWeight.w800,
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
    super.key,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  style: WeatherCareTheme.microTextStyle.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(icon, size: 13, color: state.color),
                const SizedBox(width: 3),
                Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: state.color,
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopMetricGrid extends StatelessWidget {
  final List<_TopMetric> metrics;
  final int columns;

  const _TopMetricGrid({required this.metrics, required this.columns})
      : assert(metrics.length == 6),
        assert(columns == 2 || columns == 3);

  @override
  Widget build(BuildContext context) {
    final rowCount = (metrics.length / columns).ceil();
    return Column(
      children: List.generate(rowCount, (rowIndex) {
        final start = rowIndex * columns;
        final end = (start + columns).clamp(0, metrics.length);
        return Padding(
          padding: EdgeInsets.only(top: rowIndex == 0 ? 0 : 18),
          child: Row(
            children: [
              ...metrics.sublist(start, end),
              for (var index = end - start; index < columns; index++)
                const Expanded(child: SizedBox()),
            ],
          ),
        );
      }),
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

_MetricState _humidityState(double? value) {
  if (value == null) return _unavailableMetric;
  if (value <= 35) {
    return const _MetricState('건조', WeatherCareTheme.attentionDeep);
  }
  if (value < 70) {
    return const _MetricState('쾌적', WeatherCareTheme.primaryDeep);
  }
  if (value < 80) {
    return const _MetricState('습한 편', WeatherCareTheme.primaryDeep);
  }
  return const _MetricState('매우 습함', WeatherCareTheme.attentionDeep);
}

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

_MetricState _pm25ForecastState(String? value) {
  if (value == null || value.trim().isEmpty) return _unavailableMetric;
  final grade = value.trim();
  if (grade.contains('매우 나쁨') || grade.contains('매우 높음')) {
    return _MetricState(grade, WeatherCareTheme.danger);
  }
  if (grade.contains('나쁨') || grade.contains('높음')) {
    return _MetricState(grade, WeatherCareTheme.attentionDeep);
  }
  return _MetricState(grade, WeatherCareTheme.primaryDeep);
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

_MetricState _airQualityState(int? pm10, int? pm25) {
  final states = [
    if (pm10 != null) _pm10State(pm10),
    if (pm25 != null) _pm25State(pm25),
  ];
  if (states.isEmpty) return _unavailableMetric;
  const severity = {
    '좋음': 0,
    '보통': 1,
    '나쁨': 2,
    '매우 나쁨': 3,
  };
  return states.reduce(
    (left, right) => (severity[right.label] ?? 0) > (severity[left.label] ?? 0)
        ? right
        : left,
  );
}

_MetricState _visibilityState(double? meters) {
  if (meters == null) return _unavailableMetric;
  if (meters < 200) {
    return const _MetricState('매우 짧음', WeatherCareTheme.danger);
  }
  if (meters < 1000) {
    return const _MetricState('짧음', WeatherCareTheme.danger);
  }
  if (meters < 5000) {
    return const _MetricState('나쁨', WeatherCareTheme.attentionDeep);
  }
  if (meters < 10000) {
    return const _MetricState('보통', WeatherCareTheme.primaryDeep);
  }
  if (meters < 20000) {
    return const _MetricState('좋음', WeatherCareTheme.primaryDeep);
  }
  return const _MetricState('매우 좋음', WeatherCareTheme.primaryDeep);
}

String _visibilityValue(double? meters) {
  if (meters == null) return '--';
  if (meters >= 20000) return '20km+';
  if (meters >= 1000) {
    final kilometres = meters / 1000;
    return '${kilometres == kilometres.roundToDouble() ? kilometres.toStringAsFixed(0) : kilometres.toStringAsFixed(1)}km';
  }
  return '${meters.round()}m';
}

String _windValue(double? direction, double? speed) {
  if (direction == null && speed == null) return '--';
  final directionLabel = _windDirectionLabel(direction);
  if (speed == null) return directionLabel == null ? '--' : '$directionLabel풍';
  return '${directionLabel == null ? '' : '$directionLabel '}'
      '${speed.toStringAsFixed(1)}m/s';
}

String? _windDirectionLabel(double? direction) {
  if (direction == null || !direction.isFinite) return null;
  const labels = ['북', '북동', '동', '남동', '남', '남서', '서', '북서'];
  final normalized = ((direction % 360) + 360) % 360;
  return labels[((normalized + 22.5) ~/ 45) % labels.length];
}

String _sunTimesValue(String? sunriseAt, String? sunsetAt) {
  final sunrise = _koreaClock(sunriseAt);
  final sunset = _koreaClock(sunsetAt);
  if (sunrise == null && sunset == null) return '--';
  return '${sunrise ?? '--:--'} · ${sunset ?? '--:--'}';
}

_MetricState _sunState(
  String? sunriseAt,
  String? sunsetAt,
  String? generatedAt,
) {
  final sunrise = _parseTimestamp(sunriseAt);
  final sunset = _parseTimestamp(sunsetAt);
  final now = _parseTimestamp(generatedAt) ?? DateTime.now().toUtc();
  if (sunrise == null || sunset == null) return _unavailableMetric;
  if (now.isBefore(sunrise)) {
    return const _MetricState('해 뜨기 전', WeatherCareTheme.textSecondary);
  }
  if (!now.isBefore(sunset)) {
    return const _MetricState('해가 진 뒤', WeatherCareTheme.textSecondary);
  }
  if (sunset.difference(now) <= const Duration(hours: 1)) {
    return const _MetricState('곧 일몰', WeatherCareTheme.attentionDeep);
  }
  return const _MetricState('해가 떠 있음', WeatherCareTheme.primaryDeep);
}

String? _koreaClock(String? timestamp) {
  final value = _parseTimestamp(timestamp);
  if (value == null) return null;
  final korea = value.add(const Duration(hours: 9));
  return '${korea.hour}:'
      '${korea.minute.toString().padLeft(2, '0')}';
}

DateTime? _parseTimestamp(String? timestamp) {
  if (timestamp == null) return null;
  return DateTime.tryParse(timestamp)?.toUtc();
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
  required double? temperature,
  required double? apparentTemperature,
}) {
  final weatherExpression = _weatherExpression(sky);
  if (apparentTemperature == null) {
    return '$weatherExpression 체감 정보는 계산조건이 맞을 때 표시해요.';
  }

  final displayedApparentTemperature =
      double.parse(apparentTemperature.toStringAsFixed(1));

  final comparison = temperature == null
      ? null
      : _apparentTemperatureComparison(
          temperature: double.parse(temperature.toStringAsFixed(1)),
          apparentTemperature: displayedApparentTemperature,
        );
  final feeling =
      switch (_apparentTemperatureLabel(displayedApparentTemperature)) {
    '위험한 더위' => '위험할 만큼 매우 덥게',
    '더위 경계' => '매우 덥게',
    '더위 주의' => '더위가 강하게',
    '더움' => '꽤 덥게',
    '조금 더움' => '조금 덥게',
    '선선한 편' => '선선하게',
    '쌀쌀한 편' => '쌀쌀하게',
    _ => '춥게',
  };
  return '$weatherExpression '
      '${comparison == null ? '' : '$comparison, '}'
      '체감 상 $feeling 느껴질 수 있어요.';
}

String _apparentTemperatureComparison({
  required double temperature,
  required double apparentTemperature,
}) {
  final difference = apparentTemperature - temperature;
  if (difference.abs() < 0.05) return '실제 기온과 비슷하지만';
  return '실제 기온보다 ${difference.abs().toStringAsFixed(1)}℃ '
      '${difference > 0 ? '높지만' : '낮지만'}';
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
