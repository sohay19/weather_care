import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { runCurrentObservationCollectionJob } from '../src/collection/weatherCollectionJob';
import {
  collectedCacheKey,
  getCollectedCache,
} from '../src/database/collectedWeatherRepository';
import { getApiHubUsage } from '../src/database/apiUsageRepository';
import { nodeServerEnv } from '../src/node/runtime';
import { runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { KmaAwsMinuteObservationProvider } from '../src/providers/weather/kmaAwsMinuteObservationProvider';
import { KmaGridObservationProvider } from '../src/providers/weather/kmaGridObservationProvider';
import type { UltraShortObservation } from '../src/providers/weather/kmaUltraShortObservationProvider';

describe('현재 관측 재시도', () => {
  const cleanup: Array<() => void> = [];

  afterEach(() => {
    vi.restoreAllMocks();
    while (cleanup.length > 0) cleanup.pop()?.();
  });

  it('격자와 AWS가 비어도 다음 회차에 같은 관측 시각을 다시 요청한다', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'weather-care-current-retry-'));
    const database = new SqliteD1Database(join(directory, 'weather-care.sqlite'));
    cleanup.push(() => {
      database.close();
      rmSync(directory, { recursive: true, force: true });
    });
    runSqliteMigrations(database);
    database.sqlite.prepare(
      `INSERT INTO installation_credentials
         (installation_id, secret_hash, created_at) VALUES (?, ?, ?)`,
    ).run('active', 'test-hash', '2026-10-02T00:00:00Z');
    database.sqlite.prepare(
      `INSERT INTO installations
         (installation_id, nx, ny, region_topic, location_mode, timezone,
          created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ).run('active', 58, 125, 'region_58_125', 'MANUAL', 'Asia/Seoul',
      '2026-10-02T00:00:00Z', '2026-10-02T00:00:00Z');
    const env = nodeServerEnv(database, {
      KMA_APIHUB_KEY: 'test-key',
      NATIONWIDE_PRECOLLECT_ENABLED: 'false',
    });
    const observation: UltraShortObservation = {
      observedAt: '2026-10-02T11:50:00+09:00',
      provider: 'KMA_APIHUB_GRID_OBSERVATION',
      rainDetected: false,
      temperature: 19.5,
      humidity: 26,
      windSpeed: 3.1,
    };
    const grid = vi.spyOn(KmaGridObservationProvider.prototype, 'getAt')
      .mockResolvedValueOnce(new Map())
      .mockResolvedValueOnce(new Map())
      .mockResolvedValueOnce(new Map([['58:125', observation]]));
    const aws = vi.spyOn(KmaAwsMinuteObservationProvider.prototype, 'getCurrentByLocations')
      .mockResolvedValue([undefined]);
    const logs: string[] = [];
    vi.spyOn(console, 'log').mockImplementation((message) => logs.push(message));

    await runCurrentObservationCollectionJob(env, new Date('2026-10-02T02:56:00Z'));
    expect(await getCollectedCache(env.DB, collectedCacheKey.ultraShortObservation(58, 125)))
      .toBeNull();

    await runCurrentObservationCollectionJob(env, new Date('2026-10-02T02:58:00Z'));
    const cached = await getCollectedCache<UltraShortObservation>(
      env.DB, collectedCacheKey.ultraShortObservation(58, 125),
    );
    expect(cached?.value).toMatchObject(observation);
    expect(grid).toHaveBeenCalledTimes(3);
    expect(grid.mock.calls.map(([, clock]) => clock.toISOString()))
      .toEqual([
        '2026-10-02T11:50:00.000Z',
        '2026-10-02T11:40:00.000Z',
        '2026-10-02T11:50:00.000Z',
      ]);
    expect(grid.mock.calls.every(([, , options]) => options?.requiredOnly === true))
      .toBe(true);
    expect(aws).not.toHaveBeenCalled();
    await expect(getApiHubUsage(env.DB, new Date('2026-10-02T02:58:00Z')))
      .resolves.toEqual({ requestCount: 9, responseBytes: 9_000_000 });
    expect(logs.some((line) => line.includes('"missing":1'))).toBe(true);
    expect(logs.some((line) => line.includes('"stored":1'))).toBe(true);
  });
});
