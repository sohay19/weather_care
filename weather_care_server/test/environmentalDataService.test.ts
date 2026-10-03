import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  EnvironmentalDataBundle,
  enrichForecastWithEnvironmentalData,
  loadEnvironmentalData,
  currentEnvironmentalData,
  environmentalDataIssues,
  nearestNationwideAirQuality,
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

  it('keeps UV when only the AirKorea lookup exceeds its deadline', async () => {
    vi.useFakeTimers();
    try {
      const stalled = new Promise<Response>(() => undefined);
      const fetcher = vi.fn((input: RequestInfo | URL) => {
        const url = String(input);
        if (url.includes('LivingWthrIdxServiceV5')) {
          return Promise.resolve(new Response(JSON.stringify({
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
          })));
        }
        return stalled;
      });
      vi.stubGlobal('fetch', fetcher);

      const resultPromise = loadEnvironmentalData(
        { KMA_SERVICE_KEY: 'test-key' } as ServerEnv,
        undefined,
        {
          nx: 98,
          ny: 76,
          coordinates: { latitude: 35.1796, longitude: 129.0756 },
          now: new Date('2026-09-01T03:40:00Z'),
          providerTimeoutMs: 3_500,
        },
      );
      await vi.advanceTimersByTimeAsync(3_500);
      const result = await resultPromise;

      expect(result.uv?.points[0]?.uvIndex).toBe(6);
      expect(result.airQuality).toBeUndefined();
      expect(result.providerTimeouts).toEqual({
        uv: false,
        airQuality: true,
      });
      expect(result.sources.uv.state).toBe('AVAILABLE');
      expect(result.sources.airQuality.state).toBe('UNAVAILABLE');
    } finally {
      vi.useRealTimers();
    }
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

describe('수집된 환경 자료의 현재 유효성', () => {
  const now = new Date('2026-08-21T01:30:00Z');
  function bundle(): EnvironmentalDataBundle {
    return {
      uv: { areaNo: '4111000000', provider: 'KMA_LIVING_INDEX_V5',
        issuedAt: '2026-08-21T09:00:00+09:00',
        points: [{ forecastAt: '2026-08-21T09:00:00+09:00', uvIndex: 4 }] },
      airQuality: { observedAt: '2026-08-21T10:00:00+09:00', stationName: '수원',
        pm10: 20, pm25: 10, ozone: 0.02, provider: 'AIRKOREA' },
      sources: {
        uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'CACHED', cachedAt: now.toISOString() },
        airQuality: { provider: 'AIRKOREA', state: 'CACHED', cachedAt: now.toISOString() },
      },
    };
  }

  it('신선한 전국 원본을 쓰고 재병합 시 이전 환경 값과 결측 플래그를 남기지 않는다', () => {
    const old = bundle();
    old.airQuality!.pm10 = 900;
    old.airQuality!.observedAt = '2026-08-21T08:00:00+09:00';
    const national = { collectedAt: now.toISOString(),
      catalog: { fetchedAt: now.toISOString(),
        stations: [{ stationName: '수원', latitude: 37.2636, longitude: 127.0286 }] },
      observations: [bundle().airQuality!] };
    const current = currentEnvironmentalData(old, now, national,
      { latitude: 37.2636, longitude: 127.0286 });
    const input = enrichForecastWithEnvironmentalData(forecast(), old);
    input.hourly[0].qualityFlags = ['UV_UNAVAILABLE', 'STALE_AIR_QUALITY'];
    const output = enrichForecastWithEnvironmentalData(input, current);
    expect(output.current.pm10).toBe(20);
    expect(output.current.qualityFlags).not.toContain('UV_UNAVAILABLE');
    expect(output.current.qualityFlags).not.toContain('STALE_AIR_QUALITY');
    expect(environmentalDataIssues(current, now)).toEqual([]);
  });

  it('캐시가 다시 저장돼도 측정 시각이 너무 오래된 관측은 사용하지 않는다', () => {
    const old = bundle();
    old.airQuality!.observedAt = '2026-08-21T05:00:00+09:00';
    const normalized = currentEnvironmentalData(old, now);
    expect(normalized.airQuality).toBeUndefined();
    expect(normalized.sources.airQuality.state).toBe('UNAVAILABLE');
    const result = enrichForecastWithEnvironmentalData(
      enrichForecastWithEnvironmentalData(forecast(), bundle()), normalized);
    expect(result.current.pm10).toBeUndefined();
    expect(environmentalDataIssues(normalized, now)).toEqual(['PM10', 'PM25', 'O3']);
  });

  it('만료된 자외선·관측, 빈 예측 구간과 부분 오염물질 결측을 검사한다', () => {
    const old = bundle();
    old.sources.uv.cachedAt = '2026-08-20T16:00:00Z';
    old.airQuality!.ozone = undefined;
    expect(environmentalDataIssues(old, now)).toEqual(['UV', 'O3']);
    old.sources.uv.cachedAt = now.toISOString();
    old.uv!.points = [];
    expect(environmentalDataIssues(old, now)).toEqual(['UV', 'O3']);
  });

  it('가까운 측정소의 일부 값이 결측이면 인근의 완전한 관측을 우선한다', () => {
    const snapshot = { collectedAt: now.toISOString(),
      catalog: { fetchedAt: now.toISOString(), stations: [
        { stationName: '결측', latitude: 37.2636, longitude: 127.0286 },
        { stationName: '수원', latitude: 37.264, longitude: 127.029 },
      ] }, observations: [
        { ...bundle().airQuality!, stationName: '결측', pm25: undefined }, bundle().airQuality!,
      ] };
    expect(nearestNationwideAirQuality(snapshot, 37.2636, 127.0286, now)?.stationName)
      .toBe('수원');
  });

  it('GPS가 바뀌면 격자 대표점의 더 늦은 관측보다 요청 위치의 관측을 사용한다', () => {
    const snapshot = { collectedAt: now.toISOString(),
      catalog: { fetchedAt: now.toISOString(),
        stations: [{ stationName: '현재 위치', latitude: 37.26, longitude: 127.02 }] },
      observations: [{ ...bundle().airQuality!, stationName: '현재 위치',
        observedAt: '2026-08-21T09:00:00+09:00', pm10: 40 }] };
    expect(currentEnvironmentalData(bundle(), now, snapshot,
      { latitude: 37.26, longitude: 127.02 }).airQuality)
      .toMatchObject({ stationName: '현재 위치', pm10: 40 });
  });
});
