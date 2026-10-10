import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { app } from '../src/index';
import { runWeatherCollectionJob } from '../src/collection/weatherCollectionJob';
import { collectedCacheKey, saveCollectedCache } from '../src/database/collectedWeatherRepository';
import {
  getNationwidePrecipitation,
  saveNationwidePrecipitation,
} from '../src/database/nationwidePrecipitationRepository';
import { nodeServerEnv } from '../src/node/runtime';
import { runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import type { TodayWeatherResponse } from '../src/types';
import type { EnvironmentalDataBundle } from '../src/providers/environmental/environmentalDataService';
import { latestAirKoreaForecastIssue } from '../src/collection/sourcePublicationSchedule';
import { KmaRoadIceProvider } from '../src/providers/road/kmaRoadIceProvider';
import {
  analysisGridPoint,
  nationwidePrecipitationAtPoint,
  radarGridPoint,
  type NationwidePrecipitationSnapshot,
} from '../src/providers/precipitation/precipitationObservationProvider';

const latitude = 37.487652;
const longitude = 126.893405;
const now = new Date('2026-10-02T06:30:00Z');
const cleanup: Array<() => void> = [];

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  vi.useRealTimers();
  while (cleanup.length > 0) cleanup.pop()?.();
});

function database(): SqliteD1Database {
  const directory = mkdtempSync(join(tmpdir(), 'weather-care-national-rain-'));
  const value = new SqliteD1Database(join(directory, 'weather-care.sqlite'));
  cleanup.push(() => {
    value.close();
    rmSync(directory, { recursive: true, force: true });
  });
  runSqliteMigrations(value);
  return value;
}

function snapshot(raining: boolean): NationwidePrecipitationSnapshot {
  const analysis = new ArrayBuffer(4 + 2049 * 2049 * 4);
  const analysisView = new DataView(analysis);
  analysisView.setUint16(0, 2049, true);
  analysisView.setUint16(2, 2049, true);
  const analysisPoint = analysisGridPoint(latitude, longitude);
  analysisView.setFloat32(
    4 + (analysisPoint.y * 2049 + analysisPoint.x) * 4,
    raining ? 1 : 0,
    true,
  );
  const radar = new ArrayBuffer(4 + 2305 * 2881 * 2);
  const radarView = new DataView(radar);
  radarView.setUint16(0, 2305, true);
  radarView.setUint16(2, 2881, true);
  new Int16Array(radar, 4).fill(-25_000);
  const radarPoint = radarGridPoint(latitude, longitude);
  if (raining) {
    radarView.setInt16(4 + (radarPoint.y * 2305 + radarPoint.x) * 2, 1234, true);
  }
  return {
    observedAt: '2026-10-02T15:15:00+09:00',
    analysis,
    radar,
  };
}

