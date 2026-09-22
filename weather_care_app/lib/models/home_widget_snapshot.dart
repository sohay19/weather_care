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

class HomeWidgetBriefingEntry {
  final String briefingId;
  final String sceneId;
  final String validFrom;
  final String validUntil;
  final String shortMessage;
  final String mediumMessage;
  final String longMessage;
  final String? targetFrom;
  final String? targetUntil;
  final String? action;
  final String? copyVariantKey;
  final List<String> recommendedItems;

  const HomeWidgetBriefingEntry({
    required this.briefingId,
    required this.sceneId,
    required this.validFrom,
    required this.validUntil,
    required this.shortMessage,
    required this.mediumMessage,
    required this.longMessage,
    this.targetFrom,
    this.targetUntil,
    this.action,
    this.copyVariantKey,
    this.recommendedItems = const [],
  });

  factory HomeWidgetBriefingEntry.fromTimeline(
    BriefingTimelineEntry entry,
  ) =>
      HomeWidgetBriefingEntry(
        briefingId: entry.briefingId,
        sceneId: entry.sceneId,
        validFrom: entry.validFrom,
        validUntil: entry.validUntil,
        shortMessage: entry.copy.short,
        mediumMessage: entry.copy.medium,
        longMessage: entry.copy.long,
        targetFrom: entry.targetFrom,
        targetUntil: entry.targetUntil,
        action: entry.action,
        copyVariantKey: entry.copyVariantKey,
        recommendedItems: entry.recommendedItems,
      );

  factory HomeWidgetBriefingEntry.fromBriefing(
    CanonicalBriefing briefing,
  ) =>
      HomeWidgetBriefingEntry(
        briefingId: briefing.briefingId,
        sceneId: briefing.sceneId,
        validFrom: briefing.validFrom,
        validUntil: briefing.validUntil,
        shortMessage: briefing.copy.short,
        mediumMessage: briefing.copy.medium,
        longMessage: briefing.copy.long,
        targetFrom: briefing.targetFrom,
        targetUntil: briefing.targetUntil,
        action: briefing.action,
        copyVariantKey: briefing.copyVariantKey,
        recommendedItems: briefing.recommendedItems,
      );

  Map<String, dynamic> toJson() => {
        'briefingId': briefingId,
        'sceneId': sceneId,
        'validFrom': validFrom,
        'validUntil': validUntil,
        'shortMessage': shortMessage,
        'mediumMessage': mediumMessage,
        'longMessage': longMessage,
        if (targetFrom != null) 'targetFrom': targetFrom,
        if (targetUntil != null) 'targetUntil': targetUntil,
        if (action != null) 'action': action,
        if (copyVariantKey != null) 'copyVariantKey': copyVariantKey,
        'recommendedItems': recommendedItems,
      };
}

class HomeWidgetSnapshot {
  static const schemaVersion = 3;

  final String generatedAt;
  final String locationKey;
  final String briefingId;
  final String sceneId;
  final String validFrom;
  final String validUntil;
  final String nextBriefingBoundary;
  final String dataFreshUntil;
  final List<HomeWidgetBriefingEntry> briefingTimeline;
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
  final List<HomeWidgetPreparation> preparationCatalog;

  const HomeWidgetSnapshot({
    required this.generatedAt,
    required this.locationKey,
    required this.briefingId,
    required this.sceneId,
    required this.validFrom,
    required this.validUntil,
    required this.nextBriefingBoundary,
    required this.dataFreshUntil,
    required this.briefingTimeline,
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
    required this.preparationCatalog,
  });

