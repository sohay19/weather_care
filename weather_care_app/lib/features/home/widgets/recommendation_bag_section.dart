import 'dart:async';
import 'package:flutter/material.dart';

import '../../../models/briefing_time.dart';
import '../../../models/recommendation.dart';
import '../../../models/weather.dart';
import '../../../services/preparation_checklist_repository.dart';
import '../../../theme/recommendation_theme.dart';
import '../../../theme/weather_theme.dart';
import 'home_section_header.dart';
import 'preparation_icon.dart';

class RecommendationBagSection extends StatefulWidget {
  final String regionName;
  final List<WeatherRecommendation> recommendations;
  final CanonicalBriefing? briefing;
  final List<BriefingTimelineEntry> briefingTimeline;
  final String? generatedAt;
  final DateTime? receivedAt;
  final ValueChanged<RecommendationType> onDetail;
  final PreparationChecklistRepository checklistRepository;
  final DateTime Function()? now;

  const RecommendationBagSection({
    super.key,
    required this.regionName,
    required this.recommendations,
    this.briefing,
    this.briefingTimeline = const [],
    this.generatedAt,
    this.receivedAt,
    required this.onDetail,
    this.checklistRepository = const PreparationChecklistRepository(),
    this.now,
  });

  @override
  State<RecommendationBagSection> createState() =>
      _RecommendationBagSectionState();
}

class _RecommendationBagSectionState extends State<RecommendationBagSection>
    with WidgetsBindingObserver {
  Set<RecommendationType> _checked = {};
  String? _date;
  Timer? _midnightTimer;
  Timer? _briefingTimer;
  int _loadRevision = 0;
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;
  bool _expanded = false;

  DateTime get _now => responseNow(
        (widget.now ?? DateTime.now)(),
        generatedAt: widget.generatedAt,
        receivedAt: widget.receivedAt,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDate();
    _scheduleBriefingBoundary();
  }

  @override
  void didUpdateWidget(covariant RecommendationBagSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.regionName != widget.regionName) _expanded = false;
    _refreshDate();
    _scheduleBriefingBoundary();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDate(retry: _loadFailed);
      _scheduleBriefingBoundary();
      setState(() {});
    } else {
      _briefingTimer?.cancel();
    }
  }

  void _scheduleBriefingBoundary() {
    _briefingTimer?.cancel();
    final now = _now;
    final boundaries = <DateTime>[];
    for (final entry in widget.briefingTimeline) {
      for (final raw in [entry.validFrom, entry.validUntil]) {
        final value = DateTime.tryParse(raw);
        if (value != null && value.isAfter(now)) boundaries.add(value);
      }
    }
    if (widget.briefingTimeline.isEmpty && widget.briefing != null) {
      for (final raw in [
        widget.briefing!.validFrom,
        widget.briefing!.validUntil,
      ]) {
        final value = DateTime.tryParse(raw);
        if (value != null && value.isAfter(now)) boundaries.add(value);
      }
    }
    if (boundaries.isEmpty) return;
    boundaries.sort();
    final remaining = boundaries.first.difference(now);
    final delay = remaining > const Duration(minutes: 1)
        ? const Duration(minutes: 1)
        : remaining;
    _briefingTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleBriefingBoundary();
    });
  }

  List<WeatherRecommendation> _visibleRecommendations() {
    final now = _now;
    List<String>? intended;
    String description = '';
    if (widget.briefingTimeline.isNotEmpty) {
      for (final entry in widget.briefingTimeline) {
        final from = DateTime.tryParse(entry.validFrom);
        final until = DateTime.tryParse(entry.validUntil);
        if (from != null &&
            until != null &&
            !now.isBefore(from) &&
            now.isBefore(until)) {
          intended = entry.recommendedItems;
          description = entry.copy.medium;
          break;
        }
      }
      intended ??= const [];
    } else if (widget.briefing != null) {
      final from = DateTime.tryParse(widget.briefing!.validFrom);
      final until = DateTime.tryParse(widget.briefing!.validUntil);
      final active = from != null &&
          until != null &&
          from.isBefore(until) &&
          !now.isBefore(from) &&
          now.isBefore(until);
      intended = active ? widget.briefing!.recommendedItems : const [];
      description = widget.briefing!.copy.medium;
    }
    if (intended == null) {
      return widget.recommendations.where((item) => item.recommended).toList();
    }

    final existing = {
      for (final item in widget.recommendations) item.type: item,
    };
    final visible = <WeatherRecommendation>[];
    final seen = <RecommendationType>{};
    for (final raw in intended) {
      final type = recommendationTypeFromApiName(raw);
      if (type == null || !seen.add(type)) continue;
      final item = existing[type];
      visible.add(item?.copyWith(recommended: true) ??
          WeatherRecommendation(
            type: type,
            recommended: true,
            priority: 100 - visible.length,
            title: type.title,
            description: description,
            notificationEligible: false,
          ));
    }
    return visible;
  }

  void _refreshDate({bool retry = false}) {
    final now = _now;
    final date = preparationDateInKorea(now);
    _midnightTimer?.cancel();
    _midnightTimer = Timer(untilPreparationMidnight(now), _refreshDate);
    if (_date == date && !retry) return;
    final revision = ++_loadRevision;
    setState(() {
      _date = date;
      _checked = {};
      _loading = true;
      _loadFailed = false;
    });
    unawaited(_restore(date, revision));
  }

  Future<void> _restore(String date, int revision) async {
    try {
      final checked = await widget.checklistRepository.load(date);
      if (!mounted || revision != _loadRevision) return;
      if (date != preparationDateInKorea(_now)) {
        _refreshDate();
        return;
      }
      setState(() {
        _checked = checked;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _toggle(RecommendationType type) async {
    if (_loading || _saving || _loadFailed) return;
    if (_date != preparationDateInKorea(_now)) {
      _refreshDate();
      return;
    }
    final date = _date!;
    final revision = _loadRevision;
    final previous = _checked;
    final updated = {...previous};
    if (!updated.remove(type)) updated.add(type);
    setState(() {
      _checked = updated;
      _saving = true;
    });
    try {
      await widget.checklistRepository.save(date, updated);
    } catch (_) {
      if (!mounted) return;
      if (revision == _loadRevision) setState(() => _checked = previous);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('체크 상태를 저장하지 못했어요.\n다시 눌러주세요')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        _refreshDate();
      }
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _briefingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = _visibleRecommendations();
    final visible = _expanded ? all : all.take(3).toList();
    final now = _now;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.of(context).surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionHeader(
            icon: Icons.playlist_add_check_rounded,
            title: 'Check List',
            subtitle: '외출 전 준비할 물건을 확인해요',
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            const _EmptyBag()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 6.0;
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final maxColumns = ((constraints.maxWidth + spacing) /
                        (100 * textScale + spacing))
                    .floor()
                    .clamp(1, 3);
                final columns = visible.length.clamp(1, maxColumns);
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * spacing) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final recommendation in visible)
                      SizedBox(
                        width: itemWidth,
                        height: 176 + (textScale - 1).clamp(0, 2) * 110,
                        child: _BagItem(
                          key: ValueKey(
                            'bag-item-${recommendation.type.apiName.toLowerCase()}',
                          ),
                          recommendation: recommendation,
                          now: now,
                          checked: _checked.contains(recommendation.type),
                          pendingLabel: _loading
                              ? '확인 중'
                              : _loadFailed
                                  ? '확인 필요'
                                  : null,
                          onToggle: _loading || _saving || _loadFailed
                              ? null
                              : () => _toggle(recommendation.type),
                          onDetail: () => widget.onDetail(recommendation.type),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (visible.isNotEmpty && _loadFailed)
            TextButton(
              onPressed: () => _refreshDate(retry: true),
              child: const Text('체크 상태를 불러오지 못했어요 · 다시 시도'),
            ),
          if (all.length > 3)
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(_expanded ? '접기' : '외 ${all.length - 3}개 더 보기'),
            ),
        ],
      ),
    );
  }
}