describe('전국 정밀 강수 선수집', () => {
  it('실제 구로동 좌표를 관측분석 500m 셀에 대응시키고 전국 자료를 왕복 저장한다', async () => {
    expect(analysisGridPoint(latitude, longitude)).toEqual({ x: 1034, y: 1430 });
    const source = snapshot(true);
    const writer = database();
    const db = nodeServerEnv(writer, {}).DB;
    await saveNationwidePrecipitation(db, source, now);
    const reader = new SqliteD1Database(writer.sqlite.name);
    cleanup.push(() => reader.close());
    const loaded = await getNationwidePrecipitation(nodeServerEnv(reader, {}).DB, now);

    expect(loaded).not.toBeNull();
    expect(nationwidePrecipitationAtPoint(loaded!, latitude, longitude)).toMatchObject({
      analysisRainDetected: true,
      radarRainDetected: true,
      radarDbz: 12.34,
      state: 'RAIN',
    });
    expect(await getNationwidePrecipitation(db, new Date('2026-10-02T07:11:00Z')))
      .toBeNull();
  });

  it('설치 등록이 0건이어도 전국 강수를 수집한다', async () => {
    const db = database();
    const source = snapshot(false);
    const requested: string[] = [];
    vi.stubGlobal('fetch', async (input: RequestInfo | URL) => {
      const url = String(input);
      requested.push(url);
      return new Response(url.includes('nph-sfc_obs_nc_api')
        ? source.analysis : source.radar);
    });
    vi.spyOn(console, 'log').mockImplementation(() => {});

    await runWeatherCollectionJob(nodeServerEnv(db, {
      KMA_APIHUB_KEY: 'test-key',
    }), {
      now,
      collectCore: false,
      collectRadar: true,
      nationwideShardIndex: 0,
    });

    expect(requested).toHaveLength(2);
    expect(requested.some((url) =>
      url.includes('nph-sfc_obs_nc_api') &&
      url.includes('obs=rn_ox') && url.includes('disp=B'))).toBe(true);
    expect(await getNationwidePrecipitation(nodeServerEnv(db, {}).DB, now))
      .not.toBeNull();
  });

  it('등록되지 않은 iOS 좌표도 전국 강수와 도로 통제 스냅샷으로 응답한다', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(now);
    const db = database();
    const env = nodeServerEnv(db, {});
    const current = {
      observedAt: '2026-10-02T15:00:00+09:00',
      forecastAt: '2026-10-02T15:00:00+09:00',
      validFrom: '2026-10-02T15:00:00+09:00',
      validTo: '2026-10-02T15:59:59+09:00',
      temperature: 22,
      apparentTemperature: 22,
      humidity: 60,
      windSpeed: 2,
      precipitationType: 'NONE' as const,
      precipitationProbability: 0,
      precipitationAmount: 0,
      snowfallAmount: 0,
      skyCondition: '맑음',
    };
    await saveCollectedCache(env.DB, {
      key: 'COLLECTED_REGION_58_125',
      type: 'COLLECTED_REGION',
      value: {
        forecast: {
          current,
          hourly: [current],
          daily: [],
          dataSource: '기상청 단기예보',
        },
        environmental: {
          sources: {
            uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNAVAILABLE' },
            airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' },
          },
        },
      },
      nx: 58,
      ny: 125,
      updatedAt: now,
    });
    await saveNationwidePrecipitation(env.DB, snapshot(false), now);
    await saveCollectedCache(env.DB, {
      key: collectedCacheKey.roadControlSnapshot,
      type: 'COLLECTED_ROAD_CONTROL_SNAPSHOT',
      value: [],
      updatedAt: now,
    });

    const response = await app.fetch(new Request(
      `http://localhost/api/v1/weather/today?nx=58&ny=125&latitude=${latitude}&longitude=${longitude}`,
    ), env);
    const body = await response.json() as {
      currentPrecipitation?: { state: string };
      currentRoadControl?: unknown;
      dataStatusMessages: Array<{ text: string }>;
    };

    expect(response.status).toBe(200);
    expect(body.currentPrecipitation?.state).toBe('DRY');
    expect(body.currentRoadControl).toBeUndefined();
    expect(body.dataStatusMessages.map((message) => message.text).join(' '))
      .not.toMatch(/현재 강수|도로 통제/);
  });

  it('설치 0건의 새 GPS 좌표에 최신 환경·특보·겨울철 도로 자료를 캐시만으로 반환한다', async () => {
    const winter = new Date('2026-12-01T06:30:00Z');
    vi.useFakeTimers();
    vi.setSystemTime(winter);
    const db = database();
    const env = nodeServerEnv(db, {});
    const fetcher = vi.fn(() => { throw new Error('요청 중 외부 조회 금지'); });
    vi.stubGlobal('fetch', fetcher);
    const current = {
      observedAt: '2026-12-01T15:00:00+09:00', forecastAt: '2026-12-01T15:00:00+09:00',
      temperature: 2, humidity: 60, windSpeed: 2, pm10: 900,
      precipitationType: 'NONE', precipitationProbability: 0, skyCondition: '맑음',
    };
    const unavailable = { sources: {
      uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNAVAILABLE' },
      airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' },
    } };
    const save = async (key: string, value: unknown) => saveCollectedCache(env.DB,
      { key, type: 'TEST', value, updatedAt: winter });
    await save('COLLECTED_REGION_58_125', {
      forecast: { current, hourly: [current], daily: [], dataSource: '기상청 단기예보' },
      environmental: unavailable,
    });
    const environmental: EnvironmentalDataBundle = {
      uv: { areaNo: '1153000000', issuedAt: '2026-12-01T15:00:00+09:00',
        provider: 'KMA_LIVING_INDEX_V5', points: [{ forecastAt: '2026-12-01T15:00:00+09:00', uvIndex: 2 }] },
      sources: {
        uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'AVAILABLE', cachedAt: winter.toISOString() },
        airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' },
      },
    };
    await save(collectedCacheKey.environmental(58, 125), environmental);
    await save(collectedCacheKey.nationwideAir, {
      catalog: { fetchedAt: winter.toISOString(), stations: [{ stationName: '구로', latitude, longitude }] },
      collectedAt: winter.toISOString(), observations: [{ stationName: '구로',
        observedAt: '2026-12-01T15:00:00+09:00', pm10: 30, pm25: 12, ozone: 0.03, provider: 'AIRKOREA' }],
    });
    await save(collectedCacheKey.nationwideAirForecast, {
      issue: latestAirKoreaForecastIssue(winter),
      areas: { 서울: [{ date: '20261201', pm25Grade: '좋음' }] },
    });
    await save(collectedCacheKey.ultraShortObservation(58, 125), {
      observedAt: '2026-12-01T15:20:00+09:00', temperature: 2, humidity: 60, windSpeed: 2,
      provider: 'KMA_APIHUB_GRID_OBSERVATION',
    });
    await save(collectedCacheKey.visibility(58, 125), {
      observedAt: '2026-12-01T14:00:00+09:00', stationId: '108', distanceKm: 12,
      visibilityMeters: 15_000, provider: 'KMA_ASOS',
    });
    await save(collectedCacheKey.warningSnapshot, {
      stations: [{ regionId: 'L1110000', regionName: '서울', stationId: '108', stationName: '서울', latitude, longitude }],
      warnings: [{ regionId: 'L1110000', regionName: '서울', typeCode: 'C', type: '한파',
        levelCode: '2', level: '주의보', commandCode: '1', announcedAt: winter.toISOString(),
        validFrom: winter.toISOString(), provider: '기상청 특보현황' }],
    });
    const roadIce = vi.spyOn(KmaRoadIceProvider.prototype, 'getRiskSegments').mockResolvedValue([{
      producedAt: winter.toISOString(), roadNumber: '001', linkId: 'test-ice', level: 2 as const,
      sourceType: 'ANALYSIS', fromLatitude: latitude, fromLongitude: longitude,
      toLatitude: latitude + 0.01, toLongitude: longitude,
    }]);
    await runWeatherCollectionJob(nodeServerEnv(db, { KMA_APIHUB_KEY: 'test-key' }), {
      now: winter, collectCore: false, collectRoadIce: true,
    });
    expect(roadIce).toHaveBeenCalledOnce();
    await save(collectedCacheKey.roadControlSnapshot, [{
      eventKey: 'test-control', startedAt: winter.toISOString(), controlKind: 'FULL',
      eventType: '공사', message: '전면 통제', latitude, longitude,
      provider: '국가교통정보센터 돌발상황정보',
    }]);
    await saveNationwidePrecipitation(env.DB,
      { ...snapshot(false), observedAt: '2026-12-01T15:15:00+09:00' }, winter);

    for (const location of [
      { latitude, longitude }, { latitude: latitude + 0.001, longitude: longitude - 0.001 },
    ]) {
      const response = await app.fetch(new Request(
        `http://localhost/api/v1/weather/today?nx=58&ny=125&latitude=${location.latitude}&longitude=${location.longitude}`,
      ), env);
      const body = await response.json() as TodayWeatherResponse;
      expect(response.status).toBe(200);
      expect(body.current).toMatchObject({ temperature: 2, uvIndex: 2,
        pm10: 30, pm25: 12, ozone: 0.03, visibilityMeters: 15_000 });
      expect(body.current.activeWarnings?.[0]?.type).toBe('한파');
      expect(body.currentPrecipitation?.state).toBe('DRY');
      expect(body.currentRoadIce?.level).toBe(2);
      expect(body.currentRoadControl?.controlKind).toBe('FULL');
      expect(body.dataStatusMessages).toEqual([]);
    }
    expect(fetcher).not.toHaveBeenCalled();
    expect(db.sqlite.prepare('SELECT COUNT(*) AS count FROM installations').get()).toEqual({ count: 0 });
    expect(db.sqlite.prepare("SELECT COUNT(*) AS count FROM weather_cache WHERE cache_type = 'COLLECTED_PRECIPITATION'").get())
      .toEqual({ count: 0 });
  });
});
