import { env } from 'cloudflare:test';
import type { CollectedRegionBundle, CollectedWeeklyBundle } from '../src/collection/collectionTypes';
import { collectedCacheKey, saveCollectedCache } from '../src/database/collectedWeatherRepository';
import type { EnvironmentalDataBundle } from '../src/providers/environmental/environmentalDataService';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import type { KmaHourlyComparison } from '../src/providers/weather/kmaHourlyObservationProvider';

export const unavailableEnvironmental: EnvironmentalDataBundle = {
  sources: {
    uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNAVAILABLE' },
    airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' },
  },
};

export async function seedCollectedRegion(
  nx: number,
  ny: number,
  forecast: WeatherForecast,
  environmental: EnvironmentalDataBundle = unavailableEnvironmental,
): Promise<void> {
  await ensureWeatherCache();
  await saveCollectedCache<CollectedRegionBundle>(env.DB, {
    key: `COLLECTED_REGION_${nx}_${ny}`,
    type: 'COLLECTED_REGION',
    value: { forecast, environmental },
    nx,
    ny,
  });
}

export async function seedCollectedWeekly(
  nx: number,
  ny: number,
  value: Omit<CollectedWeeklyBundle, 'collectedAt'>,
): Promise<void> {
  await ensureWeatherCache();
  await saveCollectedCache(env.DB, {
    key: collectedCacheKey.weekly(nx, ny),
    type: 'COLLECTED_WEEKLY',
    value: { ...value, collectedAt: new Date().toISOString() },
    nx,
    ny,
  });
}

export async function seedCollectedComparison(
  nx: number,
  ny: number,
  value: KmaHourlyComparison,
): Promise<void> {
  await ensureWeatherCache();
  await saveCollectedCache(env.DB, {
    key: collectedCacheKey.comparison(nx, ny),
    type: 'COLLECTED_COMPARISON',
    value,
    nx,
    ny,
  });
}

async function ensureWeatherCache(): Promise<void> {
  await env.DB.prepare(
    `CREATE TABLE IF NOT EXISTS weather_cache (
      cache_key TEXT PRIMARY KEY,
      region_id TEXT,
      nx INTEGER,
      ny INTEGER,
      cache_type TEXT NOT NULL,
      payload TEXT NOT NULL,
      status TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )`,
  ).run();
}
