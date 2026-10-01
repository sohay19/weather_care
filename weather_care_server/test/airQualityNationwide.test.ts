import { env } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  AirKoreaAirQualityProvider, nearestAirStations,
} from '../src/providers/air/airKoreaAirQualityProvider';
import { loadEnvironmentalData } from '../src/providers/environmental/environmentalDataService';
import { regionMetadataForGrid } from '../src/regions/regionCatalog';
import { saveEnvironmentalCache } from '../src/database/environmentalCacheRepository';

const now = new Date('2026-09-10T09:00:00Z');
const stations = [
  { stationName: '서울 테스트', dmX: '37.58', dmY: '126.99' },
  { stationName: '부산 테스트', dmX: '35.18', dmY: '129.19' },
  { stationName: '제주 테스트', dmX: '33.50', dmY: '126.49' },
  { stationName: '울릉 테스트', dmX: '37.47', dmY: '130.88' },
  { stationName: '백령 테스트', dmX: '37.80', dmY: '124.71' },
];

function response(items: unknown[], extra = {}) {
  return Response.json({ response: {
    header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' },
    body: { items, ...extra },
  } });
}

function mockAirFetch() {
  const fetcher = vi.fn<typeof fetch>(async (input) => {
    const url = new URL(String(input));
    if (url.pathname.endsWith('/getMsrstnList')) {
      return response(stations, { totalCount: stations.length, pageNo: 1, numOfRows: 1000 });
    }
    if (url.pathname.endsWith('/getMsrstnAcctoRltmMesureDnsty')) {
      return response([{
        stationName: url.searchParams.get('stationName'), dataTime: '2026-09-10 18:00',
        pm10Value: '31', pm25Value: '12', o3Value: '0.028',
      }]);
    }
    // UV is outside this test; reject locally, never contact external providers.
    return response([]);
  });
  vi.stubGlobal('fetch', fetcher);
  vi.spyOn(console, 'error').mockImplementation(() => {});
  return fetcher;
}

beforeEach(async () => {
  await env.DB.prepare(`CREATE TABLE IF NOT EXISTS weather_cache (
    cache_key TEXT PRIMARY KEY, region_id TEXT NOT NULL, nx INTEGER NOT NULL,
    ny INTEGER NOT NULL, cache_type TEXT NOT NULL, payload TEXT NOT NULL,
    status TEXT NOT NULL, updated_at TEXT NOT NULL)`).run();
  await env.DB.prepare('DELETE FROM weather_cache').run();
});
afterEach(() => { vi.unstubAllGlobals(); vi.restoreAllMocks(); });

