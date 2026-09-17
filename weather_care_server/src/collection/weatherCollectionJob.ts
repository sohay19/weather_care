import type {
  CurrentPrecipitationObservation,
  OfficialRoadControl,
  RoadIceRisk,
  ServerEnv,
} from '../types';
import { KmaWeatherProvider } from '../providers/weather/kmaWeatherProvider';
import type { WeatherForecast } from '../providers/weather/weatherProvider';
import {
  enrichForecastWithEnvironmentalData,
  loadEnvironmentalData,
  type EnvironmentalDataBundle,
} from '../providers/environmental/environmentalDataService';
import { KmaUltraShortObservationProvider, type UltraShortObservation } from '../providers/weather/kmaUltraShortObservationProvider';
import { KmaPrecipitationObservationProvider } from '../providers/precipitation/precipitationObservationProvider';
import {
  KmaWarningProvider,
  type KmaWarningRegionMatch,
} from '../providers/warnings/kmaWarningProvider';
import {
  isRoadIceSeason,
  KmaRoadIceProvider,
  ROAD_ICE_ROAD_NUMBERS,
} from '../providers/road/kmaRoadIceProvider';
import { itsRoadControlProviderFromEnvironment } from '../providers/traffic/itsRoadControlProvider';
import { KmaHourlyObservationProvider } from '../providers/weather/kmaHourlyObservationProvider';
import { KmaDailyObservationProvider } from '../providers/weather/kmaDailyObservationProvider';
import { KmaMidTermProvider } from '../providers/weather/kmaMidTermProvider';
import { KmaUvProvider } from '../providers/uv/kmaUvProvider';
import { AirKoreaForecastProvider } from '../providers/air/airKoreaForecastProvider';
import { resolveKmaMidTermRegionIds } from '../regions/kmaMidTermRegionCatalog';
import { uvAreaNoForGrid } from '../regions/kmaUvAreaGridCatalog';
import { regionMetadataForGrid } from '../regions/regionCatalog';
import { kmaGridCoordinates } from '../regions/kmaGridCoordinates';
import { mapWithConcurrency } from '../utils/concurrencyLimiter';
import {
  cacheRecordIsFresh,
  collectedCacheKey,
  getCollectedCache,
  locationCacheKey,
  saveCollectedCache,
  type CollectedCacheRecord,
} from '../database/collectedWeatherRepository';
import { reserveApiHubBudget } from '../database/apiUsageRepository';
import { saveCurrentWeather } from '../database/weatherCacheRepository';
import {
  currentKoreanCalendarWeek,
  koreanCalendarDate,
} from '../database/weeklyForecastRepository';
import { providerErrorDiagnostic, safeErrorName } from '../observability/providerErrorDiagnostics';
import type {
  CollectedRegionBundle,
  CollectedWarningBundle,
  CollectedWeeklyBundle,
  CollectionTarget,
} from './collectionTypes';

const FORECAST_MAX_AGE_MS = 2 * 60 * 60 * 1000 + 40 * 60 * 1000;
const ENVIRONMENTAL_MAX_AGE_MS = 30 * 60 * 1000;
const ENVIRONMENTAL_RETRY_INTERVAL_MS = 10 * 60 * 1000;
const WEEKLY_MAX_AGE_MS = 6 * 60 * 60 * 1000;
const ULTRA_SHORT_MAX_AGE_MS = 70 * 60 * 1000;
const RADAR_BYTES = 13_281_414;
const ANALYSIS_VALIDATION_LIMIT = 69;

export interface WeatherCollectionOptions {
  now?: Date;
  collectCore?: boolean;
  collectRoadIce?: boolean;
}

export async function runWeatherCollectionJob(
  env: ServerEnv,
  options: WeatherCollectionOptions = {},
): Promise<void> {
  if (!env.DB) return;
  const now = options.now ?? new Date();
  const targets = await loadCollectionTargets(env.DB);
  if (targets.length === 0) return;
  const regions = distinctRegions(targets);
  const locations = distinctLocations(targets);

  if (options.collectCore !== false) {
    await collectRegionForecasts(env, regions, now);
    await collectWarnings(env, regions, now);
    await collectCurrentPrecipitation(env, targets, locations, now);
    await collectRoadControls(env, locations, now);
    if (koreanMinute(now) === 0) {
      await collectYesterdayComparisons(env, targets, now);
      if (koreanHour(now) === 2) {
        await collectDailyObservations(env, regions, now);
      }
    }
  }
  if (options.collectRoadIce === true) {
    await collectRoadIce(env, locations, now);
  }
}

