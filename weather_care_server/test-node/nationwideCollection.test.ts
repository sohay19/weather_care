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
  inspectOperationalPrewarm,
} from '../src/node/prewarmNationwide';
import {
  latestBaseDateTimes,
  KmaWeatherProvider,
} from '../src/providers/weather/kmaWeatherProvider';
import type { DailyWeatherForecast } from '../src/providers/weather/weatherProvider';
import { latestMidTermIssueTimes } from '../src/providers/weather/kmaMidTermProvider';
import { nationwideForecastGridShard } from '../src/regions/nationwideForecastGridCatalog';
import { kmaGridCoordinates } from '../src/regions/kmaGridCoordinates';
import { supportedKmaMidTermRegionIds } from '../src/regions/kmaMidTermRegionCatalog';

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

    database.sqlite.prepare(
      'DELETE FROM weather_cache WHERE cache_key IN (?, ?)',
    ).run(
      collectedCacheKey.visibility(60, 121),
      collectedCacheKey.sourceVersion('ASOS_VISIBILITY_HOURLY'),
    );
    getObservations.mockResolvedValue(
      snapshot('2026-09-18T08:00:00+09:00'),
    );
    await runWeatherCollectionJob(env, {
      now,
      collectCore: false,
      collectHourlyObservations: true,
    });
    await runWeatherCollectionJob(env, {
      now,
      collectCore: false,
      collectHourlyObservations: true,
    });
    expect(getObservations).toHaveBeenCalledTimes(2);
    await expect(getCollectedCache(
      env.DB,
      collectedCacheKey.sourceVersion('ASOS_VISIBILITY_HOURLY'),
    )).resolves.toBeNull();
  });

  it('운영 선수집은 전국·활성 지역·좌표 필수 캐시를 모두 검증한다', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'weather-care-completeness-'));
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
          latitude, longitude, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).run(
      'active-installation',
      60,
      121,
      'region_60_121',
      'GPS',
      'Asia/Seoul',
      37.2636,
      127.0286,
      nowIso(),
      nowIso(),
    );
    const env = nodeServerEnv(database, {});
    const runtime = { database, env, close: () => database.close() };
    const grid = [{ nx: 60, ny: 121 }] as const;
    const requiredCaches = [
      collectedCacheKey.forecast(60, 121),
      'CURRENT_60_121',
      'COLLECTED_REGION_60_121',
      collectedCacheKey.weekly(60, 121),
      collectedCacheKey.environmental(60, 121),
      collectedCacheKey.warning(60, 121),
      collectedCacheKey.ultraShortObservation(60, 121),
      collectedCacheKey.precipitation(37.2636, 127.0286),
      collectedCacheKey.roadControl(37.2636, 127.0286),
    ];
    for (const key of requiredCaches) {
      await saveCollectedCache(env.DB, {
        key,
        type: 'TEST',
        value: key.startsWith('COLLECTED_ROAD_CONTROL_')
          ? null
          : key.startsWith('COLLECTED_WEEKLY_')
            ? {
                observedDays: [
                  '20260914',
                  '20260915',
                  '20260916',
                  '20260917',
                  '20260918',
                  '20260919',
                  '20260920',
                ].map((date) => ({ date, weatherDataComplete: true })),
              }
            : { ready: true },
        nx: key.includes('60_121') ? 60 : undefined,
        ny: key.includes('60_121') ? 121 : undefined,
      });
    }
    const midTermIssue = latestMidTermIssueTimes(
      new Date('2026-09-21T05:00:00Z'),
      1,
    )[0];
    const midTermKeys = new Map<string, string>();
    for (const { temperatureRegionId, landRegionId } of
      supportedKmaMidTermRegionIds()) {
      midTermKeys.set(
        collectedCacheKey.midTermTemperature(temperatureRegionId, midTermIssue),
        temperatureRegionId,
      );
      if (landRegionId) {
        midTermKeys.set(
          collectedCacheKey.midTermLand(landRegionId, midTermIssue),
          landRegionId,
        );
      }
    }
    for (const [key, regionId] of midTermKeys) {
      await saveCollectedCache(env.DB, {
        key,
        type: 'TEST_MID_TERM',
        value: { regionId, issueTime: midTermIssue, item: { regId: regionId } },
      });
    }

    const incomplete = inspectOperationalPrewarm(
      runtime,
      new Date('2026-09-21T05:00:00Z'),
      grid,
    );
    expect(incomplete.missingCaches).toBe(1);
    expect(incomplete.missingSample).toEqual([
      collectedCacheKey.visibility(60, 121),
    ]);

    await saveCollectedCache(env.DB, {
      key: collectedCacheKey.visibility(60, 121),
      type: 'COLLECTED_VISIBILITY',
      value: {},
      nx: 60,
      ny: 121,
    });
    expect(inspectOperationalPrewarm(
      runtime,
      new Date('2026-09-21T05:00:00Z'),
      grid,
    ).missingCaches).toBe(1);

    await saveCollectedCache(env.DB, {
      key: collectedCacheKey.visibility(60, 121),
      type: 'COLLECTED_VISIBILITY',
      value: { visibilityMeters: 20_000 },
      nx: 60,
      ny: 121,
    });
    database.sqlite.prepare(
      'UPDATE weather_cache SET status = ? WHERE cache_key = ?',
    ).run('UNAVAILABLE', collectedCacheKey.forecast(60, 121));
    expect(inspectOperationalPrewarm(
      runtime,
      new Date('2026-09-21T05:00:00Z'),
      grid,
    ).missingSample).toEqual([collectedCacheKey.forecast(60, 121)]);
    database.sqlite.prepare(
      'UPDATE weather_cache SET status = ? WHERE cache_key = ?',
    ).run('AVAILABLE', collectedCacheKey.forecast(60, 121));

    expect(inspectOperationalPrewarm(
      runtime,
      new Date('2026-09-21T05:00:00Z'),
      grid,
    )).toMatchObject({
      requiredCaches: 10 + midTermKeys.size,
      collectedCaches: 10 + midTermKeys.size,
      missingCaches: 0,
    });
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