describe('nationwide air-quality resolution', () => {
  it.each([
    [100, 76, '부산 테스트'], [52, 38, '제주 테스트'],
    [127, 127, '울릉 테스트'], [21, 132, '백령 테스트'],
  ])('loads uncatalogued grid %d,%d without precise GPS', async (nx, ny, stationName) => {
    mockAirFetch();
    expect(regionMetadataForGrid(Number(nx), Number(ny))).toBeUndefined();
    const bundle = await loadEnvironmentalData({ ...env, KMA_SERVICE_KEY: 'test-key' }, undefined,
      { nx: Number(nx), ny: Number(ny), now });
    expect(bundle.sources.airQuality.state).toBe('AVAILABLE');
    expect(bundle.airQuality).toMatchObject({ stationName, pm10: 31, pm25: 12, ozone: 0.028 });
  });

  it('selects again from GPS and isolates observations by station, not shared grid', async () => {
    const fetcher = mockAirFetch();
    const testEnv = { ...env, KMA_SERVICE_KEY: 'test-key' };
    const load = (coordinates?: { latitude: number; longitude: number }) =>
      loadEnvironmentalData(testEnv, undefined, { nx: 100, ny: 76, coordinates, now });
    // Deliberately distinct coordinates verify that a GRID cache cannot override GPS.
    const first = await load();
    const second = await load({ latitude: 33.50, longitude: 126.49 });
    const third = await load();
    expect(first.airQuality?.stationName).toBe('부산 테스트');
    expect(second.airQuality?.stationName).toBe('제주 테스트');
    expect(third.airQuality?.stationName).toBe('부산 테스트');
    expect(third.sources.airQuality.state).toBe('CACHED');
    const paths = fetcher.mock.calls.map(([input]) => new URL(String(input)).pathname);
    expect(paths.filter(path => path.endsWith('/getMsrstnList'))).toHaveLength(1);
    expect(paths.filter(path => path.endsWith('/getMsrstnAcctoRltmMesureDnsty'))).toHaveLength(2);
  });

  it('ignores legacy grid caches and unrelated static region metadata', async () => {
    mockAirFetch();
    await saveEnvironmentalCache(env.DB, { cacheKey: 'AIR_100_76', cacheType: 'AIR_QUALITY', nx: 100, ny: 76,
      value: { stationName: '인계동', pm10: 999, observedAt: now.toISOString() }, updatedAt: now.toISOString() });
    const bundle = await loadEnvironmentalData({ ...env, KMA_SERVICE_KEY: 'test-key' },
      regionMetadataForGrid(60, 121), { nx: 100, ny: 76, now });
    expect(bundle.airQuality?.stationName).toBe('부산 테스트');
    expect(bundle.airQuality?.pm10).toBe(31);
  });

  it('does not treat stale observations as fresh just because their cache is recent', async () => {
    mockAirFetch();
    await saveEnvironmentalCache(env.DB, { cacheKey: 'AIR_STATION_V1_부산 테스트', cacheType: 'AIR_QUALITY', nx: 100, ny: 76,
      value: { stationName: '부산 테스트', pm10: 999, observedAt: '2026-09-10T08:00:00+09:00' },
      updatedAt: now.toISOString() });
    const bundle = await loadEnvironmentalData({ ...env, KMA_SERVICE_KEY: 'test-key' }, undefined, { nx: 100, ny: 76, now });
    expect(bundle.airQuality?.pm10).toBe(31);
    expect(bundle.sources.airQuality.state).toBe('AVAILABLE');
  });

  it('uses a nearby station cache after the closest station request times out', async () => {
    const collectionTime = new Date('2026-10-01T05:50:00Z');
    await saveEnvironmentalCache(env.DB, {
      cacheKey: 'AIR_STATIONS_V1', cacheType: 'AIR_STATIONS', nx: 0, ny: 0,
      value: { fetchedAt: collectionTime.toISOString(), stations: [
        { stationName: '대야동', latitude: 37.443, longitude: 126.788 },
        { stationName: '소사본동', latitude: 37.48, longitude: 126.8 },
      ] }, updatedAt: collectionTime.toISOString(),
    });
    await saveEnvironmentalCache(env.DB, {
      cacheKey: 'AIR_STATION_V1_소사본동', cacheType: 'AIR_QUALITY', nx: 57, ny: 124,
      value: { stationName: '소사본동', observedAt: '2026-10-01T13:00:00+09:00',
        pm10: 40, pm25: 0, provider: 'AIRKOREA' },
      updatedAt: '2026-10-01T04:50:00Z',
    });
    const fetcher = vi.fn<typeof fetch>((input, init) => {
      if (!String(input).includes('getMsrstnAcctoRltmMesureDnsty')) {
        return Promise.resolve(new Response('failure', { status: 503 }));
      }
      return new Promise<Response>((_resolve, reject) => {
        init?.signal?.addEventListener('abort', () => reject(init.signal?.reason), { once: true });
      });
    });
    vi.stubGlobal('fetch', fetcher);
    vi.spyOn(console, 'error').mockImplementation(() => {});

    const result = await loadEnvironmentalData(
      { ...env, KMA_SERVICE_KEY: 'test-key' }, undefined,
      { nx: 57, ny: 124, now: collectionTime, providerTimeoutMs: 7_500 },
    );

    expect(result.airQuality).toMatchObject({ stationName: '소사본동', pm10: 40, pm25: 0 });
    expect(result.sources.airQuality.state).toBe('CACHED');
    expect(result.providerTimeouts?.airQuality).toBe(false);
    expect(fetcher.mock.calls.filter(([input]) =>
      String(input).includes('getMsrstnAcctoRltmMesureDnsty'))).toHaveLength(1);
  }, 10_000);

  it('rejects failed station catalog responses instead of marking the region unsupported', async () => {
    const fetcher = vi.fn<typeof fetch>(async () => new Response('failure', { status: 503 }));
    vi.stubGlobal('fetch', fetcher);
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const bundle = await loadEnvironmentalData({ ...env, KMA_SERVICE_KEY: 'test-key' }, undefined, { nx: 100, ny: 76, now });
    expect(bundle.airQuality).toBeUndefined();
    expect(bundle.sources.airQuality.state).toBe('UNAVAILABLE');
    expect(await env.DB.prepare('SELECT cache_key FROM weather_cache').all()).toMatchObject({ results: [] });
  });
});

