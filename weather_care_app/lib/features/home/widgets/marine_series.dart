import 'dart:math' as math;

/// 한국 달력 시각을 UTC 좌표에 옮겨 기기 시간대와 무관하게 비교한다.
DateTime marineTime(DateTime value) {
  final korea = value.toUtc().add(const Duration(hours: 9));
  return DateTime.utc(
      korea.year, korea.month, korea.day, korea.hour, korea.minute);
}

DateTime? marineRecordTime(Object? value) {
  final text = '$value';
  if (!RegExp(r'[T ]\d{2}:\d{2}').hasMatch(text)) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  return text.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(text)
      ? marineTime(parsed)
      : DateTime.utc(
          parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute);
}

class MarinePoint {
  final DateTime time;
  final Map<String, double> values;
  const MarinePoint(this.time, this.values);
}

List<MarinePoint> marinePoints(List<Map<String, dynamic>> records,
    {bool buoy = false, Map<String, dynamic>? location}) {
  final chosen = <DateTime, (MarinePoint, double)>{};
  for (final record in records) {
    final time = marineRecordTime(record['time']);
    if (time == null) continue;
    final raw = Map<String, dynamic>.from(record['values'] as Map? ?? {});
    final values = <String, double>{};
    for (final key in [
      'tideCm',
      'waterTempC',
      'currentSpeed',
      'currentDirectionDeg'
    ]) {
      final value = key == 'currentSpeed' && buoy
          ? (raw['currentSpeedCmPerSec'] is num
              ? (raw['currentSpeedCmPerSec'] as num) / 100
              : raw['currentSpeedMs'])
          : raw[key];
      if (value is num && value.isFinite) values[key] = value.toDouble();
    }
    var distance = double.infinity;
    if (location?['latitude'] is num &&
        location?['longitude'] is num &&
        raw['latitude'] is num &&
        raw['longitude'] is num) {
      distance = math
              .pow((raw['latitude'] as num) - (location!['latitude'] as num), 2)
              .toDouble() +
          math
              .pow(
                  (raw['longitude'] as num) - (location['longitude'] as num), 2)
              .toDouble();
    }
    if (!chosen.containsKey(time) || distance < chosen[time]!.$2) {
      chosen[time] = (MarinePoint(time, values), distance);
    }
  }
  return chosen.values.map((entry) => entry.$1).toList()
    ..sort((a, b) => a.time.compareTo(b.time));
}

class MarineHourlyData {
  final DateTime now;
  final List<MarinePoint> observations;
  final List<MarinePoint> forecasts;
  MarineHourlyData(
      {required this.now, required this.observations, required this.forecasts});

  DateTime get day => DateTime.utc(now.year, now.month, now.day);
  bool _today(MarinePoint p) =>
      !p.time.isBefore(day) &&
      p.time.isBefore(day.add(const Duration(days: 1)));

  MarinePoint? latest(String metric) => observations
      .where((p) =>
          _today(p) && !p.time.isAfter(now) && p.values.containsKey(metric))
      .lastOrNull;

  (double, double)? range(String metric) {
    final values = forecasts
        .where(_today)
        .map((p) => p.values[metric])
        .whereType<double>();
    return values.isEmpty
        ? null
        : (values.reduce(math.min), values.reduce(math.max));
  }

  /// 과거의 빈 관측값을 예측값으로 메우지 않는다. 현재 이후의 관측값도 사용하지 않는다.
  List<double?> hourly(String metric, {required bool forecast}) =>
      List.generate(24, (hour) {
        final rows = (forecast ? forecasts : observations).where((p) =>
            _today(p) &&
            p.time.hour == hour &&
            (forecast ? p.time.isAfter(now) : !p.time.isAfter(now)));
        return rows
            .where((p) => p.values.containsKey(metric))
            .lastOrNull
            ?.values[metric];
      });
}
