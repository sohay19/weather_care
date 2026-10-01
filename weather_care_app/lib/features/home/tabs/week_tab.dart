import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/briefing_time.dart';
import '../../../models/recommendation.dart';
import '../../../models/weather.dart';
import '../../../theme/recommendation_theme.dart';
import '../../../theme/weather_theme.dart';
import '../../../utils/korea_date.dart';
import '../weather_data_phase.dart';
import '../widgets/weather_data_notice.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/missing_data_retry.dart';
import '../widgets/preparation_icon.dart';
import '../widgets/weather_condition_icon.dart';
import '../widgets/week_presentation.dart';
import '../widgets/week_precipitation.dart';

class WeekTab extends StatefulWidget {
  final WeeklyWeatherResponse weekly;
  final WeatherDataPhase dataPhase;
  final bool serverFeaturesAvailable;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onRetryData;
  final bool retrying;
  final DateTime Function()? now;
  final String? fallbackGeneratedAt;
  final DateTime? fallbackReceivedAt;
  final Widget? advertisement;

  const WeekTab({
    super.key,
    required this.weekly,
    this.dataPhase = WeatherDataPhase.ready,
    required this.serverFeaturesAvailable,
    required this.onRefresh,
    this.onRetryData,
    this.retrying = false,
    this.now,
    this.fallbackGeneratedAt,
    this.fallbackReceivedAt,
    this.advertisement,
  });

  @override
  State<WeekTab> createState() => _WeekTabState();
}

class _WeekTabState extends State<WeekTab> with WidgetsBindingObserver {
  Timer? _midnightTimer;

