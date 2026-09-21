import 'package:flutter/material.dart';

enum RecommendationType {
  umbrella,
  raincoat,
  rainBoots,
  parasol,
  sunscreen,
  sunglasses,
  water,
  portableFan,
  coolingItem,
  outerwear,
  scarf,
  handWarmer,
  snowChains,
  powerBank,
  winterBoots,
  heavySnowCaution,
  mask,
}

enum RecommendationPriority {
  high,
  medium,
  low,
}

extension RecommendationTypeLabel on RecommendationType {
  String get label {
    return switch (this) {
      RecommendationType.umbrella => '우산',
      RecommendationType.raincoat => '우비',
      RecommendationType.rainBoots => '장화',
      RecommendationType.parasol => '양산',
      RecommendationType.sunscreen => '선크림',
      RecommendationType.sunglasses => '선글라스',
      RecommendationType.water => '물',
      RecommendationType.portableFan => '휴대용 선풍기',
      RecommendationType.coolingItem => '쿨링제품',
      RecommendationType.outerwear => '두꺼운 겉옷',
      RecommendationType.scarf => '목도리',
      RecommendationType.handWarmer => '핫팩',
      RecommendationType.snowChains => '스노우체인',
      RecommendationType.powerBank => '보조배터리',
      RecommendationType.winterBoots => '방한부츠',
      RecommendationType.heavySnowCaution => '많은 눈 대비',
      RecommendationType.mask => '마스크',
    };
  }

  String get title {
    return switch (this) {
      RecommendationType.umbrella => '우산 챙겨요',
      RecommendationType.raincoat => '우비 챙겨요',
      RecommendationType.rainBoots => '장화 챙겨요',
      RecommendationType.parasol => '양산 챙겨요',
      RecommendationType.sunscreen => '선크림 챙겨요',
      RecommendationType.sunglasses => '선글라스 챙겨요',
      RecommendationType.water => '물 챙겨요',
      RecommendationType.portableFan => '휴대용 선풍기 챙겨요',
      RecommendationType.coolingItem => '쿨링제품 챙겨요',
      RecommendationType.outerwear => '두꺼운 겉옷 챙겨요',
      RecommendationType.scarf => '목도리 챙겨요',
      RecommendationType.handWarmer => '핫팩 챙겨요',
      RecommendationType.snowChains => '스노우체인 챙겨요',
      RecommendationType.powerBank => '보조배터리 챙겨요',
      RecommendationType.winterBoots => '방한부츠 챙겨요',
      RecommendationType.heavySnowCaution => '많은 눈 대비',
      RecommendationType.mask => '마스크 챙겨요',
    };
  }

  IconData get icon {
    return switch (this) {
      RecommendationType.umbrella => Icons.umbrella,
      RecommendationType.raincoat => Icons.checkroom,
      RecommendationType.rainBoots => Icons.hiking,
      RecommendationType.parasol => Icons.wb_sunny,
      RecommendationType.sunscreen => Icons.spa,
      RecommendationType.sunglasses => Icons.visibility,
      RecommendationType.water => Icons.local_drink,
      RecommendationType.portableFan => Icons.air,
      RecommendationType.coolingItem => Icons.ac_unit,
      RecommendationType.outerwear => Icons.checkroom,
      RecommendationType.scarf => Icons.checkroom,
      RecommendationType.handWarmer => Icons.local_fire_department,
      RecommendationType.snowChains => Icons.directions_car,
      RecommendationType.powerBank => Icons.battery_charging_full,
      RecommendationType.winterBoots => Icons.hiking,
      RecommendationType.heavySnowCaution => Icons.ac_unit,
      RecommendationType.mask => Icons.face,
    };
  }

  String get apiName {
    return switch (this) {
      RecommendationType.umbrella => 'UMBRELLA',
      RecommendationType.raincoat => 'RAINCOAT',
      RecommendationType.rainBoots => 'RAIN_BOOTS',
      RecommendationType.parasol => 'PARASOL',
      RecommendationType.sunscreen => 'SUNSCREEN',
      RecommendationType.sunglasses => 'SUNGLASSES',
      RecommendationType.water => 'WATER',
      RecommendationType.portableFan => 'PORTABLE_FAN',
      RecommendationType.coolingItem => 'COOLING_ITEM',
      RecommendationType.outerwear => 'OUTERWEAR',
      RecommendationType.scarf => 'SCARF',
      RecommendationType.handWarmer => 'HAND_WARMER',
      RecommendationType.snowChains => 'SNOW_CHAINS',
      RecommendationType.powerBank => 'POWER_BANK',
      RecommendationType.winterBoots => 'WINTER_BOOTS',
      RecommendationType.heavySnowCaution => 'HEAVY_SNOW_CAUTION',
      RecommendationType.mask => 'MASK',
    };
  }

