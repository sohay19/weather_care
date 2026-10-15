import '../../../utils/weather_number.dart';
import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../models/selectable_region.dart';
import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../weather_data_phase.dart';
import '../widgets/missing_data_retry.dart';
import '../widgets/hourly_forecast_section.dart';
import '../widgets/weather_data_notice.dart';
import '../widgets/recommendation_bag_section.dart';
import '../widgets/server_feature_unavailable_card.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/weather_condition_icon.dart';
import '../widgets/weather_brief_text.dart';

class MainTab extends StatelessWidget {
  final TodayWeatherResponse today;
  final WeatherDataPhase dataPhase;
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
  final List<ForecastRegion> savedRegions;
  final String? selectedRegionKey;
  final bool gpsSelected;
  final VoidCallback? onSelectGps;
  final ValueChanged<ForecastRegion>? onSelectRegion;
  final VoidCallback? onAddRegion;
  final VoidCallback? onOpenWeatherMap;

  const MainTab({
    super.key,
    required this.today,
    this.dataPhase = WeatherDataPhase.ready,
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
    this.savedRegions = const [],
    this.selectedRegionKey,
    this.gpsSelected = true,
    this.onSelectGps,
    this.onSelectRegion,
    this.onAddRegion,
    this.onOpenWeatherMap,
  });

  @override
  Widget build(BuildContext context) => WeatherDataPhaseScope(
        phase: dataPhase,
        child: _content(context),
      );

