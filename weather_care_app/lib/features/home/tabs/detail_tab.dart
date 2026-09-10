import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../models/lifestyle_message.dart';
import '../../../models/weather.dart';
import '../../../services/notification_destination.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/home_section_header.dart';
import '../widgets/server_feature_unavailable_card.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/weather_card.dart';
import '../widgets/weather_condition_icon.dart';

enum DetailFocusSource {
  notification,
  selection,
}

class DetailTab extends StatefulWidget {
  final TodayWeatherResponse today;
  final List<WeatherRecommendation> recommendations;
  final bool serverFeaturesAvailable;
  final Future<void> Function() onRefresh;
  final NotificationTopic? focusTopic;
  final LifestyleMessageType? focusLifestyleType;
  final DetailFocusSource focusSource;
  final int focusRequestId;

  const DetailTab({
    super.key,
    required this.today,
    required this.recommendations,
    required this.serverFeaturesAvailable,
    required this.onRefresh,
    this.focusTopic,
    this.focusLifestyleType,
    this.focusSource = DetailFocusSource.notification,
    this.focusRequestId = 0,
  });

  @override
  State<DetailTab> createState() => _DetailTabState();
}

class _DetailTabState extends State<DetailTab> {
  final _focusedEvidenceKey = GlobalKey();
  final _evidenceSectionKey = GlobalKey();
  bool _focusScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleFocusScroll();
  }

  @override
  void didUpdateWidget(covariant DetailTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusTopic != widget.focusTopic ||
        oldWidget.focusLifestyleType != widget.focusLifestyleType ||
        oldWidget.focusSource != widget.focusSource ||
        oldWidget.focusRequestId != widget.focusRequestId ||
        oldWidget.today != widget.today) {
      _focusScheduled = false;
      _scheduleFocusScroll();
    }
  }

  void _scheduleFocusScroll() {
    if (_focusScheduled ||
        !_shouldFocus(widget.focusTopic, widget.focusLifestyleType)) {
      return;
    }
    _focusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _focusedEvidenceKey.currentContext ??
          _evidenceSectionKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: WeatherCareTheme.primary,
      onRefresh: widget.onRefresh,
      child: ListView(
        key: const ValueKey('detail-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TabPageHeader(
            eyebrow: 'DETAIL',
            title: '날씨 자세히보기',
            subtitle: '상세한 날씨 정보를 확인해요',
            icon: Icons.query_stats_rounded,
          ),
          const SizedBox(height: 18),
          WeatherInfoCard(current: widget.today.current),
          const SizedBox(height: 16),
          if (widget.serverFeaturesAvailable)
            _RecommendationEvidence(
              key: _evidenceSectionKey,
              today: widget.today,
              focusTopic: widget.focusTopic,
              focusLifestyleType: widget.focusLifestyleType,
              focusSource: widget.focusSource,
              focusedItemKey: _focusedEvidenceKey,
            )
          else
            const ServerFeatureUnavailableCard(
              icon: Icons.fact_check_outlined,
              title: '챙길 이유',
            ),
          const SizedBox(height: 16),
          _HourlyForecastCard(items: widget.today.hourly),
        ],
      ),
    );
  }
}

class _RecommendationEvidence extends StatelessWidget {
  final TodayWeatherResponse today;
  final NotificationTopic? focusTopic;
  final LifestyleMessageType? focusLifestyleType;
  final DetailFocusSource focusSource;
  final Key focusedItemKey;

  const _RecommendationEvidence({
    super.key,
    required this.today,
    required this.focusTopic,
    required this.focusLifestyleType,
    required this.focusSource,
    required this.focusedItemKey,
  });

  @override
  Widget build(BuildContext context) {
    final focusedTypes = focusLifestyleType == null
        ? lifestyleTypesForNotificationTopic(focusTopic)
        : {focusLifestyleType!};
    final orderedItems = [
      ...today.lifestyleMessages.where(
        (item) => focusedTypes.contains(item.type),
      ),
      ...today.lifestyleMessages.where(
        (item) => !focusedTypes.contains(item.type),
      ),
    ];
    final items = orderedItems.take(5).toList();
    final focusedIndex = items.indexWhere(
      (item) => focusedTypes.contains(item.type),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionHeader(
            title: '근거와 자료',
            subtitle: '추천 뒤에 공식 정보와 자료 상태를 확인해요',
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(
              '현재 조건에서는 별도 준비물 추천이 없어요.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              _EvidenceItem(
                key: index == focusedIndex ? focusedItemKey : null,
                message: items[index],
                focused: index == focusedIndex,
                focusSource: focusSource,
              ),
              if (index < items.length - 1) ...[
                const SizedBox(height: 11),
                const Divider(height: 1),
                const SizedBox(height: 11),
              ],
            ],
        ],
      ),
    );
  }
}

