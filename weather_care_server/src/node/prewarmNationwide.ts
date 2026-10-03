import { pathToFileURL } from 'node:url';
import { runWeatherCollectionJob } from '../collection/weatherCollectionJob';
import {
  cacheRecordIsFresh,
  collectedCacheKey,
  getCollectedCache,
  locationCacheKey,
  saveCollectedCache,
} from '../database/collectedWeatherRepository';
import { NATIONWIDE_PRECIPITATION_CACHE_KEY } from '../database/nationwidePrecipitationRepository';
import { isRoadIceSeason } from '../providers/road/kmaRoadIceProvider';
import {
  currentEnvironmentalData, environmentalDataIssues,
  type EnvironmentalDataBundle, type NationwideAirQualitySnapshot,
} from '../providers/environmental/environmentalDataService';
import { kmaGridCoordinates } from '../regions/kmaGridCoordinates';
import { nationwideAirForecastIsUsable, type NationwideAirForecast } from '../providers/air/airKoreaForecastProvider';
import {
  NATIONWIDE_FORECAST_GRIDS,
  NATIONWIDE_FORECAST_GRID_SHARD_COUNT,
} from '../regions/nationwideForecastGridCatalog';
import { previousKoreanDate } from '../collection/sourcePublicationSchedule';
import { latestMidTermIssueTimes } from '../providers/weather/kmaMidTermProvider';
import { supportedKmaMidTermRegionIds } from '../regions/kmaMidTermRegionCatalog';
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
  environmentalMissingSample: Array<{ cacheKey: string; sources: string[] }>;
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
        forceSourceRefresh: attempt > 1,
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
    `SELECT cache_key AS cacheKey, payload, status, updated_at AS updatedAt
       FROM weather_cache`,
  ).all() as Array<{
    cacheKey: string;
    payload: string;
    status: string;
    updatedAt: string;
  }>;
  const requiredObservationDates = recentCompletedKoreanDates(now, 7);
  const airRow = cacheRows.find((row) => row.cacheKey === collectedCacheKey.nationwideAir &&
    row.status === 'AVAILABLE');
  let nationwideAir: NationwideAirQualitySnapshot | undefined;
  try { nationwideAir = airRow ? JSON.parse(airRow.payload) : undefined; } catch { /* 손상된 원본은 사용하지 않는다. */ }
  const available = new Set(
    cacheRows
      .filter((row) => cacheRowHasUsablePayload(row, requiredObservationDates, now, nationwideAir))
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
  required.add(NATIONWIDE_PRECIPITATION_CACHE_KEY);
  required.add(collectedCacheKey.roadControlSnapshot);
  required.add(collectedCacheKey.nationwideAir);
  required.add(collectedCacheKey.nationwideAirForecast);
  required.add(collectedCacheKey.warningStations);
  required.add(collectedCacheKey.warningSnapshot);
  if (isRoadIceSeason(now)) required.add(collectedCacheKey.roadIceSnapshot);

  for (const { nx, ny } of grids) {
    required.add(collectedCacheKey.forecast(nx, ny));
    required.add(`CURRENT_${nx}_${ny}`);
    required.add(`COLLECTED_REGION_${nx}_${ny}`);
    required.add(collectedCacheKey.environmental(nx, ny));
    required.add(collectedCacheKey.weekly(nx, ny));
    required.add(collectedCacheKey.warning(nx, ny));
    required.add(collectedCacheKey.visibility(nx, ny));
    required.add(collectedCacheKey.ultraShortObservation(nx, ny));
  }
  const midTermIssue = latestMidTermIssueTimes(now, 1)[0];
  if (midTermIssue) {
    for (const { temperatureRegionId, landRegionId } of
      supportedKmaMidTermRegionIds()) {
      required.add(collectedCacheKey.midTermTemperature(
        temperatureRegionId,
        midTermIssue,
      ));
      if (landRegionId) {
        required.add(collectedCacheKey.midTermLand(landRegionId, midTermIssue));
      }
    }
  }
  for (const { nx, ny } of activeRegions) {
    required.add(collectedCacheKey.environmental(nx, ny));
    required.add(collectedCacheKey.warning(nx, ny));
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
    environmentalMissingSample: missing.filter((key) => key.startsWith('COLLECTED_ENVIRONMENTAL_'))
      .slice(0, 20).map((cacheKey) => {
        const row = cacheRows.find((candidate) => candidate.cacheKey === cacheKey);
        if (!row || row.status !== 'AVAILABLE') {
          return { cacheKey, sources: ['UV', 'PM10', 'PM25', 'O3'] };
        }
        try {
          const [, , nx, ny] = cacheKey.split('_');
          const bundle = currentEnvironmentalData(JSON.parse(row.payload), now,
            nationwideAir, kmaGridCoordinates(Number(nx), Number(ny)));
          return { cacheKey, sources: environmentalDataIssues(bundle, now) };
        } catch { return { cacheKey, sources: ['UV', 'PM10', 'PM25', 'O3'] }; }
      }),
  };
}

