import { WeatherSnapshot } from '../types';

export async function saveCurrentWeather(db: any, nx: number, ny: number, snapshot: WeatherSnapshot): Promise<void> {
  await db
    .prepare(
      `INSERT OR REPLACE INTO weather_cache
       (cache_key, region_id, nx, ny, cache_type, payload, status, updated_at)
       VALUES (?, ?, ?, ?, 'CURRENT', ?, 'AVAILABLE', ?)`,
    )
    .bind(
      `CURRENT_${nx}_${ny}`,
      `${nx}_${ny}`,
      nx,
      ny,
      JSON.stringify(snapshot),
      new Date().toISOString(),
    )
    .run();
}

export async function getCurrentWeather(db: any, nx: number, ny: number): Promise<WeatherSnapshot | null> {
  const row = await db
    .prepare(
      `SELECT payload, status FROM weather_cache WHERE cache_key = ?`,
    )
    .bind(`CURRENT_${nx}_${ny}`)
    .first();
  if (!row) return null;
  if (row.status === 'UNAVAILABLE') return null;
  return JSON.parse(row.payload) as WeatherSnapshot;
}

