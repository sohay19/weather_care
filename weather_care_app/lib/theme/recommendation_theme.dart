import 'package:flutter/material.dart';

import '../models/recommendation.dart';
import 'weather_theme.dart';

extension RecommendationPresentation on RecommendationType {
  Color get accentColor {
    return WeatherCareTheme.primaryDeep;
  }

  Color get softColor {
    return WeatherCareTheme.primarySoft;
  }

  String get statusLabel {
    return switch (this) {
      RecommendationType.umbrella => '오후부터 필요해요',
      RecommendationType.parasol => '낮에 챙기면 좋아요',
      RecommendationType.heavySnowCaution => '이동할 때 주의해요',
      RecommendationType.outerwear => '아침저녁에 추천해요',
      RecommendationType.mask => '대기질을 확인해요',
      RecommendationType.water => '수분을 보충해요',
      RecommendationType.sunscreen => '자외선이 강해요',
    };
  }
}
