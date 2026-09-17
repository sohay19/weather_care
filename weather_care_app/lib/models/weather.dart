import 'recommendation.dart';
import 'lifestyle_message.dart';
import 'precipitation.dart';

class WeatherRegion {
  final int nx;
  final int ny;
  final String name;

  const WeatherRegion({
    required this.nx,
    required this.ny,
    required this.name,
  });

  String get id => '${nx}_$ny';

  factory WeatherRegion.fromJson(Map<String, dynamic> json) {
    return WeatherRegion(
      nx: (json['nx'] as num?)?.toInt() ?? 60,
      ny: (json['ny'] as num?)?.toInt() ?? 121,
      name: json['name']?.toString() ?? '수원',
    );
  }
}

class CurrentWeather {
  final double? temperature;
  final String? forecastAt;
  final String? issuedAt;
  final double? apparentTemperature;
  final String? apparentTemperatureSource;
  final double? humidity;
  final double? windSpeed;
  final double? uvIndex;
  final int? pm10;
  final int? pm25;
  final String? sky;
  final String? airQualityStationName;
  final String? airQualityObservedAt;

  const CurrentWeather({
    required this.temperature,
    this.forecastAt,
    this.issuedAt,
    this.apparentTemperature,
    this.apparentTemperatureSource,
    this.humidity,
    this.windSpeed,
    this.uvIndex,
    this.pm10,
    this.pm25,
    this.sky,
    this.airQualityStationName,
    this.airQualityObservedAt,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    final c = json['current'] ?? {};
    return CurrentWeather(
      temperature: (c['temperature'] as num?)?.toDouble(),
      forecastAt: c['forecastAt']?.toString(),
      issuedAt: c['issuedAt']?.toString(),
      apparentTemperature: (c['apparentTemperature'] as num?)?.toDouble(),
      apparentTemperatureSource: c['apparentTemperatureSource']?.toString(),
      humidity: (c['humidity'] as num?)?.toDouble(),
      windSpeed: (c['windSpeed'] as num?)?.toDouble(),
      uvIndex: (c['uvIndex'] as num?)?.toDouble(),
      pm10: (c['pm10'] as num?)?.toInt(),
      pm25: (c['pm25'] as num?)?.toInt(),
      sky: c['skyCondition']?.toString(),
      airQualityStationName: _optionalText(c['airQualityStationName']),
      airQualityObservedAt: _optionalText(c['airQualityObservedAt']),
    );
  }
}

class HourlyWeatherItem {
  final String time;
  final PrecipitationPeriod? precipitationPeriod;
  final bool precipitationPeriodProvided;
  final String? forecastDate;
  final double? temperature;
  final double? apparentTemperature;
  final double? precipitationProbability;
  final double? precipitationAmount;
  final String? precipitationAmountLabel;
  final bool? snowExpected;
  final double? snowfallAmount;
  final String? snowfallAmountLabel;
  final double? windSpeed;
  final double? uvIndex;
  final int? pm10;
  final int? pm25;
  final String? skyCondition;

  const HourlyWeatherItem({
    required this.time,
    this.precipitationPeriod,
    this.precipitationPeriodProvided = false,
    this.forecastDate,
    required this.temperature,
    this.apparentTemperature,
    required this.precipitationProbability,
    required this.precipitationAmount,
    this.precipitationAmountLabel,
    required this.snowExpected,
    required this.snowfallAmount,
    this.snowfallAmountLabel,
    required this.windSpeed,
    this.uvIndex,
    this.pm10,
    this.pm25,
    required this.skyCondition,
  });

