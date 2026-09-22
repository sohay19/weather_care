import {
  collectedCacheKey,
  getCollectedCache,
  saveCollectedCache,
} from '../database/collectedWeatherRepository';
import {
  buildMidTermDailyForecast,
  KmaMidTermProvider,
  latestMidTermIssueTimes,
  type KmaMidTermItem,
} from '../providers/weather/kmaMidTermProvider';
import type { DailyWeatherForecast } from '../providers/weather/weatherProvider';
import {
  resolveKmaMidTermLocation,
  type KmaMidTermLocationContext,
  type KmaMidTermRegionIds,
} from '../regions/kmaMidTermRegionCatalog';

export type MidTermCacheStatus =
  | 'HIT'
  | 'MISS_REFRESHED'
  | 'STALE_FALLBACK'
  | 'UNAVAILABLE';

export interface MidTermForecastHydration {
  days: DailyWeatherForecast[];
  region: KmaMidTermRegionIds;
  issueTime?: string;
  issuedAt?: string;
  cacheStatus: MidTermCacheStatus;
}

interface MidTermSourceRecord {
  regionId: string;
  issueTime: string;
  item: KmaMidTermItem;
}

interface SourceLoadResult {
  item: KmaMidTermItem;
  refreshed: boolean;
}

const FETCH_LEASE_MAX_AGE_MS = 15_000;
const FETCH_LEASE_WAIT_MS = 7_000;

export async function hydrateMidTermForecast(input: {
  db: D1Database;
  serviceKey?: string;
  apiHubKey?: string;
  location: KmaMidTermLocationContext;
  now?: Date;
}): Promise<MidTermForecastHydration> {
  const region = resolveKmaMidTermLocation(input.location);
  if (!region) {
    return { days: [], region: emptyRegion(), cacheStatus: 'UNAVAILABLE' };
  }
  return hydrateResolvedMidTermForecast({ ...input, region });
}

export async function hydrateResolvedMidTermForecast(input: {
  db: D1Database;
  serviceKey?: string;
  apiHubKey?: string;
  region: KmaMidTermRegionIds;
  now?: Date;
}): Promise<MidTermForecastHydration> {
  const now = input.now ?? new Date();
  const provider = new KmaMidTermProvider({
    serviceKey: input.serviceKey,
    apiHubKey: input.apiHubKey,
    now: () => now,
  });
  const issueTimes = latestMidTermIssueTimes(now, 3);

  for (let issueIndex = 0; issueIndex < issueTimes.length; issueIndex += 1) {
    const issueTime = issueTimes[issueIndex];
    try {
      const [temperature, land] = await Promise.all([
        loadMidTermSource({
          db: input.db,
          key: collectedCacheKey.midTermTemperature(
            input.region.temperatureRegionId,
            issueTime,
          ),
          type: 'COLLECTED_MID_TERM_TA',
          regionId: input.region.temperatureRegionId,
          issueTime,
          now,
          fetch: () => provider.getTemperature(
            input.region.temperatureRegionId,
            issueTime,
          ),
        }),
        input.region.landRegionId
          ? loadMidTermSource({
              db: input.db,
              key: collectedCacheKey.midTermLand(
                input.region.landRegionId,
                issueTime,
              ),
              type: 'COLLECTED_MID_TERM_LAND',
              regionId: input.region.landRegionId,
              issueTime,
              now,
              fetch: () => provider.getLandForecast(
                input.region.landRegionId!,
                issueTime,
              ),
            })
          : Promise.resolve(undefined),
      ]);
      const days = buildMidTermDailyForecast(
        issueTime,
        temperature.item,
        land?.item,
      );
      if (days.length === 0) continue;
      return {
        days,
        region: input.region,
        issueTime,
        issuedAt: days[0]?.issuedAt,
        cacheStatus: issueIndex > 0
          ? 'STALE_FALLBACK'
          : temperature.refreshed || land?.refreshed
            ? 'MISS_REFRESHED'
            : 'HIT',
      };
    } catch {
      // The newest publication can legitimately be delayed. Try earlier
      // publications and expose that fallback in the response metadata.
    }
  }
  return { days: [], region: input.region, cacheStatus: 'UNAVAILABLE' };
}

