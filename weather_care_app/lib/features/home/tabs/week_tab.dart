import '../../../utils/weather_number.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/briefing_time.dart';
import '../../../models/precipitation.dart';
import '../../../models/recommendation.dart';
import '../../../models/weather.dart';
import '../../../theme/recommendation_theme.dart';
import '../../../theme/weather_theme.dart';
import '../../../utils/korea_date.dart';
import '../weather_labels.dart';
import '../weather_data_phase.dart';
import '../widgets/weather_data_notice.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/missing_data_retry.dart';
import '../widgets/preparation_icon.dart';
import '../widgets/weather_condition_icon.dart';
import '../widgets/hourly_forecast_section.dart';
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
  final List<HourlyWeatherItem> hourly;
  final List<HourlyWeatherItem> timelineHourly;

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
    this.hourly = const [],
    this.timelineHourly = const [],
  });

  @override
  State<WeekTab> createState() => _WeekTabState();
}

class _WeekTabState extends State<WeekTab> with WidgetsBindingObserver {
  Timer? _midnightTimer;
  DateTime? _selectedWeekStart;
  DateTime? _lastToday;
  int _selectedDayIndex = 0;
  double _horizontalDragDistance = 0;

  void _showDay(int index) {
    if (index < 0 || index > 6 || index == _selectedDayIndex) return;
    setState(() => _selectedDayIndex = index);
  }

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
    if (_selectedWeekStart != calendarDays.first.date) {
      _selectedWeekStart = calendarDays.first.date;
      _selectedDayIndex = parseForecastDate(today)!.weekday % 7;
    } else if (_lastToday != null && _lastToday != parseForecastDate(today)) {
      if (calendarDays[_selectedDayIndex].date == _lastToday) {
        _selectedDayIndex = parseForecastDate(today)!.weekday % 7;
      }
    }
    _lastToday = parseForecastDate(today);
    final selectedDay = calendarDays[_selectedDayIndex];
    final selectedHourly = _weekTimelineItems(
      selectedDay,
      today,
      widget.hourly,
      widget.timelineHourly,
    );
    final calendarForecasts = calendarDays
        .map((day) => day.forecast)
        .whereType<WeeklyForecastItem>()
        .toList(growable: false);
    return RefreshIndicator(
      color: WeatherCareTheme.of(context).primary,
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
                today: parseForecastDate(today)!,
                dataPhase: widget.dataPhase,
                serverFeaturesAvailable: widget.serverFeaturesAvailable,
              )
            else
              Text(widget.dataPhase == WeatherDataPhase.ready
                  ? '자료를 받아오면 해당 날짜의 날씨와 준비물을 표시해요.'
                  : widget.dataPhase.explanation),
            const SizedBox(height: 16),
            if (widget.advertisement != null) ...[
              widget.advertisement!,
              const SizedBox(height: 24),
            ],
            Center(
              child: Text(
                calendarDayLabel(selectedDay.date),
                key: const ValueKey('week-selected-date'),
                style: TextStyle(
                  color: WeatherCareTheme.of(context).primaryDeep,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  key: const ValueKey('week-previous-day'),
                  tooltip: '이전 날짜',
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 40),
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _selectedDayIndex == 0
                      ? null
                      : () => _showDay(_selectedDayIndex - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('week-day-swipe-area'),
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (_) => _horizontalDragDistance = 0,
                    onHorizontalDragUpdate: (details) =>
                        _horizontalDragDistance += details.delta.dx,
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (_horizontalDragDistance < -50 || velocity < -300) {
                        _showDay(_selectedDayIndex + 1);
                      } else if (_horizontalDragDistance > 50 ||
                          velocity > 300) {
                        _showDay(_selectedDayIndex - 1);
                      }
                    },
                    child: _WeekDayCard(
                      calendarDay: selectedDay,
                      dataPhase: widget.dataPhase,
                      isToday: dateInKorea(selectedDay.date) == today,
                      isPast: selectedDay.date.isBefore(
                        parseForecastDate(today)!,
                      ),
                      today: parseForecastDate(today)!,
                      hourly: selectedHourly,
                      serverFeaturesAvailable: widget.serverFeaturesAvailable,
                      onRetry: widget.onRetryData,
                      retrying: widget.retrying,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: const ValueKey('week-next-day'),
                  tooltip: '다음 날짜',
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 40),
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _selectedDayIndex == calendarDays.length - 1
                      ? null
                      : () => _showDay(_selectedDayIndex + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

List<HourlyWeatherItem> _weekTimelineItems(
  WeekCalendarDay day,
  String today,
  List<HourlyWeatherItem> hourly,
  List<HourlyWeatherItem> timelineHourly,
) {
  if (day.date.isBefore(parseForecastDate(today)!)) return const [];
  final date = dateInKorea(day.date);
  final source = date == today ? [...timelineHourly, ...hourly] : hourly;
  final items = <HourlyWeatherItem>[
    for (final item in source)
      if (item.forecastDate == date || item.precipitationPeriod?.date == date)
        item,
  ];
  final detail = day.forecast?.precipitationDetail;
  if (detail?.kind == 'HOURLY') {
    for (final hour in detail!.hours) {
      final end = hour.forecastAt;
      if (end == null) continue;
      final start = end.subtract(const Duration(hours: 1));
      if (dateInKorea(start) != date ||
          (hour.probability == null && hour.amount == null)) {
        continue;
      }
      items.add(HourlyWeatherItem(
        time: start
            .toUtc()
            .add(const Duration(hours: 9))
            .hour
            .toString()
            .padLeft(2, '0'),
        forecastDate: date,
        precipitationPeriod: PrecipitationPeriod(start: start, end: end),
        precipitationPeriodProvided: true,
        temperature: null,
        precipitationProbability: hour.probability,
        precipitationAmount: null,
        precipitationAmountLabel: hour.amount?.label,
        snowExpected: null,
        snowfallAmount: null,
        windSpeed: null,
        skyCondition: null,
      ));
    }
  }
  return items;
}

class _WeekSummary extends StatelessWidget {
  final List<WeeklyForecastItem> days;
  final DateTime today;
  final WeatherDataPhase dataPhase;
  final bool serverFeaturesAvailable;

  const _WeekSummary({
    required this.days,
    required this.today,
    required this.dataPhase,
    required this.serverFeaturesAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final summary = buildWeekSummary(days,
        serverFeaturesAvailable: serverFeaturesAvailable, today: today);

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: WeatherCareTheme.of(context).mood('clear'),
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
            style: WeatherCareTheme.of(context)
                .microTextStyle
                .copyWith(fontSize: 12),
          ),
          const SizedBox(height: 15),
          _SummaryMetric(
            key: const ValueKey('week-summary-precipitation'),
            icon: WeatherConditionIcon(
              condition: '비/눈',
              size: 21,
              color: WeatherCareTheme.of(context).primaryDeep,
            ),
            label: '강수',
            details: [
              ('강수일', summary.precipitation),
              ('최고 강수량', summary.precipitationAmount),
            ],
            dataPhase: dataPhase,
          ),
          const SizedBox(height: 8),
          _SummaryMetric(
            key: const ValueKey('week-summary-temperature'),
            icon: Icon(
              Icons.device_thermostat_rounded,
              color: WeatherCareTheme.of(context).primaryDeep,
              size: 19,
            ),
            label: '기온',
            details: [
              ('최저', summary.minimum),
              ('최고', summary.maximum),
            ],
            dataPhase: dataPhase,
          ),
          const SizedBox(height: 8),
          _SummaryMetric(
            key: const ValueKey('week-summary-preparations'),
            icon: Icon(
              Icons.work_outline_rounded,
              color: WeatherCareTheme.of(context).primaryDeep,
              size: 19,
            ),
            label: '준비물',
            details: [
              ('', summary.preparations),
              ('', summary.preparationItems),
            ],
            dataPhase: dataPhase,
          ),
          if (summary.excludedNotice != null) ...[
            const SizedBox(height: 8),
            Text(summary.excludedNotice!,
                style: WeatherCareTheme.of(context).microTextStyle),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final Widget icon;
  final String label;
  final List<(String, WeekSummaryMetric)> details;
  final WeatherDataPhase dataPhase;

  const _SummaryMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.details,
    required this.dataPhase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: WeatherCareTheme.of(context).surface.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            label,
            style: WeatherCareTheme.of(context).microTextStyle.copyWith(
                  color: WeatherCareTheme.of(context).textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                for (var index = 0; index < details.length; index++) ...[
                  if (index > 0) const TextSpan(text: '  ·  '),
                  if (details[index].$1.isNotEmpty)
                    TextSpan(text: '${details[index].$1} '),
                  TextSpan(
                    text: details[index]
                        .$2
                        .value
                        .replaceAll('자료 없음', dataPhase.missingText()),
                    style: TextStyle(
                      color: WeatherCareTheme.of(context).primaryDeep,
                      fontFamily: WeatherCareTheme.fontSuite,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ]),
              textAlign: TextAlign.right,
              style: WeatherCareTheme.of(context).microTextStyle,
            ),
          ),
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
  final List<HourlyWeatherItem> hourly;
  final bool serverFeaturesAvailable;
  final Future<void> Function()? onRetry;
  final bool retrying;

  const _WeekDayCard({
    required this.calendarDay,
    required this.dataPhase,
    required this.isToday,
    required this.isPast,
    required this.today,
    required this.hourly,
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
        hourly: hourly,
        onRetry: onRetry,
        retrying: retrying,
      );
    }
    final weatherLabel = weekWeatherLabel(day);
    final precipitation = weekPrecipitationCompact(day, isPast: isPast);
    final snowfall = _weekSnowfallText(day, isPast: isPast);
    final recommendations = !isPast && serverFeaturesAvailable
        ? weekRecommendations(day)
        : <WeatherRecommendation>[];
    final minimumTemperature = weekTemperature(day, maximum: false);
    final maximumTemperature = weekTemperature(day, maximum: true);
    final additionalData = _additionalWeekData(day, isPast: isPast);
    final sourceLabel = day.forecastSource == 'KMA_OBSERVATION'
        ? '실제 관측'
        : day.forecastSource == 'KMA_MID_TERM'
            ? '중기예보'
            : '단기예보';
    final missing = <String>[
      if (weatherLabel == null || day.weatherDataComplete != true) '날씨',
      if (minimumTemperature == null) '최저기온',
      if (maximumTemperature == null) '최고기온',
      if (!isPast && serverFeaturesAvailable && !day.recommendationsAvailable)
        '준비물 추천',
    ];
    final card = Container(
      key: ValueKey('week-day-${day.forecastDate}'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isPast
            ? WeatherCareTheme.of(context).surfaceMuted
            : isToday
                ? WeatherCareTheme.of(context).primarySoft
                : WeatherCareTheme.of(context).surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isToday
              ? WeatherCareTheme.of(context).primaryBorder
              : WeatherCareTheme.of(context).outline,
        ),
        boxShadow: [
          BoxShadow(
            color: WeatherCareTheme.of(context).shadow,
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isPast)
                Expanded(
                  child: Text(
                    sourceLabel,
                    style: WeatherCareTheme.of(context)
                        .specialLabelStyle
                        .copyWith(fontSize: 10),
                  ),
                )
              else
                const Spacer(),
              if (isToday || isPast) const SizedBox(width: 8),
              if (isToday)
                Text(
                  '오늘',
                  key: ValueKey('week-today-${day.forecastDate}'),
                  style:
                      WeatherCareTheme.of(context).specialLabelStyle.copyWith(
                            fontSize: 11,
                          ),
                )
              else if (isPast)
                Text(
                  '지난 날짜',
                  key: ValueKey('week-past-${day.forecastDate}'),
                  style:
                      WeatherCareTheme.of(context).specialLabelStyle.copyWith(
                            color: WeatherCareTheme.of(context).textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
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
                color: WeatherCareTheme.of(context)
                    .surface
                    .withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
              child: WeatherConditionIcon(
                condition: weatherLabel,
                color: isPast
                    ? WeatherCareTheme.of(context).textSecondary
                    : WeatherCareTheme.of(context).primaryDeep,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                weatherLabel ?? dataPhase.missingText('날씨 자료 없음'),
                style: TextStyle(
                  color: isPast
                      ? WeatherCareTheme.of(context).textSecondary
                      : null,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ]),
          if (weatherLabel != null && day.weatherDataComplete == false)
            Text('일부 시간대 날씨 ${dataPhase.missingText()}',
                style: WeatherCareTheme.of(context).microTextStyle),
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
                  isFuture: !isToday && !isPast,
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
                  isFuture: !isToday && !isPast,
                ),
              ),
            ],
          ),
          if (day.minTemperatureSource == 'HOURLY' ||
              day.maxTemperatureSource == 'HOURLY')
            Text('받은 시간대 기준 최저·최고',
                style: WeatherCareTheme.of(context).microTextStyle),
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
          for (final (kind, icon, text) in [
            ('precipitation', Icons.water_drop_outlined, precipitation),
            ('snowfall', Icons.ac_unit_rounded, snowfall),
          ]) ...[
            const SizedBox(height: 10),
            _WeekAmountRow(
              key: ValueKey('week-$kind-${day.forecastDate}'),
              icon: icon,
              text: text,
              detail:
                  !isPast && kind == 'snowfall' && day.snowProbability != null
                      ? '눈 또는 비/눈으로 예보된 시간대의 기상청 강수확률을 표시해요. '
                          '기상청이 별도로 산출한 강설확률은 아니에요. '
                          '비/눈은 비가 내릴 가능성도 포함해요. '
                          '일별 수치는 해당 예보 시간대 중 가장 높은 값이에요.'
                      : null,
              isToday: isToday,
              isPast: isPast,
            ),
          ],
          if (!isPast &&
              (recommendations.isNotEmpty ||
                  !serverFeaturesAvailable ||
                  !day.recommendationsAvailable)) ...[
            const SizedBox(height: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recommendations.isEmpty)
                  Text(
                    !serverFeaturesAvailable
                        ? '운영 서버 미연결로 준비물 미지원'
                        : '준비물 추천 ${dataPhase.missingText()}',
                    style: WeatherCareTheme.of(context)
                        .microTextStyle
                        .copyWith(fontSize: 11),
                  )
                else
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final recommendation in recommendations)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isToday
                                ? WeatherCareTheme.of(context).surface
                                : recommendation.type.softColor(context),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PreparationIcon(
                                type: recommendation.type,
                                size: 16,
                                color: recommendation.type.accentColor(context),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                  child: Text(
                                recommendation.type.label,
                                style: const TextStyle(
                                  fontFamily: WeatherCareTheme.fontMona,
                                  fontSize: 10,
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
                      style: WeatherCareTheme.of(context).microTextStyle),
              ],
            ),
          ],
          if (hourly.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(
              key: ValueKey('week-hourly-divider-${day.forecastDate}'),
              height: 1,
              color: WeatherCareTheme.of(context).outline,
            ),
            HourlyForecastSection(
              key: ValueKey('week-hourly-${day.forecastDate}'),
              keyPrefix: 'week-${day.forecastDate}',
              items: hourly,
              targetDate: day.forecastDate,
              availableOnly: true,
              inline: true,
              contrastFilters: isToday,
              uvCenterColor:
                  isToday ? WeatherCareTheme.of(context).primarySoft : null,
            ),
          ],
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
  final bool isFuture;

  const _WeekTemperaturePeriod({
    required this.label,
    required this.value,
    required this.isPast,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: isFuture
            ? WeatherCareTheme.of(context).primarySoft.withValues(alpha: 0.35)
            : WeatherCareTheme.of(context).surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: WeatherCareTheme.of(context).microTextStyle.copyWith(
                    color: isPast
                        ? WeatherCareTheme.of(context).textSecondary
                        : null,
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
                  color: isPast
                      ? WeatherCareTheme.of(context).textSecondary
                      : null,
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

class _WeekAmountRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isToday;
  final bool isPast;
  final String? detail;

  const _WeekAmountRow({
    super.key,
    this.detail,
    required this.icon,
    required this.text,
    required this.isToday,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text.rich(
      TextSpan(children: _weekPrecipitationSpans(text)),
      style: WeatherCareTheme.of(context)
          .microTextStyle
          .copyWith(fontSize: 12, fontWeight: FontWeight.w400),
    );
    final singleLine = text.startsWith('강설확률 ') && !text.contains('예보 이력 없음');
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(10, 10, detail == null ? 10 : 2, 10),
      decoration: BoxDecoration(
        color: isToday || isPast
            ? WeatherCareTheme.of(context).surface.withValues(alpha: 0.65)
            : WeatherCareTheme.of(context).surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: WeatherCareTheme.of(context).primaryDeep),
          const SizedBox(width: 7),
          Expanded(
            child: singleLine
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: label)
                : label,
          ),
          if (detail != null)
            IconButton(
              tooltip: '강설확률 설명',
              padding: EdgeInsets.zero,
              alignment: Alignment.centerRight,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 40),
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.info_outline_rounded, size: 17),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('강설확률'),
                  content: Text(detail!),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('확인'),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<InlineSpan> _weekPrecipitationSpans(String text) {
  text = text.replaceAll('예보 이력 없음 · ', '예보 이력 없음\n');
  final pattern =
      RegExp(r'(강수확률 |강수량 |강수 관측 |강설확률 |최심신적설 |예상 신적설 )(.*?)(?= · |\n|$)');
  final spans = <InlineSpan>[];
  var end = 0;
  for (final match in pattern.allMatches(text)) {
    spans.add(TextSpan(text: '${text.substring(end, match.start)}${match[1]}'));
    spans.add(TextSpan(
      text: match[2],
      style: const TextStyle(
          fontFamily: WeatherCareTheme.fontSuite, fontWeight: FontWeight.w700),
    ));
    end = match.end;
  }
  if (end < text.length) spans.add(TextSpan(text: text.substring(end)));
  return spans;
}

class _WeekData {
  final IconData icon;
  final String title;
  final String label;
  final String value;
  final String detail;

  const _WeekData(this.icon, this.title, this.label, this.value, this.detail);
}

class _WeekDataChip extends StatelessWidget {
  final _WeekData data;
  final bool isPast;

  const _WeekDataChip({required this.data, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final color = isPast
        ? WeatherCareTheme.of(context).textSecondary
        : WeatherCareTheme.of(context).primaryDeep;
    return Tooltip(
      message: '눌러서 수치 보기',
      child: ChoiceChip(
        label: Text.rich(TextSpan(children: [
          TextSpan(text: '${data.label} '),
          TextSpan(
            text: data.value,
            style: const TextStyle(
                fontFamily: WeatherCareTheme.fontSuite,
                fontWeight: FontWeight.w700),
          ),
        ])),
        avatar: Icon(data.icon, size: 17, color: color),
        selected: false,
        onSelected: (_) => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(data.title),
            content: Text(data.detail),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              )
            ],
          ),
        ),
        labelStyle: WeatherCareTheme.of(context).microTextStyle.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
        backgroundColor:
            WeatherCareTheme.of(context).surface.withValues(alpha: 0.35),
        side: BorderSide(
          color: isPast ? Colors.transparent : color.withValues(alpha: 0.65),
          width: 1.2,
        ),
        elevation: isPast ? 0 : 2,
        shadowColor: color.withValues(alpha: 0.32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        visualDensity: VisualDensity.standard,
      ),
    );
  }
}

String _weekSnowfallText(WeeklyForecastItem day, {required bool isPast}) {
  final amount = day.snowfallAmount;
  if (isPast) {
    return '강설 관측 · 최심신적설 '
        '${amount == null ? '자료 없음' : '${_decimal(amount)}cm'}';
  }
  final probability = day.snowProbability;
  final probabilityText = probability == null
      ? '강설확률 자료 없음'
      : '강설확률 최고 ${formatWeatherNumber(probability)}%';
  if (day.forecastSource == 'KMA_MID_TERM') return probabilityText;
  return '$probabilityText · 예상 신적설 '
      '${amount == null ? '자료 없음' : '${_decimal(amount)}cm'}';
}

List<_WeekData> _additionalWeekData(WeeklyForecastItem day,
    {required bool isPast}) {
  return [
    if (day.averageHumidity case final value?)
      _WeekData(
        Icons.water_drop_outlined,
        '습도',
        isPast ? '평균 습도' : '습도',
        isPast ? '${formatWeatherNumber(value)}%' : humidityDescription(value)!,
        '평균 습도 ${formatWeatherNumber(value)}%',
      ),
    if (day.maximumWindSpeed case final value?)
      _WeekData(
        Icons.air_rounded,
        '바람',
        isPast ? '최대 풍속' : '바람',
        isPast ? '${_decimal(value)}m/s' : windDescription(value)!,
        '최대 풍속 ${_decimal(value)}m/s',
      ),
    if (day.maximumUvIndex case final value?)
      _WeekData(
        Icons.wb_sunny_outlined,
        '자외선',
        isPast ? '자외선 최고' : '자외선',
        isPast ? _decimal(value) : uvDescription(value)!,
        '자외선지수 최고 ${_decimal(value)}',
      ),
    if (day.airQualityObservation case final observed?
        when observed.pm10 != null ||
            observed.pm25 != null ||
            observed.ozone != null)
      _WeekData(
        Icons.cloud_outlined,
        '대기질 관측',
        '대기질',
        observed.pm25 != null
            ? '초미세먼지 ${formatWeatherNumber(observed.pm25!)}㎍/㎥'
            : observed.pm10 != null
                ? '미세먼지 ${formatWeatherNumber(observed.pm10!)}㎍/㎥'
                : '오존 ${formatWeatherNumber(observed.ozone!)}ppm',
        '${observed.stationName} 측정소 · ${observed.observedHours}개 시간대 관측 평균'
            '${observed.pm25 == null ? '' : '\n초미세먼지 ${formatWeatherNumber(observed.pm25!)}㎍/㎥'}'
            '${observed.pm10 == null ? '' : '\n미세먼지 ${formatWeatherNumber(observed.pm10!)}㎍/㎥'}'
            '${observed.ozone == null ? '' : '\n오존 ${formatWeatherNumber(observed.ozone!)}ppm'}',
      ),
    if (day.airQualityForecast case final air?
        when air.pm10Grade != null ||
            air.pm25Grade != null ||
            air.ozoneGrade != null ||
            air.yellowDustMentioned)
      _WeekData(
        Icons.cloud_outlined,
        '대기 상태',
        _airQualityLabel(air).$1,
        _airQualityLabel(air).$2,
        '${_airQualityLines(air).join(' · ')}\n농도 수치는 주간 예보에서 제공되지 않아요.',
      ),
  ];
}

(String, String) _airQualityLabel(WeeklyAirQualityForecast air) {
  final grades = [
    air.pm10Grade,
    air.pm25Grade,
    air.ozoneGrade,
  ].whereType<String>().toSet();
  return grades.isEmpty ? ('황사', '영향 언급') : ('대기질', grades.join('·'));
}

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

String _decimal(double value) => formatWeatherNumber(value);

class _UnavailableWeekDayCard extends StatelessWidget {
  final DateTime date;
  final WeatherDataPhase dataPhase;
  final bool isToday;
  final DateTime today;
  final List<HourlyWeatherItem> hourly;
  final Future<void> Function()? onRetry;
  final bool retrying;

  const _UnavailableWeekDayCard({
    required this.date,
    required this.dataPhase,
    required this.isToday,
    required this.today,
    required this.hourly,
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
                ? '인근 관측소의 실제 일관측 자료가 없어요.'
                : daysAhead >= 4
                    ? '단기·중기예보를 모두 받지 못해 표시할 자료가 없어요.'
                    : '예보 범위 안이지만 아직 날씨 자료를 받지 못했어요.';
    final card = Container(
      key: ValueKey('week-unavailable-${dateInKorea(date)}'),
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isPast
            ? WeatherCareTheme.of(context).surfaceMuted
            : isToday
                ? WeatherCareTheme.of(context).primarySoft
                : WeatherCareTheme.of(context).surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isToday
              ? WeatherCareTheme.of(context).primaryBorder
              : WeatherCareTheme.of(context).outline,
        ),
        boxShadow: [
          BoxShadow(
            color: WeatherCareTheme.of(context).shadow,
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: WeatherCareTheme.of(context).surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.question_mark_rounded,
              color: WeatherCareTheme.of(context).textSecondary,
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
                    const Spacer(),
                    if (isToday)
                      Text(
                        '오늘',
                        key: ValueKey('week-today-${dateInKorea(date)}'),
                        style: WeatherCareTheme.of(context)
                            .specialLabelStyle
                            .copyWith(
                              fontSize: 11,
                            ),
                      )
                    else if (isPast)
                      Text(
                        '지난 날짜',
                        key: ValueKey('week-past-${dateInKorea(date)}'),
                        style: WeatherCareTheme.of(context)
                            .specialLabelStyle
                            .copyWith(
                              color: WeatherCareTheme.of(context).textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
                for (final (kind, icon, text) in [
                  (
                    'precipitation',
                    Icons.water_drop_outlined,
                    isPast ? '강수 관측 자료 없음' : '강수 자료 없음'
                  ),
                  (
                    'snowfall',
                    Icons.ac_unit_rounded,
                    isPast ? '최심신적설 자료 없음' : '강설확률 자료 없음 · 예상 신적설 자료 없음'
                  ),
                ]) ...[
                  const SizedBox(height: 10),
                  _WeekAmountRow(
                    key: ValueKey('week-$kind-${dateInKorea(date)}'),
                    icon: icon,
                    text: text,
                    isToday: isToday,
                    isPast: isPast,
                  ),
                ],
                if (hourly.isNotEmpty)
                  HourlyForecastSection(
                    key: ValueKey('week-hourly-${dateInKorea(date)}'),
                    keyPrefix: 'week-${dateInKorea(date)}',
                    items: hourly,
                    targetDate: dateInKorea(date),
                    availableOnly: true,
                    inline: true,
                    contrastFilters: isToday,
                  ),
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
