import 'home_widget_snapshot.dart';
import 'recommendation.dart';
import 'weather.dart';
import '../utils/weather_number.dart';

/// 워치 조회 자료. 알림 설정·인증정보·정밀 좌표는 보내지 않는다.
Map<String, dynamic> buildWearWeatherDetails(TodayWeatherResponse today,
    {ComparisonResponse? comparison}) {
  final c = today.current;
  String number(num? value, String unit) => value == null || !value.isFinite
      ? '자료 없음'
      : '${formatWeatherNumber(value.toDouble())}$unit';
  Map<String, String> metric(String name, String value, String? basis) => {
        'name': name,
        'value': value,
        'basis': basis ?? today.generatedAt ?? '기준 시각 없음'
      };
  String difference(num? current, num? previous, String prefix) {
    if (current == null || previous == null) {
      return prefix.isEmpty ? '어제 비교 자료 없음' : '체감 비교 자료 없음';
    }
    final delta = current - previous;
    if (delta.abs() < 0.5) return '$prefix어제와 비슷해요';
    return '$prefix어제보다 ${delta.abs().round()}° ${delta < 0 ? '낮아요' : '높아요'}';
  }

  final validComparison = comparison?.comparisonAvailable == true;
  final indices = today.livingIndices;
  final pollen =
      indices?.pollen.map((p) => '${p.species} ${p.level}').join(' · ');
  return {
    'hours': today.hourly
        .where((h) => h.forecastDate != null)
        .map((h) => {
              'at': '${h.forecastDate}T${h.time.padLeft(2, '0')}:00:00+09:00',
              'label': '${h.time}시',
              'temperature':
                  h.temperature == null ? '--' : '${h.temperature!.round()}°',
              'condition': widgetWeatherCondition(h.skyCondition),
              'rain': h.precipitationProbability == null
                  ? '--'
                  : '${h.precipitationProbability!.round()}%',
            })
        .take(24)
        .toList(),
    'metrics': [
      metric('체감온도', number(c.displayedApparentTemperature, '°'), c.observedAt),
      metric('습도', number(c.humidity, '%'), c.observedAt),
      metric('자외선', number(c.uvIndex, ''), c.uvObservedAt),
      metric('바람', number(c.windSpeed, 'm/s'), c.observedAt),
      metric('대기질', 'PM10 ${number(c.pm10, '')}\nPM2.5 ${number(c.pm25, '')}',
          c.airQualityObservedAt),
      metric('대기정체', indices?.airStagnationLevel ?? '자료 없음',
          indices?.airStagnationForecastAt),
      metric(
          '가시거리',
          number(c.visibilityMeters == null ? null : c.visibilityMeters! / 1000,
              'km'),
          c.visibilityObservedAt),
      metric(
          '꽃가루',
          pollen == null || pollen.isEmpty
              ? (indices?.pollenStatus == 'OUT_OF_SEASON' ? '기간 외' : '자료 없음')
              : pollen,
          today.generatedAt),
      metric('강수량', number(c.precipitationAmount, 'mm'), c.observedAt),
      metric('적설량', number(c.snowDepthCm, 'cm'), c.snowDepthObservedAt),
    ],
    'preparationReasons': {
      for (final item in today.recommendations)
        item.type.apiName: item.description
    },
    'temperatureComparison': difference(
        validComparison ? comparison?.current?.temperature : null,
        validComparison ? comparison?.comparison?.temperature : null,
        ''),
    'apparentComparison': difference(
        validComparison ? comparison?.current?.apparentTemperature : null,
        validComparison ? comparison?.comparison?.apparentTemperature : null,
        '체감 상 '),
  };
}
