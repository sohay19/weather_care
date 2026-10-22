import 'package:flutter/material.dart';
import '../../../theme/weather_theme.dart';

/// Week의 최저·최고처럼 라벨은 왼쪽, 굵은 값은 오른쪽에 표시한다.
class DataRangeTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const DataRangeTile(
      {super.key, required this.label, required this.value, this.icon});

  static Color backgroundColor(WeatherCarePalette palette) =>
      palette.brightness == Brightness.dark
          ? palette.surface
          : palette.primaryBorder;

  @override
  Widget build(BuildContext context) {
    final palette = WeatherCareTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
          color: backgroundColor(palette),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: palette.primaryDeep),
          const SizedBox(width: 4),
        ],
        Expanded(
            child: Text(label,
                style: palette.microTextStyle.copyWith(
                    color: palette.primaryDeep, fontWeight: FontWeight.w700))),
        Flexible(
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: palette.primaryDeep)))),
      ]),
    );
  }
}
