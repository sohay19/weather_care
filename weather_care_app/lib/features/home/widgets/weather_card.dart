import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../weather_data_phase.dart';
import 'missing_data_retry.dart';
import 'weather_condition_icon.dart';

class WeatherInfoCard extends StatelessWidget {
  final CurrentWeather current;
  final WeatherDataPhase dataPhase;
  final String? sunriseAt;
  final String? sunsetAt;
  final Future<void> Function()? onRetryMissingData;
  final bool retrying;

  const WeatherInfoCard({
    super.key,
    required this.current,
    this.dataPhase = WeatherDataPhase.ready,
    this.sunriseAt,
    this.sunsetAt,
    this.onRetryMissingData,
    this.retrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    final isObservation = current.dataRole == 'OBSERVATION';
    final currentSource = !isObservation
        ? '기상청 단기예보'
        : current.provider?.contains('KMA_APIHUB_GRID') == true ||
                current.provider?.contains('APIHUB_DFS') == true
            ? '기상청 10분 격자 실황'
            : current.provider?.contains('AWS') == true
                ? '기상청 AWS 관측'
                : '기상청 초단기실황';
    final apparentTemperature = current.displayedApparentTemperature;
    final estimatedApparentTemperature = current.apparentTemperatureSource ==
            'APP_STEADMAN_FROM_FORECAST' ||
        current.apparentTemperatureSource == 'APP_STEADMAN_FROM_OBSERVATION';
    final missing = <String>[
      if (current.temperature == null) '현재 기온',
      if (current.sky == null) '하늘 상태',
      if (apparentTemperature == null) '체감온도',
      if (current.humidity == null) '습도',
      if (current.windSpeed == null && current.windDirection == null) '바람',
      if (current.visibilityMeters == null) '가시거리',
      if (current.uvIndex == null) '자외선',
      if (current.pm25 == null && current.pm10 == null) '대기질',
      if (sunriseAt == null || sunsetAt == null) '일출·일몰',
    ];
    final metrics = [
      _WeatherMetric(
        icon: Icons.device_thermostat_rounded,
        label: '체감',
        value: apparentTemperature == null
            ? '자료 없음'
            : '${apparentTemperature.toStringAsFixed(1)}℃',
        levelTitle: estimatedApparentTemperature
            ? '기온·습도·바람으로 계산한 추정 체감온도예요'
            : '기상청 방식으로 계산한 체감온도예요',
        detailBody: apparentTemperature == null
            ? '체감온도 계산에 필요한 기온·습도·풍속 자료가 부족해요.\n빠진 값을 0으로 바꿔 계산하지 않아요.'
            : _apparentTemperatureDetail(
                current,
                currentSource,
                isObservation,
              ),
      ),
      _WeatherMetric(
        icon: Icons.water_drop_outlined,
        label: '습도',
        value: current.humidity == null
            ? '자료 없음'
            : '${current.humidity!.toStringAsFixed(0)}%',
        levelTitle: _humidityLevel(current.humidity),
        detailBody: current.humidity == null
            ? '$currentSource에서 상대습도 자료를 받지 못해 현재 값을 표시하지 않아요.\n실내 습도나 피부가 느끼는 건조함을 임의로 추정하지 않아요.'
            : '$currentSource의 상대습도는 ${current.humidity!.toStringAsFixed(0)}%예요.\n상대습도는 현재 공기가 같은 온도에서 머금을 수 있는 수증기량에 얼마나 가까운지를 나타내며, 실내 습도와는 다를 수 있어요.',
      ),
      _WeatherMetric(
        icon: Icons.air_rounded,
        label: '바람',
        value: _windValue(current.windDirection, current.windSpeed),
        levelTitle: _windLevel(current.windSpeed),
        detailBody: current.windSpeed == null && current.windDirection == null
            ? '$currentSource에서 풍속 자료를 받지 못해 바람을 표시하지 않아요.\n자료가 없다는 이유로 바람이 약하다고 판단하지 않아요.'
            : '$currentSource의 바람은 ${_windValue(current.windDirection, current.windSpeed)}예요.\n선택한 격자와 시각의 값이며, 돌풍이나 건물 사이·산지·해안의 국지적인 바람은 실제 위치에서 더 강하거나 약할 수 있어요.',
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
        value: _sunTimesValue(sunriseAt, sunsetAt),
        levelTitle: sunriseAt == null || sunsetAt == null
            ? '일출·일몰 시각을 확인하기 어려워요'
            : '오늘의 일출·일몰 시각이에요',
        detailBody: sunriseAt == null || sunsetAt == null
            ? '요청 지역과 날짜로 계산한 일출·일몰 시각을 받지 못해 임의의 시각을 표시하지 않아요.'
            : '요청 지역의 대표 좌표와 한국 날짜를 기준으로 계산한 시각이에요.\n지형과 건물 때문에 실제로 해가 보이는 시각은 달라질 수 있어요.',
      ),
    ];
    final displayMetrics = metrics
        .map((metric) =>
            metric.value == '자료 없음' && dataPhase != WeatherDataPhase.ready
                ? _WeatherMetric(
                    icon: metric.icon,
                    label: metric.label,
                    value: dataPhase == WeatherDataPhase.loading &&
                            metric.label == '체감'
                        ? '--°'
                        : dataPhase.missingText(),
                    levelTitle: dataPhase.explanation,
                    detailBody: dataPhase.explanation,
                  )
                : metric)
        .toList(growable: false);
    final apparentMetric = displayMetrics.first;
    final temperatureText = current.temperature == null
        ? dataPhase == WeatherDataPhase.loading
            ? '--°'
            : dataPhase.missingText()
        : '${current.temperature!.toStringAsFixed(1)}℃';
    final temperatureStyle = TextStyle(
      color: WeatherCareTheme.of(context).textPrimary,
      fontSize: current.temperature == null ? 18 : 32,
      height: 1,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
    );
    final apparentText = '체감 ${apparentMetric.value}';
    final apparentStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: WeatherCareTheme.of(context).textSecondary,
          fontWeight: FontWeight.w700,
        );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.of(context).surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              double textWidth(String value, TextStyle? style) {
                final painter = TextPainter(
                  text: TextSpan(text: value, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 1,
                )..layout();
                final width = painter.width;
                painter.dispose();
                return width;
              }
              final apparentWidth = textWidth(apparentText, apparentStyle) + 32;
              final fitsOnOneLine = textWidth(temperatureText, temperatureStyle) +
                          apparentWidth + 10 <= constraints.maxWidth;
              final weather = Wrap(
                spacing: 10,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(temperatureText, style: temperatureStyle),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.55),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            current.sky ?? dataPhase.missingText('하늘 상태 자료 없음'),
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: WeatherCareTheme.of(context)
                                          .textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        WeatherConditionIcon(
                          condition: current.sky,
                          size: 27,
                          color: WeatherCareTheme.of(context).primaryDeep,
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final apparent = ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        apparentText,
                        key: const ValueKey('weather-apparent-temperature'),
                        style: apparentStyle,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('weather-apparent-detail'),
                      tooltip: '체감온도 자세히 보기',
                      onPressed: () =>
                          _showMetricDetail(context, apparentMetric),
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(Icons.error_outline_rounded,
                          color: WeatherCareTheme.of(context).primaryDeep),
                    ),
                  ],
                ),
              );
              if (fitsOnOneLine) {
                return Row(
                  children: [
                    Expanded(child: weather),
                    const SizedBox(width: 10),
                    apparent,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  weather,
                  Align(alignment: Alignment.centerRight, child: apparent),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WeatherCareTheme.of(context).surfaceMuted,
              borderRadius: BorderRadius.circular(18),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final metric in displayMetrics.skip(1))
                      SizedBox(
                        width: itemWidth,
                        child: _MetricView(metric: metric),
                      ),
                  ],
                );
              },
            ),
          ),
          if (missing.isNotEmpty &&
              dataPhase != WeatherDataPhase.loading &&
              onRetryMissingData != null) ...[
            const SizedBox(height: 12),
            MissingDataRetry(
              message: dataPhase == WeatherDataPhase.failed
                  ? '서버에서 현재 날씨를 불러오지 못했어요: ${missing.join(' · ')}'
                  : '받지 못한 현재 날씨: ${missing.join(' · ')}',
              retryKey: 'today-current-data-retry',
              onRetry: onRetryMissingData!,
              retrying: retrying,
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
    source.add('요청 위치에서 관측소까지 ${distance.toStringAsFixed(1)}km');
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

String _apparentTemperatureDetail(
  CurrentWeather current,
  String currentSource,
  bool isObservation,
) {
  final apparent = current.displayedApparentTemperature!;
  final estimated =
      current.apparentTemperatureSource == 'APP_STEADMAN_FROM_FORECAST' ||
          current.apparentTemperatureSource == 'APP_STEADMAN_FROM_OBSERVATION';
  final parts = <String>[
    estimated
        ? '$currentSource의 기온·습도·바람으로 계산한 '
            '${isObservation ? '' : '예상 '}추정 체감온도는 '
            '${apparent.toStringAsFixed(1)}℃예요. 햇볕의 영향은 포함하지 않아요.'
        : '$currentSource의 기온과 상대습도(5~9월) 또는 기온과 풍속(10~4월)을 '
            '기상청 산식에 적용한 ${isObservation ? '' : '예상 '}체감온도는 '
            '${apparent.toStringAsFixed(1)}℃예요.',
  ];
  final temperature = current.temperature;
  if (temperature != null && (apparent - temperature).abs() >= 0.6) {
    final difference = apparent - temperature;
    parts.add(
      '실제 기온보다 ${difference.abs().toStringAsFixed(1)}℃ '
      '${difference > 0 ? '높게' : '낮게'} 계산됐어요.',
    );
  }
  return parts.join('\n');
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
  if (value == null) return '현재 풍속 수준을 확인하기 어려워요';
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

  const _MetricView({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('weather-metric-${metric.label}'),
      color: WeatherCareTheme.of(context).surface.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _showMetricDetail(context, metric),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: WeatherCareTheme.of(context).primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      metric.icon,
                      size: 16,
                      color: WeatherCareTheme.of(context).primaryDeep,
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: '${metric.label} 자세히 보기',
                    child: IconButton(
                      key: ValueKey('weather-metric-detail-${metric.label}'),
                      onPressed: () => _showMetricDetail(context, metric),
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(Icons.error_outline_rounded,
                          color: WeatherCareTheme.of(context).primaryDeep),
                    ),
                  ),
                ],
              ),
              Text(metric.label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 3),
              Text(
                metric.value,
                maxLines: 2,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showMetricDetail(BuildContext context, _WeatherMetric metric) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('${metric.label} 상세'),
      content: SingleChildScrollView(
        key: ValueKey('weather-metric-detail-content-${metric.label}'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric.levelTitle,
              key: ValueKey('weather-metric-level-${metric.label}'),
              style: TextStyle(
                color: WeatherCareTheme.of(dialogContext).primaryDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(metric.detailBody),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
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
