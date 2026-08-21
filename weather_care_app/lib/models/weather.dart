import 'recommendation.dart';
import 'lifestyle_message.dart';

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
  final double temperature;
  final double? apparentTemperature;
  final double? humidity;
  final double? windSpeed;
  final double? uvIndex;
  final int? pm10;
  final int? pm25;
  final String? sky;

  const CurrentWeather({
    required this.temperature,
    this.apparentTemperature,
    this.humidity,
    this.windSpeed,
    this.uvIndex,
    this.pm10,
    this.pm25,
    this.sky,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    final c = json['current'] ?? {};
    return CurrentWeather(
      temperature: (c['temperature'] as num?)?.toDouble() ?? 0,
      apparentTemperature: (c['apparentTemperature'] as num?)?.toDouble(),
      humidity: (c['humidity'] as num?)?.toDouble(),
      windSpeed: (c['windSpeed'] as num?)?.toDouble(),
      uvIndex: (c['uvIndex'] as num?)?.toDouble(),
      pm10: (c['pm10'] as num?)?.toInt(),
      pm25: (c['pm25'] as num?)?.toInt(),
      sky: c['skyCondition']?.toString(),
    );
  }
}

class HourlyWeatherItem {
  final String time;
  final double temperature;
  final double? apparentTemperature;
  final double precipitationProbability;
  final double precipitationAmount;
  final bool snowExpected;
  final double snowfallAmount;
  final double windSpeed;
  final double? uvIndex;
  final int? pm10;
  final int? pm25;
  final String skyCondition;

  const HourlyWeatherItem({
    required this.time,
    required this.temperature,
    this.apparentTemperature,
    required this.precipitationProbability,
    required this.precipitationAmount,
    required this.snowExpected,
    required this.snowfallAmount,
    required this.windSpeed,
    this.uvIndex,
    this.pm10,
    this.pm25,
    required this.skyCondition,
  });

  factory HourlyWeatherItem.fromJson(Map<String, dynamic> json) {
    final observedAt =
        json['forecastAt']?.toString() ?? json['observedAt']?.toString() ?? '';
    final parsedTime =
        observedAt.length >= 13 ? observedAt.substring(11, 13) : '--';
    final snowfallAmount = (json['snowfallAmount'] as num?)?.toDouble() ?? 0;
    final legacySnowProbability =
        (json['snowProbability'] as num?)?.toDouble() ?? 0;
    return HourlyWeatherItem(
      time: json['time']?.toString() ?? parsedTime,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      apparentTemperature: (json['apparentTemperature'] as num?)?.toDouble(),
      precipitationProbability:
          (json['precipitationProbability'] as num?)?.toDouble() ?? 0,
      precipitationAmount:
          (json['precipitationAmount'] as num?)?.toDouble() ?? 0,
      snowExpected: json['snowExpected'] == true ||
          legacySnowProbability > 0 ||
          snowfallAmount > 0,
      snowfallAmount: snowfallAmount,
      windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0,
      uvIndex: (json['uvIndex'] as num?)?.toDouble(),
      pm10: (json['pm10'] as num?)?.toInt(),
      pm25: (json['pm25'] as num?)?.toInt(),
      skyCondition: json['skyCondition']?.toString() ?? '맑음',
    );
  }
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
  final String weatherLabel;
  final String min;
  final String max;
  final List<WeatherRecommendation> recommendations;

  const WeeklyForecastItem({
    required this.date,
    required this.weatherLabel,
    required this.min,
    required this.max,
    required this.recommendations,
  });
}

class TodayWeatherResponse {
  final String dataSource;
  final WeatherRegion region;
  final String brief;
  final CurrentWeather current;
  final List<WeatherRecommendation> recommendations;
  final List<LifestyleMessage> lifestyleMessages;
  final List<TimelineItem> timeline;
  final List<HourlyWeatherItem> hourly;

  const TodayWeatherResponse({
    required this.dataSource,
    required this.region,
    required this.brief,
    required this.current,
    required this.recommendations,
    required this.lifestyleMessages,
    required this.timeline,
    required this.hourly,
  });

  factory TodayWeatherResponse.fromJson(Map<String, dynamic> json) {
    final recs = (json['recommendations'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => WeatherRecommendation.fromJson(e))
        .toList();
    final lifestyles = (json['lifestyleMessages'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => LifestyleMessage.fromJson(e))
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
      brief: json['brief']?.toString() ?? '오늘은 덥다가 퇴근할 때 비가 와요.',
      current: CurrentWeather.fromJson(json),
      recommendations: recs,
      lifestyleMessages: lifestyles,
      timeline: timeline,
      hourly: hourly,
    );
  }
}

class WeeklyWeatherResponse {
  final List<WeeklyForecastItem> days;

  const WeeklyWeatherResponse({required this.days});

  factory WeeklyWeatherResponse.fromJson(Map<String, dynamic> json) {
    final days = (json['days'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => WeeklyForecastItem(
            date: e['date']?.toString() ?? '',
            weatherLabel: e['weatherLabel']?.toString() ?? '맑음',
            min: e['min']?.toString() ?? '--',
            max: e['max']?.toString() ?? '--',
            recommendations: ((e['recommendations'] as List<dynamic>? ?? [])
                    .whereType<Map<String, dynamic>>()
                    .map((r) => WeatherRecommendation.fromJson(r))
                    .toList())
                .take(3)
                .toList(),
          ),
        )
        .toList();
    return WeeklyWeatherResponse(days: days);
  }
}

class ComparisonResponse {
  final bool comparisonAvailable;
  final Map<String, dynamic> payload;

  const ComparisonResponse(
      {required this.comparisonAvailable, required this.payload});

  factory ComparisonResponse.fromJson(Map<String, dynamic> json) {
    return ComparisonResponse(
      comparisonAvailable: json['comparisonAvailable'] == true,
      payload: Map<String, dynamic>.from(json),
    );
  }
}
