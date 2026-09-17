import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../models/lifestyle_message.dart';
import '../../../models/weather.dart';
import '../../../services/notification_destination.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/lifestyle_evidence_checklist_section.dart';
import '../widgets/server_feature_unavailable_card.dart';
import '../widgets/tab_page_header.dart';

enum DetailFocusSource {
  notification,
  selection,
}

class DetailTab extends StatefulWidget {
  final TodayWeatherResponse today;
  final List<WeatherRecommendation> recommendations;
  final bool serverFeaturesAvailable;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onRetryData;
  final bool retrying;
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
    this.onRetryData,
    this.retrying = false,
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
        oldWidget.serverFeaturesAvailable != widget.serverFeaturesAvailable ||
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
        alignment: 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final focusedTypes = widget.focusLifestyleType == null
        ? lifestyleTypesForNotificationTopic(widget.focusTopic)
        : {widget.focusLifestyleType!};
    final focusLabel = switch (widget.focusSource) {
      DetailFocusSource.notification => '알림에서 확인한 항목',
      DetailFocusSource.selection => '선택한 항목의 근거',
    };
    return RefreshIndicator(
      color: WeatherCareTheme.primary,
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        key: const ValueKey('detail-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabPageHeader(
              eyebrow: 'DETAIL',
              title: '자세히보기',
              subtitle: '항목별로 자세한 정보를 확인해요',
              icon: Icons.query_stats_rounded,
            ),
            const SizedBox(height: 18),
            if (widget.serverFeaturesAvailable)
              LifestyleEvidenceChecklistSection(
                key: _evidenceSectionKey,
                messages: widget.today.lifestyleMessages,
                dataStatusMessages: widget.today.dataStatusMessages,
                focusedTypes: focusedTypes,
                focusLabel: focusLabel,
                focusedItemKey:
                    focusedTypes.isEmpty ? null : _focusedEvidenceKey,
                missingFocusMessage:
                    widget.focusSource == DetailFocusSource.notification
                        ? '이 알림과 연결된 근거가 현재 자료에 없어요.'
                        : '선택한 항목의 근거가 현재 자료에 없어요.',
                onRetryMissingData: widget.onRetryData,
                retrying: widget.retrying,
              )
            else
              ServerFeatureUnavailableCard(
                key: _evidenceSectionKey,
                icon: Icons.fact_check_outlined,
                title: '근거와 자료',
                onRetry: widget.onRetryData,
                retrying: widget.retrying,
              ),
          ],
        ),
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
