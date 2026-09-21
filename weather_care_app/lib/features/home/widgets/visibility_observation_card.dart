import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import 'home_section_header.dart';

class VisibilityObservationCard extends StatelessWidget {
  final CurrentWeather? current;
  final String title;

  const VisibilityObservationCard({
    super.key,
    required this.current,
    this.title = '가시거리 관측',
  });

  @override
  Widget build(BuildContext context) {
    final weather = current;
    final value = weather?.visibilityMeters;
    return Container(
      key: const ValueKey('visibility-observation-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            icon: Icons.visibility_outlined,
            title: title,
            subtitle: value == null
                ? '현재 관측자료를 아직 확인하기 어려워요'
                : '현재 시야는 ${_visibilityLevel(value)} 수준이에요',
          ),
          const SizedBox(height: 12),
          Text(
            value == null ? '관측값 자료 없음' : _visibilityValue(value),
            style: TextStyle(
              color: value != null && value < 1000
                  ? WeatherCareTheme.danger
                  : WeatherCareTheme.primaryDeep,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (_observationSource(weather) case final source?) ...[
            const SizedBox(height: 5),
            Text(source, style: WeatherCareTheme.microTextStyle),
          ],
          const SizedBox(height: 10),
          Text(
            '가시거리는 관측 시점의 값이며 시간별·주간 미래 예보로 확대하지 않아요.',
            key: const ValueKey('visibility-forecast-limit'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WeatherCareTheme.textSecondary,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

String _visibilityValue(double meters) {
  if (meters >= 20000) return '20km 이상';
  if (meters >= 1000) {
    final kilometres = meters / 1000;
    final value = kilometres == kilometres.roundToDouble()
        ? kilometres.toStringAsFixed(0)
        : kilometres.toStringAsFixed(1);
    return '$value km';
  }
  return '${meters.round()} m';
}

String _visibilityLevel(double meters) {
  if (meters < 200) return '매우 짧은';
  if (meters < 1000) return '짧은';
  if (meters < 5000) return '제한적인';
  if (meters < 10000) return '보통';
  if (meters < 20000) return '좋은';
  return '매우 좋은';
}

String? _observationSource(CurrentWeather? current) {
  if (current == null) return null;
  final parts = <String>[];
  final station = current.visibilityStationId?.trim();
  if (station != null && station.isNotEmpty) parts.add('관측소 $station');
  if (current.visibilityStationDistanceKm case final distance?) {
    parts.add('대표 지점에서 ${distance.toStringAsFixed(1)}km');
  }
  final rawTime = current.visibilityObservedAt;
  final parsed = rawTime == null ? null : DateTime.tryParse(rawTime)?.toUtc();
  if (parsed != null) {
    final korea = parsed.add(const Duration(hours: 9));
    parts.add(
      '${korea.month}월 ${korea.day}일 ${korea.hour}시 '
      '${korea.minute.toString().padLeft(2, '0')}분 관측',
    );
  }
  return parts.isEmpty ? null : parts.join(' · ');
}