describe('station list and measurement quality', () => {
  it('reads every page before choosing the geographically closest station', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = new URL(String(input));
      const page = Number(url.searchParams.get('pageNo'));
      return response([stations[page === 1 ? 0 : 1]], { totalCount: 2, pageNo: page, numOfRows: 1 });
    });
    const catalog = await new AirKoreaAirQualityProvider({ serviceKey: 'test', fetcher, now: () => now }).getStationCatalog();
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(nearestAirStations(catalog, 35.18, 129.19)[0].stationName).toBe('부산 테스트');
  });

  it('rejects an incomplete or repeating page instead of selecting from a partial country', async () => {
    const fetcher = vi.fn<typeof fetch>().mockImplementation(async () =>
      response([stations[0]], { totalCount: 2, pageNo: 1, numOfRows: 1 }));
    await expect(new AirKoreaAirQualityProvider({ serviceKey: 'test', fetcher }).getStationCatalog()).rejects.toThrow('pagination');
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it('validates coordinates, removes duplicate station names, and caps candidates at five', () => {
    const catalog = { fetchedAt: now.toISOString(), stations: Array.from({ length: 8 }, (_, index) => ({
      stationName: `station-${Math.floor(index / 2)}`, latitude: 35.18 + index / 100, longitude: 129.19,
    })) };
    expect(nearestAirStations(catalog, 35.18, 129.19)).toHaveLength(4);
    expect(() => nearestAirStations(catalog, NaN, 129.19)).toThrow();
    catalog.stations.push(...stations.map(s => ({ stationName: s.stationName, latitude: Number(s.dmX), longitude: Number(s.dmY) })));
    expect(nearestAirStations(catalog, 35.18, 129.19)).toHaveLength(5);
  });

  it('falls back from missing nearby observations and keeps the actual selected station', async () => {
    const fetcher = mockAirFetch();
    fetcher.mockImplementation(async input => {
      const url = new URL(String(input));
      if (url.pathname.endsWith('/getMsrstnList')) return response(stations.slice(0, 2), { totalCount: 2, pageNo: 1, numOfRows: 1000 });
      const stationName = url.searchParams.get('stationName');
      return response([{ stationName, dataTime: '2026-09-10 18:00', pm10Value: stationName === '부산 테스트' ? '-' : '45' }]);
    });
    const observation = await new AirKoreaAirQualityProvider({ serviceKey: 'test', fetcher, now: () => now }).getByRegion(100, 76);
    expect(observation.stationName).toBe('서울 테스트');
    expect(observation.pm10).toBe(45);
    expect(observation.pm25).toBeUndefined();
  });

  it('does not turn invalid, negative or mismatched observations into safe values', async () => {
    const fetcher = vi.fn<typeof fetch>(async () => response([
      { stationName: '다른 측정소', dataTime: '2026-09-10 18:00', pm10Value: '1' },
      { stationName: 'test', dataTime: 'bad', pm10Value: '2' },
      { stationName: 'test', dataTime: '2026-09-10 18:00', pm10Value: '-999', pm25Value: '-' },
    ]));
    await expect(new AirKoreaAirQualityProvider({ serviceKey: 'test', fetcher, now: () => now }).getByStation('test')).rejects.toThrow('no usable');
  });

  it('bounds the incoming JSON size', async () => {
    const fetcher = vi.fn<typeof fetch>(async () => new Response(' '.repeat(2 * 1024 * 1024 + 1)));
    await expect(new AirKoreaAirQualityProvider({ serviceKey: 'test', fetcher }).getStationCatalog()).rejects.toThrow('size');
  });
});
