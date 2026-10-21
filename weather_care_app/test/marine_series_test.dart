import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/features/home/widgets/marine_series.dart';

void main() {
  test('관측은 최신 시각까지, 예측은 오늘 0시부터 표시하며 결측과 날짜 경계를 유지한다', () {
    final data = MarineHourlyData(
        now: marineTime(DateTime.utc(2026, 10, 20, 4, 30)),
        observations: marinePoints([
          {
            'time': '2026-10-19 23:00',
            'values': {'tideCm': 999}
          },
          {
            'time': '2026-10-20 11:00',
            'values': {'tideCm': 110}
          },
          {
            'time': '2026-10-20 13:00',
            'values': {'tideCm': 130}
          },
          {
            'time': '2026-10-20 14:00',
            'values': {'tideCm': 888}
          },
        ]),
        forecasts: marinePoints([
          {
            'time': '2026-10-19 23:00',
            'values': {'tideCm': 9999}
          },
          {
            'time': '2026-10-20 00:00',
            'values': {'tideCm': 50}
          },
          {
            'time': '2026-10-20 11:00',
            'values': {'tideCm': 5}
          },
          {
            'time': '2026-10-20 12:00',
            'values': {'tideCm': 60}
          },
          {
            'time': '2026-10-20 14:00',
            'values': {'tideCm': 140}
          },
          {
            'time': '2026-10-20 23:00',
            'values': {'tideCm': 135}
          },
          {
            'time': '2026-10-21 00:00',
            'values': {'tideCm': 9000}
          },
        ]));
    expect(data.latest('tideCm')!.values['tideCm'], 130);
    expect(data.hourly('tideCm', forecast: false)[12], isNull);
    expect(data.hourly('tideCm', forecast: false)[14], isNull);
    expect(data.hourly('tideCm', forecast: true)[0], 50);
    expect(data.hourly('tideCm', forecast: true)[1], isNull);
    expect(data.hourly('tideCm', forecast: true)[11], 5);
    expect(data.hourly('tideCm', forecast: true)[12], 60);
    expect(data.hourly('tideCm', forecast: true)[14], 140);
    expect(data.hourly('tideCm', forecast: true)[23], 135);
    expect(data.range('tideCm'), (5.0, 140.0));
  });

  test('현재 정각의 관측과 예측을 함께 표시하고 m/s 단위·유향·결측을 보존한다', () {
    final data = MarineHourlyData(
        now: DateTime.utc(2026, 10, 20, 13),
        observations: marinePoints([
          {
            'time': '2026-10-20T04:00:00Z',
            'values': {'currentSpeedCmPerSec': 123, 'currentDirectionDeg': 359}
          },
          {
            'time': '2026-10-20 13:30',
            'values': {'waterTempC': 99}
          },
        ], buoy: true),
        forecasts: marinePoints([
          {
            'time': '2026-10-20 13:00',
            'values': {'currentSpeed': 9}
          },
          {
            'time': '2026-10-20 14:00',
            'values': {'currentSpeed': 2}
          },
        ]));
    expect(data.hourly('currentSpeed', forecast: false)[13], 1.23);
    expect(data.hourly('currentSpeed', forecast: true)[13], 9);
    expect(data.hourly('currentSpeed', forecast: true)[14], 2);
    expect(
        data.latest('currentDirectionDeg')!.values['currentDirectionDeg'], 359);
    expect(data.latest('waterTempC'), isNull);
  });

  test('같은 시각의 모델 지점은 관측소와 가까운 지점을 사용하고 날짜만 있는 값은 제외한다', () {
    final points = marinePoints([
      {
        'time': '2026-10-20 14:00',
        'values': {'waterTempC': 30, 'latitude': 35, 'longitude': 129}
      },
      {
        'time': '2026-10-20 14:00',
        'values': {'waterTempC': 20, 'latitude': 37.5, 'longitude': 126.5}
      },
      {
        'time': '2026-10-20',
        'values': {'waterTempC': 999}
      },
    ], location: {
      'latitude': 37.5,
      'longitude': 126.5
    });
    expect(points.length, 1);
    expect(points.single.values['waterTempC'], 20);
    expect(marineRecordTime('2026-10-20T14:00:00+09:00'),
        DateTime.utc(2026, 10, 20, 14));
  });
}
