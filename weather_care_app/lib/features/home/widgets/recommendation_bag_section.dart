import 'package:flutter/material.dart';
import '../../../models/recommendation.dart';

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
  State<RecommendationBagSection> createState() => _RecommendationBagSectionState();
}

class _RecommendationBagSectionState extends State<RecommendationBagSection> {
  final Map<RecommendationType, bool> _checked = {};

  @override
  Widget build(BuildContext context) {
    final visible = widget.recommendations.where((r) => r.recommended).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('오늘의 가방 · ${widget.regionName}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (visible.isEmpty) const Text('오늘은 특별히 챙길 준비물이 없습니다.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visible
                  .map(
                    (r) => InputChip(
                      avatar: Icon(r.type.icon, size: 18),
                      label: Text('${r.title}'),
                      selected: _checked[r.type] == true,
                      onSelected: (v) {
                        setState(() {
                          _checked[r.type] = v;
                        });
                      },
                      onPressed: () => widget.onDetail(r.type),
                      deleteIcon: const Icon(Icons.info_outline),
                      onDeleted: () => widget.onDetail(r.type),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
            Text('선택 항목은 하루 단위 로컬 상태로만 관리됩니다.', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

