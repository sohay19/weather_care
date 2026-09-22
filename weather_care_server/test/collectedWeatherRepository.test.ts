import { env } from 'cloudflare:test';
import { beforeEach, describe, expect, it } from 'vitest';
import {
  getCollectedCache,
  locationCacheKey,
  saveCollectedCache,
} from '../src/database/collectedWeatherRepository';

describe('collected weather repository', () => {
  beforeEach(async () => {
    await env.DB.exec('DROP TABLE IF EXISTS weather_cache');
    await env.DB.prepare(
      `CREATE TABLE weather_cache (
        cache_key TEXT PRIMARY KEY,
        region_id TEXT NOT NULL,
        nx INTEGER NOT NULL,
        ny INTEGER NOT NULL,
        cache_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'AVAILABLE',
        updated_at TEXT NOT NULL
      )`,
    ).run();
  });

  it('stores location-only cache records in the legacy non-null schema', async () => {
    await saveCollectedCache(env.DB, {
      key: 'COLLECTED_PRECIPITATION_12345678',
      type: 'COLLECTED_PRECIPITATION',
      value: { precipitation: true },
    });

    const row = await env.DB.prepare(
      `SELECT region_id AS regionId, nx, ny FROM weather_cache
       WHERE cache_key = ?`,
    ).bind('COLLECTED_PRECIPITATION_12345678').first<{
      regionId: string;
      nx: number;
      ny: number;
    }>();
    expect(row).toEqual({
      regionId: 'COLLECTED_PRECIPITATION_12345678',
      nx: 0,
      ny: 0,
    });
    await expect(getCollectedCache(env.DB, 'COLLECTED_PRECIPITATION_12345678'))
      .resolves.toMatchObject({ value: { precipitation: true } });
  });

  it('uses one cache key for ordinary stationary GPS drift', () => {
    expect(locationCacheKey(37.48771, 126.89391)).toBe(
      locationCacheKey(37.48774, 126.89394),
    );
    expect(locationCacheKey(37.48771, 126.89391)).not.toBe(
      locationCacheKey(37.48901, 126.89501),
    );
  });
});
