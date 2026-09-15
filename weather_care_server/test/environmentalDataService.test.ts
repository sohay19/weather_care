import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  EnvironmentalDataBundle,
  enrichForecastWithEnvironmentalData,
  loadEnvironmentalData,
} from '../src/providers/environmental/environmentalDataService';
import { WeatherForecast } from '../src/providers/weather/weatherProvider';
import { ServerEnv } from '../src/types';

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('environmental data enrichment', () => {
  it('adds UV forecasts to matching hours and air observations to current only', () => {
    const bundle: EnvironmentalDataBundle = {
      uv: {
        areaNo: '4111000000',
        issuedAt: '2026-08-21T09:00:00+09:00',
        provider: 'KMA_LIVING_INDEX_V5',
        points: [
          { forecastAt: '2026-08-21T09:00:00+09:00', uvIndex: 3 },
          { forecastAt: '2026-08-21T12:00:00+09:00', uvIndex: 7 },
        ],
      },
      airQuality: {
        observedAt: '2026-08-21T10:00:00+09:00',
        stationName: '인계동',
        pm10: 42,
        pm25: 18,
        airQualityGrade: 'Moderate',
        ozone: 0.032,
        ozoneGrade: 'Good',
        provider: 'AIRKOREA',
      },
      sources: {
        uv: {
          provider: 'KMA_LIVING_INDEX_V5',
          state: 'AVAILABLE',
        },
        airQuality: { provider: 'AIRKOREA', state: 'AVAILABLE' },
      },
    };

    const result = enrichForecastWithEnvironmentalData(forecast(), bundle);

    expect(result.dataSource).toBe(
      '기상청 단기예보 · 기상청 생활기상지수 · 에어코리아',
    );
    expect(result.current).toEqual(
      expect.objectContaining({
        uvIndex: 3,
        pm10: 42,
        pm25: 18,
        ozone: 0.032,
        provider: 'KMA+KMA_LIVING_INDEX_V5+AIRKOREA',
      }),
    );
    expect(result.hourly[1].uvIndex).toBe(7);
    expect(result.hourly[1].pm10).toBeUndefined();
    expect(result.hourly[1].pm25).toBeUndefined();
  });

  it('enriches retained timeline hours without moving them into the detail list', () => {
    const input = forecast();
    input.timelineHourly = [
      {
        observedAt: '2026-08-21T09:00:00+09:00',
        forecastAt: '2026-08-21T09:00:00+09:00',
        temperature: 23,
        provider: 'KMA',
        providerField: 'TMP',
      },
      ...input.hourly,
    ];
    const bundle: EnvironmentalDataBundle = {
      uv: {
        areaNo: '4111000000',
        issuedAt: '2026-08-21T06:00:00+09:00',
        provider: 'KMA_LIVING_INDEX_V5',
        points: [
          { forecastAt: '2026-08-21T09:00:00+09:00', uvIndex: 3 },
        ],
      },
      sources: {
        uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'AVAILABLE' },
        airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' },
      },
    };

    const result = enrichForecastWithEnvironmentalData(input, bundle);

    expect(result.hourly).toHaveLength(3);
    expect(result.timelineHourly).toHaveLength(4);
    expect(result.timelineHourly?.[0]).toMatchObject({
      uvIndex: 3,
      provider: 'KMA+KMA_LIVING_INDEX_V5',
    });
  });

  it('keeps weather available and records flags when environmental providers fail', () => {
    const bundle: EnvironmentalDataBundle = {
      sources: {
        uv: {
          provider: 'KMA_LIVING_INDEX_V5',
          state: 'UNAVAILABLE',
          reason: 'PROVIDER_UNAVAILABLE',
        },
        airQuality: {
          provider: 'AIRKOREA',
          state: 'UNAVAILABLE',
          reason: 'PROVIDER_UNAVAILABLE',
        },
      },
    };

    const result = enrichForecastWithEnvironmentalData(forecast(), bundle);

    expect(result.current.temperature).toBe(24);
    expect(result.current.uvIndex).toBeUndefined();
    expect(result.current.qualityFlags).toEqual(
      expect.arrayContaining(['UV_UNAVAILABLE', 'AIR_QUALITY_UNAVAILABLE']),
    );
  });

  it('loads UV for an uncatalogued nationwide weather grid', async () => {
    const fetcher = vi.fn(async () =>
      new Response(JSON.stringify({
        response: {
          header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' },
          body: {
            items: {
              item: {
                areaNo: '2623056000',
                date: '2026090112',
                h0: '6',
              },
            },
          },
        },
      })),
    );
    vi.stubGlobal('fetch', fetcher);

    const result = await loadEnvironmentalData(
      { KMA_SERVICE_KEY: 'test-key' } as ServerEnv,
      undefined,
      {
        nx: 98,
        ny: 76,
        now: new Date('2026-09-01T03:40:00Z'),
      },
    );

    expect(result.uv).toMatchObject({
      areaNo: '2623056000',
      points: [expect.objectContaining({ uvIndex: 6 })],
    });
    const requestUrl = new URL(fetcher.mock.calls[0][0].toString());
    expect(requestUrl.searchParams.get('areaNo')).toBe('2623056000');
  });
});

function forecast(): WeatherForecast {
  const hourly = [10, 12, 13].map((hour) => ({
    observedAt: `2026-08-21T${String(hour).padStart(2, '0')}:00:00+09:00`,
    forecastAt: `2026-08-21T${String(hour).padStart(2, '0')}:00:00+09:00`,
    temperature: 24 + (hour - 10),
    provider: 'KMA',
    providerField: 'TMP',
  }));
  return {
    current: {
      ...hourly[0],
      minTemperature: 20,
      maxTemperature: 29,
    },
    hourly,
    daily: [],
    baseDate: '20260821',
    baseTime: '0800',
    dataSource: '기상청 단기예보',
  };
}