async function loadCollectionTargets(db: D1Database): Promise<CollectionTarget[]> {
  const result = await db.prepare(
    `SELECT nx, ny, latitude, longitude
     FROM installations
     GROUP BY nx, ny, latitude, longitude`,
  ).all<{
    nx: number;
    ny: number;
    latitude: number | null;
    longitude: number | null;
  }>();
  return result.results.map((row) => ({
    nx: Number(row.nx),
    ny: Number(row.ny),
    latitude: row.latitude ?? undefined,
    longitude: row.longitude ?? undefined,
  }));
}

async function collectRegionForecasts(
  env: ServerEnv,
  regions: CollectionTarget[],
  now: Date,
): Promise<void> {
  await mapWithConcurrency(regions, 2, async ({ nx, ny }) => {
    try {
      let forecastRecord = await getCollectedCache<WeatherForecast>(
        env.DB,
        collectedCacheKey.forecast(nx, ny),
      );
      if (!cacheRecordIsFresh(forecastRecord, FORECAST_MAX_AGE_MS, now)) {
        const forecast = await new KmaWeatherProvider({
          serviceKey: env.KMA_SERVICE_KEY,
        }).getForecastByRegion(nx, ny);
        await saveCollectedCache(env.DB, {
          key: collectedCacheKey.forecast(nx, ny),
          type: 'COLLECTED_FORECAST',
          value: forecast,
          nx,
          ny,
          updatedAt: now,
        });
        await saveCurrentWeather(env.DB, nx, ny, forecast.current);
        forecastRecord = { value: forecast, status: 'AVAILABLE', updatedAt: now.toISOString() };
      }

      let environmentalRecord = await getCollectedCache<EnvironmentalDataBundle>(
        env.DB,
        collectedCacheKey.environmental(nx, ny),
      );
      if (shouldRefreshEnvironmentalRecord(environmentalRecord, now)) {
        const environmental = await loadEnvironmentalData(
          env,
          regionMetadataForGrid(nx, ny),
          { nx, ny, coordinates: kmaGridCoordinates(nx, ny), providerTimeoutMs: 7_500 },
        );
        await saveCollectedCache(env.DB, {
          key: collectedCacheKey.environmental(nx, ny),
          type: 'COLLECTED_ENVIRONMENTAL',
          value: environmental,
          nx,
          ny,
          updatedAt: now,
        });
        environmentalRecord = { value: environmental, status: 'AVAILABLE', updatedAt: now.toISOString() };
      }

      if (forecastRecord && environmentalRecord) {
        const bundle: CollectedRegionBundle = {
          forecast: enrichForecastWithEnvironmentalData(
            forecastRecord.value,
            environmentalRecord.value,
          ),
          environmental: environmentalRecord.value,
        };
        await saveCollectedCache(env.DB, {
          key: `COLLECTED_REGION_${nx}_${ny}`,
          type: 'COLLECTED_REGION',
          value: bundle,
          nx,
          ny,
          updatedAt: now,
        });
      }
      await collectWeekly(env, nx, ny, forecastRecord?.value, now);
    } catch (error) {
      logCollectionFailure('region', error, { nx, ny });
    }
  });
}

export function shouldRefreshEnvironmentalRecord(
  record: CollectedCacheRecord<EnvironmentalDataBundle> | null,
  now = new Date(),
): boolean {
  if (!record) return true;
  const updatedAt = Date.parse(record.updatedAt);
  if (!Number.isFinite(updatedAt)) return true;
  const hasTemporaryFailure = Object.values(record.value.sources ?? {}).some(
    ({ state }) => state === 'STALE' || state === 'UNAVAILABLE',
  );
  const maxAgeMs = hasTemporaryFailure
    ? ENVIRONMENTAL_RETRY_INTERVAL_MS
    : ENVIRONMENTAL_MAX_AGE_MS;
  return now.getTime() - updatedAt >= maxAgeMs;
}

