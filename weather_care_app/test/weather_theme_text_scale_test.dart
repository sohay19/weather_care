import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/theme/weather_theme.dart';

void main() {
  test('기본 글자 배율은 1.1로 높인다', () {
    final data = WeatherCareTheme.scaledMediaQuery(
      const MediaQueryData(textScaler: TextScaler.linear(1)),
    );

    expect(data.textScaler.scale(10), 11);
  });

  test('시스템 글자 배율은 1.1까지만 반영한다', () {
    for (final scale in [1.2, 1.3, 2.0, 3.0]) {
      final data = WeatherCareTheme.scaledMediaQuery(
        MediaQueryData(textScaler: TextScaler.linear(scale)),
      );
      expect(data.textScaler.scale(10), 11);
    }
  });

  test('시스템 1.1배는 그대로 유지한다', () {
    final data = WeatherCareTheme.scaledMediaQuery(
      const MediaQueryData(textScaler: TextScaler.linear(1.1)),
    );

    expect(data.textScaler.scale(10), 11);
  });
}
