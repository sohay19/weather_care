import 'package:flutter/material.dart';

import '../models/recommendation.dart';
import 'weather_theme.dart';

extension RecommendationPresentation on RecommendationType {
  Color accentColor(BuildContext context) {
    return WeatherCareTheme.of(context).primaryDeep;
  }

  Color softColor(BuildContext context) {
    return WeatherCareTheme.of(context).primarySoft;
  }
}