async function collectWeekly(
  env: ServerEnv,
  nx: number,
  ny: number,
  forecast: WeatherForecast | undefined,
  now: Date,
): Promise<void> {
  const key = collectedCacheKey.weekly(nx, ny);
  const cached = await getCollectedCache<CollectedWeeklyBundle>(env.DB, key);
  const sameForecastIssue = cached?.value.forecast?.baseDate === forecast?.baseDate &&
    cached?.value.forecast?.baseTime === forecast?.baseTime;
  if (sameForecastIssue && cacheRecordIsFresh(cached, WEEKLY_MAX_AGE_MS, now)) return;
  const midRegion = resolveKmaMidTermRegionIds(undefined, undefined, nx, ny);
  const uvAreaNo = uvAreaNoForGrid(nx, ny);
  const [midTermDays, uv, airQuality] = await Promise.all([
    midRegion
      ? new KmaMidTermProvider({ serviceKey: env.KMA_SERVICE_KEY })
          .getForecast(midRegion).catch(() => [])
      : Promise.resolve([]),
    uvAreaNo
      ? new KmaUvProvider({ serviceKey: env.KMA_SERVICE_KEY })
          .getForecast(uvAreaNo).catch(() => undefined)
      : Promise.resolve(undefined),
    new AirKoreaForecastProvider({ serviceKey: env.KMA_SERVICE_KEY })
      .getForecast(undefined, nx, ny).catch(() => []),
  ]);
  await saveCollectedCache(env.DB, {
    key,
    type: 'COLLECTED_WEEKLY',
    value: {
      forecast,
      midTermDays,
      observedDays: cached?.value.observedDays ?? [],
      uv,
      airQuality,
      collectedAt: now.toISOString(),
    } satisfies CollectedWeeklyBundle,
    nx,
    ny,
    updatedAt: now,
  });
}

async function collectWarnings(
  env: ServerEnv,
  regions: CollectionTarget[],
  now: Date,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY) return;
  const metadata: Array<{
    region: CollectionTarget;
    value: { name: string; warningRegionIds: string[] };
  }> = regions.flatMap((region) => {
    const value = regionMetadataForGrid(region.nx, region.ny);
    return value ? [{
      region,
      value: { name: value.name, warningRegionIds: [...value.warningRegionIds] },
    }] : [];
  });
  const unresolved: Array<{
    region: CollectionTarget;
    coordinates: { latitude: number; longitude: number };
  }> = [];
  for (const region of regions) {
    if (regionMetadataForGrid(region.nx, region.ny)) continue;
    const cached = await getCollectedCache<KmaWarningRegionMatch>(
      env.DB,
      collectedCacheKey.warningRegion(region.nx, region.ny),
    );
    if (cacheRecordIsFresh(cached, 24 * 60 * 60 * 1000, now)) {
      metadata.push({
        region,
        value: {
          name: cached!.value.regionName,
          warningRegionIds: [cached!.value.regionId],
        },
      });
      continue;
    }
    const coordinates = region.latitude !== undefined && region.longitude !== undefined
      ? { latitude: region.latitude, longitude: region.longitude }
      : kmaGridCoordinates(region.nx, region.ny);
    if (coordinates) unresolved.push({ region, coordinates });
  }
  const provider = new KmaWarningProvider({ serviceKey: env.KMA_APIHUB_KEY });
  const mappingRefresh = await getCollectedCache<{ refreshedAt: string }>(
    env.DB,
    'COLLECTED_WARNING_MAPPING_REFRESH',
  );
  if (unresolved.length > 0 &&
      !cacheRecordIsFresh(mappingRefresh, 24 * 60 * 60 * 1000, now) &&
      await reserveApiHubBudget(
    env.DB,
    'WARNING_REGION_MAPPING',
    1,
    1_000_000,
    now,
  )) {
    try {
      const matches = await provider.resolveRegionsByLocations(
        unresolved.map(({ coordinates }) => coordinates),
      );
      for (const [index, { region }] of unresolved.entries()) {
        const match = matches[index];
        metadata.push({
          region,
          value: { name: match.regionName, warningRegionIds: [match.regionId] },
        });
        await saveCollectedCache(env.DB, {
          key: collectedCacheKey.warningRegion(region.nx, region.ny),
          type: 'COLLECTED_WARNING_REGION',
          value: match,
          nx: region.nx,
          ny: region.ny,
          updatedAt: now,
        });
      }
      await saveCollectedCache(env.DB, {
        key: 'COLLECTED_WARNING_MAPPING_REFRESH',
        type: 'COLLECTED_WARNING_MAPPING_REFRESH',
        value: { refreshedAt: now.toISOString() },
        updatedAt: now,
      });
    } catch (error) {
      logCollectionFailure('warning_region_mapping', error);
    }
  }
  const ids = [...new Set(metadata.flatMap(({ value }) => value.warningRegionIds))];
  if (ids.length === 0 || !await reserveApiHubBudget(env.DB, 'WARNING', 1, 256_000, now)) return;
  try {
    const warnings = await provider.getActiveForRegions(ids);
    await Promise.all(metadata.map(({ region, value }) =>
      saveCollectedCache(env.DB, {
        key: collectedCacheKey.warning(region.nx, region.ny),
        type: 'COLLECTED_WARNING',
        value: {
          warnings: warnings.filter((warning) =>
            value.warningRegionIds.includes(warning.regionId),
          ),
          regionName: value.name,
        } satisfies CollectedWarningBundle,
        nx: region.nx,
        ny: region.ny,
        updatedAt: now,
      }),
    ));
  } catch (error) {
    logCollectionFailure('warning', error);
  }
}

