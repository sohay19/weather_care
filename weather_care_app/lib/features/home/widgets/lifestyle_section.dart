import 'package:flutter/material.dart';
import '../../../models/lifestyle_message.dart';

class LifestyleSection extends StatelessWidget {
  final List<LifestyleMessage> messages;

  const LifestyleSection({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('생활 날씨', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (messages.isEmpty) const Text('오늘은 특별한 생활 메시지가 없습니다.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: messages
                  .map((m) => Chip(label: Text(m.title)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

