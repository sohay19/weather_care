enum LifestyleMessageType {
  rainGearUseful,
  strongSunExposure,
  outerwearUseful,
  maskUseful,
  hydrationImportant,
  sunscreenUseful,
  snowTravelCaution,
  veryHotAndHumid,
  coolerThanTemperature,
  largeTemperatureSwing,
  outdoorCaution,
  rainBreakWindow,
  bestOutingWindow,
  petWalkWindow,
  wetRoadCaution,
  laundryPickupDue,
  windowCloseSoon,
  rapidTemperatureDrop,
  nightWeatherCheck,
  blackIceCaution,
  unknown,
}

extension LifestyleMessageTypeLabel on LifestyleMessageType {
  String get title => switch (this) {
        LifestyleMessageType.rainGearUseful => '비와 우산 준비',
        LifestyleMessageType.strongSunExposure => '자외선과 양산',
        LifestyleMessageType.outerwearUseful => '겉옷 준비',
        LifestyleMessageType.maskUseful => '대기질과 마스크',
        LifestyleMessageType.hydrationImportant => '더위와 물 준비',
        LifestyleMessageType.sunscreenUseful => '자외선 차단제',
        LifestyleMessageType.snowTravelCaution => '새로 쌓인 눈',
        LifestyleMessageType.veryHotAndHumid => '덥고 습한 날씨',
        LifestyleMessageType.coolerThanTemperature => '기온과 바람',
        LifestyleMessageType.largeTemperatureSwing => '시간대별 기온 차',
        LifestyleMessageType.outdoorCaution => '강풍',
        LifestyleMessageType.rainBreakWindow => '비가 잠시 그치는 시간',
        LifestyleMessageType.bestOutingWindow => '외출 시간 확인',
        LifestyleMessageType.petWalkWindow => '반려견 산책계획',
        LifestyleMessageType.wetRoadCaution => '젖은 도로',
        LifestyleMessageType.laundryPickupDue => '빨래 회수',
        LifestyleMessageType.windowCloseSoon => '창문 확인',
        LifestyleMessageType.rapidTemperatureDrop => '기온 하강',
        LifestyleMessageType.nightWeatherCheck => '수면환경 확인',
        LifestyleMessageType.blackIceCaution => '블랙아이스(도로살얼음)',
        LifestyleMessageType.unknown => '날씨 안내',
      };

  String get apiName => switch (this) {
        LifestyleMessageType.rainGearUseful => 'RAIN_GEAR_USEFUL',
        LifestyleMessageType.strongSunExposure => 'STRONG_SUN_EXPOSURE',
        LifestyleMessageType.outerwearUseful => 'OUTERWEAR_USEFUL',
        LifestyleMessageType.maskUseful => 'MASK_USEFUL',
        LifestyleMessageType.hydrationImportant => 'HYDRATION_IMPORTANT',
        LifestyleMessageType.sunscreenUseful => 'SUNSCREEN_USEFUL',
        LifestyleMessageType.snowTravelCaution => 'SNOW_TRAVEL_CAUTION',
        LifestyleMessageType.veryHotAndHumid => 'VERY_HOT_AND_HUMID',
        LifestyleMessageType.coolerThanTemperature => 'COOLER_THAN_TEMPERATURE',
        LifestyleMessageType.largeTemperatureSwing => 'LARGE_TEMPERATURE_SWING',
        LifestyleMessageType.outdoorCaution => 'OUTDOOR_ACTIVITY_CAUTION',
        LifestyleMessageType.rainBreakWindow => 'RAIN_BREAK_WINDOW',
        LifestyleMessageType.bestOutingWindow => 'BEST_OUTING_WINDOW',
        LifestyleMessageType.petWalkWindow => 'PET_WALK_WINDOW',
        LifestyleMessageType.wetRoadCaution => 'WET_ROAD_CAUTION',
        LifestyleMessageType.laundryPickupDue => 'LAUNDRY_PICKUP_DUE',
        LifestyleMessageType.windowCloseSoon => 'WINDOW_CLOSE_SOON',
        LifestyleMessageType.rapidTemperatureDrop => 'RAPID_TEMPERATURE_DROP',
        LifestyleMessageType.nightWeatherCheck => 'NIGHT_WEATHER_CHECK',
        LifestyleMessageType.blackIceCaution => 'BLACK_ICE_CAUTION',
        LifestyleMessageType.unknown => 'UNKNOWN',
      };
}

enum WeatherMessageRole {
  appSuggestion,
  internalPossibility,
  officialFact,
  calculatedFact,
  dataStatus,
}

