import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../weather_labels.dart';
import 'missing_data_retry.dart';
import 'weather_condition_icon.dart';

class WeatherInfoCard extends StatefulWidget {
  final CurrentWeather current;
  final String? sunriseAt;
  final String? sunsetAt;
  final Future<void> Function()? onRetryMissingData;
  final bool retrying;

  const WeatherInfoCard({
    super.key,
    required this.current,
    this.sunriseAt,
    this.sunsetAt,
    this.onRetryMissingData,
    this.retrying = false,
  });

  @override
  State<WeatherInfoCard> createState() => _WeatherInfoCardState();
}

class _WeatherInfoCardState extends State<WeatherInfoCard> {
  final Set<String> _expandedMetrics = {};

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    final missing = <String>[
      if (current.temperature == null) '예상 기온',
      if (current.sky == null) '하늘 상태',
      if (current.apparentTemperature == null) '체감온도',
      if (current.humidity == null) '습도',
      if (current.windSpeed == null && current.windDirection == null) '바람',
      if (current.visibilityMeters == null) '가시거리',
      if (current.uvIndex == null) '자외선',
      if (current.pm25 == null && current.pm10 == null) '대기질',
      if (widget.sunriseAt == null || widget.sunsetAt == null) '일출·일몰',
    ];
    final metrics = [
      _WeatherMetric(
        icon: Icons.device_thermostat_rounded,
        label: '체감',
        value: current.apparentTemperature == null
            ? '자료 없음'
            : '${current.apparentTemperature!.toStringAsFixed(1)}℃',
        levelTitle: _apparentTemperatureLevel(current.apparentTemperature),
        detailBody: current.apparentTemperature == null
            ? '기온·습도·풍속 입력자료가 모두 갖춰지지 않았거나 체감온도 계산조건에 맞지 않아 값을 만들지 않았어요.\n빠진 값을 0으로 바꿔 계산하지 않아요.'
            : '기상청 단기예보의 기온·상대습도·풍속을 이용해 계산한 예상 체감온도는 ${current.apparentTemperature!.toStringAsFixed(1)}℃예요.\n햇빛, 옷차림, 활동량, 건물 주변 바람에 따라 실제로 느끼는 정도는 달라질 수 있어요.',
      ),
      _WeatherMetric(
        icon: Icons.water_drop_outlined,
        label: '습도',
        value: current.humidity == null
            ? '자료 없음'
            : '${current.humidity!.toStringAsFixed(0)}%',
        levelTitle: _humidityLevel(current.humidity),
        detailBody: current.humidity == null
            ? '기상청 단기예보에서 상대습도 자료를 받지 못해 현재 값을 표시하지 않아요.\n실내 습도나 피부가 느끼는 건조함을 임의로 추정하지 않아요.'
            : '기상청 단기예보의 상대습도는 ${current.humidity!.toStringAsFixed(0)}%예요.\n상대습도는 현재 공기가 같은 온도에서 머금을 수 있는 수증기량에 얼마나 가까운지를 나타내며, 실내 습도와는 다를 수 있어요.',
      ),
      _WeatherMetric(
        icon: Icons.air_rounded,
        label: '바람',
        value: _windValue(current.windDirection, current.windSpeed),
        levelTitle: _windLevel(current.windSpeed),
        detailBody: current.windSpeed == null && current.windDirection == null
            ? '기상청 단기예보에서 풍향과 풍속 자료를 받지 못해 바람을 표시하지 않아요.\n자료가 없다는 이유로 바람이 약하다고 판단하지 않아요.'
            : '기상청 단기예보의 바람은 ${_windValue(current.windDirection, current.windSpeed)}예요.\n선택한 예보 격자와 시각의 값이며, 돌풍이나 건물 사이·산지·해안의 국지적인 바람은 실제 위치에서 더 강하거나 약할 수 있어요.',
      ),
      _WeatherMetric(
        icon: Icons.wb_sunny_outlined,
        label: '자외선',
        value: current.uvIndex == null
            ? '자료 없음'
            : current.uvIndex!.toStringAsFixed(1),
        levelTitle: current.uvIndex == null
            ? '자외선 수준을 확인하기 어려워요'
            : '자외선은 ${_uvGrade(current.uvIndex!)} 단계예요',
        detailBody: current.uvIndex == null
            ? '기상청 생활기상지수 자료를 받지 못해 자외선지수와 단계를 표시하지 않아요.\n자료가 없음을 낮음 단계로 바꾸지 않아요.'
            : '기상청 자외선지수는 ${current.uvIndex!.toStringAsFixed(1)}, ${_uvGrade(current.uvIndex!)} 단계예요.\n0~2 낮음, 3~5 보통, 6~7 높음, 8~10 매우 높음, 11 이상 위험으로 구분해요.\n구름, 그늘, 고도와 노출 시간에 따라 개인의 실제 노출량은 달라질 수 있어요.',
      ),
      _WeatherMetric(
        icon: Icons.eco_outlined,
        label: '대기질',
        value: _airQualityGrade(current.pm10, current.pm25) ?? '자료 없음',
        levelTitle: _airQualityGrade(current.pm10, current.pm25) == null
            ? '대기질 수준을 확인하기 어려워요'
            : '대기질은 ${_airQualityGrade(current.pm10, current.pm25)} 등급이에요',
        detailBody: _airQualityDetail(current),
      ),
      _WeatherMetric(
        icon: Icons.visibility_outlined,
        label: '가시거리',
        value: _visibilityValue(current.visibilityMeters),
        levelTitle: _visibilityLevel(current.visibilityMeters),
        detailBody: _visibilityDetail(current),
      ),
      _WeatherMetric(
        icon: Icons.wb_twilight_rounded,
        label: '일출·일몰',
        value: _sunTimesValue(widget.sunriseAt, widget.sunsetAt),
        levelTitle: widget.sunriseAt == null || widget.sunsetAt == null
            ? '일출·일몰 시각을 확인하기 어려워요'
            : '오늘의 일출·일몰 시각이에요',
        detailBody: widget.sunriseAt == null || widget.sunsetAt == null
            ? '요청 지역과 날짜로 계산한 일출·일몰 시각을 받지 못해 임의의 시각을 표시하지 않아요.'
            : '요청 지역의 대표 좌표와 한국 날짜를 기준으로 계산한 시각이에요.\n지형과 건물 때문에 실제로 해가 보이는 시각은 달라질 수 있어요.',
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
            child: Column(
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  _MetricView(
                    metric: metrics[index],
                    expanded: _expandedMetrics.contains(metrics[index].label),
                    onTap: () {
                      setState(() {
                        if (!_expandedMetrics.remove(metrics[index].label)) {
                          _expandedMetrics.add(metrics[index].label);
                        }
                      });
                    },
                  ),
                  if (index < metrics.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          if (missing.isNotEmpty && widget.onRetryMissingData != null) ...[
            const SizedBox(height: 12),
            MissingDataRetry(
              message: '받지 못한 현재 날씨: ${missing.join(' · ')}',
              retryKey: 'today-current-data-retry',
              onRetry: widget.onRetryMissingData!,
              retrying: widget.retrying,
            ),
          ],
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
  return '\n\n$stationLabel · $timeLabel\n'.trimRight();
}

String? _airQualityGrade(int? pm10, int? pm25) {
  final grades = [
    if (pm10 != null) _pm10Grade(pm10),
    if (pm25 != null) _pm25Grade(pm25),
  ];
  if (grades.isEmpty) return null;
  const severity = {'좋음': 0, '보통': 1, '나쁨': 2, '매우 나쁨': 3};
  return grades.reduce(
    (left, right) =>
        (severity[right] ?? 0) > (severity[left] ?? 0) ? right : left,
  );
}

String _airQualityDetail(CurrentWeather current) {
  final grade = _airQualityGrade(current.pm10, current.pm25);
  if (grade == null) {
    return '에어코리아 관측자료를 받지 못해 대기질을 표시하지 않아요.\n자료가 없음을 좋음 등급으로 바꾸지 않아요.';
  }
  final values = [
    if (current.pm25 != null) '초미세먼지 ${current.pm25}㎍/㎥',
    if (current.pm10 != null) '미세먼지 ${current.pm10}㎍/㎥',
  ].join(' · ');
  return '에어코리아 관측값 중 더 나쁜 등급을 대기질로 표시해요.\n'
      '$values · 종합 $grade${_airObservationSource(current)}';
}

String _windValue(double? direction, double? speed) {
  if (direction == null && speed == null) return '자료 없음';
  final directionLabel = _windDirectionLabel(direction);
  if (speed == null) {
    return directionLabel == null ? '자료 없음' : '$directionLabel풍';
  }
  return '${directionLabel == null ? '' : '$directionLabel '}'
      '${speed.toStringAsFixed(1)}m/s';
}

String? _windDirectionLabel(double? direction) {
  if (direction == null || !direction.isFinite) return null;
  const labels = ['북', '북동', '동', '남동', '남', '남서', '서', '북서'];
  final normalized = ((direction % 360) + 360) % 360;
  return labels[((normalized + 22.5) ~/ 45) % labels.length];
}

String _visibilityValue(double? meters) {
  if (meters == null) return '자료 없음';
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

String _visibilityLevel(double? meters) {
  if (meters == null) return '현재 가시거리 수준을 확인하기 어려워요';
  final level = switch (meters) {
    < 200 => '매우 짧은',
    < 1000 => '짧은',
    < 5000 => '제한적인',
    < 10000 => '보통',
    < 20000 => '좋은',
    _ => '매우 좋은',
  };
  return '현재 시야는 $level 수준이에요';
}

String _visibilityDetail(CurrentWeather current) {
  final meters = current.visibilityMeters;
  if (meters == null) {
    return '기상청 지상관측 자료를 받지 못해 현재 가시거리를 표시하지 않아요.\n가시거리는 미래 예보값으로 대신 채우지 않아요.';
  }
  final source = <String>[];
  if (current.visibilityStationId case final station?) {
    source.add('관측소 $station');
  }
  if (current.visibilityStationDistanceKm case final distance?) {
    source.add('대표 지점에서 ${distance.toStringAsFixed(1)}km');
  }
  final observed = _koreaObservationClock(current.visibilityObservedAt);
  if (observed != null) source.add(observed);
  final sourceText = source.isEmpty ? '' : '\n${source.join(' · ')}';
  return '기상청 지상관측의 현재 가시거리는 ${_visibilityValue(meters)}예요.'
      '$sourceText\n시간별·주간 미래 가시거리 예보로 확대하지 않아요.';
}

String _sunTimesValue(String? sunriseAt, String? sunsetAt) {
  final sunrise = _koreaClock(sunriseAt);
  final sunset = _koreaClock(sunsetAt);
  if (sunrise == null && sunset == null) return '자료 없음';
  return '${sunrise ?? '--:--'} · ${sunset ?? '--:--'}';
}

String? _koreaClock(String? timestamp) {
  final parsed =
      timestamp == null ? null : DateTime.tryParse(timestamp)?.toUtc();
  if (parsed == null) return null;
  final korea = parsed.add(const Duration(hours: 9));
  return '${korea.hour}:${korea.minute.toString().padLeft(2, '0')}';
}

String? _koreaObservationClock(String? timestamp) {
  final parsed =
      timestamp == null ? null : DateTime.tryParse(timestamp)?.toUtc();
  if (parsed == null) return null;
  final korea = parsed.add(const Duration(hours: 9));
  return '${korea.month}월 ${korea.day}일 ${korea.hour}시 '
      '${korea.minute.toString().padLeft(2, '0')}분 관측';
}

String _apparentTemperatureLevel(double? value) {
  if (value == null) return '체감온도 수준을 확인하기 어려워요';
  final level = switch (value) {
    >= 38 => '위험한 더위',
    >= 35 => '더위 경계',
    >= 33 => '더위 주의',
    >= 28 => '더운',
    >= 20 => '조금 더운',
    >= 10 => '선선한',
    >= 0 => '쌀쌀한',
    _ => '추운',
  };
  return '체감온도는 $level 수준이에요';
}

String _humidityLevel(double? value) {
  if (value == null) return '실외 습도 수준을 확인하기 어려워요';
  final level = switch (value) {
    < 30 => '낮은',
    <= 60 => '보통',
    <= 80 => '높은',
    _ => '매우 높은',
  };
  return '실외 습도는 $level 수준이에요';
}

String _windLevel(double? value) {
  if (value == null) return '예상 풍속 수준을 확인하기 어려워요';
  final level = switch (value) {
    < 4 => '약한',
    < 9 => '약간 강한',
    < 14 => '강한',
    _ => '매우 강한',
  };
  return '바람은 $level 수준이에요';
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

class _MetricView extends StatelessWidget {
  final _WeatherMetric metric;
  final bool expanded;
  final VoidCallback onTap;

  const _MetricView({
    required this.metric,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('weather-metric-${metric.label}'),
      color: Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: WeatherCareTheme.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      metric.icon,
                      size: 17,
                      color: WeatherCareTheme.primaryDeep,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          metric.value,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: expanded
                        ? '${metric.label} 상세 내용 접기'
                        : '${metric.label} 자세히 보기',
                    child: IconButton(
                      key: ValueKey('weather-metric-detail-${metric.label}'),
                      onPressed: onTap,
                      icon: Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: WeatherCareTheme.primaryDeep,
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: expanded
                    ? Padding(
                        key: ValueKey(
                          'weather-metric-detail-content-${metric.label}',
                        ),
                        padding: const EdgeInsets.fromLTRB(42, 10, 8, 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metric.levelTitle,
                              key: ValueKey(
                                'weather-metric-level-${metric.label}',
                              ),
                              style: const TextStyle(
                                color: WeatherCareTheme.primaryDeep,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              metric.detailBody,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
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
  final String levelTitle;
  final String detailBody;

  const _WeatherMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.levelTitle,
    required this.detailBody,
  });
}