  String? get assetPath {
    return switch (this) {
      RecommendationType.umbrella => 'assets/icons/prep_umbrella.png',
      RecommendationType.raincoat => 'assets/icons/prep_raincoat.png',
      RecommendationType.rainBoots => 'assets/icons/prep_rain_boots.png',
      RecommendationType.parasol => 'assets/icons/prep_parasol.png',
      RecommendationType.sunscreen => 'assets/icons/prep_sunscreen.png',
      RecommendationType.sunglasses => 'assets/icons/prep_sunglasses.png',
      RecommendationType.water => 'assets/icons/prep_water.png',
      RecommendationType.portableFan => 'assets/icons/prep_portable_fan.png',
      RecommendationType.coolingItem => 'assets/icons/prep_cooling_item.png',
      RecommendationType.outerwear => 'assets/icons/prep_outerwear.png',
      RecommendationType.scarf => 'assets/icons/prep_scarf.png',
      RecommendationType.handWarmer => 'assets/icons/prep_hand_warmer.png',
      RecommendationType.snowChains => 'assets/icons/prep_snow_chains.png',
      RecommendationType.powerBank => 'assets/icons/prep_power_bank.png',
      RecommendationType.winterBoots => 'assets/icons/prep_winter_boots.png',
      RecommendationType.heavySnowCaution || RecommendationType.mask => null,
    };
  }
}

class WeatherRecommendation {
  final RecommendationType type;
  final bool recommended;
  final int priority;
  final String title;
  final String description;
  final String? validFrom;
  final String? validUntil;
  final bool notificationEligible;

  WeatherRecommendation({
    required this.type,
    required this.recommended,
    required this.priority,
    required this.title,
    required this.description,
    required this.notificationEligible,
    this.validFrom,
    this.validUntil,
  });

  WeatherRecommendation copyWith({
    bool? recommended,
    int? priority,
    String? title,
    String? description,
    bool? notificationEligible,
    String? validFrom,
    String? validUntil,
  }) {
    return WeatherRecommendation(
      type: type,
      recommended: recommended ?? this.recommended,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      description: description ?? this.description,
      notificationEligible: notificationEligible ?? this.notificationEligible,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
    );
  }

  factory WeatherRecommendation.fromJson(Map<String, dynamic> json) {
    return WeatherRecommendation(
      type: _parseType((json['type'] ?? '').toString()),
      recommended: json['recommended'] == true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      title: json['title'] ?? _parseType((json['type'] ?? '').toString()).title,
      description: json['description'] ?? '',
      notificationEligible: json['notificationEligible'] == true,
      validFrom: json['validFrom'] as String?,
      validUntil: json['validUntil'] as String?,
    );
  }
}

RecommendationType _parseType(String raw) {
  switch (raw) {
    case 'UMBRELLA':
      return RecommendationType.umbrella;
    case 'RAINCOAT':
      return RecommendationType.raincoat;
    case 'RAIN_BOOTS':
      return RecommendationType.rainBoots;
    case 'PARASOL':
      return RecommendationType.parasol;
    case 'SUNSCREEN':
      return RecommendationType.sunscreen;
    case 'SUNGLASSES':
      return RecommendationType.sunglasses;
    case 'WATER':
      return RecommendationType.water;
    case 'PORTABLE_FAN':
      return RecommendationType.portableFan;
    case 'COOLING_ITEM':
      return RecommendationType.coolingItem;
    case 'OUTERWEAR':
      return RecommendationType.outerwear;
    case 'SCARF':
      return RecommendationType.scarf;
    case 'HAND_WARMER':
      return RecommendationType.handWarmer;
    case 'SNOW_CHAINS':
      return RecommendationType.snowChains;
    case 'POWER_BANK':
      return RecommendationType.powerBank;
    case 'WINTER_BOOTS':
      return RecommendationType.winterBoots;
    case 'HEAVY_SNOW_CAUTION':
      return RecommendationType.heavySnowCaution;
    case 'MASK':
      return RecommendationType.mask;
    default:
      return RecommendationType.umbrella;
  }
}
