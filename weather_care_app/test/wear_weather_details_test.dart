import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/models/wear_weather_details.dart';

void main() {
  test('워치 상세는 10개 지표의 실제 0과 결측을 구분하고 인증정보를 포함하지 않는다', () {
    final today = TodayWeatherResponse.fromJson({
      'generatedAt': '2026-11-02T03:00:00Z',
      'region': {'nx': 60, 'ny': 121, 'name': '서울'},
      'current': {'temperature': 0, 'humidity': 0, 'snowDepthCm': 0},
      'installationSecret': 'must-not-sync',
    });
    final details = buildWearWeatherDetails(today);
    final metrics = details['metrics'] as List;
    expect(metrics, hasLength(10));
    expect(metrics.firstWhere((m) => m['name'] == '습도')['value'], '0%');
    expect(metrics.firstWhere((m) => m['name'] == '적설량')['value'], '0cm');
    expect(metrics.firstWhere((m) => m['name'] == '바람')['value'], '자료 없음');
    expect(details.toString(), isNot(contains('must-not-sync')));
    expect(details['temperatureComparison'], '어제 비교 자료 없음');
    expect(details['apparentComparison'], '체감 비교 자료 없음');
  });

  test('어제 비교 응답의 동일 격자·시각 자료를 사용하며 임의 예시를 넣지 않는다', () {
    final details = buildWearWeatherDetails(
      TodayWeatherResponse.fromJson({
        'current': {'temperature': 999}
      }),
      comparison: const ComparisonResponse(
        comparisonAvailable: true,
        current:
            ComparisonWeatherSnapshot(temperature: 10, apparentTemperature: 7),
        comparison:
            ComparisonWeatherSnapshot(temperature: 12, apparentTemperature: 10),
      ),
    );
    expect(details['temperatureComparison'], '어제보다 2° 낮아요');
    expect(details['apparentComparison'], '체감 상 어제보다 3° 낮아요');
  });
}