  factory HomeWidgetSnapshot.fromWeather({
    required TodayWeatherResponse today,
    WeeklyWeatherResponse? weekly,
    DateTime? now,
  }) {
    final instant = now ?? DateTime.now();
    final daily = _todayForecast(weekly?.days ?? const [], instant);
    final fallbackRecommendations = List<WeatherRecommendation>.from(
      today.recommendations.where((item) => item.recommended),
    )..sort((a, b) => b.priority.compareTo(a.priority));
    final briefingTimeline = today.briefingTimeline
        .map(HomeWidgetBriefingEntry.fromTimeline)
        .toList();
    if (briefingTimeline.isEmpty && today.briefing != null) {
      briefingTimeline.add(
        HomeWidgetBriefingEntry.fromBriefing(today.briefing!),
      );
    }
    final activeBriefing = _activeBriefing(briefingTimeline, instant);
    final hasCanonicalBriefing = briefingTimeline.isNotEmpty;
    final fallbackTypes =
        fallbackRecommendations.map((item) => item.type.apiName);
    final currentTypes = hasCanonicalBriefing
        ? activeBriefing?.recommendedItems ?? const <String>[]
        : fallbackTypes;
    final catalogTypes = hasCanonicalBriefing
        ? briefingTimeline.expand((entry) => entry.recommendedItems)
        : fallbackTypes;
    final preparations = _preparationsFromTypes(currentTypes, limit: 3);
    final preparationCatalog = _preparationsFromTypes(catalogTypes);
    final fallbackBrief = _singleSpaced(today.brief);
    final brief = _singleSpaced(
      activeBriefing?.longMessage ??
          (today.briefing == null ? fallbackBrief : ''),
    );
    final next = today.nextForecast;
    final validUntil = activeBriefing?.validUntil ?? '';
    final dataFreshUntil = briefingTimeline.isEmpty
        ? validUntil
        : briefingTimeline.last.validUntil;

    return HomeWidgetSnapshot(
      generatedAt: today.generatedAt ?? instant.toUtc().toIso8601String(),
      locationKey: today.briefing?.locationKey ?? today.region.id,
      briefingId: activeBriefing?.briefingId ?? '',
      sceneId: activeBriefing?.sceneId ?? 'UNAVAILABLE',
      validFrom: activeBriefing?.validFrom ?? '',
      validUntil: validUntil,
      nextBriefingBoundary: today.briefing?.nextBriefingBoundary ?? validUntil,
      dataFreshUntil: dataFreshUntil,
      briefingTimeline: briefingTimeline,
      region: compactWidgetRegionName(today.region.name),
      refreshTime: widgetRefreshTime(today.generatedAt, fallback: instant),
      condition: widgetWeatherCondition(today.current.sky),
      currentTemperature: _temperature(today.current.temperature),
      apparentTemperature: _temperature(
          today.current.displayedApparentTemperature ??
              today.current.temperature),
      minimumTemperature: _temperature(daily?.min),
      maximumTemperature: _temperature(daily?.max),
      shortMessage:
          _singleSpaced(activeBriefing?.shortMessage ?? '최신 날씨를 확인해 주세요.'),
      brief: brief.isEmpty ? '최신 날씨를 확인해 주세요.' : brief,
      nextTime: widgetForecastTime(next?.forecastAt ?? next?.issuedAt),
      nextCondition: widgetWeatherCondition(next?.sky ?? today.current.sky),
      nextTemperature: _temperature(next?.temperature),
      preparations: preparations,
      preparationCatalog: preparationCatalog,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'generatedAt': generatedAt,
        'locationKey': locationKey,
        'briefingId': briefingId,
        'sceneId': sceneId,
        'validFrom': validFrom,
        'validUntil': validUntil,
        'nextBriefingBoundary': nextBriefingBoundary,
        'dataFreshUntil': dataFreshUntil,
        'briefingTimeline':
            briefingTimeline.map((item) => item.toJson()).toList(),
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
        'preparationCatalog':
            preparationCatalog.map((item) => item.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());
}

List<HomeWidgetPreparation> _preparationsFromTypes(
  Iterable<String> rawTypes, {
  int? limit,
}) {
  final result = <HomeWidgetPreparation>[];
  final seen = <RecommendationType>{};
  for (final raw in rawTypes) {
    final type = recommendationTypeFromApiName(raw);
    if (type == null || !seen.add(type)) continue;
    result.add(HomeWidgetPreparation(type: type.apiName, label: type.label));
    if (limit != null && result.length >= limit) break;
  }
  return result;
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

HomeWidgetBriefingEntry? _activeBriefing(
  List<HomeWidgetBriefingEntry> entries,
  DateTime now,
) {
  for (final entry in entries) {
    final from = DateTime.tryParse(entry.validFrom);
    final until = DateTime.tryParse(entry.validUntil);
    if (from != null &&
        until != null &&
        !now.isBefore(from) &&
        now.isBefore(until)) {
      return entry;
    }
  }
  return null;
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
