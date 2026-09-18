import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/home_widget_snapshot.dart';
import 'package:weather_care/models/recommendation.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  test('위젯 자료는 시안 형식과 준비물 최대 3개를 유지한다', () {
    final snapshot = HomeWidgetSnapshot.fromWeather(
      today: _today(
        recommendations: [
          _recommendation(RecommendationType.mask, 2),
          _recommendation(RecommendationType.outerwear, 5),
          _recommendation(RecommendationType.umbrella, 4),
          _recommendation(RecommendationType.water, 1),
          _recommendation(RecommendationType.umbrella, 3),
        ],
      ),
      weekly: WeeklyWeatherResponse.fromJson({
        'days': [
          {
            'date': '토',
            'forecastDate': '2026-09-19',
            'min': 12,
            'max': 20,
            'recommendations': <Object?>[],
          },
        ],
      }),
      now: DateTime.parse('2026-09-18T23:30:00Z'),
    );

    expect(snapshot.region, '시흥시 은행동');
    expect(snapshot.refreshTime, '오전 8:20 기준');
    expect(snapshot.condition, 'drizzle');
    expect(snapshot.currentTemperature, '18°');
    expect(snapshot.apparentTemperature, '17.5°');
    expect(snapshot.minimumTemperature, '12°');
    expect(snapshot.maximumTemperature, '20°');
    expect(snapshot.shortMessage, '겉옷을 챙기세요');
    expect(snapshot.nextTime, '오전 9시');
    expect(snapshot.nextTemperature, '19°');
    expect(
      snapshot.preparations.map((item) => item.label),
      ['겉옷', '우산', '마스크'],
    );
    expect(snapshot.preparations, hasLength(3));

    final encoded = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
    expect(encoded['schemaVersion'], HomeWidgetSnapshot.schemaVersion);
    expect((encoded['preparations'] as List), hasLength(3));
  });

  test('갱신 시각은 한국시간 오전과 오후로 표시한다', () {
    expect(
      widgetRefreshTime(
        '2026-09-18T04:20:00Z',
        fallback: DateTime.utc(2000),
      ),
      '오후 1:20 기준',
    );
    expect(
      widgetRefreshTime(
        '2026-09-18T15:05:00Z',
        fallback: DateTime.utc(2000),
      ),
      '오전 12:05 기준',
    );
  });

  test('큰 날씨 아이콘 11종을 구분한다', () {
    const cases = {
      '맑음': 'clear',
      '구름많음': 'partlyCloudy',
      '흐림': 'overcast',
      '빗방울': 'drizzle',
      '비': 'rain',
      '소나기': 'shower',
      '빗방울/눈날림': 'lightWintryMix',
      '비/눈': 'wintryMix',
      '눈날림': 'snowFlurry',
      '눈': 'snow',
      '자료 없음': 'unknown',
    };

    for (final entry in cases.entries) {
      expect(widgetWeatherCondition(entry.key), entry.value);
    }
  });

  test('광역 단위는 줄이고 짧은 지역명은 유지한다', () {
    expect(compactWidgetRegionName('경기도 시흥시 은행동'), '시흥시 은행동');
    expect(compactWidgetRegionName('서울특별시 종로구 청운효자동'), '종로구 청운효자동');
    expect(compactWidgetRegionName('시흥시 은행동'), '시흥시 은행동');
  });

  test('짧은 브리핑은 준비물 이름이 아닌 행동 문장으로 표시한다', () {
    const expected = {
      RecommendationType.umbrella: '우산을 챙기세요',
      RecommendationType.parasol: '양산을 챙기세요',
      RecommendationType.heavySnowCaution: '많은 눈에 대비하세요',
      RecommendationType.outerwear: '겉옷을 챙기세요',
      RecommendationType.mask: '마스크를 챙기세요',
      RecommendationType.water: '물을 챙기세요',
      RecommendationType.sunscreen: '선크림을 챙기세요',
    };

    for (final entry in expected.entries) {
      final snapshot = HomeWidgetSnapshot.fromWeather(
        today: _today(recommendations: [_recommendation(entry.key, 1)]),
        now: DateTime.parse('2026-09-18T23:30:00Z'),
      );
      expect(snapshot.shortMessage, entry.value);
    }
  });
}

TodayWeatherResponse _today({
  required List<WeatherRecommendation> recommendations,
}) {
  return TodayWeatherResponse(
    dataSource: '서버 데이터',
    generatedAt: '2026-09-18T23:20:00Z',
    region: const WeatherRegion(
      nx: 57,
      ny: 124,
      name: '경기도 시흥시 은행동',
    ),
    brief: '오전에는 선선하고 오후에는 포근해요. 얇은 겉옷을 챙기면 좋아요.',
    current: const CurrentWeather(
      temperature: 18,
      apparentTemperature: 17.5,
      sky: '빗방울',
    ),
    nextForecast: const CurrentWeather(
      temperature: 19,
      forecastAt: '2026-09-19T00:00:00Z',
      sky: '맑음',
    ),
    recommendations: recommendations,
    lifestyleMessages: const [],
    timeline: const [],
    hourly: const [],
  );
}

WeatherRecommendation _recommendation(RecommendationType type, int priority) {
  return WeatherRecommendation(
    type: type,
    recommended: true,
    priority: priority,
    title: type.title,
    description: '',
    notificationEligible: true,
  );
}
