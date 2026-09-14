import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../weather_labels.dart';
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
            ? '자료 없음'
            : '${current.apparentTemperature!.toStringAsFixed(1)}℃',
        dialogTitle: '예상 체감온도',
        dialogBody: current.apparentTemperature == null
            ? '체감온도 계산조건이 맞지 않거나 입력자료가 없어 표시하지 않아요.'
            : '기상청 단기예보 기온·습도·풍속 기준 예상 체감온도는 ${current.apparentTemperature!.toStringAsFixed(1)}℃예요.',
      ),
      _WeatherMetric(
        icon: Icons.water_drop_outlined,
        label: '습도',
        value: current.humidity == null
            ? '자료 없음'
            : '${current.humidity!.toStringAsFixed(0)}%',
        dialogTitle: '실외 상대습도',
        dialogBody: current.humidity == null
            ? '습도 자료가 없어 실외 상대습도를 확인하기 어려워요.'
            : '기상청은 선택한 지역에 상대습도 ${current.humidity!.toStringAsFixed(0)}%를 예보했어요.',
      ),
      _WeatherMetric(
        icon: Icons.air_rounded,
        label: '풍속',
        value: current.windSpeed == null
            ? '자료 없음'
            : '${current.windSpeed!.toStringAsFixed(1)}m/s',
        dialogTitle: '예상 풍속',
        dialogBody: current.windSpeed == null
            ? '풍속 자료가 없어 바람의 세기를 확인하기 어려워요.'
            : '기상청은 선택한 지역에 풍속 ${current.windSpeed!.toStringAsFixed(1)}m/s를 예보했어요.',
      ),
      _WeatherMetric(
        icon: Icons.wb_sunny_outlined,
        label: '자외선',
        value: current.uvIndex == null
            ? '자료 없음'
            : current.uvIndex!.toStringAsFixed(1),
        dialogTitle: '자외선지수 공식 단계',
        dialogBody: current.uvIndex == null
            ? '자외선 자료가 없어 자외선지수와 단계를 확인하기 어려워요.'
            : '기상청 자외선지수는 ${current.uvIndex!.toStringAsFixed(1)}, ${_uvGrade(current.uvIndex!)} 단계예요. 공식 단계는 낮음·보통·높음·매우 높음·위험으로 구분해요.',
      ),
      _WeatherMetric(
        icon: Icons.blur_on_rounded,
        label: '초미세먼지',
        value: current.pm25 == null ? '자료 없음' : '${current.pm25}㎍/㎥',
        dialogTitle: '초미세먼지 공식 등급',
        dialogBody: current.pm25 == null
            ? '초미세먼지 자료가 없어 농도와 등급을 확인하기 어려워요.'
            : '에어코리아 초미세먼지 농도는 ${current.pm25}㎍/㎥, ${_pm25Grade(current.pm25!)} 등급이에요.${_airObservationSource(current)}',
      ),
      _WeatherMetric(
        icon: Icons.grain_rounded,
        label: '미세먼지',
        value: current.pm10 == null ? '자료 없음' : '${current.pm10}㎍/㎥',
        dialogTitle: '미세먼지 공식 등급',
        dialogBody: current.pm10 == null
            ? '미세먼지 자료가 없어 농도와 등급을 확인하기 어려워요.'
            : '에어코리아 미세먼지 농도는 ${current.pm10}㎍/㎥, ${_pm10Grade(current.pm10!)} 등급이에요.${_airObservationSource(current)}',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            forecastTemperatureLabel(current.forecastAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WeatherCareTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  current.temperature == null
                      ? '자료 없음'
                      : '${current.temperature!.toStringAsFixed(1)}℃',
                  style: TextStyle(
                    color: WeatherCareTheme.textPrimary,
                    fontSize: current.temperature == null ? 20 : 34,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  current.sky ?? '하늘 상태 자료 없음',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: WeatherCareTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WeatherCareTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                final textScale =
                    MediaQuery.textScalerOf(context).scale(13) / 13;
                final minWidth = 112 * textScale.clamp(1.0, 3.0);
                final columns =
                    ((constraints.maxWidth + spacing) / (minWidth + spacing))
                        .floor()
                        .clamp(1, 3);
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: 12,
                  children: [
                    for (final metric in metrics)
                      SizedBox(
                        width: width,
                        child: _MetricView(
                          metric: metric,
                          onTap: () => _showMetricDialog(context, metric),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _airObservationSource(CurrentWeather current) {
  final station = current.airQualityStationName?.trim();
  final rawTime = current.airQualityObservedAt;
  final parsed =
      rawTime != null && RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(rawTime)
          ? DateTime.tryParse(rawTime)?.toUtc().add(const Duration(hours: 9))
          : null;
  final stationLabel =
      station == null || station.isEmpty ? '측정소 정보 없음' : '$station 측정소';
  final timeLabel = parsed == null
      ? '관측 시각 정보 없음'
      : '${parsed.month}월 ${parsed.day}일 ${parsed.hour}시 '
          '${parsed.minute.toString().padLeft(2, '0')}분 관측';
  return '\n\n$stationLabel · $timeLabel\n'
      '측정소에서 관측한 값이며, 사용자 위치에서 직접 측정한 농도는 아니에요.';
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
      scrollable: true,
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
      message: '${metric.label} 자료와 기준 보기',
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
                textAlign: TextAlign.center,
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
