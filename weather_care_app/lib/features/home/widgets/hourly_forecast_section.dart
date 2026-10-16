import '../../../utils/weather_number.dart';
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/briefing_time.dart';
import '../../../models/weather.dart';
import '../../../services/timeline_order_store.dart';
import '../../../theme/weather_theme.dart';
import '../../../utils/korea_date.dart';
import '../weather_labels.dart';
import '../weather_data_phase.dart';
import 'home_section_header.dart';
import 'hourly_value_chart.dart';
import 'missing_data_retry.dart';

enum _HourlyMetric { weather, precipitation, snowfall, uv, wind, humidity }

const _timeLabelHeight = 28.0;
const _timeDotGap = 3.0;

class HourlyForecastSection extends StatefulWidget {
  final String keyPrefix;
  final List<HourlyWeatherItem> items;
  final String? generatedAt;
  final DateTime? receivedAt;
  final DateTime? now;
  final String? targetDate;
  final bool availableOnly;
  final bool inline;
  final bool contrastFilters;
  final WeatherDataPhase dataPhase;
  final Future<void> Function()? onRetryMissingData;
  final bool retrying;

  const HourlyForecastSection({
    super.key,
    this.keyPrefix = 'today',
    required this.items,
    this.generatedAt,
    this.receivedAt,
    this.now,
    this.targetDate,
    this.availableOnly = false,
    this.inline = false,
    this.contrastFilters = false,
    this.dataPhase = WeatherDataPhase.ready,
    this.onRetryMissingData,
    this.retrying = false,
  });

  @override
  State<HourlyForecastSection> createState() => _HourlyForecastSectionState();
}

