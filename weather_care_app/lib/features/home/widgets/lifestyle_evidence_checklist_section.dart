import 'package:flutter/material.dart';

import '../../../models/lifestyle_message.dart';
import '../../../theme/weather_theme.dart';
import 'home_section_header.dart';
import 'missing_data_retry.dart';

class LifestyleEvidenceChecklistSection extends StatelessWidget {
  final List<LifestyleMessage> messages;
  final List<WeatherMessagePart> dataStatusMessages;
  final Set<LifestyleMessageType> focusedTypes;
  final String? focusLabel;
  final Key? focusedItemKey;
  final String? missingFocusMessage;
  final Future<void> Function()? onRetryMissingData;
  final bool retrying;
  final int focusRequestId;
  final Widget? leadingEvidence;

  const LifestyleEvidenceChecklistSection({
    super.key,
    required this.messages,
    required this.dataStatusMessages,
    this.focusedTypes = const {},
    this.focusLabel,
    this.focusedItemKey,
    this.missingFocusMessage,
    this.onRetryMissingData,
    this.retrying = false,
    this.focusRequestId = 0,
    this.leadingEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final visibleMessages = messages
        .where((message) =>
            message.title.trim().isNotEmpty ||
            message.parts.any((part) => part.text.trim().isNotEmpty))
        .toList(growable: false);
    final orderedMessages = [
      ...visibleMessages
          .where((message) => focusedTypes.contains(message.type)),
      ...visibleMessages
          .where((message) => !focusedTypes.contains(message.type)),
    ];
    final focusedIndex = orderedMessages.indexWhere(
      (message) => focusedTypes.contains(message.type),
    );
    final missingFocus = focusedTypes.isNotEmpty && focusedIndex < 0;
    final statuses = dataStatusMessages
        .where((part) =>
            part.text.trim().isNotEmpty &&
            !_isConfirmedNoEventStatus(part) &&
            !_isOffSeasonRoadIceStatus(part))
        .toList(growable: false);
    final groupedStatuses = <String, List<WeatherMessagePart>>{};
    for (final part in statuses) {
      (groupedStatuses[_dataStatusTitle(part)] ??= []).add(part);
    }
    final statusGroups = groupedStatuses.entries.toList(growable: false);

    return Container(
      key: const ValueKey('lifestyle-evidence-checklist'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.of(context).surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionHeader(
            icon: Icons.list_alt_sharp,
            title: '상세 자료',
            subtitle: '날씨 판단에 사용한 자료를 함께 확인해요',
          ),
          const SizedBox(height: 18),
          if (leadingEvidence != null) leadingEvidence!,
          if (missingFocus) ...[
            KeyedSubtree(
              key: focusedItemKey,
              child: Container(
                key: const ValueKey('detail-focus-unavailable'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WeatherCareTheme.of(context).surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  missingFocusMessage ?? '선택한 항목의 근거가 현재 자료에 없어요.',
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (orderedMessages.isEmpty && !missingFocus && statusGroups.isEmpty)
            const _EmptyLifestyleChecklist()
          else
            for (var index = 0; index < orderedMessages.length; index++) ...[
              WeatherEvidenceCard(
                key: ValueKey(
                    'evidence-${orderedMessages[index].type.apiName}-${orderedMessages[index].title}-$index'),
                message: orderedMessages[index],
                focused: index == focusedIndex,
                focusLabel: focusLabel,
                focusedItemKey: focusedItemKey,
                focusRequestId: focusRequestId,
              ),
              if (index < orderedMessages.length - 1)
                const SizedBox(height: 12),
            ],
          if (statusGroups.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (var index = 0; index < statusGroups.length; index++) ...[
              _DataStatusCard(
                key: ValueKey('evidence-status-${statusGroups[index].key}'),
                title: statusGroups[index].key,
                parts: statusGroups[index].value,
                onRetry: onRetryMissingData,
                retrying: retrying,
              ),
              if (index < statusGroups.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class WeatherEvidenceCard extends StatefulWidget {
  final LifestyleMessage message;
  final bool focused;
  final String? focusLabel;
  final Key? focusedItemKey;
  final int focusRequestId;
  final String? id;
  final String? title;
  final IconData? icon;
  final WeatherMessageRole summaryRole;
  final String? supportingLabel;
  final Widget? expandedFooter;

  const WeatherEvidenceCard({
    super.key,
    required this.message,
    this.focused = false,
    this.focusLabel,
    this.focusedItemKey,
    this.focusRequestId = 0,
    this.id,
    this.title,
    this.icon,
    this.summaryRole = WeatherMessageRole.appSuggestion,
    this.supportingLabel,
    this.expandedFooter,
  });

  @override
  State<WeatherEvidenceCard> createState() => _WeatherEvidenceCardState();
}

class _WeatherEvidenceCardState extends State<WeatherEvidenceCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.focused;
  }

  @override
  void didUpdateWidget(covariant WeatherEvidenceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusRequestId != widget.focusRequestId ||
        oldWidget.focused != widget.focused) {
      _expanded = widget.focused;
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final id = widget.id ?? message.type.apiName.toLowerCase();
    final title = widget.title ?? message.type.title;
    final focused = widget.focused;
    final focusLabel = widget.focusLabel;
    final focusedItemKey = widget.focusedItemKey;
    final parts = message.parts
        .where((part) => part.text.trim().isNotEmpty)
        .toList(growable: false);
    final suggestions = parts
        .where((part) => part.role == WeatherMessageRole.appSuggestion)
        .toList(growable: false);
    final supporting = parts
        .where((part) => part.role != WeatherMessageRole.appSuggestion)
        .toList(growable: false);
    final action = suggestions.isEmpty ? message.title : suggestions.first.text;
    final validPeriod = _messageValidPeriod(parts);

    final card = AnimatedContainer(
      key: ValueKey(
        'lifestyle-evidence-set-$id',
      ),
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: focused
            ? WeatherCareTheme.of(context).primarySoft.withValues(alpha: 0.55)
            : WeatherCareTheme.of(context).surfaceSubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused
              ? WeatherCareTheme.of(context).primary
              : WeatherCareTheme.of(context).outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (focused && focusLabel != null) ...[
            Text(
              focusLabel,
              style: WeatherCareTheme.of(context).microTextStyle.copyWith(
                    color: WeatherCareTheme.of(context).primaryDeep,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 7),
          ],
          InkWell(
            key: ValueKey('detail-evidence-toggle-$id'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: WeatherCareTheme.of(context).primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon ?? _lifestyleIcon(message.type),
                    size: 20,
                    color: WeatherCareTheme.of(context).primaryDeep,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: WeatherCareTheme.of(context).textPrimary,
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!_expanded &&
                          message.title.trim().isNotEmpty &&
                          message.title != title &&
                          message.title != action) ...[
                        const SizedBox(height: 2),
                        Text(message.title,
                            style: WeatherCareTheme.of(context).microTextStyle),
                      ],
                      if (validPeriod != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          validPeriod,
                          key: ValueKey(
                            'detail-valid-period-$id',
                          ),
                          style: WeatherCareTheme.of(context).microTextStyle,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: WeatherCareTheme.of(context).primaryDeep,
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          _MatchedDetail(
            icon: _roleIcon(widget.summaryRole),
            label: _roleSetLabel(widget.summaryRole),
            text: action,
            highlighted: widget.summaryRole == WeatherMessageRole.appSuggestion,
            muted: widget.summaryRole == WeatherMessageRole.dataStatus,
          ),
          if (_expanded) ...[
            if (supporting.isEmpty) ...[
              const SizedBox(height: 8),
              const _MatchedDetail(
                icon: Icons.info_outline_rounded,
                label: '근거와 자료',
                text: '이 항목에 연결된 추가 근거 자료가 없어요.',
                muted: true,
              ),
            ] else
              for (final part in supporting) ...[
                const SizedBox(height: 8),
                _MatchedDetail(
                  icon: _roleIcon(part.role),
                  label: widget.supportingLabel ?? _roleSetLabel(part.role),
                  text: part.text,
                  source: _partSource(part),
                  muted: part.role == WeatherMessageRole.dataStatus,
                ),
              ],
            if (widget.expandedFooter != null) ...[
              const SizedBox(height: 10),
              widget.expandedFooter!,
            ],
          ],
        ],
      ),
    );
    if (!focused) return card;
    return KeyedSubtree(
      key: focusedItemKey,
      child: Container(
        key: const ValueKey('detail-focused-evidence'),
        child: card,
      ),
    );
  }
}

class _MatchedDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final String? source;
  final bool muted;
  final bool highlighted;

  const _MatchedDetail({
    required this.icon,
    required this.label,
    required this.text,
    this.source,
    this.muted = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: highlighted ? const ValueKey('detail-check-action') : null,
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: muted
            ? WeatherCareTheme.of(context).surfaceMuted
            : highlighted
                ? WeatherCareTheme.of(context).primarySoft
                : WeatherCareTheme.of(context).surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: WeatherCareTheme.of(context).primaryDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: WeatherCareTheme.of(context).microTextStyle.copyWith(
                        color: WeatherCareTheme.of(context).primaryDeep,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(text, style: Theme.of(context).textTheme.bodySmall),
                if (source != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    source!,
                    key: ValueKey('detail-provider-$source'),
                    style: WeatherCareTheme.of(context).microTextStyle.copyWith(
                          color: WeatherCareTheme.of(context).textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
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

class _DataStatusCard extends StatefulWidget {
  final String title;
  final List<WeatherMessagePart> parts;
  final Future<void> Function()? onRetry;
  final bool retrying;

  const _DataStatusCard({
    super.key,
    required this.title,
    required this.parts,
    this.onRetry,
    this.retrying = false,
  });

  @override
  State<_DataStatusCard> createState() => _DataStatusCardState();
}

class _DataStatusCardState extends State<_DataStatusCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('detail-data-status-${widget.title}'),
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: WeatherCareTheme.of(context).surfaceSubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WeatherCareTheme.of(context).outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: ValueKey('detail-data-status-toggle-${widget.title}'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: WeatherCareTheme.of(context).primaryDeep,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(_expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded),
              ],
            ),
          ),
          if (_expanded)
            for (final part in widget.parts) ...[
              const SizedBox(height: 7),
              Text(part.text, style: Theme.of(context).textTheme.bodySmall),
            ],
          if (_expanded &&
              widget.onRetry != null &&
              widget.parts.any((part) => part.retryable)) ...[
            const SizedBox(height: 10),
            MissingDataRetry(
              message: '서버에 저장된 ${widget.title} 자료를 다시 받아올 수 있어요. '
                  '외부 자료는 서버가 다음 수집 주기에 다시 확인해요.',
              retryKey: 'detail-data-retry-${widget.title}',
              retryTooltip: '서버의 ${widget.title} 자료 다시 받기',
              onRetry: widget.onRetry!,
              retrying: widget.retrying,
            ),
          ],
        ],
      ),
    );
  }
}

String _dataStatusTitle(WeatherMessagePart part) {
  final itemTitle = part.itemTitle?.trim();
  if (itemTitle != null && itemTitle.isNotEmpty) return itemTitle;
  return switch (part.source) {
    'AIRKOREA' => '대기질',
    'KMA_LIVING_INDEX_V5' => '자외선지수',
    '기상청 관측분석자료·기상청 레이더' => '현재 강수',
    '기상청 특보정보' => '기상특보',
    '기상청 도로살얼음 발생 가능 정보' => '블랙아이스(도로살얼음)',
    '국가교통정보센터 돌발상황정보' => '도로 통제',
    _ => '자료 상태',
  };
}

bool _isOffSeasonRoadIceStatus(WeatherMessagePart part) =>
    part.text.contains('블랙아이스') && part.text.contains('제공기간이 아닌');

bool _isConfirmedNoEventStatus(WeatherMessagePart part) =>
    !part.retryable &&
    (part.text.contains('현재 강수가 확인되지 않았어요') ||
        (part.text.contains('활성 도로 통제가') && part.text.contains('없어요')));

class _EmptyLifestyleChecklist extends StatelessWidget {
  const _EmptyLifestyleChecklist();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WeatherCareTheme.of(context).surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '현재 예보에서 안내할 체크 항목과 근거가 없어요.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: WeatherCareTheme.of(context).textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _roleSetLabel(WeatherMessageRole role) => switch (role) {
      WeatherMessageRole.appSuggestion => '체크할 일',
      WeatherMessageRole.internalPossibility => '판단 근거',
      WeatherMessageRole.calculatedFact => '계산 근거',
      WeatherMessageRole.officialFact => '사용한 자료',
      WeatherMessageRole.dataStatus => '자료 상태',
    };

IconData _roleIcon(WeatherMessageRole role) => switch (role) {
      WeatherMessageRole.appSuggestion => Icons.check_circle_outline_rounded,
      WeatherMessageRole.internalPossibility => Icons.psychology_alt_outlined,
      WeatherMessageRole.calculatedFact => Icons.calculate_outlined,
      WeatherMessageRole.officialFact => Icons.menu_book_outlined,
      WeatherMessageRole.dataStatus => Icons.info_outline_rounded,
    };

String? _partSource(WeatherMessagePart part) {
  final source = part.source?.trim();
  return source == null || source.isEmpty ? null : _sourceLabel(source);
}

String _sourceLabel(String source) {
  final normalized = source.toUpperCase();
  if (source.replaceAll(' ', '').contains('날씨챙겨') ||
      normalized.contains('APP')) {
    return '앱 자체 분석';
  }
  if (normalized.contains('KMA_LIVING') || source.contains('생활기상')) {
    return '기상청 생활기상지수';
  }
  if (normalized.contains('AIRKOREA')) return '에어코리아 관측자료';
  if (normalized.contains('KMA')) return '기상청 자료';
  if (normalized.contains('ITS')) return '국가교통정보센터 자료';
  return source;
}

String? _messageValidPeriod(List<WeatherMessagePart> parts) {
  for (final part in [
    ...parts.where((part) => part.role == WeatherMessageRole.appSuggestion),
    ...parts.where((part) => part.role != WeatherMessageRole.appSuggestion),
  ]) {
    final period = _validPeriodLabel(part.validFrom, part.validUntil);
    if (period != null) return period;
  }
  return null;
}

String? _validPeriodLabel(String? from, String? until) {
  DateTime? parse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String format(DateTime parsed) {
    final korea = parsed.isUtc ? parsed.add(const Duration(hours: 9)) : parsed;
    return '${korea.month}월 ${korea.day}일 '
        '${korea.hour.toString().padLeft(2, '0')}시'
        '${korea.minute == 0 ? '' : ' ${korea.minute.toString().padLeft(2, '0')}분'}';
  }

  final startAt = parse(from);
  final endAt = parse(until);
  if (startAt == null) {
    return endAt == null ? null : '${format(endAt)}까지 유효';
  }
  if (endAt == null) return '${format(startAt)}부터 유효';

  final duration = endAt.difference(startAt);
  final hours = duration > Duration.zero
      ? (duration.inMilliseconds / const Duration(hours: 1).inMilliseconds)
          .ceil()
      : null;
  final durationLabel = hours == null ? '' : ' (${hours}H)';
  return '${format(startAt)}~${format(endAt)} 유효$durationLabel';
}

IconData _lifestyleIcon(LifestyleMessageType type) => switch (type) {
      LifestyleMessageType.rainGearUseful => Icons.umbrella_outlined,
      LifestyleMessageType.strongSunExposure => Icons.wb_sunny_outlined,
      LifestyleMessageType.outerwearUseful => Icons.checkroom_rounded,
      LifestyleMessageType.maskUseful => Icons.masks_outlined,
      LifestyleMessageType.ozoneCaution => Icons.air_rounded,
      LifestyleMessageType.hydrationImportant => Icons.local_drink_outlined,
      LifestyleMessageType.sunscreenUseful => Icons.spa_outlined,
      LifestyleMessageType.snowTravelCaution => Icons.ac_unit_rounded,
      LifestyleMessageType.veryHotAndHumid => Icons.thermostat_rounded,
      LifestyleMessageType.coolerThanTemperature => Icons.air_rounded,
      LifestyleMessageType.largeTemperatureSwing =>
        Icons.device_thermostat_outlined,
      LifestyleMessageType.outdoorCaution => Icons.air_rounded,
      LifestyleMessageType.rainBreakWindow => Icons.schedule_rounded,
      LifestyleMessageType.bestOutingWindow => Icons.schedule_rounded,
      LifestyleMessageType.petWalkWindow => Icons.pets_outlined,
      LifestyleMessageType.wetRoadCaution => Icons.directions_car_outlined,
      LifestyleMessageType.laundryPickupDue =>
        Icons.local_laundry_service_outlined,
      LifestyleMessageType.windowCloseSoon => Icons.window_outlined,
      LifestyleMessageType.rapidTemperatureDrop =>
        Icons.thermostat_auto_outlined,
      LifestyleMessageType.nightWeatherCheck => Icons.bedtime_outlined,
      LifestyleMessageType.blackIceCaution => Icons.warning_amber_rounded,
      LifestyleMessageType.commuteRouteCaution => Icons.alt_route_rounded,
      LifestyleMessageType.unknown => Icons.info_outline_rounded,
    };
