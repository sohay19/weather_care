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
import { reserveMidTermRequest } from '../database/apiUsageRepository';
import { providerErrorDiagnostic } from '../observability/providerErrorDiagnostics';
import { administrativeAreaForLocation, type NationwideLocation } from '../regions/nationwideLocation';

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
  provider?: 'KMA_DATA_GO_KR';
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
export const MID_TERM_DAILY_CALL_LIMIT = 9000;

export async function readCachedMidTermForecast(input: {
  db?: D1Database; location: NationwideLocation; now: Date;
}): Promise<MidTermForecastHydration> {
  const area = administrativeAreaForLocation(input.location);
  const region = resolveKmaMidTermLocation({ ...input.location,
    nx: -1, ny: -1, adminCode: input.location.adminCode ?? area?.[0], regionName: area?.[1] ?? input.location.regionName });
  if (!region || !input.db) return { days: [], region: region ?? emptyRegion(), cacheStatus: 'UNAVAILABLE' };
  for (const issueTime of latestMidTermIssueTimes(input.now, 3)) {
    const [temperature, land] = await Promise.all([
      getCollectedCache<MidTermSourceRecord>(input.db, collectedCacheKey.midTermTemperature(region.temperatureRegionId, issueTime)),
      region.landRegionId ? getCollectedCache<MidTermSourceRecord>(input.db, collectedCacheKey.midTermLand(region.landRegionId, issueTime)) : null,
    ]);
    if (temperature?.status !== 'AVAILABLE' || (region.landRegionId && land?.status !== 'AVAILABLE')) continue;
    const days = buildMidTermDailyForecast(issueTime, temperature.value.item, land?.value.item);
    if (days.length) return { days, region, issueTime, issuedAt: days[0].issuedAt, cacheStatus: 'HIT' };
  }
  return { days: [], region, cacheStatus: 'UNAVAILABLE' };
}

export async function hydrateMidTermForecast(input: {
  db: D1Database;
  serviceKey?: string;
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
  region: KmaMidTermRegionIds;
  now?: Date;
}): Promise<MidTermForecastHydration> {
  const now = input.now ?? new Date();
  const provider = new KmaMidTermProvider({
    serviceKey: input.serviceKey,
    now: () => now,
    timeoutMs: 30_000,
    fetcher: midTermPortalFetch(input.db),
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
    } catch (error) {
      const diagnostic = providerErrorDiagnostic(error);
      console.error(JSON.stringify({ event: 'mid_term_source_failed', provider: 'KMA_DATA_GO_KR', issueTime,
        regionId: input.region.temperatureRegionId, ...diagnostic }));
      if (['NOT_CONFIGURED', 'AUTHORIZATION_FAILED', 'QUOTA_EXCEEDED', 'RATE_LIMITED', 'BUDGET_EXHAUSTED'].includes(diagnostic.failureReason)) throw error;
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
  if (cached?.status === 'AVAILABLE' && cached.value.provider === 'KMA_DATA_GO_KR') {
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
    if (afterLease?.status === 'AVAILABLE' && afterLease.value.provider === 'KMA_DATA_GO_KR') {
      return { item: afterLease.value.item, refreshed: false };
    }
    const item = await input.fetch();
    await saveCollectedCache<MidTermSourceRecord>(input.db, {
      key: input.key,
      type: input.type,
      value: {
        provider: 'KMA_DATA_GO_KR',
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
    if (cached?.status === 'AVAILABLE' && cached.value.provider === 'KMA_DATA_GO_KR') return cached.value;
    waitMs = Math.min(500, waitMs * 2);
  }
  return undefined;
}

function emptyRegion(): KmaMidTermRegionIds {
  return { temperatureRegionId: '' };
}

function midTermPortalFetch(db: D1Database): typeof fetch {
  return async (input, init) => {
    if (!await reserveMidTermRequest(db, MID_TERM_DAILY_CALL_LIMIT, new Date())) throw new Error('MID_TERM_BUDGET_EXHAUSTED');
    const url = new URL(String(input));
    const started = performance.now();
    const response = await globalThis.fetch(input, init);
    const body = await response.arrayBuffer();
    if (body.byteLength > 32_768) throw new Error('KMA mid-term response size is invalid');
    console.log(JSON.stringify({ event: 'mid_term_portal_response', provider: 'KMA_DATA_GO_KR',
      endpoint: url.pathname.split('/').pop(), regionId: url.searchParams.get('regId'), issueTime: url.searchParams.get('tmFc'),
      httpStatus: response.status, responseBytes: body.byteLength, elapsedMs: Math.round(performance.now() - started) }));
    return new Response(response.status === 204 || response.status === 304 ? null : body,
      { status: response.status, statusText: response.statusText, headers: response.headers });
  };
}
