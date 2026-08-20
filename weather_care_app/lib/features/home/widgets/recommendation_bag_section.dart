import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../theme/recommendation_theme.dart';
import '../../../theme/weather_theme.dart';
import 'home_section_header.dart';

class RecommendationBagSection extends StatefulWidget {
  final String regionName;
  final List<WeatherRecommendation> recommendations;
  final ValueChanged<RecommendationType> onDetail;

  const RecommendationBagSection({
    super.key,
    required this.regionName,
    required this.recommendations,
    required this.onDetail,
  });

  @override
  State<RecommendationBagSection> createState() =>
      _RecommendationBagSectionState();
}

class _RecommendationBagSectionState extends State<RecommendationBagSection> {
  final Map<RecommendationType, bool> _checked = {};

  @override
  Widget build(BuildContext context) {
    final visible = widget.recommendations.where((r) => r.recommended).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            icon: Icons.work_outline_rounded,
            title: '오늘의 가방',
            subtitle: '${widget.regionName}에서 오늘 필요한 것만 모았어요',
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            const _EmptyBag()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = visible.length.clamp(1, 3);
                const spacing = 8.0;
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * spacing) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final recommendation in visible)
                      SizedBox(
                        width: itemWidth,
                        height: 196,
                        child: _BagItem(
                          key: ValueKey(
                            'bag-item-${recommendation.type.apiName.toLowerCase()}',
                          ),
                          recommendation: recommendation,
                          checked: _checked[recommendation.type] == true,
                          onToggle: () {
                            setState(() {
                              _checked[recommendation.type] =
                                  !(_checked[recommendation.type] == true);
                            });
                          },
                          onDetail: () => widget.onDetail(recommendation.type),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.touch_app_outlined,
                size: 16,
                color: WeatherCareTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '카드를 누르면 오늘 챙긴 항목으로 표시돼요',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BagItem extends StatelessWidget {
  final WeatherRecommendation recommendation;
  final bool checked;
  final VoidCallback onToggle;
  final VoidCallback onDetail;

  const _BagItem({
    super.key,
    required this.recommendation,
    required this.checked,
    required this.onToggle,
    required this.onDetail,
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
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 48,
                      height: 48,
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
                      child: Icon(
                        checked ? Icons.check_rounded : type.icon,
                        color: checked ? Colors.white : type.accentColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    type.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: WeatherCareTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.statusLabel,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: WeatherCareTheme.textSecondary,
                      fontSize: 10.5,
                      height: 1.3,
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
                      checked ? '챙겼어요' : '챙길게요',
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
              '오늘은 특별히 챙길 준비물이 없어요',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
