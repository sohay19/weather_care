import { describe, expect, it } from 'vitest';
import {
  enrichForecastWithVisibility,
  latestVisibilityKoreanHour,
  usableVisibilityObservation,
} from '../src/providers/weather/visibility';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import type { CurrentVisibilityObservation } from '../src/types';

const now = new Date('2026-09-21T06:00:00Z');
const observation: CurrentVisibilityObservation = {
  observedAt: '2026-09-21T14:00:00+09:00',
  stationId: '108',
  distanceKm: 4.2,
  visibilityMeters: 800,
  provider: 'KMA_ASOS',
};

describe('visibility observation policy', () => {
  it.each([
    ['2026-10-08T13:00:00+09:00', '2026-10-08T12:00:00.000Z'],
    ['2026-10-08T13:30:00+09:00', '2026-10-08T12:00:00.000Z'],
    ['2026-10-08T13:59:59+09:00', '2026-10-08T12:00:00.000Z'],
    ['2026-10-08T14:00:00+09:00', '2026-10-08T13:00:00.000Z'],
    ['2026-10-08T00:00:00+09:00', '2026-10-07T23:00:00.000Z'],
    ['2026-01-01T00:30:00+09:00', '2025-12-31T23:00:00.000Z'],
  ])('직전 정시 회차를 고른다: %s', (time, expected) => {
    expect(latestVisibilityKoreanHour(new Date(time)).toISOString()).toBe(expected);
  });

  it('현재 시각보다 과거여도 이번 정시 자료는 응답하지 않는다', () => {
    const time = new Date('2026-10-08T13:30:00+09:00');
    expect(usableVisibilityObservation({ ...observation, observedAt: '2026-10-08T13:00:00+09:00' }, time)).toBe(false);
    expect(usableVisibilityObservation({ ...observation, observedAt: '2026-10-08T12:00:00+09:00' }, time)).toBe(true);
    expect(usableVisibilityObservation({ ...observation, observedAt: '2026-10-08T10:30:00+09:00' }, time)).toBe(true);
    expect(usableVisibilityObservation({ ...observation, observedAt: '2026-10-08T10:29:59+09:00' }, time)).toBe(false);
  });
  it('adds a recent nearby observation to current weather only', () => {
    const forecast = sampleForecast();
    const enriched = enrichForecastWithVisibility(forecast, observation, now);

    expect(enriched.current).toMatchObject({
      visibilityMeters: 800,
      visibilityObservedAt: observation.observedAt,
      visibilityStationId: '108',
      visibilityStationDistanceKm: 4.2,
    });
    expect(enriched.hourly).toEqual(forecast.hourly);
    expect(forecast.current.visibilityMeters).toBeUndefined();
  });

  it('오래된 값과 미래 값은 제외하지만 가까운 후보가 없는 원거리 관측소는 사용한다', () => {
    expect(
      usableVisibilityObservation(
        {
          ...observation,
          observedAt: '2026-09-21T11:59:59+09:00',
        },
        now,
      ),
    ).toBe(false);
    expect(
      usableVisibilityObservation(
        {
          ...observation,
          distanceKm: 30.1,
        },
        now,
      ),
    ).toBe(true);
    expect(
      usableVisibilityObservation(
        {
          ...observation,
          observedAt: '2026-09-21T15:00:01+09:00',
        },
        now,
      ),
    ).toBe(false);
  });
});

function sampleForecast(): WeatherForecast {
  return {
    current: {
      observedAt: '2026-09-21T15:00:00+09:00',
      temperature: 24,
    },
    hourly: [
      {
        forecastAt: '2026-09-21T16:00:00+09:00',
        temperature: 23,
      },
    ],
    daily: [],
    baseDate: '20260921',
    baseTime: '1400',
    dataSource: 'test',
  };
}
