import { pathToFileURL } from 'node:url';
import { runWeatherCollectionJob } from '../collection/weatherCollectionJob';
import {
  cacheRecordIsFresh,
  collectedCacheKey,
  getCollectedCache,
  locationCacheKey,
  saveCollectedCache,
} from '../database/collectedWeatherRepository';
import { isRoadIceSeason } from '../providers/road/kmaRoadIceProvider';
import {
  NATIONWIDE_FORECAST_GRIDS,
  NATIONWIDE_FORECAST_GRID_SHARD_COUNT,
} from '../regions/nationwideForecastGridCatalog';
import { previousKoreanDate } from '../collection/sourcePublicationSchedule';
import {
  assertNodeEnvironment,
  createNodeRuntime,
  type NodeRuntime,
} from './runtime';

const PREWARM_ATTEMPTS = 3;
const RECENT_PREWARM_MAX_AGE_MS = 5 * 60 * 1000;
const OPERATIONAL_PREWARM_KEY = 'COLLECTED_OPERATIONAL_PREWARM';

interface ForecastGrid {
  nx: number;
  ny: number;
}

interface ActiveTarget extends ForecastGrid {
  latitude: number | null;
  longitude: number | null;
}

export interface OperationalPrewarmSummary {
  totalGrids: number;
  activeRegions: number;
  activeLocations: number;
  requiredCaches: number;
  collectedCaches: number;
  missingCaches: number;
  missingSample: string[];
}

export async function prewarmNationwideInRuntime(
  runtime: NodeRuntime,
  now = new Date(),
): Promise<OperationalPrewarmSummary> {
  runtime.env.NATIONWIDE_PRECOLLECT_ENABLED = 'true';
  let summary = inspectOperationalPrewarm(runtime, now);
  const recentPrewarm = await getCollectedCache<{ completedAt: string }>(
    runtime.env.DB,
    OPERATIONAL_PREWARM_KEY,
  );
  if (summary.missingCaches === 0 &&
      cacheRecordIsFresh(recentPrewarm, RECENT_PREWARM_MAX_AGE_MS, now)) {
    console.log(JSON.stringify({ event: 'operational_prewarm_reused', ...summary }));
    return summary;
  }

  for (let attempt = 1; attempt <= PREWARM_ATTEMPTS; attempt += 1) {
    for (
      let shardIndex = 0;
      shardIndex < NATIONWIDE_FORECAST_GRID_SHARD_COUNT;
      shardIndex += 1
    ) {
      await runWeatherCollectionJob(runtime.env, {
        now,
        collectCore: true,
        collectActiveDetails: false,
        nationwideShardIndex: shardIndex,
      });
      console.log(JSON.stringify({
        event: 'nationwide_prewarm_shard_completed',
        attempt,
        shardIndex,
        shardCount: NATIONWIDE_FORECAST_GRID_SHARD_COUNT,
      }));
    }

    await runWeatherCollectionJob(runtime.env, {
      now,
      collectCore: true,
      collectActiveDetails: true,
      collectHourlyObservations: true,
      dailyObservationLookbackDays: 7,
      collectRadar: true,
      collectRoadIce: true,
      forceSourceRefresh: true,
    });

    summary = inspectOperationalPrewarm(runtime, now);
    console.log(JSON.stringify({
      event: 'operational_prewarm_checked',
      attempt,
      ...summary,
    }));
    if (summary.missingCaches === 0) {
      const completedAt = new Date();
      await saveCollectedCache(runtime.env.DB, {
        key: OPERATIONAL_PREWARM_KEY,
        type: 'COLLECTED_OPERATIONAL_PREWARM',
        value: { completedAt: completedAt.toISOString() },
        updatedAt: completedAt,
      });
      return summary;
    }
  }

  throw new Error(`OPERATIONAL_PREWARM_INCOMPLETE:${summary.missingCaches}`);
}

export async function prewarmNationwide(): Promise<OperationalPrewarmSummary> {
  const runtime = createNodeRuntime();
  try {
    return await prewarmNationwideInRuntime(runtime);
  } finally {
    runtime.close();
  }
}

