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
  final double apparentTemperature;
  final double? humidity;
  final double? windSpeed;
  final double? uvIndex;
  final int? pm10;
  final int? pm25;
  final String? sky;

  const CurrentWeather({
    required this.temperature,
    required this.apparentTemperature,
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
      apparentTemperature: (c['apparentTemperature'] as num?)?.toDouble() ?? 0,
      humidity: (c['humidity'] as num?)?.toDouble(),
      windSpeed: (c['windSpeed'] as num?)?.toDouble(),
      uvIndex: (c['uvIndex'] as num?)?.toDouble(),
      pm10: (c['pm10'] as num?)?.toInt(),
      pm25: (c['pm25'] as num?)?.toInt(),
      sky: c['skyCondition']?.toString(),
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
  final WeatherRegion region;
  final String brief;
  final CurrentWeather current;
  final List<WeatherRecommendation> recommendations;
  final List<LifestyleMessage> lifestyleMessages;
  final List<TimelineItem> timeline;

  const TodayWeatherResponse({
    required this.region,
    required this.brief,
    required this.current,
    required this.recommendations,
    required this.lifestyleMessages,
    required this.timeline,
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

    return TodayWeatherResponse(
      region: WeatherRegion.fromJson(
        json['region'] as Map<String, dynamic>? ?? {'name': '수원', 'nx': 60, 'ny': 121},
      ),
      brief: json['brief']?.toString() ?? '오늘은 덥다가 퇴근할 때 비가 와요.',
      current: CurrentWeather.fromJson(json),
      recommendations: recs,
      lifestyleMessages: lifestyles,
      timeline: timeline,
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
                .take(2)
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

  const ComparisonResponse({required this.comparisonAvailable, required this.payload});

  factory ComparisonResponse.fromJson(Map<String, dynamic> json) {
    return ComparisonResponse(
      comparisonAvailable: json['comparisonAvailable'] == true,
      payload: Map<String, dynamic>.from(json),
    );
  }
}