async function collectCurrentPrecipitation(
  env: ServerEnv,
  targets: CollectionTarget[],
  locations: Array<{ latitude: number; longitude: number }>,
  now: Date,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY || locations.length === 0) return;
  const ultraByGrid = new Map<string, UltraShortObservation>();
  for (const region of distinctRegions(targets)) {
    const key = collectedCacheKey.ultraShortObservation(region.nx, region.ny);
    let record = await getCollectedCache<UltraShortObservation>(env.DB, key);
    if (!cacheRecordIsFresh(record, ULTRA_SHORT_MAX_AGE_MS, now)) {
      try {
        const value = await new KmaUltraShortObservationProvider({
          serviceKey: env.KMA_SERVICE_KEY,
          now: () => now,
        }).getCurrent(region.nx, region.ny);
        await saveCollectedCache(env.DB, {
          key,
          type: 'COLLECTED_ULTRA_SHORT',
          value,
          nx: region.nx,
          ny: region.ny,
          updatedAt: now,
        });
        record = { value, status: 'AVAILABLE', updatedAt: now.toISOString() };
      } catch (error) {
        logCollectionFailure('ultra_short', error, {
          nx: region.nx,
          ny: region.ny,
        });
      }
    }
    if (record) ultraByGrid.set(`${region.nx}_${region.ny}`, record.value);
  }

  const targetByLocation = new Map(
    targets.flatMap((target) =>
      target.latitude === undefined || target.longitude === undefined
        ? []
        : [[locationCacheKey(target.latitude, target.longitude), target] as const],
    ),
  );
  const inputs = locations.flatMap((location) => {
    const target = targetByLocation.get(locationCacheKey(location.latitude, location.longitude));
    const reference = target && ultraByGrid.get(`${target.nx}_${target.ny}`);
    return reference ? [{ ...location, referenceRainDetected: reference.rainDetected,
      referenceObservedAt: reference.observedAt }] : [];
  });
  if (inputs.length === 0) return;
  const reserved = await reserveApiHubBudget(
    env.DB,
    'RADAR_AND_POINT_VALIDATION',
    1 + ANALYSIS_VALIDATION_LIMIT,
    RADAR_BYTES + ANALYSIS_VALIDATION_LIMIT * 4_096,
    now,
  );
  if (!reserved) return;
  try {
    const observations = await new KmaPrecipitationObservationProvider({
      serviceKey: env.KMA_APIHUB_KEY,
      now: () => now,
      timeoutMs: 12_000,
      attempts: 1,
    }).getCurrentByLocations(inputs, ANALYSIS_VALIDATION_LIMIT);
    await Promise.all(observations.map((value) => saveCollectedCache(env.DB, {
      key: collectedCacheKey.precipitation(value.latitude, value.longitude),
      type: 'COLLECTED_PRECIPITATION',
      value,
      updatedAt: now,
    })));
  } catch (error) {
    logCollectionFailure('precipitation', error);
  }
}

async function collectRoadIce(
  env: ServerEnv,
  locations: Array<{ latitude: number; longitude: number }>,
  now: Date,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY || locations.length === 0 || !isRoadIceSeason(now)) return;
  if (!await reserveApiHubBudget(
    env.DB,
    'ROAD_ICE',
    ROAD_ICE_ROAD_NUMBERS.length,
    ROAD_ICE_ROAD_NUMBERS.length * 2_100_000,
    now,
  )) return;
  try {
    const values = await new KmaRoadIceProvider({
      serviceKey: env.KMA_APIHUB_KEY,
      now: () => now,
    }).getNearestRisksByLocations(locations);
    await Promise.all(locations.map((location, index) => saveCollectedCache<RoadIceRisk | null>(
      env.DB,
      {
        key: collectedCacheKey.roadIce(location.latitude, location.longitude),
        type: 'COLLECTED_ROAD_ICE',
        value: values[index] ?? null,
        updatedAt: now,
      },
    )));
  } catch (error) {
    logCollectionFailure('road_ice', error);
  }
}

