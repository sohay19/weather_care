import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { runWeatherCollectionJob } from '../src/collection/weatherCollectionJob';
import { nodeServerEnv } from '../src/node/runtime';
import { runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import {
  latestBaseDateTimes,
  KmaWeatherProvider,
} from '../src/providers/weather/kmaWeatherProvider';
import { nationwideForecastGridShard } from '../src/regions/nationwideForecastGridCatalog';

describe('Node 전국 선수집', () => {
  const cleanup: Array<() => void> = [];

  afterEach(() => {
    vi.restoreAllMocks();
    while (cleanup.length > 0) cleanup.pop()?.();
  });

  it('설치 지역이 없어도 지정한 전국 묶음의 기본 예보 캐시를 만든다', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'weather-care-prewarm-'));
    const database = new SqliteD1Database(join(directory, 'weather-care.sqlite'));
    cleanup.push(() => {
      database.close();
      rmSync(directory, { recursive: true, force: true });
    });
    runSqliteMigrations(database);

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
});
