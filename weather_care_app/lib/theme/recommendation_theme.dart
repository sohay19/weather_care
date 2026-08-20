import 'package:flutter/material.dart';

import '../models/recommendation.dart';

extension RecommendationPresentation on RecommendationType {
  Color get accentColor {
    return switch (this) {
      RecommendationType.umbrella => const Color(0xFF4E8FD8),
      RecommendationType.parasol => const Color(0xFFE7A93B),
      RecommendationType.heavySnowCaution => const Color(0xFF65A9C8),
      RecommendationType.outerwear => const Color(0xFF8B78C6),
      RecommendationType.mask => const Color(0xFF748596),
      RecommendationType.water => const Color(0xFF3FA9C5),
      RecommendationType.sunscreen => const Color(0xFFE98B65),
    };
  }

  Color get softColor {
    return switch (this) {
      RecommendationType.umbrella => const Color(0xFFEAF3FD),
      RecommendationType.parasol => const Color(0xFFFFF5D9),
      RecommendationType.heavySnowCaution => const Color(0xFFEAF7FC),
      RecommendationType.outerwear => const Color(0xFFF1EDFB),
      RecommendationType.mask => const Color(0xFFF0F3F5),
      RecommendationType.water => const Color(0xFFE7F8FB),
      RecommendationType.sunscreen => const Color(0xFFFFEFE8),
    };
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