async function loadMidTermSource(input: {
  db: D1Database;
  key: string;
  type: string;
  regionId: string;
  issueTime: string;
  now: Date;
  fetch: () => Promise<KmaMidTermItem>;
}): Promise<SourceLoadResult> {
  const cached = await getCollectedCache<MidTermSourceRecord>(input.db, input.key);
  if (cached?.status === 'AVAILABLE') {
    return { item: cached.value.item, refreshed: false };
  }

  const owner = crypto.randomUUID();
  const leasePayload = JSON.stringify({ owner });
  const acquired = await acquireFetchLease(
    input.db,
    input.key,
    leasePayload,
    input.now,
  );
  if (!acquired) {
    const shared = await waitForMidTermSource(input.db, input.key);
    if (shared) return { item: shared.item, refreshed: false };
    throw new Error('Timed out waiting for the shared mid-term fetch');
  }

  try {
    const afterLease = await getCollectedCache<MidTermSourceRecord>(
      input.db,
      input.key,
    );
    if (afterLease?.status === 'AVAILABLE') {
      return { item: afterLease.value.item, refreshed: false };
    }
    const item = await input.fetch();
    await saveCollectedCache<MidTermSourceRecord>(input.db, {
      key: input.key,
      type: input.type,
      value: {
        regionId: input.regionId,
        issueTime: input.issueTime,
        item,
      },
      updatedAt: input.now,
    });
    return { item, refreshed: true };
  } finally {
    await releaseFetchLease(input.db, input.key, leasePayload);
  }
}

async function acquireFetchLease(
  db: D1Database,
  sourceKey: string,
  payload: string,
  now: Date,
): Promise<boolean> {
  const key = collectedCacheKey.fetchLease(sourceKey);
  const staleBefore = new Date(
    now.getTime() - FETCH_LEASE_MAX_AGE_MS,
  ).toISOString();
  const result = await db.prepare(
    `INSERT INTO weather_cache
       (cache_key, region_id, nx, ny, cache_type, payload, status, updated_at)
     VALUES (?, ?, 0, 0, 'MID_TERM_FETCH_LEASE', ?, 'AVAILABLE', ?)
     ON CONFLICT(cache_key) DO UPDATE SET
       payload=excluded.payload,
       status='AVAILABLE',
       updated_at=excluded.updated_at
     WHERE weather_cache.cache_type = 'MID_TERM_FETCH_LEASE'
       AND weather_cache.updated_at < ?`,
  ).bind(key, key, payload, now.toISOString(), staleBefore).run();
  return (result.meta.changes ?? 0) > 0;
}

async function releaseFetchLease(
  db: D1Database,
  sourceKey: string,
  payload: string,
): Promise<void> {
  await db.prepare(
    `DELETE FROM weather_cache
     WHERE cache_key = ? AND cache_type = 'MID_TERM_FETCH_LEASE' AND payload = ?`,
  ).bind(collectedCacheKey.fetchLease(sourceKey), payload).run();
}

async function waitForMidTermSource(
  db: D1Database,
  key: string,
): Promise<MidTermSourceRecord | undefined> {
  const startedAt = Date.now();
  let waitMs = 75;
  while (Date.now() - startedAt < FETCH_LEASE_WAIT_MS) {
    await new Promise((resolve) => setTimeout(resolve, waitMs));
    const cached = await getCollectedCache<MidTermSourceRecord>(db, key);
    if (cached?.status === 'AVAILABLE') return cached.value;
    waitMs = Math.min(500, waitMs * 2);
  }
  return undefined;
}

function emptyRegion(): KmaMidTermRegionIds {
  return { temperatureRegionId: '' };
}
