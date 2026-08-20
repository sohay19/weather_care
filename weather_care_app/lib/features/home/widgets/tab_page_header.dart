import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

class TabPageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onRefresh;

  const TabPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: WeatherCareTheme.primarySoft,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: WeatherCareTheme.primaryDeep, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: WeatherCareTheme.primaryDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (onRefresh != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: '날씨 새로고침',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 21),
          ),
        ],
      ],
    );
  }
}
