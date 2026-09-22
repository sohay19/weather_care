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
      title: canonical.copy.notificationTitle,
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
});

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
