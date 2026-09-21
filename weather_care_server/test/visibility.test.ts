import { describe, expect, it } from 'vitest';
import {
  enrichForecastWithVisibility,
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

  it('rejects observations that are too old, too distant, or in the future', () => {
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
    ).toBe(false);
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
