import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/utils/weather_number.dart';

void main() {
  test('소수 첫째 자리와 작은 값의 첫 유효숫자를 유지한다', () {
    for (final (value, expected) in [
      (23.46, '23.5'),
      (12.5, '12.5'),
      (20, '20'),
      (0.125, '0.1'),
      (0.009, '0.009'),
      (0.00026, '0.0003'),
      (-0.009, '-0.009'),
      (-0.0, '0'),
    ]) {
      expect(formatWeatherNumber(value), expected);
    }
  });

  test('대기질 소수 관측값을 모델에서 정수로 자르지 않는다', () {
    final weather = CurrentWeather.fromJson({
      'current': {'pm25': 12.56, 'pm10': 27.24, 'ozone': 0.009},
    });
    expect(weather.pm25, 12.56);
    expect(weather.pm10, 27.24);
    expect(formatWeatherNumber(weather.ozone!), '0.009');
  });
}
