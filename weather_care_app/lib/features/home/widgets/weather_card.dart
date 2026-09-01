import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import 'weather_condition_icon.dart';

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
            : '${current.apparentTemperature!.toStringAsFixed(1)}℃',
        dialogTitle: '예상 체감온도',
        dialogBody: current.apparentTemperature == null
            ? '체감온도 계산조건이 맞지 않거나 입력자료가 없어 표시하지 않아요.'
            : '기상청 단기예보의 기온·습도·풍속으로 계산한 예상 체감온도는 ${current.apparentTemperature!.toStringAsFixed(1)}℃예요.',
      ),
      if (current.humidity != null)
        _WeatherMetric(
          icon: Icons.water_drop_outlined,
          label: '습도',
          value: '${current.humidity!.toStringAsFixed(0)}%',
          dialogTitle: '실외 상대습도',
          dialogBody:
              '기상청은 선택한 지역에 상대습도 ${current.humidity!.toStringAsFixed(0)}%를 예보했어요.',
        ),
      if (current.uvIndex != null)
        _WeatherMetric(
          icon: Icons.wb_sunny_outlined,
          label: '자외선',
          value: current.uvIndex!.toStringAsFixed(1),
          dialogTitle: '자외선지수 공식 단계',
          dialogBody:
              '기상청 자외선지수는 ${current.uvIndex!.toStringAsFixed(1)}, ${_uvGrade(current.uvIndex!)} 단계예요. 공식 단계는 낮음·보통·높음·매우 높음·위험으로 구분해요.',
        ),
      if (current.pm25 != null || current.pm10 != null)
        _WeatherMetric(
          icon: Icons.blur_on_rounded,
          label: current.pm25 != null ? '초미세먼지' : '미세먼지',
          value: current.pm25?.toString() ?? current.pm10.toString(),
          dialogTitle: current.pm25 != null ? '초미세먼지 공식 등급' : '미세먼지 공식 등급',
          dialogBody: current.pm25 != null
              ? '에어코리아 초미세먼지 농도는 ${current.pm25}㎍/㎥, ${_pm25Grade(current.pm25!)} 등급이에요.'
              : '에어코리아 미세먼지 농도는 ${current.pm10}㎍/㎥, ${_pm10Grade(current.pm10!)} 등급이에요.',
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${current.temperature.toStringAsFixed(1)}℃',
                style: const TextStyle(
                  color: WeatherCareTheme.textPrimary,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const Spacer(),
              Text(
                current.sky ?? '정보 없음',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: WeatherCareTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 8),
              WeatherConditionIcon(
                condition: current.sky,
                size: 27,
                color: WeatherCareTheme.primaryDeep,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: WeatherCareTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  Expanded(
                    child: _MetricView(
                      metric: metrics[index],
                      onTap: () => _showMetricDialog(context, metrics[index]),
                    ),
                  ),
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

String _uvGrade(double value) {
  if (value <= 2) return '낮음';
  if (value <= 5) return '보통';
  if (value <= 7) return '높음';
  if (value <= 10) return '매우 높음';
  return '위험';
}

String _pm25Grade(int value) {
  if (value <= 15) return '좋음';
  if (value <= 35) return '보통';
  if (value <= 75) return '나쁨';
  return '매우 나쁨';
}

String _pm10Grade(int value) {
  if (value <= 30) return '좋음';
  if (value <= 80) return '보통';
  if (value <= 150) return '나쁨';
  return '매우 나쁨';
}

void _showMetricDialog(BuildContext context, _WeatherMetric metric) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(metric.dialogTitle),
      content: Text(metric.dialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

class _MetricView extends StatelessWidget {
  final _WeatherMetric metric;
  final VoidCallback onTap;

  const _MetricView({required this.metric, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${metric.label} 기준 보기',
      child: InkWell(
        key: ValueKey('weather-metric-${metric.label}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Icon(metric.icon, size: 17, color: WeatherCareTheme.primary),
              const SizedBox(height: 5),
              Text(
                metric.value,
                maxLines: 1,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 10,
                    color: WeatherCareTheme.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherMetric {
  final IconData icon;
  final String label;
  final String value;
  final String dialogTitle;
  final String dialogBody;

  const _WeatherMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.dialogTitle,
    required this.dialogBody,
  });
}