  Widget _content(BuildContext context) {
    return RefreshIndicator(
      color: WeatherCareTheme.of(context).primary,
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
                      subtitle: '예보 기준 구역 지도를 확인할 수 있어요',
                      subtitleTrailing: IconButton(
                        key: const ValueKey('main-weather-map-info'),
                        icon: const Icon(Icons.info_outline_rounded, size: 18),
                        tooltip: '예보 기준 구역 지도 열기',
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: WeatherCareTheme.of(context).primary,
                        ),
                        onPressed: onOpenWeatherMap,
                      ),
                      trailing: PopupMenuButton<String>(
                        key: const ValueKey('main-region-menu'),
                        tooltip: '지역 선택',
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        onSelected: (value) {
                          if (value == 'gps') {
                            onSelectGps?.call();
                          } else if (value == 'add') {
                            onAddRegion?.call();
                          } else {
                            for (final region in savedRegions) {
                              if (region.key == value) {
                                onSelectRegion?.call(region);
                                break;
                              }
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'gps',
                            child: Row(children: [
                              if (gpsSelected)
                                const Icon(Icons.check_rounded, size: 18),
                              const SizedBox(width: 8),
                              const Text('현재 위치'),
                            ]),
                          ),
                          for (final region in savedRegions)
                            PopupMenuItem(
                              value: region.key,
                              child: Row(children: [
                                if (!gpsSelected &&
                                    selectedRegionKey == region.key)
                                  const Icon(Icons.check_rounded, size: 18),
                                const SizedBox(width: 8),
                                Flexible(child: Text(region.fullName)),
                              ]),
                            ),
                          const PopupMenuItem(
                            value: 'add',
                            child: Row(children: [
                              Icon(Icons.add_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('구역 추가'),
                            ]),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 20 : 24),
                    if (detailsLoading)
                      const _ProgressiveLoadingCard(
                        icon: Icons.playlist_add_check_rounded,
                        title: 'Check List를 불러오고 있어요',
                      )
                    else if (serverFeaturesAvailable)
                      RecommendationBagSection(
                        regionName: today.region.name,
                        recommendations: today.recommendations,
                        briefing: today.briefing,
                        briefingTimeline: today.briefingTimeline,
                        generatedAt: today.generatedAt,
                        receivedAt: today.receivedAt,
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
                    if (dataPhase != WeatherDataPhase.ready) ...[
                      WeatherDataNotice(phase: dataPhase, subject: '오늘 날씨'),
                      SizedBox(height: compact ? 12 : 16),
                    ],
                    _TopWeatherCard(
                      today: today,
                      yesterday: yesterdayComparison,
                      mood: mood,
                      compact: compact,
                      onRetry: onRetryData,
                      onRetryComparison: onRetryComparison,
                      retrying: retryingData,
                      comparisonLoading: comparisonLoading,
                    ),
                    SizedBox(height: compact ? 12 : 16),
                    HourlyForecastSection(
                      keyPrefix: 'main',
                      items: today.timelineHourly ?? today.hourly,
                      generatedAt: today.generatedAt,
                      receivedAt: today.receivedAt,
                      dataPhase: dataPhase,
                      onRetryMissingData: onRetryData,
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
  final ComparisonResponse? yesterday;
  final CurrentWeather current;
  final Future<void> Function()? onRetryComparison;
  final bool comparisonLoading;

  const _TodaySection({
    required this.yesterday,
    required this.current,
    required this.comparisonLoading,
    this.onRetryComparison,
  });

  @override
  Widget build(BuildContext context) {
    final phase = WeatherDataPhaseScope.of(context);
    final feelingStyle = TextStyle(
      color: WeatherCareTheme.of(context).textPrimary,
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w600,
    );
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.today_outlined,
              size: 18,
              color: WeatherCareTheme.of(context).primaryDeep,
            ),
            const SizedBox(width: 9),
            const Expanded(
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
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 10),
          child: Row(
            key: const ValueKey('main-weather-feeling'),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  current.sky == null && phase != WeatherDataPhase.ready
                      ? phase.explanation
                      : _weatherSummaryMessage(sky: current.sky),
                  style: feelingStyle,
                ),
              ),
              const SizedBox(width: 8),
              WeatherConditionIcon(
                condition: current.sky,
                color: WeatherCareTheme.of(context).textPrimary,
                size: 25,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _TemperatureLine(
          lineKey: const ValueKey('main-current-forecast-row'),
          temperatureLabel: '현재 기온',
          temperature: current.temperature,
          apparentLabel: '현재 체감온도',
          apparentTemperature: current.displayedApparentTemperature,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(
              Icons.call_missed,
              size: 18,
              color: WeatherCareTheme.of(context).primaryDeep,
            ),
            const SizedBox(width: 9),
            const Expanded(
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
        const SizedBox(height: 4),
        _YesterdayComparisonSection(
          comparison: yesterday,
          loading: comparisonLoading,
          onRetry: onRetryComparison,
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
    final todayObservation = comparison?.current;
    final yesterdayObservation = comparison?.comparison;
    final metrics = todayObservation == null || yesterdayObservation == null
        ? const <_ComparisonMetricData>[]
        : [
            _ComparisonMetricData(
              subject: '기온은',
              current: todayObservation.temperature,
              previous: yesterdayObservation.temperature,
              unit: '℃',
            ),
            _ComparisonMetricData(
              subject: '체감온도는',
              current: todayObservation.apparentTemperature,
              previous: yesterdayObservation.apparentTemperature,
              unit: '℃',
            ),
            if (todayObservation.pm25 != null &&
                yesterdayObservation.pm25 != null)
              _ComparisonMetricData(
                subject: '초미세먼지는',
                current: todayObservation.pm25?.toDouble(),
                previous: yesterdayObservation.pm25?.toDouble(),
                unit: '㎍/㎥',
              )
            else if (todayObservation.pm10 != null &&
                yesterdayObservation.pm10 != null)
              _ComparisonMetricData(
                subject: '미세먼지는',
                current: todayObservation.pm10?.toDouble(),
                previous: yesterdayObservation.pm10?.toDouble(),
                unit: '㎍/㎥',
              ),
          ].where((metric) => metric.isComparable).toList(growable: false);
    final skyComparable = todayObservation?.skyCondition != null &&
        yesterdayObservation?.skyCondition != null;
    final available = _hasUsableComparison(comparison);
    final basis = comparison?.basis;
    final basisLabel = _comparisonBasisLabel(basis);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _singleLineComparisonText(
          _comparisonSubtitle(basis),
          style: TextStyle(
            color: WeatherCareTheme.of(context).textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        if (loading) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 10),
          const Text('어제 날씨를 확인하고 있어요.'),
        ] else if (!available) ...[
          Row(
            children: [
              Expanded(
                child: _singleLineComparisonText(
                  comparison?.requestFailed == true
                      ? '서버에서 어제 비교 자료를 불러오지 못했어요.'
                      : '받지 못한 자료: 어제와 같은 시각의 관측값',
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
                  color: WeatherCareTheme.of(context).primaryDeep,
                ),
            ],
          ),
        ] else ...[
          if (basisLabel != null) ...[
            _singleLineComparisonText(
              basisLabel,
              key: const ValueKey('yesterday-comparison-basis'),
              style: TextStyle(
                color: WeatherCareTheme.of(context).textSecondary,
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (skyComparable)
            _singleLineComparisonText(
              '하늘 상태는 오늘 ${todayObservation!.skyCondition}, '
              '어제 ${yesterdayObservation!.skyCondition}이었어요.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (skyComparable && metrics.isNotEmpty) const SizedBox(height: 10),
          for (var index = 0; index < metrics.length; index++) ...[
            _ComparisonMetric(metric: metrics[index]),
            if (index < metrics.length - 1) const SizedBox(height: 9),
          ],
        ],
      ],
    );
  }
}

class _ComparisonMetric extends StatelessWidget {
  final _ComparisonMetricData metric;

  const _ComparisonMetric({required this.metric});

  @override
  Widget build(BuildContext context) {
    final difference = metric.current! - metric.previous!;
    final same = formatWeatherNumber(metric.current!) ==
        formatWeatherNumber(metric.previous!);
    final change = same
        ? '어제와 같아요'
        : '어제보다 ${formatWeatherNumber(difference.abs(), keepDecimal: metric.unit == '℃')}${metric.unit} '
            '${difference > 0 ? '높아요' : '낮아요'}';
    String value(double value) =>
        '${formatWeatherNumber(value, keepDecimal: metric.unit == '℃')}${metric.unit}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: WeatherCareTheme.of(context).surfaceMuted,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        key: ValueKey('yesterday-comparison-row-${metric.subject}'),
        children: [
          Expanded(
            flex: 20,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${metric.subject} $change.',
                style: const TextStyle(fontWeight: FontWeight.w700),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '어제 ${value(metric.previous!)}',
            style: WeatherCareTheme.of(context).microTextStyle,
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}

Widget _singleLineComparisonText(String text, {TextStyle? style, Key? key}) {
  return SizedBox(
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        key: key,
        style: style,
        maxLines: 1,
        softWrap: false,
      ),
    ),
  );
}

class _ComparisonMetricData {
  final String subject;
  final double? current;
  final double? previous;
  final String unit;

  const _ComparisonMetricData({
    this.subject = '기온은',
    required this.current,
    required this.previous,
    required this.unit,
  });

  bool get isComparable => current != null && previous != null;
}

bool _hasUsableComparison(
  ComparisonResponse? response,
) {
  final todayObservation = response?.current;
  final yesterdayObservation = response?.comparison;
  if (response?.comparisonAvailable != true ||
      todayObservation == null ||
      yesterdayObservation == null) {
    return false;
  }
  return (todayObservation.temperature != null &&
          yesterdayObservation.temperature != null) ||
      (todayObservation.apparentTemperature != null &&
          yesterdayObservation.apparentTemperature != null) ||
      (todayObservation.pm10 != null && yesterdayObservation.pm10 != null) ||
      (todayObservation.pm25 != null && yesterdayObservation.pm25 != null) ||
      (todayObservation.skyCondition != null &&
          yesterdayObservation.skyCondition != null);
}

String? _comparisonBasisLabel(ComparisonBasis? basis) {
  if (basis == null) return null;
  final source = <String>[];
  if (basis.stationId case final station?) source.add('관측소 $station');
  if (basis.distanceKm case final distance?) {
    source.add('대표 위치에서 ${formatWeatherNumber(distance, keepDecimal: true)}km');
  }
  if (basis.provider == 'KMA_FORECAST_VS_ULTRA_SHORT_OBSERVATION') {
    return source.isEmpty ? null : source.join(' · ');
  }
  final current = basis.currentForecastAt == null
      ? _comparisonObservationClock('오늘', basis.currentObservedAt)
      : _comparisonObservationClock('오늘 예보', basis.currentForecastAt);
  final previous = _comparisonObservationClock(
    basis.currentForecastAt == null ? '어제' : '어제 실황',
    basis.comparisonObservedAt,
  );
  if (current != null) source.add(current);
  if (previous != null) source.add(previous);
  return source.isEmpty ? null : source.join(' · ');
}

String _comparisonSubtitle(ComparisonBasis? basis) {
  if (basis?.provider == 'KMA_FORECAST_VS_ULTRA_SHORT_OBSERVATION') {
    final time = _comparisonTimeLabel(basis?.currentForecastAt);
    return time == null
        ? '다음 시간 기온 예보를 어제 같은 시간 실황과 비교해요'
        : '$time 기준, 다음 시간 기온 예보를 어제 실황과 비교해요';
  }
  if (basis?.provider == 'KMA_ULTRA_SHORT_OBSERVATION') {
    return '선택지역 동네예보 격자의 오늘·어제 같은 시각을 비교해요';
  }
  if (basis?.provider == 'KMA_ASOS') {
    return '인근 ASOS 관측소의 오늘·어제 같은 시각을 비교해요';
  }
  return '같은 지역의 같은 기준시각 자료만 비교해요';
}

String? _comparisonTimeLabel(String? raw) {
  if (raw == null || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
    return null;
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final inKorea = parsed.toUtc().add(const Duration(hours: 9));
  final period = inKorea.hour < 12 ? '오전' : '오후';
  final hour = inKorea.hour % 12 == 0 ? 12 : inKorea.hour % 12;
  return '$period $hour시';
}

String? _comparisonObservationClock(String prefix, String? raw) {
  if (raw == null || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
    return null;
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final inKorea = parsed.toUtc().add(const Duration(hours: 9));
  final period = inKorea.hour < 12 ? '오전' : '오후';
  final hour = inKorea.hour % 12 == 0 ? 12 : inKorea.hour % 12;
  return '$prefix ${inKorea.month}월 ${inKorea.day}일 $period $hour시';
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
      decoration: WeatherCareTheme.of(context).surfaceDecoration(),
      child: Row(
        children: [
          Icon(icon, color: WeatherCareTheme.of(context).primaryDeep),
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
  final ComparisonResponse? yesterday;
  final String mood;
  final bool compact;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onRetryComparison;
  final bool retrying;
  final bool comparisonLoading;

  const _TopWeatherCard({
    required this.today,
    required this.yesterday,
    required this.mood,
    required this.compact,
    required this.comparisonLoading,
    this.onRetry,
    this.onRetryComparison,
    this.retrying = false,
  });
  @override
  Widget build(BuildContext context) {
    final phase = WeatherDataPhaseScope.of(context);
    final current = today.current;
    final missing = <String>[
      if (current.temperature == null) '현재 기온',
      if (current.displayedApparentTemperature == null) '현재 체감온도',
      if (current.sky == null) '하늘 상태',
    ];

    return AnimatedContainer(
      key: const ValueKey('main-top-weather-card'),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 13 : 16),
      decoration: WeatherCareTheme.of(context).surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WeatherBriefText(
            text: today.briefing?.copy.medium ?? today.brief,
            expiresAt:
                today.briefing?.nextBriefingBoundary ?? today.briefExpiresAt,
            timeline: today.briefingTimeline,
            generatedAt: today.generatedAt,
            receivedAt: today.receivedAt,
            style: TextStyle(
              fontFamily: WeatherCareTheme.fontNeoHyundai,
              color: WeatherCareTheme.of(context).textPrimary,
              fontSize: compact ? 21 : 23,
              height: 1.24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.45,
            ),
          ),
          SizedBox(height: compact ? 22 : 28),
          _TodaySection(
            yesterday: yesterday,
            current: current,
            onRetryComparison: onRetryComparison,
            comparisonLoading: comparisonLoading,
          ),
          if (missing.isNotEmpty &&
              phase != WeatherDataPhase.loading &&
              onRetry != null) ...[
            SizedBox(height: compact ? 8 : 10),
            MissingDataRetry(
              message: phase == WeatherDataPhase.failed
                  ? '서버에서 날씨 자료를 불러오지 못했어요: ${missing.join(' · ')}'
                  : '받지 못한 날씨 자료: ${missing.join(' · ')}',
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

  const _TemperatureLine({
    required this.lineKey,
    required this.temperatureLabel,
    required this.temperature,
    required this.apparentLabel,
    required this.apparentTemperature,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: WeatherCareTheme.of(context).primarySoft,
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
            _TemperatureValue(value: temperature),
            const SizedBox(width: 16),
            _TemperatureLabel(apparentLabel),
            const SizedBox(width: 8),
            _TemperatureValue(value: apparentTemperature),
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
      style: TextStyle(
        color: WeatherCareTheme.of(context).textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TemperatureValue extends StatelessWidget {
  final double? value;

  const _TemperatureValue({required this.value});

  @override
  Widget build(BuildContext context) {
    final phase = WeatherDataPhaseScope.of(context);
    return Text(
      value == null
          ? phase == WeatherDataPhase.loading
              ? '--°'
              : phase.missingText()
          : '${formatWeatherNumber(value!, keepDecimal: true)}℃',
      style: TextStyle(
        color: WeatherCareTheme.of(context).primaryDeep,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
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
}) {
  return _weatherExpression(sky);
}
