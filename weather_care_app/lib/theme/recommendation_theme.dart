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
}
