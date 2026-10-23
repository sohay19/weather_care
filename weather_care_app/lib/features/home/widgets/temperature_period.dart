import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

class TemperaturePeriod extends StatelessWidget {
  final String label;
  final String value;
  final bool isPast;
  final bool isFuture;
  final Color? backgroundColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const TemperaturePeriod({
    super.key,
    required this.label,
    required this.value,
    this.isPast = false,
    this.isFuture = false,
    this.backgroundColor,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor ??
            (isFuture
                ? WeatherCareTheme.of(context)
                    .primarySoft
                    .withValues(alpha: 0.35)
                : WeatherCareTheme.of(context).surface.withValues(alpha: 0.65)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: labelStyle ??
                  WeatherCareTheme.of(context).microTextStyle.copyWith(
                        color: isPast
                            ? WeatherCareTheme.of(context).textSecondary
                            : null,
                        fontWeight: FontWeight.w700,
                      ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: valueStyle ??
                    TextStyle(
                      color: isPast
                          ? WeatherCareTheme.of(context).textSecondary
                          : null,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
