import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../models/weather.dart';
import '../../../theme/recommendation_theme.dart';
import '../../../theme/weather_theme.dart';
import 'home_section_header.dart';
import 'preparation_icon.dart';

class TimelineSection extends StatefulWidget {
  final List<TimelineItem> items;
  final ValueChanged<RecommendationType> onDetail;

  const TimelineSection({
    super.key,
    required this.items,
    required this.onDetail,
  });

  @override
  State<TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<TimelineSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: _expanded ? '간단한 타임라인 접기' : '간단한 타임라인 펼치기',
            child: InkWell(
              key: const ValueKey('timeline-toggle'),
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: HomeSectionHeader(
                  icon: Icons.schedule_rounded,
                  title: '간단한 타임라인',
                  subtitle: '준비물이 필요한 시간과 날씨를 확인해요',
                  trailing: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: WeatherCareTheme.primaryDeep,
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Column(
                    key: const ValueKey('timeline-content'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      if (widget.items.isEmpty)
                        Text(
                          '표시할 타임라인이 없어요',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        for (var index = 0;
                            index < widget.items.length;
                            index++)
                          _TimelineItemView(
                            item: widget.items[index],
                            isLast: index == widget.items.length - 1,
                            onDetail: widget.onDetail,
                          ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TimelineItemView extends StatelessWidget {
  final TimelineItem item;
  final bool isLast;
  final ValueChanged<RecommendationType> onDetail;

  const _TimelineItemView({
    required this.item,
    required this.isLast,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final recommendations =
        item.recommendations.where((item) => item.recommended).toList();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: recommendations.isEmpty
                        ? WeatherCareTheme.surfaceMuted
                        : WeatherCareTheme.primarySoft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: recommendations.isEmpty
                          ? WeatherCareTheme.outline
                          : WeatherCareTheme.primaryBorder,
                    ),
                  ),
                  child: Text(
                    item.timeLabel,
                    style: TextStyle(
                      color: recommendations.isEmpty
                          ? WeatherCareTheme.textSecondary
                          : WeatherCareTheme.primaryDeep,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: WeatherCareTheme.primaryBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: WeatherCareTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: WeatherCareTheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.stateLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.detail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: WeatherCareTheme.textSecondary,
                          ),
                    ),
                    if (recommendations.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '이 시간에 필요해요',
                        style: WeatherCareTheme.microTextStyle.copyWith(
                          color: WeatherCareTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final recommendation in recommendations)
                            Semantics(
                              button: true,
                              excludeSemantics: true,
                              label: '${recommendation.type.label} 근거 보기',
                              child: Material(
                                color: recommendation.type.softColor,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  key: ValueKey(
                                    'timeline-detail-${item.timeLabel}-'
                                    '${recommendation.type.apiName.toLowerCase()}',
                                  ),
                                  onTap: () => onDetail(recommendation.type),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        PreparationIcon(
                                          type: recommendation.type,
                                          size: 14,
                                          color:
                                              recommendation.type.accentColor,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          recommendation.type.label,
                                          style: TextStyle(
                                            fontFamily:
                                                WeatherCareTheme.fontMona,
                                            color:
                                                recommendation.type.accentColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 1),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 14,
                                          color:
                                              recommendation.type.accentColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
