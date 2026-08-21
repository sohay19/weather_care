enum LifestyleMessageType {
  rainGearUseful,
  strongSunExposure,
  veryHotAndHumid,
  laundryGood,
  coolerThanTemperature,
  outerwearUseful,
  maskUseful,
  hydrationImportant,
  sunscreenUseful,
  snowTravelCaution,
  largeTemperatureSwing,
  outdoorCaution,
  ventilationGood,
  dailyWeatherCheck,
  dailyHydration,
  flexibleDayPlan,
}

extension LifestyleMessageTypeLabel on LifestyleMessageType {
  String get title {
    return switch (this) {
      LifestyleMessageType.rainGearUseful => '비 오는 시간대를 준비해요',
      LifestyleMessageType.strongSunExposure => '햇볕 노출에 주의해요',
      LifestyleMessageType.veryHotAndHumid => '땀이 비 오듯 나는 날',
      LifestyleMessageType.laundryGood => '빨래가 잘 마르는 날',
      LifestyleMessageType.coolerThanTemperature => '아침저녁이 쌀쌀해요',
      LifestyleMessageType.outerwearUseful => '겉옷이 유용할 가능성이 높아요',
      LifestyleMessageType.maskUseful => '대기질을 확인해요',
      LifestyleMessageType.hydrationImportant => '물을 자주 마셔요',
      LifestyleMessageType.sunscreenUseful => '선크림이 필요한 날이에요',
      LifestyleMessageType.snowTravelCaution => '눈길 이동에 주의해요',
      LifestyleMessageType.largeTemperatureSwing => '하루 기온 차가 커요',
      LifestyleMessageType.outdoorCaution => '야외활동 시 주의가 필요해요',
      LifestyleMessageType.ventilationGood => '환기하기 좋은 시간이에요',
      LifestyleMessageType.dailyWeatherCheck => '시간대별 흐름을 확인해요',
      LifestyleMessageType.dailyHydration => '물 한 모금을 챙겨요',
      LifestyleMessageType.flexibleDayPlan => '여유 있게 움직여요',
    };
  }

  String get apiName {
    return switch (this) {
      LifestyleMessageType.rainGearUseful => 'RAIN_GEAR_USEFUL',
      LifestyleMessageType.strongSunExposure => 'STRONG_SUN_EXPOSURE',
      LifestyleMessageType.veryHotAndHumid => 'VERY_HOT_AND_HUMID',
      LifestyleMessageType.laundryGood => 'LAUNDRY_GOOD',
      LifestyleMessageType.coolerThanTemperature => 'COOLER_THAN_TEMPERATURE',
      LifestyleMessageType.outerwearUseful => 'OUTERWEAR_USEFUL',
      LifestyleMessageType.maskUseful => 'MASK_USEFUL',
      LifestyleMessageType.hydrationImportant => 'HYDRATION_IMPORTANT',
      LifestyleMessageType.sunscreenUseful => 'SUNSCREEN_USEFUL',
      LifestyleMessageType.snowTravelCaution => 'SNOW_TRAVEL_CAUTION',
      LifestyleMessageType.largeTemperatureSwing => 'LARGE_TEMPERATURE_SWING',
      LifestyleMessageType.outdoorCaution => 'OUTDOOR_ACTIVITY_CAUTION',
      LifestyleMessageType.ventilationGood => 'VENTILATION_GOOD',
      LifestyleMessageType.dailyWeatherCheck => 'DAILY_WEATHER_CHECK',
      LifestyleMessageType.dailyHydration => 'DAILY_HYDRATION',
      LifestyleMessageType.flexibleDayPlan => 'FLEXIBLE_DAY_PLAN',
    };
  }
}

class LifestyleMessage {
  final LifestyleMessageType type;
  final String title;
  final String? description;
  final double score;

  LifestyleMessage({
    required this.type,
    required this.title,
    this.description,
    this.score = 0,
  });

  factory LifestyleMessage.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString();
    final parsed = switch (type) {
      'RAIN_GEAR_USEFUL' => LifestyleMessageType.rainGearUseful,
      'STRONG_SUN_EXPOSURE' => LifestyleMessageType.strongSunExposure,
      'VERY_HOT_AND_HUMID' => LifestyleMessageType.veryHotAndHumid,
      'LAUNDRY_GOOD' => LifestyleMessageType.laundryGood,
      'COOLER_THAN_TEMPERATURE' => LifestyleMessageType.coolerThanTemperature,
      'OUTERWEAR_USEFUL' => LifestyleMessageType.outerwearUseful,
      'MASK_USEFUL' => LifestyleMessageType.maskUseful,
      'HYDRATION_IMPORTANT' => LifestyleMessageType.hydrationImportant,
      'SUNSCREEN_USEFUL' => LifestyleMessageType.sunscreenUseful,
      'SNOW_TRAVEL_CAUTION' => LifestyleMessageType.snowTravelCaution,
      'LARGE_TEMPERATURE_SWING' => LifestyleMessageType.largeTemperatureSwing,
      'OUTDOOR_ACTIVITY_CAUTION' => LifestyleMessageType.outdoorCaution,
      'VENTILATION_GOOD' => LifestyleMessageType.ventilationGood,
      'DAILY_WEATHER_CHECK' => LifestyleMessageType.dailyWeatherCheck,
      'DAILY_HYDRATION' => LifestyleMessageType.dailyHydration,
      'FLEXIBLE_DAY_PLAN' => LifestyleMessageType.flexibleDayPlan,
      _ => LifestyleMessageType.outdoorCaution,
    };
    return LifestyleMessage(
      type: parsed,
      title: json['title']?.toString() ?? parsed.title,
      description: json['description']?.toString(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }
}
