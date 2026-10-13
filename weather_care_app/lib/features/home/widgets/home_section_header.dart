import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

class HomeSectionHeader extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const HomeSectionHeader({
    super.key,
    this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
    );
    final subtitleStyle = TextStyle(
      color: WeatherCareTheme.of(context).textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: WeatherCareTheme.of(context).primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon,
                size: 21, color: WeatherCareTheme.of(context).primaryDeep),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              const SizedBox(height: 2),
              Text(subtitle, style: subtitleStyle),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