class _EvidenceItem extends StatelessWidget {
  final LifestyleMessage message;
  final bool focused;
  final DetailFocusSource focusSource;

  const _EvidenceItem({
    super.key,
    required this.message,
    required this.focused,
    required this.focusSource,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: focused ? const ValueKey('detail-focused-evidence') : null,
      duration: const Duration(milliseconds: 250),
      padding: focused ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: focused
          ? BoxDecoration(
              color: WeatherCareTheme.primarySoft.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WeatherCareTheme.primary),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: WeatherCareTheme.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.fact_check_outlined,
              size: 19,
              color: WeatherCareTheme.primaryDeep,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (focused) ...[
                  Text(
                    switch (focusSource) {
                      DetailFocusSource.notification => '알림에서 확인한 항목',
                      DetailFocusSource.selection => '선택한 항목의 근거',
                    },
                    style: WeatherCareTheme.microTextStyle.copyWith(
                      color: WeatherCareTheme.primaryDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                for (final part in message.parts.skip(1)) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${part.role.label} · ${part.text}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _shouldFocus(
  NotificationTopic? topic,
  LifestyleMessageType? lifestyleType,
) =>
    lifestyleType != null ||
    (topic != null &&
        topic != NotificationTopic.overview &&
        topic != NotificationTopic.unknown);

Set<LifestyleMessageType> lifestyleTypesForNotificationTopic(
  NotificationTopic? topic,
) =>
    switch (topic) {
      NotificationTopic.strongWind => const {
          LifestyleMessageType.outdoorCaution,
        },
      NotificationTopic.roadIce => const {
          LifestyleMessageType.blackIceCaution,
          LifestyleMessageType.wetRoadCaution,
        },
      NotificationTopic.uv => const {
          LifestyleMessageType.strongSunExposure,
          LifestyleMessageType.sunscreenUseful,
        },
      NotificationTopic.precipitation => const {
          LifestyleMessageType.rainGearUseful,
          LifestyleMessageType.rainBreakWindow,
          LifestyleMessageType.wetRoadCaution,
          LifestyleMessageType.windowCloseSoon,
        },
      NotificationTopic.laundry => const {
          LifestyleMessageType.laundryPickupDue,
        },
      NotificationTopic.petWalk => const {
          LifestyleMessageType.petWalkWindow,
          LifestyleMessageType.bestOutingWindow,
        },
      NotificationTopic.commute => const {
          LifestyleMessageType.commuteRouteCaution,
          LifestyleMessageType.wetRoadCaution,
          LifestyleMessageType.snowTravelCaution,
        },
      NotificationTopic.sleep => const {
          LifestyleMessageType.nightWeatherCheck,
          LifestyleMessageType.veryHotAndHumid,
        },
      NotificationTopic.snow => const {
          LifestyleMessageType.snowTravelCaution,
        },
      NotificationTopic.airQuality => const {
          LifestyleMessageType.maskUseful,
          LifestyleMessageType.ozoneCaution,
        },
      NotificationTopic.temperature => const {
          LifestyleMessageType.outerwearUseful,
          LifestyleMessageType.coolerThanTemperature,
          LifestyleMessageType.largeTemperatureSwing,
          LifestyleMessageType.rapidTemperatureDrop,
        },
      NotificationTopic.heat => const {
          LifestyleMessageType.hydrationImportant,
          LifestyleMessageType.veryHotAndHumid,
        },
      NotificationTopic.overview ||
      NotificationTopic.weatherWarning ||
      NotificationTopic.unknown ||
      null =>
        const {},
    };

LifestyleMessageType detailLifestyleTypeForRecommendationType(
  RecommendationType type,
) =>
    switch (type) {
      RecommendationType.umbrella => LifestyleMessageType.rainGearUseful,
      RecommendationType.parasol => LifestyleMessageType.strongSunExposure,
      RecommendationType.heavySnowCaution =>
        LifestyleMessageType.snowTravelCaution,
      RecommendationType.outerwear => LifestyleMessageType.outerwearUseful,
      RecommendationType.mask => LifestyleMessageType.maskUseful,
      RecommendationType.water => LifestyleMessageType.hydrationImportant,
      RecommendationType.sunscreen => LifestyleMessageType.sunscreenUseful,
    };

class _HourlyForecastCard extends StatelessWidget {
  final List<HourlyWeatherItem> items;

  const _HourlyForecastCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final visibleItems = _todayHourlyItems(items);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionHeader(
            icon: Icons.schedule_rounded,
            title: '시간별 예보',
            subtitle: '기온·체감·강수·바람을 시간별로 비교해요',
          ),
          const SizedBox(height: 8),
          Text(
            '자외선과 대기질은 자료가 있는 시간대에만 표시해요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (visibleItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WeatherCareTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(
                items.isEmpty
                    ? '시간별 예보 자료가 없어 표시하기 어려워요.'
                    : '오늘 표시할 시간별 예보가 없어요.',
                style: const TextStyle(
                  color: WeatherCareTheme.textSecondary,
                ),
              ),
            )
          else
            for (var index = 0; index < visibleItems.length; index++) ...[
              _HourlyRow(
                key: ValueKey('detail-hourly-$index'),
                item: visibleItems[index],
              ),
              if (index < visibleItems.length - 1) const SizedBox(height: 9),
            ],
        ],
      ),
    );
  }
}

List<HourlyWeatherItem> _todayHourlyItems(List<HourlyWeatherItem> items) {
  final hasForecastDates = items.any((item) => item.forecastDate != null);
  if (!hasForecastDates) {
    return items.take(24).toList(growable: false);
  }

  final nowInKorea = DateTime.now().toUtc().add(const Duration(hours: 9));
  final today = '${nowInKorea.year.toString().padLeft(4, '0')}-'
      '${nowInKorea.month.toString().padLeft(2, '0')}-'
      '${nowInKorea.day.toString().padLeft(2, '0')}';
  return items
      .where((item) => item.forecastDate == today)
      .toList(growable: false);
}

class _HourlyRow extends StatelessWidget {
  final HourlyWeatherItem item;

