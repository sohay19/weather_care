import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { runWeatherCollectionJob } from '../src/collection/weatherCollectionJob';
import type { CollectedWeeklyBundle } from '../src/collection/collectionTypes';
import {
  collectedCacheKey,
  getCollectedCache,
  saveCollectedCache,
} from '../src/database/collectedWeatherRepository';
import { nodeServerEnv } from '../src/node/runtime';
import { runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { KmaDailyObservationProvider } from '../src/providers/weather/kmaDailyObservationProvider';
import {
  KmaHourlyObservationProvider,
  latestCompletedKoreanHour,
  type KmaHourlyObservationSnapshot,
} from '../src/providers/weather/kmaHourlyObservationProvider';
import {
  latestBaseDateTimes,
  KmaWeatherProvider,
} from '../src/providers/weather/kmaWeatherProvider';
import type { DailyWeatherForecast } from '../src/providers/weather/weatherProvider';
import { nationwideForecastGridShard } from '../src/regions/nationwideForecastGridCatalog';
import { kmaGridCoordinates } from '../src/regions/kmaGridCoordinates';

describe('Node 전국 선수집', () => {
  const cleanup: Array<() => void> = [];

  afterEach(() => {
    vi.restoreAllMocks();
    while (cleanup.length > 0) cleanup.pop()?.();
  });

  it('활성 설치 상세수집 없이 지정한 전국 묶음의 기본 예보 캐시를 만든다', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'weather-care-prewarm-'));
    const database = new SqliteD1Database(join(directory, 'weather-care.sqlite'));
    cleanup.push(() => {
      database.close();
      rmSync(directory, { recursive: true, force: true });
    });
    runSqliteMigrations(database);
    database.sqlite.prepare(
      `INSERT INTO installation_credentials
         (installation_id, secret_hash, created_at)
       VALUES (?, ?, ?)`,
    ).run('active-installation', 'test-secret-hash', nowIso());
    database.sqlite.prepare(
      `INSERT INTO installations
         (installation_id, nx, ny, region_topic, location_mode, timezone,
          created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ).run(
      'active-installation',
      60,
      121,
      'region_60_121',
      'MANUAL',
      'Asia/Seoul',
      nowIso(),
      nowIso(),
    );

    const now = new Date('2026-09-18T09:30:00Z');
    const issue = latestBaseDateTimes(now, 1)[0]!;
    const latest = vi.spyOn(KmaWeatherProvider.prototype, 'getLatestForecastByRegion')
      .mockImplementation(async () => ({
        current: { observedAt: now.toISOString() },
        hourly: [],
        daily: [],
        baseDate: issue.baseDate,
        baseTime: issue.baseTime,
        dataSource: '테스트 예보',
      }));
    const full = vi.spyOn(KmaWeatherProvider.prototype, 'getForecastByRegion');
    vi.spyOn(console, 'log').mockImplementation(() => {});

    await runWeatherCollectionJob(nodeServerEnv(database, {}), {
      now,
      collectActiveDetails: false,
      nationwideShardIndex: 0,
    });

    const expected = nationwideForecastGridShard(0).length;
    const row = database.sqlite.prepare(
      "SELECT COUNT(*) AS count FROM weather_cache WHERE cache_type = 'COLLECTED_REGION'",
    ).get() as { count: number };
    expect(latest).toHaveBeenCalledTimes(expected);
    expect(full).not.toHaveBeenCalled();
    expect(row.count).toBe(expected);
  });

  it('스케줄러 시작용 요청은 어제까지 최근 7일의 누락 관측을 보충한다', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'weather-care-observation-backfill-'));
    const database = new SqliteD1Database(join(directory, 'weather-care.sqlite'));
    cleanup.push(() => {
      database.close();
      rmSync(directory, { recursive: true, force: true });
    });
    runSqliteMigrations(database);
    database.sqlite.prepare(
      `INSERT INTO installation_credentials
         (installation_id, secret_hash, created_at)
       VALUES (?, ?, ?)`,
    ).run('active-installation', 'test-secret-hash', nowIso());
    database.sqlite.prepare(
      `INSERT INTO installations
         (installation_id, nx, ny, region_topic, location_mode, timezone,
          created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ).run(
      'active-installation',
      60,
      121,
      'region_60_121',
      'MANUAL',
      'Asia/Seoul',
      nowIso(),
      nowIso(),
    );
    const env = nodeServerEnv(database, {
      KMA_APIHUB_KEY: 'test-api-hub-key',
      NATIONWIDE_PRECOLLECT_ENABLED: 'false',
    });
    await saveCollectedCache(env.DB, {
      key: collectedCacheKey.weekly(60, 121),
      type: 'COLLECTED_WEEKLY',
      value: {
        midTermDays: [],
        observedDays: [],
        airQuality: [],
        collectedAt: nowIso(),
      } satisfies CollectedWeeklyBundle,
      nx: 60,
      ny: 121,
      updatedAt: new Date(nowIso()),
    });

    const dates = [
      '2026-09-11',
      '2026-09-12',
      '2026-09-13',
      '2026-09-14',
      '2026-09-15',
      '2026-09-16',
      '2026-09-17',
    ];
    const getDaily = vi.spyOn(KmaDailyObservationProvider.prototype, 'getDailyByLocations')
      .mockImplementation(async (locations, startDate, endDate) => {
        expect(startDate).toBe('2026-09-11');
        expect(endDate).toBe('2026-09-17');
        return locations.map(() => dates.map(observation));
      });
    vi.spyOn(console, 'log').mockImplementation(() => {});

    const options = {
      now: new Date('2026-09-18T01:00:00Z'),
      collectCore: false,
      dailyObservationLookbackDays: 7,
    } as const;
    await runWeatherCollectionJob(env, options);

    const cached = await getCollectedCache<CollectedWeeklyBundle>(
      env.DB,
      collectedCacheKey.weekly(60, 121),
    );
    expect(getDaily).toHaveBeenCalledTimes(1);
    expect(cached?.value.observedDays.map((day) => day.date)).toEqual(
      dates.map((date) => date.replaceAll('-', '')),
    );

    getDaily.mockClear();
    await runWeatherCollectionJob(env, options);
    expect(getDaily).not.toHaveBeenCalled();
  });

  it('스케줄러 시작 시 기존 시간관측 캐시에 없는 가시거리를 즉시 보충한다', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'weather-care-visibility-backfill-'));
    const database = new SqliteD1Database(join(directory, 'weather-care.sqlite'));
    cleanup.push(() => {
      database.close();
      rmSync(directory, { recursive: true, force: true });
    });
    runSqliteMigrations(database);
    database.sqlite.prepare(
      `INSERT INTO installation_credentials
         (installation_id, secret_hash, created_at)
       VALUES (?, ?, ?)`,
    ).run('active-installation', 'test-secret-hash', nowIso());
    database.sqlite.prepare(
      `INSERT INTO installations
         (installation_id, nx, ny, region_topic, location_mode, timezone,
          created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ).run(
      'active-installation',
      60,
      121,
      'region_60_121',
      'MANUAL',
      'Asia/Seoul',
      nowIso(),
      nowIso(),
    );
    const env = nodeServerEnv(database, {
      KMA_APIHUB_KEY: 'test-api-hub-key',
      NATIONWIDE_PRECOLLECT_ENABLED: 'false',
    });
    const now = new Date('2026-09-18T01:23:00Z');
    const currentHour = latestCompletedKoreanHour(now);
    const coordinates = kmaGridCoordinates(60, 121)!;
    const snapshot = (
      observedAt: string,
      visibilityMeters?: number,
    ): KmaHourlyObservationSnapshot => ({
      observedAt,
      stations: [{
        observedAt,
        stationId: 'TEST',
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        temperature: 23,
        humidity: 60,
        windSpeed: 2,
        visibilityMeters,
      }],
    });
    const getObservations = vi.spyOn(
      KmaHourlyObservationProvider.prototype,
      'getObservationsAt',
    ).mockResolvedValue(
      snapshot('2026-09-18T08:00:00+09:00', 20_000),
    );
    vi.spyOn(console, 'log').mockImplementation(() => {});

    await runWeatherCollectionJob(env, {
      now,
      collectCore: false,
      collectHourlyObservations: true,
    });

    expect(getObservations).toHaveBeenCalledOnce();
    expect(getObservations).toHaveBeenCalledWith(
      currentHour,
      { includeVisibility: true },
    );
    const visibility = await getCollectedCache<{ visibilityMeters: number }>(
      env.DB,
      collectedCacheKey.visibility(60, 121),
    );
    expect(visibility?.value.visibilityMeters).toBe(20_000);

    getObservations.mockClear();
    await runWeatherCollectionJob(env, {
      now,
      collectCore: false,
      collectHourlyObservations: true,
    });
    expect(getObservations).not.toHaveBeenCalled();
  });
});

function observation(date: string): DailyWeatherForecast {
  return {
    date: date.replaceAll('-', ''),
    forecastSource: 'KMA_OBSERVATION',
    historical: true,
    minTemperature: 18,
    maxTemperature: 27,
    minTemperatureSource: 'DAILY',
    maxTemperatureSource: 'DAILY',
    snowfallDataAvailable: true,
    weatherDataComplete: true,
    precipitationDetail: {
      kind: 'OBSERVATION',
      hours: [],
      observedAmount: 0,
    },
    skyCondition: '강수 관측 없음',
    precipitationProbability: 0,
    precipitationAmount: 0,
    snowProbability: 0,
    snowfallAmount: 0,
  };
}

function nowIso(): string {
  return new Date('2026-09-18T09:00:00Z').toISOString();
}
