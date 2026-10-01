import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/home_widget_snapshot.dart';
import 'package:weather_care/models/recommendation.dart';
import 'package:weather_care/models/weather.dart';

void main() {
  test('위젯 자료는 시안 형식과 준비물 최대 3개를 유지한다', () {
    final snapshot = HomeWidgetSnapshot.fromWeather(
      today: _today(
        briefing: _briefing(
          sceneId: 'RAIN',
          short: '비 소식, 우산 챙기세요.',
          medium: '오후 3시부터 비가 올 수 있어요. 우산을 챙기세요.',
          long: '오후 3시~5시 비 가능성이 높아요. 외출한다면 우산을 챙기는 게 좋아요.',
          recommendedItems: const ['UMBRELLA'],
        ),
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
    expect(snapshot.sceneId, 'RAIN');
    expect(snapshot.shortMessage, '비 소식, 우산 챙기세요.');
    expect(snapshot.brief, contains('비 가능성'));
    expect(snapshot.nextTime, '오전 9시');
    expect(snapshot.nextTemperature, '19°');
    expect(
      snapshot.preparations.map((item) => item.label),
      ['우산'],
    );
    expect(snapshot.preparations, hasLength(1));

    final encoded = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
    expect(encoded['schemaVersion'], HomeWidgetSnapshot.schemaVersion);
    expect(encoded['locationKey'], '57/124');
    expect(encoded['briefingId'], '57/124:20260919:RAIN');
    expect((encoded['preparations'] as List), hasLength(1));
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

  test('다음 예보와 오늘 최고·최저가 없으면 현재 날씨와 다른 날짜로 채우지 않는다', () {
    final snapshot = HomeWidgetSnapshot.fromWeather(
      today: _today(
        recommendations: const [],
        nextForecast: null,
      ),
      weekly: WeeklyWeatherResponse.fromJson({
        'days': [
          {
            'date': '일',
            'forecastDate': '2026-09-20',
            'min': 8,
            'max': 25,
            'recommendations': <Object?>[],
          },
        ],
      }),
      now: DateTime.parse('2026-09-19T03:00:00Z'),
    );

    expect(snapshot.nextTime, '예보 준비 중');
    expect(snapshot.nextCondition, 'unknown');
    expect(snapshot.nextTemperature, '--°');
    expect(snapshot.minimumTemperature, '--°');
    expect(snapshot.maximumTemperature, '--°');
  });

  test('짧은 브리핑은 긴 문장을 자른 값이 아니다', () {
    final briefing = _briefing(
      sceneId: 'RAIN',
      short: '비 소식, 우산 챙기세요.',
      medium: '오후에 비가 와요. 우산을 챙기세요.',
      long: '이 문장은 스물한 글자보다 훨씬 길지만 그대로 전달되는 긴 브리핑입니다.',
      recommendedItems: const ['UMBRELLA'],
    );
    final snapshot = HomeWidgetSnapshot.fromWeather(
      today: _today(
        briefing: briefing,
        recommendations: [_recommendation(RecommendationType.umbrella, 1)],
      ),
      now: DateTime.parse('2026-09-18T23:30:00Z'),
    );

    expect(snapshot.shortMessage, briefing.copy.short);
    expect(snapshot.brief, briefing.copy.long);
    expect(snapshot.shortMessage, isNot(briefing.copy.long.substring(0, 21)));
  });

  test('일몰 후에는 저장된 timeline에서 저녁 scene을 선택한다', () {
    final uv = _timelineEntry(
      sceneId: 'UV',
      from: '2026-09-19T09:30:00Z',
      until: '2026-09-19T09:47:00Z',
      short: '자외선이 강해요. 햇볕을 피하세요.',
    );
    final evening = _timelineEntry(
      sceneId: 'THERMAL_COMFORTABLE',
      from: '2026-09-19T09:47:00Z',
      until: '2026-09-19T15:00:00Z',
      short: '선선하고 편안한 날씨예요.',
    );
    final snapshot = HomeWidgetSnapshot.fromWeather(
      today: _today(
        briefing: _briefing(
          sceneId: 'UV',
          short: uv.copy.short,
          medium: uv.copy.medium,
          long: uv.copy.long,
        ),
        briefingTimeline: [uv, evening],
        recommendations: const [],
      ),
      now: DateTime.parse('2026-09-19T09:48:00Z'),
    );

    expect(snapshot.sceneId, 'THERMAL_COMFORTABLE');
    expect(snapshot.shortMessage, '선선하고 편안한 날씨예요.');
    expect(snapshot.shortMessage, isNot(contains('자외선')));
  });

  test('위젯 준비물은 추천 엔진이 아니라 현재 브리핑을 따르고 미래 목록도 보존한다', () {
    final snapshot = HomeWidgetSnapshot.fromWeather(
      today: _today(
        briefingTimeline: [
          _timelineEntry(
            sceneId: 'HUMIDITY_LOW',
            from: '2026-09-19T03:00:00Z',
            until: '2026-09-19T04:00:00Z',
            short: '공기가 건조해요.',
            recommendedItems: const ['WATER'],
          ),
          _timelineEntry(
            sceneId: 'RAIN',
            from: '2026-09-19T04:00:00Z',
            until: '2026-09-19T05:00:00Z',
            short: '비 소식, 우산 챙기세요.',
            recommendedItems: const ['UMBRELLA', 'RAINCOAT'],
          ),
        ],
        recommendations: const [],
      ),
      now: DateTime.parse('2026-09-19T03:30:00Z'),
    );

    expect(snapshot.preparations.map((item) => item.type), ['WATER']);
    expect(
      snapshot.preparationCatalog.map((item) => item.type),
      ['WATER', 'UMBRELLA', 'RAINCOAT'],
    );
    final encoded = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
    expect((encoded['preparationCatalog'] as List), hasLength(3));
  });

  test('기기 시계가 3시간 느려도 수신한 위젯 스냅샷에 현재 브리핑을 넣는다', () {
    final receivedAt = DateTime.parse('2026-09-18T23:30:00Z');
    final snapshot = HomeWidgetSnapshot.fromWeather(
      today: _today(
        generatedAt: '2026-09-19T02:30:00Z',
        receivedAt: receivedAt,
        briefingTimeline: [
          _timelineEntry(
            sceneId: 'UV',
            from: '2026-09-19T02:30:00Z',
            until: '2026-09-19T03:00:00Z',
            short: '선크림을 챙기세요.',
            recommendedItems: const ['SUNSCREEN'],
          ),
        ],
        recommendations: const [],
      ),
      now: receivedAt,
    );
    expect(snapshot.shortMessage, '선크림을 챙기세요.');
    expect(snapshot.preparations.map((item) => item.type), ['SUNSCREEN']);
    expect(snapshot.toJson()['receivedAt'], receivedAt.toIso8601String());
  });

  test('오늘과 주간 응답 사이에 날짜가 바뀌면 주간 응답의 오늘 최저·최고를 쓴다', () {
    final receivedAt = DateTime.parse('2026-10-01T10:00:00Z');
    final snapshot = HomeWidgetSnapshot.fromWeather(
      today: _today(
        generatedAt: '2026-10-01T14:59:00Z',
        receivedAt: receivedAt,
        recommendations: const [],
      ),
      weekly: WeeklyWeatherResponse.fromJson({
        'generatedAt': '2026-10-01T15:01:00Z',
        'days': [
          {'forecastDate': '2026-10-01', 'min': 11, 'max': 21},
          {'forecastDate': '2026-10-02', 'min': 12, 'max': 22},
        ],
      }, receivedAt: receivedAt),
      now: receivedAt,
    );
    expect(snapshot.minimumTemperature, '12°');
    expect(snapshot.maximumTemperature, '22°');
  });
}

TodayWeatherResponse _today({
  String generatedAt = '2026-09-18T23:20:00Z',
  DateTime? receivedAt,
  CanonicalBriefing? briefing,
  List<BriefingTimelineEntry> briefingTimeline = const [],
  required List<WeatherRecommendation> recommendations,
  CurrentWeather? nextForecast = const CurrentWeather(
    temperature: 19,
    forecastAt: '2026-09-19T00:00:00Z',
    sky: '맑음',
  ),
}) {
  return TodayWeatherResponse(
    dataSource: '서버 데이터',
    generatedAt: generatedAt,
    receivedAt: receivedAt,
    region: const WeatherRegion(
      nx: 57,
      ny: 124,
      name: '경기도 시흥시 은행동',
    ),
    brief: '오전에는 선선하고 오후에는 포근해요. 얇은 겉옷을 챙기면 좋아요.',
    briefing: briefing,
    briefingTimeline: briefingTimeline,
    current: const CurrentWeather(
      temperature: 18,
      apparentTemperature: 17.5,
      sky: '빗방울',
    ),
    nextForecast: nextForecast,
    recommendations: recommendations,
    lifestyleMessages: const [],
    timeline: const [],
    hourly: const [],
  );
}

CanonicalBriefing _briefing({
  required String sceneId,
  required String short,
  required String medium,
  required String long,
  List<String> recommendedItems = const [],
}) =>
    CanonicalBriefing(
      briefingId: '57/124:20260919:$sceneId',
      locationKey: '57/124',
      sceneId: sceneId,
      scope: 'TODAY',
      validFrom: '2026-09-18T23:00:00Z',
      validUntil: '2026-09-19T15:00:00Z',
      nextBriefingBoundary: '2026-09-19T15:00:00Z',
      action: sceneId == 'RAIN' ? 'TAKE_UMBRELLA' : null,
      recommendedItems: recommendedItems,
      copy: BriefingCopy(
        short: short,
        medium: medium,
        long: long,
        notificationTitle: '오늘 날씨 안내',
        notificationBody: medium,
      ),
    );

BriefingTimelineEntry _timelineEntry({
  required String sceneId,
  required String from,
  required String until,
  required String short,
  List<String> recommendedItems = const [],
}) =>
    BriefingTimelineEntry(
      briefingId: '57/124:20260919:$sceneId',
      sceneId: sceneId,
      validFrom: from,
      validUntil: until,
      recommendedItems: recommendedItems,
      copy: BriefingCopy(
        short: short,
        medium: short,
        long: short,
        notificationTitle: '오늘 날씨 안내',
        notificationBody: short,
      ),
    );

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
