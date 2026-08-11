import 'package:flutter/material.dart';
import 'package:weather_care/models/recommendation.dart';
import '../../../models/weather.dart';

class TimelineSection extends StatelessWidget {
  final List<TimelineItem> items;

  const TimelineSection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('오늘 하루 타임라인', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...items.map(
              (item) => ListTile(
                dense: true,
                leading: Text(item.timeLabel),
                title: Text(item.stateLabel),
                subtitle: Text(item.detail),
                trailing: Wrap(
                  spacing: 6,
                  children: item.recommendations.map((r) => Chip(label: Text(r.type.title))).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