class _BagItem extends StatelessWidget {
  final WeatherRecommendation recommendation;
  final DateTime now;
  final bool checked;
  final VoidCallback? onToggle;
  final String? pendingLabel;
  final VoidCallback onDetail;

  const _BagItem({
    super.key,
    required this.recommendation,
    required this.now,
    required this.checked,
    required this.onToggle,
    required this.onDetail,
    this.pendingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final type = recommendation.type;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final startsAt = DateTime.tryParse(recommendation.validFrom ?? '');
    final futureStart = startsAt != null &&
        startsAt.isAfter(now.add(const Duration(minutes: 10)));
    final koreaStart = startsAt?.toUtc().add(const Duration(hours: 9));

    return Material(
      color: checked
          ? type.accentColor(context).withValues(alpha: 0.13)
          : type.softColor(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 9),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: checked
                            ? WeatherCareTheme.of(context).actionBackground
                            : WeatherCareTheme.of(context).surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: type
                                .accentColor(context)
                                .withValues(alpha: 0.14),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: checked
                          ? Icon(
                              Icons.check_rounded,
                              color: WeatherCareTheme.of(context).onPrimary,
                              size: 24,
                            )
                          : Center(
                              child: PreparationIcon(
                                type: type,
                                color: type.accentColor(context),
                                size: 34,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: WeatherCareTheme.of(context).textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (futureStart && koreaStart != null)
                    Text(
                      '${koreaStart.hour}시부터',
                      textAlign: TextAlign.center,
                      style: WeatherCareTheme.of(context).microTextStyle,
                    ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 32 * textScale.clamp(1, 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: checked
                          ? WeatherCareTheme.of(context).actionBackground
                          : WeatherCareTheme.of(context).surface,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      pendingLabel ?? (checked ? '챙겼어요' : '챙길게요'),
                      maxLines: 1,
                      style: TextStyle(
                        color: checked
                            ? WeatherCareTheme.of(context).onPrimary
                            : type.accentColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: -7,
                right: -7,
                child: IconButton(
                  key: ValueKey(
                    'bag-detail-${type.apiName.toLowerCase()}',
                  ),
                  onPressed: onDetail,
                  tooltip: '${type.label} 추천 이유 보기',
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(30, 30),
                    maximumSize: const Size(30, 30),
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    foregroundColor: type.accentColor(context),
                  ),
                  icon: const Icon(Icons.info_outline_rounded, size: 17),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBag extends StatelessWidget {
  const _EmptyBag();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: WeatherCareTheme.of(context).primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: WeatherCareTheme.of(context).surface,
            child: Icon(
              Icons.check_rounded,
              color: WeatherCareTheme.of(context).primaryDeep,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              '지금은 특별히 챙길 준비물이 없어요',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
