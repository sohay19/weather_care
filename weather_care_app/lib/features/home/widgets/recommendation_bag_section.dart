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
  final ValueChanged<RecommendationType> onDetail;
  final PreparationChecklistRepository checklistRepository;
  final DateTime Function()? now;

  const RecommendationBagSection({
    super.key,
    required this.regionName,
    required this.recommendations,
    this.briefing,
    this.briefingTimeline = const [],
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

  DateTime get _now => (widget.now ?? DateTime.now)();

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
      if (intended == null) {
        final first = widget.briefingTimeline.first;
        final from = DateTime.tryParse(first.validFrom);
        final until = DateTime.tryParse(first.validUntil);
        if (from != null &&
            until != null &&
            from.isBefore(until) &&
            briefingStartsWithinClockSkew(from, now)) {
          intended = first.recommendedItems;
          description = first.copy.medium;
        }
      }
      intended ??= const [];
    } else if (widget.briefing != null) {
      final from = DateTime.tryParse(widget.briefing!.validFrom);
      final until = DateTime.tryParse(widget.briefing!.validUntil);
      final active = from != null &&
          until != null &&
          from.isBefore(until) &&
          (!now.isBefore(from) || briefingStartsWithinClockSkew(from, now)) &&
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
      if (visible.length == 3) break;
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
    final visible = _visibleRecommendations();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
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
                final columns = visible.length.clamp(1, 3);
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * spacing) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final recommendation in visible)
                      SizedBox(
                        width: itemWidth,
                        height: 178,
                        child: _BagItem(
                          key: ValueKey(
                            'bag-item-${recommendation.type.apiName.toLowerCase()}',
                          ),
                          recommendation: recommendation,
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
        ],
      ),
    );
  }
}

class _BagItem extends StatelessWidget {
  final WeatherRecommendation recommendation;
  final bool checked;
  final VoidCallback? onToggle;
  final String? pendingLabel;
  final VoidCallback onDetail;

  const _BagItem({
    super.key,
    required this.recommendation,
    required this.checked,
    required this.onToggle,
    required this.onDetail,
    this.pendingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final type = recommendation.type;

    return Material(
      color:
          checked ? type.accentColor.withValues(alpha: 0.13) : type.softColor,
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
                        color: checked ? type.accentColor : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: type.accentColor.withValues(alpha: 0.14),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: checked
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 24,
                            )
                          : Center(
                              child: PreparationIcon(
                                type: type,
                                color: type.accentColor,
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
                    style: const TextStyle(
                      color: WeatherCareTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: checked ? type.accentColor : Colors.white,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      pendingLabel ?? (checked ? '챙겼어요' : '챙길게요'),
                      maxLines: 1,
                      style: TextStyle(
                        color: checked ? Colors.white : type.accentColor,
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
                    foregroundColor: type.accentColor,
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
        color: WeatherCareTheme.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(
              Icons.check_rounded,
              color: WeatherCareTheme.primaryDeep,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
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
