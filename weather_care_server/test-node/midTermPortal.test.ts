import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { SqliteD1Database, asD1Database, runSqliteMigrations } from '../src/node/sqliteD1';
import { reserveMidTermRequest, getApiHubUsage } from '../src/database/apiUsageRepository';
import { collectedCacheKey, getCollectedCache, saveCollectedCache } from '../src/database/collectedWeatherRepository';
import { hydrateResolvedMidTermForecast } from '../src/services/midTermForecastCache';
import { KmaMidTermProvider } from '../src/providers/weather/kmaMidTermProvider';

let database: SqliteD1Database;
const now = new Date('2026-10-10T03:00:00Z');
const region = { temperatureRegionId: '11B20202', landRegionId: '11B00000' };

beforeEach(() => { database = new SqliteD1Database(':memory:'); runSqliteMigrations(database); });
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); database.close(); });

describe('중기예보 공공데이터포털 전환', () => {
  it('포털 일 한도를 원자적으로 예약하고 APIHub 예산에서 제외한다', async () => {
    const db = asD1Database(database);
    expect(await Promise.all(Array.from({ length: 4 }, () => reserveMidTermRequest(db, 3, now))))
      .toEqual([true, true, true, false]);
    expect(await getApiHubUsage(db, now)).toEqual({ requestCount: 0, responseBytes: 0 });
    expect(await reserveMidTermRequest(db, 3, new Date('2026-10-10T15:00:00Z'))).toBe(true);
  });

  it('기존 APIHub 캐시를 포털 원본으로 교체하고 다음 조회는 공유 캐시를 사용한다', async () => {
    const db = asD1Database(database);
    const key = collectedCacheKey.midTermTemperature(region.temperatureRegionId, '202610100600');
    await saveCollectedCache(db, { key, type: 'COLLECTED_MID_TERM_TA', updatedAt: now,
      value: { regionId: region.temperatureRegionId, issueTime: '202610100600', item: { regId: region.temperatureRegionId, taMin4: -1 } } });
    const fetcher = vi.fn(async (input: RequestInfo | URL) => {
      const url = new URL(String(input));
      expect(url.hostname).toBe('apis.data.go.kr');
      expect(url.searchParams.has('authKey')).toBe(false);
      const item = url.pathname.endsWith('/getMidTa')
        ? { regId: region.temperatureRegionId, taMin4: 12, taMax4: 20 }
        : { regId: region.landRegionId, wf4Am: '구름많음', wf4Pm: '맑음', rnSt4Am: 20, rnSt4Pm: 10 };
      return new Response(JSON.stringify({ response: { header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' }, body: { items: { item: [item] } } } }));
    });
    vi.stubGlobal('fetch', fetcher);
    const first = await hydrateResolvedMidTermForecast({ db, serviceKey: 'portal-key', region, now });
    expect(first.cacheStatus).toBe('MISS_REFRESHED');
    expect(first.days[0]).toMatchObject({ minTemperature: 12, maxTemperature: 20, weatherDataComplete: true });
    expect((await getCollectedCache<{ provider: string }>(db, key))?.value.provider).toBe('KMA_DATA_GO_KR');
    expect((await hydrateResolvedMidTermForecast({ db, serviceKey: 'portal-key', region, now })).cacheStatus).toBe('HIT');
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(await db.prepare("SELECT COUNT(*) AS count FROM weather_cache WHERE cache_type='MID_TERM_FETCH_LEASE'").first('count')).toBe(0);
  });

  it('인증 거부 시 이전 발표·다른 제공처로 재요청하지 않고 기존 성공 캐시를 보존한다', async () => {
    const db = asD1Database(database);
    const key = collectedCacheKey.midTermTemperature(region.temperatureRegionId, '202610100600');
    const legacy = { regionId: region.temperatureRegionId, issueTime: '202610100600', item: { regId: region.temperatureRegionId, taMin4: 12 } };
    await saveCollectedCache(db, { key, type: 'COLLECTED_MID_TERM_TA', value: legacy, updatedAt: now });
    const fetcher = vi.fn(async () => new Response('denied', { status: 403 }));
    vi.stubGlobal('fetch', fetcher);
    await expect(hydrateResolvedMidTermForecast({ db, serviceKey: 'portal-key', region: { temperatureRegionId: region.temperatureRegionId }, now }))
      .rejects.toThrow('403');
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect((await getCollectedCache(db, key))?.value).toEqual(legacy);
    expect(await db.prepare("SELECT COUNT(*) AS count FROM weather_cache WHERE cache_type='MID_TERM_FETCH_LEASE'").first('count')).toBe(0);
  });

  it('키가 없으면 발신하지 않고 잘못된 예보구역 응답을 수용하지 않는다', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ response: {
      header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' }, body: { items: { item: [{ regId: 'wrong-region', taMin4: 10 }] } },
    } })));
    expect(() => new KmaMidTermProvider({ fetcher }).getTemperature(region.temperatureRegionId, '202610100600')).toThrow('not configured');
    expect(fetcher).not.toHaveBeenCalled();
    await expect(new KmaMidTermProvider({ serviceKey: 'portal-key', fetcher }).getTemperature(region.temperatureRegionId, '202610100600')).rejects.toThrow('no item');
  });
});
