export interface EnvironmentalCacheEntry<T> {
  value: T;
  updatedAt: string;
}

export async function getEnvironmentalCache<T>(
  db: D1Database,
  cacheKey: string,
): Promise<EnvironmentalCacheEntry<T> | null> {
  const row = await db
    .prepare(
      `SELECT payload, updated_at
       FROM weather_cache
       WHERE cache_key = ? AND status = 'AVAILABLE'`,
    )
    .bind(cacheKey)
    .first<{ payload: string; updated_at: string }>();
  if (!row) return null;
  return {
    value: JSON.parse(row.payload) as T,
    updatedAt: row.updated_at,
  };
}

export async function saveEnvironmentalCache<T>(
  db: D1Database,
  options: {
    cacheKey: string;
    cacheType: 'UV' | 'AIR_QUALITY';
    nx: number;
    ny: number;
    value: T;
    updatedAt: string;
  },
): Promise<void> {
  await db
    .prepare(
      `INSERT OR REPLACE INTO weather_cache
       (cache_key, region_id, nx, ny, cache_type, payload, status, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, 'AVAILABLE', ?)`,
    )
    .bind(
      options.cacheKey,
      `${options.nx}_${options.ny}`,
      options.nx,
      options.ny,
      options.cacheType,
      JSON.stringify(options.value),
      options.updatedAt,
    )
    .run();
}
