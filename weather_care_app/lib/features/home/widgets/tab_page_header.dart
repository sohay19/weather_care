import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

class TabPageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget? subtitleTrailing;

  const TabPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.icon,
    this.trailing,
    this.subtitleTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: WeatherCareTheme.of(context).primarySoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: WeatherCareTheme.of(context).primaryDeep,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: WeatherCareTheme.of(context).specialLabelStyle,
              ),
              const SizedBox(height: 2),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Row(children: [
                Flexible(
                    child: Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall)),
                if (subtitleTrailing != null) subtitleTrailing!,
              ]),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