class _HourlyForecastSectionState extends State<HourlyForecastSection>
    with WidgetsBindingObserver {
  _HourlyMetric _selected = _HourlyMetric.weather;
  final ScrollController _timelineController = ScrollController();
  Object? _scrolledItems;
  String? _scrolledSelection;
  final _contentKey = GlobalKey();
  Timer? _hourTimer;

  DateTime get _now => responseNow(widget.now ?? DateTime.now(),
      generatedAt: widget.generatedAt, receivedAt: widget.receivedAt);

  void _scheduleHour() {
    _hourTimer?.cancel();
    if (widget.now != null) return;
    _hourTimer = Timer(untilNextKoreaHour(_now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleHour();
    });
  }

  @override
  void didUpdateWidget(covariant HourlyForecastSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleHour();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleHour();
    }
  }

  void _selectMetric(_HourlyMetric metric) {
    setState(() => _selected = metric);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final contentContext = _contentKey.currentContext;
      final scrollable = contentContext == null
          ? null
          : Scrollable.maybeOf(contentContext, axis: Axis.vertical);
      final viewport = scrollable?.context.findRenderObject();
      final box = contentContext?.findRenderObject();
      if (scrollable == null || viewport is! RenderBox || box is! RenderBox) {
        return;
      }
      final position = scrollable.position;
      final boxBottom = position.pixels +
          box.localToGlobal(Offset(0, box.size.height), ancestor: viewport).dy -
          position.viewportDimension;
      // 박스 하단을 네비게이션바 위에 맞추는 것을 칩 상단 정렬보다 우선한다.
      position.animateTo(
          boxBottom.clamp(position.minScrollExtent, position.maxScrollExtent),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleHour();
    TimelineOrderStore.order.addListener(_orderChanged);
    TimelineOrderStore.load();
  }

  void _orderChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _editOrder(int month) async {
    var draft = [
      ...(TimelineOrderStore.order.value ?? TimelineOrderStore.defaults(month))
    ];
    var useDefault = TimelineOrderStore.order.value == null;
    var saving = false;
    String? error;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: const Text('타임라인 순서'),
                  content: SizedBox(
                      width: 340,
                      child: SingleChildScrollView(
                          child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('화살표로 순서를 바꿔요. Main과 Week에 함께 적용돼요.'),
                          const SizedBox(height: 8),
                          for (var index = 0; index < draft.length; index++)
                            Row(
                                key: ValueKey('timeline-order-${draft[index]}'),
                                children: [
                                  Expanded(
                                      child: Text(_metricLabel(_HourlyMetric
                                          .values
                                          .byName(draft[index])))),
                                  IconButton(
                                      tooltip:
                                          '${_metricLabel(_HourlyMetric.values.byName(draft[index]))} 위로',
                                      onPressed: saving || index == 0
                                          ? null
                                          : () => update(() {
                                                final metric =
                                                    draft.removeAt(index);
                                                draft.insert(index - 1, metric);
                                                useDefault = false;
                                              }),
                                      icon: const Icon(
                                          Icons.arrow_upward_rounded)),
                                  IconButton(
                                      tooltip:
                                          '${_metricLabel(_HourlyMetric.values.byName(draft[index]))} 아래로',
                                      onPressed: saving ||
                                              index == draft.length - 1
                                          ? null
                                          : () => update(() {
                                                final metric =
                                                    draft.removeAt(index);
                                                draft.insert(index + 1, metric);
                                                useDefault = false;
                                              }),
                                      icon: const Icon(
                                          Icons.arrow_downward_rounded)),
                                ]),
                          TextButton(
                              onPressed: saving
                                  ? null
                                  : () => update(() {
                                        draft =
                                            TimelineOrderStore.defaults(month);
                                        useDefault = true;
                                      }),
                              child: const Text('계절별 기본 순서로 복원')),
                          const Text('봄·여름·가을과 겨울(12~2월)에 맞춰 기본 순서가 바뀌어요.'),
                          if (error != null) Text(error!),
                        ],
                      ))),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(dialogContext),
                        child: const Text('취소')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                update(() {
                                  saving = true;
                                  error = null;
                                });
                                try {
                                  await TimelineOrderStore.save(
                                      useDefault ? null : draft);
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    update(() {
                                      saving = false;
                                      error = '순서를 저장하지 못했어요. 다시 시도해 주세요.';
                                    });
                                  }
                                }
                              },
                        child: Text(saving ? '저장 중' : '저장')),
                  ],
                )));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hourTimer?.cancel();
    TimelineOrderStore.order.removeListener(_orderChanged);
    _timelineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTime = _now;
    final referenceDate = dateInKorea(currentTime);
    final today = widget.targetDate ?? referenceDate;
    final hourlyByHour = <int, HourlyWeatherItem>{};
    final precipitationByHour = <int, HourlyWeatherItem>{};
    final snowfallByHour = <int, HourlyWeatherItem>{};
    for (final item in widget.items) {
      final hour = int.tryParse(item.time);
      final isToday = item.forecastDate == today ||
          (widget.targetDate == null && item.forecastDate == null);
      if (isToday && hour != null && hour >= 0 && hour < 24) {
        hourlyByHour.putIfAbsent(hour, () => item);
      }
      final period = item.precipitationPeriod;
      if (period != null && period.date == today) {
        final startHour =
            period.start.toUtc().add(const Duration(hours: 9)).hour;
        final previous = precipitationByHour[startHour];
        if (previous == null ||
            !_hasValue(_HourlyMetric.precipitation, previous)) {
          precipitationByHour[startHour] = item;
        }
        snowfallByHour.putIfAbsent(startHour, () => item);
      } else if (period == null &&
          !widget.availableOnly &&
          isToday &&
          hour != null &&
          hour >= 0 &&
          hour < 24) {
        final previous = precipitationByHour[hour];
        if (previous == null ||
            !_hasValue(_HourlyMetric.precipitation, previous)) {
          precipitationByHour[hour] = item;
        }
        snowfallByHour.putIfAbsent(hour, () => item);
      }
    }
    final emptySlots = [
      for (var hour = 0; hour < 24; hour++)
        HourlyWeatherItem(
          time: hour.toString().padLeft(2, '0'),
          forecastDate: today,
          temperature: null,
          precipitationProbability: null,
          precipitationAmount: null,
          snowExpected: null,
          snowfallAmount: null,
          windSpeed: null,
          skyCondition: null,
        ),
    ];
    Map<int, HourlyWeatherItem> itemsFor(_HourlyMetric metric) =>
        switch (metric) {
          _HourlyMetric.precipitation => precipitationByHour,
          _HourlyMetric.snowfall => snowfallByHour,
          _ => hourlyByHour,
        };
    final month = int.tryParse(referenceDate.substring(5, 7)) ?? 1;
    final metricOrder =
        TimelineOrderStore.order.value ?? TimelineOrderStore.defaults(month);
    final availableMetrics = [
      for (final name in metricOrder)
        for (final metric in [_HourlyMetric.values.byName(name)])
          if (!widget.availableOnly ||
              itemsFor(metric).values.any((item) => _hasValue(metric, item)))
            metric,
    ];
    if (availableMetrics.isEmpty) return const SizedBox.shrink();
    final selected = availableMetrics.contains(_selected)
        ? _selected
        : availableMetrics.first;
    final selectedItems = <HourlyWeatherItem>[];
    final selectedHours = <int>[];
    for (var hour = 0; hour < 24; hour++) {
      final item = itemsFor(selected)[hour];
      if (widget.availableOnly) {
        if (item != null && _hasValue(selected, item)) {
          selectedItems.add(item);
          selectedHours.add(hour);
        }
      } else {
        selectedItems.add(item ?? emptySlots[hour]);
        selectedHours.add(hour);
      }
    }
    final pointWidth = MediaQuery.textScalerOf(context).scale(
      selected == _HourlyMetric.wind
          ? 100.0
          : selected == _HourlyMetric.weather
              ? 80.0
              : 72.0,
    );
    final series =
        _chartSeries(selected, selectedItems, WeatherCareTheme.of(context));
    final precipitation = selected == _HourlyMetric.precipitation ||
        selected == _HourlyMetric.snowfall;
    final combined = selected == _HourlyMetric.weather || precipitation;
    final tall =
        selected == _HourlyMetric.humidity || selected == _HourlyMetric.uv;
    final chartHeight = (tall
            ? 400.0
            : combined
                ? 320.0
                : hourlyChartHeight) *
        math.min(MediaQuery.textScalerOf(context).scale(1), 1.3);
    final sharedBounds = selected == _HourlyMetric.weather
        ? HourlyChartSeries(
                id: 'temperature-axis',
                title: '온도',
                unit: '°C',
                values: series.expand((chart) => chart.values).toList())
            .bounds
        : null;
    final bottomPadding = hourlyChartBottomPadding(series, sharedBounds,
        chartHeight, MediaQuery.textScalerOf(context).scale(18));
    final currentHour = today == dateInKorea(currentTime)
        ? currentTime.toUtc().add(const Duration(hours: 9)).hour
        : 0;
    final timelineWidth = hourlyChartWidth(selectedHours, pointWidth, series);
    final timelineEndPadding = timelineWidth -
        (selectedHours.last - selectedHours.first + 1) * pointWidth;
    final intervalTimeline = series.any((chart) => chart.intervals);
    final scrollSelection = '$today:${selected.name}:$currentHour:$pointWidth';
    if (!identical(_scrolledItems, widget.items) ||
        _scrolledSelection != scrollSelection) {
      _scrolledItems = widget.items;
      _scrolledSelection = scrollSelection;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_timelineController.hasClients) return;
        final hour = currentHour.clamp(selectedHours.first, selectedHours.last);
        _timelineController.jumpTo(
          ((hour - selectedHours.first - (intervalTimeline ? .5 : 0)) *
                  pointWidth)
              .clamp(
                  0.0,
                  math.min(
                      _timelineController.position.maxScrollExtent,
                      math.max(
                          0.0,
                          timelineWidth -
                              _timelineController.position.viewportDimension))),
        );
      });
    }
    final hasMissingData = hourlyByHour.isEmpty ||
        hourlyByHour.values.any(
          (item) =>
              item.time == '--' ||
              item.temperature == null ||
              item.displayedApparentTemperature == null ||
              item.precipitationProbability == null ||
              item.windSpeed == null ||
              item.skyCondition == null,
        );
    return LayoutBuilder(builder: (context, constraints) {
      final content = Container(
        key: ValueKey(widget.keyPrefix == 'main'
            ? 'main-hourly-timeline-section'
            : widget.inline
                ? '${widget.keyPrefix}-hourly-timeline-section'
                : 'today-hourly-forecast-section'),
        padding: widget.inline
            ? const EdgeInsets.only(top: 12)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
        decoration: widget.inline
            ? null
            : WeatherCareTheme.of(context).surfaceDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.inline)
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    key: ValueKey('${widget.keyPrefix}-hourly-title-icon'),
                    size: 18,
                    color: WeatherCareTheme.of(context).primaryDeep,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('시간별 예보',
                        style: Theme.of(context).textTheme.labelLarge),
                  ),
                ],
              )
            else
              HomeSectionHeader(
                icon: Icons.schedule_rounded,
                title: '타임라인',
                subtitle: '항목을 선택해 시간별로 비교해요',
              ),
            if (!widget.inline)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: ValueKey('${widget.keyPrefix}-hourly-order'),
                            onPressed: () => _editOrder(month),
                            style:
                                TextButton.styleFrom(padding: EdgeInsets.zero),
                            icon: const Icon(Icons.swap_vert_rounded, size: 18),
                            label: const Text('순서 변경'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: ValueKey('${widget.keyPrefix}-hourly-info'),
                      tooltip: '타임라인 안내',
                      alignment: Alignment.centerRight,
                      onPressed: () => _showHourlyInfo(context),
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 32, height: 32),
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(Icons.error_outline_rounded,
                          color: WeatherCareTheme.of(context).primaryDeep),
                    ),
                  ],
                ),
              ),
            if (widget.inline) const SizedBox(height: 20),
            SingleChildScrollView(
              key: ValueKey('${widget.keyPrefix}-hourly-filters'),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 10, right: 3),
              child: Row(
                children: [
                  for (final metric in availableMetrics)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        key: ValueKey(
                            '${widget.keyPrefix}-hourly-filter-${metric.name}'),
                        showCheckmark: false,
                        label: Text(_metricLabel(metric)),
                        selected: selected == metric,
                        backgroundColor: widget.contrastFilters
                            ? WeatherCareTheme.of(context).surface
                            : null,
                        selectedColor: widget.contrastFilters
                            ? WeatherCareTheme.of(context).actionBackground
                            : null,
                        labelStyle: (Theme.of(context).chipTheme.labelStyle ??
                                const TextStyle())
                            .copyWith(
                          fontFamily: WeatherCareTheme.fontSuite,
                          color: widget.contrastFilters
                              ? selected == metric
                                  ? WeatherCareTheme.of(context).onPrimary
                                  : WeatherCareTheme.of(context).textPrimary
                              : null,
                        ),
                        onSelected: (_) => _selectMetric(metric),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (series.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(left: 6, right: 6, bottom: 32),
                  child: HourlyChartLegend(
                      key: ValueKey(
                          '${widget.keyPrefix}-hourly-legend-${selected.name}'),
                      series: series)),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (series.isNotEmpty)
                SizedBox(
                    width: 44 *
                        math.min(
                            MediaQuery.textScalerOf(context).scale(1), 1.3),
                    child: HourlyChartAxis(
                        series: series.first,
                        height: chartHeight,
                        sharedBounds: sharedBounds,
                        bottomPadding: bottomPadding)),
              Expanded(child: LayoutBuilder(builder: (context, viewport) {
                final contentWidth = math.max(viewport.maxWidth, timelineWidth);
                return SingleChildScrollView(
                  key: ValueKey('${widget.keyPrefix}-hourly-timeline'),
                  controller: _timelineController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                      width: contentWidth,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final chart
                                in combined ? series.take(1) : series)
                              HourlyValueChart(
                                series: chart,
                                hours: selectedHours,
                                pointWidth: pointWidth,
                                height: chartHeight,
                                sharedBounds: sharedBounds,
                                overlays: combined
                                    ? series.skip(1).toList()
                                    : const [],
                                showValues: true,
                                conditions: selected == _HourlyMetric.weather
                                    ? selectedItems
                                        .map((item) => item.skyCondition)
                                        .toList()
                                    : const [],
                              ),
                            if (precipitation) const SizedBox(height: 8),
                            if (intervalTimeline)
                              SizedBox(
                                width: timelineWidth,
                                height: MediaQuery.textScalerOf(context)
                                        .scale(_timeLabelHeight) +
                                    _timeDotGap,
                                child: Stack(children: [
                                  for (var hour = selectedHours.first;
                                      hour <= selectedHours.last + 1;
                                      hour++)
                                    Positioned(
                                      key: ValueKey(selectedHours
                                              .contains(hour - 1)
                                          ? '${widget.keyPrefix}-hourly-${selectedHours.indexOf(hour - 1)}'
                                          : '${widget.keyPrefix}-hourly-clock-$hour'),
                                      left: math.max(
                                          0,
                                          (hour - selectedHours.first - .5) *
                                              pointWidth),
                                      width: pointWidth,
                                      child: _HourlyTimeLabel(
                                        label:
                                            '${hour.toString().padLeft(2, '0')}시',
                                        valueKey: const ValueKey(
                                            'hourly-probability-time'),
                                        alignment: hour == selectedHours.first
                                            ? Alignment.centerLeft
                                            : Alignment.center,
                                        isCurrent:
                                            today == dateInKorea(currentTime) &&
                                                hour == currentHour,
                                      ),
                                    ),
                                ]),
                              )
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var index = 0;
                                      index < selectedItems.length;
                                      index++) ...[
                                    if (index > 0 &&
                                        selectedHours[index] -
                                                selectedHours[index - 1] >
                                            1)
                                      SizedBox(
                                          width: (selectedHours[index] -
                                                  selectedHours[index - 1] -
                                                  1) *
                                              pointWidth),
                                    _HourlyPoint(
                                      key: ValueKey(
                                          '${widget.keyPrefix}-hourly-$index'),
                                      item: selectedItems[index],
                                      metric: selected,
                                      dataPhase: widget.dataPhase,
                                      today: today,
                                      pointWidth: pointWidth,
                                      now: currentTime,
                                    ),
                                  ],
                                  if (timelineEndPadding > 0)
                                    SizedBox(width: timelineEndPadding),
                                ],
                              ),
                          ])),
                );
              })),
              if (precipitation)
                SizedBox(
                    width: 40 *
                        math.min(
                            MediaQuery.textScalerOf(context).scale(1), 1.3),
                    child: HourlyChartAxis(
                        series: series.last,
                        height: chartHeight,
                        right: true,
                        bottomPadding: bottomPadding)),
            ]),
            if (itemsFor(selected).isEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WeatherCareTheme.of(context).surfaceMuted,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(
                  widget.dataPhase == WeatherDataPhase.loading
                      ? '타임라인을 불러오고 있어요.'
                      : widget.dataPhase == WeatherDataPhase.failed
                          ? '서버에서 타임라인을 불러오지 못했어요.'
                          : widget.items.isEmpty
                              ? '타임라인 자료가 없어 표시하기 어려워요.'
                              : '표시할 타임라인 자료가 없어요.',
                  style: TextStyle(
                    color: WeatherCareTheme.of(context).textSecondary,
                  ),
                ),
              ),
            ],
            if (hasMissingData &&
                widget.dataPhase != WeatherDataPhase.loading &&
                widget.onRetryMissingData != null) ...[
              const SizedBox(height: 12),
              MissingDataRetry(
                message: widget.dataPhase == WeatherDataPhase.failed
                    ? '서버에서 타임라인 항목을 불러오지 못했어요.'
                    : '받지 못한 타임라인 항목이 있어요.',
                retryKey: '${widget.keyPrefix}-hourly-data-retry',
                onRetry: widget.onRetryMissingData!,
                retrying: widget.retrying,
              ),
            ],
          ],
        ),
      );
      final measuredContent = KeyedSubtree(key: _contentKey, child: content);
      return constraints.hasBoundedHeight
          ? SingleChildScrollView(child: measuredContent)
          : measuredContent;
    });
  }
}

