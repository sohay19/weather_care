import { describe, expect, it } from 'vitest';
import {
  morningBriefDestination,
  recommendationDestination,
  warningDestination,
} from '../src/notification/notificationDestination';
import { buildNotification } from '../src/notification/notificationBuilder';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import { buildWeatherBriefResult } from '../src/presentation/weatherBrief';
import { Recommendation, RecommendationType } from '../src/types';

describe('notification destinations', () => {
  it('opens a morning brief on the main screen', () => {
    expect(morningBriefDestination).toEqual({
      target: 'MAIN',
      topic: 'OVERVIEW',
    });
  });

  it('maps recommendation types to weather detail topics', () => {
    const cases: Array<[RecommendationType, string]> = [
      ['UMBRELLA', 'PRECIPITATION'],
      ['RAINCOAT', 'PRECIPITATION'],
      ['RAIN_BOOTS', 'PRECIPITATION'],
      ['PARASOL', 'UV'],
      ['SUNGLASSES', 'UV'],
      ['HEAVY_SNOW_CAUTION', 'SNOW'],
      ['SNOW_CHAINS', 'SNOW'],
      ['POWER_BANK', 'SNOW'],
      ['WINTER_BOOTS', 'SNOW'],
      ['OUTERWEAR', 'TEMPERATURE'],
      ['SCARF', 'TEMPERATURE'],
      ['HAND_WARMER', 'TEMPERATURE'],
      ['MASK', 'AIR_QUALITY'],
      ['WATER', 'HEAT'],
      ['PORTABLE_FAN', 'HEAT'],
      ['COOLING_ITEM', 'HEAT'],
      ['SUNSCREEN', 'UV'],
    ];

    for (const [type, topic] of cases) {
      expect(recommendationDestination(type)).toEqual({
        target: 'WEATHER_DETAILS',
        topic,
      });
    }
  });

  it('maps every official warning type to its related detail topic', () => {
    const cases = {
      W: 'STRONG_WIND',
      R: 'PRECIPITATION',
      C: 'TEMPERATURE',
      D: 'WEATHER_WARNING',
      O: 'WEATHER_WARNING',
      N: 'WEATHER_WARNING',
      V: 'WEATHER_WARNING',
      T: 'WEATHER_WARNING',
      S: 'SNOW',
      Y: 'AIR_QUALITY',
      H: 'HEAT',
      F: 'COMMUTE',
      K: 'SLEEP',
    };

    for (const [typeCode, topic] of Object.entries(cases)) {
      expect(warningDestination(typeCode)).toEqual({
        target: 'WEATHER_DETAILS',
        topic,
      });
    }
  });

  it('keeps a combined brief on main and sends standalone heavy snow to detail', () => {
    const umbrella = recommendation('UMBRELLA');
    const snow = recommendation('HEAVY_SNOW_CAUTION');

    expect(buildNotification([umbrella, snow])).toMatchObject([
      {
        notification_key: 'MORNING_BRIEF',
        destination: { target: 'MAIN', topic: 'OVERVIEW' },
      },
      {
        notification_key: 'IMPORTANT_HEAVY_SNOW_CAUTION',
        destination: { target: 'WEATHER_DETAILS', topic: 'SNOW' },
      },
    ]);
  });

  it('places each morning brief message on its own line', () => {
    expect(
      buildNotification([
        recommendation('UMBRELLA'),
        recommendation('PARASOL'),
      ])[0].body,
    ).toBe('UMBRELLA description\nPARASOL description');
  });

  it('요약 알림은 발송 시점 canonical intent의 알림 copy를 재사용한다', () => {
    const forecast = sampleForecast();
    forecast.current.visibilityMeters = 500;
    forecast.current.humidity = 85;
    const now = new Date('2026-09-21T08:10:00+09:00');
    const canonical = buildWeatherBriefResult(forecast, { now }).intent;

    const notification = buildNotification([], now, forecast)[0];

    expect(notification).toEqual({
      notification_key: 'MORNING_BRIEF',
      title: '오늘자 준비물 😊',
      body: canonical.copy.notificationBody,
      destination: morningBriefDestination,
    });
    expect(notification.body).not.toMatch(/500|85|m\b|%/);
  });

  it('20시 요약 알림에서 종료된 낮 UV 행동을 제거한다', () => {
    const forecast = sampleForecast();
    forecast.current = {
      observedAt: '2026-09-21T20:00:00+09:00',
      forecastAt: '2026-09-21T20:00:00+09:00',
      temperature: 22,
      apparentTemperature: 22,
    };
    forecast.hourly = [{
      observedAt: '2026-09-21T14:00:00+09:00',
      forecastAt: '2026-09-21T14:00:00+09:00',
      validTo: '2026-09-21T15:00:00+09:00',
      uvIndex: 8,
    }];

    const notification = buildNotification(
      [],
      new Date('2026-09-21T20:00:00+09:00'),
      forecast,
      { sunsetAt: '2026-09-21T18:40:00+09:00' },
    )[0];

    expect(notification.body).not.toMatch(/자외선|선크림|양산|햇볕/);
  });

  it('새 요약은 내일 준비물을 오늘 준비물로 되돌려 넣지 않는다', () => {
    const forecast = sampleForecast();
    forecast.current = { observedAt: '2026-09-20T08:00:00+09:00' };
    forecast.hourly = [{ observedAt: '2026-09-22T05:00:00+09:00',
      precipitationType: 'RAIN', precipitationProbability: 80 }];
    expect(buildNotification([recommendation('UMBRELLA')],
      new Date('2026-09-21T07:00:00+09:00'), forecast, {
        tieredPreparations: true, allowedRecommendedItems: ['UMBRELLA'],
      })).toEqual([]);
  });

  it('종일 추위와 낮 자외선 준비물을 친근한 문장으로 안내한다', () => {
    const forecast = preparationForecast();
    const result = buildNotification([], new Date('2026-10-27T07:00:00+09:00'), forecast,
      { tieredPreparations: true })[0];
    expect(result.title).toBe('오늘자 준비물 😊');
    expect(result.body).toBe('오늘은 하루 종일 쌀쌀해요. 두꺼운 겉옷을 챙겨 입고,\n' +
      '오전 9시~오후 3시까지 자외선이 강하니 선크림을 잊지 마세요.');
  });

  it.each(['회복', '누락'])('낮 기온 %s 구간이 있으면 하루 종일 춥다고 하지 않는다', (kind) => {
    const forecast = preparationForecast();
    if (kind === '회복') forecast.hourly[5].temperature = 22;
    else forecast.hourly.splice(5, 1);
    const result = buildNotification([], new Date('2026-10-27T07:00:00+09:00'), forecast,
      { tieredPreparations: true })[0];
    expect(result.body).not.toContain('하루 종일');
    expect(result.body).toContain('오전 7시~밤 12시까지는 쌀쌀해요.');
  });

  it('같은 시간대 비 준비물은 한 문장에 묶고 자정 이후 비는 제외한다', () => {
    const forecast = preparationForecast();
    forecast.current = { observedAt: '2026-10-27T07:00:00+09:00', temperature: 22 };
    forecast.hourly = [18, 24].map((hour) => ({
      observedAt: new Date(Date.parse('2026-10-27T00:00:00+09:00') + hour * 3_600_000).toISOString(),
      temperature: 22, precipitationType: 'RAIN', precipitationProbability: 80, precipitationAmount: 16,
    }));
    const result = buildNotification([], new Date('2026-10-27T07:00:00+09:00'), forecast,
      { tieredPreparations: true })[0];
    expect(result.body).toBe('오후 6시~오후 7시에는 비 소식이 있어요. 우산, 장화, 우비를 챙겨 나가세요.');
  });

  it.each([
    ['SNOW', { precipitationType: 'SNOW', snowfallAmount: 1 }, '눈 소식이 있어요.'],
    ['HEAT', { temperature: 33 }, '더위에 대비해요.'],
    ['AIR', { pm25: 80 }, '미세먼지가 심하니 마스크를 챙겨 쓰세요.'],
  ])('%s 준비물도 문장으로 안내한다', (_kind, weather, expected) => {
    const forecast = preparationForecast();
    forecast.current = { observedAt: '2026-10-27T07:00:00+09:00' };
    forecast.hourly = [{ observedAt: '2026-10-27T09:00:00+09:00', temperature: 22, ...weather }];
    const result = buildNotification([], new Date('2026-10-27T07:00:00+09:00'), forecast,
      { tieredPreparations: true })[0];
    expect(result.body).toContain(expected);
    expect(result.body).not.toContain(' · ');
  });

  it.each([
    [18, 19, { precipitationType: 'RAIN', precipitationProbability: 60, precipitationAmount: 1 },
      '오후 6시~오후 7시에는 비 소식이 있어요. 우산을 챙겨 나가세요.'],
    [11, 16, { temperature: 26 },
      '오전 11시~오후 4시까지는 더위에 대비해요. 물을 챙기고 틈틈이 쉬어 가세요.'],
    [8, 11, { pm25: 80 },
      '오전 8시~오전 11시까지는 미세먼지가 심하니 마스크를 챙겨 쓰세요.'],
    [8, 10, { precipitationType: 'SNOW', snowfallAmount: 0.5 },
      '오전 8시~오전 10시까지는 눈 소식이 있어요. 우산, 미끄럼 방지 신발 준비하여 미끄러지지 않도록 조심하세요.'],
  ])('사용자 지정 문구를 %s시~%s시 예보에 적용한다', (start, end, weather, expected) => {
    const forecast = preparationForecast();
    forecast.current = { observedAt: '2026-10-27T07:00:00+09:00', temperature: 22 };
    forecast.hourly = Array.from({ length: end - start }, (_, index) => ({
      observedAt: new Date(Date.parse('2026-10-27T00:00:00+09:00') + (start + index) * 3_600_000).toISOString(),
      temperature: 22, ...weather,
    }));
    expect(buildNotification([], new Date('2026-10-27T07:00:00+09:00'), forecast,
      { tieredPreparations: true })[0].body).toBe(expected);
  });

  it('자외선 안내가 없으면 겉옷 문장을 쉼표로 끝내지 않는다', () => {
    const forecast = preparationForecast();
    forecast.hourly.forEach((item) => { item.uvIndex = 0; });
    expect(buildNotification([], new Date('2026-10-27T07:00:00+09:00'), forecast,
      { tieredPreparations: true })[0].body)
      .toBe('오늘은 하루 종일 쌀쌀해요. 두꺼운 겉옷을 챙겨 입으세요.');
  });
});

function preparationForecast(): WeatherForecast {
  const hourly = Array.from({ length: 17 }, (_, index) => ({
    observedAt: new Date(Date.parse('2026-10-27T07:00:00+09:00') + index * 3_600_000).toISOString(),
    temperature: 8,
    uvIndex: index >= 2 && index < 8 ? 3 : 0,
  }));
  return { ...sampleForecast(), current: hourly[0], hourly };
}

function recommendation(type: RecommendationType): Recommendation {
  return {
    type,
    recommended: true,
    priority: 100,
    title: type,
    description: `${type} description`,
    reasonCodes: [],
    notificationEligible: true,
  };
}

function sampleForecast(): WeatherForecast {
  return {
    current: {
      observedAt: '2026-09-21T08:00:00+09:00',
      temperature: 22,
      humidity: 60,
    },
    hourly: [],
    daily: [],
    baseDate: '20260921',
    baseTime: '0800',
    dataSource: 'test',
  };
}