  factory HourlyWeatherItem.fromJson(Map<String, dynamic> json) {
    final observedAt =
        json['forecastAt']?.toString() ?? json['observedAt']?.toString() ?? '';
    final parsed =
        observedAt.contains('T') ? DateTime.tryParse(observedAt) : null;
    final inKorea =
        parsed?.isUtc == true ? parsed!.add(const Duration(hours: 9)) : parsed;
    final parsedTime = inKorea?.hour.toString().padLeft(2, '0') ?? '--';
    final parsedDate = inKorea == null
        ? null
        : '${inKorea.year.toString().padLeft(4, '0')}-'
            '${inKorea.month.toString().padLeft(2, '0')}-'
            '${inKorea.day.toString().padLeft(2, '0')}';
    final snowfallAmount = _optionalNumber(json['snowfallAmount']);
    final legacySnowProbability = _optionalNumber(json['snowProbability']);
    final explicitSnowExpected = json['snowExpected'];
    return HourlyWeatherItem(
      time: json['time']?.toString() ?? parsedTime,
      precipitationPeriod:
          PrecipitationPeriod.fromJson(json['precipitationPeriod'], observedAt),
      precipitationPeriodProvided: json.containsKey('precipitationPeriod'),
      forecastDate: json['forecastDate']?.toString() ?? parsedDate,
      temperature: _optionalNumber(json['temperature']),
      apparentTemperature: _optionalNumber(json['apparentTemperature']),
      precipitationProbability:
          _optionalNumber(json['precipitationProbability']),
      precipitationAmount: _optionalNumber(json['precipitationAmount']),
      precipitationAmountLabel: _amountRangeLabel(
        json['precipitationAmountRange'],
        'mm',
      ),
      snowExpected: explicitSnowExpected == true ||
              (legacySnowProbability != null && legacySnowProbability > 0) ||
              (snowfallAmount != null && snowfallAmount > 0)
          ? true
          : explicitSnowExpected is bool
              ? explicitSnowExpected
              : legacySnowProbability == null
                  ? null
                  : false,
      snowfallAmount: snowfallAmount,
      snowfallAmountLabel: _amountRangeLabel(
        json['snowfallAmountRange'],
        'cm',
      ),
      windSpeed: _optionalNumber(json['windSpeed']),
      uvIndex: _optionalNumber(json['uvIndex']),
      pm10: _optionalNumber(json['pm10'])?.toInt(),
      pm25: _optionalNumber(json['pm25'])?.toInt(),
      skyCondition: _optionalText(json['skyCondition']),
    );
  }
}

double? _optionalNumber(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;

String? _optionalText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

String? _amountRangeLabel(Object? raw, String fallbackUnit) {
  if (raw is! Map<String, dynamic>) return null;
  final type = raw['type']?.toString();
  final min = _optionalNumber(raw['min']);
  final max = _optionalNumber(raw['max']);
  final unit = raw['unit']?.toString() == 'CM' ? 'cm' : fallbackUnit;
  String number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  return switch (type) {
    'NONE' => '0$unit',
    'LESS_THAN' when max != null => '${number(max)}$unit 미만',
    'RANGE' when min != null && max != null =>
      '${number(min)}~${number(max)}$unit',
    'AT_LEAST' when min != null => '${number(min)}$unit 이상',
    'VALUE' when min != null => '${number(min)}$unit',
    _ => null,
  };
}

class TimelineItem {
  final String timeLabel;
  final String stateLabel;
  final String detail;
  final List<WeatherRecommendation> recommendations;

  const TimelineItem({
    required this.timeLabel,
    required this.stateLabel,
    required this.detail,
    required this.recommendations,
  });
}

class WeeklyForecastItem {
  final String date;
  final String? forecastDate;
  final String? weatherLabel;
  final bool? weatherDataComplete;
  final DailyPrecipitationDetail? precipitationDetail;
  final double? min;
  final double? max;
  final String? minTemperatureSource;
  final String? maxTemperatureSource;
  final double? averageHumidity;
  final double? maximumWindSpeed;
  final double? maximumUvIndex;
  final double? snowfallAmount;
  final WeeklyAirQualityForecast? airQualityForecast;
  final String? forecastSource;
  final String? issuedAt;
  final String? recordedAt;
  final bool historical;
  final String? observationStationId;
  final double? observationDistanceKm;
  final bool recommendationsAvailable;
  final List<WeatherRecommendation> recommendations;

  const WeeklyForecastItem({
    required this.date,
    this.forecastDate,
    required this.weatherLabel,
    this.weatherDataComplete,
    this.precipitationDetail,
    required this.min,
    required this.max,
    this.minTemperatureSource,
    this.maxTemperatureSource,
    this.averageHumidity,
    this.maximumWindSpeed,
    this.maximumUvIndex,
    this.snowfallAmount,
    this.airQualityForecast,
    this.forecastSource,
    this.issuedAt,
    this.recordedAt,
    this.historical = false,
    this.observationStationId,
    this.observationDistanceKm,
    this.recommendationsAvailable = true,
    required this.recommendations,
  });

  factory WeeklyForecastItem.fromJson(Map<String, dynamic> json) {
    var min = _weeklyNumber(json['min']);
    var max = _weeklyNumber(json['max']);
    if (min != null && max != null && min > max) {
      min = null;
      max = null;
    }
    final raw = json['recommendations'];
    final valid = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .where(_validWeeklyRecommendation)
            .toList()
        : <Map<String, dynamic>>[];
    final seen = <RecommendationType>{};
    final active = valid
        .map(WeatherRecommendation.fromJson)
        .where((item) => item.recommended && seen.add(item.type))
        .take(3)
        .toList();
    return WeeklyForecastItem(
      date: _optionalText(json['date']) ?? '',
      forecastDate: _optionalText(json['forecastDate']),
      weatherLabel: _optionalText(json['weatherLabel']),
      weatherDataComplete: json['weatherDataComplete'] is bool
          ? json['weatherDataComplete'] as bool
          : null,
      precipitationDetail:
          DailyPrecipitationDetail.fromJson(json['precipitationDetail']),
      min: min,
      max: max,
      minTemperatureSource: _optionalText(json['minTemperatureSource']),
      maxTemperatureSource: _optionalText(json['maxTemperatureSource']),
      averageHumidity: _weeklyNumber(json['averageHumidity']),
      maximumWindSpeed: _weeklyNumber(json['maximumWindSpeed']),
      maximumUvIndex: _weeklyNumber(json['maximumUvIndex']),
      snowfallAmount: _weeklyNumber(json['snowfallAmount']),
      airQualityForecast:
          WeeklyAirQualityForecast.fromJson(json['airQualityForecast']),
      forecastSource: _optionalText(json['forecastSource']),
      issuedAt: _optionalText(json['issuedAt']),
      recordedAt: _optionalText(json['recordedAt']),
      historical: json['historical'] == true,
      observationStationId: _optionalText(json['observationStationId']),
      observationDistanceKm: _weeklyNumber(json['observationDistanceKm']),
      recommendationsAvailable: raw is List && valid.length == raw.length,
      recommendations: active,
    );
  }
}

class WeeklyAirQualityForecast {
  final String? pm10Grade;
  final String? pm25Grade;
  final String? ozoneGrade;
  final bool yellowDustMentioned;
  final String? confidence;

  const WeeklyAirQualityForecast({
    this.pm10Grade,
    this.pm25Grade,
    this.ozoneGrade,
    this.yellowDustMentioned = false,
    this.confidence,
  });

  static WeeklyAirQualityForecast? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final forecast = WeeklyAirQualityForecast(
      pm10Grade: _optionalText(value['pm10Grade']),
      pm25Grade: _optionalText(value['pm25Grade']),
      ozoneGrade: _optionalText(value['ozoneGrade']),
      yellowDustMentioned: value['yellowDustMentioned'] == true,
      confidence: switch (_optionalText(value['confidence'])) {
        '높음' => '높음',
        '낮음' => '낮음',
        _ => null,
      },
    );
    return forecast.pm10Grade == null &&
            forecast.pm25Grade == null &&
            forecast.ozoneGrade == null &&
            !forecast.yellowDustMentioned &&
            forecast.confidence == null
        ? null
        : forecast;
  }
}

double? _weeklyNumber(Object? value) {
  final number =
      value is String ? double.tryParse(value.trim()) : _optionalNumber(value);
  return number?.isFinite == true ? number : null;
}

bool _validWeeklyRecommendation(Map<String, dynamic> json) {
  if (!RecommendationType.values.any((type) => type.apiName == json['type']) ||
      json['recommended'] is! bool) {
    return false;
  }
  if (json['priority'] != null && _optionalNumber(json['priority']) == null) {
    return false;
  }
  for (final key in ['title', 'description', 'validFrom', 'validUntil']) {
    if (json[key] != null && json[key] is! String) return false;
  }
  return true;
}

class TodayWeatherResponse {
  final String dataSource;
  final WeatherRegion region;
  final String brief;
  final String? briefExpiresAt;
  final CurrentWeather current;
  final List<WeatherRecommendation> recommendations;
  final List<LifestyleMessage> lifestyleMessages;
  final List<WeatherMessagePart> dataStatusMessages;
  final List<TimelineItem> timeline;
  final List<HourlyWeatherItem> hourly;

