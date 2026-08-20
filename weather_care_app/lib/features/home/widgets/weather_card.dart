import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import 'home_section_header.dart';

class WeatherInfoCard extends StatelessWidget {
  final CurrentWeather current;

  const WeatherInfoCard({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _WeatherMetric(
        icon: Icons.device_thermostat_rounded,
        label: '체감',
        value: current.apparentTemperature == null
            ? '미지원'
            : '${current.apparentTemperature!.toStringAsFixed(1)}°',
      ),
      if (current.humidity != null)
        _WeatherMetric(
          icon: Icons.water_drop_outlined,
          label: '습도',
          value: '${current.humidity!.toStringAsFixed(0)}%',
        ),
      if (current.uvIndex != null)
        _WeatherMetric(
          icon: Icons.wb_sunny_outlined,
          label: '자외선',
          value: current.uvIndex!.toStringAsFixed(1),
        ),
      if (current.pm25 != null)
        _WeatherMetric(
          icon: Icons.blur_on_rounded,
          label: 'PM2.5',
          value: current.pm25.toString(),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionHeader(
            icon: Icons.query_stats_rounded,
            title: '상세 날씨',
            subtitle: '추천을 만든 근거 수치를 확인해요',
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${current.temperature.toStringAsFixed(1)}°',
                style: const TextStyle(
                  color: WeatherCareTheme.textPrimary,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  current.sky ?? '맑음',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: WeatherCareTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  Expanded(child: _MetricView(metric: metrics[index])),
                  if (index < metrics.length - 1)
                    const SizedBox(
                      height: 34,
                      child: VerticalDivider(width: 1),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricView extends StatelessWidget {
  final _WeatherMetric metric;

  const _MetricView({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(metric.icon, size: 17, color: WeatherCareTheme.primary),
        const SizedBox(height: 5),
        Text(
          metric.value,
          maxLines: 1,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

class _WeatherMetric {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherMetric({
    required this.icon,
    required this.label,
    required this.value,
  });
}
