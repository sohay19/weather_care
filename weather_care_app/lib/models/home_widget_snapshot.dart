import 'dart:convert';

import '../utils/korea_date.dart';
import 'recommendation.dart';
import 'weather.dart';

class HomeWidgetPreparation {
  final String type;
  final String label;

  const HomeWidgetPreparation({required this.type, required this.label});

  Map<String, dynamic> toJson() => {'type': type, 'label': label};
}

class HomeWidgetSnapshot {
  static const schemaVersion = 1;

  final String region;
  final String refreshTime;
  final String condition;
  final String currentTemperature;
  final String apparentTemperature;
  final String minimumTemperature;
  final String maximumTemperature;
  final String shortMessage;
  final String brief;
  final String nextTime;
  final String nextCondition;
  final String nextTemperature;
  final List<HomeWidgetPreparation> preparations;

  const HomeWidgetSnapshot({
    required this.region,
    required this.refreshTime,
    required this.condition,
    required this.currentTemperature,
    required this.apparentTemperature,
    required this.minimumTemperature,
    required this.maximumTemperature,
    required this.shortMessage,
    required this.brief,
    required this.nextTime,
    required this.nextCondition,
    required this.nextTemperature,
    required this.preparations,
  });

  factory HomeWidgetSnapshot.fromWeather({
    required TodayWeatherResponse today,
    WeeklyWeatherResponse? weekly,
    DateTime? now,
  }) {
    final instant = now ?? DateTime.now();
    final daily = _todayForecast(weekly?.days ?? const [], instant);
    final activeRecommendations = List<WeatherRecommendation>.from(
      today.recommendations.where((item) => item.recommended),
    )..sort((a, b) => b.priority.compareTo(a.priority));
    final distinctPreparations = <RecommendationType>{};
    final preparations = activeRecommendations
        .where((item) => distinctPreparations.add(item.type))
        .take(3)
        .map(
          (item) => HomeWidgetPreparation(
            type: item.type.apiName,
            label: item.type.label,
          ),
        )
        .toList(growable: false);
    final brief = _singleSpaced(today.brief);
    final next = today.nextForecast;

    return HomeWidgetSnapshot(
      region: compactWidgetRegionName(today.region.name),
      refreshTime: widgetRefreshTime(today.generatedAt, fallback: instant),
      condition: widgetWeatherCondition(today.current.sky),
      currentTemperature: _temperature(today.current.temperature),
      apparentTemperature: _temperature(
          today.current.apparentTemperature ?? today.current.temperature),
      minimumTemperature: _temperature(daily?.min),
      maximumTemperature: _temperature(daily?.max),
      shortMessage: activeRecommendations.isNotEmpty
          ? activeRecommendations.first.title.trim()
          : _shortMessage(brief),
      brief: brief.isEmpty ? '외출 전에 시간별 예보를 확인하세요.' : brief,
      nextTime: widgetForecastTime(next?.forecastAt ?? next?.issuedAt),
      nextCondition: widgetWeatherCondition(next?.sky ?? today.current.sky),
      nextTemperature: _temperature(next?.temperature),
      preparations: preparations,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'region': region,
        'refreshTime': refreshTime,
        'condition': condition,
        'currentTemperature': currentTemperature,
        'apparentTemperature': apparentTemperature,
        'minimumTemperature': minimumTemperature,
        'maximumTemperature': maximumTemperature,
        'shortMessage': shortMessage,
        'brief': brief,
        'nextTime': nextTime,
        'nextCondition': nextCondition,
        'nextTemperature': nextTemperature,
        'preparations': preparations.map((item) => item.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());
}

String compactWidgetRegionName(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.length >= 3 && _isProvinceLevel(parts.first)) {
    return parts.skip(1).join(' ');
  }
  return parts.where((part) => part.isNotEmpty).join(' ');
}

String widgetRefreshTime(String? value, {required DateTime fallback}) {
  final parsed = _koreaTime(value) ?? _toKorea(fallback);
  return '${_dayPeriod(parsed)} ${_hour12(parsed.hour)}:'
      '${parsed.minute.toString().padLeft(2, '0')} 기준';
}

String widgetForecastTime(String? value) {
  final parsed = _koreaTime(value);
  if (parsed == null) return '예보 준비 중';
  final time = parsed.minute == 0
      ? '${_hour12(parsed.hour)}시'
      : '${_hour12(parsed.hour)}:'
          '${parsed.minute.toString().padLeft(2, '0')}';
  return '${_dayPeriod(parsed)} $time';
}

String widgetWeatherCondition(String? value) {
  final normalized = (value ?? '').trim().toLowerCase().replaceAll(' ', '');
  if (normalized.contains('빗방울/눈날림')) return 'lightWintryMix';
  if (normalized.contains('비/눈') ||
      normalized.contains('진눈깨비') ||
      normalized.contains('rain/snow') ||
      normalized.contains('sleet')) {
    return 'wintryMix';
  }
  if (normalized.contains('소나기') || normalized.contains('shower')) {
    return 'shower';
  }
  if (normalized.contains('빗방울') ||
      normalized.contains('이슬비') ||
      normalized.contains('가랑비') ||
      normalized.contains('약한비') ||
      normalized.contains('drizzle')) {
    return 'drizzle';
  }
  if (normalized.contains('비') || normalized.contains('rain')) return 'rain';
  if (normalized.contains('눈날림') || normalized.contains('flurry')) {
    return 'snowFlurry';
  }
  if (normalized.contains('눈') || normalized.contains('snow')) return 'snow';
  if (normalized.contains('구름많음') || normalized.contains('partlycloudy')) {
    return 'partlyCloudy';
  }
  if (normalized.contains('흐림') ||
      normalized.contains('overcast') ||
      normalized.contains('cloudy') ||
      normalized.contains('구름')) {
    return 'overcast';
  }
  if (normalized.contains('맑음') ||
      normalized.contains('clear') ||
      normalized.contains('sunny')) {
    return 'clear';
  }
  return 'unknown';
}

WeeklyForecastItem? _todayForecast(
  List<WeeklyForecastItem> days,
  DateTime now,
) {
  final today = dateInKorea(now);
  for (final day in days) {
    if (!day.historical && day.forecastDate == today) return day;
  }
  for (final day in days) {
    if (!day.historical && (day.min != null || day.max != null)) return day;
  }
  return null;
}

String _temperature(double? value) {
  if (value == null || !value.isFinite) return '--°';
  final number = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  return '$number°';
}

String _shortMessage(String brief) {
  if (brief.isEmpty) return '시간별 예보를 확인하세요';
  final sentenceEnd = brief.indexOf(RegExp(r'[.!?。]'));
  final sentence = sentenceEnd > 0 ? brief.substring(0, sentenceEnd) : brief;
  return sentence.length <= 22 ? sentence : '${sentence.substring(0, 21)}…';
}

String _singleSpaced(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

DateTime? _koreaTime(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final raw = value.trim();
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final hasZone =
      RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(raw);
  return hasZone ? _toKorea(parsed) : parsed;
}

DateTime _toKorea(DateTime value) =>
    value.toUtc().add(const Duration(hours: 9));

String _dayPeriod(DateTime value) => value.hour < 12 ? '오전' : '오후';

int _hour12(int hour) {
  final converted = hour % 12;
  return converted == 0 ? 12 : converted;
}

bool _isProvinceLevel(String value) =>
    value.endsWith('특별시') ||
    value.endsWith('광역시') ||
    value.endsWith('특별자치시') ||
    value.endsWith('특별자치도') ||
    value.endsWith('도');