bool _hasValue(_HourlyMetric metric, HourlyWeatherItem item) =>
    switch (metric) {
      _HourlyMetric.weather => item.skyCondition != null ||
          item.temperature != null ||
          item.displayedApparentTemperature != null,
      _HourlyMetric.precipitation => item.precipitationProbability != null ||
          item.precipitationAmount != null ||
          item.precipitationAmountLabel != null,
      _HourlyMetric.snowfall => item.snowExpected != null ||
          item.snowfallAmount != null ||
          item.snowfallAmountLabel != null,
      _HourlyMetric.uv => item.uvIndex != null,
      _HourlyMetric.wind => item.windSpeed != null,
      _HourlyMetric.humidity => item.humidity != null,
    };

void _showHourlyInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('타임라인 안내'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '기온·바람은 정시 값이에요. 강수와 강설의 양·확률은 정시 눈금 사이의 1시간 구간 가운데에 표시해요. 구간 시간 문구는 따로 쓰지 않으며, 확률은 시간별로 더하지 않아요.\n자외선은 자료가 있는 경우에만 표시해요. 자외선지수 0도 실제 값이며, 자료가 없으면 —로 표시해요.'),
            SizedBox(height: 8),
            Text(
              '가시거리는 현재 관측자료만 제공돼 시간별 예보에는 표시하지 않아요.',
              key: ValueKey('today-hourly-visibility-notice'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

String _metricLabel(_HourlyMetric metric) => switch (metric) {
      _HourlyMetric.weather => '기온',
      _HourlyMetric.precipitation => '강수',
      _HourlyMetric.snowfall => '강설',
      _HourlyMetric.uv => '자외선',
      _HourlyMetric.wind => '바람',
      _HourlyMetric.humidity => '습도',
    };

double? _snowProbability(HourlyWeatherItem item) {
  final probability = item.precipitationProbability;
  if (probability == null ||
      probability < 0 ||
      probability > 100 ||
      item.snowExpected == null) {
    return null;
  }
  return item.snowExpected! ? probability : 0;
}

const _uvBands = [
  HourlyChartBand(0, 2, WeatherCareTheme.primaryDeep, '낮음 · 0~2',
      includeUpper: true),
  HourlyChartBand(2, 5, Colors.orange, '보통 · 2 초과~5', includeUpper: true),
  HourlyChartBand(5, 7, Colors.deepOrange, '높음 · 5 초과~7', includeUpper: true),
  HourlyChartBand(7, 10, Colors.red, '매우 높음 · 7 초과~10', includeUpper: true),
  HourlyChartBand(10, 100, Color(0xFFB71C1C), '위험 · 10 초과', includeUpper: true),
];
const _humidityBands = [
  HourlyChartBand(0, 35, Color(0xFFB27A3D), '건조 · 35% 이하', includeUpper: true),
  HourlyChartBand(35, 70, WeatherCareTheme.primaryDeep, '쾌적 · 35% 초과~70% 미만'),
  HourlyChartBand(70, 80, Color(0xFF7C78A8), '습한 편 · 70~80% 미만'),
  HourlyChartBand(80, 100, Color(0xFF655184), '매우 습함 · 80% 이상',
      includeUpper: true),
];

List<HourlyChartSeries> _chartSeries(_HourlyMetric metric,
    List<HourlyWeatherItem> items, WeatherCarePalette palette) {
  HourlyChartSeries chart(String id, String title, String unit,
          HourlyChartValue? Function(HourlyWeatherItem) value,
          {bool bars = false,
          double? max,
          List<HourlyChartBand> bands = const [],
          Color? color,
          String? Function(HourlyWeatherItem)? label}) =>
      HourlyChartSeries(
          id: id,
          title: title,
          unit: unit,
          values: items.map((item) {
            if ((metric == _HourlyMetric.precipitation ||
                    metric == _HourlyMetric.snowfall) &&
                item.precipitationPeriodProvided &&
                item.precipitationPeriod == null) {
              return null;
            }
            final result = value(item);
            if (max == 100 &&
                (result != null && (result.lower < 0 || result.lower > 100))) {
              return null;
            }
            return result;
          }).toList(),
          bars: bars,
          fixedMax: max,
          bands: bands,
          color: color,
          intervals: (metric == _HourlyMetric.precipitation ||
                  metric == _HourlyMetric.snowfall) &&
              items.any((item) => item.precipitationPeriod != null),
          labels: label == null ? const [] : items.map(label).toList());
  HourlyChartValue? number(double? value) => HourlyChartValue.number(value);
  return switch (metric) {
    _HourlyMetric.weather => [
        chart('temperature', '기온', '°C', (item) => number(item.temperature),
            color: palette.primaryDeep),
        chart('apparent', '체감온도', '°C',
            (item) => number(item.displayedApparentTemperature),
            color: palette.brightness == Brightness.dark
                ? const Color(0xFFE4A977)
                : const Color(0xFFB56837)),
      ],
    _HourlyMetric.precipitation => [
        chart(
            'rain-amount',
            '강수량',
            'mm',
            (item) => HourlyChartValue.amount(
                item.precipitationAmount, item.precipitationAmountLabel),
            color: palette.primaryDeep,
            label: (item) =>
                item.precipitationAmountLabel ??
                (item.precipitationAmount == null
                    ? null
                    : '${formatWeatherNumber(item.precipitationAmount!)}mm')),
        chart('rain-probability', '강수확률', '%',
            (item) => number(item.precipitationProbability),
            bars: true,
            max: 100,
            color: palette.brightness == Brightness.dark
                ? const Color(0xFFBFA6E8)
                : const Color(0xFF8A65B5)),
      ],
    _HourlyMetric.snowfall => [
        chart(
            'snow-amount',
            '신적설',
            'cm',
            (item) => HourlyChartValue.amount(
                item.snowfallAmount, item.snowfallAmountLabel),
            color: palette.primaryDeep,
            label: (item) =>
                item.snowfallAmountLabel ??
                (item.snowfallAmount == null
                    ? null
                    : '${formatWeatherNumber(item.snowfallAmount!)}cm')),
        chart('snow-probability', '강설확률', '%',
            (item) => number(_snowProbability(item)),
            bars: true,
            max: 100,
            color: palette.brightness == Brightness.dark
                ? const Color(0xFFBFA6E8)
                : const Color(0xFF8A65B5)),
      ],
    _HourlyMetric.uv => [
        chart('uv', '자외선', '지수', (item) => number(item.uvIndex),
            max: math.max(
                12,
                items.fold(
                    0.0, (value, item) => math.max(value, item.uvIndex ?? 0))),
            bands: _uvBands)
      ],
    _HourlyMetric.humidity => [
        chart('humidity', '습도', '%', (item) => number(item.humidity),
            bars: true, max: 100, bands: _humidityBands)
      ],
    _HourlyMetric.wind => [],
  };
}

class _HourlyTimeLabel extends StatelessWidget {
  final String label;
  final bool isCurrent;
  final Key? valueKey;
  final Alignment alignment;
  const _HourlyTimeLabel(
      {required this.label,
      required this.isCurrent,
      this.valueKey,
      this.alignment = Alignment.center});

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(_timeLabelHeight),
      child: Align(
          alignment: alignment,
          child: Semantics(
            label: isCurrent ? '현재 시간 $label' : null,
            child: Container(
              key: isCurrent ? const ValueKey('hourly-current-time') : null,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: isCurrent
                  ? BoxDecoration(
                      color: palette.primaryDeep,
                      borderRadius: BorderRadius.circular(8))
                  : null,
              child: Text(label,
                  key: valueKey,
                  maxLines: 1,
                  style: TextStyle(
                      color:
                          isCurrent ? palette.onPrimary : palette.primaryDeep,
                      fontWeight: FontWeight.w900)),
            ),
          )),
    );
  }
}