  const _HourlyRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final rainAmount = item.precipitationAmountLabel ??
        (item.precipitationAmount == null
            ? null
            : '${_amountNumber(item.precipitationAmount!)}mm');
    final snowAmount = item.snowfallAmountLabel ??
        (item.snowfallAmount == null
            ? null
            : '${_amountNumber(item.snowfallAmount!)}cm');
    final showRain = (item.precipitationProbability ?? 0) > 0 ||
        _hasPositiveAmount(rainAmount, 'mm');
    final showSnow =
        item.snowExpected == true || _hasPositiveAmount(snowAmount, 'cm');
    final missing = [
      if (item.precipitationProbability == null) '강수확률',
      if (rainAmount == null) '강수량',
      if (snowAmount == null) '쌓일 눈',
      if (item.windSpeed == null) '풍속',
    ];
    final hour = int.tryParse(item.time);
    final timeLabel = hour != null && hour >= 0 && hour < 24
        ? '${hour.toString().padLeft(2, '0')}시'
        : '시각 자료 없음';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WeatherCareTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: WeatherCareTheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  timeLabel,
                  style: const TextStyle(
                    color: WeatherCareTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              WeatherConditionIcon(
                condition: item.skyCondition,
                size: 19,
                color: WeatherCareTheme.textSecondary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  item.skyCondition ?? '날씨 자료 없음',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item.temperature == null
                    ? '예상기온 자료 없음'
                    : '예상기온 ${item.temperature!.toStringAsFixed(0)}℃',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              Text(
                item.apparentTemperature == null
                    ? '예상 체감 자료 없음'
                    : '예상 체감 ${item.apparentTemperature!.toStringAsFixed(0)}℃',
                style: const TextStyle(
                  color: WeatherCareTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (showRain && item.precipitationProbability != null)
                _MetricChip(
                  icon: Icons.water_drop_outlined,
                  label:
                      '강수확률 ${item.precipitationProbability!.toStringAsFixed(0)}%',
                ),
              if (_hasPositiveAmount(rainAmount, 'mm'))
                _MetricChip(
                  icon: Icons.water_drop_outlined,
                  label: '강수량 $rainAmount',
                ),
              if (showSnow)
                _MetricChip(
                  icon: Icons.ac_unit_rounded,
                  label: _hasPositiveAmount(snowAmount, 'cm')
                      ? '쌓일 눈 $snowAmount'
                      : '눈이 예보됐어요',
                ),
              if (item.windSpeed != null)
                _MetricChip(
                  icon: Icons.air_rounded,
                  label: '바람 ${item.windSpeed!.toStringAsFixed(1)}m/s',
                ),
              if (item.uvIndex != null)
                _MetricChip(
                  icon: Icons.wb_sunny_outlined,
                  label: '자외선 ${item.uvIndex!.toStringAsFixed(0)}',
                ),
              if (item.pm25 != null)
                _MetricChip(
                  icon: Icons.grain_rounded,
                  label: '초미세먼지 ${item.pm25}㎍/㎥',
                ),
              if (item.pm10 != null)
                _MetricChip(
                  icon: Icons.grain_rounded,
                  label: '미세먼지 ${item.pm10}㎍/㎥',
                ),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '자료 없음: ${missing.join(' · ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WeatherCareTheme.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

String _amountNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

// 명시된 무강수·무적설은 반복 노출하지 않되, 미만·범위 예보는 보존한다.
bool _hasPositiveAmount(String? label, String unit) =>
    label != null && label != '0$unit' && label != '0.0$unit';

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: WeatherCareTheme.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: WeatherCareTheme.microTextStyle.copyWith(
                color: WeatherCareTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
