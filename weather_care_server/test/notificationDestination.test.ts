import { describe, expect, it } from 'vitest';
import {
  morningBriefDestination,
  recommendationDestination,
  warningDestination,
} from '../src/notification/notificationDestination';
import { buildNotification } from '../src/notification/notificationBuilder';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
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
      ['PARASOL', 'UV'],
      ['HEAVY_SNOW_CAUTION', 'SNOW'],
      ['OUTERWEAR', 'TEMPERATURE'],
      ['MASK', 'AIR_QUALITY'],
      ['WATER', 'HEAT'],
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

  it('sends qualitative visibility and humidity context without measurements', () => {
    const forecast = sampleForecast();
    forecast.current.visibilityMeters = 500;
    forecast.current.humidity = 85;

    const notification = buildNotification([], undefined, forecast)[0];

    expect(notification).toMatchObject({
      notification_key: 'MORNING_BRIEF',
      title: '오늘 날씨 안내',
    });
    expect(notification.body).toContain('운전할 때는 감속하고');
    expect(notification.body).toContain('빨래가 더디게 마를 수 있어요');
    expect(notification.body).not.toMatch(/500|85|m\b|%/);
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