export function inspectOperationalPrewarm(
  runtime: NodeRuntime,
  now = new Date(),
  grids: readonly ForecastGrid[] = NATIONWIDE_FORECAST_GRIDS,
): OperationalPrewarmSummary {
  const cacheRows = runtime.database.sqlite.prepare(
    `SELECT cache_key AS cacheKey, payload, status
       FROM weather_cache`,
  ).all() as Array<{
    cacheKey: string;
    payload: string;
    status: string;
  }>;
  const requiredObservationDates = recentCompletedKoreanDates(now, 7);
  const available = new Set(
    cacheRows
      .filter((row) => cacheRowHasUsablePayload(row, requiredObservationDates))
      .map(({ cacheKey }) => cacheKey),
  );
  const activeTargets = runtime.database.sqlite.prepare(
    `SELECT nx, ny, latitude, longitude
       FROM installations
      GROUP BY nx, ny, latitude, longitude`,
  ).all() as ActiveTarget[];
  const activeRegions = distinctGridTargets(activeTargets);
  const activeLocations = distinctLocationTargets(activeTargets);
  const required = new Set<string>();

  for (const { nx, ny } of grids) {
    required.add(collectedCacheKey.forecast(nx, ny));
    required.add(`CURRENT_${nx}_${ny}`);
    required.add(`COLLECTED_REGION_${nx}_${ny}`);
    required.add(collectedCacheKey.weekly(nx, ny));
    required.add(collectedCacheKey.visibility(nx, ny));
  }
  for (const { nx, ny } of activeRegions) {
    required.add(collectedCacheKey.environmental(nx, ny));
    required.add(collectedCacheKey.warning(nx, ny));
    required.add(collectedCacheKey.ultraShortObservation(nx, ny));
  }
  for (const { latitude, longitude } of activeLocations) {
    required.add(collectedCacheKey.precipitation(latitude, longitude));
    required.add(collectedCacheKey.roadControl(latitude, longitude));
    if (isRoadIceSeason(now)) {
      required.add(collectedCacheKey.roadIce(latitude, longitude));
    }
  }

  const missing = [...required].filter((key) => !available.has(key));
  return {
    totalGrids: grids.length,
    activeRegions: activeRegions.length,
    activeLocations: activeLocations.length,
    requiredCaches: required.size,
    collectedCaches: required.size - missing.length,
    missingCaches: missing.length,
    missingSample: missing.slice(0, 20),
  };
}

function cacheRowHasUsablePayload(row: {
  cacheKey: string;
  payload: string;
  status: string;
}, requiredObservationDates: readonly string[]): boolean {
  if (row.status !== 'AVAILABLE' || row.payload.trim().length === 0) return false;
  try {
    const value: unknown = JSON.parse(row.payload);
    if (value === null) {
      return row.cacheKey.startsWith('COLLECTED_ROAD_CONTROL_') ||
        row.cacheKey.startsWith('COLLECTED_ROAD_ICE_');
    }
    if (typeof value !== 'object' || Array.isArray(value) ||
        Object.keys(value).length === 0) return false;
    if (row.cacheKey.startsWith('COLLECTED_WEEKLY_')) {
      const observedDays = (value as { observedDays?: unknown }).observedDays;
      if (!Array.isArray(observedDays)) return false;
      const completedDates = new Set(observedDays.flatMap((day) => {
        if (!day || typeof day !== 'object') return [];
        const candidate = day as { date?: unknown; weatherDataComplete?: unknown };
        return typeof candidate.date === 'string' &&
          candidate.weatherDataComplete === true
          ? [candidate.date.replaceAll('-', '')]
          : [];
      }));
      return requiredObservationDates.every((date) => completedDates.has(date));
    }
    return true;
  } catch {
    return false;
  }
}

function recentCompletedKoreanDates(now: Date, days: number): string[] {
  const endDate = previousKoreanDate(now);
  const end = new Date(`${endDate}T00:00:00Z`).getTime();
  return Array.from({ length: days }, (_, index) =>
    new Date(end - (days - index - 1) * 86_400_000)
      .toISOString()
      .slice(0, 10)
      .replaceAll('-', ''),
  );
}

function distinctGridTargets(targets: readonly ActiveTarget[]): ForecastGrid[] {
  const values = new Map<string, ForecastGrid>();
  for (const { nx, ny } of targets) {
    values.set(`${nx}_${ny}`, { nx: Number(nx), ny: Number(ny) });
  }
  return [...values.values()];
}

function distinctLocationTargets(
  targets: readonly ActiveTarget[],
): Array<{ latitude: number; longitude: number }> {
  const values = new Map<string, { latitude: number; longitude: number }>();
  for (const target of targets) {
    if (target.latitude === null || target.longitude === null) continue;
    const latitude = Number(target.latitude);
    const longitude = Number(target.longitude);
    values.set(locationCacheKey(latitude, longitude), { latitude, longitude });
  }
  return [...values.values()];
}

async function main(): Promise<void> {
  assertNodeEnvironment();
  const summary = await prewarmNationwide();
  console.log(JSON.stringify({ event: 'operational_prewarm_completed', ...summary }));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  void main().catch((error) => {
    console.error(JSON.stringify({
      event: 'operational_prewarm_failed',
      error: error instanceof Error ? error.message : 'UnknownError',
    }));
    process.exitCode = 1;
  });
}