function cacheRowHasUsablePayload(row: {
  cacheKey: string;
  payload: string;
  status: string;
  updatedAt: string;
}, requiredObservationDates: readonly string[], now: Date,
  nationwideAir?: NationwideAirQualitySnapshot): boolean {
  if (row.status !== 'AVAILABLE' || row.payload.trim().length === 0) return false;
  try {
    const value: unknown = JSON.parse(row.payload);
    if (row.cacheKey === collectedCacheKey.roadControlSnapshot) {
      return Array.isArray(value) &&
        Date.parse(row.updatedAt) > now.getTime() - 30 * 60 * 1000;
    }
    if (row.cacheKey === collectedCacheKey.roadIceSnapshot) {
      return Array.isArray(value) &&
        Date.parse(row.updatedAt) > now.getTime() - 45 * 60 * 1000;
    }
    if (row.cacheKey === collectedCacheKey.warningStations) {
      return Array.isArray(value) && value.length > 0;
    }
    if (row.cacheKey === collectedCacheKey.warningSnapshot) {
      const snapshot = value as { stations?: unknown; warnings?: unknown };
      return Array.isArray(snapshot?.stations) && snapshot.stations.length > 0 &&
        Array.isArray(snapshot?.warnings) &&
        Date.parse(row.updatedAt) > now.getTime() - 45 * 60 * 1000;
    }
    if (row.cacheKey === collectedCacheKey.nationwideAir) {
      const snapshot = value as NationwideAirQualitySnapshot;
      return Array.isArray(snapshot?.catalog?.stations) &&
        Array.isArray(snapshot?.observations) &&
        snapshot.catalog.stations.length > 0 && snapshot.observations.length > 0 &&
        Date.parse(snapshot.collectedAt) > now.getTime() - 3 * 60 * 60 * 1000;
    }
    if (row.cacheKey === collectedCacheKey.nationwideAirForecast) {
      return nationwideAirForecastIsUsable(value as NationwideAirForecast, now);
    }
    if (row.cacheKey.startsWith('COLLECTED_ENVIRONMENTAL_')) {
      const [, , nx, ny] = row.cacheKey.split('_');
      const bundle = currentEnvironmentalData(value as EnvironmentalDataBundle, now,
        nationwideAir, kmaGridCoordinates(Number(nx), Number(ny)));
      return environmentalDataIssues(bundle, now).length === 0;
    }
    if (row.cacheKey === NATIONWIDE_PRECIPITATION_CACHE_KEY) {
      const manifest = value as { analysisChunks?: unknown; radarChunks?: unknown };
      return Number.isInteger(manifest?.analysisChunks) &&
        Number.isInteger(manifest?.radarChunks) &&
        Number(manifest.analysisChunks) > 0 && Number(manifest.radarChunks) > 0 &&
        Date.parse(row.updatedAt) > now.getTime() - 40 * 60 * 1000;
    }
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
