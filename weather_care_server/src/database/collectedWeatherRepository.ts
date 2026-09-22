export interface CollectedCacheRecord<T> {
  value: T;
  status: 'AVAILABLE' | 'UNAVAILABLE';
  updatedAt: string;
}

export const collectedCacheKey = {
  forecast: (nx: number, ny: number) => `COLLECTED_FORECAST_${nx}_${ny}`,
  environmental: (nx: number, ny: number) =>
    `COLLECTED_ENVIRONMENTAL_${nx}_${ny}`,
  weekly: (nx: number, ny: number) => `COLLECTED_WEEKLY_${nx}_${ny}`,
  comparison: (nx: number, ny: number) =>
    `COLLECTED_COMPARISON_${nx}_${ny}`,
  warning: (nx: number, ny: number) => `COLLECTED_WARNING_${nx}_${ny}`,
  warningRegion: (nx: number, ny: number) =>
    `COLLECTED_WARNING_REGION_${nx}_${ny}`,
  precipitation: (latitude: number, longitude: number) =>
    `COLLECTED_PRECIPITATION_${locationCacheKey(latitude, longitude)}`,
  ultraShortObservation: (nx: number, ny: number) =>
    `COLLECTED_ULTRA_SHORT_${nx}_${ny}`,
  roadIce: (latitude: number, longitude: number) =>
    `COLLECTED_ROAD_ICE_${locationCacheKey(latitude, longitude)}`,
  roadControl: (latitude: number, longitude: number) =>
    `COLLECTED_ROAD_CONTROL_${locationCacheKey(latitude, longitude)}`,
  roadControlSnapshot: 'COLLECTED_ROAD_CONTROL_SNAPSHOT',
  sourceVersion: (source: string) => `COLLECTED_SOURCE_VERSION_${source}`,
  hourlyObservation: (version: string) =>
    `COLLECTED_HOURLY_OBSERVATION_${version}`,
  visibility: (nx: number, ny: number) =>
    `COLLECTED_VISIBILITY_${nx}_${ny}`,
  midTermTemperature: (regionId: string, issueTime: string) =>
    `COLLECTED_MID_TERM_TA_${regionId}_${issueTime}`,
  midTermLand: (regionId: string, issueTime: string) =>
    `COLLECTED_MID_TERM_LAND_${regionId}_${issueTime}`,
  fetchLease: (sourceKey: string) => `COLLECTED_FETCH_LEASE_${sourceKey}`,
};

export interface CollectedSourceVersion {
  version: string;
}

export function locationCacheKey(latitude: number, longitude: number): string {
  const normalized = `${latitude.toFixed(5)}:${longitude.toFixed(5)}`;
  let hash = 2166136261;
  for (let index = 0; index < normalized.length; index += 1) {
    hash ^= normalized.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, '0');
}

export async function saveCollectedCache<T>(
  db: D1Database,
  input: {
    key: string;
    type: string;
    value: T;
    nx?: number;
    ny?: number;
    updatedAt?: Date;
  },
): Promise<void> {
  const hasGrid = input.nx !== undefined && input.ny !== undefined;
  const nx = hasGrid ? input.nx! : 0;
  const ny = hasGrid ? input.ny! : 0;
  const regionId = hasGrid ? `${nx}_${ny}` : input.key;
  await db.prepare(
    `INSERT INTO weather_cache
       (cache_key, region_id, nx, ny, cache_type, payload, status, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, 'AVAILABLE', ?)
     ON CONFLICT(cache_key) DO UPDATE SET
       region_id=excluded.region_id,
       nx=excluded.nx,
       ny=excluded.ny,
       cache_type=excluded.cache_type,
       payload=excluded.payload,
       status='AVAILABLE',
       updated_at=excluded.updated_at`,
  ).bind(
    input.key,
    regionId,
    nx,
    ny,
    input.type,
    JSON.stringify(input.value),
    (input.updatedAt ?? new Date()).toISOString(),
  ).run();
}

export async function getCollectedCache<T>(
  db: D1Database | undefined,
  key: string,
): Promise<CollectedCacheRecord<T> | null> {
  if (!db) return null;
  const row = await db.prepare(
    `SELECT payload, status, updated_at AS updatedAt
     FROM weather_cache WHERE cache_key = ?`,
  ).bind(key).first<{
    payload: string;
    status: 'AVAILABLE' | 'UNAVAILABLE';
    updatedAt: string;
  }>();
  if (!row) return null;
  try {
    return {
      value: JSON.parse(row.payload) as T,
      status: row.status,
      updatedAt: row.updatedAt,
    };
  } catch {
    return null;
  }
}

export async function collectedSourceVersionIsCurrent(
  db: D1Database,
  source: string,
  version: string,
): Promise<boolean> {
  const record = await getCollectedCache<CollectedSourceVersion>(
    db,
    collectedCacheKey.sourceVersion(source),
  );
  return record?.value.version === version;
}

export async function saveCollectedSourceVersion(
  db: D1Database,
  source: string,
  version: string,
  updatedAt: Date,
): Promise<void> {
  await saveCollectedCache(db, {
    key: collectedCacheKey.sourceVersion(source),
    type: 'COLLECTED_SOURCE_VERSION',
    value: { version } satisfies CollectedSourceVersion,
    updatedAt,
  });
}

export function cacheRecordIsFresh(
  record: { updatedAt: string } | null,
  maxAgeMs: number,
  now = new Date(),
): boolean {
  if (!record) return false;
  const updated = Date.parse(record.updatedAt);
  return Number.isFinite(updated) && now.getTime() - updated <= maxAgeMs;
}