class _HourlyPoint extends StatelessWidget {
  final HourlyWeatherItem item;
  final _HourlyMetric metric;
  final WeatherDataPhase dataPhase;
  final String today;
  final double pointWidth;
  final DateTime now;

  const _HourlyPoint({
    super.key,
    required this.item,
    required this.metric,
    required this.dataPhase,
    required this.today,
    required this.pointWidth,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    final period = item.precipitationPeriod;
    final precipitationValid = !item.precipitationPeriodProvided ||
        (period != null && period.date.compareTo(today) >= 0);
    final hour = int.tryParse(item.time);
    final labelDate = item.forecastDate;
    final dayPrefix =
        labelDate != null && labelDate.compareTo(today) > 0 ? '내일 ' : '';
    final timeLabel = hour != null && hour >= 0 && hour < 24
        ? '$dayPrefix${hour.toString().padLeft(2, '0')}시'
        : '시각 ${dataPhase.missingText()}';
    final isCurrent = (labelDate ?? today) == dateInKorea(now) &&
        hour == now.toUtc().add(const Duration(hours: 9)).hour;
    final visual = switch (metric) {
      _HourlyMetric.wind => Transform.rotate(
          key: const ValueKey('today-hourly-wind-icon'),
          angle: ((item.windDirection ?? 90) - 90) * math.pi / 180,
          child: Icon(Icons.air_rounded, size: 30, color: palette.primaryDeep),
        ),
      _ => null,
    };
    final values = switch (metric) {
      _HourlyMetric.precipitation =>
        precipitationValid ? <String>[] : ['강수 구간 —'],
      _HourlyMetric.snowfall => precipitationValid ? <String>[] : ['강설 구간 —'],
      _HourlyMetric.wind => [
          windDescription(item.windSpeed) ?? '—',
          '${_windDirectionLabel(item.windDirection)} · ${item.windSpeed == null ? '—' : '${formatWeatherNumber(item.windSpeed!, keepDecimal: true)}m/s'}',
        ],
      _ => <String>[],
    };

    return SizedBox(
      width: pointWidth,
      child: Column(
        children: [
          _HourlyTimeLabel(label: timeLabel, isCurrent: isCurrent),
          const SizedBox(height: _timeDotGap),
          if (metric == _HourlyMetric.wind) ...[
            Stack(alignment: Alignment.center, children: [
              Container(height: 2, color: palette.primaryBorder),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: palette.primaryDeep, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 8),
          ],
          if (visual != null) ...[
            SizedBox(height: 44, child: Center(child: visual)),
            const SizedBox(height: 3),
          ],
          if (metric == _HourlyMetric.wind ||
              metric == _HourlyMetric.snowfall ||
              (metric == _HourlyMetric.precipitation && !precipitationValid))
            for (var index = 0; index < values.length; index++)
              Text(
                values[index],
                textAlign: TextAlign.center,
                maxLines: 1,
                style: index == 0 &&
                        metric != _HourlyMetric.precipitation &&
                        metric != _HourlyMetric.uv
                    ? Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        )
                    : Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                          fontSize: 10,
                        ),
              ),
        ],
      ),
    );
  }
}

String _windDirectionLabel(double? direction) {
  if (direction == null) return '방향 —';
  const labels = ['북', '북동', '동', '남동', '남', '남서', '서', '북서'];
  final normalized = ((direction % 360) + 360) % 360;
  return '${labels[((normalized + 22.5) ~/ 45) % labels.length]}풍';
}
