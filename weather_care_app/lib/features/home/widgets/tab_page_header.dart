import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

class TabPageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData? icon;
  final bool showRegionMenu;
  final VoidCallback? onOpenRegionMenu;
  final bool singleLineTitle;
  final Widget? trailing;
  final Widget? subtitleTrailing;

  const TabPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.icon,
    this.showRegionMenu = false,
    this.onOpenRegionMenu,
    this.singleLineTitle = false,
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
        ],
        Expanded(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: showRegionMenu ? 50 : 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eyebrow,
                              style: WeatherCareTheme.of(context)
                                  .specialLabelStyle,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(
                                  child: singleLineTitle
                                      ? FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            softWrap: false,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall,
                                          ),
                                        )
                                      : Text(title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall),
                                ),
                                if (trailing != null) trailing!,
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (showRegionMenu)
                        Positioned(
                          left: 10,
                          bottom: -4,
                          child: Icon(
                            Icons.menu_rounded,
                            size: 24,
                            color: WeatherCareTheme.of(context).primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 50),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(subtitle,
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                        if (subtitleTrailing != null) subtitleTrailing!,
                      ],
                    ),
                  ),
                ],
              ),
              if (showRegionMenu)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 44,
                  child: Tooltip(
                    message: '구역 선택 및 구역 추가',
                    child: Semantics(
                      button: true,
                      enabled: onOpenRegionMenu != null,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          key: const ValueKey('main-region-menu'),
                          onTap: onOpenRegionMenu,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