  DateTime _now() => responseNow(
        (widget.now ?? DateTime.now)(),
        generatedAt: widget.weekly.generatedAt ?? widget.fallbackGeneratedAt,
        receivedAt: widget.weekly.receivedAt ?? widget.fallbackReceivedAt,
      );

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
    final now = _now();
    final today = dateInKorea(now);
    final calendarDays = currentCalendarWeek(weekly.days, now);
    final calendarForecasts = calendarDays
        .map((day) => day.forecast)
        .whereType<WeeklyForecastItem>()
        .toList(growable: false);
    return RefreshIndicator(
      color: WeatherCareTheme.primary,
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        key: const ValueKey('week-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabPageHeader(
              eyebrow: 'WEEK',
              title: '이번 주',
              subtitle: calendarWeekPeriodLabel(calendarDays),
              icon: Icons.calendar_month_outlined,
            ),
            const SizedBox(height: 18),
            if (widget.dataPhase != WeatherDataPhase.ready) ...[
              WeatherDataNotice(phase: widget.dataPhase, subject: '주간 날씨'),
              const SizedBox(height: 16),
            ],
            if (calendarForecasts.isNotEmpty)
              _WeekSummary(
                days: calendarForecasts,
                dataPhase: widget.dataPhase,
                serverFeaturesAvailable: widget.serverFeaturesAvailable,
              )
            else
              Text(widget.dataPhase == WeatherDataPhase.ready
                  ? '자료를 받아오면 해당 날짜의 날씨와 준비물을 표시해요.'
                  : widget.dataPhase.explanation),
            if (widget.advertisement != null) ...[
              const SizedBox(height: 18),
              widget.advertisement!,
            ],
            const SizedBox(height: 16),
            for (var index = 0; index < calendarDays.length; index++) ...[
              _WeekDayCard(
                calendarDay: calendarDays[index],
                dataPhase: widget.dataPhase,
                isToday: dateInKorea(calendarDays[index].date) == today,
                isPast: calendarDays[index].date.isBefore(
                      parseForecastDate(today)!,
                    ),
                today: parseForecastDate(today)!,
                serverFeaturesAvailable: widget.serverFeaturesAvailable,
                onRetry: widget.onRetryData,
                retrying: widget.retrying,
              ),
              if (index < calendarDays.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekSummary extends StatelessWidget {
  final List<WeeklyForecastItem> days;
  final WeatherDataPhase dataPhase;
  final bool serverFeaturesAvailable;

  const _WeekSummary({
    required this.days,
    required this.dataPhase,
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
            '주간 날씨 요약',
            style: TextStyle(
              fontFamily: WeatherCareTheme.fontNeoHyundai,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '한 주의 날씨를 요약해서 보여드려요',
            style: WeatherCareTheme.microTextStyle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryMetric(
                  key: const ValueKey('week-summary-precipitation'),
                  icon: const WeatherConditionIcon(
                    condition: '비/눈',
                    size: 21,
                    color: WeatherCareTheme.primaryDeep,
                  ),
                  label: '예상 강수일',
                  metric: summary.precipitation,
                  dataPhase: dataPhase,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  key: const ValueKey('week-summary-temperature'),
                  icon: const Icon(
                    Icons.device_thermostat_rounded,
                    color: WeatherCareTheme.primaryDeep,
                    size: 19,
                  ),
                  label: '예상 주중 최고기온',
                  metric: summary.maximum,
                  dataPhase: dataPhase,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  key: const ValueKey('week-summary-preparations'),
                  icon: const Icon(
                    Icons.work_outline_rounded,
                    color: WeatherCareTheme.primaryDeep,
                    size: 19,
                  ),
                  label: '예상 준비물',
                  metric: summary.preparations,
                  dataPhase: dataPhase,
                ),
              ),
            ],
          ),
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
  final WeatherDataPhase dataPhase;

  const _SummaryMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.metric,
    required this.dataPhase,
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
          Text(
            label,
            textAlign: TextAlign.center,
            style: WeatherCareTheme.microTextStyle.copyWith(
              color: WeatherCareTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          icon,
          const SizedBox(height: 5),
          Text(metric.value.replaceAll('자료 없음', dataPhase.missingText()),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _WeekDayCard extends StatelessWidget {
  final WeekCalendarDay calendarDay;
  final WeatherDataPhase dataPhase;
  final bool isToday;
  final bool isPast;
  final DateTime today;
  final bool serverFeaturesAvailable;
  final Future<void> Function()? onRetry;
  final bool retrying;

  const _WeekDayCard({
    required this.calendarDay,
    required this.dataPhase,
    required this.isToday,
    required this.isPast,
    required this.today,
    required this.serverFeaturesAvailable,
    this.onRetry,
    this.retrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final day = calendarDay.forecast;
    if (day == null) {
      return _UnavailableWeekDayCard(
        date: calendarDay.date,
        dataPhase: dataPhase,
        isToday: isToday,
        today: today,
        onRetry: onRetry,
        retrying: retrying,
      );
    }
    final weatherLabel = weekWeatherLabel(day);
    final precipitationLines = weekPrecipitationLines(day);
    final recommendations = serverFeaturesAvailable
        ? weekRecommendations(day)
        : <WeatherRecommendation>[];
    final minimumTemperature = weekTemperature(day, maximum: false);
    final maximumTemperature = weekTemperature(day, maximum: true);
    final additionalData = _additionalWeekData(day);
    final airQualityLines = _airQualityLines(day.airQualityForecast);
    final sourceLabel = day.forecastSource == 'KMA_OBSERVATION'
        ? '실제 관측'
        : day.historical
            ? '저장된 예보'
            : day.forecastSource == 'KMA_MID_TERM'
                ? '중기예보'
                : '단기예보';
    final missing = <String>[
      if (weatherLabel == null || day.weatherDataComplete != true) '날씨',
      if (minimumTemperature == null) '최저기온',
      if (maximumTemperature == null) '최고기온',
      if (serverFeaturesAvailable && !day.recommendationsAvailable) '준비물 추천',
    ];
    final card = Container(
      key: ValueKey('week-day-${day.forecastDate}'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isPast
            ? WeatherCareTheme.surfaceMuted
            : isToday
                ? WeatherCareTheme.primarySoft
                : Colors.white,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      calendarDayLabel(calendarDay.date),
                      style: TextStyle(
                        color: isPast
                            ? WeatherCareTheme.textSecondary
                            : isToday
                                ? WeatherCareTheme.primaryDeep
                                : WeatherCareTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      sourceLabel,
                      style: WeatherCareTheme.specialLabelStyle.copyWith(
                        color: isPast && sourceLabel == '실제 관측'
                            ? WeatherCareTheme.textPrimary
                            : WeatherCareTheme.primaryDeep,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (isToday || isPast) const SizedBox(width: 8),
              if (isToday)
                Text(
                  '오늘',
                  key: ValueKey('week-today-${day.forecastDate}'),
                  style: WeatherCareTheme.specialLabelStyle.copyWith(
                    fontSize: 11,
                  ),
                )
              else if (isPast)
                Text(
                  '지난 날짜',
                  key: ValueKey('week-past-${day.forecastDate}'),
                  style: WeatherCareTheme.specialLabelStyle.copyWith(
                    color: WeatherCareTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (day.forecastSource == 'KMA_OBSERVATION') ...[
            const SizedBox(height: 5),
            Text(
              '인근 기상청 지상·AWS 관측소의 일자료'
              '${day.observationDistanceKm == null ? '' : ' · 예보격자 대표점에서 ${day.observationDistanceKm!.toStringAsFixed(1)}km'}',
              style: WeatherCareTheme.microTextStyle,
            ),
          ],
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
                color: isPast
                    ? WeatherCareTheme.textSecondary
                    : WeatherCareTheme.primaryDeep,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                weatherLabel ?? dataPhase.missingText('날씨 자료 없음'),
                style: TextStyle(
                  color: isPast ? WeatherCareTheme.textSecondary : null,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ]),
          if (weatherLabel != null && day.weatherDataComplete == false)
            Text('일부 시간대 날씨 ${dataPhase.missingText()}',
                style: WeatherCareTheme.microTextStyle),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _WeekTemperaturePeriod(
                  label: '최저',
                  value: minimumTemperature == null
                      ? dataPhase.missingText()
                      : weekDegrees(minimumTemperature),
                  isPast: isPast,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WeekTemperaturePeriod(
                  label: '최고',
                  value: maximumTemperature == null
                      ? dataPhase.missingText()
                      : weekDegrees(maximumTemperature),
                  isPast: isPast,
                ),
              ),
            ],
          ),
          if (day.minTemperatureSource == 'HOURLY' ||
              day.maxTemperatureSource == 'HOURLY')
            Text('시간별 최저·최고는 받은 시간대만 비교한 값이에요.',
                style: WeatherCareTheme.microTextStyle),
          if (additionalData.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final data in additionalData)
                  _WeekDataChip(data: data, isPast: isPast),
              ],
            ),
          ],
          if (airQualityLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              key: ValueKey('week-air-quality-${day.forecastDate}'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '대기 상태',
                    style: TextStyle(
                      color: isPast ? WeatherCareTheme.textSecondary : null,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    airQualityLines.join(' · '),
                    style: WeatherCareTheme.microTextStyle.copyWith(
                      color: isPast ? WeatherCareTheme.textSecondary : null,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (precipitationLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              key: ValueKey('week-precipitation-${day.forecastDate}'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      day.forecastSource == 'KMA_OBSERVATION'
                          ? '강수 관측'
                          : '강수 예보',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  for (final line in precipitationLines)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(line,
                          style: WeatherCareTheme.microTextStyle
                              .copyWith(fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recommendations.isEmpty)
                Text(
                  !serverFeaturesAvailable
                      ? '운영 서버 미연결로 준비물 미지원'
                      : day.forecastSource == 'KMA_OBSERVATION'
                          ? '지난 날은 준비물 추천 대상이 아니에요'
                          : day.recommendationsAvailable
                              ? '표시할 준비물 추천 없음'
                              : '준비물 추천 ${dataPhase.missingText()}',
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
                            PreparationIcon(
                              type: recommendation.type,
                              size: 10,
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
          if (missing.isNotEmpty &&
              dataPhase != WeatherDataPhase.loading &&
              onRetry != null) ...[
            const SizedBox(height: 10),
            MissingDataRetry(
              message: dataPhase == WeatherDataPhase.failed
                  ? '서버에서 불러오지 못한 항목: ${missing.join(' · ')}'
                  : '받지 못한 항목: ${missing.join(' · ')}',
              retryKey: 'week-day-retry-${day.forecastDate}',
              onRetry: onRetry!,
              retrying: retrying,
            ),
          ],
        ],
      ),
    );
    return card;
  }
}

class _WeekTemperaturePeriod extends StatelessWidget {
  final String label;
  final String value;
  final bool isPast;

  const _WeekTemperaturePeriod({
    required this.label,
    required this.value,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: WeatherCareTheme.microTextStyle.copyWith(
                color: isPast ? WeatherCareTheme.textSecondary : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(
                  color: isPast ? WeatherCareTheme.textSecondary : null,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekData {
  final IconData icon;
  final String label;

  const _WeekData(this.icon, this.label);
}

class _WeekDataChip extends StatelessWidget {
  final _WeekData data;
  final bool isPast;

  const _WeekDataChip({required this.data, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final color =
        isPast ? WeatherCareTheme.textSecondary : WeatherCareTheme.primaryDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            data.label,
            style: WeatherCareTheme.microTextStyle.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

List<_WeekData> _additionalWeekData(WeeklyForecastItem day) => [
      if (day.averageHumidity case final value?)
        _WeekData(Icons.water_drop_outlined, '평균 습도 ${value.round()}%'),
      if (day.maximumWindSpeed case final value?)
        _WeekData(Icons.air_rounded, '최대 풍속 ${_decimal(value)}m/s'),
      if (day.snowfallAmount case final value?)
        _WeekData(Icons.ac_unit_rounded, '예상 강설 ${_decimal(value)}cm'),
      if (day.maximumUvIndex case final value?)
        _WeekData(Icons.wb_sunny_outlined, '자외선 최고 ${_decimal(value)}'),
    ];

List<String> _airQualityLines(WeeklyAirQualityForecast? air) {
  if (air == null) return const [];
  return [
    if (air.pm10Grade != null) '미세먼지 ${air.pm10Grade}',
    if (air.pm25Grade != null) '초미세먼지 ${air.pm25Grade}',
    if (air.ozoneGrade != null) '오존 ${air.ozoneGrade}',
    if (air.yellowDustMentioned) '황사 영향 언급',
    if (air.confidence != null) '신뢰도 ${air.confidence}',
  ];
}

String _decimal(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

class _UnavailableWeekDayCard extends StatelessWidget {
  final DateTime date;
  final WeatherDataPhase dataPhase;
  final bool isToday;
  final DateTime today;
  final Future<void> Function()? onRetry;
  final bool retrying;

  const _UnavailableWeekDayCard({
    required this.date,
    required this.dataPhase,
    required this.isToday,
    required this.today,
    this.onRetry,
    this.retrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final daysAhead = date.difference(today).inDays;
    final isPast = date.isBefore(today);
    final message = dataPhase != WeatherDataPhase.ready
        ? dataPhase.explanation
        : isToday
            ? '지금 날씨 자료를 받지 못했어요.'
            : date.isBefore(today)
                ? '인근 관측소의 실제 일관측과 저장된 예보가 모두 없어요.'
                : daysAhead >= 4
                    ? '단기·중기예보를 모두 받지 못해 표시할 자료가 없어요.'
                    : '예보 범위 안이지만 아직 날씨 자료를 받지 못했어요.';
    final card = Container(
      key: ValueKey('week-unavailable-${dateInKorea(date)}'),
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isPast
            ? WeatherCareTheme.surfaceMuted
            : isToday
                ? WeatherCareTheme.primarySoft
                : Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: WeatherCareTheme.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.question_mark_rounded,
              color: WeatherCareTheme.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        calendarDayLabel(date),
                        style: TextStyle(
                          color: isToday
                              ? WeatherCareTheme.primaryDeep
                              : WeatherCareTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isToday)
                      Text(
                        '오늘',
                        key: ValueKey('week-today-${dateInKorea(date)}'),
                        style: WeatherCareTheme.specialLabelStyle.copyWith(
                          fontSize: 11,
                        ),
                      )
                    else if (isPast)
                      Text(
                        '지난 날짜',
                        key: ValueKey('week-past-${dateInKorea(date)}'),
                        style: WeatherCareTheme.specialLabelStyle.copyWith(
                          color: WeatherCareTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
                if (dataPhase != WeatherDataPhase.loading &&
                    onRetry != null) ...[
                  const SizedBox(height: 10),
                  MissingDataRetry(
                    message: dataPhase == WeatherDataPhase.failed
                        ? '서버에서 이 날짜의 날씨를 불러오지 못했어요.'
                        : '받지 못한 항목: 이 날짜의 날씨',
                    retryKey: 'week-unavailable-retry-${dateInKorea(date)}',
                    onRetry: onRetry!,
                    retrying: retrying,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return card;
  }
}
