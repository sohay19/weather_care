import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../../../models/lifestyle_message.dart';
import '../../../services/notification_destination.dart';
import '../../../theme/weather_theme.dart';
import '../weather_data_phase.dart';
import 'evidence_focus.dart';
import '../widgets/lifestyle_evidence_checklist_section.dart';
import '../widgets/server_feature_unavailable_card.dart';
import '../widgets/weather_data_notice.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/weather_card.dart';

class TodayTab extends StatefulWidget {
  final TodayWeatherResponse today;
  final WeatherDataPhase dataPhase;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onRetryData;
  final bool retrying;
  final Widget? advertisement;
  final bool serverFeaturesAvailable;
  final NotificationTopic? focusTopic;
  final LifestyleMessageType? focusLifestyleType;
  final DetailFocusSource focusSource;
  final int focusRequestId;

  const TodayTab({
    super.key,
    required this.today,
    this.dataPhase = WeatherDataPhase.ready,
    required this.onRefresh,
    this.onRetryData,
    this.retrying = false,
    this.advertisement,
    this.serverFeaturesAvailable = true,
    this.focusTopic,
    this.focusLifestyleType,
    this.focusSource = DetailFocusSource.notification,
    this.focusRequestId = 0,
  });

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  final _focusedEvidenceKey = GlobalKey();
  final _evidenceSectionKey = GlobalKey();
  bool _focusScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleFocusScroll();
  }

  @override
  void didUpdateWidget(covariant TodayTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusRequestId != widget.focusRequestId ||
        oldWidget.dataPhase != widget.dataPhase ||
        oldWidget.serverFeaturesAvailable != widget.serverFeaturesAvailable ||
        oldWidget.today != widget.today) {
      _focusScheduled = false;
      _scheduleFocusScroll();
    }
  }

  void _scheduleFocusScroll() {
    if (_focusScheduled ||
        (widget.focusLifestyleType == null &&
            lifestyleTypesForNotificationTopic(widget.focusTopic).isEmpty)) {
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
    final focusLabel = widget.focusSource == DetailFocusSource.selection
        ? '선택한 항목의 근거'
        : '알림에서 확인한 항목';
    return RefreshIndicator(
      color: WeatherCareTheme.of(context).primary,
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        key: const ValueKey('today-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TabPageHeader(
              eyebrow: 'TODAY',
              title: '오늘 하루',
              subtitle: '현재 날씨를 자세히 확인해요',
              icon: Icons.schedule_rounded,
            ),
            const SizedBox(height: 18),
            if (widget.dataPhase != WeatherDataPhase.ready) ...[
              WeatherDataNotice(phase: widget.dataPhase, subject: '오늘 날씨'),
              const SizedBox(height: 16),
            ],
            WeatherInfoCard(
              current: widget.today.current,
              livingIndices: widget.today.livingIndices,
              showCurrentSummary: false,
              dataPhase: widget.dataPhase,
              sunriseAt: widget.today.sunriseAt,
              sunsetAt: widget.today.sunsetAt,
              onRetryMissingData: widget.onRetryData,
              retrying: widget.retrying,
            ),
            if (widget.advertisement != null) ...[
              const SizedBox(height: 16),
              widget.advertisement!,
            ],
            const SizedBox(height: 16),
            if (widget.dataPhase == WeatherDataPhase.loading)
              const Center(child: CircularProgressIndicator())
            else if (widget.serverFeaturesAvailable)
              LifestyleEvidenceChecklistSection(
                key: _evidenceSectionKey,
                messages: widget.today.lifestyleMessages,
                dataStatusMessages: widget.today.dataStatusMessages,
                focusedTypes: focusedTypes,
                focusLabel: focusLabel,
                focusedItemKey:
                    focusedTypes.isEmpty ? null : _focusedEvidenceKey,
                focusRequestId: widget.focusRequestId,
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
