import nationwideForecastMigration from '../migrations/0013_nationwide_forecast.sql?raw';
import administrativeBoundariesMigration from '../migrations/0014_administrative_boundaries.sql?raw';
import { env } from 'cloudflare:test';
import gridHistoryMigration from '../migrations/0012_grid_observation_history.sql?raw';
import type { CollectedRegionBundle, CollectedWeeklyBundle } from '../src/collection/collectionTypes';
import { collectedCacheKey, saveCollectedCache } from '../src/database/collectedWeatherRepository';
import type { EnvironmentalDataBundle } from '../src/providers/environmental/environmentalDataService';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import type { KmaHourlyComparison } from '../src/providers/weather/kmaHourlyObservationProvider';
import type { UltraShortObservation } from '../src/providers/weather/kmaUltraShortObservationProvider';

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

export async function seedCollectedUltraShortObservation(
  nx: number,
  ny: number,
  value: UltraShortObservation,
  updatedAt = new Date(),
): Promise<void> {
  await ensureWeatherCache();
  await saveCollectedCache(env.DB, {
    key: collectedCacheKey.ultraShortObservation(nx, ny),
    type: 'COLLECTED_ULTRA_SHORT',
    value,
    nx,
    ny,
    updatedAt,
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
  await env.DB.exec(administrativeBoundariesMigration.replaceAll(/--[^\n]*/g, '').replaceAll(/\r?\n/g, ' '));
  await env.DB.exec(nationwideForecastMigration.replaceAll(/\r?\n/g, ' ').replace('CREATE TABLE ', 'CREATE TABLE IF NOT EXISTS ').replace('CREATE INDEX ', 'CREATE INDEX IF NOT EXISTS '));
  await env.DB.exec(gridHistoryMigration.replaceAll(/--[^\n]*/g, '').replaceAll(/\r?\n/g, ' ').replace('CREATE TABLE ', 'CREATE TABLE IF NOT EXISTS '));
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