async function collectRoadControls(
  env: ServerEnv,
  locations: Array<{ latitude: number; longitude: number }>,
  now: Date,
): Promise<void> {
  const provider = itsRoadControlProviderFromEnvironment(env);
  if (!provider || locations.length === 0) return;
  await mapWithConcurrency(locations, 2, async (location) => {
    try {
      const value = await provider.getNearestActiveControl(
        location.latitude,
        location.longitude,
      );
      await saveCollectedCache<OfficialRoadControl | null>(env.DB, {
        key: collectedCacheKey.roadControl(location.latitude, location.longitude),
        type: 'COLLECTED_ROAD_CONTROL',
        value: value ?? null,
        updatedAt: now,
      });
    } catch (error) {
      logCollectionFailure('road_control', error);
    }
  });
}

async function collectYesterdayComparisons(
  env: ServerEnv,
  targets: CollectionTarget[],
  now: Date,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY) return;
  const regions = distinctRegions(targets).flatMap((target) => {
    const coordinates = kmaGridCoordinates(target.nx, target.ny);
    return coordinates ? [{ target, coordinates }] : [];
  });
  if (regions.length === 0 || !await reserveApiHubBudget(env.DB, 'ASOS_HOURLY', 3, 384_000, now)) return;
  try {
    const values = await new KmaHourlyObservationProvider({
      serviceKey: env.KMA_APIHUB_KEY,
      now: () => now,
    }).getYesterdayComparisons(regions.map(({ coordinates }) => coordinates));
    await Promise.all(regions.flatMap(({ target }, index) => {
      const value = values[index];
      if (!value) return [];
      return [saveCollectedCache(env.DB, {
        key: collectedCacheKey.comparison(target.nx, target.ny),
        type: 'COLLECTED_COMPARISON',
        value,
        nx: target.nx,
        ny: target.ny,
        updatedAt: now,
      })];
    }));
  } catch (error) {
    logCollectionFailure('comparison', error);
  }
}

async function collectDailyObservations(
  env: ServerEnv,
  targets: CollectionTarget[],
  now: Date,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY) return;
  const calendarWeek = currentKoreanCalendarWeek(now);
  const today = koreanCalendarDate(now);
  const endDate = calendarWeek.dates.filter((date) => date < today).at(-1);
  if (!endDate) return;
  const regions = distinctRegions(targets).flatMap((target) => {
    const coordinates = kmaGridCoordinates(target.nx, target.ny);
    return coordinates ? [{ target, coordinates }] : [];
  });
  if (regions.length === 0 || !await reserveApiHubBudget(
    env.DB,
    'AWS_DAILY',
    4,
    2_048_000,
    now,
  )) return;
  try {
    const values = await new KmaDailyObservationProvider({
      serviceKey: env.KMA_APIHUB_KEY,
    }).getDailyByLocations(
      regions.map(({ coordinates }) => coordinates),
      calendarWeek.startDate,
      endDate,
    );
    await Promise.all(regions.flatMap(({ target }, index) => {
      const key = collectedCacheKey.weekly(target.nx, target.ny);
      return [getCollectedCache<CollectedWeeklyBundle>(env.DB, key).then((cached) => {
        if (!cached) return;
        return saveCollectedCache(env.DB, {
          key,
          type: 'COLLECTED_WEEKLY',
          value: {
            ...cached.value,
            observedDays: values[index] ?? [],
            collectedAt: now.toISOString(),
          },
          nx: target.nx,
          ny: target.ny,
          updatedAt: now,
        });
      })];
    }));
  } catch (error) {
    logCollectionFailure('daily_observation', error);
  }
}

function distinctRegions(targets: CollectionTarget[]): CollectionTarget[] {
  return [...new Map(targets.map((target) => [
    `${target.nx}_${target.ny}`,
    { ...target },
  ])).values()];
}

function distinctLocations(
  targets: CollectionTarget[],
): Array<{ latitude: number; longitude: number }> {
  return [...new Map(targets.flatMap((target) =>
    target.latitude === undefined || target.longitude === undefined
      ? []
      : [[locationCacheKey(target.latitude, target.longitude), {
          latitude: target.latitude,
          longitude: target.longitude,
        }] as const],
  )).values()];
}

function koreanMinute(now: Date): number {
  return new Date(now.getTime() + 9 * 60 * 60 * 1000).getUTCMinutes();
}

function koreanHour(now: Date): number {
  return new Date(now.getTime() + 9 * 60 * 60 * 1000).getUTCHours();
}

function logCollectionFailure(
  source: string,
  error: unknown,
  context: Record<string, unknown> = {},
): void {
  console.error(JSON.stringify({
    event: 'weather_collection_failed',
    source,
    ...context,
    error: safeErrorName(error),
    ...providerErrorDiagnostic(error),
  }));
}