extension WeatherMessageRoleLabel on WeatherMessageRole {
  String get label => switch (this) {
        WeatherMessageRole.appSuggestion => '추천 행동',
        WeatherMessageRole.internalPossibility => '발생 가능성',
        WeatherMessageRole.officialFact => '공식 정보',
        WeatherMessageRole.calculatedFact => '앱 계산',
        WeatherMessageRole.dataStatus => '자료 상태',
      };
}

class WeatherMessagePart {
  final WeatherMessageRole role;
  final String text;
  final String? source;
  final String? validFrom;
  final String? validUntil;

  const WeatherMessagePart({
    required this.role,
    required this.text,
    this.source,
    this.validFrom,
    this.validUntil,
  });

  factory WeatherMessagePart.fromJson(Map<String, dynamic> json) {
    final role = switch (json['role']?.toString()) {
      'APP_SUGGESTION' => WeatherMessageRole.appSuggestion,
      'INTERNAL_POSSIBILITY' => WeatherMessageRole.internalPossibility,
      'OFFICIAL_FACT' => WeatherMessageRole.officialFact,
      'CALCULATED_FACT' => WeatherMessageRole.calculatedFact,
      'DATA_STATUS' => WeatherMessageRole.dataStatus,
      _ => WeatherMessageRole.dataStatus,
    };
    return WeatherMessagePart(
      role: role,
      text: json['text']?.toString() ?? '',
      source: json['source']?.toString(),
      validFrom: json['validFrom']?.toString(),
      validUntil: json['validUntil']?.toString(),
    );
  }
}

class LifestyleMessage {
  final LifestyleMessageType type;
  final String title;
  final String? description;
  final double priority;
  final List<WeatherMessagePart> parts;

  double get score => priority;

  LifestyleMessage({
    required this.type,
    required this.title,
    this.description,
    double priority = 0,
    double? score,
    List<WeatherMessagePart>? parts,
  })  : priority = score ?? priority,
        parts = parts ??
            [
              WeatherMessagePart(
                role: WeatherMessageRole.appSuggestion,
                text: title,
              ),
              if (description != null && description.isNotEmpty)
                WeatherMessagePart(
                  role: WeatherMessageRole.internalPossibility,
                  text: description,
                ),
            ];

  factory LifestyleMessage.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? '').toString();
    final parsed = _typeFromApiName(rawType);
    final title = json['title']?.toString() ?? parsed.title;
    final description = json['description']?.toString();
    final parts = (json['parts'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WeatherMessagePart.fromJson)
        .where((part) => part.text.isNotEmpty)
        .toList();
    return LifestyleMessage(
      type: parsed,
      title: title,
      description: description,
      priority: (json['priority'] as num?)?.toDouble() ??
          (json['score'] as num?)?.toDouble() ??
          0,
      parts: parts.isEmpty ? null : parts,
    );
  }
}

LifestyleMessageType _typeFromApiName(String value) => switch (value) {
      'RAIN_GEAR_USEFUL' => LifestyleMessageType.rainGearUseful,
      'STRONG_SUN_EXPOSURE' => LifestyleMessageType.strongSunExposure,
      'OUTERWEAR_USEFUL' => LifestyleMessageType.outerwearUseful,
      'MASK_USEFUL' => LifestyleMessageType.maskUseful,
      'HYDRATION_IMPORTANT' => LifestyleMessageType.hydrationImportant,
      'SUNSCREEN_USEFUL' => LifestyleMessageType.sunscreenUseful,
      'SNOW_TRAVEL_CAUTION' => LifestyleMessageType.snowTravelCaution,
      'VERY_HOT_AND_HUMID' => LifestyleMessageType.veryHotAndHumid,
      'COOLER_THAN_TEMPERATURE' => LifestyleMessageType.coolerThanTemperature,
      'LARGE_TEMPERATURE_SWING' => LifestyleMessageType.largeTemperatureSwing,
      'OUTDOOR_ACTIVITY_CAUTION' => LifestyleMessageType.outdoorCaution,
      'RAIN_BREAK_WINDOW' => LifestyleMessageType.rainBreakWindow,
      'BEST_OUTING_WINDOW' => LifestyleMessageType.bestOutingWindow,
      'PET_WALK_WINDOW' => LifestyleMessageType.petWalkWindow,
      'WET_ROAD_CAUTION' => LifestyleMessageType.wetRoadCaution,
      'LAUNDRY_PICKUP_DUE' => LifestyleMessageType.laundryPickupDue,
      'WINDOW_CLOSE_SOON' => LifestyleMessageType.windowCloseSoon,
      'RAPID_TEMPERATURE_DROP' => LifestyleMessageType.rapidTemperatureDrop,
      'NIGHT_WEATHER_CHECK' => LifestyleMessageType.nightWeatherCheck,
      'BLACK_ICE_CAUTION' => LifestyleMessageType.blackIceCaution,
      _ => LifestyleMessageType.unknown,
    };
