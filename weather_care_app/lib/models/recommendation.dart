import 'package:flutter/material.dart';

enum RecommendationType {
  umbrella,
  parasol,
  heavySnowCaution,
  outerwear,
  mask,
  water,
  sunscreen,
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
      RecommendationType.parasol => '양산',
      RecommendationType.heavySnowCaution => '폭설 주의',
      RecommendationType.outerwear => '겉옷',
      RecommendationType.mask => '마스크',
      RecommendationType.water => '물',
      RecommendationType.sunscreen => '선크림',
    };
  }

  String get title {
    return switch (this) {
      RecommendationType.umbrella => '우산 챙겨요',
      RecommendationType.parasol => '양산 챙겨요',
      RecommendationType.heavySnowCaution => '폭설 주의',
      RecommendationType.outerwear => '겉옷 챙겨요',
      RecommendationType.mask => '마스크 챙겨요',
      RecommendationType.water => '물 챙겨요',
      RecommendationType.sunscreen => '선크림 챙겨요',
    };
  }

  IconData get icon {
    return switch (this) {
      RecommendationType.umbrella => Icons.umbrella,
      RecommendationType.parasol => Icons.wb_sunny,
      RecommendationType.heavySnowCaution => Icons.ac_unit,
      RecommendationType.outerwear => Icons.checkroom,
      RecommendationType.mask => Icons.face,
      RecommendationType.water => Icons.local_drink,
      RecommendationType.sunscreen => Icons.spa,
    };
  }

  String get apiName {
    return switch (this) {
      RecommendationType.umbrella => 'UMBRELLA',
      RecommendationType.parasol => 'PARASOL',
      RecommendationType.heavySnowCaution => 'HEAVY_SNOW_CAUTION',
      RecommendationType.outerwear => 'OUTERWEAR',
      RecommendationType.mask => 'MASK',
      RecommendationType.water => 'WATER',
      RecommendationType.sunscreen => 'SUNSCREEN',
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
    case 'PARASOL':
      return RecommendationType.parasol;
    case 'HEAVY_SNOW_CAUTION':
      return RecommendationType.heavySnowCaution;
    case 'OUTERWEAR':
      return RecommendationType.outerwear;
    case 'MASK':
      return RecommendationType.mask;
    case 'WATER':
      return RecommendationType.water;
    case 'SUNSCREEN':
      return RecommendationType.sunscreen;
    default:
      return RecommendationType.umbrella;
  }
}

