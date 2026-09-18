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

  test('시스템 글자 배율은 1.3까지만 반영한다', () {
    final data = WeatherCareTheme.scaledMediaQuery(
      const MediaQueryData(textScaler: TextScaler.linear(2)),
    );

    expect(data.textScaler.scale(10), 13);
  });

  test('1.1과 1.3 사이의 시스템 글자 배율은 유지한다', () {
    final data = WeatherCareTheme.scaledMediaQuery(
      const MediaQueryData(textScaler: TextScaler.linear(1.2)),
    );

    expect(data.textScaler.scale(10), 12);
  });
}
