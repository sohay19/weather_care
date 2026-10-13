import 'package:flutter/material.dart';

import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../weather_labels.dart';
import '../weather_data_phase.dart';
import 'missing_data_retry.dart';
import 'weather_condition_icon.dart';

class WeatherInfoCard extends StatelessWidget {
  final CurrentWeather current;
  final TodayLivingIndices? livingIndices;
  final WeatherDataPhase dataPhase;
  final String? sunriseAt;
  final String? sunsetAt;
  final bool showCurrentSummary;
  final Future<void> Function()? onRetryMissingData;
  final bool retrying;

  const WeatherInfoCard({
    super.key,
    required this.current,
    this.livingIndices,
    this.dataPhase = WeatherDataPhase.ready,
    this.sunriseAt,
    this.sunsetAt,
    this.showCurrentSummary = true,
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
    final snowDepth =
        current.snowDepthStatus == 'UNAVAILABLE' ? null : current.snowDepthCm;
    final estimatedApparentTemperature = current.apparentTemperatureSource ==
            'APP_STEADMAN_FROM_FORECAST' ||
        current.apparentTemperatureSource == 'APP_STEADMAN_FROM_OBSERVATION';
    final missing = <String>[
      if (showCurrentSummary && current.temperature == null) '현재 기온',
      if (showCurrentSummary && current.sky == null) '하늘 상태',
      if (showCurrentSummary && apparentTemperature == null) '체감온도',
      if (current.humidity == null) '습도',
      if (current.windSpeed == null) '바람',
      if (current.visibilityMeters == null) '가시거리',
      if (current.uvIndex == null) '자외선',
      if (current.pm25 == null && current.pm10 == null && current.ozone == null)
        '대기질',
      if (sunriseAt == null || sunsetAt == null) '일출·일몰',
      if (!showCurrentSummary &&
          livingIndices?.pollenStatus != 'OUT_OF_SEASON' &&
          (livingIndices?.pollen.isEmpty ?? true))
        '꽃가루',
      if (!showCurrentSummary && livingIndices?.airStagnationLevel == null)
        '대기정체',
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
            : '${humidityDescription(current.humidity)}\n${current.humidity!.toStringAsFixed(0)}%',
        levelTitle: _humidityLevel(current.humidity),
        detailBody: current.humidity == null
            ? '$currentSource에서 상대습도 자료를 받지 못해 현재 값을 표시하지 않아요.\n실내 습도나 피부가 느끼는 건조함을 임의로 추정하지 않아요.\n\n$humidityRanges'
            : '$currentSource의 상대습도는 ${current.humidity!.toStringAsFixed(0)}%예요.\n상대습도는 현재 공기가 같은 온도에서 머금을 수 있는 수증기량에 얼마나 가까운지를 나타내며, 실내 습도와는 다를 수 있어요.\n\n$humidityRanges',
      ),
      _WeatherMetric(
        icon: Icons.air_rounded,
        label: '바람',
        value: current.windSpeed == null
            ? '자료 없음'
            : '${windDescription(current.windSpeed)}\n${_windValue(current.windDirection, current.windSpeed)}',
        levelTitle: _windLevel(current.windSpeed),
        detailBody: current.windSpeed == null
            ? '$currentSource에서 풍속 자료를 받지 못해 현재 바람 수준을 표시하지 않아요.\n자료가 없다는 이유로 바람이 약하다고 판단하지 않아요.\n\n$windRanges'
            : '$currentSource의 바람은 ${_windValue(current.windDirection, current.windSpeed)}예요.\n선택한 격자와 시각의 값이며, 돌풍이나 건물 사이·산지·해안의 국지적인 바람은 실제 위치에서 더 강하거나 약할 수 있어요.\n\n$windRanges',
      ),
      _WeatherMetric(
        icon: Icons.wb_sunny_outlined,
        label: '자외선',
        value: current.uvIndex == null
            ? '자료 없음'
            : '${uvDescription(current.uvIndex)}\n${current.uvIndex!.toStringAsFixed(1)}',
        levelTitle: current.uvIndex == null
            ? '자외선 수준을 확인하기 어려워요'
            : '자외선은 ${uvDescription(current.uvIndex)} 단계예요',
        detailBody: current.uvIndex == null
            ? '기상청 생활기상지수 자료를 받지 못해 자외선지수와 단계를 표시하지 않아요.\n자료가 없음을 낮음 단계로 바꾸지 않아요.\n\n$uvRanges'
            : '기상청 자외선지수는 ${current.uvIndex!.toStringAsFixed(1)}, ${uvDescription(current.uvIndex)} 단계예요.\n구름, 그늘, 고도와 노출 시간에 따라 개인의 실제 노출량은 달라질 수 있어요.\n\n$uvRanges',
      ),
      _WeatherMetric(
        icon: Icons.eco_outlined,
        label: '대기질',
        value: _airQualityGrade(current.pm10, current.pm25, current.ozone) ??
            '자료 없음',
        levelTitle: _airQualityGrade(
                    current.pm10, current.pm25, current.ozone) ==
                null
            ? '대기질 수준을 확인하기 어려워요'
            : '대기질은 ${_airQualityGrade(current.pm10, current.pm25, current.ozone)} 등급이에요',
        detailBody: _airQualityDetail(current),
      ),
      _WeatherMetric(
        icon: Icons.visibility_outlined,
        label: '가시거리',
        value: current.visibilityMeters == null
            ? '자료 없음'
            : '${visibilityDescription(current.visibilityMeters)}\n${_visibilityValue(current.visibilityMeters)}',
        levelTitle: _visibilityLevel(current.visibilityMeters),
        detailBody: _visibilityDetail(current),
      ),
      if (!showCurrentSummary) ...[
        _WeatherMetric(
          icon: Icons.grass_rounded,
          label: '꽃가루',
          value: livingIndices?.pollenStatus == 'OUT_OF_SEASON'
              ? '제공 기간 밖'
              : _pollenSummary(livingIndices?.pollen),
          levelTitle: livingIndices?.pollenStatus == 'OUT_OF_SEASON'
              ? '현재는 꽃가루농도위험지수 제공 기간이 아니에요'
              : (livingIndices?.pollen.isEmpty ?? true)
                  ? '꽃가루 위험 수준을 확인하기 어려워요'
                  : '오늘의 꽃가루농도위험지수예요',
          detailBody: livingIndices?.pollenStatus == 'OUT_OF_SEASON'
              ? '기상청은 참나무·소나무를 3~6월, 잡초류를 8~10월에 제공해요. 제공 기간 밖을 낮음 단계로 해석하지 않아요.'
              : (livingIndices?.pollen.isEmpty ?? true)
                  ? '기상청 꽃가루농도위험지수 자료를 받지 못했어요. 자료 없음은 꽃가루가 없다는 뜻이 아니에요.'
                  : '기상청 꽃가루농도위험지수의 오늘 예측값이에요.\n${livingIndices!.pollen.map((risk) => '${risk.species}: ${risk.level}').join(' · ')}\n개인의 알레르기 반응은 다를 수 있어요.',
        ),
        _WeatherMetric(
          icon: Icons.air_rounded,
          label: '대기정체',
          value: livingIndices?.airStagnationLevel ?? '자료 없음',
          levelTitle: livingIndices?.airStagnationLevel == null
              ? '대기정체 수준을 확인하기 어려워요'
              : '대기정체지수는 ${livingIndices!.airStagnationLevel} 단계예요',
          detailBody: livingIndices?.airStagnationLevel == null
              ? '기상청 대기정체지수 예측 자료를 받지 못했어요. 미세먼지 농도로 대기정체 수준을 추정하지 않아요.'
              : '기상청 대기정체지수의 ${_koreaClock(livingIndices?.airStagnationForecastAt) ?? '오늘'} 예측값이에요. 대기가 얼마나 잘 순환하는지 나타내며, 실제 미세먼지 농도와는 다른 정보예요.',
        ),
      ],
      if (!showCurrentSummary)
        _WeatherMetric(
          icon: Icons.ac_unit_rounded,
          label: '현재 적설',
          value: snowDepth == null
              ? '자료 없음'
              : snowDepth == 0
                  ? '쌓인 눈 없음\n0cm'
                  : '눈 쌓임\n${_snowDepthValue(snowDepth)}cm',
          levelTitle: snowDepth == null
              ? '현재 쌓인 눈의 깊이를 확인하기 어려워요'
              : '관측소의 현재 적설은 ${_snowDepthValue(snowDepth)}cm예요',
          detailBody: _snowDepthDetail(current),
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
          if (showCurrentSummary) ...[
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

                final apparentWidth =
                    textWidth(apparentText, apparentStyle) + 32;
                final fitsOnOneLine =
                    textWidth(temperatureText, temperatureStyle) +
                            apparentWidth +
                            10 <=
                        constraints.maxWidth;
                final weather = Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(temperatureText, style: temperatureStyle),
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: constraints.maxWidth * 0.55),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              current.sky ??
                                  dataPhase.missingText('하늘 상태 자료 없음'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: WeatherCareTheme.of(context)
                                        .textSecondary,
                                    fontSize: 14,
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
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WeatherCareTheme.of(context).surfaceMuted,
              borderRadius: BorderRadius.circular(18),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 8) / 2;
                final metricHeight = _equalMetricHeight(
                  context,
                  displayMetrics.skip(1),
                  itemWidth,
                );
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final metric in displayMetrics.skip(1))
                      SizedBox(
                        width: itemWidth,
                        height: metricHeight,
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

String _pollenSummary(List<PollenRisk>? pollen) {
  if (pollen == null || pollen.isEmpty) return '자료 없음';
  const levels = ['낮음', '보통', '높음', '매우 높음'];
  final highest = pollen.reduce(
      (a, b) => levels.indexOf(a.level) >= levels.indexOf(b.level) ? a : b);
  return '${highest.level}\n${highest.species}';
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

String? _airQualityGrade(int? pm10, int? pm25, double? ozone) {
  final grades = [
    if (pm10 != null) _pm10Grade(pm10),
    if (pm25 != null) _pm25Grade(pm25),
    if (ozoneDescription(ozone) case final grade?) grade,
  ];
  if (grades.isEmpty) return null;
  const severity = {'좋음': 0, '보통': 1, '나쁨': 2, '매우 나쁨': 3};
  return grades.reduce(
    (left, right) =>
        (severity[right] ?? 0) > (severity[left] ?? 0) ? right : left,
  );
}

String _airQualityDetail(CurrentWeather current) {
  final grade = _airQualityGrade(current.pm10, current.pm25, current.ozone);
  if (grade == null) {
    return '에어코리아 관측자료를 받지 못해 대기질을 표시하지 않아요.\n자료가 없음을 좋음 등급으로 바꾸지 않아요.';
  }
  final values = [
    if (current.pm25 != null) '초미세먼지 ${current.pm25}㎍/㎥',
    if (current.pm10 != null) '미세먼지 ${current.pm10}㎍/㎥',
    if (ozoneDescription(current.ozone) != null)
      '오존 ${current.ozone!.toStringAsFixed(3)}ppm',
  ].join(' · ');
  return '제공된 에어코리아 오염물질 관측값 중 가장 나쁜 등급을 표시해요. 공식 통합대기환경지수는 아니에요.\n'
      '$values · 표시 등급 $grade${_airObservationSource(current)}';
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
  return '가시거리 · ${visibilityDescription(meters)}';
}

String _visibilityDetail(CurrentWeather current) {
  final meters = current.visibilityMeters;
  if (meters == null) {
    return '기상청 지상관측 자료를 받지 못해 현재 가시거리를 표시하지 않아요.\n가시거리는 미래 예보값으로 대신 채우지 않아요.\n\n$visibilityRanges';
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
      '$sourceText\n시간별·주간 미래 가시거리 예보로 확대하지 않아요.\n\n$visibilityRanges';
}

String _snowDepthValue(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _snowDepthDetail(CurrentWeather current) {
  final depth =
      current.snowDepthStatus == 'UNAVAILABLE' ? null : current.snowDepthCm;
  if (depth == null) {
    return '기상청의 현재 적설 관측값을 받지 못했어요. 예보 신적설이나 지난 날 최심신적설로 대신 채우지 않아요.';
  }
  final station = current.snowDepthStationName?.trim();
  final source = [
    if (station != null && station.isNotEmpty) '$station 관측소',
    if (current.snowDepthStationDistanceKm case final distance?)
      '요청 위치에서 ${distance.toStringAsFixed(1)}km',
    if (_koreaObservationClock(current.snowDepthObservedAt) case final time?)
      time,
  ].join(' · ');
  return '기상청 관측소에서 측정한 현재 총 적설은 ${_snowDepthValue(depth)}cm예요.'
      '${source.isEmpty ? '' : '\n$source'}\n선택한 위치에서 직접 측정한 값은 아니며, 앞으로 새로 쌓일 눈의 예보 신적설과 달라요.';
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
  return '실외 습도 · ${humidityDescription(value)}';
}

String _windLevel(double? value) {
  if (value == null) return '현재 풍속 수준을 확인하기 어려워요';
  return '바람 · ${windDescription(value)}';
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

const _metricValueStyle =
    TextStyle(fontSize: 13, fontWeight: FontWeight.normal);
const _metricStatusStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w800);

TextSpan _valueSpanFor(_WeatherMetric metric) {
  final lineBreak = metric.value.indexOf('\n');
  if (lineBreak != -1) {
    return TextSpan(children: [
      TextSpan(
        text: metric.value.substring(0, lineBreak),
        style: _metricStatusStyle,
      ),
      TextSpan(
        text: metric.value.substring(lineBreak),
        style: _metricValueStyle,
      ),
    ]);
  }
  final isLevel = {'대기질', '대기정체'}.contains(metric.label) &&
      const {'좋음', '보통', '나쁨', '매우 나쁨', '낮음', '높음', '매우 높음'}
          .contains(metric.value);
  return TextSpan(
    text: metric.value,
    style: metric.label == '일출·일몰' || isLevel
        ? _metricStatusStyle
        : _metricValueStyle,
  );
}

double _equalMetricHeight(
  BuildContext context,
  Iterable<_WeatherMetric> metrics,
  double itemWidth,
) {
  final defaultStyle = DefaultTextStyle.of(context).style;
  final labelStyle = defaultStyle.merge(Theme.of(context).textTheme.bodySmall);
  final textScaler = MediaQuery.textScalerOf(context);
  final textDirection = Directionality.of(context);

  double textHeight(TextSpan span) {
    final painter = TextPainter(
      text: TextSpan(style: defaultStyle, children: [span]),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: itemWidth - 14);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  var tallest = 0.0;
  for (final metric in metrics) {
    final height = 8 +
        32 +
        textHeight(TextSpan(text: metric.label, style: labelStyle)) +
        3 +
        textHeight(_valueSpanFor(metric)) +
        10;
    if (height > tallest) tallest = height;
  }
  return tallest.ceilToDouble() + 2;
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
              Text.rich(_valueSpanFor(metric)),
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
