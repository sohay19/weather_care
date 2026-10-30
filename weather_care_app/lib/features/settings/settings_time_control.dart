import 'package:flutter/material.dart';

import '../../theme/weather_theme.dart';

/// 알림 시각과 출퇴근 시간 구간에 사용하는 공통 설정 행.
class SettingsTimeControl extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const SettingsTimeControl(
      {super.key,
      required this.label,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = WeatherCareTheme.of(context);
    final stacked = MediaQuery.textScalerOf(context).scale(16) > 22;
    final heading = Row(children: [
      Icon(Icons.alarm_rounded, color: colors.primary),
      const SizedBox(width: 12),
      Expanded(
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]);
    final time = Text(value,
        textAlign: TextAlign.right,
        style: TextStyle(
            color: colors.primaryDeep,
            fontSize: 16,
            fontWeight: FontWeight.w900));
    final arrow =
        Icon(Icons.chevron_right_rounded, color: colors.textSecondary);
    return Opacity(
      opacity: onTap == null ? 0.46 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(18)),
          child: stacked
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  heading,
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: time),
                    const SizedBox(width: 4),
                    arrow
                  ]),
                ])
              : Row(children: [
                  Expanded(child: heading),
                  time,
                  const SizedBox(width: 4),
                  arrow
                ]),
        ),
      ),
    );
  }
}