  const TodayWeatherResponse({
    required this.dataSource,
    required this.region,
    required this.brief,
    this.briefExpiresAt,
    required this.current,
    required this.recommendations,
    required this.lifestyleMessages,
    this.dataStatusMessages = const [],
    required this.timeline,
    required this.hourly,
  });

  TodayWeatherResponse withRegionName(String name) => TodayWeatherResponse(
        dataSource: dataSource,
        region: WeatherRegion(nx: region.nx, ny: region.ny, name: name),
        brief: brief,
        briefExpiresAt: briefExpiresAt,
        current: current,
        recommendations: recommendations,
        lifestyleMessages: lifestyleMessages,
        dataStatusMessages: dataStatusMessages,
        timeline: timeline,
        hourly: hourly,
      );

  factory TodayWeatherResponse.fromJson(Map<String, dynamic> json) {
    final recs = (json['recommendations'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => WeatherRecommendation.fromJson(e))
        .toList();
    final lifestyles = (json['lifestyleMessages'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => LifestyleMessage.fromJson(e))
        .toList();
    final dataStatusMessages =
        (json['dataStatusMessages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(WeatherMessagePart.fromJson)
            .where((part) => part.text.isNotEmpty)
            .toList();
    final timeline = (json['timeline'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => TimelineItem(
            timeLabel: e['timeLabel']?.toString() ?? '',
            stateLabel: e['stateLabel']?.toString() ?? '',
            detail: e['detail']?.toString() ?? '',
            recommendations: ((e['recommendations'] as List<dynamic>? ?? [])
                    .whereType<Map<String, dynamic>>()
                    .map((x) => WeatherRecommendation.fromJson(x))
                    .toList())
                .take(3)
                .toList(),
          ),
        )
        .toList();
    final hourly = (json['hourly'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(HourlyWeatherItem.fromJson)
        .toList();

    return TodayWeatherResponse(
      dataSource: json['dataSource']?.toString() ?? '서버 데이터',
      region: WeatherRegion.fromJson(
        json['region'] as Map<String, dynamic>? ??
            {'name': '수원', 'nx': 60, 'ny': 121},
      ),
      brief: json['brief']?.toString() ?? '외출 전에 시간별 예보를 확인하세요.',
      briefExpiresAt: json['briefExpiresAt']?.toString(),
      current: CurrentWeather.fromJson(json),
      recommendations: recs,
      lifestyleMessages: lifestyles,
      dataStatusMessages: dataStatusMessages,
      timeline: timeline,
      hourly: hourly,
    );
  }
}

class WeeklyWeatherResponse {
  final List<WeeklyForecastItem> days;

  const WeeklyWeatherResponse({required this.days});

  factory WeeklyWeatherResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['days'];
    final days = (raw is List ? raw : const [])
        .whereType<Map<String, dynamic>>()
        .map(WeeklyForecastItem.fromJson)
        .toList();
    return WeeklyWeatherResponse(days: days);
  }
}

class ComparisonResponse {
  final bool comparisonAvailable;
  final String? targetDate;
  final ComparisonWeatherSnapshot? current;
  final ComparisonWeatherSnapshot? comparison;
  final ComparisonBasis? basis;

  const ComparisonResponse({
    required this.comparisonAvailable,
    this.targetDate,
    this.current,
    this.comparison,
    this.basis,
  });

  const ComparisonResponse.unavailable()
      : comparisonAvailable = false,
        targetDate = null,
        current = null,
        comparison = null,
        basis = null;

  factory ComparisonResponse.fromJson(Map<String, dynamic> json) {
    final currentJson = json['current'];
    final comparisonJson = json['comparison'];
    final basisJson = json['basis'];
    return ComparisonResponse(
      comparisonAvailable: json['comparisonAvailable'] == true &&
          currentJson is Map &&
          comparisonJson is Map,
      targetDate: json['targetDate']?.toString(),
      current: currentJson is Map
          ? ComparisonWeatherSnapshot.fromJson(
              Map<String, dynamic>.from(currentJson),
            )
          : null,
      comparison: comparisonJson is Map
          ? ComparisonWeatherSnapshot.fromJson(
              Map<String, dynamic>.from(comparisonJson),
            )
          : null,
      basis: basisJson is Map
          ? ComparisonBasis.fromJson(Map<String, dynamic>.from(basisJson))
          : null,
    );
  }
}

class ComparisonBasis {
  final String? provider;
  final String? dataRole;
  final String? stationId;
  final double? distanceKm;
  final String? currentObservedAt;
  final String? comparisonObservedAt;

  const ComparisonBasis({
    this.provider,
    this.dataRole,
    this.stationId,
    this.distanceKm,
    this.currentObservedAt,
    this.comparisonObservedAt,
  });

  factory ComparisonBasis.fromJson(Map<String, dynamic> json) {
    return ComparisonBasis(
      provider: json['provider']?.toString(),
      dataRole: json['dataRole']?.toString(),
      stationId: json['stationId']?.toString(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      currentObservedAt: json['currentObservedAt']?.toString(),
      comparisonObservedAt: json['comparisonObservedAt']?.toString(),
    );
  }
}

class ComparisonWeatherSnapshot {
  final double? temperature;
  final double? apparentTemperature;
  final int? pm10;
  final int? pm25;
  final String? skyCondition;

  const ComparisonWeatherSnapshot({
    this.temperature,
    this.apparentTemperature,
    this.pm10,
    this.pm25,
    this.skyCondition,
  });

  factory ComparisonWeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return ComparisonWeatherSnapshot(
      temperature: (json['temperature'] as num?)?.toDouble(),
      apparentTemperature: ((json['apparentTemperature'] ??
              json['apparent_temperature']) as num?)
          ?.toDouble(),
      pm10: (json['pm10'] as num?)?.toInt(),
      pm25: (json['pm25'] as num?)?.toInt(),
      skyCondition: (json['skyCondition'] ?? json['summary'])?.toString(),
    );
  }
}
